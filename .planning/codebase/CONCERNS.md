# Codebase Concerns

**Analysis Date:** 2026-02-26

## Tech Debt

### Hardcoded Channel Configuration
- **Issue:** Voice channels are hardcoded in configuration with static IDs (general, random, voice-main) rather than being dynamically queried at runtime
- **Files:** `config/config.exs` (lines 67-71), `lib/cromulent/seeds.ex`
- **Impact:** Adding or removing channels requires code changes and redeployment. Makes multi-tenant or flexible channel setups impossible. All default channels are recreated on seed, which could create duplicates if migration state is inconsistent.
- **Fix approach:** Migrate hardcoded channels to database-backed configuration. Create a migration that preserves existing hardcoded channels. Add a configuration option to toggle between legacy hardcoded and database-driven channels during transition period.

### Debug Logging Left in Production Code
- **Issue:** `IO.puts` debug statements remain in voice channel initialization
- **Files:** `lib/cromulent_web/channels/voice_channel.ex` (line 17): `IO.puts("🔊 after_join firing for user #{socket.assigns.current_user.id}")`
- **Impact:** Creates verbose noise in production logs. Sensitive user IDs are logged. Makes it harder to find real issues in log output.
- **Fix approach:** Replace with structured logging via Logger module or remove entirely. If debugging needed, use Logger.debug with metadata.

### ID Parsing Fragility in Voice Channel
- **Issue:** `parse_id/1` function in voice channel attempts to parse string channel IDs to integers with a fallback to return the string as-is
- **Files:** `lib/cromulent_web/channels/voice_channel.ex` (lines 82-87)
- **Impact:** If channel IDs are UUIDs (which `Cromulent.UUID7` suggests they are), this parsing will fail silently and return a string. The downstream `Cromulent.Channels.get_channel()` will receive inconsistent types. This could cause legitimate channels to fail to join due to type mismatch.
- **Fix approach:** Determine the actual channel ID type in the system. If using UUIDs, remove the Integer.parse attempt and accept strings directly. Add type validation to ensure consistent ID handling throughout the voice channel flow.

## Known Bugs

### Race Condition in After-Join Presence Tracking
- **Issue:** In voice channel `handle_info(:after_join)`, presence is tracked without checking if the current user is already present
- **Files:** `lib/cromulent_web/channels/voice_channel.ex` (lines 16-32)
- **Symptoms:** If a user joins multiple voice channels simultaneously or reconnects quickly, duplicate presence entries could be created. The `{:ok, _}` pattern match swallows any potential error.
- **Trigger:** User joins voice channel, connection drops and reconnects before cleanup completes, or user joins multiple voice channels in rapid succession
- **Workaround:** Currently none. Reconnection should eventually clean up duplicates via disconnect, but state will be inconsistent during the overlap.

### Unhandled Error in Presence Update
- **Issue:** Presence update on mute toggle has no error handling
- **Files:** `lib/cromulent_web/channels/voice_channel.ex` (lines 34-39)
- **Symptoms:** If presence update fails (e.g., user not found in presence list), the error is silently ignored and client receives no feedback
- **Trigger:** Mute toggle immediately after joining or during presence inconsistency
- **Workaround:** Refresh the page to re-sync presence state

### Missing Handling for Invalid ICE Candidates
- **Issue:** ICE candidates are broadcast without validation that the receiving peer exists
- **Files:** `lib/cromulent_web/channels/voice_channel.ex` (lines 67-74)
- **Symptoms:** If a client sends ICE candidates for a peer that hasn't established a connection yet (peer not in `this.peers` object), the candidate is silently dropped
- **Trigger:** Network jitter causing candidates to arrive before SDP offer/answer completes
- **Workaround:** Clients should queue candidates locally before setting up peer connection (current implementation may already do this)

## Security Considerations

