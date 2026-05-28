# Health & Damage

> **Status**: In Review
> **Author**: Kusuma Putra + Claude Code Game Studios
> **Last Updated**: 2026-05-28 (revised after design-review round 3 — 16 blockers resolved)
> **Implements Pillar**: Pillar 3 (Chaos Has Consequences), Pillar 2 (Power is Earned Through Understanding)

## Overview

Health & Damage is the combat resource layer for The Last Cipher. It tracks two distinct HP pools: **Fayde's health** (a single shared pool initialized to 100 HP at run start) and **each enemy instance's health** (initialized from Enemy Data `base_hp` at spawn). When damage is applied to either pool, this system calculates the final damage value — accounting for the incoming base damage and any elemental modifiers from Elemental Affiliation & Weakness — subtracts it from the target's current HP, and emits the resulting state as signals. No other system stores HP values; all HP state lives here.

The system manages four events that other systems depend on: **damage taken** (HP decreased, Combat HUD updates, hit flash triggered), **death** (HP reaches zero or below, death signal emitted to Game State & Scene Flow and Audio System), **healing** (HP increased by Verdant Prana regen, capped at max HP), and **enemy killed** (enemy HP reaches zero, Prana Drop / Loot and Wave / Encounter System are notified). Damage-over-time effects (Burn from Ashfire) are applied as ticks by Status Effects, which calls back into Health & Damage for each tick application — Health & Damage does not own tick timing, only the application of damage values.

On the player side, Health & Damage is the system that makes the roguelike stakes tangible: Fayde has one HP pool per run, healing is available only through deliberate grid investment in Verdant Prana, and death is permanent for the run. The scarcity of HP recovery is player-chosen — a player who slots Verdant trades offensive grid space for a modest heal (6 HP per cast, intentionally isolated-weak — see Tuning Knobs). The weight of surviving is highest when the player chose not to slot Verdant, and sharpest when they did and 6 HP wasn't enough. On the enemy side, it's what makes elemental affiliation matter — a Charger with 35 HP hit by an Ashfire spell with a 1.25× modifier takes more than a neutral-affiliation hit would.

## Player Fantasy

The fantasy of Health & Damage is **the weight of surviving**. Fayde's HP isn't a number — it's the thickness of the thread. At 80 HP, combat is confident. At 40 HP, it becomes careful. At 20 HP, every enemy movement is a potential run-ender, and the Prana grid arrangements from the last Preparation phase suddenly feel very deliberate or very wrong.

The system delivers two peak moments. The first is **the clean run** — waves cleared, HP barely touched, which tells the player they read the elemental matchups correctly and positioned well. The enemy catalog worked as a legible threat; the player parsed it. This is Pillar 2 (*Power is Earned Through Understanding*) working. The second is **the desperate win** — finishing a wave at 12 HP, one Charger charge away from death, scrambling into the next Preparation phase with the knowledge that everything they do next has to count. This is Pillar 3 (*Chaos Has Consequences*) working.

On the enemy side, the fantasy is *feedback legibility*: the Charger should feel dangerous (35 HP, 20 base damage), the Cluster should feel fragile (12 HP, 4 base damage — dies in one focused hit). A player who has learned the catalog feels competent for knowing which enemy demands their full attention and which they can dispatch carelessly. Health & Damage is the system that makes that knowledge feel like *power*. The `heavy_hit` signal (Rule 2, step 7a) is the connective tissue for this — it is what Game Feel / Juice keys off to add hit-stop and impact weight that makes a 20-damage Charger hit feel categorically different from a 4-damage Cluster hit.

**Known Design Tension — Verdant viability**: Verdant's 6 HP heal is intentionally weak in isolation against the primary threat (Charger deals 20 damage per hit). Verdant derives full strategic value through Combination Resolution grid combo bonuses, not through raw heal output alone. This is a deliberate depth-over-breadth choice: Verdant is not a substitute for damage, but a specialist pick for sustained engagements where combo bonuses amplify its utility. If Combination Resolution does not deliver combo bonuses that make Verdant competitive, this design must be revisited.

## Detailed Design

### Core Rules

1. **Two HP pools, different owners**: Fayde has one shared HP pool for the entire run (`fayde_current_hp`, max = `FAYDE_MAX_HP` = 100). Each spawned enemy has its own per-instance `current_hp`, initialized from its Enemy Data `base_hp` at spawn. Health & Damage tracks both; no other system stores HP state.

2. **Damage application pipeline** (applies to both Fayde and enemy instances):
   1. Receive damage event: `apply_damage(target, base_damage: float, element: DamageClass | null, source: DamageSource)`
      - `DamageSource` enum: `CONTACT` (Enemy AI hit), `DOT` (Status Effects tick), `DIRECT` (anything else not subject to i-frames)
   1a. **Dash invincibility guard (Fayde + CONTACT only)**: If `target == fayde AND source == DamageSource.CONTACT`: query `PlayerController.is_invincible() -> bool` (accessed via `get_tree().get_first_node_in_group(&"player")` or an equivalent typed reference). If `true`, return immediately — no damage, no signal emitted. Covers Fayde's dash i-frame window (`DASHING` state in Player Controller) — distinct from Rule 3's post-hit i-frame window, which H&D manages internally via its own flag.
   2. **Dead-target guard**: If target is in `DEAD` state (`current_hp <= 0`), return immediately — no processing, no signal. *(Uses `<= 0` to match the state table definition of DEAD; the clamp in step 7 guarantees `current_hp` never goes negative in normal execution, but `<= 0` is the authoritative guard.)*
   2b. **I-frame check (Fayde + CONTACT only)**: If `_iframe_active AND source == DamageSource.CONTACT AND target == fayde`: return immediately — no damage, no signal emitted. *(Distinct from the dead-target guard: target is alive here; i-frame is a separate INVINCIBLE state, not the DEAD state. Checked before elemental multiplier lookup to avoid unnecessary EA&W calls on blocked hits.)*
   3. If `element != null` → request `damage_multiplier: float` from Elemental Affiliation & Weakness
   4. If `element == null` → `damage_multiplier = 1.0`
   5. `final_damage = clamp(roundi(base_damage × damage_multiplier), 0, target.max_hp)` *(rounded to nearest int via `roundi()` — round-half-away-from-zero; clamped so final_damage never exceeds max_hp — prevents misleadingly large overkill values in signals)*
   6. **First-run mercy** (Fayde + CONTACT only): If `target == fayde AND source == CONTACT AND first_run_active`: `final_damage = clamp(roundi(float(final_damage) × FIRST_RUN_DAMAGE_MULTIPLIER), 0, target.max_hp)`. `first_run_active` is a flag set by Tutorial/Onboarding (on `run_started`) for the player's first lifetime run. Default multiplier is 0.5 (halves contact damage on the first run). See Tuning Knobs. *(This is H&D's contract; Tutorial/Onboarding GDD owns the lifecycle of the `first_run_active` flag.)*
   7. `target.current_hp = clamp(target.current_hp - final_damage, 0, target.max_hp)`
   8. If `final_damage > 0`: emit `damage_taken(target, final_damage, target.current_hp)` *(zero-damage hits do not emit — prevents spurious hit flash and SFX for blocked or zero-source events)*
   9. If `final_damage >= HEAVY_HIT_THRESHOLD` AND `final_damage > 0`: emit `heavy_hit(target, final_damage)`. Game Feel / Juice listens and applies hit-stop and screen shake scaled to hit weight. This is the mechanic that differentiates a 20-damage Charger hit from a 4-damage Cluster hit at the feel level.
   10. If `target.current_hp <= 0` → trigger death (see Rule 5) — only reached if target was alive at step 2

