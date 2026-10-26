# Offlink BLE Design

## Role model

A phone may need to act as:
- BLE central/scanner
- BLE peripheral/advertiser

Because two mobile devices can connect in either role, `BlePacketTransport` coordinates both:
1. **Central Role (`BlePacketChannel`)**:
   - Initiates connection via `flutter_blue_plus`.
   - Requests 512-byte ATT MTU on connection to support single-PDU JSON packet transmission.
   - Discovers `OfflinkBleService.serviceUuid`.
   - Subscribes to `txCharacteristicUuid` notifications for incoming packets from the peripheral.
   - Writes outgoing packets to `rxCharacteristicUuid` (with write response).
2. **Peripheral Role (`BlePeripheralPacketChannel`)**:
   - Advertises `OfflinkBleService.serviceUuid` via `flutter_ble_peripheral`.
   - Hosts GATT service with `txCharacteristicUuid` (notify) and `rxCharacteristicUuid` (write).
   - Receives incoming packets written to RX characteristic via `onDataReceived`.
   - Sends outgoing packets to the connected central by notifying on `txCharacteristicUuid`.
3. **Unified Stream**:
   - Incoming packets across both Central and Peripheral channels are decoded via `PacketCodec` and multiplexed into a single `incomingPackets` stream on `PacketTransport`.
   - Malformed or invalid packets are caught and safely ignored without disrupting the stream or connection.

## Discovery

Advertisements should contain only the minimum public discovery information required.

Do not advertise:
- message content
- location
- phone number
- email
- private key
- conversation data
- unnecessary stable personal identifiers

The final advertisement design should consider passive tracking risk.

## Connection lifecycle

```text
Idle
  -> Discovery window
  -> Peer found
  -> Connect
  -> MTU negotiation (request 512 bytes)
  -> Service discovery
  -> Subscribe to TX notifications
  -> Bidirectional packet exchange
  -> Disconnect
  -> Backoff/idle
```

## GATT design

Logical service:

```text
Offlink Service (00000000-0000-0000-0000-000000000000)
  |
  +-- Control characteristic (00000000-0000-0000-0000-000000000001)
  |     handshake / capabilities / control
  |
  +-- TX characteristic (00000000-0000-0000-0000-000000000002)
  |     peripheral -> central notifications
  |
  +-- RX characteristic (00000000-0000-0000-0000-000000000003)
        central -> peripheral writes
```

## Battery rules

- Avoid continuous low-latency scanning.
- Prefer low-power/balanced scanning based on state.
- Use short discovery windows.
- Batch packet exchange.
- Disconnect after synchronization.
- Back off when no useful peer is found.
- Avoid reconnect loops.

## Background limitations

Android and iOS manage background execution differently. We must test actual behavior on physical devices and must not promise always-on mesh behavior without platform-specific evidence.

## Physical testing

At minimum:
- Android A ↔ Android B (bidirectional verification)
- Android A ↔ Android B ↔ Android C (mesh forwarding in Module 7)
