# Offlink Verification Plan

## Principle

A phase is complete only when its acceptance criteria pass.

## Phase 0

- [x] Product scope defined.
- [x] Architecture documented.
- [x] Security direction documented.
- [x] Privacy baseline documented.
- [x] Battery strategy documented.
- [x] Data map documented.
- [x] Failure model documented.
- [ ] Protocol wire format frozen.
- [ ] Threat model reviewed.
- [ ] Test vectors created.
- [ ] GitHub branch protection configured.
- [ ] CI passing on a real PR.

## Phase 1

- [ ] Flutter project builds.
- [ ] analyze passes.
- [ ] tests pass.
- [ ] onboarding persists identity.
- [ ] secure key storage works.

## Phase 2

- [ ] Two physical Android devices discover each other.
- [ ] Bluetooth permissions handled.
- [ ] Offlink identity shown.
- [ ] No sensitive advertisement data.
- [ ] Peer list deduplicates.

## Phase 3

- [ ] Direct encrypted message.
- [ ] Authentication failures rejected.
- [ ] ACK.
- [ ] Offline queue.
- [ ] Restart recovery.

## Phase 4

- [ ] Three-node forwarding.
- [ ] Relay cannot decrypt.
- [ ] TTL.
- [ ] Deduplication.
- [ ] Expiry.
- [ ] Bounded retries.

## Phase 5

- [ ] Group membership.
- [ ] Group key management.
- [ ] Removal/key rotation.

## Phase 6

- [ ] One-time location.
- [ ] Permission only after user action.
- [ ] Encrypted location payload.
- [ ] No default location history.

## Phase 7

- [ ] ESP32 relay.
- [ ] Protocol compatibility.
- [ ] Malformed packet safety.

## Release

- [ ] Security review.
- [ ] dependency review.
- [ ] privacy review.
- [ ] battery measurements.
- [ ] physical-device regression.
- [ ] release build.
