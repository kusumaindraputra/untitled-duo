# Health & Damage

> **Status**: In Review
> **Author**: Kusuma Putra + Claude Code Game Studios
> **Last Updated**: 2026-05-23 (revised after design-review)
> **Implements Pillar**: Pillar 3 (Chaos Has Consequences), Pillar 2 (Power is Earned Through Understanding)

## Overview

Health & Damage is the combat resource layer for The Last Cipher. It tracks two distinct HP pools: **Fayde's health** (a single shared pool initialized to 100 HP at run start) and **each enemy instance's health** (initialized from Enemy Data `base_hp` at spawn). When damage is applied to either pool, this system calculates the final damage value — accounting for the incoming base damage and any elemental modifiers from Elemental Affiliation & Weakness — subtracts it from the target's current HP, and emits the resulting state as signals. No other system stores HP values; all HP state lives here.

The system manages four events that other systems depend on: **damage taken** (HP decreased, Combat HUD updates, hit flash triggered), **death** (HP reaches zero or below, death signal emitted to Game State & Scene Flow and Audio System), **healing** (HP increased by Verdant Prana regen, capped at max HP), and **enemy killed** (enemy HP reaches zero, Prana Drop / Loot and Wave / Encounter System are notified). Damage-over-time effects (Burn from Ashfire) are applied as ticks by Status Effects, which calls back into Health & Damage for each tick application — Health & Damage does not own tick timing, only the application of damage values.

On the player side, Health & Damage is the system that makes the roguelike stakes tangible: Fayde has one HP pool per run, healing is available only through deliberate grid investment in Verdant Prana, and death is permanent for the run. The scarcity of HP recovery is player-chosen — a player who slots Verdant trades offensive grid space for a modest heal (6 HP per cast, intentionally isolated-weak — see Tuning Knobs). The weight of surviving is highest when the player chose not to slot Verdant, and sharpest when they did and 6 HP wasn't enough. On the enemy side, it's what makes elemental affiliation matter — a Charger with 35 HP hit by an Ashfire spell with a 1.25× modifier takes more than a neutral-affiliation hit would.

## Player Fantasy

The fantasy of Health & Damage is **the weight of surviving**. Fayde's HP isn't a number — it's the thickness of the thread. At 80 HP, combat is confident. At 40 HP, it becomes careful. At 20 HP, every enemy movement is a potential run-ender, and the Prana grid arrangements from the last Preparation phase suddenly feel very deliberate or very wrong.

The system delivers two peak moments. The first is **the clean run** — waves cleared, HP barely touched, which tells the player they read the elemental matchups correctly and positioned well. The enemy catalog worked as a legible threat; the player parsed it. This is Pillar 2 (*Power is Earned Through Understanding*) working. The second is **the desperate win** — finishing a wave at 12 HP, one Charger charge away from death, scrambling into the next Preparation phase with the knowledge that everything they do next has to count. This is Pillar 3 (*Chaos Has Consequences*) working.

On the enemy side, the fantasy is *feedback legibility*: the Charger should feel dangerous (35 HP, 20 base damage), the Cluster should feel fragile (12 HP, 4 base damage — dies in one focused hit). A player who has learned the catalog feels competent for knowing which enemy demands their full attention and which they can dispatch carelessly. Health & Damage is the system that makes that knowledge feel like *power*.

**Known Design Tension — Verdant viability**: Verdant's 6 HP heal is intentionally weak in isolation against the primary threat (Charger deals 20 damage per hit). Verdant derives full strategic value through Combination Resolution grid combo bonuses, not through raw heal output alone. This is a deliberate depth-over-breadth choice: Verdant is not a substitute for damage, but a specialist pick for sustained engagements where combo bonuses amplify its utility. If Combination Resolution does not deliver combo bonuses that make Verdant competitive, this design must be revisited.

## Detailed Design

### Core Rules

1. **Two HP pools, different owners**: Fayde has one shared HP pool for the entire run (`fayde_current_hp`, max = `FAYDE_MAX_HP` = 100). Each spawned enemy has its own per-instance `current_hp`, initialized from its Enemy Data `base_hp` at spawn. Health & Damage tracks both; no other system stores HP state.

