# Project Research Summary

**Project:** Cromulent - Rich Notifications and Voice Reliability
**Domain:** Self-hostable voice and chat application (Phoenix LiveView)
**Researched:** 2026-02-26
**Confidence:** HIGH

## Executive Summary

This research covers enhancements to Cromulent, a self-hostable voice chat application built with Phoenix LiveView and Electron. The milestone focuses on four interconnected features: @mention autocomplete, desktop/sound notifications with unread indicators, rich text rendering with markdown support, and voice reliability improvements via TURN server integration and double-join bug fixes.

The recommended approach follows established Phoenix LiveView patterns: server-side rendering with client-side JavaScript hooks for interactive elements, async notification delivery to prevent blocking, and security-first design with HTML sanitization and SSRF protection. The core stack leverages Elixir-native libraries (Earmark for markdown, HtmlSanitizeEx for sanitization, Makeup for syntax highlighting) paired with lightweight JavaScript tools (Tribute.js for autocomplete, Howler.js for audio). TURN server integration via coturn enables voice connections through restrictive NATs.

Key risks include XSS vulnerabilities from unsanitized markdown, performance degradation from synchronous notification fan-out at scale, desktop notification permission management complexity, and voice connection "ghost peers" from double-join race conditions. All risks have clear mitigation strategies involving sanitization pipelines, async processing, lazy permission requests, and connection uniqueness enforcement.

## Key Findings

### Recommended Stack

The research identifies battle-tested Elixir/Phoenix libraries for core functionality without unnecessary external dependencies. The stack leverages existing Phoenix patterns (LiveView hooks, PubSub, Channels) rather than introducing new frameworks.

**Core technologies:**
- **Earmark 1.4.46+**: Markdown parsing — de facto standard in Elixir ecosystem, powers ExDoc, pure Elixir with no compilation complexity
- **coturn 4.6+**: TURN/STUN server — industry-standard open-source solution for WebRTC NAT traversal, Docker-friendly, essential for restrictive firewall scenarios
- **HtmlSanitizeEx 1.4+**: HTML sanitization — prevents XSS when rendering user-generated markdown, allowlist-based approach
- **Tribute.js 5.1.3+**: @mention autocomplete — lightweight (8KB), framework-agnostic, integrates cleanly with LiveView via phx-hooks
- **Howler.js 2.2.4+**: Audio playback — handles browser autoplay policies and audio context quirks better than raw Web Audio API
- **Makeup 1.1+**: Code syntax highlighting — server-side rendering avoids shipping 300KB+ Prism.js bundle to clients

**Supporting libraries:**
- **linkify 0.5+**: URL detection (used by Pleroma/Akkoma, proven in production chat)
- **makeup_elixir / makeup_js**: Language-specific lexers for code highlighting
- **Finch + Floki**: Link preview fetching (already in stack via Swoosh dependencies)

