# Release Automation Progress & Checkpoint

## Objective
Establish a production-grade, fully automated CI/CD and release pipeline for Offlink such that the maintainer's **only routine manual action** is reviewing and merging Pull Requests. Upon PR merge to `main`, automation handles version calculation, tagging, building, signing, verification, checksum generation, release note drafting, and deployment to the official distribution repository ([Omkar-git-hub/offlink-releases](https://github.com/Omkar-git-hub/offlink-releases)).

---

## Current Architecture & Status Baseline

### Source Repository (`offlink`)
- **URL**: [https://github.com/Omkar-git-hub/offlink](https://github.com/Omkar-git-hub/offlink)
- **Branch**: `feature/automated-ci-cd-release-system` (branched from `main` at `c41b0df`)
- **Modules Present**: Modules 1 through 11 fully merged.
- **Test Suite**: 352/352 tests passing (100% pass rate: 324 core + 28 release automation tests).
- **Static Analysis**: 0 issues (`flutter analyze`).
- **Formatting**: 100% clean (`dart format`).
- **Android Configuration**:
  - `applicationId`: `io.github.omkar_git_hub.offlink` (migrated from placeholder `com.example.offlink`)
  - `namespace`: `io.github.omkar_git_hub.offlink`
  - `minSdk`: API 24 (Android 7.0)
  - `targetSdk`: API 36 (Android 16)
  - `compileSdk`: API 36
- **Signing Configuration**:
  - `release` signing config configured in `android/app/build.gradle.kts`. Reads environment variables (`OFFLINK_KEYSTORE_PATH`, etc.) with automatic fallback to debug keystore for development and PR verification.
- **Workflows**:
  - `.github/workflows/ci.yml`: Runs on PRs to `main` and pushes to `feature/**`. Validates secrets, dependencies, formatting, static analysis, unit tests, release APK build, and APK structure.
  - `.github/workflows/release.yml`: Runs on PR merges to `main`. Determines PR release labels, calculates next semantic version, extracts release notes, signs APK, verifies integrity, tags repository, publishes to `offlink`, and synchronizes metadata and releases to `offlink-releases`.

### Release / Distribution Repository (`offlink-releases`)
- **URL**: [https://github.com/Omkar-git-hub/offlink-releases](https://github.com/Omkar-git-hub/offlink-releases)
- **Branch**: `main`
- **Current Live Release**: `v0.1.0-alpha.1` with `Offlink-0.1.0-alpha.1.apk` and `SHA256SUMS.txt`.
- **Automated Synchronization**: Driven by `tool/release/sync_distribution_repo.dart` and `tool/release/publish_release.dart`.

---

## Phase Execution Roadmap

| Phase | Description | Status |
| :--- | :--- | :--- |
| **Phase 0** | Audit & Checkpoint Baseline | **Completed** |
| **Phase 1** | Release Foundations (App ID, Licensing Analysis, Semantic Versioning) | **Completed** |
| **Phase 2** | Production CI Workflow Hardening (`ci.yml`) | **Completed** |
| **Phase 3** | Merge-to-Release Automation Pipeline (`release.yml`) | **Completed** |
| **Phase 4** | Distribution Repository Automated Publishing (`sync_distribution_repo.dart`) | **Completed** |
| **Phase 5** | Production Signing Architecture & Secret Management | **Completed** |
| **Phase 6** | Release Safety, Guardrails & Concurrency Control | **Completed** |
| **Phase 7** | Automated Changelog & Release Notes Engine | **Completed** |
| **Phase 8** | Automation & Pipeline Validation Testing | **In Progress** |
| **Phase 9** | Production CI/CD Documentation & Bootstrap Guide (`AUTOMATED_RELEASE_PIPELINE.md`) | **Completed** |
| **Phase 10** | Final Repository Verification & PR Creation | Pending |

---

## Tooling Suite (`tool/release/`)

1. `version_calculator.dart` — Evaluates Git tags and PR labels (`release:major`, `release:minor`, `release:patch`, `release:alpha`, `release:beta`, `release:stable`), increments version, enforces tag collision avoidance, updates `pubspec.yaml`, and exports to `$GITHUB_OUTPUT`. Tested in `test/unit/release/version_calculator_test.dart` (13 tests).
2. `release_notes_generator.dart` — Categorizes commit logs between releases into Keep-a-Changelog sections and writes Markdown notes. Tested in `test/unit/release/release_notes_generator_test.dart` (4 tests).
3. `verify_release_apk.dart` — Computes SHA-256 hash, verifies package ID (`io.github.omkar_git_hub.offlink`), version, and signature. Tested in `test/unit/release/verify_release_apk_test.dart` (6 tests).
4. `publish_release.dart` — Automates GitHub Release creation, idempotent publishing, and binary asset upload.
5. `sync_distribution_repo.dart` — Updates `metadata/release-information.json`, `metadata/app-information.json`, `CHANGELOG.md`, and `RELEASES.md` in `offlink-releases`. Tested in `test/unit/release/sync_distribution_repo_test.dart` (5 tests).

---

## Decisions Log
- **Application ID**: Permanent ID migrated to `io.github.omkar_git_hub.offlink` tying identity cryptographically to the author's verified GitHub namespace. All Kotlin source code, MethodChannel names, and test suites updated.
- **Pure Dart Tooling**: All automation tools written in standard Dart for 100% portability, zero external runtime dependencies (no Python/Node requirement), and full unit test coverage using `flutter test`.
- **Ephemeral Keystore Pattern**: Production keystore is reconstructed from base64 environment secret exclusively during CI execution and immediately removed in an `always()` post-action step.
- **Fail-Safe Release Fallback**: If keystore secrets or `RELEASE_TOKEN` are not yet configured by the repository owner, the pipeline does not fail abruptly. Instead, it signs using debug fallback and logs actionable warnings directing the maintainer to `AUTOMATED_RELEASE_PIPELINE.md`.
- **Protected-Main Branch Compatibility**: Release automation never pushes version bumps or changelogs to `main`. Versions are injected at build time (`--build-name` and `--build-number`), and releases are tagged atomically using GitHub Releases targeting the merged commit on `main`.

---

## Protected-Main Branch Compatibility Fix (2026-11-24)
- **Branch**: `fix/ci-cd-protected-main-compatibility` (PR #25, merged)
- **Issue**: GitHub Actions runner failed on step `Commit version bump and updated CHANGELOG to main` with error `GH013: Repository rule violations found for refs/heads/main` (changes must be made through a pull request; required check `Flutter CI` expected).
- **Resolution**:
  1. Removed `git push origin main` and file commits from `.github/workflows/release.yml`.
  2. Dynamically inject version and build number via `flutter build apk --release --build-name=... --build-number=...`.
  3. Added release-skipping support (`release:skip`, `no-release`, `[skip release]`).
  4. Made tag and release creation atomic using `gh release create <tag> --target $GITHUB_SHA`.
  5. Added idempotency guards to skip duplicate releases safely on retries.
  6. Verified 29/29 release unit tests passing, static analysis clean, and formatting clean.

---

## Fully Automatic PR-Based Release System (2026-11-24)
- **Branch**: `feature/automatic-pr-release-system`
- **Core Principle**: Maintainer's only routine manual action is **Review PR → Merge PR**. No manual version bumps, tagging, or release triggering required.

### 1. Conventional PR Title Release Rules
PR titles automatically drive release classification:

| PR Title Prefix | Action | Alpha Version Effect | Stable Version Effect |
|---|---|---|---|
| `feat:` / `feat(...):` | **Release** | Increments alpha iteration (`0.1.0-alpha.2` -> `0.1.0-alpha.3`) | Increments minor version (`0.2.0`) |
| `fix:` / `fix(...):` | **Release** | Increments alpha iteration (`0.1.0-alpha.2` -> `0.1.0-alpha.3`) | Increments patch version (`0.1.1`) |
| `perf:` / `perf(...):` | **Release** | Increments alpha iteration (`0.1.0-alpha.2` -> `0.1.0-alpha.3`) | Increments patch version (`0.1.1`) |
| `feat!:` / `fix!:` | **Breaking Release** | Increments minor version (`0.2.0-alpha.1`) | Increments major version (`1.0.0`) |
| `docs:` / `docs(...):` | **No Release** | Release skipped (`should_release=false`) | Release skipped |
| `test:` / `test(...):` | **No Release** | Release skipped (`should_release=false`) | Release skipped |
| `chore:` / `chore(...):` | **No Release** | Release skipped (`should_release=false`) | Release skipped |
| `ci:` / `ci(...):` | **No Release** | Release skipped (`should_release=false`) | Release skipped |
| `refactor:` | **No Release** | Skipped unless breaking (`refactor!:`) or `[release]` token | Skipped unless breaking or `[release]` |

### 2. CI PR Title Validation
- Integrated `tool/release/pr_classifier.dart` into `.github/workflows/ci.yml`.
- Runs on `pull_request: types: [opened, edited, synchronize, reopened]`.
- Fails with explicit, actionable formatting guidance if a PR title does not conform to Conventional Commits.

### 3. Release Notes Generation Fix
- Fixed argument mismatch where `release.yml` passed `--output=RELEASE_NOTES.md` while `release_notes_generator.dart` previously expected `--output-file=`.
- Updated `release_notes_generator.dart` to support both `--output=` and `--output-file=`, create parent directories recursively, and accept `--pr-title`.
- Added a fail-safe fallback in `release.yml` ensuring `RELEASE_NOTES.md` is guaranteed to exist and be non-empty before release creation.

### 4. Idempotent Retry & Asset Reconciliation
- Enhanced `release.yml` and `publish_release.dart` with `uploadAssets` and asset presence verification.
- If a release workflow fails or is retried after partial completion:
  1. Checks if release exists on source repo (`Omkar-git-hub/offlink`); uploads missing assets with `--clobber`.
  2. Checks if release exists on distribution repo (`Omkar-git-hub/offlink-releases`); reconciles metadata and uploads assets with `--clobber`.
  3. If both releases and assets exist, cleanly skips duplicate work and exits 0.

### 5. Automated Tooling & Test Coverage
- Added `tool/release/pr_classifier.dart`.
- Added unit tests in `test/unit/release/pr_classifier_test.dart` (15 tests).
- Expanded `test/unit/release/version_calculator_test.dart` (50+ tests total across release suite).

---

## Release Signing Hardening (Fail-Closed Architecture) (2026-11-24)
- **Branch**: `security/release-signing-fail-closed`
- **Objective**: Prevent official release APKs from ever being silently signed with debug credentials (`CN=Android Debug`) or built without valid production credentials.
- **Implementation**:
  1. **Gradle Build Configuration (`android/app/build.gradle.kts`)**:
     - Permanently removed debug fallback from `buildTypes.release`.
     - Hooked into `gradle.taskGraph.whenReady` to check for release tasks (`assembleRelease`, `packageRelease`, `bundleRelease`).
     - Fails closed with an explicit `GradleException` if any of `OFFLINK_KEYSTORE_PATH`, `OFFLINK_KEYSTORE_PASSWORD`, `OFFLINK_KEY_ALIAS`, or `OFFLINK_KEY_PASSWORD` are missing or if the keystore file does not exist.
     - Debug tasks (`assembleDebug`, `packageDebug`) remain completely functional for local development without credentials.
  2. **GitHub Actions Release Workflow (`.github/workflows/release.yml`)**:
     - Eliminated debug keystore generation fallback in `Set up Android Keystore`.
     - Fails the workflow immediately with exit code 1 if required signing secrets are not configured.
     - Added `--require-production` argument to `verify_release_apk.dart`.
  3. **Verification Tooling (`tool/release/verify_release_apk.dart`)**:
     - Added `ApkVerifier.isProductionCertificate` checking that the certificate Distinguished Name (`certDn`) does not contain `CN=Android Debug`.
     - Unit tests in `test/unit/release/verify_release_apk_test.dart`.
  4. **Pull Request CI Compatibility (`.github/workflows/ci.yml`)**:
     - Configured ephemeral PR test keystore in runner temp to validate release compilation without requiring production secrets.


