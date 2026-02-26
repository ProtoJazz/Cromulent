# Roadmap: Cromulent - Rich Notifications and Voice Reliability

## Overview

This milestone transforms Cromulent's basic chat into a polished communication platform by adding @mention autocomplete, comprehensive notification delivery (desktop alerts, sound, unread indicators), voice reliability improvements (TURN server, double-join fix), rich text rendering with markdown and link previews, and operator-configurable feature toggles for self-hosted deployments.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Mention Autocomplete** - Type-ahead @mention UI with keyboard navigation
- [ ] **Phase 2: Notification System** - Desktop alerts, sound, unread indicators, and inbox
- [ ] **Phase 3: Voice Reliability** - TURN server and double-join prevention
- [ ] **Phase 4: Rich Text Rendering** - Markdown, link previews, and image embeds
- [ ] **Phase 5: Feature Toggles** - Operator controls for self-hosted deployments

## Phase Details

### Phase 1: Mention Autocomplete
**Goal**: Users can @mention channel members, groups, and broadcast targets with keyboard-driven autocomplete
**Depends on**: Nothing (first phase)
**Requirements**: MENT-01, MENT-02, MENT-03, MENT-04
**Success Criteria** (what must be TRUE):
  1. User types @ in message input and sees a filterable dropdown showing channel members
  2. User navigates autocomplete suggestions with arrow keys and selects with Enter
  3. @everyone and @here appear in autocomplete results alongside users
  4. @group mentions display all user groups in autocomplete alongside individual users
  5. Selected mention inserts into message and closes autocomplete popup
**Plans**: TBD

Plans:
- TBD

### Phase 2: Notification System
**Goal**: Users receive timely, multi-channel notifications for mentions with unread tracking
**Depends on**: Phase 1 (mentions must exist to trigger notifications)
**Requirements**: NOTF-01, NOTF-02, NOTF-03, NOTF-04, NOTF-05, NOTF-06, NOTF-07
**Success Criteria** (what must be TRUE):
  1. Electron users receive native OS desktop notifications when mentioned in channels they're not viewing
  2. Web browser users receive Web Notifications API alerts when mentioned in channels they're not viewing
  3. Users hear an audible sound when mentioned in a channel they're not actively viewing
  4. Channels with unread mentions display a badge showing unread count
  5. Users can view a notification inbox showing all missed mentions and alerts
  6. Hovering over a username displays a tooltip with avatar, online status, and role
  7. Notifications only fire when user is online and not currently viewing the mentioned channel
**Plans**: TBD

Plans:
- TBD

### Phase 3: Voice Reliability
**Goal**: Voice connections work reliably through restrictive NATs without duplicate joins
**Depends on**: Phase 2 (independent, but sequenced to avoid parallel work)
**Requirements**: VOIC-01, VOIC-02
**Success Criteria** (what must be TRUE):
  1. User cannot join the same voice channel multiple times even with rapid reconnects
  2. Users behind restrictive firewalls successfully connect to voice via TURN relay
  3. TURN credentials are time-limited and generated server-side (not exposed in client)
  4. Voice connection state clearly indicates connecting, connected, or disconnected status
**Plans**: TBD

Plans:
- TBD

### Phase 4: Rich Text Rendering
**Goal**: Messages display rich formatting with markdown, link previews, and embedded images
**Depends on**: Phase 3
**Requirements**: RTXT-01, RTXT-02, RTXT-03, RTXT-04
**Success Criteria** (what must be TRUE):
  1. Messages render markdown formatting including bold, italic, code blocks, lists, and blockquotes
  2. URLs in messages are automatically converted to clickable links
  3. URLs display a preview card showing title, description, and thumbnail (Open Graph)
  4. Image URLs display inline as embedded images in the message feed
  5. User-generated markdown is sanitized to prevent XSS attacks
**Plans**: TBD

Plans:
- TBD

### Phase 5: Feature Toggles
**Goal**: Server operators can enable/disable features via configuration for their deployment
**Depends on**: Phase 4 (wraps all features with config layer)
**Requirements**: ADMN-01
**Success Criteria** (what must be TRUE):
  1. Operator can disable voice features via environment variable (hides voice channels)
  2. Operator can disable TURN server via environment variable (uses STUN-only mode)
  3. Operator can disable link previews via environment variable (shows plain URLs)
  4. Operator can disable user registration via environment variable (invite-only mode)
  5. Feature flags are checked at runtime without requiring code changes
**Plans**: TBD

Plans:
- TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Mention Autocomplete | 0/TBD | Not started | - |
| 2. Notification System | 0/TBD | Not started | - |
| 3. Voice Reliability | 0/TBD | Not started | - |
| 4. Rich Text Rendering | 0/TBD | Not started | - |
| 5. Feature Toggles | 0/TBD | Not started | - |
