# Open-Source Licensing Analysis & Options — Offlink

This document evaluates suitable open-source licensing models for the Offlink project. In accordance with project governance rules, no license is unilaterally applied until the maintainer formally approves the choice.

---

## 1. Project Context & Considerations

Offlink is an offline-first, decentralized peer-to-peer messaging application using Bluetooth Low Energy (BLE) and ad-hoc mesh networking. Key licensing considerations include:

1. **Decentralized Network Protection**: Ensuring that commercial entities or proprietary forks cannot build proprietary closed-source relays or modified clients that undermine user privacy or lock users into walled gardens.
2. **F-Droid Distribution**: Any selected license must be recognized as Free/Libre and Open Source Software (FLOSS) by the Free Software Foundation (FSF) and Open Source Initiative (OSI), which is mandatory for F-Droid inclusion.
3. **Patent Protections & Cryptographic Freedom**: Ensuring protection against patent trolling relating to mesh routing or cryptographic implementations.
4. **Third-Party Dependency Compatibility**: Offlink's current dependencies (`flutter`, `drift`, `flutter_blue_plus`, `cryptography`, `riverpod`) are licensed under permissive terms (MIT, BSD-3-Clause, Apache-2.0), which are compatible with both copyleft and permissive licenses.

---

## 2. Licensing Options Evaluated

### Option A: GNU General Public License v3.0 (GPL-3.0) — *Strong Copyleft (Recommended for P2P Commons)*
- **Summary**: Anyone who modifies and distributes Offlink (or a derived client) must make the complete source code available under GPL-3.0.
- **Advantages**:
  - Prevents closed-source proprietary forks from piggybacking on the mesh protocol.
  - Enforces community reciprocation: if hardware vendors (e.g., disaster relief equipment manufacturers) ship Offlink, their improvements must be shared.
  - Strong patent protection (Section 11 explicitly grants patent licenses).
  - 100% compatible with F-Droid.
- **Trade-offs**: Proprietary proprietary integration is disallowed (e.g., closed-source proprietary SDKs cannot link directly with Offlink code).

### Option B: GNU Affero General Public License v3.0 (AGPL-3.0) — *Network Copyleft*
- **Summary**: Extends GPL-3.0 to cover network-hosted services.
- **Relevance to Offlink**: Because Offlink has **zero central servers** and operates strictly peer-to-peer on device, standard GPL-3.0 is typically sufficient and avoids potential confusion regarding server-side triggers.

### Option C: Apache License 2.0 — *Permissive with Patent Protection*
- **Summary**: Allows anyone to modify, distribute, or incorporate Offlink code into closed-source or proprietary software, provided that notice and copyright are preserved.
- **Advantages**:
  - Maximum commercial flexibility for enterprise adoption.
  - Explicit patent grant protects contributors and users from patent litigation.
  - Highly popular across Flutter and Android ecosystems.
- **Trade-offs**: A third-party company could build a closed-source modified version of Offlink with proprietary features or surveillance telemetry without contributing source back.

### Option D: MIT License — *Maximum Permissive Simplicity*
- **Summary**: Extremely short, highly permissive license allowing anyone to do anything with the code as long as the copyright notice is retained.
- **Trade-offs**: Does not include explicit patent grants or copyleft reciprocity.

---

## 3. Recommendation & Next Steps

| License | Copyleft | Patent Grant | Commercial Protection | F-Droid Ready | Recommended |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **GPL-3.0** | Strong | Yes (Explicit) | High (Prevents closed forks) | Yes | **Primary Recommendation** |
| **Apache-2.0** | Permissive | Yes (Explicit) | Moderate (Permits closed forks) | Yes | Secondary Option |
| **MIT** | Permissive | No | Low | Yes | Basic Option |

### Maintainer Action Required
When ready, the maintainer can approve the preferred license (e.g., GPL-3.0). Once approved, a `LICENSE` file and corresponding SPDX headers will be generated and committed. Until approval, all existing source code files remain protected under standard copyright.