### Admin Check Does Not Validate User Existence
- **Issue:** `require_admin` hook checks `socket.assigns.current_user.role == :admin` without confirming the user still exists in the database
- **Files:** `lib/cromulent_web/user_auth.ex` (lines 152-158)
- **Risk:** If a user is deleted from the database but retains an active session, they could maintain admin access. Particularly concerning if admin users can delete other admins.
- **Current mitigation:** User deletion is not implemented in the codebase, so this is theoretical. Session expiry provides some protection.
- **Recommendations:** (1) Add a user existence check in the ensure_authenticated hook that refreshes user data from DB. (2) Implement user soft-delete with a deactivation timestamp that's checked in the admin authorization check.

### Incomplete Token Validation in Auto-Login
- **Issue:** Auto-login endpoint doesn't validate that the refresh token's device info matches the current request
- **Files:** `lib/cromulent_web/controllers/auto_login_controller.ex` (lines 7-19)
- **Risk:** A leaked refresh token could be used from any device. There's no IP validation or device fingerprinting check.
- **Current mitigation:** Device info is stored with the token but not verified on use. Tokens have an expiry.
- **Recommendations:** (1) Add IP address validation matching the device that originally authenticated. (2) Implement token rotation - issue a new token on successful verification and invalidate the old one. (3) Add configurable token TTL that's shorter than the 60-day session cookie.

### WebRTC Signaling Has No Rate Limiting
- **Issue:** Voice channel message handlers (sdp_offer, ice_candidate, etc.) have no rate limiting or validation
- **Files:** `lib/cromulent_web/channels/voice_channel.ex` (lines 41-74)
- **Risk:** A malicious user could flood other clients with invalid offers/candidates causing resource exhaustion or DoS
- **Current mitigation:** None explicit. WebSocket connection limits may provide some protection at the transport layer.
- **Recommendations:** (1) Add a message rate limit per user per voice channel. (2) Validate SDP structure before broadcasting. (3) Log and drop candidates for unknown peers after a threshold.

## Performance Bottlenecks

### Full Channel Message List Loaded on Every View
- **Issue:** `ChannelLive.handle_params` loads all messages for a channel without pagination at the initial load
- **Files:** `lib/cromulent_web/live/channel_live.ex` (lines 34-35)
- **Problem:** Large channels (100s-1000s of messages) will cause slow page loads. The query `Cromulent.Messages.list_messages(channel.id)` has no limit clause visible.
- **Cause:** Messages are loaded as a single batch. Scrolling back uses `list_messages_before` which is paginated (50 message limit), but initial load is unlimited.
- **Improvement path:** (1) Add pagination to initial load - fetch last 50 messages instead of all. (2) Load older messages on scroll via virtual scrolling or infinite scroll. (3) Add database indices on `(channel_id, inserted_at)` to speed up before queries.

### Unread Counts Query Joins All Messages
- **Issue:** `Notifications.unread_counts_for_user` and `mention_counts_for_user` are called on every channel change
- **Files:** `lib/cromulent_web/live/channel_live.ex` (line 65-66), `lib/cromulent/notifications.ex` (lines 28-52)
- **Problem:** The unread_counts query joins across all messages in all channels. With many users and messages, this becomes expensive. Called synchronously without caching.
- **Cause:** Full table scans of message table with group-by aggregation on every channel navigation
- **Improvement path:** (1) Cache unread counts in a separate table that's updated on message insertion via Notifications.fan_out_notifications. (2) Use denormalized counters rather than aggregating on read. (3) Consider Redis caching layer with TTL-based invalidation.

### Notification Fan-Out May Block
- **Issue:** `fan_out_notifications` in message flow uses `Repo.insert_all` which happens synchronously
- **Files:** `lib/cromulent/messages.ex` (implied caller), `lib/cromulent/notifications.ex` (lines 63-99)
- **Problem:** If a message mentions @everyone in a large channel (500+ users), this creates 500 insert statements that block the message insertion transaction
- **Cause:** Synchronous bulk insert without async offloading
- **Improvement path:** (1) Move notification fan-out to an async task via Oban or similar job queue. (2) Batch inserts into smaller chunks. (3) Use database-level triggers for notification creation instead of application logic.

