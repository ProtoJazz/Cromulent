# Pitfalls Research

**Domain:** Self-hostable voice and chat application (Phoenix LiveView)
**Researched:** 2026-02-26
**Confidence:** HIGH (based on codebase analysis + domain patterns)

## Critical Pitfalls

### Pitfall 1: Synchronous Notification Fan-Out Blocks Message Creation

**What goes wrong:**
`@everyone` mention triggers `fan_out_notifications/4` synchronously inside the message creation transaction. With 50 channel members, this inserts 50 notification rows in sequence, blocking the message from appearing for 200-500ms. Users see lag when using broadcast mentions.

**Why it happens:**
The existing implementation in `lib/cromulent/notifications.ex:63-99` runs fan-out inside the message transaction. This is fine for `@user` (1 insert) but doesn't scale to `@everyone` (N inserts).

**How to avoid:**
1. Move fan-out to async (Task.Supervisor or Oban job)
2. Batch notification inserts with `Repo.insert_all/2`
3. Message insert returns immediately, notifications fan out asynchronously

**Warning signs:**
- Message latency increases with channel size
- Users report "lag" when @everyone is used

**Phase to address:** Phase 1 (Notification Infrastructure) - Implement async fan-out before adding desktop/sound notifications.

---

### Pitfall 2: Desktop Notifications Without Permission Management

**What goes wrong:**
Desktop notifications implemented but users never see them because the app doesn't request notification permissions at the right time, or doesn't detect when permissions are denied.

**How to avoid:**
1. Check `Notification.permission` before showing notifications
2. Request permission lazily — when user first enables desktop notifications in settings, not on app launch
3. Show clear UI feedback when permission is denied with instructions to fix
4. Provide a fallback (in-app notification banner) when desktop notifications are blocked
5. Test on fresh browser profile/Electron install where permissions are not granted

**Warning signs:**
- Users report "notifications don't work" but can't debug why
- Notifications work in development but not in production builds
- No UI indication when permission is denied

**Phase to address:** Phase 1 (Desktop Notifications) - Build permission management first, then notification display.

---

### Pitfall 3: XSS Injection Through Unescaped Markdown Rendering

**What goes wrong:**
Markdown rendering allows raw HTML by default. An attacker posts `<img src=x onerror=alert('XSS')>` or `[click me](javascript:alert('XSS'))` and executes arbitrary JavaScript in other users' browsers.

**Why it happens:**
Earmark enables HTML for "flexibility" by default. LiveView's automatic HTML escaping doesn't apply to content explicitly marked as safe via `raw/1`.

**How to avoid:**
1. Use Earmark with HTML disabled: `Earmark.as_html!(text, escape: true)`
2. Pipe through `HtmlSanitizeEx.markdown_html()` after parsing
3. Sanitize all link hrefs — reject `javascript:`, `data:`, `vbscript:` protocols
4. Never use `raw/1` on unsanitized user content

**Warning signs:**
- Using `raw(Earmark.as_html!(message.body))` directly in templates
- No test cases with malicious markdown payloads
- Link hrefs not validated before rendering

**Phase to address:** Phase 3 (Rich Text Rendering) - Implement markdown with sanitization from day one. Security review before shipping.

---

### Pitfall 4: TURN Server Credentials Hardcoded or Exposed

**What goes wrong:**
TURN credentials hardcoded in JavaScript or embedded in HTML. Attackers extract credentials and use the TURN server to proxy traffic, turning it into an open relay.

**How to avoid:**
1. Generate short-lived TURN credentials (TTL: 24 hours) using coturn's HMAC-SHA1 auth
2. Create credentials server-side in LiveView, never in JavaScript
3. Pass credentials to client via `push_event` when joining voice
4. Configure coturn with `use-auth-secret`, `static-auth-secret`, and `denied-peer-ip`

**Warning signs:**
- Credentials visible in browser DevTools Network tab or page source
- Same credentials used for all users/sessions
- TURN server config has `no-auth` or static usernames

**Phase to address:** Phase 2 (TURN Server Integration) - Implement HMAC-based time-limited credentials from the start.

---

### Pitfall 5: @Mention Autocomplete Race Conditions with LiveView

