# Automated CI/CD & Continuous Release Pipeline — Offlink

This document provides the definitive guide to the automated CI/CD and release distribution architecture for Offlink.

---

## 1. Design Philosophy: Zero Routine Maintenance

Offlink is designed so that **the maintainer's only routine manual action is reviewing and merging Pull Requests**.

Once a Pull Request is approved and merged into `main`, GitHub Actions automation autonomously handles:
1. Version increment determination based on PR labels and git tags.
2. Generating Keep-a-Changelog compliant release notes from commit history.
3. Updating `pubspec.yaml` and `CHANGELOG.md`.
4. Injecting production signing credentials (with safe debug fallback).
5. Compiling the production Android APK (`Offlink-<version>.apk`).
6. Cryptographically verifying the APK (SHA-256 calculation, package ID, version codes).
7. Tagging the source repository (`v<version>`).
8. Publishing a GitHub Release on the source repository ([`Omkar-git-hub/offlink`](https://github.com/Omkar-git-hub/offlink)).
9. Synchronizing metadata, changelog, and release matrices to the official distribution repository ([`Omkar-git-hub/offlink-releases`](https://github.com/Omkar-git-hub/offlink-releases)).
10. Publishing the official GitHub Release and binary assets to the distribution repository.

---

## 2. Dual-Repository Architecture

```
                    ┌────────────────────────────┐
                    │    Developer / PR Author   │
                    └─────────────┬──────────────┘
                                  │ Opens PR
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│ Main Source Repository: Omkar-git-hub/offlink                    │
├──────────────────────────────────────────────────────────────────┤
│ 1. .github/workflows/ci.yml:                                     │
│    - Gitleaks secret detection                                   │
│    - flutter pub outdated & dependency check                     │
│    - dart format & flutter analyze                               │
│    - 324+ Unit, widget, and protocol fuzzing tests               │
│    - Release APK compilation & verify_release_apk.dart check     │
│                                                                  │
│ 2. Maintainer Reviews & Merges PR to 'main'                      │
│                                                                  │
│ 3. .github/workflows/release.yml:                                │
│    - Version Calculator (tool/release/version_calculator.dart)   │
│    - Release Notes (tool/release/release_notes_generator.dart)   │
│    - Release Keystore Injection & Secure Cleanup                 │
│    - Build Offlink-<version>.apk & SHA256SUMS.txt                │
│    - Verify APK (tool/release/verify_release_apk.dart)           │
│    - Tag & Release on Omkar-git-hub/offlink                      │
└─────────────────────────────────┬────────────────────────────────┘
                                  │ Push metadata & Assets
                                  │ (using RELEASE_TOKEN)
                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│ Public Distribution Repository: Omkar-git-hub/offlink-releases   │
├──────────────────────────────────────────────────────────────────┤
│ - Synchronized metadata/release-information.json                 │
│ - Synchronized metadata/app-information.json                     │
│ - Synchronized CHANGELOG.md and RELEASES.md                      │
│ - Official GitHub Release with:                                  │
│     * Offlink-<version>.apk                                      │
│     * SHA256SUMS.txt                                             │
└──────────────────────────────────────────────────────────────────┘
```

---

## 3. Versioning Strategy & Pull Request Labels

Offlink follows Semantic Versioning 2.0.0 (`MAJOR.MINOR.PATCH-CHANNEL.ITERATION`).

When opening or reviewing a Pull Request, apply **optional labels** to control how the version increments upon merge:

| Pull Request Label | Target Release Impact | Example (from `0.1.0-alpha.1`) |
| :--- | :--- | :--- |
| *(None / Default)* | Increments pre-release iteration or patch | `0.1.0-alpha.2` |
| `release:alpha` | Ensures alpha track & increments iteration | `0.1.0-alpha.2` |
| `release:beta` | Transitions to beta track | `0.1.0-beta.1` |
| `release:patch` | Increments patch version | `0.1.1-alpha.1` |
| `release:minor` | Increments minor version | `0.2.0-alpha.1` |
| `release:major` | Increments major version | `1.0.0-alpha.1` |
| `release:stable` | Promotes pre-release to General Availability | `0.1.0` |

### Collision Avoidance
The `version_calculator.dart` utility automatically queries existing Git tags. If a calculated tag already exists, it monotonically advances the pre-release iteration or patch until an unused tag is found, preventing pipeline collisions.

---

## 4. One-Time Setup: Keystore & GitHub Secrets

To enable production APK signing and cross-repository release publishing, configure the following secrets once in GitHub:

### A. Android Release Keystore Generation
Generate a dedicated 2048-bit RSA signing key using Java `keytool`:

```bash
keytool -genkeypair -v \
  -keystore offlink-release.jks \
  -alias offlink \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass "<STRONG_KEYSTORE_PASSWORD>" \
  -keypass "<STRONG_KEY_PASSWORD>" \
  -dname "CN=Offlink Production, O=Offlink Mesh, C=US"
```

Convert the keystore to base64:
- **PowerShell (Windows)**:
  ```powershell
  [Convert]::ToBase64String([IO.File]::ReadAllBytes('offlink-release.jks')) | Set-Clipboard
  ```
- **Bash (Linux/macOS)**:
  ```bash
  base64 -w 0 offlink-release.jks
  ```

### B. Personal Access Token (`RELEASE_TOKEN`)
1. In GitHub, navigate to **Settings** > **Developer Settings** > **Personal Access Tokens** (Fine-grained or Classic).
2. Create a token named `OFFLINK_RELEASE_TOKEN` with:
   - Repository access to: `Omkar-git-hub/offlink` and `Omkar-git-hub/offlink-releases`.
   - Permissions: `Contents: Read and write`.

### C. Configure Repository Secrets
In [`Omkar-git-hub/offlink`](https://github.com/Omkar-git-hub/offlink) > **Settings** > **Secrets and variables** > **Actions**, add:

| Secret Name | Description | Required / Fallback |
| :--- | :--- | :--- |
| `RELEASE_TOKEN` | GitHub PAT with write access to `offlink-releases` | Required for distribution repo sync |
| `OFFLINK_KEYSTORE_BASE64` | Base64-encoded string of `offlink-release.jks` | Falls back to debug signing if omitted |
| `OFFLINK_KEYSTORE_PASSWORD` | Keystore password | Falls back to debug signing if omitted |
| `OFFLINK_KEY_ALIAS` | Key alias (`offlink`) | Falls back to debug signing if omitted |
| `OFFLINK_KEY_PASSWORD` | Key password | Falls back to debug signing if omitted |

> [!NOTE]
> If keystore secrets are not yet configured, the release pipeline will build the release APK using the debug signing certificate and log an action warning. This guarantees builds never fail due to missing secrets during development.

---

## 5. Pure Dart Release Tooling Reference

All automation logic is implemented in self-contained Dart scripts located in `tool/release/`. These run identically on developer workstations, CI runners, and test suites with zero external dependencies.

### 1. `version_calculator.dart`
- Evaluates Git tags and PR labels.
- Calculates next `version`, `tag`, `version_code`, `channel`, and `is_prerelease`.
- Supports updating `pubspec.yaml` in-place.
- Writes outputs to `$GITHUB_OUTPUT`.

### 2. `release_notes_generator.dart`
- Parses git commit history between the previous release tag and `HEAD`.
- Automatically categorizes commits into standard sections:
  - Breaking Changes
  - Added / Features
  - Fixed / Bug Fixes
  - Security & Privacy
  - Performance & Optimization
  - Maintenance & Internal
- Prepends notes to `CHANGELOG.md`.

### 3. `verify_release_apk.dart`
- Computes SHA-256 checksum and writes `SHA256SUMS.txt`.
- Verifies the APK's package identity (`io.github.omkar_git_hub.offlink`).
- Verifies version name and version code match expectations using `aapt`.
- Verifies APK signature scheme and integrity using `apksigner`.

### 4. `publish_release.dart`
- Integrates with GitHub CLI (`gh release create`).
- Verifies idempotency (skips duplicate release creation if already published).
- Attaches `Offlink-<version>.apk` and `SHA256SUMS.txt`.
- Supports dry-run verification mode.

### 5. `sync_distribution_repo.dart`
- Updates `metadata/release-information.json` with new file sizes, hashes, and download links.
- Confirms production application identity in `metadata/app-information.json`.
- Prepends new release notes to `CHANGELOG.md` in `offlink-releases`.
- Appends release matrix entries to `RELEASES.md` in `offlink-releases`.

---

## 6. Security Guarantees & Safeguards

1. **Ephemeral Secrets**: The base64 keystore is decoded into the runner's temporary directory (`${{ runner.temp }}/release.jks`), used exclusively during the Gradle task, and deleted in the `always()` post-build hook.
2. **Secret Scanning**: `gitleaks-action` runs on every pull request and push to prevent accidental credential leakage into Git history.
3. **Application Identity**: The application package ID is permanently anchored to `io.github.omkar_git_hub.offlink`, fulfilling F-Droid inclusion requirements and preventing clashes with placeholder IDs.
4. **Reproducible Integrity**: Every release binary is accompanied by an authoritative `SHA256SUMS.txt` allowing independent client-side verification before installation.
