# Roadmap: Cromulent

## Milestones

- ✅ **v1.0 MVP** — Phases 1-6 (shipped 2026-03-04)
- [ ] **v1.1 Polish & Distribution** — Phases 7-10 (in progress)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-6) — SHIPPED 2026-03-04</summary>

- [x] Phase 1: Mention Autocomplete (2/2 plans) — completed 2026-02-26
- [x] Phase 2: Notification System (3/3 plans) — completed 2026-02-27
- [x] Phase 3: Voice Reliability (4/4 plans) — completed 2026-03-01
- [x] Phase 4: Rich Text Rendering (3/3 plans) — completed 2026-03-02
- [x] Phase 5: Feature Toggles (4/4 plans) — completed 2026-03-02
- [x] Phase 6: Voice Improvement (5/5 plans) — completed 2026-03-03

See full details: `.planning/milestones/v1.0-ROADMAP.md`

</details>

### v1.1 Polish & Distribution (Phases 7-10)

- [ ] **Phase 7: CI/CD & Electron Distribution** - Automated builds for Linux/Windows Electron and Docker image published via GitHub Actions
- [ ] **Phase 8: PTT Key Binding** - Users can configure their push-to-talk key in voice preferences; Electron reads it from the server
- [ ] **Phase 9: User Profiles** - Display name changes and admin-configurable avatar modes (none, URL, Libravatar)
- [ ] **Phase 10: Unraid & Documentation** - Unraid Community Applications template and comprehensive README for self-hosters

## Phase Details

### Phase 7: CI/CD & Electron Distribution
**Goal**: Cromulent releases build and publish automatically — operators install by downloading a release artifact, not by building from source
**Depends on**: Nothing (first v1.1 phase; v1.0 shipped)
**Requirements**: DIST-01, DIST-02, DIST-03, DIST-04
**Success Criteria** (what must be TRUE):
  1. Pushing a release tag to GitHub triggers a build that produces Linux (.AppImage, .deb) and Windows (.exe or .msi) Electron artifacts without manual intervention
  2. Built Electron artifacts are attached to a GitHub Release automatically and available for download from the repository's Releases page
  3. Pushing a release tag triggers a Docker image build that pushes to GitHub Container Registry (GHCR) without manual intervention
  4. A user on Windows can download the Electron installer from GitHub Releases and run it without needing to install Elixir, Node, or any dev tooling
**Plans**: 3 plans

Plans:
- [ ] 07-01-PLAN.md — Migrate electron-client to electron-builder (package.json, main.js daemon path fix, icon assets)
- [ ] 07-02-PLAN.md — Create GHCR Docker release workflow (.github/workflows/release-docker.yml)
- [ ] 07-03-PLAN.md — Create Electron release workflow with Linux+Windows matrix (.github/workflows/release-electron.yml)

### Phase 8: PTT Key Binding
**Goal**: Users can configure which key activates push-to-talk in the Electron client, and their preference persists across sessions
**Depends on**: Phase 7 (optional; can develop independently but validates against real Electron builds)
**Requirements**: PTT-01, PTT-02, PTT-03
**Success Criteria** (what must be TRUE):
  1. User can open voice preferences in the web UI and select or record a custom PTT key (e.g., press a key to set it)
  2. After setting a PTT key, restarting the Electron client still uses the configured key without any re-configuration
  3. The Electron client reads the user's configured PTT key from the server on connect and activates PTT using that key
  4. A user who has never configured a PTT key gets the existing default behavior (no regression)
**Plans**: TBD

### Phase 9: User Profiles
**Goal**: Users can present themselves with a display name and avatar; admins control how avatars work for their server
**Depends on**: Phase 7 (for deployment context; can develop independently)
**Requirements**: PROF-01, PROF-02, PROF-03, PROF-04, PROF-05, PROF-06
**Success Criteria** (what must be TRUE):
  1. User can set a display name in profile settings that is distinct from their login username, and that name appears in chat messages, the member list, and user popovers
  2. An admin can set the server avatar mode to "none" (no avatars shown anywhere), "URL" (users paste an image URL), or "Libravatar" (auto-derived from email hash)
  3. When avatar mode is "URL", a user can enter an image URL in their profile settings and that avatar appears next to their messages, in the member list, and in their popover
  4. When avatar mode is "Libravatar", avatars appear automatically for all users without any per-user configuration, derived from each user's email
  5. When avatar mode is "none", no avatar UI is shown anywhere — no broken images, no placeholder gaps
**Plans**: TBD

### Phase 10: Unraid & Documentation
**Goal**: Self-hosters can find Cromulent in Unraid Community Applications and have clear documentation to deploy and understand the system
**Depends on**: Phase 7 (Docker image on GHCR must exist before Unraid template can reference it)
**Requirements**: DOCS-01, DOCS-02, DOCS-03
**Success Criteria** (what must be TRUE):
  1. An Unraid user can find Cromulent in Community Applications, click install, fill in environment variables, and have a running instance without leaving the Unraid UI
  2. A new self-hoster following the README deployment guide can get Cromulent running with Docker Compose — including PostgreSQL and coturn — with no prior Elixir knowledge
  3. A developer reading the README technical architecture section can understand the major components (Phoenix LiveView, Channels, Electron, Rust PTT daemon) and how they fit together without reading source code
**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Mention Autocomplete | v1.0 | 2/2 | Complete | 2026-02-26 |
| 2. Notification System | v1.0 | 3/3 | Complete | 2026-02-27 |
| 3. Voice Reliability | v1.0 | 4/4 | Complete | 2026-03-01 |
| 4. Rich Text Rendering | v1.0 | 3/3 | Complete | 2026-03-02 |
| 5. Feature Toggles | v1.0 | 4/4 | Complete | 2026-03-02 |
| 6. Voice Improvement | v1.0 | 5/5 | Complete | 2026-03-03 |
| 7. CI/CD & Electron Distribution | 2/3 | In Progress|  | - |
| 8. PTT Key Binding | v1.1 | 0/? | Not started | - |
| 9. User Profiles | v1.1 | 0/? | Not started | - |
| 10. Unraid & Documentation | v1.1 | 0/? | Not started | - |
