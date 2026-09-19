# Offlink Threat Model

## Assets

1. Message plaintext.
2. Identity private keys.
3. Conversation/session keys.
4. Username/profile information.
5. Location information.
6. Local message database.
7. Delivery metadata.
8. Device availability/battery.

## Threats and controls

### Passive BLE observer
Risk:
Observes advertisements and radio traffic.

Controls:
- minimal advertisement data
- no plaintext
- ephemeral discovery design where practical
- encrypted payloads

### Malicious relay
Risk:
Reads or modifies relayed data.

Controls:
- end-to-end encryption
- authentication
- packet integrity
- relay does not receive plaintext keys

### Replay attacker
Risk:
Reinjects an old message.

Controls:
- message/packet IDs
- timestamps/expiry
- seen cache
- protocol replay rules

### Flooding attacker
Risk:
Consumes storage/battery.

Controls:
- packet size limits
- queue limits
- rate limits
- TTL
- connection timeouts
- malformed-packet rejection

### Compromised endpoint
Risk:
Local plaintext/keys exposed.

Controls:
- secure storage
- minimal local retention
- deletion controls
- no unnecessary logging

### Location misuse
Risk:
User accidentally shares precise location.

Controls:
- explicit action
- contextual permission request
- one-time sharing first
- approximate/precise choice where platform supports it
- no history by default

### Protocol downgrade
Risk:
New node is forced into a weaker version.

Controls:
- minimum supported version
- capability negotiation
- explicit rejection of unsupported/unsafe versions
