# Milestone: First Playable

**Target Date**: 2026-06-14
**Stage**: Production — First Playable internal playtest
**Author**: Kusuma Putra
**Created**: 2026-05-31

---

## What "First Playable" Means

A single complete combat encounter is playable from start to finish in Godot 4.6, with no manual editor intervention between launch and run end. The two-phase loop (Preparation → Combat) executes correctly, Fayde can win or lose, and the result screen loads. No persistent data, no meta-progression, no audio, no tutorial.

This is an internal playtest milestone — not a public build. The question it must answer: **"Is the core two-phase Preparation + Combat loop fun?"**

---

## Included at First Playable

| System | Scope | Governs |
|--------|-------|---------|
| Game State & Scene Flow | ✅ Complete | State machine, scene transitions, signals |
| Prana Data | ✅ Complete | 5 Prana types, full catalog, .tres files |
| Enemy Data | ✅ Complete | 3 active enemy types, catalog loaded |
| Player Controller | Sprint-2 Must Have | 8-dir movement, dash, flash-invincibility |
| Health & Damage | Sprint-2 Must Have | HP tracking, 4 zones, damage/heal signals |
| Enemy Instance (AI) | Sprint-2 Must Have | CHASING→DEAD, contact damage, queue_free() |
| Wave / Encounter System | Sprint-2 Must Have (via Enemy Instance) | 1 hardcoded wave, 10 enemies, win condition |
| Status Effects | Sprint-2 Should Have | Freeze + Burn (enables Shatter at playtest) |
| Combination Resolution | Sprint-2 Nice to Have | Full grid resolution; if slips → basic cast only |
| Combat HUD (minimal) | Sprint-2 Must Have dependency | HP bar + grid visible; no wave counter |
| Prana Grid | Sprint-2 Nice to Have (deferred — HIGH risk) | ADR-0013 engine verification required first |

---

## Excluded at First Playable

- Audio System (VS scope — deferred)
- Wave Peek preview panel (VS scope)
- Procedural dungeon generation (VS scope)
- Meta-progression, loot, save/load
- Prana Grid (HIGH engine risk — defer until ADR-0013 verified)
- Status effect icons on HUD, wave counter
- Any content beyond the single hardcoded arena

> **Prana Grid note**: PranaGrid epic is intentionally excluded from Sprint-2 due to ADR-0013 HIGH engine risk (dual-input focus model). Run `/story-readiness` on PranaGrid stories and verify ADR-0013 engine test before scheduling. If PranaGrid is not available at FP, the playtest uses keyboard shortcut casting as a placeholder.

---

## Exit Criteria

All of the following must be true before First Playable is declared:

### Hard criteria (all must pass)
- [ ] Launch the game from Godot → main.tscn loads without errors
- [ ] Preparation Phase: Fayde can arrange the Prana grid (or cast via shortcut if Grid not ready)
- [ ] Combat Phase starts on trigger: all 10 enemies spawn simultaneously
- [ ] Enemies move toward Fayde using direct vector movement (no navmesh required)
- [ ] Fayde can cast a spell and deal damage to enemies
- [ ] Elemental 2× affiliation bonus applies correctly (visible in damage numbers)
- [ ] Enemies deal contact damage to Fayde; HP bar updates in real time
- [ ] Fayde can reach 0 HP → DEAD state → result screen loads
- [ ] All 10 enemies can be killed → `all_waves_cleared` fires → result screen loads
- [ ] No infinite loop, no softlock, no crash during a complete run (start → result screen)
- [ ] All Must Have unit/integration tests pass headless (GdUnit4)

### Playtest validation criteria (checked after first playtest session)
- [ ] At least one player independently arranges the Prana grid with intent (not randomly)
- [ ] At least one player verbally identifies an elemental strategy without prompting
- [ ] All-Ashfire is not the first strategy reached by the tester (Charger → Deepfrost redesign validated)
- [ ] Prana-matching an enemy weakness (2× bonus) is discoverable without a tooltip within 5 minutes
- [ ] No confusion loop: tester does not get stuck without knowing why, longer than 30 seconds

### Advisory (not gate-blocking but tracked)
- [ ] Freeze (Status Effects Should Have) implemented → Shatter bonus fires correctly
- [ ] Combination Resolution implemented → full grid combo resolves

---

## Fun Hypothesis

> "If the player arranges Prana types in a 3×3 grid before a wave and then casts in combat, the act of deciding which combination to use — and having it work as planned — will feel like a meaningful, satisfying decision."

The First Playable playtest exists to validate or falsify this hypothesis. Evidence against it requires a design rethink before committing MVP scope.

---

## Open Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| PranaGrid not ready at FP (ADR-0013 engine verification) | Medium | High | Placeholder keyboard casting for playtest; verify ADR-0013 before scheduling PranaGrid epic |
| Status Effects slips to Sprint-3 | Low–Medium | Medium | Shatter won't fire; 2× affiliation still demonstrates depth; schedule Freeze as first story of Sprint-3 if slips |
| H&D takes >3 days | Medium | High | Monitor at day 2; defer Should Have (Status Effects) if needed |

---

## What Comes After

Once First Playable is validated:
1. `/gate-check production` → if fun hypothesis validated, advance toward MVP
2. Author Prana Grid stories, verify ADR-0013, schedule PranaGrid epic for Sprint-3
3. Run `/create-epics layer:feature` → WaveManager, procedural dungeon, Wave Peek
4. Sprint-3 planning
