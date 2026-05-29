# Combat HUD (Minimal)

> **Status**: In Design
> **Author**: Kusuma Putra + Claude Code Game Studios
> **Last Updated**: 2026-05-29
> **Implements Pillar**: Pillar 3 (Chaos Has Consequences), Pillar 2 (Power is Earned Through Understanding)

## Overview

Combat HUD is the persistent feedback layer for The Last Cipher's two-phase combat cycle — a signal-driven overlay that translates gameplay state into player-readable information. It lives on a `CanvasLayer` above the game world, listens exclusively to signals from Health & Damage and Spell Casting & Effects, and never polls game state directly.

At First Playable scope, Combat HUD owns three display responsibilities: **(1) Fayde's HP display** — a visual bar with numeric readout (`current / max`) animated with smooth tweens on every `damage_taken` and `health_restored` event, shifting to an amber treatment when entering `HPZone.CAREFUL` (≤ 40 HP) and a red treatment on `HPZone.DESPERATE` (≤ 20 HP); **(2) Prana Grid layout boundary** — Combat HUD defines the screen region for the Prana Grid system's panel, ensuring it remains visible during both Preparation (editable) and Combat (locked, display-only) phases without being obscured by other HUD elements; **(3) floating damage numbers** — positioned over hit targets, color-coded by Prana type, appearing on every `damage_taken` event. All HUD elements combined occupy ≤ 20% of screen area during combat. Status effect icons, wave counter, and enemy HP bars are excluded at FP scope.

From the player's perspective, the Combat HUD's singular responsibility is clarity: the HP bar and zone color make the run's stakes legible at a glance. At 80 HP with a full-color bar, combat is confident. At 20 HP with a red critical bar and a Charger approaching, the visual state alone communicates the stakes. The HUD does not editorialize — it reports. The decisions belong to the player; the HUD ensures those decisions are made with accurate information.

## Player Fantasy

The player fantasy of Combat HUD is **the weight of information at the right moment**. The HUD is not an interruption — it is always there, peripheral, quiet. But when Fayde's HP bar drops into the amber zone mid-wave, that shift is not decoration. It is a signal: *something is wrong, and you need to respond.* The player who reads that transition correctly and adjusts their positioning has just used the HUD as a skill expression tool, not a passive readout.

The peak moment this system delivers is the **threshold read**: Fayde at 22 HP, one Charger rushing in, the bar a narrow sliver of red. The HUD has compressed the run's entire risk into a single visible state. The player knows — not because the game told them in words, but because the visual language of the bar communicates it instantly. That clarity under pressure is what the HUD exists to provide.

The secondary fantasy is **legibility of your own power**. Floating damage numbers in Prana type colors are not just numerical feedback — they are confirmation that the arrangement worked. A Stormgold strike landing a `23` in bright gold against a rust-grey robot is the moment of *"yes, that was the right read."* The numbers are the system translating the player's Preparation Phase decision into a visible, readable result.

The failure version matters equally: a Deepfrost spell landing a grey-white `16` on a non-affiliated enemy tells the player, without text or tutorial, that the elemental matchup wasn't optimal. The HUD's job is to make the feedback self-evident — not to explain it.

> *`creative-director` not consulted — Lean mode. Review manually before production.*

## Detailed Design

> *Specialist agents not consulted — Lean mode. Review manually before production.*

### Core Rules

**1. Node type and lifecycle.** Combat HUD is a `CanvasLayer` scene (layer 10 — above all 2D game nodes). It connects to signals in `_ready()`:
- `HealthAndDamage.damage_taken` → `_on_damage_taken(target, amount, current_hp)`
- `HealthAndDamage.health_restored` → `_on_health_restored(target, amount, current_hp)`
- `HealthAndDamage.player_died` → `_on_player_died()`
- `HealthAndDamage.player_hp_zone_changed` → `_on_hp_zone_changed(zone: HPZone)`
- `SpellCastingEffects.chain_index_changed` → `_on_chain_index_changed(combo_index, combo_attack_count)`
- `SpellCastingEffects.spell_hit_element` → `_on_spell_hit_element(target, prana_type_id)` *(new FP signal — see Rule 7)*
- `GameStateManager.combat_started` → `_on_combat_started()`
- `GameStateManager.preparation_started` → `_on_preparation_started()`
- `GameStateManager.run_started` → `_on_run_started()`

`process_mode = PROCESS_MODE_ALWAYS` — HUD updates during pause.

**2. Screen layout.** Four regions; Combat HUD owns regions 1 and 2 only:

