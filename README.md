# Offlink

**Offline-first, privacy-first peer-to-peer messaging over Bluetooth Low Energy (BLE).**

Offlink is designed to exchange messages without relying on the internet, a SIM card, a mobile network, or a central messaging server.

## Current status

**Phase 0 — Architecture + verification foundation**

The repository intentionally starts with documentation and CI rules before implementing BLE messaging.

## Product principles

- Offline by default for core messaging.
- BLE-based application-level store-and-forward mesh.
- End-to-end encrypted message content.
- Relay nodes forward ciphertext; they do not need plaintext.
- Optional one-time location sharing.
- Low battery consumption is a first-class requirement.
- Minimal collection and local-first storage of personal data.
- Android-first MVP; iOS and ESP32 follow after the protocol is stable.
- Simple architecture with clear interfaces and Open/Closed Principle.
- Every phase has a verification gate.

## Planned topology

```text
Phone A <-> Phone B <-> Phone C
                    ^
                    |
                  ESP32
```

A message can travel through multiple nodes while its content remains encrypted.

## Repository rules

- Do not push directly to `main`.
- Work on a feature branch.
- Open a Pull Request.
- Required GitHub Actions checks must pass.
- Human review is required before merging protocol/security changes.
- Never commit secrets, private keys, real user data, or credentials.

## Documentation map

- `BRAIN.md` — AI/project context and non-negotiable rules.
- `ARCHITECTURE.md` — system structure and boundaries.
- `PROTOCOL.md` — packet and transport protocol.
- `SECURITY.md` — security model and controls.
- `THREAT_MODEL.md` — threats and mitigations.
- `BLE.md` — BLE/GATT design.
- `BATTERY.md` — power strategy and measurement.
- `DATABASE.md` — local data model.
- `PRIVACY.md` — privacy engineering baseline.
- `DATA_MAP.md` — what data exists, where it lives, and why.
- `RETENTION.md` — retention/deletion rules.
- `VERIFICATION.md` — phase acceptance criteria.
- `TEST_MATRIX.md` — test scenarios.
- `ROADMAP.md` — implementation phases.
- `DEVELOPMENT.md` — local development.
- `CONTRIBUTING.md` — contribution and PR rules.
- `docs/DECISIONS.md` — architecture decisions.
- `docs/SOURCES.md` — verified external sources.

## License

License decision is intentionally pending until the project owner chooses the desired open-source terms.
