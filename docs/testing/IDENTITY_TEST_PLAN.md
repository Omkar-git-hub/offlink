
### 2. `docs/testing/IDENTITY_TEST_PLAN.md`

```markdown
# Identity Test Plan

## Purpose

Verify that Offlink identity is generated correctly, stored securely, and remains stable across application restarts.

## Test Categories

### 1. First-Time Identity Creation

Verify that a new installation creates:

- Username
- Node ID
- Ed25519 public key
- Ed25519 private key
- Creation timestamp

Expected result:

All required identity components are generated successfully.

### 2. Node ID Stability

Create an identity and restart the application.

Expected result:

The Node ID remains unchanged.

### 3. Key Stability

Create an identity and restart the application.

Expected result:

The Ed25519 public/private key pair remains unchanged.

### 4. Username Independence

Create an identity with:

`Omkar`

Change the username to another valid username.

Expected result:

- Username changes.
- Node ID remains unchanged.
- Public key remains unchanged.
- Private key remains unchanged.

### 5. Private Key Storage

Verify that the private key is not stored as plaintext in SQLite.

Expected result:

The database contains no plaintext private key.

### 6. Private Key Logging

Run the application with logging enabled.

Expected result:

The private key never appears in application logs.

### 7. Identity Persistence

Close the application completely and start it again.

Expected result:

The previously created identity is loaded.

A new Node ID or key pair must not be generated.

### 8. Clean Installation

Remove application data and perform a new installation/setup.

Expected result:

A new identity is generated.

### 9. Invalid/Missing Identity Data

Simulate missing or corrupted identity metadata.

Expected result:

The application handles the condition safely without exposing private key material.

### 10. Concurrent Initialization

Attempt identity initialization from multiple application startup paths.

Expected result:

Only one valid local identity is created.

## Security Verification

Verify:

- No private key in logs
- No private key in SQLite
- No private key in BLE advertisement data
- No private key transmitted to peers
- Node ID is not derived from username
- Node ID is not derived from device hardware identifiers

## Phase 1 Acceptance Criteria

Phase 1 is complete when:

- [ ] User can complete onboarding
- [ ] Username is validated
- [ ] Node ID is generated
- [ ] Ed25519 key pair is generated
- [ ] Private key uses secure storage
- [ ] Public identity metadata is persisted
- [ ] Identity survives application restart
- [ ] Username changes do not change cryptographic identity
- [ ] Unit tests pass
- [ ] Flutter analyzer passes
- [ ] Android debug APK builds successfully