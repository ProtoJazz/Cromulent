---
phase: 03-voice-reliability
plan: "02"
subsystem: infrastructure
tags: [coturn, turn-server, docker, docker-compose, deployment, webrtc]
dependency_graph:
  requires: []
  provides: [coturn-infra]
  affects: [03-01-turn-provider]
tech_stack:
  added: [coturn/coturn:4.6]
  patterns: [docker-compose service, standalone Dockerfile for Coolify]
key_files:
  created:
    - priv/coturn/turnserver.conf
    - Dockerfile.coturn
  modified:
    - docker-compose.yml
decisions:
  - "network_mode: host used on Linux to avoid Docker NAT breaking TURN relay"
  - "Relay port range kept narrow (49152-49200) for local dev; Dockerfile.coturn EXPOSE covers full range for production"
  - "TURN_SECRET env var substitution is native Coturn feature — no shell scripting needed"
metrics:
  duration: "1 minute"
  completed: "2026-03-01"
  tasks_completed: 2
  files_changed: 3
---

# Phase 3 Plan 2: Coturn Infrastructure Summary

Coturn TURN server infrastructure as three files: `turnserver.conf` (shared config), docker-compose service (local dev), and `Dockerfile.coturn` (production deployment via Coolify).

## What Was Built

### Task 1: Coturn config and docker-compose service (b6f0600)

**`priv/coturn/turnserver.conf`** — The Coturn server configuration file, mounted read-only into the container. Uses `use-auth-secret` + `static-auth-secret=${TURN_SECRET}` which is the HMAC time-limited credential mode matching the `Coturn.ex` provider implementation. The `${TURN_SECRET}` substitution is handled natively by Coturn at startup, not by shell.

**`docker-compose.yml`** — Added `coturn` service after `adminer`:
- Image: `coturn/coturn:4.6`
- `network_mode: host` (Linux) — bypasses Docker NAT, which would otherwise break TURN relay by masking the real client address
- Port mappings commented-out with instructions for Mac/Windows users who need explicit port binding
- Config volume-mounted from `./priv/coturn/turnserver.conf`

### Task 2: Dockerfile.coturn for production (85553a2)

**`Dockerfile.coturn`** — Wraps `coturn/coturn:4.6` and bakes the config in via `COPY`. Production operators don't need volume mounts — just set `TURN_SECRET` env var and run with `--network host`. `EXPOSE 49152-65535/udp` covers the full relay range; firewall rules on the production host should match.

## Operator Notes

### Local development
```bash
# Start TURN server for local dev testing
export TURN_SECRET=your_dev_secret
docker compose up coturn
```

The TURN server will be available at `turn:localhost:3478`. Configure `TURN_PROVIDER=coturn` and `TURN_SECRET=your_dev_secret` in your Phoenix dev environment to point the app at it.

### Production (Coolify)
```bash
# Build standalone image
docker build -f Dockerfile.coturn -t cromulent-coturn .

# Run (Linux host networking recommended)
docker run -e TURN_SECRET=$(openssl rand -hex 32) --network host cromulent-coturn
```

Set `TURN_SECRET` to a long random value (use `openssl rand -hex 32`). The same value must be set in the Phoenix app's `TURN_SECRET` env var so credentials match.

**Port range note:** `turnserver.conf` has `min-port=49152; max-port=49200` (narrow, for local dev). Production should widen this range and ensure the firewall allows UDP on those ports. Edit `turnserver.conf` before building the image.

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

- [x] `priv/coturn/turnserver.conf` exists with `use-auth-secret` and `static-auth-secret=${TURN_SECRET}`
- [x] `docker-compose.yml` contains coturn service using `coturn/coturn:4.6`
- [x] `Dockerfile.coturn` exists in project root with `FROM coturn/coturn:4.6`
- [x] `docker compose config` validates without YAML errors
- [x] Commits b6f0600 and 85553a2 exist in git log
