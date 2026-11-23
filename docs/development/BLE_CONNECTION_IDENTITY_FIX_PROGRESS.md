# BLE Connection Failure & Incorrect Peer Identity Fix — Progress Checkpoint

## Task Metadata
- **Branch**: `bugfix/ble-service-discovery-peer-identity`
- **Target**: `main`
- **Date Started**: 2026-11-23
- **Baseline Test Count**: 352/352 passed

## Problem Statement
Real device testing between two Android devices (Motorola Edge 50 Pro) identified two issues:
1. **BLE Connection Failure**: `Unable to connect to motorola edge 50 pro: Bad state: Offlink BLE service was not found.`
2. **Incorrect Peer Display Name**: The discovered peer is displayed using the Android device manufacturer/model name (`motorola` or `Motorola Edge 50 Pro`) instead of the user's configured Offlink username.

## Root Cause Analysis Summary
1. **Nil UUID Rejection**: `OfflinkBleService` used `00000000-0000-0000-0000-000000000000`. The Android Bluetooth GATT server (`BluetoothGattServer.addService`) returns false / rejects nil UUIDs. While BLE advertising packet broadcast succeeded, the GATT service was not added to the peripheral's GATT database.
2. **Asynchronous GATT Setup Race Condition**: `startAdvertising` runs before asynchronous `addService` finishes. A fast scanning Central connects and calls `discoverServices()` before the peripheral finishes GATT registration.
3. **Guid String Representation Sensitivity**: `service.uuid.toString()` compares varied string formats (16-bit, 32-bit, 128-bit) without canonical normalization.
4. **Device Model Substituted for Username**: `PhoneBleDiscovery` fell back to `result.device.platformName` (the Android OS Bluetooth device name), conflating hardware platform model with user identity.
5. **No Username Advertising or Handshake Exchange**: Neither scan responses nor cryptographic handshakes transmitted configured Offlink usernames.

## Execution Checklist
- [x] Phase 0: Root cause investigation & baseline verification (352/352 tests pass).
- [x] Phase 1: Core BLE specification update (RFC 4122 v4 UUIDs & canonical normalization).
- [x] Phase 2: Resilient service discovery with retry & backoff in `BlePacketChannel`.
- [x] Phase 3: Peer model refinement (`deviceModel` vs `displayName` vs `username`).
- [x] Phase 4: Offlink username advertising in scan response data.
- [x] Phase 5: Cryptographic handshake username exchange in `DirectMessageService`.
- [x] Phase 6: UI updates on `HomePage` (display hierarchy & dynamic name updates).
- [x] Phase 7: Regression unit & widget tests (356/356 tests pass).
- [x] Phase 8: Verification (`dart format` clean, `flutter analyze` 0 issues, `flutter test` 356/356 passed, `flutter build apk --debug` succeeded).
- [x] Phase 9: Documentation updates (`docs/architecture/BLE.md`, `AI_PROGRESS.md`, `AI_DECISIONS.md`).
- [x] Phase 10: Git commit, push, and PR creation targeting `main` (PR #24 created, GitHub Actions CI passed).


