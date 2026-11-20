# AI Architectural & Protocol Decisions

This document records durable architectural, protocol, security, and compatibility decisions that future sessions and PRs must respect.

---

## DECISION-001: Dual-Role BLE Packet Transport Architecture
- **Context**: On Android, when two Offlink devices communicate over BLE, one acts as Central (GATT client) and the other as Peripheral (GATT server). Neither device knows in advance which role it will play for an incoming or outgoing session.
- **Decision**: `BlePacketTransport` coordinates both Central and Peripheral roles.
  - When the local device connects to a remote peer as Central, it instantiates and routes through `BlePacketChannel` (writes to peer RX, subscribes to peer TX).
  - When a remote device connects to the local device as Central, the local device's `BlePeripheralPacketChannel` receives incoming packets on its GATT server and sends response packets by notifying on its TX characteristic.
  - Both incoming streams are decoded via `PacketCodec` and multiplexed into a single `incomingPackets` stream on `PacketTransport`.
- **Status**: Implemented in Module 1 (`feature/protocol-ble-integration`).

---

## DECISION-002: Dynamic ATT MTU Negotiation with Safe Fallback
- **Context**: Default BLE ATT MTU is 23 bytes (effective payload ~20 bytes). Serialized JSON `OfflinkPacket` payloads range from ~150 to ~500 bytes. Android BLE allows requesting up to 512 bytes MTU on Central connection.
- **Decision**: Upon GATT connection in `BlePacketChannel.initialize()`, the Central requests an MTU of 512 bytes with graceful fallback on platforms or devices where MTU negotiation fails. The GATT server (`flutter_ble_peripheral`) responds to MTU negotiation and buffers long writes if prepared writes are used.
- **Status**: Implemented in Module 1 (`feature/protocol-ble-integration`).

---

## DECISION-003: Safe Rejection of Malformed Protocol Packets
- **Context**: In an untrusted BLE environment, malformed, non-UTF8, non-JSON, or schema-invalid byte sequences may arrive on either GATT characteristic.
- **Decision**: All transport listeners must catch decoding and parsing exceptions safely, ignoring malformed packets without throwing unhandled exceptions, crashing streams, or terminating the connection.
- **Status**: Enforced in `BlePacketTransport`, `BlePacketChannel`, and `BlePeripheralPacketTransport`.

---

## DECISION-004: Decoupled MessageService Contract & In-Memory Chat Architecture
- **Context**: Module 2 introduces direct peer-to-peer chat functionality. The presentation layer (`ChatPage`) must not invoke BLE transport APIs, serialize `OfflinkPacket`s directly, or couple itself to future database schemas.
- **Decision**:
  - Define an abstract domain contract `MessageService` (`lib/domain/messaging/message_service.dart`) exposing `Stream<ChatMessage> incomingMessages`, `Future<void> sendMessage({required String recipientNodeId, required String content})`, and lifecycle `dispose()`.
  - Implement `DirectMessageService` (`lib/domain/messaging/direct_message_service.dart`) implementing `MessageService` over `PacketTransport` and `IdentityManager`.
  - For Module 2, conversation history is managed in-memory within `ChatPage` and scoped per active session.
  - The UI protects against duplicate sends via an async `_isSending` lock on the send button.
  - Module 3 will layer persistent SQLite/Drift storage beneath or alongside `MessageService` without requiring UI or transport redesign.
- **Status**: Implemented in Module 2 (`feature/direct-messaging`).

---

## DECISION-005: Drift SQLite Database & Repository Architecture
- **Context**: Offlink requires persistent local storage for message and conversation history that survives app restarts, supports chronological retrieval, unread tracking, cascade deletion, and asynchronous stream updates.
- **Decision**:
  - Implement SQLite persistence using `Drift` with strongly typed tables: `ConversationsTable` and `MessagesTable`.
  - Enable SQLite foreign keys (`PRAGMA foreign_keys = ON`) in `beforeOpen` with cascade deletion from conversations to messages.
  - Abstract data access behind domain interfaces: `ConversationRepository` and `MessageRepository`.
  - All DateTime columns are normalized to UTC upon retrieval (`.toUtc()`) to ensure consistent ordering and timestamp comparison across diverse device locales.
  - Inject repositories into `DirectMessageService` and `ChatPage` to automatically persist messages on send and receive, and preload conversation history on chat launch without coupling UI components to Drift.
- **Status**: Implemented in Module 3 (`feature/local-message-storage`).


---

## DECISION-006: Authenticated X25519/Ed25519 Handshake & AES-256-GCM AEAD Session Encryption
- **Context**: Offlink operates over open Bluetooth Low Energy (BLE) channels. Packets can be intercepted, tampered with, or replayed by untrusted peer or relay nodes. The application requires mutual peer identity authentication, forward secrecy, ciphertext-only transmission over the wire, replay protection, and envelope-bound authenticity.
- **Decision**:
  - Mutual Authentication: Peers sign ephemeral X25519 public keys with their long-term Ed25519 identity key (`HandshakeInitPayload` and `HandshakeResponsePayload`). Signatures are strictly 64 bytes and validated prior to session key derivation.
  - Forward Secrecy & Key Derivation: Ephemeral X25519 Diffie-Hellman key agreement derives a shared secret. HKDF-SHA256 with domain-separated salt and info parameters derives a 256-bit symmetric session key (`AesGcm.with256bits()`).
  - AEAD Envelope Binding: Messages are encrypted with AES-256-GCM using Additional Authenticated Data (AAD) bound to packet envelope headers: `AAD = "$messageId:$senderNodeId:$recipientNodeId:$sequenceNumber"`. This prevents header tampering, recipient swapping, and message splicing attacks.
  - Replay Protection: A monotonic sequence counter is tracked per session. Inbound packets with `sequenceNumber <= lastInboundSequenceNumber` are rejected immediately. The counter only advances after successful AEAD cryptographic MAC verification.
  - Plaintext Leak Prevention: Any authentication or decryption failure silently rejects the packet without logging, persisting, or displaying corrupted plaintext to the user.
  - UI Security Indicator: `ChatPage` displays an "Encrypted" lock badge when a secure session is active with the peer.
