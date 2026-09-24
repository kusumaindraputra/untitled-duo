## HealthAndDamage — Autoload #5. Sole owner of all HP state for the session.
##
## Contract (ADR-0007, health-damage.md):
##   - apply_damage() is the single entry point for ALL damage sources (DIRECT, DOT, CONTACT).
##   - apply_heal() is the single entry point for ALL healing.
##   - Enemy HP is held in _enemy_registry; no enemy node stores its own HP.
##   - Fayde HP is held in _fayde_current_hp; no other system stores it.
##   - enemy_killed is emitted exactly once per enemy death; registry entry erased immediately.
##   - player_died is emitted exactly once per run (DEAD state guard prevents re-emit).
##   - I-frames apply only to Fayde, only for DamageSource.CONTACT, and only when final_damage > 0.
##   - run_started resets Fayde HP to FAYDE_MAX_HP and emits player_hp_zone_changed(FULL).
##   - force_end_iframe_window() is a TEST SEAM ONLY — never call from gameplay code.
##
## Registration: Autoload #5 in project.godot (ADR-0002).
##   Node name in Project Settings: "HealthAndDamage". No class_name — Godot 4 rejects
##   class_name matching the Autoload node name ("hides autoload singleton" parse error).
##   Access in game code: HealthAndDamage.apply_damage(...)
##   Access in tests: preload("res://src/systems/health_and_damage.gd").new()
extends Node

# ── Constants ─────────────────────────────────────────────────────────────────

## Fayde's starting and maximum HP for every run.
const FAYDE_MAX_HP: int = 100

## Duration in seconds during which CONTACT damage to Fayde is blocked after a hit.
const FAYDE_IFRAME_DURATION: float = 0.5

## Fraction of FAYDE_MAX_HP below which HPZone.CAREFUL is entered (default: 40%).
const FAYDE_HP_CRITICAL_CAREFUL: float = 0.40

## Fraction of FAYDE_MAX_HP below which HPZone.DESPERATE is entered (default: 20%).
## Must be strictly less than FAYDE_HP_CRITICAL_CAREFUL (startup assert enforces this).
const FAYDE_HP_CRITICAL_DESPERATE: float = 0.20

## final_damage value at or above which heavy_hit is emitted alongside damage_taken.
const HEAVY_HIT_THRESHOLD: int = 15

## Multiplier applied to CONTACT final_damage on Fayde during the player's first run.
## Set by Tutorial/Onboarding via first_run_active flag. 0.5 = half damage.
const FIRST_RUN_DAMAGE_MULTIPLIER: float = 0.5

# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted when a target takes damage and final_damage > 0.
## [param target] is the affected node (Fayde or an enemy Node2D).
## [param final_damage] is the post-pipeline integer damage applied.
## [param current_hp] is the target's HP after the hit.
signal damage_taken(target: Node, final_damage: int, current_hp: int)

## Emitted when a target is healed and the effective heal > 0.
## [param target] is the healed node.
## [param healed_amount] is the integer HP delta actually applied (capped by max_hp).
## [param current_hp] is the target's HP after the heal.
signal health_restored(target: Node, healed_amount: int, current_hp: int)

## Emitted once when Fayde's current_hp reaches 0. Never re-emitted within a run.
signal player_died()

## Emitted when an enemy's HP reaches 0.
## [param instance_id] is the Node instance ID (from Node.get_instance_id()).
## [param type_id] is the EnemyCatalog entry ID for the enemy's type.
## [param prana_affiliation] is the enemy's elemental affiliation (DamageClass.NONE for neutral).
signal enemy_killed(instance_id: int, type_id: int, prana_affiliation: GameEnums.DamageClass)

## Emitted alongside damage_taken when final_damage >= HEAVY_HIT_THRESHOLD.
## Game Feel / Juice uses this for hit-stop and screen shake (health-damage.md Rule 2 step 9).
signal heavy_hit(target: Node, final_damage: int)

## Emitted when Fayde's HP crosses a zone boundary in either direction.
## Fires once per zone transition; not emitted continuously within a zone.
## Audio System and Combat HUD listen to update their danger-state presentation.
signal player_hp_zone_changed(zone: GameEnums.HPZone)

# ── Public variables ──────────────────────────────────────────────────────────

## Set to true by Tutorial/Onboarding for the player's first lifetime run.
## Health & Damage reads this in apply_damage() step 6 (FIRST_RUN_DAMAGE_MULTIPLIER).
## Tutorial/Onboarding owns the flag lifecycle; H&D trusts the caller.
var first_run_active: bool = false