2. **Damage application pipeline** (applies to both Fayde and enemy instances):
   1. Receive damage event: `apply_damage(target, base_damage: float, element: DamageClass | null, source: DamageSource)`
      - `DamageSource` enum: `CONTACT` (Enemy AI hit), `DOT` (Status Effects tick), `DIRECT` (anything else not subject to i-frames)
   2. **Dead-target guard**: If target is in `DEAD` state (`current_hp == 0`), return immediately — no processing, no signal.
   3. If `element != null` → request `damage_multiplier: float` from Elemental Affiliation & Weakness
   4. If `element == null` → `damage_multiplier = 1.0`
   5. `final_damage = clamp(round(base_damage × damage_multiplier), 0, target.max_hp)` *(rounded to nearest int; clamped so final_damage never exceeds max_hp — prevents misleadingly large overkill values in signals)*
   6. `target.current_hp = clamp(target.current_hp - final_damage, 0, target.max_hp)`
   7. If `final_damage > 0`: emit `damage_taken(target, final_damage, target.current_hp)` *(zero-damage hits do not emit — prevents spurious hit flash and SFX for blocked or zero-source events)*
   8. If `target.current_hp <= 0` → trigger death (see Rule 5) — only reached if target was alive at step 2

3. **Invincibility frames (Fayde only)**: After Fayde takes a hit with `source = DamageSource.CONTACT`, a `FAYDE_IFRAME_DURATION` window (default 0.5s) opens during which any subsequent `apply_damage` call with `source = CONTACT` returns at step 2 (dead-target guard path — no damage, no signal). The i-frame check uses `source`, not `element`, so `element = null` contact hits are correctly blocked and `element = null` DoT ticks are correctly passed through. The i-frame window does NOT block: `source = DOT` ticks from Status Effects, `source = DIRECT` damage, or any healing call. I-frames are re-triggered on each qualifying `CONTACT` hit after the previous window expires.
   - *Note: i-frame lower bound (0.2s) is only safe if Enemy AI enforces a minimum inter-contact interval on Cluster units. Without that constraint, 0.2s may be effectively no protection in swarm scenarios.*

4. **Heal application**: `apply_heal(target, heal_amount: float)`
   - **Precondition guard**: If `heal_amount <= 0`, log an error and return immediately — callers must use `apply_damage` for damage. Negative values passed to `apply_heal` would silently reduce HP with no death signal (Fayde zombie state).
   - `target.current_hp = int(clamp(target.current_hp + heal_amount, 0, target.max_hp))` — result is cast to int via `int()` (GDScript: `int + float = float` without explicit cast).
   - Cannot overheal — HP is capped at max.
   - If the effective heal (`new_current_hp - old_current_hp`) is 0 (target was already at max HP), emit no signal.
   - Otherwise emit `health_restored(target, healed_amount: int, target.current_hp: int)` where `healed_amount = new_current_hp - old_current_hp`.
   - Verdant Prana regen is the only MVP heal source. VS adds rest rooms and items as additional heal sources via the same interface.

5. **Death events**:
   - **Enemy death**: When enemy `current_hp <= 0` → emit `enemy_killed(enemy_instance_id, enemy_type_id)`. Enemy node is not freed here — Enemy AI and Wave / Encounter System handle the death sequence (animation, cleanup). Health & Damage only emits the signal. **Node-lifetime guarantee**: Enemy AI must not free the enemy node until at least one frame after `enemy_killed` is emitted — this ensures Prana Drop / Loot can resolve position via `instance_from_id()` in the same frame.
   - **Fayde death**: When Fayde `current_hp <= 0` → emit `player_died`. Game State & Scene Flow transitions to `DEATH_SCREEN`. This signal fires exactly once per run — not re-emitted if HP stays at 0.
   - **Same-frame death ordering**: If both an enemy and Fayde reach `current_hp <= 0` in the same frame (e.g., a DoT tick kills Fayde while the last wave enemy is simultaneously killed), `enemy_killed` is emitted before `player_died`. Game State & Scene Flow must treat `player_died` as taking priority over any in-flight win condition — a run ending in simultaneous kill-and-death resolves as a player death.

