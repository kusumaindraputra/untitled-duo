# Dev Plan: v0.9.0 → Beta Testing

**Created**: 2026-09-26
**Target**: closed beta on itch.io (Restricted page) opens **2026-11-16**
**Owner**: solo dev
**Starting point**: `main` @ 294c8f7 (PR #78 merged). Version in `project.godot` is 0.9.0.

---

## Where the game is now

Shipped and merged:

| Area | What exists | Source |
|------|-------------|--------|
| Core loop | Prana grid → combat, bullet patterns, Perfect Dodge / Cast, Special | earlier sprints |
| Run shape | 3 floors × 12 rooms (8 walked per floor, 24 per run), target 15–25 min | PR #77 |
| Run variety | 20 sigils, Challenge / Cursed rooms, Wayshrine trade | PR #75, ADR-0026 |
| Bosses | Vault Sentinel, Warped Warden, Cipher Keeper, 3 variants each from the run seed | PR #78, ADR-0028 |
| Story | 10 memory fragments, two endings, Memories archive | PR #76, ADR-0027 |
| Meta | Cipher Shards, Heirlooms, Hard Mode (`progress.cfg`) | ADR-0025 |
| Settings | Display, comfort, audio, keyboard rebinding (`settings.cfg`) | PR #75 |
| Builds | Windows / Linux / Web export presets, headless export works | `docs/build/demo-export.md` |
| Tests | ~1,500 GdUnit4 tests, CI on every PR | `.github/workflows/tests.yml` |

Still open:

- **No external playtest since 2026-06-12.** S9-03 has carried since Sprint 7. Nothing after the
  polish pass (story, 12-room floors, new bosses) has been seen by a non-developer.
- **Gamepad is partial.** Gamepad buttons cannot be rebound, and the ADR-0013 live gamepad gate
  (S9-02) was never run on a physical controller. The itch page already promises "Full keyboard
  and gamepad play".
- **Tracking is stale.** `sprint-status.yaml` still shows Sprint 9 (June).
- **itch page is out of date.** Its Known Issues say the story is not in the build; it is now.
- Not started: Daily Run, Bahasa Indonesia.

---

## What "Beta" means for this project

A build that a stranger can download from itch, play from the main menu to either ending without
help, and send useful feedback on. Content is complete for the first public release; beta is for
balance, bugs and clarity, not for new systems.

### Beta entry criteria (all must be true on 2026-11-13)

- [ ] At least 3 non-developer testers have played the current build, and every CRITICAL or HIGH
      finding from them is fixed or has a written reason why not
- [ ] A full run to the Keeper is possible on Windows, Linux and Web, with no crash, on keyboard
      **and** gamepad
- [ ] Median first-clear time from testers falls inside 15–25 min (or the target is revised on purpose)
- [ ] Every gamepad action can be rebound, and all menus are usable without a mouse
- [ ] Save files carry a version and an old `progress.cfg` / `settings.cfg` loads without loss
- [ ] Web build: 60 fps in the busiest Floor 3 room on a mid laptop in Chrome and Firefox
- [ ] CI green, no skipped tests, content freeze in place
- [ ] itch page, screenshots, cover image and a feedback form are ready

---

## Phases

Four two-week blocks. Each block ends with a build uploaded to the project `builds/` folder.

### Phase 1 — Alpha build and first new playtest (Sep 28 – Oct 11)

Goal: get the current game in front of new players as soon as possible.

| # | Task | Type | Notes |
|---|------|------|-------|
| 1.1 | Refresh tracking: close Sprint 9, write `sprint-11.md` from this plan | Docs | small |
| 1.2 | Self-play 3 full runs per platform, log bugs in `production/qa/bugs/` | QA | covers S9-01 |
| 1.3 | Fix any crash or softlock found in 1.2 | Fix | must |
| 1.4 | Update the playtest guide: add parts for story fragments, both endings, floor bosses and run length | Docs | extends `playtest-guide-polish-pass.md` |
| 1.5 | Tag and export **v0.10.0-alpha** (Win / Linux / Web) | Build | |
| 1.6 | Run the playtest with 2–3 testers who have not played; write `playtest-alpha-YYYY-MM-DD.md` | Playtest | closes S9-03 |
| 1.7 | Fix the stale Known Issues on the itch page | Docs | small |

Exit: a written playtest report and a triaged bug list.

### Phase 2 — Fix from playtest and full gamepad (Oct 12 – Oct 25)

| # | Task | Type | Notes |
|---|------|------|-------|
| 2.1 | Fix every CRITICAL / HIGH playtest finding | Fix | first priority |
| 2.2 | Gamepad button rebinding in Settings (same swap rule as keys) | Feature | new ADR-0029; tests in `tests/unit/settings/` |
| 2.3 | Gamepad pass on every screen: main menu, grid, sigil pick, Memories, pause, Settings, endings | UX | no mouse-only step |
| 2.4 | Run the ADR-0013 live gamepad gate on a real controller, save evidence | QA | closes S9-02 |
| 2.5 | Button prompts that follow the last device used (keyboard vs pad) | UX | via `ui_copy.gd` |
| 2.6 | Balance pass on run length and boss HP from playtest timings | Tuning | `.tres` only |

Exit: v0.11.0-alpha with gamepad complete.

### Phase 3 — Hardening and second playtest (Oct 26 – Nov 8)

| # | Task | Type | Notes |
|---|------|------|-------|
| 3.1 | Save versioning and migration for `progress.cfg` and `settings.cfg` | Feature | tests required; beta testers will keep saves into 1.0 |
| 3.2 | Performance pass on Web (busy Floor 3 rooms, Keeper phase 4) | Perf | `/perf-profile` |
| 3.3 | Soak test: 5 runs back to back, watch memory and orphan nodes | QA | `/soak-test` |
| 3.4 | Accessibility check: text size, flash / shake options, colour of bullets vs floor | UX | |
| 3.5 | Second playtest with 2–3 new testers on v0.12.0 | Playtest | checks the Phase 2 fixes worked |
| 3.6 | Bahasa Indonesia (optional, see decisions below) | Feature | only if 3.1–3.5 are done |

Exit: content freeze. From here only bug fixes and tuning.

### Phase 4 — Beta candidate (Nov 9 – Nov 15)

| # | Task | Type | Notes |
|---|------|------|-------|
| 4.1 | Fix second-playtest findings | Fix | |
| 4.2 | Cover image 630×500, fresh screenshots, trailer GIF | Store | |
| 4.3 | Feedback form link in the main menu and on the end screen | Feature | text via `ui_copy.gd` |
| 4.4 | `/release-checklist` and `/gate-check` for Beta | Gate | |
| 4.5 | Export **v0.95.0-beta**, itch page set to Restricted, devlog post | Release | |

**Beta opens 2026-11-16.** Run it for three weeks, with a patch build each week.

---

## Decisions

| Question | Recommendation | Why |
|----------|----------------|-----|
| Full gamepad before beta? | **Yes** (Phase 2) | The store page already promises it, and it is the one partial system left |
| Daily Run before beta? | **No, after beta** | It is a retention feature; beta needs to answer "is one run good?" first. The run seed from ADR-0028 already makes it cheap to add later |
| Bahasa Indonesia before beta? | **Only if time remains in Phase 3** | Text already goes through `ui_copy.gd`, so it is mostly writing. Move it up if the beta testers will be mostly Indonesian |
| Version numbers | 0.10 / 0.11 / 0.12 alpha, 0.95 beta, 1.0 release | Leaves room for weekly beta patches |

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| No testers available again (S9-03 carried 3 sprints) | Beta opens blind | Line up testers in week 1; the Web build removes install friction |
| Playtest shows the grid still is not legible | Large rework | Phase 2 is reserved for fixes before any new feature |
| Run is too long or too hard | Players quit before the story pays off | Tune in `.tres` only; `FloorTheme.room_count` can drop back if needed |
| Web performance on Floor 3 | Largest audience has the worst build | Profile in Phase 3, cap bullets per room if needed |
| Solo capacity | Phases slip | Cut 3.6, then 2.5, then 3.4 in that order; never cut 2.1, 3.1 or the playtests |

## After beta (not in this plan)

Daily Run, Bahasa Indonesia (if cut), Steam page, 1.0 launch.