# ── Private state ─────────────────────────────────────────────────────────────

## Fayde's current HP. Clamped to [0, FAYDE_MAX_HP]. Set to 0 on death; reset on run_started.
var _fayde_current_hp: int = FAYDE_MAX_HP

## Whether Fayde is dead this run. Terminal until run_started.
var _fayde_dead: bool = false

## DEBUG QA ONLY — blocks all incoming damage to Fayde. Remove before ship.
var _debug_god_mode: bool = false

## Whether a CONTACT i-frame window is currently active for Fayde.
var _iframe_active: bool = false

## Float accumulator for the i-frame timer (ADR-0004 accumulator pattern).
var _iframe_timer: float = 0.0

## Current HP danger zone for Fayde.  Tracked to detect boundary crossings.
var _current_zone: GameEnums.HPZone = GameEnums.HPZone.FULL

## Registry of live enemy HP records.  Keyed by Node.get_instance_id() → EnemyHPInstance.
var _enemy_registry: Dictionary = {}

# ── Built-in virtual methods ──────────────────────────────────────────────────

func _ready() -> void:
	assert(
		FAYDE_HP_CRITICAL_CAREFUL > FAYDE_HP_CRITICAL_DESPERATE,
		"CAREFUL threshold must exceed DESPERATE threshold"
	)
	GameStateManager.run_started.connect(_on_run_started)


func _process(delta: float) -> void:
	if _iframe_active:
		_iframe_timer += delta
		if _iframe_timer >= FAYDE_IFRAME_DURATION:
			_iframe_active = false
			_iframe_timer = 0.0


# ── Public API — registration ─────────────────────────────────────────────────

## Registers an enemy node before it enters the scene tree.
##
## Must be called by WaveManager BEFORE add_child() — see ADR-0007 registration contract.
## Reads [param type_id] from EnemyCatalog to initialise current_hp and max_hp from base_hp.
## Pushes an error and no-ops if the type_id is not found in EnemyCatalog.
## [param hp_mult] scales base_hp — WaveManager passes the elite multiplier (ADR-0018).
##
## Example (WaveManager):
##   HealthAndDamage.register_enemy(enemy_node, enemy_type.id)
##   arena.add_child(enemy_node)
func register_enemy(enemy: Node, type_id: int, hp_mult: float = 1.0) -> void:
	var enemy_type: EnemyType = EnemyCatalog.get_type(type_id)
	if enemy_type == null:
		push_error(
			"HealthAndDamage.register_enemy(): EnemyCatalog.get_type(%d) returned null — "
			% type_id
			+ "enemy not registered; apply_damage() will push_error for this instance"
		)
		return

	var rec: EnemyHPInstance = EnemyHPInstance.new()
	# hp_mult > 1.0 for elites (ADR-0018); EnemyInstance.make_elite() mirrors it.
	var hp: int = maxi(roundi(float(enemy_type.base_hp) * hp_mult), 1)
	rec.max_hp = hp
	rec.current_hp = hp
	rec.type_id = type_id
	rec.prana_affiliation = enemy_type.prana_affiliation
	_enemy_registry[enemy.get_instance_id()] = rec


## Removes a dead enemy's registry entry.
##
## Called internally by apply_damage() immediately after emitting enemy_killed.
## External callers (e.g., WaveManager) do not need to call this — it is automatic.
func unregister_enemy(instance_id: int) -> void:
	_enemy_registry.erase(instance_id)


# ── Public API — damage and healing ──────────────────────────────────────────

