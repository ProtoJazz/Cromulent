---
phase: 07-cicd-electron-distribution
plan: "03"
subsystem: infra
tags: [github-actions, electron, electron-builder, rust, appimage, deb, nsis, ci-cd]

# Dependency graph
requires:
  - phase: 07-cicd-electron-distribution plan 01
    provides: electron-builder config in package.json with linux/win targets and GitHub publish settings
provides:
  - GitHub Actions workflow that builds Electron installers for Linux (.AppImage, .deb) and Windows (.exe NSIS) on version tag push
  - Automated GitHub Release creation and artifact upload via electron-builder --publish always
affects:
  - operators downloading Cromulent desktop client from GitHub Releases
  - future code-signing milestone (deferred, SmartScreen warning documented)

# Tech tracking
tech-stack:
  added:
    - dtolnay/rust-toolchain@stable (GitHub Actions Rust toolchain action)
    - npx electron-builder --publish always (CI publish command)
  patterns:
    - Matrix strategy with fail-fast false for independent platform builds
    - Conditional Rust build steps gated on matrix.platform == linux
    - contents: write job permission for GITHUB_TOKEN GitHub Releases access
    - electron-builder OS auto-detection via runner (no --linux/--win CLI flags needed)

key-files:
  created:
    - .github/workflows/release-electron.yml
  modified: []

key-decisions:
  - "fail-fast: false on matrix strategy — Linux and Windows are independent deliverables, one failure should not cancel the other"
  - "No --linux/--win CLI flags passed to electron-builder — runner OS auto-detected, mismatched flags cause errors"
  - "dtolnay/rust-toolchain@stable used instead of archived actions-rs/toolchain"
  - "Rust build steps conditional on matrix.platform == linux — evdev crate does not build on Windows"
  - "Code signing explicitly deferred to future milestone — SmartScreen warning documented in workflow comments for maintainers"

patterns-established:
  - "Rust native binary compiled before electron-builder so files glob picks up ptt-daemon/target/release/ptt-daemon"
  - "GH_TOKEN set as env var on npm ci + electron-builder step (not job-level) to limit secret exposure scope"

requirements-completed: [DIST-01, DIST-02, DIST-03]

# Metrics
duration: 1min
completed: 2026-03-05
---

# Phase 7 Plan 03: Electron Release Workflow Summary

**GitHub Actions matrix workflow that builds .AppImage/.deb (Linux) and NSIS .exe (Windows) Electron installers and publishes them directly to GitHub Releases on semver tag push**

## Performance

- **Duration:** ~1 min
- **Started:** 2026-03-05T14:22:51Z
- **Completed:** 2026-03-05T14:23:41Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Created `.github/workflows/release-electron.yml` with a 2-entry matrix (ubuntu-latest + windows-latest)
- Linux job compiles the Rust PTT daemon via `cargo build --release` before electron-builder runs so the binary is available for packaging
- Windows job skips Rust build entirely (evdev is Linux-only); electron-builder handles uiohook-napi native rebuild automatically
- `npx electron-builder --publish always` with `GH_TOKEN` creates the GitHub Release and uploads all artifacts in one step
- `releaseType: release` in package.json (set by Plan 01) prevents draft creation — release is public immediately

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Electron release workflow with Linux and Windows matrix** - `ec0b45b` (feat)

**Plan metadata:** (docs commit — follows this summary)

## Files Created/Modified

- `.github/workflows/release-electron.yml` - GitHub Actions workflow triggering on v*.*.* tags, building Linux and Windows Electron installers and publishing to GitHub Releases

## Decisions Made

- `fail-fast: false` on matrix strategy — Linux and Windows are independent platform deliverables; a Linux build failure should not cancel the Windows build
- No `--linux` or `--win` CLI flags passed to electron-builder — runner OS is auto-detected; specifying mismatched targets would cause errors
- `dtolnay/rust-toolchain@stable` used instead of the archived `actions-rs/toolchain`
- Both Rust steps (`Install Rust toolchain` and `Build PTT daemon`) gated on `matrix.platform == 'linux'` — the evdev crate does not build on Windows
- Code signing explicitly deferred to a future milestone — SmartScreen "Unknown Publisher" warning documented in workflow comments for maintainers

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None — Python's YAML parser treats `on` as the boolean `True` (YAML 1.1 behavior), requiring `w[True]` instead of `w['on']` in verification scripts. This is a quirk of the PyYAML library, not an issue with the workflow file itself.

## User Setup Required

None - the workflow uses `GITHUB_TOKEN` (automatically provided by GitHub Actions) with `contents: write` permission. No external PAT secrets or repository secrets need to be configured.

## Next Phase Readiness

- Electron release automation complete for Phase 7
- Phase 7 CI/CD requirements DIST-01, DIST-02, DIST-03 fulfilled (Plan 01: electron-builder config, Plan 02: Docker/GHCR release, Plan 03: Electron release workflow)
- DIST-04 (if any remaining) to be checked against phase plan
- Ready to proceed to Phase 8 PTT Key Binding

---
*Phase: 07-cicd-electron-distribution*
*Completed: 2026-03-05*
