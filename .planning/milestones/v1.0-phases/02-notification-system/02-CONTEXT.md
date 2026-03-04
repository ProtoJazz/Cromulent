# Phase 2: Notification System - Context

**Gathered:** 2026-02-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Multi-channel notification delivery for @mentions. Users receive desktop alerts (Electron native + Web Notifications API), audible sounds, and can review missed notifications in an inbox. Unread badge tracking already exists and works with real mention data — this phase wires notifications into the existing system. User popovers on hover complete the "who is this person" experience.

Per-channel notification preferences, DND mode, and offline notifications are deferred to v2 (NOTF-08, NOTF-09, NOTF-10).

</domain>

<decisions>
## Implementation Decisions

### Desktop Alerts
- Full context notifications: author name, channel name, and message preview text
- Clicking a notification focuses the app/tab and navigates to the mentioned channel
- Each mention gets its own notification (stack individually, not grouped)
- Single default alert sound plays for all mention notifications
- System detects Electron vs web browser and uses native OS notifications or Web Notifications API accordingly
- Notifications only fire when user is online and not currently viewing the mentioned channel

### Unread Badges & Tracking
- Badge system already exists and works with real mention data — no rebuild needed
- Clicking a desktop notification and jumping to the channel auto-clears the mention badge
- New work: ensure desktop notification delivery integrates with the existing badge/tracking system

### Notification Inbox
- Bell icon in the top header bar (not in the sidebar)
- Bell icon shows a number badge with unread notification count
- Dropdown panel opens on click with a list of notifications
- Each item shows: author, channel name, message snippet, and timestamp (rich preview)
- Click an item to navigate to that channel
- "Mark all as read" button to clear the inbox
- No per-item dismiss — keep it simple

### User Popover
- Triggered by hover with ~300ms delay on any username
- Displays: avatar, display name, online/offline status dot, role badge
- Info only — no quick actions or buttons
- Works everywhere usernames appear: @mentions in messages, sidebar member list, and any other username rendering

### Claude's Discretion
- Notification sound file selection and format
- Exact popover positioning and animation
- Dropdown panel dimensions and scroll behavior
- Web Notifications API permission request flow and timing
- Error handling for denied notification permissions

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. General direction is Discord/Slack conventions for desktop alerts, GitHub-style bell dropdown for the inbox.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

Per-channel notification preferences (NOTF-08), DND mode (NOTF-09), and offline/push notifications (NOTF-10) are already tracked as v2 requirements.

</deferred>

---

*Phase: 02-notification-system*
*Context gathered: 2026-02-26*
