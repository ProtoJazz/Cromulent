# Requirements: Cromulent

**Defined:** 2026-02-26
**Core Value:** Friends can reliably chat and voice call on a self-hosted server that just works

## v1 Requirements

Requirements for this milestone. Each maps to roadmap phases.

### Mentions

- [x] **MENT-01**: User can type @ in message input and see a filterable dropdown of channel members
- [x] **MENT-02**: User can navigate autocomplete with keyboard (up/down/enter/escape)
- [x] **MENT-03**: @everyone and @here mentions display correctly in autocomplete alongside users
- [x] **MENT-04**: @group mentions display correctly in autocomplete alongside users

### Notifications

- [x] **NOTF-01**: System detects whether user is on Electron or web browser client
- [x] **NOTF-02**: Electron users receive native OS desktop notifications when mentioned
- [x] **NOTF-03**: Web browser users receive Web Notifications API alerts when mentioned
- [x] **NOTF-04**: Notifications only fire when user is online and not viewing the mentioned channel
- [x] **NOTF-05**: User hears an audible sound when mentioned in a channel they're not viewing
- [ ] **NOTF-06**: User can view a notification inbox tab showing missed mentions and alerts
- [x] **NOTF-07**: User tooltip/popover shows display name, avatar, online status, and role on hover

### Rich Text

- [x] **RTXT-01**: Messages render markdown formatting (bold, italic, code blocks, lists, blockquotes)
- [x] **RTXT-02**: URLs in messages are automatically linked
- [ ] **RTXT-03**: URLs display a preview card with title, description, and thumbnail (Open Graph)
- [x] **RTXT-04**: Image URLs display inline as embedded images

### Voice

- [x] **VOIC-01**: User cannot join the same voice channel multiple times
- [x] **VOIC-02**: Server includes a bundled TURN server (coturn) for NAT traversal

### Admin/Config

- [ ] **ADMN-01**: Server operator can enable/disable features via environment variables (voice, TURN, link previews, registration)

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Rich Text

- **RTXT-05**: Code blocks display with syntax highlighting and language detection
- **RTXT-06**: User sees live markdown preview while composing messages

### Notifications

- **NOTF-08**: User can configure notification preferences per channel (mute, custom sounds)
- **NOTF-09**: User can set Do Not Disturb mode to suppress all notifications
- **NOTF-10**: Offline users receive notifications when they next log in (push notifications for mobile)

### Mentions

- **MENT-05**: Mention chips render as rich tokens in the message input (Discord-style)
- **MENT-06**: #channel-name auto-links to channels in messages

## Out of Scope

| Feature | Reason |
|---------|--------|
| Per-message read receipts | Privacy concerns — users feel surveilled |
| Email notifications | Adds Swoosh production config complexity, overkill for self-hosted |
| Mobile push notifications | No mobile app in scope for this milestone |
| WYSIWYG editor | Massive complexity, breaks LiveView patterns, users expect markdown in chat |
| Inline GIF search (Tenor/Giphy) | Third-party API dependency, violates self-hosting philosophy |
| Voice activity detection (VAD) | Privacy concerns, false positives, CPU intensive |
| End-to-end encryption | Breaks self-hosted trust model, adds significant complexity |
| SFU/media server | Overkill for 5-50 users, P2P is sufficient |
| Video chat | Bandwidth/complexity, audio-only keeps it manageable |
| OAuth/LDAP/SSO | Local accounts sufficient for small-scale self-hosting |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| MENT-01 | Phase 1 | Complete |
| MENT-02 | Phase 1 | Complete |
| MENT-03 | Phase 1 | Complete |
| MENT-04 | Phase 1 | Complete |
| NOTF-01 | Phase 2 | Complete |
| NOTF-02 | Phase 2 | Complete |
| NOTF-03 | Phase 2 | Complete |
| NOTF-04 | Phase 2 | Complete |
| NOTF-05 | Phase 2 | Complete |
| NOTF-06 | Phase 2 | Pending |
| NOTF-07 | Phase 2 | Complete |
| RTXT-01 | Phase 4 | Complete |
| RTXT-02 | Phase 4 | Complete |
| RTXT-03 | Phase 4 | Pending |
| RTXT-04 | Phase 4 | Complete |
| VOIC-01 | Phase 3 | Complete |
| VOIC-02 | Phase 3 | Complete |
| ADMN-01 | Phase 5 | Pending |

**Coverage:**
- v1 requirements: 18 total
- Mapped to phases: 18
- Unmapped: 0

---
*Requirements defined: 2026-02-26*
*Last updated: 2026-02-26 after roadmap creation*