## Applies damage through the full H&D pipeline (health-damage.md Rule 2).
##
## Pipeline steps:
##   1a. Dash i-frame guard  (Fayde + CONTACT only, via PlayerController.is_invincible())
##   2.  Dead-target guard
##   2b. I-frame check       (Fayde + CONTACT only)
##   3.  Elemental multiplier lookup (element == null → multiplier = 1.0)
##   4.  final_damage = clamp(roundi(base_damage × multiplier), 0, target.max_hp)
##   5.  First-run mercy     (Fayde + CONTACT + first_run_active only)
##   6.  Apply HP delta
##   7.  Emit damage_taken   (only if final_damage > 0)
##   8.  Emit heavy_hit      (only if final_damage >= HEAVY_HIT_THRESHOLD)
##   9.  Check HP zone transitions
##   10. Death check
##
## [param target] must be in the "player" group for Fayde, or pre-registered for enemies.
## [param element] pass null for no elemental modifier (multiplier = 1.0).
func apply_damage(
	target: Node,
	base_damage: float,
	element: GameEnums.DamageClass,
	source: GameEnums.DamageSource
) -> void:
	var is_player: bool = target.is_in_group(&"player")

	# DEBUG QA — block all damage to Fayde in god mode
	if is_player and _debug_god_mode:
		return

	# Step 1a — Dash invincibility guard (Fayde + CONTACT only)
	if is_player and source == GameEnums.DamageSource.CONTACT:
		if target.has_method(&"is_invincible") and target.is_invincible():
			return

	# Step 2 — Dead-target guard
	if is_player:
		if _fayde_dead:
			return
	else:
		var instance_id: int = target.get_instance_id()
		if not _enemy_registry.has(instance_id):
			push_error(
				"HealthAndDamage.apply_damage(): enemy instance %d not in registry — "
				% instance_id
				+ "call register_enemy() before add_child() (ADR-0007)"
			)
			return
		if _enemy_registry[instance_id].is_dead:
			return

	# Step 2b — I-frame check (Fayde + CONTACT only)
	if is_player and source == GameEnums.DamageSource.CONTACT and _iframe_active:
		return

	# Step 3 — Elemental multiplier
	var multiplier: float = 1.0
	# NOTE: ElementalAffinityWeakness system is not yet implemented.
	# When it lands, replace the multiplier line with:
	#   multiplier = ElementalAffinityWeakness.get_multiplier(element, target_affiliation)
	# For now, multiplier stays 1.0 for all elements (no-op; pipeline structure is in place).

	# Step 4 — Compute final_damage
	var target_max_hp: int = _get_max_hp(target)
	var final_damage: int = clampi(roundi(base_damage * multiplier), 0, target_max_hp)

	# Step 5 — First-run mercy (Fayde + CONTACT + first_run_active flag)
	if is_player and source == GameEnums.DamageSource.CONTACT and first_run_active:
		final_damage = clampi(roundi(float(final_damage) * FIRST_RUN_DAMAGE_MULTIPLIER), 0, target_max_hp)

	# Step 6 — Apply HP delta
	if is_player:
		_fayde_current_hp = clampi(_fayde_current_hp - final_damage, 0, FAYDE_MAX_HP)
	else:
		var rec: EnemyHPInstance = _enemy_registry[target.get_instance_id()]
		rec.current_hp = clampi(rec.current_hp - final_damage, 0, rec.max_hp)

	# Arm i-frames if this was a qualifying CONTACT hit on Fayde with damage > 0
	if is_player and source == GameEnums.DamageSource.CONTACT and final_damage > 0:
		_iframe_active = true
		_iframe_timer = 0.0

	# Step 7 — Emit damage_taken (only when final_damage > 0)
	if final_damage > 0:
		damage_taken.emit(target, final_damage, _get_current_hp(target))

	# Step 8 — Emit heavy_hit
	if final_damage >= HEAVY_HIT_THRESHOLD and final_damage > 0:
		heavy_hit.emit(target, final_damage)

	# Step 9 — HP zone transition check (Fayde only)
	if is_player:
		_check_hp_zone_change()

	# Step 10 — Death check
	var current_hp: int = _get_current_hp(target)
	if current_hp <= 0:
		if is_player:
			_fayde_dead = true
			player_died.emit()
		else:
			var instance_id: int = target.get_instance_id()
			var rec: EnemyHPInstance = _enemy_registry[instance_id]
			rec.is_dead = true
			enemy_killed.emit(instance_id, rec.type_id, rec.prana_affiliation)
			_enemy_registry.erase(instance_id)


