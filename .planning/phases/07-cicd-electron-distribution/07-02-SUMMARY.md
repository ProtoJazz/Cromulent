---
phase: 07-cicd-electron-distribution
plan: "02"
subsystem: infra
tags: [github-actions, docker, ghcr, cicd, release]

# Dependency graph
requires:
  - phase: 07-cicd-electron-distribution
    provides: "Existing Dockerfile in repo root"
provides:
  - "GitHub Actions workflow that builds and pushes Phoenix server Docker image to GHCR on semver tags"
affects: [deployment, operators, self-hosting]

# Tech tracking
tech-stack:
  added:
    - docker/login-action@v3
    - docker/metadata-action@v5
    - docker/build-push-action@v6
  patterns:
    - "GITHUB_TOKEN for GHCR auth — no external PAT secrets required"
    - "docker/metadata-action semver tag pattern: version, major.minor, latest"

key-files:
  created:
    - .github/workflows/release-docker.yml
  modified: []

key-decisions:
  - "GITHUB_TOKEN with packages: write permission is sufficient for GHCR push — no external PAT needed"
  - "Three image tags produced per release: exact semver (v1.2.0 → 1.2.0), major.minor (1.2), and latest"
  - "Workflow triggers only on v*.*.* tags — not every push, keeping CI fast"
  - "Build context is repo root (context: .) to use existing Dockerfile"

patterns-established:
  - "GHCR Docker release: docker/login-action@v3 + docker/metadata-action@v5 + docker/build-push-action@v6 standard pattern"

requirements-completed:
  - DIST-04

# Metrics
duration: 1min
completed: "2026-03-05"
---

# Phase 7 Plan 02: GHCR Docker Release Workflow Summary

**GitHub Actions workflow that builds the Phoenix server Docker image on v*.*.* tags and pushes to GHCR with semver, major.minor, and latest tags using only GITHUB_TOKEN**

## Performance

- **Duration:** ~1 min
- **Started:** 2026-03-05T14:19:32Z
- **Completed:** 2026-03-05T14:20:32Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Created `.github/workflows/release-docker.yml` workflow triggered on semver release tags
- Configured GHCR authentication using `packages: write` permission with automatic GITHUB_TOKEN — no external secrets needed
- docker/metadata-action@v5 produces three tags per release: exact version, major.minor, and `latest`
- docker/build-push-action@v6 builds from repo root using the existing Dockerfile

## Task Commits

Each task was committed atomically:

1. **Task 1: Create GHCR Docker release workflow** - `ceba871` (feat)

**Plan metadata:** (pending final commit)

## Files Created/Modified
- `.github/workflows/release-docker.yml` - GitHub Actions workflow for Docker image release to GHCR

## Decisions Made
- GITHUB_TOKEN with `packages: write` is sufficient for GHCR push (no external PAT needed) — simplifies operator setup
- Three image tags per release (exact version, major.minor, latest) — standard Docker release practice
- Workflow triggers only on `v*.*.*` tags — independent of other CI workflows, runs in parallel with Electron builds

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- PyYAML parses YAML `on` key as boolean `True` (YAML 1.1 behavior) during verification. GitHub Actions uses YAML 1.2 where `on` is a valid string key — the file is correct for GitHub Actions. Verification adapted to use the `True` key for Python-based YAML inspection.

## User Setup Required
After the first Docker image push, operators must make the GHCR package public:
- GitHub -> Repository -> Packages -> cromulent -> Package settings -> Change visibility -> Public

This is a one-time manual step — it cannot be automated without a Personal Access Token. The comment at the top of the workflow file reminds operators of this step.

## Next Phase Readiness
- Docker release workflow complete and ready to trigger on first `v*.*.*` tag push
- Runs independently from Electron release workflow (07-01) — both can fire in parallel on the same tag
- No blockers for subsequent phases

---
*Phase: 07-cicd-electron-distribution*
*Completed: 2026-03-05*
