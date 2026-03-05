---
phase: 02-notification-system
plan: 02
subsystem: notifications
tags: [notification-inbox, bell-icon, live-component, unread-count]
dependency_graph:
  requires: [desktop-notification-delivery, notification-data-model]
  provides: [notification-inbox-ui, mark-all-read, unread-badge]
  affects: [app-layout, channel-live-view, notifications-context]
tech_stack:
  elixir: [Phoenix.LiveComponent, Ecto.Query]
  ui: [Tailwind, Flowbite]
---

## What Was Built

Notification inbox with bell icon in the header bar. Clicking the bell opens a dropdown showing unread mentions with author, channel, message preview, and timestamp. "Mark all as read" clears all notifications. Badge count updates in real-time via PubSub.

## Key Decisions

1. **LiveComponent for inbox**: Used `Phoenix.LiveComponent` so the inbox manages its own state (open/close, notification list) independently from the parent LiveView.
2. **Dual placement**: Bell icon in both desktop toolbar and mobile top bar with separate component IDs to avoid conflicts.
3. **send_update for refresh**: On `:mention_changed` PubSub event, the parent LiveView calls `send_update/2` to re-render the inbox component with fresh data.
4. **Navigation via parent**: Inbox component sends `{:navigate_to_channel, slug}` to the parent process, which handles `push_patch` navigation.

## Tasks Completed

| # | Task | Status |
|---|------|--------|
| 1 | Add inbox query functions (list_unread_notifications, mark_all_read, unread_notification_count) | ✓ |
| 2 | Create NotificationInbox LiveComponent, wire into header bar, refresh on mentions | ✓ |

## Key Files

### Created
- `lib/cromulent_web/components/notification_inbox.ex` — LiveComponent with bell icon, badge, dropdown panel

### Modified
- `lib/cromulent/notifications.ex` — Added list_unread_notifications/2, unread_notification_count/1, mark_all_read/1
- `lib/cromulent_web/components/layouts/app.html.heex` — Bell icon in desktop and mobile toolbars
- `lib/cromulent_web/live/channel_live.ex` — send_update for inbox refresh, navigate_to_channel handler

## Commits
- 544051b: feat(02-02): add notification inbox query functions
- 8bdd2ab: feat(02-02): add notification inbox bell icon and dropdown

## Self-Check: PASSED

- [x] All files from plan created/modified
- [x] Compilation succeeds with no new warnings
- [x] All tasks completed
- [x] Commits present in git log
