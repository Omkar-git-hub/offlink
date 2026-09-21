# Offlink Protocol Foundation

## Purpose

This document defines the initial foundation of the Offlink application
protocol.

The current implementation is intentionally minimal. It establishes the
logical packet structure and basic validation before encryption, BLE packet
transport, and mesh routing are introduced.

---

## Current Scope

The protocol foundation currently defines:

- Protocol version
- Message ID
- Sender Node ID
- Recipient Node ID
- Message type
- Timestamp
- TTL / hop limit
- Payload
- JSON serialization
- JSON deserialization
- Basic packet validation

---

## Packet Structure

An Offlink packet currently contains:

| Field | Type | Purpose |
|---|---|---|
| `version` | integer | Identifies the protocol version |
| `messageId` | string | Uniquely identifies the message |
| `senderNodeId` | string | Identifies the original sender |
| `recipientNodeId` | string | Identifies the intended recipient |
| `messageType` | string | Identifies the logical message type |
| `timestamp` | ISO-8601 string | Records packet creation time |
| `ttl` | integer | Limits forwarding/hop count |
| `payload` | string | Carries the current application payload |

---

## Supported Message Types

The current implementation supports:

### `text`

Used for a normal text message.

### `ack`

Used as the foundation for acknowledgement messages.

Additional message types must be added deliberately and covered by tests.

---

## Protocol Version

The current protocol version is:

```text
1