## Applies healing to [param target] (health-damage.md Rule 4).
##
## Precondition: [param heal_amount] must be > 0. Negative values are a caller error;
## this method logs push_error and returns without modifying HP or emitting signals.
## Emit health_restored only when effective heal > 0 (target was not already at max HP).
##
## Example:
##   HealthAndDamage.apply_heal(fayde_node, 6.0)  # Verdant Prana regen tick
func apply_heal(target: Node, heal_amount: float) -> void:
	if heal_amount <= 0.0:
		push_error(
			"HealthAndDamage.apply_heal(): heal_amount must be > 0 (got %f). "
			% heal_amount
			+ "Use apply_damage() for damage. Negative heals are a caller error (health-damage.md Rule 4)."
		)
		return

	var is_player: bool = target.is_in_group(&"player")
	var old_hp: int
	var new_hp: int
	var max_hp: int

	if is_player:
		old_hp = _fayde_current_hp
		max_hp = FAYDE_MAX_HP
		_fayde_current_hp = roundi(clampf(float(_fayde_current_hp) + heal_amount, 0.0, float(max_hp)))
		new_hp = _fayde_current_hp
	else:
		var instance_id: int = target.get_instance_id()
		if not _enemy_registry.has(instance_id):
			push_error(
				"HealthAndDamage.apply_heal(): enemy instance %d not in registry — "
				% instance_id
				+ "call register_enemy() before healing (ADR-0007)"
			)
			return
		var rec: EnemyHPInstance = _enemy_registry[instance_id]
		old_hp = rec.current_hp
		max_hp = rec.max_hp
		rec.current_hp = roundi(clampf(float(rec.current_hp) + heal_amount, 0.0, float(max_hp)))
		new_hp = rec.current_hp

	var healed_amount: int = new_hp - old_hp
	if healed_amount > 0:
		health_restored.emit(target, healed_amount, new_hp)
		if is_player:
			_check_hp_zone_change()


## TEST SEAM ONLY — do not call from gameplay code.
##
## DEBUG QA ONLY — instantly kills all living enemies and emits enemy_killed for each.
## Allows the wave to complete so the QA run can progress through all floors.
func debug_kill_all_enemies() -> void:
	var ids: Array = _enemy_registry.keys()
	for id: int in ids:
		var rec: EnemyHPInstance = _enemy_registry[id]
		if not rec.is_dead:
			rec.is_dead = true
			enemy_killed.emit(id, rec.type_id, rec.prana_affiliation)
	_enemy_registry.clear()


## Immediately cancels the active i-frame window and resets the timer.
## No-op if no window is currently active.
## Required by AC-HD-07 and AC-HD-33 to test i-frame expiry without real time passage.
func force_end_iframe_window() -> void:
	_iframe_active = false
	_iframe_timer = 0.0


# ── Private methods ───────────────────────────────────────────────────────────

## Returns the current HP for [param target] (Fayde or a registered enemy).
func _get_current_hp(target: Node) -> int:
	if target.is_in_group(&"player"):
		return _fayde_current_hp
	var instance_id: int = target.get_instance_id()
	if _enemy_registry.has(instance_id):
		return _enemy_registry[instance_id].current_hp
	return 0


## Returns the max HP for [param target] (Fayde or a registered enemy).
func _get_max_hp(target: Node) -> int:
	if target.is_in_group(&"player"):
		return FAYDE_MAX_HP
	var instance_id: int = target.get_instance_id()
	if _enemy_registry.has(instance_id):
		return _enemy_registry[instance_id].max_hp
	return 0


## Calculates Fayde's current HPZone and emits player_hp_zone_changed if it changed.
## Only fires when the zone boundary is crossed — not every call (health-damage.md Rule 9).
func _check_hp_zone_change() -> void:
	var careful_threshold: int = roundi(float(FAYDE_MAX_HP) * FAYDE_HP_CRITICAL_CAREFUL)
	var desperate_threshold: int = roundi(float(FAYDE_MAX_HP) * FAYDE_HP_CRITICAL_DESPERATE)

	var new_zone: GameEnums.HPZone
	if _fayde_current_hp <= desperate_threshold:
		new_zone = GameEnums.HPZone.DESPERATE
	elif _fayde_current_hp <= careful_threshold:
		new_zone = GameEnums.HPZone.CAREFUL
	else:
		new_zone = GameEnums.HPZone.FULL

	if new_zone != _current_zone:
		_current_zone = new_zone
		player_hp_zone_changed.emit(new_zone)


# ── Signal callbacks ──────────────────────────────────────────────────────────

## Resets all run-scoped state when a new run begins (health-damage.md Rule 7).
##
## Steps (a) reset Fayde HP, (b) reset zone tracker, (c) emit zone signal unconditionally.
## Step (c) is required to synchronise Audio System and Combat HUD regardless of
## the zone at run end — a previous run that ended in DESPERATE must not leak zone state.
func _on_run_started() -> void:
	_fayde_current_hp = FAYDE_MAX_HP
	_fayde_dead = false
	_iframe_active = false
	_iframe_timer = 0.0
	_enemy_registry.clear()
	_current_zone = GameEnums.HPZone.FULL
	player_hp_zone_changed.emit(GameEnums.HPZone.FULL)
