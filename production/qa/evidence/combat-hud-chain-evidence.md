# QA Evidence: CombatHUD — Chain Dots (Story 004)

**Date**: [fill in when verified]
**Story**: production/epics/combat-hud/story-004-chain-dots.md
**AC**: AC-HUD-26 — floating damage label animation (manual only — physics/tween-dependent)
**Tester**: Kusuma Putra
**Sign-off gate**: ADVISORY — does not block headless CI, but must be closed before S3-11 playtest

---

## Verification Session

**Godot version**: 4.6.x
**Scene / Run context**: [describe how you triggered the test — e.g., "opened BattleScene, pressed F5, used keyboard to queue spell"]

---

## AC-HUD-26: Damage Label Float and Fade Animation

**Criterion**: On `spell_hit_element` + `damage_taken` firing, a floating damage label
appears at the enemy position, rises ~32 px, fades to transparent over ~0.8 s, then
is removed from the scene tree.

| Check | Result | Notes |
|-------|--------|-------|
| Damage label appears above enemy on spell hit | [ ] Pass / [ ] Fail | |
| Label rises approximately 32 px upward | [ ] Pass / [ ] Fail | |
| Label fades to fully transparent over ~0.8 s | [ ] Pass / [ ] Fail | |
| Label is gone from scene tree after ~1.0 s | [ ] Pass / [ ] Fail | |
| No orphan node warning in Output panel | [ ] Pass / [ ] Fail | |

---

## Chain Dot Visual Checks (bonus — unit-tested, but verify in-game)

| Check | Result | Notes |
|-------|--------|-------|
| Chain dot row visible during combat (combo_count ≥ 2) | [ ] Pass / [ ] Fail | |
| Active dot shows correct Prana primary-type color | [ ] Pass / [ ] Fail | |
| Inactive dots are gray (not Prana-colored) | [ ] Pass / [ ] Fail | |
| Chain dots hidden when preparation phase begins | [ ] Pass / [ ] Fail | |

---

## Overall Verdict

**AC-HUD-26**: [ ] PASS  [ ] FAIL

**Notes / observations**:
> (fill in)

**Sign-off**: _________________________________ Date: _____________
