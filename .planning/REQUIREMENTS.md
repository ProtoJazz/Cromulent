# Requirements: Cromulent

**Defined:** 2026-03-05
**Core Value:** Friends can reliably chat and voice call on a self-hosted server that just works — deploy it, invite people, and use it daily.

## v1.1 Requirements

### Distribution

- [x] **DIST-01**: GitHub Actions builds Electron app for Linux (.AppImage, .deb) on release tag
- [x] **DIST-02**: GitHub Actions builds Electron app for Windows (.exe or .msi) on release tag
- [x] **DIST-03**: Built Electron artifacts are published to GitHub Releases automatically
- [ ] **DIST-04**: GitHub Actions builds and pushes Docker image to GHCR on release tag

### Push-to-Talk

- [ ] **PTT-01**: User can configure their PTT key in voice preferences settings
- [ ] **PTT-02**: Electron client reads the user's configured PTT key from the server on connect
- [ ] **PTT-03**: PTT key preference persists in the database across Electron client restarts

### Profiles

- [ ] **PROF-01**: User can set a display name separate from their username
- [ ] **PROF-02**: Display name is shown in chat messages, member list, and user popovers
- [ ] **PROF-03**: Admin can configure avatar mode for the server (none, URL, or Libravatar)
- [ ] **PROF-04**: When avatar mode is "URL", user can enter an avatar image URL in profile settings
- [ ] **PROF-05**: When avatar mode is "Libravatar", avatar is automatically derived from user's email hash
- [ ] **PROF-06**: Avatar is displayed in the message feed, member list, and user popovers when a mode is active

### Unraid & Documentation

- [ ] **DOCS-01**: Unraid Community Applications XML template created and referencing GHCR image
- [ ] **DOCS-02**: README contains a self-hosting deployment guide (Docker setup, environment variables, first run)
- [ ] **DOCS-03**: README contains a technical architecture reference (stack, components, how it fits together)

## Future Requirements

### Avatar Uploads

- **AVT-01**: Admin can enable local disk avatar uploads (server-stored)
- **AVT-02**: Admin can enable S3-compatible avatar uploads (external storage)
- **AVT-03**: User can upload an avatar image when upload mode is enabled

### PTT

- **PTT-04**: Web client respects configured PTT key when browser tab is focused

## Out of Scope

| Feature | Reason |
|---------|--------|
| Avatar file uploads (local/S3) | Deferred to v1.2+; URL and Libravatar cover v1.1 use cases |
| PTT key binding on web | Web tab focus limitation makes global PTT impractical; Electron covers primary use case |
| OAuth/LDAP/SSO | Local accounts sufficient for small-scale self-hosting |
| Mobile app | Web and Electron desktop cover use cases |
| Direct messages | Channel-based communication is the focus |
| Video chat | Audio-only keeps complexity manageable |
| General file uploads in chat | No cloud storage; image embeds via URL |
| Multi-node clustering | Single-server deployment is the target |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DIST-01 | Phase 7 | Complete |
| DIST-02 | Phase 7 | Complete |
| DIST-03 | Phase 7 | Complete |
| DIST-04 | Phase 7 | Pending |
| PTT-01 | Phase 8 | Pending |
| PTT-02 | Phase 8 | Pending |
| PTT-03 | Phase 8 | Pending |
| PROF-01 | Phase 9 | Pending |
| PROF-02 | Phase 9 | Pending |
| PROF-03 | Phase 9 | Pending |
| PROF-04 | Phase 9 | Pending |
| PROF-05 | Phase 9 | Pending |
| PROF-06 | Phase 9 | Pending |
| DOCS-01 | Phase 10 | Pending |
| DOCS-02 | Phase 10 | Pending |
| DOCS-03 | Phase 10 | Pending |

**Coverage:**
- v1.1 requirements: 16 total
- Mapped to phases: 16
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-05*
*Last updated: 2026-03-05 after v1.1 milestone discussion*