3. **Invincibility frames (Fayde only)**: After Fayde takes a hit with `source = DamageSource.CONTACT` **and `final_damage > 0`**, a `FAYDE_IFRAME_DURATION` window (default 0.5s) opens during which any subsequent `apply_damage` call with `source = CONTACT` is blocked at pipeline step 2b (i-frame check) — no damage, no signal. A zero-damage CONTACT call (`base_damage = 0.0` or `damage_multiplier = 0.0`) does NOT arm i-frames. The i-frame check uses `source`, not `element`, so `element = null` contact hits are correctly blocked and `element = null` DoT ticks are correctly passed through. The i-frame window does NOT block: `source = DOT` ticks from Status Effects, `source = DIRECT` damage, or any healing call. I-frames are re-triggered on each qualifying CONTACT hit (with `final_damage > 0`) after the previous window expires.

   **Test seam**: The implementation MUST expose `force_end_iframe_window() -> void` as a public method. Behaviour: immediately cancels the active i-frame timer and sets `_iframe_active = false`. No-op if no window is active. This is a test seam only — not callable from gameplay code. Required to make AC-HD-07 and AC-HD-33 executable in a headless GUT test.
   - *Note: i-frame lower bound (0.2s) is only safe if Enemy AI enforces a minimum inter-contact interval on Cluster units. Without that constraint, 0.2s may be effectively no protection in swarm scenarios. See Dependency #5.*

4. **Heal application**: `apply_heal(target, heal_amount: float)`
   - **Precondition guard**: If `heal_amount <= 0`, log an error and return immediately — callers must use `apply_damage` for damage. Negative values passed to `apply_heal` would silently reduce HP with no death signal (Fayde zombie state).
   - `target.current_hp = int(round(clamp(target.current_hp + heal_amount, 0, target.max_hp)))` — `round()` is used before `int()` cast to avoid silent truncation: `int(0.8) = 0` would silently deliver zero healing at low magnitudes; `round(0.8) = 1` preserves small-but-nonzero heals. The outer `int()` cast is required because GDScript widens `int + float = float`.
   - Cannot overheal — HP is capped at max.
   - If the effective heal (`new_current_hp - old_current_hp`) is 0 (target was already at max HP), emit no signal.
   - Otherwise emit `health_restored(target, healed_amount: int, target.current_hp: int)` where `healed_amount = new_current_hp - old_current_hp`.
   - Verdant Prana regen is the only MVP heal source. VS adds rest rooms and items as additional heal sources via the same interface.

5. **Death events**:
   - **Enemy death**: When enemy `current_hp <= 0` → emit `enemy_killed(enemy_instance_id, enemy_type_id, prana_affiliation: DamageClass)`. The `prana_affiliation` value is the enemy's elemental affiliation from Enemy Data, using the **same `DamageClass` enum as the damage system**. Neutral (unaffiliated) enemies use `DamageClass.NONE` (value = −1) as the sentinel — do NOT pass `null`; GDScript typed signals do not support union types. Enemy node is not freed here — Enemy AI and Wave / Encounter System handle the death sequence (animation, cleanup). Health & Damage only emits the signal. **Node-lifetime guarantee**: Enemy AI must not free the enemy node until at least one frame after `enemy_killed` is emitted — this ensures Prana Drop / Loot can resolve position via `instance_from_id()` in the same frame. **Caller guard**: Despite this guarantee, the contract applies to `queue_free()` only — immediate `free()` or a deferred signal connection can violate it. Prana Drop / Loot MUST guard with `is_instance_valid(instance_from_id(enemy_instance_id))` before accessing any property on the resolved node. This guard is required defensive code, not optional.
   - **Fayde death**: When Fayde `current_hp <= 0` → emit `player_died`. Game State & Scene Flow transitions to `DEATH_SCREEN`. This signal fires exactly once per run — not re-emitted if HP stays at 0.
   - **Same-frame death ordering**: If both an enemy and Fayde reach `current_hp <= 0` in the same frame (e.g., a DoT tick kills Fayde while the last wave enemy is simultaneously killed), `enemy_killed` is emitted before `player_died`. Game State & Scene Flow must treat `player_died` as taking priority over any in-flight win condition — a run ending in simultaneous kill-and-death resolves as a player death.

6. **DoT/HoT delegation**: Health & Damage does NOT own tick timing. Status Effects owns the timer for Burn, Regen, and other timed effects. For each tick, Status Effects calls:
   - `apply_damage(target, tick_damage, null, DamageSource.DOT)` — `source = DOT` bypasses the i-frame check; no elemental multiplier on ticks (damage already calculated by Status Effects using `burn_total` formula from Prana Data)
   - `apply_heal(target, tick_heal)` — for Verdant Regen ticks

7. **Run reset**: On `run_started` signal from Game State & Scene Flow, Health & Damage: (a) resets Fayde's HP to `FAYDE_MAX_HP`, (b) resets `_current_zone` to `HPZone.FULL`, and (c) emits `player_hp_zone_changed(HPZone.FULL)` unconditionally — regardless of the zone at run end. Step (c) is required to synchronise Audio System and Combat HUD zone state at the start of each new run; without it, a run that ended in DESPERATE zone would leave those systems in critical state at full HP. Enemy HP instances are created fresh at spawn and require no run-level reset.

8. **No HP persistence**: Fayde's HP does not carry between runs. Enemy HP is per-instance — no enemy survives between waves.

