---
created: 2026-03-04T00:00:00.000Z
title: Rework voice settings page UI
area: frontend
files:
  - lib/cromulent_web/live/user_settings_live.ex
---

## Problem

The Voice Settings section on `/users/settings` needs visual polish. The current implementation is functional but rough — layout, spacing, and section hierarchy could be improved to match the quality of the rest of the settings page.

Known issues from UAT:
- Slider renders inconsistently across browsers (currently using appearance-none + Flowbite fallback)
- Section doesn't feel visually distinct from the password/account sections above it
- "Most sensitive / Least sensitive" labels and dBFS readout are functional but not well-styled

## Solution

Redesign the Voice Settings section with proper visual hierarchy:
- Clear section card/separator to distinguish it from account settings
- Styled range slider that looks consistent with the rest of the UI
- Better label layout for the sensitivity slider (current value inline, not below)
- Consider grouping device pickers and mode toggle more clearly
- May want to add a small explainer for what VAD vs PTT means for new users