6. **DoT/HoT delegation**: Health & Damage does NOT own tick timing. Status Effects owns the timer for Burn, Regen, and other timed effects. For each tick, Status Effects calls:
   - `apply_damage(target, tick_damage, null, DamageSource.DOT)` — `source = DOT` bypasses the i-frame check; no elemental multiplier on ticks (damage already calculated by Status Effects using `burn_total` formula from Prana Data)
   - `apply_heal(target, tick_heal)` — for Verdant Regen ticks

7. **Run reset**: On `run_started` signal from Game State & Scene Flow, Health & Damage resets Fayde's HP to `FAYDE_MAX_HP`. Enemy HP instances are created fresh at spawn and require no run-level reset.

8. **No HP persistence**: Fayde's HP does not carry between runs. Enemy HP is per-instance — no enemy survives between waves.

9. **Critical HP thresholds (Fayde only)**: Health & Damage emits threshold signals when Fayde's HP drops below defined levels. These are emitted once on the downward crossing; they are not re-emitted while HP stays below the threshold, and they re-arm when HP recovers above the threshold.
   - When `current_hp` drops below `FAYDE_HP_CRITICAL_CAREFUL` (default 33 HP, ~33%): emit `player_hp_careful` — "careful" zone entry. Audio System and Combat HUD respond with amber warning treatment.
   - When `current_hp` drops below `FAYDE_HP_CRITICAL_DESPERATE` (default 15 HP, ~15%): emit `player_hp_desperate` — "desperate" zone entry. Audio System and Combat HUD respond with red critical treatment, overriding the careful state.
   - Both thresholds re-arm on upward crossing (HP recovers above `FAYDE_HP_CRITICAL_CAREFUL` clears both; HP recovers between thresholds re-arms only the desperate signal).
   - These signals are the connective tissue for the 80/40/20 HP fantasy — they are what Audio, VFX, and UI key off to create the behavioral shift at low HP.

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

| Zone | Condition | Signal emitted |
|------|-----------|----------------|
| `FULL` | `current_hp > FAYDE_HP_CRITICAL_CAREFUL` (33) | — |
| `CAREFUL` | `current_hp ≤ 33` and `> 15` | `player_hp_careful` (once on entry) |
| `DESPERATE` | `current_hp ≤ 15` | `player_hp_desperate` (once on entry, overrides careful) |

**Enemy HP states:**

| State | Condition |
|-------|-----------|
| `ALIVE` | `current_hp > 0` |
| `DEAD` | `current_hp <= 0` — `enemy_killed` emitted, death sequence owned by Enemy AI |

Enemies have no i-frames. All damage applies immediately.

---

### Interactions with Other Systems

| System | Interface | Direction |
|--------|-----------|-----------|
| **Enemy Data** | Reads `base_hp`, `base_damage` per enemy type at spawn | Enemy Data → H&D |
| **Elemental Affiliation & Weakness** | Called with `(attacker_element, target_affiliation)` → returns `damage_multiplier: float` | H&D calls EA&W |
| **Status Effects** | Calls `apply_damage(target, tick_damage, null, DamageSource.DOT)` and `apply_heal()` for each DoT/HoT tick | Status Effects → H&D |
| **Spell Casting & Effects** | Calls `apply_damage(enemy_target, spell_base_damage, spell_element, DamageSource.DIRECT)` on hit | Spell Casting → H&D |
| **Enemy AI** | Calls `apply_damage(fayde, enemy.base_damage, null, DamageSource.CONTACT)` on hit contact | Enemy AI → H&D |
| **Game State & Scene Flow** | Listens for `player_died`; emits `run_started` → H&D resets Fayde HP | Bidirectional signals |
| **Audio System** | Listens for `player_died` (music → END), `player_hp_careful` (amber warning music), `player_hp_desperate` (critical music) | H&D → Audio System |
| **Wave / Encounter System** | Listens for `enemy_killed(id, type_id)` to count wave progress | H&D → Wave System |
| **Prana Drop / Loot** | Listens for `enemy_killed(id, type_id)` to trigger drop logic — resolves enemy position via `instance_from_id()` within the same frame (node-lifetime guarantee in Rule 5) | H&D → Prana Drop |
| **Combat HUD** | Listens for `damage_taken`, `health_restored`, `player_died`, `player_hp_careful`, `player_hp_desperate` to update HP display and visual state | H&D → Combat HUD |

