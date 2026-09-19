# Development Guide

## Prerequisites

- Flutter SDK compatible with the selected dependency versions.
- Android Studio/Android SDK.
- Git.
- Physical Android devices for BLE tests.

## Local checks

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
```

## Branch

```powershell
git checkout -b feature/<short-name>
```

## Commit examples

```text
docs: define BLE protocol
feat: add onboarding
feat: add BLE discovery
feat: add direct encrypted messaging
test: add mesh deduplication tests
fix: prevent duplicate forwarding
```

## Pull Request

1. Explain what changed.
2. Explain how it was tested.
3. Link issue if applicable.
4. Confirm no secrets or personal data were added.
5. Wait for required CI checks.
6. Request review.
7. Merge only after approval and green checks.

## Never

- commit private keys
- commit API secrets
- disable security checks to pass CI
- bypass main protection
- change protocol without updating documentation/tests
