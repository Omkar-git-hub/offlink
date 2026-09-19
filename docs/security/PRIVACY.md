# Offlink Privacy Design

This is an engineering privacy baseline, not legal advice.

## Core principle

Collect, expose, store, and transmit only what the feature requires.

## Core MVP does not require

- phone number
- email
- account login
- contact list
- cloud account
- advertising ID
- analytics identifier

## Username

A user-selected display name may be shared with a peer after the discovery/handshake flow.

## Location

One-time location:
- only after user action
- permission requested in context
- encrypted before transmission
- no continuous tracking
- no location history by default

## BLE metadata

Advertisements are visible to nearby radios. Do not put private message content, location, phone number, email, or private keys into advertisements.

## Privacy by design

The app should:
- minimize permissions
- minimize retention
- minimize metadata
- provide deletion controls
- avoid analytics by default
- document all data flows

## India

The project will be reviewed against the applicable Indian data-protection requirements before public release. MeitY lists the Digital Personal Data Protection Rules, 2025 and related commencement material. The project must not claim legal compliance solely from this engineering document.
