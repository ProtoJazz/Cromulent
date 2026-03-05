# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

---

## Milestone: v1.0 — MVP

**Shipped:** 2026-03-04
**Phases:** 6 | **Plans:** 21 | **Timeline:** 22 days (2026-02-11 → 2026-03-04)
**Commits:** ~113 | **Files changed:** 356 | **Codebase:** ~141k lines

### What Was Built

- **@mention autocomplete** — type-ahead popup with keyboard navigation, @everyone/@here/@group, ARIA accessibility
- **Full notification pipeline** — desktop (Electron + Web API), sound alerts with audio cloning, unread badges, notification inbox, user popovers
- **Voice reliability** — bundled coturn TURN server with Docker, server-side double-join Presence guard, connection state UI
- **Rich text rendering** — MDEx markdown (bold, italic, code blocks, lists), Open Graph link previews via async Finch, inline image embeds
- **Feature toggles** — DB-backed operator controls for voice, registration, link previews, TURN, email confirmation; admin settings UI
- **Voice polish** — mute/deafen controls with PTT guard, speaking indicators (green ring + voice-first sort), opt-in VAD with threshold slider, audio device selection

### What Worked

- **GSD plan structure** — plan → execute → verify → UAT loop caught real issues (e.g. VAD mute respect, slider rendering) that would have shipped as bugs
- **Short plan scope** — each plan stayed focused (1-4 files modified), enabling fast iteration with minimal context loss
- **Brownfield approach** — building on a solid foundation meant each phase integrated cleanly without re-architecting
- **Fire-and-forget async pattern** — `Task.start` from GenServer casts kept link preview fetching non-blocking; applied consistently
- **Runtime env vars** — TURN credentials and feature flags both read at runtime, not compile time; server starts in safe defaults without config
- **`@behaviour` for TURN providers** — clean swap between Coturn and Metered via env var with no calling code changes
- **Presence for voice state** — reusing Phoenix Presence for mute/deafen/speaking state was elegant; no custom state management needed

### What Was Inefficient

- **ROADMAP.md plan completion markers** — plan `[ ]` → `[x]` markers in ROADMAP.md were not always updated during execution; STATE.md and SUMMARY files remained the source of truth
- **Phase 5 scope drift** — Feature Toggles grew beyond original ADMN-01 requirement to include TURN config UI and email confirmation; would have benefited from explicit scope definition up front
- **Voice improvement as Phase 6** — VAD and audio device selection were significant features that could have been their own milestone requirements rather than inserted late in v1.0
- **UAT iterations** — Phase 6 required multiple UAT fix commits (4 fix commits for voice improvement UAT); VAD complexity underestimated
- **Milestone archive was partial** — previous session completed MILESTONES.md and archives but did not finish PROJECT.md, RETROSPECTIVE, or tagging; required resume

### Patterns Established

- **`get_flags/0` upsert pattern** — `Repo.one(Flags) || %Flags{}` returns safe defaults on fresh install; detect insert vs update by `id == nil`
- **LiveView hook re-acquisition in `updated()`** — `this.el.querySelector()` in `updated()` handles LiveView DOM replacements without listener breakage
- **Stable input IDs** — prevents Hook event listener breakage on LiveView patches
- **`Presence.list(topic_string)` not `Presence.list(socket)`** — global topic check catches all tabs/connections for duplicate-join guard
- **`setSinkId` feature-detected at runtime** — Chromium/Electron only; Firefox no-op without crashing
- **Image URL regex splits BEFORE MDEx** — prevents image URLs being double-rendered as both `img` and anchor tag
- **`try/rescue` wraps Finch.request** — converts `ArgumentError` for invalid URL schemes (`javascript:`, bare words) into `{:error, :fetch_failed}`

### Key Lessons

1. **Scope active voice features explicitly in requirements** — Voice polish (VAD, device selection) should have been in REQUIREMENTS.md from the start; inserting Phase 6 late worked but surprised the plan structure
2. **Keep UAT scope tight per plan** — multi-feature UAT checkpoints (like 06-05 covering 6 VOIC requirements) compound fix iterations; smaller UAT scopes would reduce back-and-forth
3. **ROADMAP.md is documentation, STATE.md is truth** — don't rely on ROADMAP.md checkbox accuracy during execution; use SUMMARY.md + STATE.md for actual progress tracking
4. **Context-level patterns pay dividends** — the Elixir context module pattern (Accounts, Messages, FeatureFlags) made every new feature cleanly encapsulated; continue this in v1.1+
5. **`network_mode: host` for TURN on Linux is non-negotiable** — Docker NAT breaks relay; document this prominently for self-hosters

### Cost Observations

- Model mix: primarily Sonnet 4.6 (balanced profile)
- Sessions: multiple — resumed several times across 22 days
- Notable: plan execution was fast (avg 1.9 min/plan for tracked phases); most time was in planning, UAT iteration, and context restoration at session start

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Timeline | Phases | Plans | Key Change |
|-----------|----------|--------|-------|------------|
| v1.0 MVP  | 22 days  | 6      | 21    | First milestone — GSD structure established |

### Cumulative Quality

| Milestone | Tests | UAT Passes | Known Gaps |
|-----------|-------|------------|------------|
| v1.0 MVP  | Elixir mix test suite | All 6 phases UAT accepted | Code syntax highlighting deferred |

### Top Lessons (Verified Across Milestones)

1. Short plan scope (1-4 files) enables fast execution with low error rate
2. Runtime env vars with safe defaults prevent broken deploys on fresh installs