## Fragile Areas

### Voice Channel Presence Inconsistency
- **Files:** `lib/cromulent_web/channels/voice_channel.ex`
- **Why fragile:** The voice channel relies on Phoenix Presence which has eventual consistency semantics. A rapid join/leave can cause inconsistent state between clients. The `peer_joined` and `peer_left` broadcasts are separate from Presence tracking, creating two sources of truth.
- **Safe modification:** Any change to join/leave flow must update both the explicit broadcasts AND Presence. Add tests for rapid join/leave scenarios. Consider consolidating to a single source of truth by deriving peer_joined/left from Presence changes rather than explicit messages.
- **Test coverage:** No dedicated tests for voice channel found. Voice channel join/leave behavior is untested.

### Admin Route Access Control
- **Files:** `lib/cromulent_web/live/admin_live.ex` (line 5), `lib/cromulent_web/user_auth.ex` (lines 152-158)
- **Why fragile:** Only one live view is protected by `require_admin`. If new admin routes are added, the hook must be manually added to each module. There's no centralized list of protected routes.
- **Safe modification:** Before adding any new admin endpoints, verify that either: (1) the `require_admin` hook is mounted, or (2) role checking exists in the implementation. Add a compile-time check or documentation requiring this.
- **Test coverage:** User auth tests exist but don't explicitly test admin authorization failure cases.

### Message Mention Parsing and Notification Creation
- **Files:** `lib/cromulent/messages/mention_parser.ex`, `lib/cromulent/notifications.ex` (lines 63-99), `lib/cromulent_web/live/channel_live.ex` (message creation)
- **Why fragile:** The mention parsing produces a list that's passed to fan_out_notifications, but there's no validation that the mention types are consistent with the intended groups. @group mentions require the group to exist, but this check may happen after notification creation.
- **Safe modification:** Always load group IDs before notification creation. Add validation that group_ids in mentions exist. Test @group with non-existent group ID.
- **Test coverage:** Notifications have tests but coverage of mention parsing edge cases is unclear.

### ID Type Consistency
- **Files:** `lib/cromulent_web/channels/voice_channel.ex` (parse_id function), throughout voice.js
- **Why fragile:** The system appears to use UUID7 for IDs, but voice_channel.ex treats them as potentially integers. JavaScript code converts IDs to strings. Mixed type handling could cause subtle failures where integer 1 !== string "1" in comparisons.
- **Safe modification:** Audit all ID handling in voice flow. Standardize on UUID7 type throughout. Add type guards in Elixir. Ensure JavaScript always works with string IDs.
- **Test coverage:** No type-mismatch scenarios are tested.

## Scaling Limits

### Single Presence Process
- **Resource:** Voice presence tracking uses Phoenix.Presence with hardcoded cluster mode
- **Current capacity:** Works fine with 10s of concurrent users. At 100+ concurrent users in voice, the Presence broadcast load becomes significant.
- **Limit:** ~500-1000 concurrent voice users per node before presence synchronization becomes the bottleneck
- **Scaling path:** (1) For multi-node, enable distributed Presence with Erlang distribution and cluster membership. (2) Consider sharding voice channels across nodes using partitioned names. (3) Cache presence locally with periodic sync rather than real-time broadcast.

### PubSub Broadcasts for Notifications
- **Resource:** Every message creation broadcasts to all channel members via PubSub
- **Current capacity:** ~50-100 active channels with moderate message volume
- **Limit:** At 1000+ active channels, PubSub becomes CPU-bound on message broadcast
- **Scaling path:** (1) Use Redis-based PubSub adapter instead of in-process. (2) Batch notifications instead of broadcasting on every message. (3) Client-side polling for unread counts instead of server-push.