9. **HP zone signals (Fayde only)**: Health & Damage emits `player_hp_zone_changed(zone: HPZone)` whenever Fayde's HP crosses a zone boundary in **either direction** (entering a lower zone on damage, entering a higher zone on healing). `HPZone` is a GDScript enum with values: `FULL`, `CAREFUL`, `DESPERATE`.

   Zone boundaries are **percentage-based** against `FAYDE_MAX_HP`:
   - `FULL`: `current_hp > FAYDE_MAX_HP × FAYDE_HP_CRITICAL_CAREFUL` (above 40% at default)
   - `CAREFUL`: `current_hp ≤ FAYDE_MAX_HP × FAYDE_HP_CRITICAL_CAREFUL` AND `current_hp > FAYDE_MAX_HP × FAYDE_HP_CRITICAL_DESPERATE` (between 40% and 20% at default)
   - `DESPERATE`: `current_hp ≤ FAYDE_MAX_HP × FAYDE_HP_CRITICAL_DESPERATE` (at or below 20% at default)

   The signal fires once per zone transition — not continuously while HP stays within a zone. All zone transitions emit the same signal with the new zone value, covering entry from below (damage) and exit upward (healing) symmetrically. At default `FAYDE_MAX_HP = 100`:
   - HP drops from 45 to 38: emit `player_hp_zone_changed(HPZone.CAREFUL)`
   - HP drops from 22 to 14: emit `player_hp_zone_changed(HPZone.DESPERATE)`
   - HP recovers from 14 to 22: emit `player_hp_zone_changed(HPZone.CAREFUL)` *(upward crossing into CAREFUL zone)*
   - HP recovers from 14 to 45: emit `player_hp_zone_changed(HPZone.FULL)` *(skips CAREFUL; only the final zone crossing fires)*
   - HP recovers from 38 to 45: emit `player_hp_zone_changed(HPZone.FULL)`

   Audio System and Combat HUD listen to `player_hp_zone_changed` and update their state to match the current zone. The Audio System implements the amber/critical music treatment as a parameter blend within the COMBAT music state (not as new FSM states — see Visual/Audio Requirements).

   *Runtime invariant*: The percentage-based formulation guarantees `CAREFUL threshold > DESPERATE threshold` as long as `FAYDE_HP_CRITICAL_CAREFUL > FAYDE_HP_CRITICAL_DESPERATE` (0.40 > 0.20 by default). Add a startup assert: `assert(FAYDE_HP_CRITICAL_CAREFUL > FAYDE_HP_CRITICAL_DESPERATE, "CAREFUL threshold must exceed DESPERATE threshold")`.*

---

### States and Transitions

**Fayde HP states:**

| State | Condition | Behavior |
|-------|-----------|---------|
| `ALIVE` | `current_hp > 0`, i-frames inactive | Normal — all damage sources apply |
| `INVINCIBLE` | `current_hp > 0`, i-frames active | `CONTACT` damage blocked; `DOT` and `DIRECT` damage and healing unaffected |
| `DEAD` | `current_hp <= 0` | Terminal for the run; `player_died` emitted once; all `apply_damage` calls return immediately at step 2 |

`ALIVE ↔ INVINCIBLE`: toggled by `CONTACT` damage events + i-frame timer expiry. `DEAD` is a run-terminal state with no return.

**Fayde HP zone overlays** (orthogonal to the state above — track alongside state):

| Zone | Condition (at default FAYDE_MAX_HP=100) | Signal emitted |
|------|-----------------------------------------|----------------|
| `FULL` | `current_hp > 40` (> 40% of 100) | `player_hp_zone_changed(HPZone.FULL)` on upward crossing |
| `CAREFUL` | `current_hp ≤ 40` and `> 20` | `player_hp_zone_changed(HPZone.CAREFUL)` on any crossing into this zone |
| `DESPERATE` | `current_hp ≤ 20` | `player_hp_zone_changed(HPZone.DESPERATE)` on downward crossing; `player_hp_zone_changed(HPZone.CAREFUL)` on upward crossing back above 20 |

At runtime, effective thresholds are `FAYDE_MAX_HP × FAYDE_HP_CRITICAL_CAREFUL` and `FAYDE_MAX_HP × FAYDE_HP_CRITICAL_DESPERATE`. Zone conditions scale automatically when `FAYDE_MAX_HP` changes.

**Enemy HP states:**

| State | Condition |
|-------|-----------|
| `ALIVE` | `current_hp > 0` |
| `DEAD` | `current_hp <= 0` — `enemy_killed(id, type_id, prana_affiliation)` emitted, death sequence owned by Enemy AI |

Enemies have no i-frames. All damage applies immediately.

---

### Interactions with Other Systems