**What to avoid:**
- Client-side markdown parsing (XSS risk, inconsistent rendering)
- React-based mention libraries (massive overhead, doesn't integrate with LiveView)
- node-notifier (redundant with Electron's built-in Notification API)
- Managed TURN services (self-hosting aligns with project philosophy)

### Expected Features

Research analyzed Discord, Slack, Mattermost, and Rocket.Chat to identify table stakes vs. differentiators.

**Must have (table stakes):**
- @user autocomplete with keyboard navigation
- @everyone and @group broadcast mentions
- Unread channel indicators with mention count badges
- Desktop notifications for mentions (Electron)
- Sound alerts for mentions
- Markdown bold/italic/code blocks with syntax highlighting
- Auto-linking bare URLs
- TURN server for NAT traversal
- Voice double-join prevention
- Connection state indicators

**Should have (competitive differentiators):**
- Link previews (unfurling og:title, og:description, og:image)
- Image embeds inline
- Notification preferences per channel
- Do Not Disturb mode
- Auto-reconnect on voice connection drop

**Defer to v2+ (not launch-blocking):**
- WYSIWYG editor (massive complexity, users expect markdown in chat)
- File attachments (requires storage infrastructure)
- End-to-end encryption (breaks self-hosted trust model)
- Voice activity detection (privacy concerns, CPU intensive)

### Architecture Approach

The architecture follows a clear separation: server-side rendering with LiveView for dynamic content, client-side JavaScript hooks for interactive elements (autocomplete, notifications, audio), and async processing for expensive operations (notification fan-out, link previews).

**Major components:**

1. **Rich Text Pipeline** — Server-side markdown parsing (Earmark) → HTML sanitization (HtmlSanitizeEx) → syntax highlighting (Makeup) → auto-linking (Linkify). Store raw markdown in DB, render on display to avoid stale sanitization.

2. **Notification System** — Async fan-out using Task.Supervisor or Oban, batched inserts with `Repo.insert_all`, PubSub broadcast to all user LiveViews, multiple delivery channels (in-app badges, desktop notifications via Electron IPC, sound alerts via Howler.js).

3. **TURN Integration** — coturn Docker container with static-auth-secret, server-generated time-limited HMAC credentials (24h TTL) passed via `push_event`, client uses credentials in RTCPeerConnection, blocks private IP ranges for security.

4. **Mention Autocomplete** — ChannelLive assigns mentionable users/groups as JSON, client-side Tribute.js hook with `phx-update="ignore"` to prevent LiveView race conditions, keyboard navigation handled by library.

**Key patterns:**
- Async processing for expensive operations (don't block message creation)
- Client-side filtering for small datasets (channel members < 50)
- Security by default (sanitize, validate URLs, block private IPs)
- LiveView hooks with `phx-update="ignore"` for interactive inputs

**Build order based on dependencies:**
1. **Mentions + Notifications** — foundation for all notification delivery
2. **Voice Reliability** — independent, can run parallel to mentions
3. **Rich Text** — depends on notification system being ready (for strip-markdown in notification text)
4. **Feature Toggles** — wraps everything after implementation

### Critical Pitfalls

Research identified eight critical pitfalls with clear prevention strategies.

1. **Synchronous notification fan-out blocks message creation** — @everyone with 50 members inserts 50 rows sequentially, causing 200-500ms lag. **Solution:** Move to async Task.Supervisor with batched `Repo.insert_all`.

2. **Desktop notifications without permission management** — Users never see notifications because permission wasn't requested or denied state not handled. **Solution:** Lazy permission request on first use, clear UI feedback when denied, fallback to in-app banner.

3. **XSS injection through unescaped markdown** — Earmark allows raw HTML by default, enabling `<img onerror=alert('XSS')>` attacks. **Solution:** Use Earmark with `escape: true`, pipe through HtmlSanitizeEx, sanitize link hrefs.

4. **TURN credentials hardcoded or exposed** — Attackers extract credentials from DevTools, use server as open relay. **Solution:** Generate HMAC-SHA1 time-limited credentials (24h TTL) server-side, pass via `push_event`.

5. **@mention autocomplete race conditions** — LiveView re-renders input during typing, losing autocomplete state. **Solution:** Use `phx-update="ignore"` on input container, manage autocomplete entirely client-side.

6. **Voice double-join creates ghost peers** — User reconnects before old connection terminates, creating duplicate peer connections and echo. **Solution:** Track connections in VoiceState with unique constraint, reject duplicate joins, client leaves before joining.

7. **Unread counts N+1 query** — Aggregating across all messages on every channel switch, 100ms+ with 10K messages. **Solution:** Denormalize to counter table with incremental updates, or cache in ETS.

8. **Link preview SSRF attack** — Fetching user URLs enables scanning internal infrastructure (169.254.169.254 metadata, localhost ports). **Solution:** Allowlist http/https, blocklist private IPs, timeout 5s, size limit 1MB.

## Implications for Roadmap

Based on research, suggested phase structure prioritizes foundation before features, groups related functionality, and addresses critical pitfalls early.

### Phase 1: Mentions and Notifications Foundation

**Rationale:** Notification infrastructure is the foundation for all delivery channels (in-app, desktop, sound). Building @mention autocomplete and notification alerts together ensures the full user flow works end-to-end. Must fix performance pitfalls (async fan-out, N+1 queries) before adding more notification volume.

**Delivers:**
- @mention autocomplete with Tribute.js
- Unread channel indicators with mention badges
- Real-time notification delivery via PubSub
- Desktop notifications with permission management (Electron)
- Sound alerts with Howler.js
- Async notification fan-out (no blocking)
- Denormalized unread counters

**Addresses:**
- P1 features: @mention autocomplete, unread indicators, desktop notifications, sound alerts
- Pitfall 1 (sync fan-out), Pitfall 2 (permission management), Pitfall 5 (autocomplete races), Pitfall 7 (N+1 queries)

**Research flag:** Standard patterns, skip research-phase. Phoenix LiveView notification patterns are well-documented.

### Phase 2: Voice Reliability

**Rationale:** Voice fixes are independent of other features and can be developed in parallel. Double-join bug is critical to fix before TURN (prevents ghost peers from consuming relay resources). TURN server requires Docker infrastructure setup and HMAC credential generation.

**Delivers:**
- TURN server via coturn Docker container
- Time-limited HMAC credential generation
- Double-join prevention with VoiceState tracking
- Connection state indicators
- Graceful disconnect handling

**Addresses:**
- P1 features: TURN server, double-join fix, connection indicators
- Pitfall 4 (TURN credentials), Pitfall 6 (voice double-join)

**Research flag:** Standard WebRTC patterns, skip research-phase. Coturn configuration is well-documented.

### Phase 3: Rich Text Rendering

**Rationale:** Rich text depends on notification system being ready (need `RichText.to_plain_text` for notification bodies). Link previews are highest complexity feature, requires async processing and SSRF protection. Group all markdown-related features together for cohesive implementation.

**Delivers:**
- Markdown rendering pipeline (Earmark → HtmlSanitizeEx → Makeup)
- Code syntax highlighting
- Auto-linking with linkify
- Link previews with async fetching
- Image embeds
- SSRF protection for link previews

**Addresses:**
- P1 features: Markdown rendering, code blocks, auto-linking
- P2 features: Link previews, image embeds, syntax highlighting
- Pitfall 3 (XSS injection), Pitfall 8 (SSRF)

**Research flag:** Link preview performance assumptions are MEDIUM confidence. May need research-phase to investigate caching strategies and performance under load.

### Phase 4: Feature Toggles and Admin Controls

**Rationale:** Wraps all features with configuration layer. Allows operators to disable features that don't fit their deployment (e.g., disable TURN server if not self-hosting, disable rich text for security-conscious deployments).

**Delivers:**
- Runtime config for feature enablement
- Admin UI for toggling features
- Database-backed feature flags
- Per-channel notification preferences

**Addresses:**
- P3 features: Feature toggles, notification preferences per channel
- Operator flexibility for self-hosted deployments

**Research flag:** Standard Phoenix configuration patterns, skip research-phase.

### Phase Ordering Rationale

- **Phase 1 before Phase 3:** Notification system must exist before rich text can strip markdown for notification bodies
- **Phase 2 parallel to Phase 1:** Voice reliability is independent, can develop simultaneously
- **Phase 3 after Phase 1:** Link previews depend on async processing patterns established in notification fan-out
- **Phase 4 last:** Wraps all features with configuration layer, requires features to be implemented first

This ordering avoids rework, groups related functionality, and addresses critical pitfalls early (async processing, permission management, XSS protection).

### Research Flags

**Phases needing deeper research during planning:**
- **Phase 3 (Link Previews):** MEDIUM confidence on performance under load with 50+ concurrent users. May need research-phase to investigate caching strategies (ETS vs database), rate limiting, and graceful degradation when preview fetch fails.

**Phases with standard patterns (skip research-phase):**
- **Phase 1 (Mentions/Notifications):** Well-documented LiveView patterns for PubSub, hooks, and async processing
- **Phase 2 (Voice Reliability):** Established WebRTC patterns, coturn configuration is standardized
- **Phase 4 (Feature Toggles):** Standard Phoenix runtime configuration

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Earmark, coturn, HtmlSanitizeEx are industry standards. Tribute.js and Howler.js widely used. All recommendations backed by official docs or community consensus. |
| Features | HIGH | Feature analysis based on direct examination of Discord, Slack, Mattermost, Rocket.Chat. Clear distinction between table stakes and differentiators. |
| Architecture | HIGH | Phoenix LiveView patterns well-established. Server-side rendering with client hooks is proven approach. Async processing and sanitization are best practices. MEDIUM confidence on link preview performance at scale. |
| Pitfalls | HIGH | Pitfalls derived from codebase analysis (existing CONCERNS.md identifies N+1 queries) and domain knowledge (XSS, SSRF, permission management are common chat app issues). |

**Overall confidence:** HIGH

### Gaps to Address

Research identified some areas requiring validation during implementation:

- **Link preview performance:** Performance assumptions for async preview fetching are based on typical scenarios (5s timeout, 1MB limit, <20 concurrent users). Need load testing with 50+ users posting URLs simultaneously to validate caching strategy (ETS vs database vs in-memory LRU).

- **Notification sound volume:** No research conducted on default volume levels, user preferences, or "quiet hours" logic. May need user testing to determine acceptable defaults.

- **Desktop notification persistence:** Electron notification behavior varies by OS (Windows Action Center vs macOS Notification Center). May need OS-specific testing to ensure notification history and click handlers work consistently.

- **TURN server relay bandwidth:** No capacity planning for TURN relay usage. If 10+ users behind restrictive NATs use relay simultaneously, bandwidth costs could be significant. Monitor relay usage in production to determine if relay limits are needed.

## Sources

### Primary (HIGH confidence)
- **Earmark** — Official Elixir markdown parser, maintained by Elixir community, powers ExDoc
- **Phoenix LiveView Hooks** — Official Phoenix documentation on client-side hooks and phx-update="ignore" patterns
- **coturn** — Industry-standard open-source TURN server, recommended by WebRTC.org
- **Electron Notification API** — Built into Electron, documented in official Electron docs
- **OWASP Markdown Cheat Sheet** — Security guidance for markdown rendering and XSS prevention
- **Codebase analysis** — Existing cromulent code (CONCERNS.md, notifications.ex, voice_channel.ex)

### Secondary (MEDIUM confidence)
- **Tribute.js** — Active project by ZURB, widely used for @mention UIs, proven integration with LiveView
- **Howler.js** — Gold standard for web audio, handles browser autoplay policies
- **linkify** — Used by Pleroma/Akkoma fediverse projects, less mainstream but proven in production
- **Makeup** — Official Elixir syntax highlighting library, powers ExDoc code display

### Tertiary (LOW confidence)
- **Link preview performance** — Assumptions based on typical HTTP fetch times and HTML parsing, not validated at scale for this specific architecture

---
*Research completed: 2026-02-26*
*Ready for roadmap: yes*