## Formulas

### Damage Formula

```
final_damage = clamp(round(base_damage × damage_multiplier), 0, target.max_hp)
target.current_hp = clamp(target.current_hp - final_damage, 0, target.max_hp)
```

*Rounding uses GDScript's `round()` — banker's rounding (round-half-to-even). Example: `round(13.5) = 14`, `round(14.5) = 14`. The inner clamp caps `final_damage` so emitted signal values never exceed `target.max_hp`.*

Full call signature: `apply_damage(target, base_damage: float, element: DamageClass | null, source: DamageSource)`

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `base_damage` | float | 0.0 – unbounded | Raw damage before modifiers — enemy `base_damage` or spell base damage |
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

*Note: `damage_multiplier = 1.0` always applies when `element == null` (DoT ticks, neutral hits). The Elemental Affiliation & Weakness system owns all non-1.0 multipliers.*

**One-shot threshold flag**: A Charger (35 HP) can be one-shot only if `final_damage ≥ 35`, which requires `base_damage × damage_multiplier ≥ 34.5`. With a 20-base spell, this means a multiplier of ≥ 1.75. Elemental Affiliation & Weakness GDD must account for this when setting weakness multipliers.

---

### Heal Formula

HP restoration does not use a named formula — healing is a clamp operation applied directly:

```
target.current_hp = int(clamp(target.current_hp + heal_amount, 0, target.max_hp))
healed_amount = target.current_hp - old_current_hp  # actual int delta, 0 if at max
```

Cannot overheal. `heal_amount` is always a positive float (from Prana Data regen formula); negative values are a precondition violation — `apply_heal` logs an error and returns. The explicit `int()` cast is required because GDScript silently widens `int + float = float`. The emitted signal uses `healed_amount: int` (the actual HP delta), not the raw `heal_amount: float`.

**Verdant Regen reference values** (from Prana Data):
- Current: `100 × 0.02 × 3 ticks` = **6 HP total** (intentionally isolated-weak; Verdant derives full value from Combination Resolution combo bonuses — see Known Design Tension note in Player Fantasy)
- *Note on rounding*: Verdant delivers `round(100 × 0.02) × 3 = round(2.0) × 3 = 6` HP, not `100 × 0.02 × 3 = 6.0` pre-rounding. At very low base values the difference matters (e.g., a 1-HP spell heal would round to 0 per tick). At 100 HP max, current values are safe.

## Edge Cases

1. **Simultaneous hits in the same frame** — If two damage sources hit the same target in one physics frame (e.g., two Cluster enemies collide with Fayde simultaneously), each `apply_damage()` call executes independently and sequentially. Both apply; order is frame-order. If the first hit kills the target, the second call enters at Rule 2 step 2 (dead-target guard) and returns immediately — no damage, no signal, no duplicate death emission.

2. **Contact hit frequency (contact-type enemies)** — Enemies that deal damage on contact (Charger rush, Cluster overlap) emit exactly **one damage event per contact event** with `source = DamageSource.CONTACT`, not one per physics frame. Enemy AI is responsible for triggering `apply_damage()` once at contact initiation. Health & Damage does not de-duplicate contact damage — it trusts the caller.

3. **I-frame window during multi-enemy encounters** — The `FAYDE_IFRAME_DURATION` window (0.5s) resets on each qualifying `CONTACT` hit after the previous window expires. During an active i-frame window, `source = CONTACT` calls return at step 2. `source = DOT` and `source = DIRECT` calls and healing proceed normally. *Note: i-frames are effectively irrelevant against Charger (3s rush interval far exceeds 0.5s window); they primarily protect against Cluster swarm stacking.*

4. **Overkill damage** — `clamp(..., 0, target.max_hp)` prevents `final_damage` from exceeding `target.max_hp`. A single hit cannot reduce HP below 0 or above max. Visual overkill feedback (if any) is owned by Game Feel / Juice, not by this system.

