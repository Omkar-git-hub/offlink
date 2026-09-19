# Offlink Protocol — Draft v0

Status: design draft. Wire format is NOT frozen.

## Design goals

- Small enough for BLE.
- Versioned.
- Extensible.
- Secure.
- Deduplicatable.
- Mesh-friendly.
- ESP32 implementable.
- Battery-conscious.

## Packet envelope

Proposed logical fields:

- protocolVersion
- packetType
- packetId
- messageId (when applicable)
- sourceNodeId
- destinationNodeId
- createdAt
- expiresAt
- ttl
- flags
- payload/ciphertext
- authentication/signature fields

## Packet types

- HELLO
- HANDSHAKE
- SYNC_REQUEST
- SYNC_RESPONSE
- MESSAGE
- ACK
- DELIVERY_STATUS
- GROUP_CONTROL (future)
- ERROR

Location is initially a message subtype, not a special transport path.

## Required protocol decisions before implementation

- binary encoding
- UUIDs
- field widths
- maximum packet size
- fragmentation
- maximum message size
- timestamp encoding
- TTL limits
- expiry limits
- replay window
- ACK semantics
- capability negotiation
- protocol downgrade behavior
- authentication flow
- session key derivation
- key rotation
- error codes

## Mesh rules

1. Reject malformed packets.
2. Reject unsupported protocol versions safely.
3. Reject expired packets.
4. Deduplicate by packet/message ID.
5. Apply TTL/hop limit.
6. Do not forward packets past limits.
7. Bound queue storage.
8. Bound retry attempts.
9. Do not expose plaintext to relays.

## Versioning

Every packet must identify its protocol version/capabilities.

A newer node must fail safely when communicating with an older node.

## Protocol freeze gate

No interoperability-critical implementation until:
- byte encoding is frozen,
- crypto transcript is frozen,
- test vectors exist,
- limits are defined,
- replay rules are defined,
- ESP32 can implement the same logical protocol.
