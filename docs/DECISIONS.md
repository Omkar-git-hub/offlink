# Architecture Decision Records

## ADR-001 — Flutter
Use Flutter/Dart for the application UI and application layer.

## ADR-002 — Android first
Validate BLE behavior on physical Android devices before expanding platform scope.

## ADR-003 — Application-level mesh
Use store-and-forward at the Offlink protocol layer instead of full Bluetooth Mesh for the first phone MVP.

## ADR-004 — Username is not identity
Username is display metadata. Cryptographic identity is independent.

## ADR-005 — Local-first database
Use SQLite/Drift.

## ADR-006 — One-time location first
Avoid continuous location tracking until the core messaging system is stable.

## ADR-007 — Battery is a first-class requirement
Power behavior is designed and measured from the beginning.

## ADR-008 — Human approval for main
CI can block a PR automatically, but security/protocol changes should retain a human review gate.
