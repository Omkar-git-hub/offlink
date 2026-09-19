# Offlink Retention Policy

## Principles

Retain data only as long as needed for the local feature.

## Suggested defaults

### Delivered messages
Retain according to the user's local chat history settings.

### Undelivered messages
Expire according to protocol-defined message expiry.

### Seen-message cache
Short-lived; only long enough to prevent replay/duplicate forwarding.

### Mesh queue
Delete after delivery or expiry.

### Peer discovery metadata
Expire stale peers after a bounded period.

### Location
No separate location history in MVP.

### Logs
No sensitive content. Rotate/limit diagnostic logs.

Exact numeric retention periods must be selected during protocol/product review and then tested.