### Hardcoded Voice Channels
- **Resource:** The system is designed around 3 hardcoded voice channels
- **Current capacity:** Fits small to medium deployments
- **Limit:** Adding more than a handful of voice channels requires code changes
- **Scaling path:** Already identified in Tech Debt section - migrate to database-driven channel creation

## Dependencies at Risk

### Phoenix 1.7+ with LiveView
- **Risk:** LiveView is a core dependency. Breaking changes in Phoenix would require significant refactoring.
- **Impact:** Cannot upgrade Phoenix without thorough testing of bidirectional socket communication, presence, and channel behaviors
- **Migration plan:** Keep Phoenix pinned to known-good minor version. Monitor release notes. Test major upgrades in staging before production deployment.

### Bcrypt for Password Hashing
- **Risk:** Bcrypt is used but cost factor is not configurable in the codebase
- **Impact:** If Bcrypt is compromised or becomes too slow, password resets would be required to migrate
- **Migration plan:** Currently acceptable. If performance concerns arise, plan for password reset campaign to migrate to Argon2.

## Missing Critical Features

### No Rate Limiting on Authentication Endpoints
- **Problem:** Login endpoint at `/api/auth/login` has no brute-force protection
- **Blocks:** Vulnerable to credential stuffing attacks
- **Recommended feature:** Add rate limiting per IP / email with exponential backoff. Implement account lockout after N failed attempts.

### No Audit Logging for Admin Actions
- **Problem:** Admin actions (user role changes, channel creation/deletion) are not logged
- **Blocks:** Cannot trace who made what changes or when. Security audits impossible.
- **Recommended feature:** Create audit log table that tracks all admin mutations with user, action, resource, timestamp, and old/new values.

### No User Email Confirmation
- **Problem:** User registration doesn't require email confirmation
- **Blocks:** Allows registering with invalid emails. No verification of ownership.
- **Recommended feature:** Implement email confirmation flow with time-limited tokens sent to registered email.

### No Message Search
- **Problem:** No way to search message history
- **Blocks:** Users can't find old messages. Large channels become unsearchable
- **Recommended feature:** Implement full-text search on message body, indexed on channel_id and timestamp.

## Test Coverage Gaps

### Voice Channel Signaling
- **What's not tested:** Voice channel join/leave, SDP offer/answer flow, ICE candidate handling
- **Files:** `lib/cromulent_web/channels/voice_channel.ex`
- **Risk:** The core WebRTC signaling code has zero test coverage. Regressions in peer connection would go undetected. Race conditions in presence tracking are untested.
- **Priority:** High - Voice is a critical feature

### Admin Authorization
- **What's not tested:** Detailed test of require_admin hook preventing non-admin access to admin routes
- **Files:** `lib/cromulent_web/user_auth.ex`, `lib/cromulent_web/live/admin_live.ex`
- **Risk:** If authorization bypass exists, it would not be caught
- **Priority:** High - Security-critical

### Notification Fan-Out
- **What's not tested:** Fan-out behavior with @everyone, @here, @group mentions in large channels
- **Files:** `lib/cromulent/notifications.ex` (lines 63-99)
- **Risk:** Edge cases with mention parsing or group resolution are not validated
- **Priority:** Medium - Affects user experience but not critical

### ID Type Handling
- **What's not tested:** Mixed integer/string/UUID ID handling in voice channel
- **Files:** `lib/cromulent_web/channels/voice_channel.ex` (parse_id)
- **Risk:** Type mismatches could silently fail or cause unexpected behavior
- **Priority:** Medium - Architectural consistency

### Auto-Login Token Refresh
- **What's not tested:** Refresh token validation with device info, IP matching (if implemented), token expiry
- **Files:** `lib/cromulent_web/controllers/auto_login_controller.ex`
- **Risk:** Security gaps in token handling are untested
- **Priority:** High - Authentication-critical

---

*Concerns audit: 2026-02-26*