| Region | Contents | Owner |
|--------|----------|-------|
| Top-left (≤15% screen width × ≤8% screen height) | HP bar + numeric readout + chain dots | Combat HUD |
| World overlay (floating) | Damage number labels | Combat HUD |
| Bottom-center/right (≤15% width × ≤20% height) | Prana Grid panel | Prana Grid system |
| Remaining (≥80%) | Arena / gameplay | Game world |

Total HUD footprint guarantee: ≤ 20% of screen area at any time.

**3. HP bar display.**
- `ProgressBar` or `TextureProgressBar` node at top-left. `value` = `fayde_current_hp`; `max_value` = `FAYDE_MAX_HP` (100).
- Numeric readout: `Label` showing `"%d / %d" % [current_hp, max_hp]`, updated immediately on each signal.
- **Animated fill**: HP changes tween the `value` property — drain duration `HP_BAR_DRAIN_DURATION = 0.15s`, fill duration `HP_BAR_FILL_DURATION = 0.20s`.
- **On heal**: bar fills with 0.20s tween AND green tint modulate `Color(0.6, 1.0, 0.6, 1.0)` applied for 0.20s then reverts. This satisfies H&D's healing audio silence conditions (see Rule 6).
- **Dead state**: on `player_died`, bar displays 0/max, no further HP updates.

**4. HP zone color treatment.** On `player_hp_zone_changed(zone)`:

| Zone | Bar Fill Color | Numeric Label |
|------|---------------|---------------|
| `FULL` | Normal (warm white — exact hex TBD with art-director) | White `#FFFFFF` |
| `CAREFUL` | Amber `#FFA500` modulate | Amber `#FFA500` |
| `DESPERATE` | Red `#FF3333` modulate | Red `#FF3333` |

Color transitions are **instantaneous** — the abrupt shift is the feedback signal. Zone resets to FULL on `run_started`.

**5. Cast chain indicator.** Visible only during Combat Phase when a SpellEffect is cached.
- N dots rendered below the HP bar, where N = `combo_attack_count` from the most recent `chain_index_changed`.
- **Active dot** (index `combo_index`): primary Prana type color (from `PranaCatalog.get_type(primary_type_id).color`).
- **Inactive dots**: dim grey `#888888`.
- On `preparation_started`: all dots hidden, state reset.
- On chain completion (index returns to 0 after reaching count): all dots reset to grey — ready for next press.
- If no `chain_index_changed` received since `combat_started`: dots remain hidden.

**6. Healing audio silence contract.** Combat HUD's heal tween (0.20s fill, Rule 3) and green tint (Rule 3) satisfy both of Health & Damage's conditions for omitting `sfx_fayde_heal` at FP scope:
1. ✓ Tween duration ≥ 0.15s (fill tween = 0.20s)
2. ✓ Distinct color shift (green tint distinguishable during active combat)

Therefore: `sfx_fayde_heal` is **not required at FP scope**. Audio System GDD must still register the `sfx_fayde_heal` event key before Vertical Slice scope.

**7. Floating damage numbers.** On every `damage_taken(target, final_damage, current_hp)` where `final_damage > 0`:
- Instantiate a `Label` at `target.global_position` (converted to viewport coordinates via `get_viewport().get_canvas_transform()`), parented to the CanvasLayer.
- Text: `str(final_damage)` (integer only).
- **Color:**
  - Enemy target + same-frame `spell_hit_element(target, prana_type_id)` received: use `PranaCatalog.get_type(prana_type_id).color`
  - Enemy target + no `spell_hit_element` in same frame: white `#FFFFFF` (neutral hit)
  - Fayde target (CONTACT damage): grey `#AAAAAA`
- **Animation:** float upward 32px over 0.8s, fade alpha 1.0→0.0 over the final 0.3s. Label `queue_free()` after tween.
- **Spawn jitter:** random X offset ±8px to prevent stacking on simultaneous hits.
- **Pool cap:** if ≥ 12 active label nodes exist, oldest is freed before spawning a new one (prevents label proliferation during Cluster swarms).

> ⚠ **SC&E GDD update required**: add signal `spell_hit_element(target: Node, prana_type_id: int)` — emitted on each hit where `prana_type_id != -1`. CONTACT hits from enemies never emit this signal. At MVP, when SC&E passes element through H&D properly, this FP signal can be removed.

**8. Prana Grid layout contract.** Prana Grid positions its panel in the bottom region (Rule 2). Combat HUD elements must not occupy that region. The grid panel's input lock during Combat Phase is triggered by `GameStateManager.combat_started` — owned by Prana Grid, not Combat HUD. This GDD documents the contract; Prana Grid GDD must implement it.

---

### States and Transitions