| System | Interface | Direction |
|--------|-----------|-----------|
| **Enemy Data** | Reads `base_hp`, `base_damage` per enemy type at spawn; reads `prana_affiliation` for inclusion in `enemy_killed` signal | Enemy Data → H&D |
| **Elemental Affiliation & Weakness** | Called with `(attacker_element, target_affiliation)` → returns `damage_multiplier: float` | H&D calls EA&W |
| **Status Effects** | Calls `apply_damage(target, tick_damage, null, DamageSource.DOT)` and `apply_heal()` for each DoT/HoT tick | Status Effects → H&D |
| **Spell Casting & Effects** | Calls `apply_damage(enemy_target, spell_base_damage, spell_element, DamageSource.DIRECT)` on hit | Spell Casting → H&D |
| **Enemy AI** | Calls `apply_damage(fayde, enemy.base_damage, null, DamageSource.CONTACT)` on hit contact | Enemy AI → H&D |
| **Game State & Scene Flow** | Listens for `player_died`; emits `run_started` → H&D resets Fayde HP | Bidirectional signals |
| **Tutorial/Onboarding** | Sets `first_run_active` flag (on `run_started` for player's first lifetime run) that H&D reads in step 6 of the damage pipeline to apply `FIRST_RUN_DAMAGE_MULTIPLIER` | Tutorial/Onboarding → H&D |
| **Audio System** | Listens for `player_died` (music → END), `player_hp_zone_changed` (zone-appropriate music blend within COMBAT state), `enemy_killed` (uses `prana_affiliation` param for elemental death SFX variant), `heavy_hit` (impact audio stinger) | H&D → Audio System |
| **Game Feel / Juice** | Listens for `heavy_hit(target, final_damage)` to apply hit-stop, screen shake, and visual impact weight | H&D → Game Feel |
| **Wave / Encounter System** | Listens for `enemy_killed(id, type_id, prana_affiliation)` to count wave progress | H&D → Wave System |
| **Prana Drop / Loot** | Listens for `enemy_killed(id, type_id, prana_affiliation)` to trigger drop logic — resolves enemy position via `instance_from_id()` within the same frame (node-lifetime guarantee in Rule 5) | H&D → Prana Drop |
| **Combat HUD** | Listens for `damage_taken`, `health_restored`, `player_died`, `player_hp_zone_changed`, `heavy_hit` to update HP display and visual state | H&D → Combat HUD |

## Formulas

### Damage Formula

```
final_damage = clamp(roundi(base_damage × damage_multiplier), 0, target.max_hp)
target.current_hp = clamp(target.current_hp - final_damage, 0, target.max_hp)
```

*Rounding uses GDScript's `roundi()` — round-half-away-from-zero (standard mathematical rounding). Example: `roundi(13.5) = 14`, `roundi(14.5) = 15`. `roundi()` returns `int` directly, avoiding a separate `int()` cast. The inner clamp caps `final_damage` so emitted signal values never exceed `target.max_hp`.*

*First-run mercy (Fayde + CONTACT + `first_run_active` flag only): `final_damage = clamp(roundi(float(final_damage) × FIRST_RUN_DAMAGE_MULTIPLIER), 0, target.max_hp)` applied after the base damage calculation.*

Full call signature: `apply_damage(target, base_damage: float, element: DamageClass | null, source: DamageSource)`

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `base_damage` | float | 0.0 – unbounded | Raw damage before modifiers — enemy `base_damage` or spell base damage (after Prana Data's `base_damage_modifier` chain) |
| `damage_multiplier` | float | 0.0 – unbounded | Elemental multiplier from Elemental Affiliation & Weakness; `1.0` if `element == null` |
| `source` | DamageSource | CONTACT / DOT / DIRECT | Determines i-frame interaction; `CONTACT` checks i-frame window; `DOT` and `DIRECT` bypass it |
| `target.max_hp` | int | 80 – 150 (Fayde); 1 – unbounded (enemies) | Per-target HP ceiling |
| `final_damage` | int | 0 – `target.max_hp` | Final value applied to `target.current_hp`; emitted in signal only if `> 0` |

**Worked examples (current catalog):**

| Scenario | `base_damage` | `damage_multiplier` | `final_damage` |
|----------|---------------|---------------------|----------------|
| Cluster hit, neutral | 4.0 | 1.0 | 4 |
| Charger hit, neutral | 20.0 | 1.0 | 20 |
| Charger hit, Fire-weak enemy | 20.0 | 1.25 | 25 |
| Voidblue spell, neutral enemy | 15.0 | 0.90 | 14 |
| DoT tick (no element) | 3.0 | 1.0 | 3 |
| Charger hit, first run (mercy 0.5) | 20.0 | 1.0 | 10 |

*Note: `damage_multiplier = 1.0` always applies when `element == null` (DoT ticks, neutral hits). The Elemental Affiliation & Weakness system owns all non-1.0 multipliers.*

**One-shot threshold flag**: A Charger (35 HP) can be one-shot only if `final_damage ≥ 35`, which requires `base_damage × damage_multiplier ≥ 35.0`.

⚠️ **One-shot precision note**: GDScript's `roundi()` uses round-half-away-from-zero. `roundi(34.5) = 35` — a product of exactly 34.5 DOES one-shot a 35 HP Charger. However, `roundi(34.4) = 34`, leaving 1 HP. The safe threshold for a guaranteed one-shot is `base_damage × damage_multiplier ≥ 34.5`. Any value below that risks leaving 1 HP due to rounding.

⚠️ **Compound chain note for Elemental Affiliation designers**: The `base_damage` entering this formula is already `raw_spell_power × base_damage_modifier` from Prana Data. The 1.75× figure above assumes no `base_damage_modifier` chain. For Ashfire (modifier = 1.25), the effective elemental multiplier threshold for one-shotting a Charger drops to `35.0 / (20 × 1.25) = 1.40×` — well within the plausible weakness range. Elemental Affiliation & Weakness GDD must account for per-type compound thresholds; do not use the 1.75× figure as a universal baseline.

---

### Heal Formula

HP restoration does not use a named formula — healing is a round-then-clamp operation applied directly:

```
old_current_hp = target.current_hp  # captured before applying heal
target.current_hp = roundi(clamp(target.current_hp + heal_amount, 0, target.max_hp))
healed_amount = target.current_hp - old_current_hp  # actual int delta, 0 if at max
```

Cannot overheal. `heal_amount` is always a positive float (from Prana Data regen formula); negative values are a precondition violation — `apply_heal` logs an error and returns. `roundi()` is used instead of `int()` to avoid silent truncation at low magnitudes: `int(0.8) = 0` would silently deliver zero HP, whereas `roundi(0.8) = 1` preserves the heal. `old_current_hp` must be captured before the formula is applied (see formula block above). The emitted signal uses `healed_amount: int` (the actual HP delta), not the raw `heal_amount: float`.

**Verdant Regen reference values** (from Prana Data):
- Current: `round(100 × 0.02) × 3 ticks` = **6 HP total** (intentionally isolated-weak; Verdant derives full value from Combination Resolution combo bonuses — see Known Design Tension note in Player Fantasy)
- *Note on minimum tuning floor*: `round(FAYDE_MAX_HP × REGEN_TICK_MAGNITUDE)` must be ≥ 1. At minimum FAYDE_MAX_HP (80) and minimum REGEN_TICK_MAGNITUDE (0.02), tick value is `round(80 × 0.02) = round(1.6) = 2` HP — safely nonzero. Do not reduce REGEN_TICK_MAGNITUDE below 0.02 without verifying the product remains ≥ 0.5 (rounds to at least 1).

## Edge Cases

1. **Simultaneous hits in the same frame** — If two damage sources hit the same target in one physics frame (e.g., two Cluster enemies collide with Fayde simultaneously), each `apply_damage()` call executes independently and sequentially. Both apply; order is frame-order. If the first hit kills the target, the second call enters at Rule 2 step 2 (dead-target guard) and returns immediately — no damage, no signal, no duplicate death emission.

2. **Contact hit frequency (contact-type enemies)** — Enemies that deal damage on contact (Charger rush, Cluster overlap) emit exactly **one damage event per contact event** with `source = DamageSource.CONTACT`, not one per physics frame. Enemy AI is responsible for triggering `apply_damage()` once at contact initiation. Health & Damage does not de-duplicate contact damage — it trusts the caller.

3. **I-frame window during multi-enemy encounters** — The `FAYDE_IFRAME_DURATION` window (0.5s) resets on each qualifying `CONTACT` hit after the previous window expires. During an active i-frame window, `source = CONTACT` calls return at step 2. `source = DOT`, `source = DIRECT`, and healing calls proceed normally. *Note: i-frames are effectively irrelevant against Charger (3s rush interval far exceeds 0.5s window); they primarily protect against Cluster swarm stacking.*

4. **Overkill damage** — `clamp(..., 0, target.max_hp)` prevents `final_damage` from exceeding `target.max_hp`. A single hit cannot reduce HP below 0 or above max. Visual overkill feedback (if any) is owned by Game Feel / Juice, not by this system.

5. **Heal when already at max HP** — `clamp(current_hp + heal_amount, 0, max_hp)` silently caps at `max_hp`. No signal emitted for a zero-effect heal. The caller (Status Effects / Verdant Regen) does not need to check before calling.

6. **`player_died` re-emit guard** — Once Fayde's `current_hp` reaches 0 and `player_died` is emitted, Health & Damage transitions to `DEAD` state and will not re-emit `player_died` for the remainder of the run, even if additional damage calls arrive. This prevents duplicate death handling in Game State & Scene Flow.

7. **Enemy HP at 0 from DoT** — If a Burn tick kills an enemy (HP reaches 0 mid-wave), `enemy_killed(id, type_id, prana_affiliation)` is emitted exactly as if direct damage killed it. Wave / Encounter System and Prana Drop / Loot do not need to distinguish DoT kills from direct kills.

8. **Negative `base_damage` input** — Not a valid call; treated as a precondition violation. `clamp(round(negative × multiplier), 0, max_hp)` = 0 damage with no HP change. This is a fail-safe, not an intended path — callers must validate before calling `apply_damage()`.

9. **Negative `heal_amount` input** — Precondition violation; `apply_heal` logs an error and returns immediately without modifying HP or emitting any signal. Without this guard, a negative `heal_amount` would silently reduce `current_hp` via the clamp formula and could set Fayde's HP to 0 without entering `DEAD` state or emitting `player_died` (zombie state).

10. **Zone boundary crossing on a single large damage/heal** — If a single `apply_damage` call drops HP across multiple zone boundaries (e.g., 100 HP → 10 HP in one hit, crossing both CAREFUL and DESPERATE thresholds), only the final destination zone signal fires: `player_hp_zone_changed(HPZone.DESPERATE)`. No intermediate `CAREFUL` signal is emitted. The zone signal represents the current zone after the HP update, not intermediate crossings.

11. **First-run mercy deactivation** — The `first_run_active` flag (set by Tutorial/Onboarding) must be cleared on `run_started` for any run after the first. If Tutorial/Onboarding fails to clear it, all subsequent runs apply the mercy multiplier silently. Tutorial/Onboarding owns the flag lifecycle; H&D trusts the caller.

## Dependencies

| # | System | Relationship | Direction | Notes |
|---|--------|-------------|-----------|-------|
| 1 | **Enemy Data** | Reads `base_hp` at spawn; reads `base_damage` at hit; reads `prana_affiliation` for inclusion in `enemy_killed` signal | Enemy Data → H&D | H&D does not own enemy stat definitions — only the HP instance and the signal payload |
| 2 | **Elemental Affiliation & Weakness** | Called with `(attacker_element, target_affiliation)` → returns `damage_multiplier: float` | H&D calls EA&W | EA&W is the authority on all multiplier values; H&D receives and applies them |
| 3 | **Status Effects** | Calls `apply_damage(target, tick_damage, null, DamageSource.DOT)` and `apply_heal(target, tick_heal)` for each DoT/HoT tick | Status Effects → H&D | H&D does not know about tick timing or Burn/Regen duration — Status Effects owns that |
| 4 | **Spell Casting & Effects** | Calls `apply_damage(enemy_target, spell_base_damage, spell_element, DamageSource.DIRECT)` on spell hit | Spell Casting → H&D | Spell Casting resolves hit detection; H&D resolves damage value and HP update |
| 5 | **Enemy AI** | Calls `apply_damage(fayde, enemy.base_damage, null, DamageSource.CONTACT)` on contact hit; **must enforce a minimum inter-contact interval (`ENEMY_MIN_CONTACT_INTERVAL`, suggest 0.3s) for contact-damage enemies — H&D's i-frame protection against Cluster swarms relies on this; violation renders i-frame protection near-zero in dense swarms** | Enemy AI → H&D | Triggers exactly one call per contact event (not per frame); must not free enemy node until at least one frame after `enemy_killed` is emitted |
| 6 | **Game State & Scene Flow** | Listens for `player_died` to transition to `DEATH_SCREEN`; emits `run_started` → H&D resets Fayde HP to `FAYDE_MAX_HP` | Bidirectional signals | The only run-lifecycle hook H&D needs is `run_started` |
| 7 | **Tutorial/Onboarding** | Sets `first_run_active: bool` flag for the player's first lifetime run; H&D reads this in damage pipeline step 6 to apply FIRST_RUN_DAMAGE_MULTIPLIER | Tutorial/Onboarding → H&D | H&D holds the damage contract; Tutorial/Onboarding owns the flag lifecycle. Flag must be cleared for all subsequent runs. |
| 8 | **Audio System** | Listens for `player_died` (→ END music), `player_hp_zone_changed(zone)` (→ zone-appropriate COMBAT audio treatment; implementation mechanism defined in Audio System GDD), `enemy_killed` (uses `prana_affiliation: DamageClass` for elemental death SFX variant — `DamageClass.NONE` maps to neutral fallback; elemental variant event keys defined in Audio System GDD), `heavy_hit` (→ impact stinger at COMBAT priority = 0) | H&D → Audio System | Audio System is a passive listener; no calls back to H&D. Audio System GDD owns the zone-treatment mechanism and must specify absolute output per HPZone value (including de-escalation on upward recovery). |
| 9 | **Game Feel / Juice** | Listens for `heavy_hit(target, final_damage)` to apply hit-stop, screen shake, and visual impact weight | H&D → Game Feel | Game Feel is a passive listener; H&D provides the trigger signal, Game Feel owns the effect. |
| 10 | **Wave / Encounter System** | Listens for `enemy_killed(id, type_id, prana_affiliation)` to track wave completion count | H&D → Wave System | Wave System determines win condition from kill counts; H&D just fires the signal |
| 11 | **Prana Drop / Loot** | Listens for `enemy_killed(id, type_id, prana_affiliation)` to evaluate and spawn Prana drops; resolves position via `instance_from_id()` | H&D → Prana Drop | Enemy node is guaranteed alive for at least one frame after signal for `queue_free()` callers (see Rule 5 node-lifetime note). **Prana Drop / Loot MUST guard with `is_instance_valid(instance_from_id(id))` before accessing any property** — required for `free()` violations and deferred signal connections. |
| 12 | **Combat HUD** | Listens for `damage_taken`, `health_restored`, `player_died`, `player_hp_zone_changed`, `heavy_hit` to update HP bar display and visual state | H&D → Combat HUD | Combat HUD is a passive listener; never calls into H&D |
| 13 | **Player Controller** | Queries `is_invincible() -> bool` at step 1a of `apply_damage` (Fayde + CONTACT only — dash i-frame guard) | H&D queries Player Controller | Accessed via `get_tree().get_first_node_in_group(&"player")` or a typed `@export` reference; Player Controller must be in the `"player"` group. This dependency was added in Player Controller GDD round-2 review. |

**Bidirectionality note:** All systems listed above that depend on H&D signals must include H&D in their own Dependencies section.

**Target discrimination contract**: The `damage_taken(target, ...)` and `heavy_hit(target, ...)` signal `target` parameters carry the node reference. Listeners that need to distinguish Fayde from enemies at runtime must check `target.is_in_group("player")`. The PlayerController node must be in the `"player"` group. Enemy instances must NOT be in the `"player"` group. This convention must be documented in both the PlayerController GDD and the Enemy AI GDD.

## Tuning Knobs

| Knob | Constant Name | Default Value | Safe Range | What It Affects |
|------|---------------|---------------|------------|----------------|
| Fayde max HP | `FAYDE_MAX_HP` | 100 | 80 – 150 | Overall run lethality; lower = more punishing, higher = more forgiving. Core to all difficulty tuning. Zone thresholds scale automatically with this value. |
| I-frame duration | `FAYDE_IFRAME_DURATION` | 0.5s | 0.2s – 1.0s | Contact-damage stacking protection vs. Cluster swarms. *Lower bound 0.2s requires Enemy AI to enforce minimum inter-contact intervals — without that constraint, 0.2s provides near-zero protection in dense swarms (Dependency #5).* Above 1.0s makes swarms trivial. |
| "Careful" HP threshold (fraction) | `FAYDE_HP_CRITICAL_CAREFUL` | 0.40 | 0.25 – 0.50 | Fraction of FAYDE_MAX_HP below which `player_hp_zone_changed(HPZone.CAREFUL)` fires. At default: 40 HP. Must exceed `FAYDE_HP_CRITICAL_DESPERATE` (invariant enforced by startup assert). |
| "Desperate" HP threshold (fraction) | `FAYDE_HP_CRITICAL_DESPERATE` | 0.20 | 0.10 – 0.24 | Fraction of FAYDE_MAX_HP below which `player_hp_zone_changed(HPZone.DESPERATE)` fires. At default: 20 HP. Must be below `FAYDE_HP_CRITICAL_CAREFUL`. Upper bound (0.24) is strictly below CAREFUL lower bound (0.25) to prevent the startup invariant assert from firing when both knobs are at their declared extremes. |
| Heavy hit threshold | `HEAVY_HIT_THRESHOLD` | 15 | 10 – 25 | `final_damage` value above which `heavy_hit(target, final_damage)` fires. At default: a Charger hit (20 damage, neutral) triggers `heavy_hit`; a Cluster hit (4 damage) does not. Calibrate so only hits representing ≥ 15% of FAYDE_MAX_HP feel weighty. |
| First-run damage multiplier | `FIRST_RUN_DAMAGE_MULTIPLIER` | 0.5 | 0.3 – 1.0 | Fraction applied to `final_damage` for CONTACT hits on Fayde during the player's first lifetime run. 1.0 = no mercy (disable feature). Owned by Tutorial/Onboarding; exposed here as H&D's tuning surface. |
| Verdant regen tick magnitude | `REGEN_TICK_MAGNITUDE` | 0.02 | 0.02 – 0.05 | Per-tick HP fraction restored. 0.02 = 6 HP per cast at max HP 100 (intentionally isolated-weak; Verdant value comes from combos). Minimum raised from 0.01: at FAYDE_MAX_HP=80, `round(80 × 0.01) = round(0.8) = 1` HP barely clears zero, but the floor is fragile. Stay at 0.02 minimum for safe nonzero delivery. Owned by Prana Data but directly feeds this system. |
| Verdant regen tick count | `REGEN_TICK_COUNT` | 3 | 2 – 5 | Total HP restored per Verdant cast (multiply by tick magnitude × max HP). Owned by Prana Data. |

**Cross-system tuning notes:**
- Charger `base_damage` (20.0) is the primary difficulty dial for melee threat. At 100 HP, Fayde survives 5 neutral hits — raising to 25 base damage means 4 hits. Both are intentional design ranges; choose based on playtesting.
- Cluster `base_damage` (4.0) is intentionally low — they are a threat via accumulation (swarming), not individual hits. Do not raise above ~8 without re-evaluating i-frame duration.
- The `burn_total` formula (Prana Data) indirectly tunes DoT threat: 32% of base spell damage over 2s. Adjusting `burn_tick_magnitude` (currently 0.08) affects Burn damage without touching this system.
- With percentage-based thresholds, the "careful" zone entry at 40 HP is calibrated so two Charger hits from full HP (100 → 80 → 60) does not trigger CAREFUL, but a third hit (60 → 40) triggers it exactly. Reinforces the "three-hit patience window" design intent.

## Acceptance Criteria

**Damage pipeline:**

- **AC-HD-01** — Given Fayde at 100 HP and an enemy hit with `base_damage=20.0, element=null`: `fayde.current_hp` equals 80 after the call and `damage_taken(fayde, 20, 80)` was emitted.
- **AC-HD-02** — Given an enemy instance with `current_hp=35` hit with `base_damage=20.0, damage_multiplier=1.25`: `enemy.current_hp` equals 10 after the call (`round(25.0) = 25`, `35 - 25 = 10`).
- **AC-HD-03** — Given `base_damage=20.0, damage_multiplier=0.90`: `final_damage` equals 18 (`round(18.0) = 18`).
- **AC-HD-04** — Given a target with `current_hp=10, max_hp=100` and a hit with `final_damage=50`: `current_hp` equals 0 after the call (clamp prevents negative HP).
- **AC-HD-05** — Given a living target (`current_hp > 0`) and `base_damage=0.0`: `final_damage` equals 0; `current_hp` is unchanged; `damage_taken` is **NOT emitted** (zero-damage hits do not trigger hit flash or SFX).

**I-frames:**

- **AC-HD-06** — After Fayde takes contact damage (with `final_damage > 0`), a second contact hit within `FAYDE_IFRAME_DURATION` (0.5s): (1) does not change Fayde's `current_hp`; (2) `damage_taken` is NOT emitted for the blocked hit. *(A broken implementation that computes damage, emits `damage_taken`, then skips the HP update would pass assertion 1 but fail assertion 2.)*
- **AC-HD-07** — After `FAYDE_IFRAME_DURATION` expires, the next contact hit applies damage normally. *(Test implementation note: requires either a time-delta accumulator pinned by test or an explicit `force_end_iframe_window()` test seam on the Health & Damage node. The GDScript implementation must expose one of these.)*
- **AC-HD-08** — A DoT tick from Status Effects applied during an active i-frame window changes Fayde's `current_hp` (i-frames do not block DoT).
- **AC-HD-09** — A heal applied during an active i-frame window changes Fayde's `current_hp` (i-frames do not block healing).
- **AC-HD-27** — A `DamageSource.DIRECT` hit applied during an active i-frame window changes Fayde's `current_hp` (i-frames do not block DIRECT damage). *This is the source type used by Spell Casting — a broken "block everything except DOT" implementation must not pass this test.*

**Healing:**

- **AC-HD-10** — Given Fayde at `current_hp=80, max_hp=100` and `heal_amount=30`: `current_hp` equals 100 (clamped at max, no overheal).
- **AC-HD-11** — Given Fayde at `current_hp=100, max_hp=100` and `heal_amount=10`: `current_hp` remains 100; `health_restored` is **NOT emitted** (zero-effect heals produce no signal).
- **AC-HD-12** — Given Fayde at `current_hp=10` and `heal_amount=6`: `current_hp` equals 16 and `health_restored(fayde, 6, 16)` was emitted.

**Death:**

- **AC-HD-13** — Given an enemy with `current_hp=5` hit with `final_damage=5`: `current_hp` equals 0 and `enemy_killed(instance_id, type_id, prana_affiliation)` is emitted once.
- **AC-HD-14** — Given Fayde at `current_hp=10` hit with `final_damage=15`: `current_hp` equals 0 and `player_died` is emitted once.
- **AC-HD-15** — Given Fayde already in `DEAD` state (`current_hp=0`): a subsequent `apply_damage()` call does not re-emit `player_died`.
- **AC-HD-16** — Given a wave with 3 enemies killed: `enemy_killed` was emitted exactly 3 times with distinct `instance_id` values.

**Run reset:**

- **AC-HD-17** — On `run_started` signal: Fayde's `current_hp` equals `FAYDE_MAX_HP` (100) regardless of previous HP value.
- **AC-HD-18** — A newly spawned enemy instance has `current_hp` equal to the `base_hp` value from Enemy Data for its type.

**HP zone signals (percentage-based thresholds at FAYDE_MAX_HP=100; effective thresholds: CAREFUL=40, DESPERATE=20):**

- **AC-HD-19** — Given Fayde at `current_hp=45` hit with `final_damage=6` (result: 39 HP, crossing below CAREFUL threshold 40): `player_hp_zone_changed(HPZone.CAREFUL)` is emitted once.
- **AC-HD-20** — Given Fayde who entered CAREFUL zone via a prior `apply_damage` call that reduced HP from above 40 to 35 (zone tracker = CAREFUL, confirmed by a preceding `player_hp_zone_changed(HPZone.CAREFUL)` emission), then hit with another `final_damage=5` (result: 30 HP, still within CAREFUL zone): `player_hp_zone_changed` is **NOT re-emitted** (already in CAREFUL zone, no boundary crossed). *(Fixture must establish zone state via the pipeline — direct assignment of `current_hp = 35` does not set the zone tracker.)*
- **AC-HD-21** — Given Fayde who entered CAREFUL zone via a prior `apply_damage` call that reduced HP from above 40 to 25 (zone tracker = CAREFUL), then hit with `final_damage=6` (result: 19 HP, crossing below DESPERATE threshold 20): `player_hp_zone_changed(HPZone.DESPERATE)` is emitted once; `player_hp_zone_changed(HPZone.CAREFUL)` is **NOT emitted** (no CAREFUL boundary crossed — already in CAREFUL). *(Fixture must establish zone state via pipeline, not direct HP assignment.)*
- **AC-HD-22** — Given Fayde heals from `current_hp=10` to `current_hp=45` (crossing both DESPERATE=20 and CAREFUL=40 thresholds in one heal): `player_hp_zone_changed(HPZone.FULL)` is emitted once (final zone); `player_hp_zone_changed(HPZone.CAREFUL)` is **NOT separately emitted** (only the final zone crossing fires per Rule 9).
- **AC-HD-26** — Given Fayde at `current_hp=10` (DESPERATE zone) heals `heal_amount=15` to reach `current_hp=25` (above DESPERATE=20, below CAREFUL=40 — CAREFUL zone): `player_hp_zone_changed(HPZone.CAREFUL)` is emitted once; `player_hp_zone_changed(HPZone.FULL)` is **NOT emitted**. *(This is the partial-recovery case — Rule 9 upward crossing into CAREFUL zone, not all the way to FULL.)*

**Dead-target guard:**

- **AC-HD-23** — Given Fayde in `DEAD` state (`current_hp=0`): calling `apply_damage(fayde, 20.0, null, DamageSource.CONTACT)` returns immediately; `current_hp` remains 0; no signal is emitted; `player_died` is not re-emitted.

**Negative heal guard:**

- **AC-HD-24** — Calling `apply_heal(fayde, -10.0)` does not change `fayde.current_hp` and does not emit any signal (precondition violation — logged as error, returns without processing).

**Heavy hit signal:**

- **AC-HD-28** — Given `final_damage=20` (above `HEAVY_HIT_THRESHOLD=15`): both `damage_taken(target, 20, current_hp)` and `heavy_hit(target, 20)` are emitted in the same `apply_damage` call (verify both signal emit counts equal 1).
- **AC-HD-29** — Given `final_damage=4` (below `HEAVY_HIT_THRESHOLD=15`): `heavy_hit` is **NOT emitted**; `damage_taken` is emitted normally.

**First-run mercy:**

- **AC-HD-30** — Given `first_run_active=true`, Fayde receives a CONTACT hit with `base_damage=20.0, element=null`: `final_damage` equals `round(20 × 0.5) = 10`; Fayde's `current_hp` decreases by 10.
- **AC-HD-31** — Given `first_run_active=false` (any subsequent run), the same CONTACT hit with `base_damage=20.0` applies `final_damage=20` without mercy modification.

**Run reset zone sync:**

- **AC-HD-32** — Given a run that ended with Fayde in DESPERATE zone (`current_hp=10`, zone tracker = DESPERATE): after `run_started` signal fires, (1) `fayde.current_hp` equals `FAYDE_MAX_HP` (100); (2) `player_hp_zone_changed(HPZone.FULL)` is emitted once.

**I-frame re-arm:**

- **AC-HD-33** — Given: first CONTACT hit (with `final_damage > 0`) arms i-frame window1; `force_end_iframe_window()` is called to expire window1; second CONTACT hit arms window2; a third CONTACT hit occurs before window2 expires. Assertions: (1) Fayde's `current_hp` is unchanged by the third hit (window2 active); (2) `damage_taken` is NOT emitted for the third hit.

**Integration — sequential damage assertions:**

- **AC-HD-25a** — Given Fayde at `current_hp=50` with i-frames active: `apply_damage(fayde, 5.0, null, DamageSource.DOT)` is called, then `apply_damage(fayde, 20.0, null, DamageSource.CONTACT)` is called. Assertions: (1) `current_hp` equals 45 after both calls (DoT applied, CONTACT blocked); (2) `damage_taken` fires exactly once with `final_damage=5`; (3) no `player_hp_zone_changed` fires (45 HP > CAREFUL threshold 40). *(These are sequential calls, not same-frame assertions; frame ordering is non-deterministic in Godot and is tested by the combination of AC-HD-08 and AC-HD-06 independently.)*

## Visual/Audio Requirements

*Note: final visual specs require art-director sign-off before implementation. The following are design intents.*

**Hit feedback — Fayde:**
- On `damage_taken(fayde, ...)`: Fayde sprite flashes white for ~0.1s (hit flash). `damage_taken` is only emitted when `final_damage > 0` — zero-damage events produce no hit flash.
- On `heavy_hit(fayde, final_damage)` (where `final_damage >= HEAVY_HIT_THRESHOLD`): Game Feel / Juice applies hit-stop (~0.05–0.1s freeze-frame) and light screen shake. This is what differentiates a 20-damage Charger hit from a 4-damage Cluster hit at the feel level. Audio System plays a high-impact stinger at **COMBAT priority (stinger_priority = 0)**. A concurrent NARRATIVE stinger (priority 1) will suppress this — accepted at MVP scope since NARRATIVE stingers are rare during combat waves.
- On `player_hp_zone_changed(HPZone.CAREFUL)` (≤ 40% HP): HP bar shifts to amber warning treatment, Audio System blends the COMBAT music toward the "careful" parameter layer (exact blend curve: Audio System GDD).
- On `player_hp_zone_changed(HPZone.DESPERATE)` (≤ 20% HP): HP bar shifts to red critical treatment, Audio System blends to the "desperate" parameter layer, overriding careful. (Exact treatment: Combat HUD GDD + art-director.)
- On `player_hp_zone_changed(HPZone.CAREFUL)` after recovery from DESPERATE (HP crossed back above 20%): Audio System and HUD de-escalate from critical to careful treatment.
- On `player_hp_zone_changed(HPZone.FULL)` after recovery above 40%: Audio System and HUD restore normal COMBAT treatment.
- No additional screen shake for non-heavy hits at MVP; if added, owned by Game Feel / Juice — not this system.

**Audio zone mechanism**: HP zone audio treatment implementation is defined in the **Audio System GDD** — Health & Damage only emits `player_hp_zone_changed(HPZone)` and requires that the Audio System produce a distinct, perceptible audio treatment for each zone value (FULL = normal COMBAT music, CAREFUL = amber treatment, DESPERATE = critical treatment). The Audio System GDD owns the mechanism (blend, layer, or state variant) and must specify how each `HPZone` value maps to an absolute audio output, including de-escalation on upward zone recovery. H&D does not prescribe the implementation. See Audio System GDD for details.

**Target discrimination**: Listeners on `damage_taken(target, ...)` and `heavy_hit(target, ...)` must use `target.is_in_group("player")` to distinguish Fayde from enemy instances at runtime. Do not use class-name checks — they break on refactor. The `"player"` group is assigned to the PlayerController node root and must NOT be present on any enemy node.

**Hit feedback — enemies:**
- On `damage_taken(enemy, ...)`: enemy sprite flashes white for ~0.1s.
- On `heavy_hit(enemy, ...)` (boss or high-HP enemy hit): Game Feel / Juice applies hit-stop and Audio plays high-impact stinger.
- Damage number floats up from hit position and fades. Number color: white (neutral), Prana element color for elemental hits (Ashfire = `#F24C1D`, etc.). Style TBD with art-director.

**Death — enemies:**
- On `enemy_killed(id, type_id, prana_affiliation)`: crumple → bloom → dissolve sequence (Art Bible §6, all-ages safe). Duration ~0.5–1.0s. Animation owned by Enemy AI / Game Feel; H&D only emits the signal.
- Elemental death SFX variant: keyed on `prana_affiliation` parameter (the enemy's own elemental type). Event key names (e.g., `sfx_enemy_death_fire`, `sfx_enemy_death_neutral`) are defined and owned by the **Audio System GDD**. H&D is responsible only for providing the `prana_affiliation` parameter; Audio System is responsible for mapping it to the correct event key.

**Death — Fayde:**
- On `player_died`: Fayde plays death animation (design TBD). Transition to `DEATH_SCREEN` handled by Game State & Scene Flow.

**Audio:**
- On `damage_taken(fayde, ...)`: play `"player_hit"` SFX (AudioSystem).
- On `damage_taken(enemy, ...)`: play `"enemy_hit"` SFX.
- On `enemy_killed`: play elemental death SFX variant (see above); fall back to `"enemy_death"` for null affiliation.
- On `player_died`: `player_died` signal transitions Audio System to END music state (handled by Audio System listening directly).
- On `health_restored`: **conditionally silent at MVP**. Healing audio is omitted at MVP only if the Combat HUD GDD specifies a heal animation meeting both of these criteria: (1) minimum tween duration of 0.15s, and (2) a distinct color shift (e.g., green flash on the HP bar) distinguishable during active combat. If the Combat HUD GDD cannot meet these criteria, the Audio System must provide a `sfx_fayde_heal` chime at MVP to ensure the all-ages (7+) audience can perceive that healing occurred. The event key `sfx_fayde_heal` must be registered in the Audio System GDD before Vertical Slice scope regardless.

## UI Requirements

*Detailed spec owned by Combat HUD GDD (System #22). Requirements from H&D's perspective:*

- Combat HUD must display `fayde_current_hp` and `FAYDE_MAX_HP` as both a visual bar and a numerical readout (e.g., `"72 / 100"`).
- HP bar must update on every `damage_taken` and `health_restored` signal — no polling.
- HP bar drain/fill should be animated (tween), not instant. Duration TBD in Combat HUD GDD; suggest 0.1–0.2s for responsiveness.
- On `player_hp_zone_changed(HPZone.CAREFUL)`: HP bar enters amber warning state. On `player_hp_zone_changed(HPZone.DESPERATE)`: HP bar enters red critical state. On `player_hp_zone_changed(HPZone.FULL)`: HP bar returns to normal state. Exact visual treatment: Combat HUD GDD + art-director.
- On `player_died`: HP bar shows 0/100. No further updates needed (run over).
- Enemy HP bars: not shown at MVP. Wave / Encounter System may show aggregate wave progress instead. No per-enemy HP UI at MVP scope.

## Open Questions

1. **Hit-stop on heavy hits** — The `heavy_hit` signal is now defined; Game Feel / Juice owns the implementation. Open question: should hit-stop duration scale with `final_damage` (e.g., 0.05s at threshold, 0.1s at double threshold), or be a flat 0.07s for any heavy hit? *Deferred to Game Feel / Juice GDD.*

2. **Damage number display** — Floating damage numbers: always visible, or only on elemental hits? Fayde-only, enemy-only, or both? Size scaling for high-damage hits? *Deferred to Combat HUD GDD.*

3. **I-frame visual clarity** — Should Fayde flash/blink repeatedly during the i-frame window to communicate invincibility to the player? Current spec says one flash at hit and one at window midpoint. Needs playtesting.

4. ~~**HP restore threshold decision**~~ — **Resolved**: Verdant at 0.02 magnitude (6 HP) is intentional. Verdant derives value from Combination Resolution combo bonuses, not raw heal. See Known Design Tension note.

5. ~~**Simultaneous death events**~~ — **Resolved**: `enemy_killed` fires before `player_died` in same-frame resolution. Game State & Scene Flow must treat `player_died` as taking priority over any in-flight win condition. See Rule 5.

6. **Tutorial/Onboarding scope for first-run mercy** — `FIRST_RUN_DAMAGE_MULTIPLIER` (default 0.5) is defined here. The Tutorial/Onboarding GDD must own the `first_run_active` flag lifecycle and define exactly what conditions constitute "first run" (first session ever, or first death-free run, or first N waves cleared). *Deferred to Tutorial/Onboarding GDD.*
