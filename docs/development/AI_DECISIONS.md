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
