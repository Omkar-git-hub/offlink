# Offlink Database

Technology: SQLite through Drift.

Drift is a reactive relational persistence library built on SQLite. The schema remains local to the installation.

## Tables

### local_identity
- node_id
- username
- identity_public_key
- created_at

Private key material is protected outside ordinary plaintext DB fields.

### peers
- node_id
- display_name
- public_key
- last_seen_at
- status
- signal_strength (optional)
- protocol_version

### conversations
- conversation_id
- type
- created_at
- updated_at

### conversation_members
- conversation_id
- node_id
- joined_at
- left_at (nullable)

### messages
- message_id
- conversation_id
- sender_id
- recipient_id
- message_type
- encrypted_payload
- created_at
- expires_at
- status
- ttl

### mesh_packets
- packet_id
- message_id
- next_hop_id
- attempts
- last_attempt_at
- expires_at

### seen_messages
- message_id
- first_seen_at
- expires_at

## Location

Location data is message content and is encrypted before transport.

Do not maintain a separate location-history table in the MVP.

## Retention

All transient mesh state must expire.
See `RETENTION.md`.

## Migration rule

Every schema change requires:
1. schema version change
2. migration
3. migration test
4. documentation update
