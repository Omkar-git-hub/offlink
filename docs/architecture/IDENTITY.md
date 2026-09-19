# Offlink Identity

## Purpose

Offlink identity provides a stable identity for every Offlink installation.

The identity must remain stable across app restarts and must not depend on:

- Username
- Phone number
- Email
- Bluetooth device name
- Device MAC address
- Timestamp

## Identity Components

Each local Offlink installation has:

1. Username
2. Permanent Node ID
3. Ed25519 public key
4. Ed25519 private key
5. Creation timestamp

### Username

The username is a user-facing display name.

Example:

`Omkar`

The username is metadata and is not a security credential.

### Node ID

The Node ID uniquely identifies the Offlink installation.

Requirements:

- Generated randomly during first-time setup
- Stable across app restarts
- Never regenerated during normal app startup
- Must not contain personal information
- Must not be derived from username
- Must not be derived from device identifiers

The Node ID is used by the Offlink protocol to identify a node.

### Ed25519 Identity Key

Each installation generates an Ed25519 key pair:

- Private key
- Public key

The public key can be shared with peers.

The private key must remain on the local device.

The private key must never be stored as plaintext in the application database.

It must be stored using platform-secure storage.

## First-Time Initialization

On first application setup:

```text
User chooses username
        ↓
Generate random Node ID
        ↓
Generate Ed25519 key pair
        ↓
Store private key securely
        ↓
Store public identity metadata
        ↓
Identity initialized