5. **Heal when already at max HP** — `clamp(current_hp + heal_amount, 0, max_hp)` silently caps at `max_hp`. No signal emitted for a zero-effect heal. The caller (Status Effects / Verdant Regen) does not need to check before calling.

6. **`player_died` re-emit guard** — Once Fayde's `current_hp` reaches 0 and `player_died` is emitted, Health & Damage transitions to `DEAD` state and will not re-emit `player_died` for the remainder of the run, even if additional damage calls arrive. This prevents duplicate death handling in Game State & Scene Flow.

7. **Enemy HP at 0 from DoT** — If a Burn tick kills an enemy (HP reaches 0 mid-wave), `enemy_killed(id, type_id)` is emitted exactly as if direct damage killed it. Wave / Encounter System and Prana Drop / Loot do not need to distinguish DoT kills from direct kills.

8. **Negative `base_damage` input** — Not a valid call; treated as a precondition violation. `clamp(round(negative × multiplier), 0, max_hp)` = 0 damage with no HP change. This is a fail-safe, not an intended path — callers must validate before calling `apply_damage()`.

9. **Negative `heal_amount` input** — Precondition violation; `apply_heal` logs an error and returns immediately without modifying HP or emitting any signal. Without this guard, a negative `heal_amount` would silently reduce `current_hp` via the clamp formula and could set Fayde's HP to 0 without entering `DEAD` state or emitting `player_died` (zombie state).

## Dependencies

