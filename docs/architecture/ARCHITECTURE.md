# Offlink Architecture

## Goals

- Simple enough for a small team.
- Testable.
- Offline-first.
- Extensible to ESP32.
- Low battery.
- Clear security boundaries.

## High-level flow

```text
Flutter UI
   |
State Management
   |
Domain Services
   |
+--+------------------+
|  |        |         |
Chat Mesh  Identity Location
|    |       |         |
+----+-------+---------+
          |
      Interfaces
          |
+---------+------------------+
|            |               |
SQLite      Crypto          Transport
|            |               |
Drift       Secure        BLE phone
            storage        ESP32 later
```

## Directory structure

```text
lib/
  app/
  core/
  crypto/
  data/
  domain/
  bluetooth/
  mesh/
  features/
    onboarding/
    discovery/
    chat/
    groups/
    location/
    profile/
    settings/
```

## Boundaries

### UI
Only presentation and user interaction.

### Domain
Business rules and interfaces.

### Data
SQLite/Drift implementations.

### Crypto
Identity, key agreement, encryption, verification.

### Bluetooth
BLE scanning, advertising, GATT, connection lifecycle.

### Mesh
Packet validation, queueing, deduplication, TTL, forwarding.

### Features
User-facing workflows.

## Open/Closed Principle

The mesh layer depends on:

```text
Transport
  start()
  stop()
  discover()
  connect()
  disconnect()
  send()
  incomingPackets
```

Implementations:
- PhoneBleTransport
- Esp32Transport

Adding a new transport must not require rewriting mesh routing.

## Dependency direction

Allowed:

```text
UI -> Domain
Domain -> Interfaces
Data -> Domain interfaces
BLE -> Transport interface
ESP32 -> Protocol
```

Avoid:

```text
UI -> SQLite directly
Mesh -> Flutter widget
Mesh -> concrete BLE plugin
Chat -> platform-specific Bluetooth API
```

## Concurrency

BLE events, queue processing, database writes, and encryption must not block the UI thread.

Use controlled async work and isolate expensive operations when measurement shows they are needed.
