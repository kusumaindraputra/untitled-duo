# Dev Plan: v0.9.0 → Beta Testing

**Created**: 2026-09-26
**Target**: closed beta on itch.io (Restricted page) opens **2026-11-30**
**Revised**: 2026-09-26, added a UI/UX and feature track (beta moved from 2026-11-16)
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

### Beta entry criteria (all must be true on 2026-11-27)

- [ ] At least 3 non-developer testers have played the current build, and every CRITICAL or HIGH
      finding from them is fixed or has a written reason why not
- [ ] A full run to the Keeper is possible on Windows, Linux and Web, with no crash, on keyboard
      **and** gamepad
- [ ] Median first-clear time from testers falls inside 15–25 min (or the target is revised on purpose)
- [ ] Every gamepad action can be rebound, and all menus are usable without a mouse
- [ ] A tester can say what their grid will cast **before** confirming it (grid legibility, the
      CRITICAL finding from the 2026-06-12 playtest)
- [ ] No placeholder or debug text is visible on any screen
- [ ] Save files carry a version and an old `progress.cfg` / `settings.cfg` loads without loss
- [ ] Web build: 60 fps in the busiest Floor 3 room on a mid laptop in Chrome and Firefox
- [ ] CI green, no skipped tests, content freeze in place
- [ ] itch page, screenshots, cover image and a feedback form are ready

---

## UI/UX and feature track

Found by looking at the current screens (main menu, prep phase, combat HUD, Settings, ending) and
the open findings from the last external playtest. IDs are used in the phases below.

### UI/UX

| ID | Change | Why | Size |
|----|--------|-----|------|
| U1 | **Spell preview in the prep panel**: before Confirm, show the spell the grid will cast (name, element, damage tier, secondary effect) and update it live as Prana moves | The 2026-06-12 tester could not tell combinations apart; this is still the biggest open finding | M |
| U2 | **Smaller prep panel**: shorter instructions with button icons, panel can shrink after Confirm, room stays visible | Panel covers a third of the room; the instruction line is two sentences of key names | S |
| U3 | **HUD pass**: framed HP bar with a hit flash, dash cooldown ring at Fayde's feet, clearer Special meter, a proper badge for the Style rank (now a bare `STYLE D` label), one visual style for the left column | HUD is plain labels and bars stacked top-left; dash cooldown was a playtest finding | M |
| U4 | **Floor map**: replace the letter row (`C C C E E R B`) with a small node map showing the branch, room icons and where Fayde is | Branch choice is a key decision, and letters do not show the fork | M |
| U5 | **Run summary screen** after death or win: time, rooms, room ranks, sigils taken, bosses beaten, shards earned, new memories, and a "Run again" button | End of run is a text overlay now; a summary is what makes "one more run" happen | M |
| U6 | **Pause shows your build**: current sigils with descriptions, the active grid and its spell | Players forget what they picked by Floor 2 | S |
| U7 | **Main menu layout**: a background (Fayde and the vault), Heirlooms moved to their own screen, clear order Play / Heirlooms / Memories / Settings / Quit | All systems are on one screen; the title screen has no art | M |
| U8 | **Button prompts follow the device** (keyboard or pad) across HUD, prep panel and menus | Needed anyway for full gamepad | S |
| U9 | **Screen feel**: fade between rooms and screens, UI sounds on focus and confirm, typewriter text on memories and endings | Cheap, makes every screen feel finished | S |

### Features

| ID | Feature | Why | Size |
|----|---------|-----|------|
| F1 | **Spellbook (codex)**: every Prana combination discovered so far, with its effect; plus sigils and enemies seen. Opens from the main menu and pause | Pairs with U1 to fix grid legibility; also a long-term goal to fill | M |
| F2 | **Assist options** in Settings: damage taken (50–100%), game speed (70–100%), auto-dash off/on. Runs with assist are marked on the summary | Bullet-hell difficulty is the most likely reason beta testers quit before the story ends | S |
| F3 | **Records**: best time, fastest boss kill per boss, total memories, shown in the summary and menu | Gives a goal after the first win; data already exists in the run | S |
| F4 | **More Heirlooms** (5 → 10) with a new unlock at each 3 memories found | Meta loop runs out after ~10 runs with 5 Heirlooms | S |
| F5 | Daily Run | Retention feature | M — **after beta** |
| F6 | Bahasa Indonesia | Text is in `ui_copy.gd` already, but a new feature adds strings every week | M — **after content freeze**, in beta |

Size: S about 1–2 days, M about 3–5 days for a solo dev with Claude.

---

## Phases

Five blocks. Each block ends with a build uploaded to the project `builds/` folder.

### Phase 1 — Alpha build, first playtest, first UX items (Sep 28 – Oct 11)