**What goes wrong:**
User types `@jo`, autocomplete shows matches. LiveView pushes a message update that re-renders the input, losing the autocomplete selection or resetting the input.

**Why it happens:**
Client-side autocomplete state conflicts with server-driven LiveView updates. When LiveView re-renders the input element, JavaScript event handlers fire out of order.

**How to avoid:**
1. Use `phx-update="ignore"` on the message input container
2. Manage autocomplete entirely client-side with a Phoenix Hook
3. Debounce autocomplete filtering (300ms)
4. Store input value in JavaScript state, sync to LiveView only on form submit

**Warning signs:**
- Input field loses focus during typing
- Cursor jumps to end of input unexpectedly
- Autocomplete dropdown closes randomly

**Phase to address:** Phase 1 (@Mention Autocomplete) - Design as client-side JS hook from the start. Use `phx-update="ignore"` pattern.

---

### Pitfall 6: Voice Double-Join Creates Ghost Peer Connections

**What goes wrong:**
User joins voice, connection drops briefly, Phoenix Channel auto-reconnects before the first connection's `terminate/2` fires. Now the user has two active connections broadcasting `peer_joined`, creating duplicate peer connections. Other users hear the same person twice with echo.

**How to avoid:**
1. Track user's voice connection in VoiceState with unique constraint on `user_id + channel_id`
2. In `join/3`, check if user already has active voice connection — reject or force-disconnect old
3. Use Presence meta with connection ref as unique key
4. Client-side: before joining, explicitly leave any existing voice connection
5. Add heartbeat to detect and clean up stale connections

**Warning signs:**
- Users report "hearing themselves twice" or echo
- Presence list shows same user_id multiple times
- Connection count grows faster than user count

**Phase to address:** Phase 2 (Voice Reliability) - Implement connection uniqueness enforcement before adding TURN.

---

### Pitfall 7: Unread Counts N+1 Query on Every Channel Switch

**What goes wrong:**
Switching channels triggers `unread_counts_for_user` and `mention_counts_for_user` which join across all messages. With 50 channels and 10K messages, queries take 100ms+.

**Why it happens:**
Queries in `lib/cromulent/notifications.ex:28-52` aggregate across entire message table. Already flagged in CONCERNS.md (lines 73-85).

**How to avoid:**
1. Denormalize unread counts into a counter table updated incrementally
2. On message insert, increment counters for all channel members except sender
3. On `mark_channel_read`, reset counter to 0 for that user+channel
4. Cache unread counts in ETS, invalidate on updates

**Warning signs:**
- `handle_params` in ChannelLive takes >100ms
- Slow query logs show `SELECT COUNT(*)` on messages table
- Performance degrades proportionally with message count

**Phase to address:** Phase 1 (Notification Infrastructure) - Refactor unread counts before adding more notification volume.

---

### Pitfall 8: Link Preview SSRF Attack Vector

**What goes wrong:**
Link preview fetches arbitrary user-provided URLs. Attacker posts `http://169.254.169.254/latest/meta-data/` and the server leaks cloud credentials, or posts `http://localhost:5432` to port-scan internal infrastructure.