| # | System | Relationship | Direction | Notes |
|---|--------|-------------|-----------|-------|
| 1 | **Enemy Data** | Reads `base_hp` at enemy spawn to initialize per-instance HP; reads `base_damage` at hit event | Enemy Data → H&D | H&D does not own enemy stat definitions — only the HP instance derived from them |
| 2 | **Elemental Affiliation & Weakness** | Called with `(attacker_element, target_affiliation)` → returns `damage_multiplier: float` | H&D calls EA&W | EA&W is the authority on all multiplier values; H&D receives and applies them |
| 3 | **Status Effects** | Calls `apply_damage(target, tick_damage, null, DamageSource.DOT)` and `apply_heal(target, tick_heal)` for each DoT/HoT tick | Status Effects → H&D | H&D does not know about tick timing or Burn/Regen duration — Status Effects owns that |
| 4 | **Spell Casting & Effects** | Calls `apply_damage(enemy_target, spell_base_damage, spell_element, DamageSource.DIRECT)` on spell hit | Spell Casting → H&D | Spell Casting resolves hit detection; H&D resolves damage value and HP update |
| 5 | **Enemy AI** | Calls `apply_damage(fayde, enemy.base_damage, null, DamageSource.CONTACT)` on contact hit | Enemy AI → H&D | Enemy AI triggers exactly one call per contact event (not per frame); **node-lifetime**: must not free enemy node until at least one frame after `enemy_killed` is emitted |
| 6 | **Game State & Scene Flow** | Listens for `player_died` to transition to `DEATH_SCREEN`; emits `run_started` → H&D resets Fayde HP to `FAYDE_MAX_HP` | Bidirectional signals | The only run-lifecycle hook H&D needs is `run_started` |
| 7 | **Audio System** | Listens for `player_died` (→ END music), `player_hp_careful` (→ amber warning music), `player_hp_desperate` (→ critical music) | H&D → Audio System | Audio System is a passive listener; no calls back to H&D |
| 8 | **Wave / Encounter System** | Listens for `enemy_killed(id, type_id)` to track wave completion count | H&D → Wave System | Wave System determines win condition from kill counts; H&D just fires the signal |
| 9 | **Prana Drop / Loot** | Listens for `enemy_killed(id, type_id)` to evaluate and spawn Prana drops; resolves position via `instance_from_id()` | H&D → Prana Drop | Enemy node is guaranteed alive for at least one frame after signal (see Dependency #5 node-lifetime note) |
| 10 | **Combat HUD** | Listens for `damage_taken`, `health_restored`, `player_died`, `player_hp_careful`, `player_hp_desperate` to update HP bar display and visual state | H&D → Combat HUD | Combat HUD is a passive listener; never calls into H&D |

**Bidirectionality note:** All systems listed above that depend on H&D signals must include H&D in their own Dependencies section. This is the canonical list for that check.

## Tuning Knobs

| Knob | Constant Name | Default Value | Safe Range | What It Affects |
|------|---------------|---------------|------------|----------------|
| Fayde max HP | `FAYDE_MAX_HP` | 100 | 80 – 150 | Overall run lethality; lower = more punishing, higher = more forgiving. Core to all difficulty tuning. |
| I-frame duration | `FAYDE_IFRAME_DURATION` | 0.5s | 0.2s – 1.0s | Contact-damage stacking protection vs. Cluster swarms. *Lower bound 0.2s requires Enemy AI to enforce minimum inter-contact intervals — without that constraint, 0.2s provides near-zero protection in dense swarms.* Above 1.0s makes swarms trivial. |
| "Careful" HP threshold | `FAYDE_HP_CRITICAL_CAREFUL` | 33 | 20 – 40 | HP level that emits `player_hp_careful`. Sets the entry point for the amber-warning zone. Should be above FAYDE_HP_CRITICAL_DESPERATE at all times. |
| "Desperate" HP threshold | `FAYDE_HP_CRITICAL_DESPERATE` | 15 | 5 – 25 | HP level that emits `player_hp_desperate`. Sets the entry point for the red-critical zone — where every decision feels terminal. Must be below FAYDE_HP_CRITICAL_CAREFUL. |
| Verdant regen tick magnitude | `REGEN_TICK_MAGNITUDE` | 0.02 | 0.01 – 0.05 | Per-tick HP fraction restored. 0.02 = 6 HP per cast (intentionally isolated-weak; Verdant value comes from combos). Owned by Prana Data but directly feeds this system. |
| Verdant regen tick count | `REGEN_TICK_COUNT` | 3 | 2 – 5 | Total HP restored per Verdant cast (multiply by tick magnitude × max HP). Owned by Prana Data. |

**Cross-system tuning notes:**
- Charger `base_damage` (20.0) is the primary difficulty dial for melee threat. At 100 HP, Fayde survives 5 neutral hits — raising to 25 base damage means 4 hits. Both are intentional design ranges; choose based on playtesting.
- Cluster `base_damage` (4.0) is intentionally low — they are a threat via accumulation (swarming), not individual hits. Do not raise above ~8 without re-evaluating i-frame duration.
- The `burn_total` formula (Prana Data) indirectly tunes DoT threat: 32% of base spell damage over 2s. Adjusting `burn_tick_magnitude` (currently 0.08) affects Burn damage without touching this system.
- `FAYDE_HP_CRITICAL_CAREFUL` (33) is calibrated so a Charger hit from 35 HP doesn't kill but immediately triggers the careful zone — reinforcing the "Charger is dangerous" read.

## Acceptance Criteria

**Damage pipeline:**

- **AC-HD-01** — Given Fayde at 100 HP and an enemy hit with `base_damage=20.0, element=null`: `fayde.current_hp` equals 80 after the call and `damage_taken(fayde, 20, 80)` was emitted.
- **AC-HD-02** — Given an enemy instance with `current_hp=35` hit with `base_damage=20.0, damage_multiplier=1.25`: `enemy.current_hp` equals 10 after the call (`round(25.0) = 25`, `35 - 25 = 10`).
- **AC-HD-03** — Given `base_damage=20.0, damage_multiplier=0.90`: `final_damage` equals 18 (`round(18.0) = 18`).
- **AC-HD-04** — Given a target with `current_hp=10, max_hp=100` and a hit with `final_damage=50`: `current_hp` equals 0 after the call (clamp prevents negative HP).
- **AC-HD-05** — Given a living target (`current_hp > 0`) and `base_damage=0.0`: `final_damage` equals 0; `current_hp` is unchanged; `damage_taken` is **NOT emitted** (zero-damage hits do not trigger hit flash or SFX).

**I-frames:**

- **AC-HD-06** — After Fayde takes contact damage, a second contact hit within `FAYDE_IFRAME_DURATION` (0.5s) does not change Fayde's `current_hp`.
- **AC-HD-07** — After `FAYDE_IFRAME_DURATION` expires, the next contact hit applies damage normally.
- **AC-HD-08** — A DoT tick from Status Effects applied during an active i-frame window changes Fayde's `current_hp` (i-frames do not block DoT).
- **AC-HD-09** — A heal applied during an active i-frame window changes Fayde's `current_hp` (i-frames do not block healing).

**Healing:**

- **AC-HD-10** — Given Fayde at `current_hp=80, max_hp=100` and `heal_amount=30`: `current_hp` equals 100 (clamped at max, no overheal).
- **AC-HD-11** — Given Fayde at `current_hp=100, max_hp=100` and `heal_amount=10`: `current_hp` remains 100; `health_restored` is **NOT emitted** (zero-effect heals produce no signal).
- **AC-HD-12** — Given Fayde at `current_hp=10` and `heal_amount=6`: `current_hp` equals 16 and `health_restored(fayde, 6, 16)` was emitted.

**Death:**

- **AC-HD-13** — Given an enemy with `current_hp=5` hit with `final_damage=5`: `current_hp` equals 0 and `enemy_killed(instance_id, type_id)` is emitted once.
- **AC-HD-14** — Given Fayde at `current_hp=10` hit with `final_damage=15`: `current_hp` equals 0 and `player_died` is emitted once.
- **AC-HD-15** — Given Fayde already in `DEAD` state (`current_hp=0`): a subsequent `apply_damage()` call does not re-emit `player_died`.
- **AC-HD-16** — Given a wave with 3 enemies killed: `enemy_killed` was emitted exactly 3 times with distinct `instance_id` values.

**Run reset:**

- **AC-HD-17** — On `run_started` signal: Fayde's `current_hp` equals `FAYDE_MAX_HP` (100) regardless of previous HP value.
- **AC-HD-18** — A newly spawned enemy instance has `current_hp` equal to the `base_hp` value from Enemy Data for its type.

**Critical HP thresholds:**

- **AC-HD-19** — Given Fayde at `current_hp=40` hit with `final_damage=8` (result: 32 HP, crossing below `FAYDE_HP_CRITICAL_CAREFUL` = 33): `player_hp_careful` is emitted once.
- **AC-HD-20** — Given Fayde already in the careful zone (`current_hp=30`) hit with another `final_damage=5` (result: 25 HP, still below 33 but above 15): `player_hp_careful` is NOT re-emitted (threshold already crossed).
- **AC-HD-21** — Given Fayde at `current_hp=20` hit with `final_damage=6` (result: 14 HP, crossing below `FAYDE_HP_CRITICAL_DESPERATE` = 15): `player_hp_desperate` is emitted once; `player_hp_careful` is NOT re-emitted.
- **AC-HD-22** — Given Fayde heals from `current_hp=12` to `current_hp=35` (above both thresholds): both `player_hp_careful` and `player_hp_desperate` re-arm, and a subsequent damage event bringing HP below 33 triggers `player_hp_careful` again.

**Dead-target guard:**

- **AC-HD-23** — Given Fayde in `DEAD` state (`current_hp=0`): calling `apply_damage(fayde, 20.0, null, DamageSource.CONTACT)` returns immediately; `current_hp` remains 0; no signal is emitted; `player_died` is not re-emitted.

**Negative heal guard:**

- **AC-HD-24** — Calling `apply_heal(fayde, -10.0)` does not change `fayde.current_hp` and does not emit any signal (precondition violation — logged as error, returns without processing).

**Integration — damage pipeline under simultaneous conditions:**

- **AC-HD-25** — Given Fayde at `current_hp=50` with i-frames active (triggered by a prior `CONTACT` hit): when `apply_damage(fayde, 5.0, null, DamageSource.DOT)` and `apply_damage(fayde, 20.0, null, DamageSource.CONTACT)` both arrive in the same frame (in that order): `current_hp` decreases by 5 (DoT applied), the `CONTACT` hit is blocked (i-frames active), `damage_taken` fires exactly once with `final_damage=5`, and no `player_hp_careful` signal fires (45 HP > 33 threshold).

## Visual/Audio Requirements

*Note: final visual specs require art-director sign-off before implementation. The following are design intents.*

**Hit feedback — Fayde:**
- On `damage_taken(fayde, ...)`: Fayde sprite flashes white for ~0.1s (hit flash). `damage_taken` is only emitted when `final_damage > 0` — zero-damage events produce no hit flash.
- On `player_hp_careful` (≤ 33 HP): HP bar shifts to amber warning treatment (exact style: Combat HUD GDD + art-director).
- On `player_hp_desperate` (≤ 15 HP): HP bar shifts to red critical treatment, overriding careful state (exact style: Combat HUD GDD + art-director).
- No screen shake at MVP; if added, owned by Game Feel / Juice — not this system.

**Hit feedback — enemies:**
- On `damage_taken(enemy, ...)`: enemy sprite flashes white for ~0.1s.
- Damage number floats up from hit position and fades. Number color: white (neutral), Prana element color for elemental hits (Ashfire = `#F24C1D`, etc.). Style TBD with art-director.

**Death — enemies:**
- On `enemy_killed`: crumple → bloom → dissolve sequence (Art Bible §6, all-ages safe). Duration ~0.5–1.0s. Animation owned by Enemy AI / Game Feel; H&D only emits the signal.

**Death — Fayde:**
- On `player_died`: Fayde plays death animation (design TBD). Transition to `DEATH_SCREEN` handled by Game State & Scene Flow.

**Audio:**
- On `damage_taken(fayde, ...)`: play `"player_hit"` SFX (AudioSystem).
- On `damage_taken(enemy, ...)`: play `"enemy_hit"` SFX.
- On `enemy_killed`: play `"enemy_death"` SFX; elemental death variant if element applies.
- On `player_died`: `player_died` signal transitions Audio System to END music state (handled by Audio System listening directly).

*`art-director` not consulted — lean mode. Review manually before production.*

## UI Requirements

*Detailed spec owned by Combat HUD GDD (System #22). Requirements from H&D's perspective:*

- Combat HUD must display `fayde_current_hp` and `FAYDE_MAX_HP` as both a visual bar and a numerical readout (e.g., `"72 / 100"`).
- HP bar must update on every `damage_taken` and `health_restored` signal — no polling.
- HP bar drain/fill should be animated (tween), not instant. Duration TBD in Combat HUD GDD; suggest 0.1–0.2s for responsiveness.
- On `player_hp_careful` signal: HP bar enters amber warning state. On `player_hp_desperate`: HP bar enters red critical state. Exact treatment: Combat HUD GDD + art-director.
- On `player_died`: HP bar shows 0/100. No further updates needed (run over).
- Enemy HP bars: not shown at MVP. Wave / Encounter System may show aggregate wave progress instead. No per-enemy HP UI at MVP scope.

## Open Questions

1. **Hit-stop on heavy hits** — Should a Charger hit (20 damage, 20% of max HP) trigger a brief freeze-frame (~0.05–0.1s) for impact weight? Adds feel but requires Game Feel / Juice coordination. *Deferred to Game Feel / Juice GDD.*

2. **Damage number display** — Floating damage numbers: always visible, or only on elemental hits? Fayde-only, enemy-only, or both? Size scaling for high-damage hits? *Deferred to Combat HUD GDD.*

3. **I-frame visual clarity** — Should Fayde flash/blink repeatedly during the i-frame window to communicate invincibility to the player? Current spec says one flash at hit and one at window midpoint. Needs playtesting.

4. ~~**HP restore threshold decision**~~ — **Resolved**: Verdant at 0.02 magnitude (6 HP) is intentional. Verdant derives value from Combination Resolution combo bonuses, not raw heal. See Known Design Tension note.

5. ~~**Simultaneous death events**~~ — **Resolved**: `enemy_killed` fires before `player_died` in same-frame resolution. Game State & Scene Flow must treat `player_died` as taking priority over any in-flight win condition. See Rule 5.