| State | HP Bar | Zone Color | Chain Dots | Damage Numbers |
|-------|--------|------------|------------|----------------|
| `PREPARATION` | Visible | Active | Hidden | None |
| `COMBAT` | Visible | Active | Visible (if spell cached) | Active |
| `DEAD` | 0/max frozen | Stays in last zone | Hidden | No new numbers |

- `preparation_started` → PREPARATION; chain dots hidden
- `combat_started` → COMBAT; chain dots shown on first `chain_index_changed`
- `player_died` → DEAD; HP bar frozen at 0/max; no further signal processing
- `run_started` → Full reset: HP bar to max, zone to FULL, chain dots hidden, all active damage number labels freed

---

### Interactions with Other Systems

| System | Interface | Direction |
|--------|-----------|-----------|
| **Health & Damage** | Listens for `damage_taken`, `health_restored`, `player_died`, `player_hp_zone_changed` | H&D → HUD |
| **Spell Casting & Effects** | Listens for `chain_index_changed(combo_index, combo_attack_count)` and `spell_hit_element(target, prana_type_id)` (new FP signal) | SC&E → HUD |
| **Combination Resolution** | Reads primary type ID via `SC&E.get_cached_spell_effect()` for chain dot color | HUD → SC&E (read) |
| **Game State & Scene Flow** | Listens for `combat_started`, `preparation_started`, `run_started` | GS&SF → HUD |
| **Prana Grid** | Screen region contract — HUD does not overlap Prana Grid panel region (Rule 8); Prana Grid locks on `combat_started` | Contractual |
| **Audio System** | Satisfies `sfx_fayde_heal` silence contract via heal tween + green tint (Rule 6) | Contractual |
| **Prana Data** | Reads Prana type colors via `PranaCatalog.get_type(id).color` for damage numbers and chain dots | HUD → Prana Data |

## Formulas

> *`systems-designer` not consulted — Lean mode. Review manually before production.*

Combat HUD derives no combat math — all damage, HP, and zone values come from upstream signals. This section documents display formulas that convert signal data into visual state.

---

### Formula 1: HP Bar Fill Fraction

`bar_fill_fraction = fayde_current_hp / FAYDE_MAX_HP`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Current HP | `fayde_current_hp` | int | 0 – `FAYDE_MAX_HP` | From `damage_taken` / `health_restored` signal `current_hp` parameter |
| Max HP | `FAYDE_MAX_HP` | int | 80 – 150 | Constant from Health & Damage GDD (default 100) |
| Bar fraction | `bar_fill_fraction` | float | 0.0 – 1.0 | Applied to `ProgressBar.value = bar_fill_fraction × max_value` |

**Output range:** 0.0 (dead) to 1.0 (full HP). Applied to `ProgressBar.value` via tween.

**Example:** HP drops from 100 to 60. `bar_fill_fraction = 60 / 100 = 0.60`. Tween drives `ProgressBar.value` from 100 to 60 over `HP_BAR_DRAIN_DURATION = 0.15s`.

---

### Formula 2: Damage Number Float Animation

`label_y_offset(t) = -DAMAGE_FLOAT_DISTANCE × (t / DAMAGE_FLOAT_DURATION)`  *(linear ascent)*
`label_alpha(t) = 1.0 - max(0.0, (t - DAMAGE_FADE_START) / (DAMAGE_FLOAT_DURATION - DAMAGE_FADE_START))`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Elapsed time | `t` | float | 0.0 – 0.8s | Seconds since label spawn |
| Float distance | `DAMAGE_FLOAT_DISTANCE` | float | 24–64px | Tuning knob; default 32px |
| Float duration | `DAMAGE_FLOAT_DURATION` | float | 0.5–1.5s | Tuning knob; default 0.8s |
| Fade start | `DAMAGE_FADE_START` | float | 0.3–0.7s | Tuning knob; default 0.5s — fade begins here |
| Vertical offset | `label_y_offset` | float | 0 – −32px | Label rises over full duration |
| Alpha | `label_alpha` | float | 0.0 – 1.0 | Begins fading at `DAMAGE_FADE_START`; fully transparent at `DAMAGE_FLOAT_DURATION` |

**Output:** Label rises 32px and fades to transparent over 0.8s, then `queue_free()`. Tween uses `TRANS_LINEAR` for position; `TRANS_CUBIC / EASE_IN` for alpha fade.

---

### Formula 3: Chain Dot Color Lookup