**How to avoid:**
1. Allowlist protocols: only `http://` and `https://`
2. Blocklist private IP ranges: `127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `169.254.0.0/16`
3. Blocklist cloud metadata endpoints: `169.254.169.254`, `metadata.google.internal`
4. Set strict timeout (5s) and size limit (1MB)

**Warning signs:**
- No URL validation before HTTP fetch
- Preview fetching done in LiveView process (blocks rendering)
- No test cases with internal URLs

**Phase to address:** Phase 3 (Link Previews) - Implement SSRF protection before writing any URL fetching code.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Synchronous notification fan-out | Simple, no job queue | Message latency scales with channel size | Never for @everyone |
| Markdown rendering without sanitization | Ship faster | XSS vulnerabilities | Never |
| Static TURN credentials | Easy setup | Server becomes open relay | Only localhost dev |
| Client-side only autocomplete (no caching) | Fast to build | Network requests on every keystroke | Acceptable with debouncing |
| Desktop notifications without permission UI | Assumes permissions granted | Users blocked with no recourse | Never |
| Presence for voice without uniqueness check | Works for single-tab | Ghost connections, echo | Only early prototype |
| Embedding notification sounds in assets | Simple | Large bundle if many sounds | Acceptable for <50KB sounds |
| All messages loaded on channel switch | Simple query | Slow loads, memory bloat | Only for <100 messages |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Coturn (TURN server) | Using `no-auth` or static credentials | Generate time-limited HMAC credentials server-side |
| Earmark (Markdown) | Allowing raw HTML by default | Disable HTML: `escape: true` + HtmlSanitizeEx |
| Electron Notifications | Calling `new Notification()` without checking permission | Check permission, request lazily, provide fallback |
| Link preview fetching | Directly fetching user-provided URLs | Validate URL, block private IPs, timeout/size limits |
| Phoenix Presence | Assuming single connection per user | Use unique tracking key per connection |
| WebRTC ICE candidates | Broadcasting to peers that don't exist yet | Queue candidates until peer connection established |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Unread counts via JOIN aggregation | Slow channel switches | Denormalize to counter table | >5K messages or >20 channels |
| Notification fan-out in transaction | Message send latency | Async job with batched inserts | @everyone with >50 members |
| Loading all channel messages | Slow initial render | Paginate: load last 50 | >500 messages per channel |
| Broadcasting all typing events | PubSub overload | Throttle to 1/second | >20 concurrent typers |
| Link preview metadata in TEXT column | Slow JSON parsing | Use JSONB column | >1K previews |
| Voice presence on every meta change | WebSocket flood | Batch presence updates, 100ms debounce | >10 voice users |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Allowing `javascript:` links in markdown | XSS via crafted links | Sanitize hrefs, allowlist http/https only |
| TURN server without IP restrictions | DDOS amplification | Configure `denied-peer-ip` for internal ranges |
| Desktop notifications with message content | Info leakage on locked screens | Show "New mention in #channel" not message body |
| Voice join without rate limiting | Resource exhaustion | Limit to 1 join per 5 seconds per user |
| Link preview without SSRF protection | Internal network scanning | Block private IPs, metadata endpoints |
| Image embeds without size limits | Browser OOM | Enforce 5MB max, lazy load |

## "Looks Done But Isn't" Checklist

- [ ] **Desktop notifications:** Permission request flow, retry logic, notification click handler, OS-specific testing
- [ ] **@Mention autocomplete:** Keyboard navigation, click-outside-to-close, scroll viewport, duplicate mention prevention
- [ ] **TURN server:** Credential rotation, IP restriction config, monitoring/logging, fallback when unreachable
- [ ] **Markdown rendering:** XSS sanitization, link protocol validation, code injection tests
- [ ] **Link previews:** SSRF protection, timeout handling, 404/error states, cache invalidation
- [ ] **Code highlighting:** Language detection, fallback for unknown languages, copy-to-clipboard, mobile scroll
- [ ] **Image embeds:** Lazy loading, error states, size limits, content-type validation
- [ ] **Sound notifications:** Volume control, mute toggle, "don't play during voice call" logic
- [ ] **Unread indicators:** Mark-as-read on scroll, mention vs unread distinction, badge count limits ("99+")
- [ ] **Voice double-join:** Client-side leave-before-join, server-side registry, cleanup on tab close

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|-------------|
| Notification fan-out blocking | Phase 1: Notifications | Load test @everyone with 50 members, p99 <200ms |
| Desktop notification permissions | Phase 1: Notifications | Test on fresh OS install, verify flow + fallback |
| XSS via markdown | Phase 3: Rich Text | Security audit with malicious payloads, CSP headers |
| TURN credentials leaked | Phase 2: Voice | Audit credentials in network tab, verify expiry |
| @Mention autocomplete races | Phase 1: Mentions | Test under 500ms artificial latency |
| Voice double-join | Phase 2: Voice | Open two tabs, join voice, verify one connection |
| Unread counts N+1 | Phase 1: Notifications | 50 channels + 10K messages, verify <50ms query |
| Link preview SSRF | Phase 3: Rich Text | Pen test with internal URLs, verify blocked |

---
*Pitfalls research for: Self-hostable voice and chat application (Phoenix LiveView)*
*Researched: 2026-02-26*