| # | Task | Notes |
|---|------|-------|
| 1.1 | Refresh tracking: close Sprint 9, write `sprint-11.md` from this plan | small |
| 1.2 | Self-play 3 full runs per platform, log bugs in `production/qa/bugs/` | covers S9-01 |
| 1.3 | Fix any crash or softlock found in 1.2 | must |
| 1.4 | **U1 spell preview + U2 smaller prep panel** | ship before the playtest so it is tested |
| 1.5 | **U3 HUD pass** | |
| 1.6 | Update the playtest guide: story fragments, endings, floor bosses, run length, spell preview | extends `playtest-guide-polish-pass.md` |
| 1.7 | Export **v0.10.0-alpha** and run the playtest with 2–3 new testers | closes S9-03 |
| 1.8 | Fix the stale Known Issues on the itch page | small |

### Phase 2 — Fix from playtest, full gamepad, run flow (Oct 12 – Oct 25)

| # | Task | Notes |
|---|------|-------|
| 2.1 | Fix every CRITICAL / HIGH playtest finding | first priority |
| 2.2 | Gamepad button rebinding in Settings (same swap rule as keys) | new ADR-0029 |
| 2.3 | Gamepad pass on every screen, then the ADR-0013 live gate on a real controller | closes S9-02 |
| 2.4 | **U8 device-aware prompts** | via `ui_copy.gd` |
| 2.5 | **U5 run summary screen + F3 records** | same data, one screen |
| 2.6 | **U4 floor map** | |

### Phase 3 — Features and menus (Oct 26 – Nov 8)

| # | Task | Notes |
|---|------|-------|
| 3.1 | **F1 Spellbook** | discovered combos saved in `progress.cfg` |
| 3.2 | **U6 pause shows your build** | reuses Spellbook entries |
| 3.3 | **U7 main menu layout** and Heirloom screen | |
| 3.4 | **F2 assist options** | `settings.cfg`, tests for the damage and speed scale |
| 3.5 | **F4 more Heirlooms** | data in `.tres` |
| 3.6 | Balance pass on run length and boss HP from playtest timings | done 2026-09-27 with the ADR-0051 bot; recheck in 4.5 |

Exit: **feature freeze**. From here no new features, only polish, fixes and tuning.

### Phase 4 — Hardening and second playtest (Nov 9 – Nov 22)

| # | Task | Notes |
|---|------|-------|
| 4.1 | Save versioning and migration for `progress.cfg` and `settings.cfg` | beta testers keep saves into 1.0 |
| 4.2 | **U9 screen feel** (fades, UI sounds, typewriter text) | |
| 4.3 | Performance pass on Web (busy Floor 3 rooms, Keeper phase 4) | `/perf-profile` |
| 4.4 | Soak test: 5 runs back to back, watch memory and orphan nodes | `/soak-test` |
| 4.5 | Second playtest with 2–3 new testers on v0.12.0, then fix its findings | checks U1–U8 actually help |

Exit: **content freeze**.

### Phase 5 — Beta candidate (Nov 23 – Nov 29)

| # | Task | Notes |
|---|------|-------|
| 5.1 | Cover image 630×500, fresh screenshots of the new UI, trailer GIF | |
| 5.2 | Feedback form link in the main menu and on the run summary | text via `ui_copy.gd` |
| 5.3 | `/release-checklist` and `/gate-check` for Beta | |
| 5.4 | Export **v0.95.0-beta**, itch page set to Restricted, devlog post | |

**Beta opens 2026-11-30.** Run it for three weeks, with a patch build each week. Bahasa
Indonesia (F6) can be built during beta, since text no longer changes.

---

## Decisions

| Question | Recommendation | Why |
|----------|----------------|-----|
| UI/UX and features before beta? | **Yes, U1–U9 and F1–F4**, beta moves two weeks to 2026-11-30 | Beta testers judge the first 5 minutes; the prep panel and HUD are what they see first |
| Full gamepad before beta? | **Yes** (Phase 2) | The store page already promises it |
| Daily Run before beta? | **No, after beta** | Beta needs to answer "is one run good?" first; the run seed from ADR-0028 makes it cheap later |
| Bahasa Indonesia before beta? | **During beta**, after content freeze | Translating while features still add text means doing it twice |
| Version numbers | 0.10 / 0.11 / 0.12 alpha, 0.95 beta, 1.0 release | Leaves room for weekly beta patches |

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| No testers available again (S9-03 carried 3 sprints) | Beta opens blind | Line up testers in week 1; the Web build removes install friction |
| Playtest shows the grid still is not legible even with U1 | Large rework | Phase 2 starts with fixes; F1 is the second line of help |
| Feature track grows | Beta slips again | Feature freeze at end of Phase 3 is fixed; anything new goes to after beta |
| Run is too long or too hard | Players quit before the story pays off | F2 assist options; tune in `.tres` only |
| Web performance on Floor 3 | Largest audience has the worst build | Profile in Phase 4, cap bullets per room if needed |
| Solo capacity | Phases slip | Cut in this order: F4, U9, U7, U4, F3. Never cut U1, 2.1, 4.1 or the playtests |

## After beta (not in this plan)

Daily Run, Bahasa Indonesia (if not finished in beta), Steam page, 1.0 launch.