`dot_color(i) = PranaCatalog.get_type(primary_type_id).color   if i == combo_index`
`             = Color(0.533, 0.533, 0.533, 1.0)               otherwise (#888888 grey)`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Dot index | `i` | int | 0 – 2 | Which dot in the chain indicator |
| Active index | `combo_index` | int | 0 – 2 | Current position in chain from SC&E `chain_index_changed` |
| Primary type | `primary_type_id` | int | 0 – 4 | From `SC&E.get_cached_spell_effect().primary_type` |
| Active color | — | Color | Prana palette | `PranaCatalog.get_type(primary_type_id).color` |
| Inactive color | — | Color | `#888888` | `Color(0.533, 0.533, 0.533, 1.0)` |

**Output:** N colored dot nodes, all updated on each `chain_index_changed` signal.

## Edge Cases

> *`systems-designer` not consulted — Lean mode. Review manually before production.*

- **If `damage_taken` fires with `final_damage > 0` and a tween is already in progress** (rapid successive hits): cancel the current tween, start a new tween from the bar's current mid-animation value to the new target. Do not reset to the pre-hit value. No visible snap.

- **If `damage_taken` fires simultaneously for both Fayde and an enemy in the same frame**: both number labels spawn at their respective positions with their respective colors. No deduplication — the signals are distinct (different targets).

- **If `health_restored` fires while a drain tween is still in progress** (e.g., DoT tick immediately followed by Regen tick): cancel the drain tween, start fill tween from current mid-animation value. Green tint is applied at the fill tween start regardless of direction.

- **If `player_hp_zone_changed` fires with the same zone twice consecutively** (should not occur per H&D contract, but defensive): re-apply the zone color — no visible change, no error. Idempotent.

- **If `chain_index_changed(0, N)` fires but `get_cached_spell_effect()` returns null**: dot color cannot be looked up. Fall back to white `#FFFFFF` for the active dot. No error logged — can occur during rapid phase transitions.

- **If `run_started` fires while damage number labels are mid-animation**: all active labels are freed immediately (`queue_free()`). No partial animations carry into the next run.

- **If `run_started` fires while an HP bar tween is in progress**: cancel tween, immediately set bar to `FAYDE_MAX_HP`. Zone resets to FULL. No green tint — run reset is not a heal event.

- **If ≥ 12 damage number labels exist and another `damage_taken` fires**: the oldest label node (by spawn order) is freed immediately, then the new label spawns. The oldest label may be mid-animation — acceptable at FP scope.

- **If `spell_hit_element(target, prana_type_id)` fires but `damage_taken` for the same target is not received in the same frame** (abnormal): discard the element signal silently. No color state persists between frames.

- **If `combo_attack_count == 1` (T1 single-attack spell)**: chain indicator shows 1 dot. Active on cast, resets to grey when chain completes. Single dot is still drawn — visible confirmation the cast registered.

- **If the game is paused while an HP bar tween is in progress**: the Tween must use `Tween.TWEEN_PAUSE_PROCESS` so it continues running during SceneTree pause — consistent with `process_mode = PROCESS_MODE_ALWAYS`. Set explicitly at tween creation.

## Dependencies

### Systems This System Depends On

