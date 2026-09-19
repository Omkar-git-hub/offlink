# Offlink Test Matrix

## Unit

- Node ID generation
- packet encoding/decoding
- TTL
- expiry
- deduplication
- retry/backoff
- message state transitions
- crypto wrappers
- repository logic
- database migrations

## Security

- altered ciphertext rejected
- altered signature rejected
- replay rejected
- expired packet rejected
- wrong recipient rejected
- nonce misuse tests
- malformed packet rejected
- oversized packet rejected
- flooding limits
- private key never logged

## BLE

- Bluetooth off
- permission denied
- scan
- advertise
- connect
- disconnect
- reconnect
- service discovery
- characteristic read/write/notify
- MTU/fragmentation
- simultaneous peers

## Mesh physical tests

A <-> B
A -> B -> C
A -> B -> C -> D
A -> B and A -> C
Peer disappears during delivery
Relay disappears and another route becomes available
Duplicate packet
Expired packet

## Location

- permission not requested at startup
- permission denied
- approximate location
- precise location
- one-time location encrypted
- recipient decrypts
- no location history created

## Battery

- idle
- discovery
- active chat
- forwarding
- repeated failed delivery
- low battery
- charging

Record physical device and OS details.

## Regression

Every bug that reaches development must get a regression test where practical.
