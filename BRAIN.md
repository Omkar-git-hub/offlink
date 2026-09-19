# OFFLINK — AI PROJECT BRAIN

## 1. Project identity

Name: Offlink
Meaning: Offline Link

Purpose:
Offline peer-to-peer messaging using Bluetooth Low Energy with application-level store-and-forward mesh routing.

Primary target:
Android first. Flutter/Dart.

## 2. Non-negotiable requirements

1. Core messaging must not require internet, SIM, mobile network, cloud, or a central server.
2. One Offlink installation has one local node identity in the MVP.
3. Username is display metadata, not a cryptographic identity.
4. Messages are end-to-end encrypted.
5. Relay nodes must not require plaintext.
6. BLE advertisements must not contain message plaintext, location, private keys, or unnecessary personal data.
7. Battery consumption must be actively controlled and measured.
8. Location is opt-in and one-time in the first release.
9. No continuous location tracking by default.
10. Do not collect unnecessary personal data.
11. Do not introduce cloud dependencies without an explicit architecture decision.
12. Do not change the wire protocol silently.
13. Do not store private keys in ordinary SQLite columns in plaintext.
14. Do not log plaintext messages, private keys, session keys, or precise location payloads.
15. Every implementation phase has a verification gate.

## 3. Identity

Display name:
- User-selected.
- Human-readable.
- Changeable.

Node ID:
- Random/cryptographic installation identifier.
- Stable for the installation in the MVP.
- Not derived only from username + timestamp.

Identity key:
- Ed25519 public/private key pair.
- Private key protected using platform secure storage.

Created timestamp:
- Metadata only.
- Never the security root.

## 4. Trust model

Discovery does not automatically mean permanent trust.

Conceptual states:
DISCOVERED -> IDENTIFIED -> SESSION_ESTABLISHED -> TRUSTED/KNOWN

MVP may establish encrypted sessions without a separate manual verification UI, but the protocol must leave room for identity verification later (for example, a safety code or QR comparison).

## 5. Crypto direction

Initial primitives:
- Ed25519 for identity signatures.
- X25519 for key agreement.
- AES-256-GCM for authenticated encryption.

These are engineering choices, not a claim that the resulting protocol is formally secure. Protocol design and implementation must be tested and reviewed before production release.

Nonce rule:
A nonce must never be reused with the same AEAD key.

## 6. Mesh

Use application-level store-and-forward, not full Bluetooth Mesh, for the first phone MVP.

Forwarding:
- Validate.
- Deduplicate.
- Check expiry.
- Apply TTL/hop limit.
- Store if required.
- Forward according to policy.
- Exponentially back off retries.

## 7. Battery

Battery efficiency is a core requirement.

Rules:
- No permanent aggressive BLE scanning while idle.
- Prefer low-power/batched discovery when possible.
- Use short connection windows.
- Batch queued messages per connection.
- Disconnect when exchange is complete.
- Back off failed retries.
- Avoid unnecessary database writes.
- Reduce background work when battery is low.
- Measure battery behavior on physical devices.

## 8. Location

MVP:
- User taps Share Location.
- Request location permission only when needed.
- Obtain one current location.
- Encrypt it as a normal message.
- Do not retain a location history by default.

Live location is a later feature with explicit duration and stop controls.

## 9. Architecture

UI
 -> state management
 -> domain services
 -> repository interfaces
 -> local data / transport / crypto adapters

The mesh domain must not know whether transport is a phone BLE adapter or an ESP32 relay.

## 10. AI development protocol

Before changing code:
1. Read this file.
2. Read the relevant document.
3. Identify the current phase.
4. Check the acceptance criteria.
5. Make the smallest safe change.
6. Add/update tests.
7. Run local checks.
8. Explain failures instead of bypassing them.
9. Update documentation if a decision changes.
10. Never weaken security or CI checks just to make a build green.

## 11. Current phase

Phase 0: architecture, CI foundation, protocol/security review.

Next gate:
Protocol + BLE + security + data model + battery strategy reviewed and accepted.