- **Status**: Implemented in Module 4 (`feature/secure-messaging`).

---

## DECISION-007: Multi-Peer Mesh Routing, Split-Horizon Flooding, and End-to-End Privacy Preservation across Relay Hops
- **Context**: Offlink devices must communicate beyond direct single-hop BLE range via multi-peer mesh routing. Intermediate relay nodes must forward messages without having access to message plaintext. Routing loops, broadcast storms, and stale paths must be prevented. In addition, delivery confirmations (ACKs) must route back to the origin across intermediate relays to confirm successful delivery.
- **Decision**:
  - Transport Layer Abstraction: `MeshPacketRouter` implements `PacketTransport`, wrapping physical `BlePacketTransport` and feeding directly into `DirectMessageService`. This preserves the Open/Closed Principle: neither UI nor cryptographic services require changes to support multi-hop routing.
  - End-to-End Privacy across Relay Hops: Intermediate relay nodes inspect only `OfflinkPacket` envelope headers (`messageId`, `senderNodeId`, `recipientNodeId`, `ttl`). The encrypted `payload` is forwarded intact without decryption. Intermediate relay nodes cannot decrypt payloads as they lack the X25519/AES-GCM session keys established between the communicating endpoints.
  - Loop Prevention & Deduplication: `SeenMessageCache` tracks observed message IDs with bounded capacity (default 1,000) and entry TTL (default 10 minutes). Duplicate packets are discarded and emitted to `droppedPackets`. Outbound packets from the local node are marked in the cache to prevent loopback processing.
  - Hop Limit & Expiration: When acting as a relay, packets are forwarded with decremented TTL (`ttl: packet.ttl - 1`). Packets with `ttl <= 1` are dropped as expired.
  - Dynamic Routing Table & Split-Horizon Flooding: `RoutingTable` learns reverse routes from incoming packet sender IDs and hop counts, selecting shorter paths and pruning entries after 15 minutes. When forwarding or flooding, split-horizon suppression prevents sending packets back out on the link or peer from which they arrived.
  - Multi-Hop Delivery Acknowledgement: Upon receiving and storing a message, the destination node automatically emits an `OfflinkMessageType.acknowledgement` packet carrying the original `messageId` back to the sender node across the mesh. Upon receiving the ACK packet, `DirectMessageService` updates the message status in `MessageRepository` to `ChatMessageStatus.delivered`.
- **Status**: Implemented in Module 5 (`feature/mesh-routing`).

---

## DECISION-008: Android Foreground Service, Lifecycle Resilience, Exponential Backoff Recovery, and Unacknowledged Message Retransmission
- **Context**: Mobile operating systems (particularly Android 8.0+ through 14+) impose strict background execution limits, Doze mode battery restrictions, and aggressive process termination when an application leaves the foreground. Offlink must maintain BLE mesh availability, survive app minimization, lock/unlock transitions, and transient disconnections, while avoiding battery-draining continuous scan loops or reconnect retry storms.
- **Decision**:
  - Android 14+ Foreground Service: Implement a native Android Foreground Service (`OfflinkForegroundService`) typed with `connectedDevice` (`ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE`) and ongoing notification on an `IMPORTANCE_LOW` channel (`offlink_background_channel`). The service is started via `startForegroundService` when the Flutter app transitions to background (`AppLifecycleState.paused` or `hidden`) and stopped when detached.
  - App Lifecycle Coordination: `AppLifecycleCoordinator` couples `AppLifecycleManager` (which observes `WidgetsBindingObserver`) with `BleDiscovery`. To conserve battery in background, aggressive continuous scanning is paused while peripheral advertising and established GATT connections remain active to receive and relay incoming traffic. Full scanning resumes automatically upon return to the foreground.
  - Exponential Backoff Connection Recovery: `ConnectionRecoveryCoordinator` manages reconnection to tracked peers when links drop unexpectedly. Reconnection uses exponential backoff with jitter (`delay = min(initialDelay * (backoffMultiplier ^ attempt), maxDelay) + jitter`), capped at `maxAttempts` (default: 5) to prevent battery-draining retry storms. Reconnects pause when Bluetooth is disabled and resume immediately when Bluetooth is restored.
  - Unacknowledged Message Recovery: `PendingMessageRecoveryService` scans `MessageRepository` for unacknowledged outgoing messages older than `ackTimeout` (default: 5 seconds) and retransmits them preserving their original `messageId`. The recipient node's `insertOnConflictUpdate` and `SeenMessageCache` ensure idempotent deduplication without creating duplicate messages in user chat history. Retries exceeding `maxRetries` (default: 3) transition to `ChatMessageStatus.failed`.
  - Zero Third-Party Background Plugin Bloat: Native Android service is integrated cleanly via a lightweight `MethodChannel` (`com.example.offlink/background_service`) abstracted behind the domain contract `BackgroundServiceContract`, ensuring 100% testability across all desktop and test environments without platform crashes.
- **Status**: Implemented in Module 6 (`feature/background-service-lifecycle`).
