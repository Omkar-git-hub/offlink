# Offlink BLE Design

## Role model

A phone may need to act as:
- BLE central/scanner
- BLE peripheral/advertiser

This is why both sides of the BLE stack are part of the architecture.

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
  -> Service discovery
  -> Protocol handshake
  -> Secure session
  -> Batch synchronization
  -> ACK
  -> Disconnect
  -> Backoff/idle
```

## GATT design

Initial logical service:

```text
Offlink Service
  |
  +-- Control characteristic
  |     handshake / capabilities / control
  |
  +-- TX characteristic
  |     node -> peer packets
  |
  +-- RX characteristic
        peer -> node packets
```

The exact UUIDs, properties, MTU strategy, packet framing and fragmentation rules must be frozen in the protocol review before implementation.

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
- Android A
- Android B
- Android C

Later:
- Android + ESP32
- iOS + Android
