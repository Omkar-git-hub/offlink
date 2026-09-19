# Contributing to Offlink

## Workflow

1. Create an issue or clearly describe the work.
2. Create a feature/fix branch.
3. Implement the smallest change.
4. Add tests.
5. Update documentation.
6. Run local checks.
7. Open a PR to `main`.
8. Wait for GitHub Actions.
9. Obtain review.
10. Merge only when required checks pass.

## PR requirements

A PR should include:
- purpose
- scope
- test evidence
- documentation changes
- security/privacy impact
- battery impact if BLE/background behavior changes

## Protocol/security changes

Any change to:
- packet fields
- crypto
- key handling
- identity
- BLE advertisements
- routing
- location handling

must update the relevant design documents and tests.

## Style

Prefer:
- small classes
- explicit interfaces
- dependency inversion
- immutable domain data where practical
- descriptive names
- testable pure logic

Avoid:
- giant services
- UI-driven business logic
- global mutable state
- unnecessary dependencies