| # | System | What Combat HUD needs | Nature |
|---|--------|-----------------------|--------|
| 1 | **Health & Damage** (#6) | `damage_taken`, `health_restored`, `player_died`, `player_hp_zone_changed` signals; HP values delivered via signals — no polling | Hard |
| 2 | **Spell Casting & Effects** (#3) | `chain_index_changed(combo_index, combo_attack_count)` signal; `spell_hit_element(target, prana_type_id)` signal (new FP); `get_cached_spell_effect()` read-only for chain dot primary type | Hard (FP) |
| 3 | **Combination Resolution** (#2) | `primary_type` from `SpellEffect` — accessed via SC&E, not directly | Soft (via SC&E) |
| 4 | **Game State & Scene Flow** (#27) | `combat_started`, `preparation_started`, `run_started` signals for phase state | Hard |
| 5 | **Prana Data** (#4) | `PranaCatalog.get_type(id).color` for Prana type colors in damage numbers and chain dots | Hard |
| 6 | **Prana Grid** (#1) | Screen region contract — Prana Grid reserves the bottom region; locks input on `combat_started` | Contractual |

### Systems That Depend on Combat HUD

| System | What it needs | Nature |
|--------|--------------|--------|
| **Audio System** (#29) | This GDD confirms the heal tween (0.20s) and green tint satisfy H&D's `sfx_fayde_heal` silence conditions — Audio System may omit that event at FP scope | Contractual |

**Bidirectionality notes (update required):**
- Health & Damage GDD lists Combat HUD as a listener ✓ — no update needed
- **Spell Casting & Effects GDD** ⚠: add `spell_hit_element(target: Node, prana_type_id: int)` signal; add Combat HUD as downstream consumer in Interactions table
- **Prana Grid GDD** ⚠: add Combat HUD screen region contract (bottom region reserved); add `combat_started` input-lock requirement
- **Audio System GDD** ⚠: note that `sfx_fayde_heal` is conditionally omitted at FP scope per Combat HUD GDD Rule 6; must still register `sfx_fayde_heal` event key before Vertical Slice

## Tuning Knobs

| Knob | Constant Name | Default Value | Safe Range | What It Affects |
|------|---------------|---------------|------------|-----------------|
| HP bar drain speed | `HP_BAR_DRAIN_DURATION` | 0.15s | 0.05–0.40s | How fast the bar visually drops on damage. Below 0.05s = snap; above 0.40s = bar lag. Does NOT affect the sfx_fayde_heal contract (only fill matters) |
| HP bar fill speed | `HP_BAR_FILL_DURATION` | 0.20s | 0.10–0.50s | How fast bar rises on heal. Slightly slower than drain makes healing feel deliberate. **Minimum 0.15s required** for H&D sfx_fayde_heal silence contract |
| Heal green tint duration | `HEAL_TINT_DURATION` | 0.20s | 0.15–0.40s | How long green tint persists. **Minimum 0.15s required** for sfx_fayde_heal silence contract |
| Damage float distance | `DAMAGE_FLOAT_DISTANCE` | 32px | 16–64px | How far numbers rise. Too low = numbers stack on target; too high = numbers leave visible area |
| Damage float duration | `DAMAGE_FLOAT_DURATION` | 0.8s | 0.4–1.5s | Total visibility window per number. Below 0.4s may be unreadable for age 7+ audience |
| Damage fade start | `DAMAGE_FADE_START` | 0.5s | 0.2–0.8s | When alpha fade begins. Controls fully-opaque read window |
| Damage label pool cap | `DAMAGE_LABEL_POOL_CAP` | 12 | 6–20 | Max simultaneous floating labels. Too low = numbers drop during Cluster swarms |

**HP zone thresholds** (CAREFUL = 40 HP, DESPERATE = 20 HP) are **not HUD constants** — they are signalled via `player_hp_zone_changed(HPZone)` from Health & Damage. Combat HUD does not compute thresholds and must not define its own copies. The values above are reference documentation only.

## Visual/Audio Requirements

> *`art-director` not consulted — Lean mode. Review manually before production.*

**HP bar and zone treatment:**
- HP bar uses `ProgressBar` / `TextureProgressBar`. Pixel art style — 2px border, no rounded corners.
- **FULL zone color**: warm white `#F5F0E8` (art bible warm-neutral palette). Background fill: dark grey `#333333`.
- **CAREFUL zone color**: amber `#FFA500` modulate. Transition: instantaneous.
- **DESPERATE zone color**: red `#FF3333` modulate. Transition: instantaneous.
- Zone recovery transitions are equally instantaneous in both directions — clarity over aesthetics.
- **DESPERATE pulse animation**: HP bar scales 1.0 → 1.03 → 1.0 over 0.8s (looped while in DESPERATE zone). Stops immediately on zone exit. Draws peripheral attention without being distracting.

**Heal visual feedback:**
- On `health_restored`: green modulate tint `Color(0.6, 1.0, 0.6, 1.0)` for `HEAL_TINT_DURATION = 0.20s`, then reverts to current zone color. Satisfies H&D's `sfx_fayde_heal` audio silence contract.

**Numeric HP readout:**
- Font: monospace / tabular figures. Size: 16–18px at 1080p reference.
- Format: `"72 / 100"` — right-aligned numerics, slash separator.
- Color matches current zone (white → amber → red). Updates synchronously (no tween on the number — bar tweens, number snaps).

**Floating damage numbers:**
- Font: same pixel art font, bold. Size: 14–16px. 1px black outline for legibility.
- No drop shadow at FP scope. No size scaling at FP scope (deferred to MVP).
- Colors per Detailed Design Rule 7: Prana type color (elemental hit), white `#FFFFFF` (neutral enemy hit), grey `#AAAAAA` (Fayde CONTACT received).

**Chain dots:**
- Filled circles, 6px diameter, 4px gap between dots.
- Active dot: full-saturation Prana type color. Inactive dot: `#888888`.
- No border or outline at FP scope.

**Audio — HUD owned events:** None. Combat HUD does not emit audio events directly. Its only audio contract is confirming the heal tween/tint satisfies H&D's silence conditions for `sfx_fayde_heal` (Rule 6, Section C).

**Art Bible compliance:**
- CAREFUL `#FFA500` and DESPERATE `#FF3333` must remain visually distinct from all 5 Prana type colors and from each other. Art-director sign-off required before production.
- Principle 1 (Serene World, Violent Magic): HUD chrome at FULL zone should be quiet and warm-neutral. The zone shift is the dramatic signal — not the default state.
- Principle 2 (Every Prana Type Has a Color Name): damage numbers and chain dots must use exact hex values from Prana Data registry. No approximations.

> 📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:combat-hud` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## UI Requirements

> 📌 **UX Flag — Combat HUD**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for the HUD screen (`design/ux/hud.md`) **before** writing epics. Stories that reference Combat HUD layout should cite `design/ux/hud.md`, not this GDD directly.

**Layout at 1920×1080 reference resolution:**

```
Screen (1920 × 1080)
┌──────────────────────────────────────────────────────────┐
│ [HP BAR region — top-left, ≤288px × ≤86px]              │
│  ┌─────────────────────┐  72 / 100                       │
│  │ ■■■■■■■■■■■■░░░░░░ │  ← ProgressBar (192×14px)       │
│  └─────────────────────┘                                  │
│  ● ○ ○  ← chain dots (shown during COMBAT only)          │
│                                                           │
│       [ARENA / GAME WORLD — ≥80% of screen]              │
│                                                           │
│            [floating damage numbers — transient overlay]  │
│                                                           │
│                            ┌──────────────────────────┐  │
│                            │   PRANA GRID PANEL       │  │
│                            │   (Prana Grid system)    │  │
│                            │   ≤288px × ≤216px        │  │
│                            └──────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

| Element | Dimensions | Position | Notes |
|---------|------------|----------|-------|
| HP bar (`ProgressBar`) | 192×14px | Top-left, 8px margin | 2px border; `max_value = FAYDE_MAX_HP` |
| Numeric readout (`Label`) | 72×18px | Right of HP bar | Monospace, 16–18px font |
| Chain dots row | N × 6px circles + gaps | 8px below HP bar | Hidden during PREPARATION |
| Prana Grid panel | ≤288×216px | Bottom-right reserved | Owned by Prana Grid system |
| Floating damage labels | 40×20px each (approx.) | World-space → viewport | Transient; pool cap = 12 |

**Total HUD footprint:** HP region (~3.6% of 1080p) + transient labels ≪ 20% screen area. ✓

**Scale guidance for non-1080p:** Use Godot anchor presets and `CanvasLayer` stretch — no hardcoded pixel positions. All element sizes should scale proportionally with viewport size.

**Accessibility note:** HP bar state (full, careful, desperate) relies on color alone. At Vertical Slice scope, add a secondary signal — texture pattern or icon — so the zone state is readable without color. Deferred; document here as a known gap.

**Prana Grid layout contract:** The bottom-right region (15% width × 20% height) is reserved for the Prana Grid panel. Combat HUD must not place any persistent element in this region. Floating damage number labels may briefly overlap it during combat — accepted at FP scope.

## Acceptance Criteria

> *`qa-lead` consulted — Lean mode. 3 blocking defects and 2 blocking coverage gaps resolved from initial draft.*

Classification: **[U]** = Unit test (GUT, headless) | **[M]** = Manual QA (visual or timing-dependent)

---

**AC-HUD-01 [U]** — HP bar value updates after drain tween
GIVEN Fayde at `current_hp=100`; `damage_taken(fayde, 20, 80)` fires
WHEN `HP_BAR_DRAIN_DURATION` (0.15s) has elapsed (drive via `_process` accumulation)
THEN `ProgressBar.value == 80`

**AC-HUD-02 [U+M]** — HP bar drain is animated
(a) [U] `assert HP_BAR_DRAIN_DURATION == 0.15` in HUD `_ready()` — constant guard ensures the contract is not broken by accidental tuning to 0.
(b) [M] Visual: HP bar visibly interpolates (no snap) during a damage hit. Confirm by eye during manual combat session.

**AC-HUD-03 [U]** — Numeric readout updates immediately (no tween)
GIVEN `damage_taken(fayde, 20, 80)` fires
WHEN signal processed (same frame)
THEN `hp_label.text == "80 / 100"`

**AC-HUD-04 [U]** — Zone CAREFUL: amber on bar AND label
GIVEN current zone = FULL; `player_hp_zone_changed(HPZone.CAREFUL)` fires
WHEN processed
THEN bar fill modulate == `Color("#FFA500")`; numeric label color == `Color("#FFA500")`

**AC-HUD-05 [U]** — Zone DESPERATE: red on bar AND label
GIVEN current zone = CAREFUL; `player_hp_zone_changed(HPZone.DESPERATE)` fires
WHEN processed
THEN bar fill modulate == `Color("#FF3333")`; numeric label color == `Color("#FF3333")`

**AC-HUD-06 [U]** — Zone FULL: warm white on bar AND label
GIVEN current zone = DESPERATE; `player_hp_zone_changed(HPZone.FULL)` fires
WHEN processed
THEN bar fill modulate == `Color("#F5F0E8")`; numeric label color == `Color("#FFFFFF")`

**AC-HUD-07 [U]** — DEAD state: all HP-related signals ignored
GIVEN `player_died` fires (ProgressBar.value == 0)
WHEN `damage_taken(fayde, 10, 0)`, `health_restored(fayde, 6, 6)`, and `player_hp_zone_changed(HPZone.FULL)` each fire subsequently
THEN ProgressBar.value remains 0 AND bar fill modulate does NOT change for any of the three subsequent signals

**AC-HUD-08 [U]** — health_restored: fill tween AND green tint fire
GIVEN HP bar at 60; `health_restored(fayde, 6, 66)` fires
WHEN processed
THEN ProgressBar is tweening toward 66 (value between 60–66 before tween completes); modulate == `Color(0.6, 1.0, 0.6, 1.0)` at tween start; after `HEAL_TINT_DURATION` (0.20s), modulate == current zone color (NOT green)

**AC-HUD-09 [U]** — Fill tween constant satisfies audio silence contract
WHEN HUD loads
THEN `assert HP_BAR_FILL_DURATION >= 0.15` — verifies `sfx_fayde_heal` silence condition cannot be broken by tuning

**AC-HUD-10 [U]** — Chain dots appear with correct Prana color
GIVEN SC&E has cached SpellEffect with `primary_type == 2` (Stormgold); `preparation_started` received; `combat_started` fires; `chain_index_changed(0, 2)` fires
WHEN processed
THEN chain dots node is visible; 2 dots drawn; dot[0] color == `Color("#FFCC00")`; dot[1] color == `Color("#888888")`

**AC-HUD-11 [U]** — Chain dots advance on next chain_index_changed
GIVEN chain dots visible (combo_attack_count=2, primary_type=0 Ashfire); `chain_index_changed(1, 2)` fires
WHEN processed
THEN dot[1] color == `Color("#F24C1D")`; dot[0] == `Color("#888888")`

**AC-HUD-12 [U]** — Chain dots hidden on preparation_started
GIVEN chain dots visible during COMBAT; `preparation_started` fires
WHEN processed
THEN chain dots node is NOT visible

**AC-HUD-13 [U]** — Damage label spawns on damage_taken > 0
GIVEN `damage_taken(enemy_node, 25, 10)` fires
WHEN processed
THEN a Label node exists as CanvasLayer child; text == "25"

**AC-HUD-14 [U]** — Elemental hit: Prana color assigned via same-frame spell_hit_element
GIVEN: emit `spell_hit_element(enemy_node, 2)` (Stormgold) AND `damage_taken(enemy_node, 23, 12)` before `await get_tree().process_frame`
WHEN frame processed
THEN spawned label color == `Color("#FFCC00")` (Stormgold)

**AC-HUD-15 [U]** — Target mismatch: wrong-target element signal = white label
GIVEN: emit `spell_hit_element(enemy_A, 2)` AND `damage_taken(enemy_B, 16, 10)` (enemy_B ≠ enemy_A) before `await get_tree().process_frame`
WHEN frame processed
THEN label for enemy_B color == `Color("#FFFFFF")` (element signal for enemy_A is not applied to enemy_B)

**AC-HUD-16 [U]** — Neutral hit: white label
GIVEN `damage_taken(enemy_node, 16, 10)` fires; no `spell_hit_element` for this target in same frame
WHEN label spawns
THEN label color == `Color("#FFFFFF")`

**AC-HUD-17 [U]** — Fayde-received: grey label at Fayde's position
GIVEN `damage_taken(fayde_node, 20, 80)` fires
WHEN label spawns
THEN label color == `Color("#AAAAAA")`; label position derived from `fayde_node.global_position`

**AC-HUD-18 [U]** — Pool cap: 13th label evicts oldest before spawning
GIVEN 12 Label nodes active as CanvasLayer children; `damage_taken` fires
WHEN new label spawns
THEN oldest label was freed BEFORE new spawn; active label count ≤ 12

**AC-HUD-19 [U]** — Pool below cap: no eviction
GIVEN 5 Label nodes active (below cap of 12); `damage_taken` fires
WHEN new label spawns
THEN no existing label freed; CanvasLayer has 6 label children

**AC-HUD-20 [U]** — run_started cancels active tween and resets to max
GIVEN HP bar is mid-drain-tween (animating toward 60); `run_started` fires
WHEN processed
THEN `ProgressBar.value == FAYDE_MAX_HP` (100) immediately; no further tween toward 60

**AC-HUD-21 [U]** — run_started resets zone, hides dots, frees labels
GIVEN zone = DESPERATE; 3 Label nodes active; chain dots visible; `run_started` fires
WHEN processed
THEN bar modulate == `Color("#F5F0E8")`; chain dots hidden; all 3 prior Labels freed

**AC-HUD-22 [U]** — Mid-tween rapid hit: new tween starts from current bar value
GIVEN HP bar is mid-drain-tween; `V_mid = ProgressBar.value` read immediately before second signal; `damage_taken` fires with new target value `V_new < V_mid`
WHEN new tween starts
THEN tween start value == `V_mid` (not the original pre-hit value of 100)

**AC-HUD-23 [U]** — Heal tint reverts to zone-specific color
GIVEN zone = DESPERATE (bar red); `health_restored(fayde, 6, 26)` fires; `HEAL_TINT_DURATION` elapses
WHEN tint reverts
THEN modulate == `Color("#FF3333")` (DESPERATE zone color — not warm white)

**AC-HUD-24 [M]** — DESPERATE pulse animation active while in zone
GIVEN `player_hp_zone_changed(HPZone.DESPERATE)` fires
WHEN 0.8s elapses
THEN HP bar has visibly pulsed (scale 1.0→1.03→1.0 cycle). [M] — confirm visually or via exposed `is_pulse_active() → bool`.

**AC-HUD-25 [U or M]** — DESPERATE pulse stops on zone exit
GIVEN HP bar pulsing in DESPERATE zone; `player_hp_zone_changed(HPZone.CAREFUL)` fires
WHEN processed
THEN `bar.scale == Vector2(1.0, 1.0)`. [U] if pulse tween stored as named class member; [M] otherwise.

**AC-HUD-26 [M]** — Damage label float and fade animation
GIVEN a damage label spawns at enemy position
WHEN 0.8s elapses
THEN label position has risen ~32px from spawn Y AND label alpha ≈ 0.0 AND label is freed. [M] — visual scene required.

---

*Coverage: AC-HUD-01–03 = Rule 3 (HP bar); AC-HUD-04–06 = Rule 4 (zone colors); AC-HUD-07 = DEAD state; AC-HUD-08–09 = Rules 3+6 (heal tween + audio contract); AC-HUD-10–12 = Rule 5 (chain dots); AC-HUD-13–19 = Rule 7 (damage numbers including pool cap and target-mismatch); AC-HUD-20–22 = edge cases (run reset + mid-tween); AC-HUD-23 = Formula 2 (zone-specific tint revert); AC-HUD-24–25 = Visual/Audio (pulse animation); AC-HUD-26 = Formula 2 (float animation).*

## Open Questions

1. **HP bar visual style (art-director sign-off pending)** — FULL zone color `#F5F0E8` is a warm white placeholder. Exact pixel art treatment (border style, fill pattern, inner glow) needs art-director review before production. *Owner: art-director.*

2. **Damage number font** — GDD specifies monospace/tabular-figures bold pixel font but does not name the font asset. Must be consistent with Main Menu and Run Summary UI. *Owner: art-director / UI implementation. Target: before Combat HUD implementation sprint.*

3. **Prana Grid reserved region dimensions** — Combat HUD documents ~288×216px reserved bottom-right region. Prana Grid GDD must confirm exact panel dimensions for the layout contract to be bidirectionally consistent. Currently provisional. *Owner: Prana Grid GDD update.*

4. **`spell_hit_element` MVP removal plan** — At FP scope, SC&E emits this signal as a workaround for inlined element check (Step 9). At MVP, when SC&E passes element through H&D, this signal is redundant. Requires coordinated removal in SC&E, H&D, and Combat HUD. *Owner: SC&E GDD MVP update.*

5. **Damage number font size scaling** — GDD defers size scaling by damage magnitude to MVP. When added, the scaling curve (linear? stepped thresholds?) needs to be specified in the MVP design pass. *Owner: Combat HUD GDD MVP update.*

6. **Accessibility: color-blind mode for zone treatment** — Zone transitions rely solely on color. A secondary visual signal (texture, icon, or pattern) is noted as a VS gap in UI Requirements. *Owner: `/ux-design` and accessibility review at VS tier.*
