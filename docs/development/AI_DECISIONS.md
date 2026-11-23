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

---

## DECISION-009: Offline Message Queue & Store-and-Forward Reliability (Delay-Tolerant Networking)
- **Context**: In offline-first BLE mesh environments, target recipient devices or intermediate mesh relays are frequently unreachable due to physical distance, transient interference, device sleep, or temporary mobility (data mule scenarios). Messages must survive app restarts and device reboots, be safely stored when unreachable, and reliably delivered without central servers, while strictly preventing relay plaintext exposure, duplicate messages, and storage exhaustion.
- **Decision**:
  - Drift Persistent Queued Packets: Upgraded SQLite schema to version 2 by introducing `QueuedPacketsTable` and `DriftStoreAndForwardRepository` implementing `StoreAndForwardRepository`. Packets stored for forwarding preserve original packet metadata, TTL, and encrypted ciphertext.
  - Store-and-Forward Relay Architecture: `StoreAndForwardManager` integrates with `MeshPacketRouter`. When a relay receives a packet destined for a third-party node and cannot deliver immediately (no active next hop or all neighbor links fail), it enqueues the packet into persistent storage.
  - Relay Privacy Protection: Relay nodes store only opaque `payload` (ciphertext for encrypted packets) without holding cryptographic keys, never attempting decryption, and never persisting plaintext in conversation history.
  - Opportunistic Forwarding & TTL Enforcement: When a target peer connects directly or a new route is learned, `StoreAndForwardManager` immediately flushes matching queued packets with decremented TTL (`ttl - 1`). Expired packets (`ttl <= 1` or older than `maxPacketAge: 24h`) are pruned to prevent stale circulation.
  - Multi-Hop ACK Purge & Reverse Store-and-Forward: When an ACK packet (`OfflinkMessageType.acknowledgement`) traverses intermediate relays, `StoreAndForwardManager.onAckReceived` immediately removes the corresponding message from the store-and-forward queue. If the reverse path to the sender is temporarily unavailable, intermediate relays store and forward the ACK packet itself.
  - Idempotent Recipient Deduplication: In `DirectMessageService`, if an incoming message ID already exists in `MessageRepository`, the node immediately re-transmits the delivery ACK (recovering lost ACKs for the sender) but suppresses duplicate events to `incomingMessages` and avoids incrementing unread counters.
  - Outgoing Offline Queue & Resilience: Local outgoing messages are stored with `status: sent` in SQLite before network transmission. If transmission fails due to offline state, the message remains safely queued. `PendingMessageRecoveryService` enforces bounded retries with exponential backoff and randomized jitter, immediate opportunistic retries upon peer availability, and expiration after 24 hours.
  - Bounded Storage Defense: `pruneExpired` enforces a hard cap (`maxQueueSize: 200` packets) with FIFO/oldest eviction to eliminate storage exhaustion attacks.
- **Status**: Implemented in Module 7 (`feature/offline-queue-store-forward`).

---

## DECISION-010: Group Messaging, Pairwise Encrypted Fanout, Dynamic Membership Control, and Cryptographic Revocation Secrecy
- **Context**: Offlink requires group messaging without servers, cloud coordinators, cellular networks, or internet access. Relays in the BLE mesh must route group packets without decrypting them. When members leave or are removed by an admin, they must not be able to decrypt future messages (Post-Removal Secrecy / Backward Secrecy). Group packets must support delay-tolerant store-and-forward, reverse-path ACKs, and idempotent deduplication.
- **Decision**:
  - Drift Schema v3: Added `GroupsTable` (`id`, `name`, `creatorNodeId`, `createdAt`, `updatedAt`) and `GroupMembersTable` (`groupId` references `GroupsTable.id` with cascade deletion, `memberNodeId`, `memberDisplayName`, `role`, `joinedAt`, composite PK `{groupId, memberNodeId}`). Upgraded `OfflinkDatabase` to `schemaVersion: 3` with automatic SQLite migrations.
  - Pairwise Session Fanout Architecture: Group messages (`GroupMessagePayload`) and membership events (`GroupMembershipPayload`) are encrypted individually for each active group member using established pairwise authenticated sessions (`SecureSessionService` via X25519 + AES-256-GCM AEAD).
  - Relay Privacy & Mesh Compatibility: Each member's encrypted packet travels in an `OfflinkPacket` with `recipientNodeId: memberNodeId`. Intermediate mesh relays forward only opaque ciphertext. Relays cannot decrypt payloads and have no knowledge of group identifiers, member lists, or message content.
  - Zero-Plaintext Security Enforcement: When `SecureSessionService` is configured, group messages and control events are strictly encrypted. If a pairwise session is absent or fails, plaintext transmission is rejected, and member delivery is marked failed rather than leaking plaintext over the air.
  - Authorization & Spoofing Defense: On packet arrival, the envelope sender is verified against the inner payload sender (`packet.senderNodeId == groupPayload.senderNodeId`). Incoming group messages from senders not present in the local group membership list are discarded. Group membership changes (`add`, `remove`) require admin role verification (`membershipPayload.adminNodeId`).
  - Cryptographic Revocation Secrecy: Removing a member immediately excludes their node ID from subsequent message fanouts. Because each packet is encrypted under the recipient's pairwise session key, removed members cannot decrypt future group messages even if acting as intermediate relays or sniffing the radio channel.
  - Per-Member Delivery Tracking & ACK Correlation: Delivery ACKs are correlated to the original message ID, updating individual member statuses to `delivered`. When all members acknowledge, the parent group message in `MessagesTable` transitions to `ChatMessageStatus.delivered`.
  - Delay-Tolerant Store-and-Forward Compatibility: Offline group members have their individual packets stored in relay `StoreAndForwardManager` queues. When the member reconnects, the relay flushes the queued packet, preserving original packet IDs and enabling reliable delayed group delivery.
