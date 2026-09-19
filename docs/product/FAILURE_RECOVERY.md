# Failure and Recovery

Offlink must assume devices disappear.

## Cases

- Bluetooth disabled.
- Permission denied.
- Peer disappears.
- App is backgrounded/killed.
- Device reboots.
- Battery becomes low.
- Storage becomes full.
- Database migration fails.
- Packet is malformed.
- Packet is duplicated.
- Packet expires.
- Peer uses incompatible protocol.
- Encryption/authentication fails.

## Principles

- Never crash because a peer sent malformed data.
- Never retry forever.
- Never block the UI on BLE/network-style operations.
- Preserve queued messages across normal app restarts.
- Expire invalid/stale data.
- Surface useful user-facing errors without leaking sensitive details.