- **Status**: Implemented in Module 8 (`feature/group-messaging`).

---

## DECISION-011: Privacy-Preserving Offline Location Sharing, End-to-End Pairwise Encryption, In-Place Live Session Updates, and Android Foreground Permission Model
- **Context**: Offlink users need to communicate their geographic coordinates (one-time snapshots and live locations) to 1-to-1 contacts and group recipients over BLE mesh networks completely offline, with zero dependencies on central servers, cloud APIs, cellular data, or internet connectivity. Geographic coordinates are sensitive personal data: intermediate mesh relays must never learn or decrypt location information; the system must strictly prevent plaintext exposure over the air; the database must not retain extraneous location tracks or a separate history table; live location streams must not flood chat history or trigger battery-draining continuous disk writes; location updates must be rate-limited and pause when the app is backgrounded to protect battery life; and location operations must strictly comply with Android permission restrictions (foreground permissions only, no unnecessary background location permission, explicit user opt-in, clear visual sharing indicators, and immediate revocation/stop controls).
- **Decision**:
  - Wire Protocol & Envelope Serialization: Introduced `OfflinkMessageType.location` (`'loc'`) and `LocationPayload` encapsulating coordinates (latitude/longitude with boundary validation -90..90, -180..180), accuracy (meters), altitude, speed, heading, timestamp, expiration (`expiresAt`), sharing type (`oneTime`, `liveUpdate`, `liveStop`), and session identifier (`liveSessionId`).
  - Zero-Plaintext Security & Pairwise Encryption: All outgoing location payloads are encrypted end-to-end via `SecureSessionService` using established pairwise sessions (X25519 + AES-256-GCM AEAD). If a pairwise session is absent or encryption fails, plaintext transmission is strictly rejected. Intermediate relays forward `OfflinkPacket` containing opaque ciphertext only, never attempting decryption and never persisting plaintext.
  - Transparent User Control & Explicit Opt-In: Location sharing is strictly initiated by user action via `LocationSharingSheet`. The sheet discloses recipient identity and cryptographic status before transmission. One-time snapshot sharing sends a single position fix. Live sharing requires selecting a duration (15m, 30m, 60m), displays prominent active banners in chat and group chat pages with immediate "Stop" controls, and automatically expires when the duration elapses.
  - Battery-Conscious Adaptive Tracking: Periodic updates are limited to a 30s interval (`_updateInterval`). GPS polling is paused or throttled when the application is backgrounded (`isAppBackgrounded = true`), resuming when foregrounded.
  - In-Place Live Message Updating & No Separate History: To prevent database bloat, disk I/O battery consumption, and privacy leakage (`docs/security/RETENTION.md`), live location messages reuse a deterministic message ID (`loc-live-${liveSessionId}`). Subsequent periodic updates update the same SQLite message record in-place. Concluding live sharing sends a `liveStop` packet and updates the bubble to `Live Location (Ended)`.
  - Android Permission Compliance: `AndroidManifest.xml` requires only foreground permissions (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`) and intentionally excludes `ACCESS_BACKGROUND_LOCATION`. Permission denial, permanent denial, and disabled location services are gracefully handled with informative modal warnings and settings prompts.
  - Group Location Fanout: For group location sharing, coordinates are encrypted pairwise for every active group member (`GroupRepository.getGroupMembers`). Intermediate relays forward ciphertext packets to individual member IDs. On receipt, authorization is verified: envelope sender must match payload sender, and both sender and recipient must be authorized members of the group.
  - Store-and-Forward & Mesh Relay Compatibility: Location packets are standard `OfflinkPacket` instances. When an intended recipient is offline or out of range, relay nodes enqueue the encrypted packet in `DriftStoreAndForwardRepository` and opportunisticly flush it upon reconnection, verified via end-to-end integration tests.
- **Status**: Implemented in Module 9 (`feature/location-sharing`).

---

## DECISION-012: Battery Optimization, Adaptive Duty-Cycled BLE Discovery, Idle Timer Elimination, and Reconnection Storm Mitigation
- **Context**: In off-grid and disaster situations, device battery longevity directly determines communications availability. Continuous BLE scanning keeps the radio receiver hardware energised 100% of the time, consuming 10%–25% device battery per hour. Unconditional periodic timers (e.g. 1s GPS ticks or 10s–15s SQLite polling) repeatedly wake the CPU from deep sleep (C-states) and trigger unnecessary disk writes even when the app is completely idle. Simultaneous GATT reconnection attempts across peers cause radio channel congestion and connection thrashing. Flooding mesh packets back to their originating sender creates redundant multi-hop ping-pong broadcasts.
- **Decision**:
  - Adaptive Duty-Cycled BLE Discovery (`AdaptiveBleDiscovery`): Implemented a decorator for `BleDiscovery` that alternates between active scanning windows and resting pause windows according to `BatteryOptimizationPolicy`:
    - `active`: 8s scan / 4s pause (66.7% radio on-time, 33.3% idle radio savings) for active navigation/chat or pending queue flush.
    - `balanced`: 6s scan / 12s pause (33.3% radio on-time, 66.7% idle radio savings) for foreground connected mesh nodes with idle traffic.
    - `lowPower`: 4s scan / 60s pause (6.25% radio on-time, 93.75% idle radio savings) for minimized/background operation under Android foreground service.
    - `conserve`: 4s scan / 120s pause (3.23% radio on-time, 96.77% idle radio savings) for extended silence or low-battery preservation.
  - Peripheral Advertising Continuity: During scan pause windows, peripheral advertising remains active. Remote peers can initiate incoming GATT connections at any moment while our scan receiver rests.
  - Cycle-End Ghost Node Pruning: `completeScanCycle()` is automatically invoked at the conclusion of each active scan window, purging stale peers that walked out of RF range without accumulating phantom entries.
  - Immediate Reactive Scan Triggers: User pull-to-refresh on `HomePage` or enqueueing of outgoing messages immediately triggers a fresh scan cycle, ensuring zero responsiveness penalty from duty cycling.
  - Idle Timer Elimination (Zero Idle CPU Wakeups):
    - `LocationService`: Removed unconditional 1s periodic timer from constructor; lazily spawns only when at least one live location session is active, and cancels immediately when all live sessions expire or are stopped, eliminating 3,600 CPU wakeups/hour when idle.
    - `PendingMessageRecoveryService`: Suspends the 10s periodic polling timer when the outgoing unacknowledged queue is empty, eliminating ~360 SQLite queries/hour when idle. Resumes upon `notifyPendingMessageQueued()` or app resume.
    - `StoreAndForwardManager`: Suspends the 15s periodic maintenance timer when `getQueueSize() == 0`, eliminating ~240 SQLite queries/hour when idle. Resumes upon `enqueueInTransitPacket()`.
  - Reconnection Storm Mitigation (`ConnectionRecoveryCoordinator`):
    - Global Inter-Peer Spacing: Enforced `minAttemptSpacing` (500ms) between successive connection attempts across all peers to eliminate simultaneous GATT handshake collision storms.
    - Background Attempt Capping: In background mode, capped maximum reconnection attempts to 3 (down from 5) with an increased initial delay (4s instead of 1s) to conserve background battery.
  - Mesh Relay Flood Suppression (`MeshPacketRouter`):
    - In `_floodPacket()`, intermediate relays explicitly skip `peerId == packet.senderNodeId`, preventing echoing flooded packets back to the originating node and eliminating multi-hop radio channel loops.
  - Power Policy Coordination (`AdaptivePowerCoordinator`):
    - Dynamically evaluates lifecycle transitions, connected peer counts, pending queue state, and active live location sessions to transition seamlessly between `active`, `balanced`, and `lowPower` modes.
  - Cryptographic & Integrity Invariance: No encryption keys, HMAC signature validations, or payload integrity checks are weakened or bypassed for battery savings. All cryptographic operations remain 100% active.
- **Status**: Implemented in Module 10 (`feature/battery-optimization`).

---

## DECISION-013: Local Serverless Peer Blocking, Sliding-Window Inbound Flood Quarantine, Deterministic Symmetric Safety Fingerprints, and Protocol Fuzzing
- **Context**: In decentralized peer-to-peer mesh networks lacking centralized authentication servers or moderation authority, malicious or malfunctioning nodes can attempt to disrupt local mesh operations or harass individual users. Attacks include:
  1. Targeted harassment / spamming from rogue peers.
  2. RF / CPU / Disk battery-exhaustion flooding attacks (flooding thousands of invalid packets or connection attempts).
  3. Man-In-The-Middle (MITM) attacks where an active adversary substitutes ephemeral or identity keys.
  4. Malformed packet fuzzing / crash attacks targeting binary packet decoders, JSON deserializers, or router logic.
- **Decision**:
  - **Local Serverless Peer Blocking (`PeerSecurityRepository`, `DriftPeerSecurityRepository`)**:
    - Drift schema version 4 introduces `BlockedPeersTable` (`nodeId`, `blockedAt`, `reason`) and `PeerTrustTable` (`peerNodeId`, `peerPublicKey`, `safetyFingerprint`, `trustStatus`, `verifiedAt`, `updatedAt`).
    - Ingress Discard: `MeshPacketRouter` checks blocked status synchronously using in-memory cached sets at the earliest entry point (`handleIncomingPacket`). Packets from blocked nodes are discarded immediately before cryptographic decryption, routing table updates, or SQLite writes, preventing resource exhaustion.
    - Relay Suppression: Mesh packets originating from (`senderNodeId`) or addressed to (`recipientNodeId`) blocked nodes are dropped before forwarding to adjacent peers.
    - Transport & Discovery Filtering: `AdaptiveBleDiscovery` silences discovered peer events from blocked nodes so they do not appear in nearby scan lists. `ConnectionRecoveryCoordinator` skips reconnect attempts to blocked peers.
    - Outbound Send Rejection: `DirectMessageService.sendMessage()` synchronously throws a `StateError` if the destination node is blocked.
  - **Inbound Flood Rate Limiting & Quarantine (`FloodRateLimiter`)**:
    - Sliding-Window Throttle: Every incoming packet is evaluated per `senderNodeId` over a sliding window (`windowDuration`: 3s, `maxPacketsPerWindow`: 15 packets).
    - Automatic Escalating Quarantine: Senders violating the rate threshold accumulate strikes. Upon reaching 3 strikes, the node enters a 30-second quarantine (`quarantineDuration`: 30s) during which all inbound packets are dropped without evaluation.
    - Self-Healing Memory Management: Clean-up routines automatically prune stale sender buckets every minute or whenever tracking exceeds 500 nodes, bounding memory usage under adversarial node ID spoofing.
  - **Cryptographic Safety Fingerprints & MITM Detection (`SafetyFingerprintGenerator`)**:
    - Deterministic Symmetric Pairing: To guarantee identical numbers on both devices without out-of-band role negotiation, public keys are canonicalized and lexicographically sorted (`sortedKeys = [localKey, peerKey]..sort()`).
    - Digest & Formatting: A SHA-256 hash transcript `offlink-safety-v1:$k1:$k2` is computed and formatted into 60 decimal digits grouped into 12 chunks of 5 digits (`00000 00000 ...`), with visual chunk styling in the UI.
    - Automatic Key Mismatch Detection: On receiving an X25519/Ed25519 handshake packet (`HandshakeInitPayload`), `DirectMessageService` verifies the incoming public key against `PeerTrustTable`. If the node ID was previously seen with a different key, status is set to `TrustStatus.mismatched`, active handshake responses are aborted, and a persistent warning banner is displayed on `ChatPage`.
  - **Security UI Controls**:
    - `ChatPage`: Displays safety fingerprint verification dialog, key mismatch alerts, blocked contact banner, and disables message input when blocked.
    - `HomePage`: Features a dedicated blocked contacts management bottom sheet (`Icons.block`) allowing review and unblocking.
  - **Protocol Fuzzing & Resilience (`test/unit/protocol/protocol_fuzz_test.dart`)**:
    - A dedicated fuzzing suite tests mutated, truncated, corrupted, and oversized binary frames across `OfflinkPacketDecoder`, handshake payloads, location payloads, group payloads, and `MeshPacketRouter`.
    - Zero crashes, unhandled exceptions, or denial-of-service conditions confirmed across corrupted payloads.
- **Status**: Implemented in Module 11 (`feature/security-hardening-abuse-controls`).

---

## DECISION-014: RFC 4122 v4 Standard BLE UUIDs, Resilient GATT Discovery Retry Loop, and Separation of Hardware Platform Name from Peer Identity
- **Context**: Real device testing on Android hardware (e.g. Motorola Edge 50 Pro) identified two critical bugs in peer-to-peer connectivity:
  1. BLE Connection Failure: Central devices encountered `Unable to connect: Bad state: Offlink BLE service was not found.`
  2. Peer Identity Display: Nearby discovered peers were displayed using the Android OS hardware model (`motorola` or `Motorola Edge 50 Pro`) rather than the user's configured Offlink username.
- **Root Cause & Architectural Impact**:
  - Nil UUID Android GATT Server Rejection: `OfflinkBleService` used `00000000-0000-0000-0000-000000000000`. Android's native Bluetooth stack (`BluetoothGattServer.addService()`) rejects nil UUIDs as invalid, causing peripheral GATT service registration to silently fail while advertising broadcasts continued.
  - Peripheral GATT Registration Race Condition: Peripheral advertising started synchronously while GATT services registered asynchronously. Fast-connecting Centrals invoked service discovery before GATT registration finished.
  - Disparate UUID String Formatting: `service.uuid.toString()` in Flutter Blue Plus produced differing string representations across platforms and short forms.
  - Conflation of Hardware Platform Name with User Identity: Centrals fell back to `result.device.platformName` (the Android OS Bluetooth name) when advertising local names were absent. Configured Offlink usernames were not transmitted during scan responses or cryptographic handshakes.
- **Decision**:
  - RFC 4122 v4 Standard UUIDs (`OfflinkBleService`):
    - Service UUID: `0f110001-4000-4000-8000-000000000000`
    - Control Characteristic UUID: `0f110002-4000-4000-8000-000000000000`
    - TX Characteristic UUID: `0f110003-4000-4000-8000-000000000000`
    - RX Characteristic UUID: `0f110004-4000-4000-8000-000000000000`
    - Manufacturer ID: `0x0F11`
  - Canonical UUID Normalization:
    - Normalizes UUID comparisons (`str128.toLowerCase()`) stripped of hyphenation, guaranteeing reliable matching regardless of 16-bit, 32-bit, or 128-bit formatting.
  - Resilient GATT Discovery Retry Loop (`BlePacketChannel`):
    - Discovers services with up to 3 attempts, applying progressive exponential delay (`150ms * attempt`) and invoking `clearGattCache()` on Android on retry to eliminate race conditions with peripheral GATT registration.
    - Throws strongly-typed `OfflinkBleServiceNotFoundException` with actionable context.
  - Three-Tier Peer Identity Hierarchy (`BlePeer`):
    - `username`: Cryptographically or scan-advertised Offlink username.
    - `deviceModel`: Physical hardware name (`result.device.platformName`).
    - `displayName`: Evaluated strictly as `username ?? advertisedUsername ?? 'Offlink User'`, never displaying the hardware model as the user's name.
  - Two-Stage Out-of-Band Username Exchange:
    - Stage 1 (Scan Response): `FlutterBleAdvertiser` broadcasts the UTF-8 encoded Offlink username in `AndroidAdvertiseSettings.advertiseResponseData` using manufacturer ID `0x0F11`. Centrals extract this during scanning without connecting.
    - Stage 2 (E2EE Handshake): `HandshakeInitPayload` and `HandshakeResponsePayload` carry `senderUsername`. Upon completion of authenticated sessions, `DirectMessageService` persists verified usernames in `ConversationRepository` and emits `peerIdentityUpdates` to dynamically update UI tiles.
- **Status**: Implemented in Bug Fix (`bugfix/ble-service-discovery-peer-identity`).


