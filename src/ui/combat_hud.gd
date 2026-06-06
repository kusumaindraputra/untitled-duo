## combat_hud.gd — CombatHUD Control node. Persistent HUD sub-scene (ADR-0005).
##
## Displays Fayde's HP bar, HP label, and chain-dot indicator.
## Signal consumer only — never reads Autoload state directly (ADR-0003 Pattern 1).
## Stays alive across scene transitions (PROCESS_MODE_ALWAYS, CanvasLayer layer 10).
##
## Float accumulator animation (ADR-0004): HP bar and heal tint are driven by
## _hp_timer and _tint_timer decremented in _process(), NOT by Godot Tween nodes.
## This allows QA tests to advance animation by calling hud._process(delta) directly.
##
## Story 001: Scene skeleton, HP bar drain/fill animation, dead state, run_started reset.
## Story 002: Zone colors, heal tint revert, DESPERATE pulse animation.
## Story 003: Floating damage number labels for enemy hits.
## Story 004: Chain-dot indicator, chain_index_changed logic.
##
## ADR: ADR-0003 (Signal-Driven Architecture), ADR-0004 (Float Accumulator Timers),
##      ADR-0005 (Persistent HUD Sub-Scene Swap)
extends Control


# ── Constants ─────────────────────────────────────────────────────────────────

## Fayde's maximum HP — matches HealthAndDamage.FAYDE_MAX_HP.
const FAYDE_MAX_HP: int = 100

## Duration in seconds for the HP bar drain animation on damage (AC-HUD-01, AC-HUD-02a).
const HP_BAR_DRAIN_DURATION: float = 0.15

## Duration in seconds for the HP bar fill animation on heal (AC-HUD-09).
## Must be >= 0.15 to satisfy the sfx_fayde_heal audio silence contract (AC-HUD-09).
const HP_BAR_FILL_DURATION: float = 0.20

## Duration in seconds the green heal tint persists before reverting to zone color (AC-HUD-08).
const HEAL_TINT_DURATION: float = 0.20

## HP bar modulate for the FULL zone — warm white.
const HP_COLOR_FULL: Color = Color("#F5F0E8")

## HP bar modulate for the CAREFUL zone — amber.
const HP_COLOR_CAREFUL: Color = Color("#FFA500")

## HP bar modulate for the DESPERATE zone — danger red.
const HP_COLOR_DESPERATE: Color = Color("#FF3333")

## HP label font color for normal (FULL) zone.
const HP_COLOR_LABEL_FULL: Color = Color("#FFFFFF")

## Heal tint color applied to hp_bar.modulate immediately on health_restored.
const HEAL_TINT_COLOR: Color = Color(0.6, 1.0, 0.6, 1.0)


# ── Public child node references (created in _ready() for testability) ────────

## The ProgressBar node displaying Fayde's HP fraction.
## Created programmatically so tests can instantiate CombatHUD without a .tscn.
var hp_bar: ProgressBar = null

## The Label node displaying "current / max" HP as integers.
var hp_label: Label = null

## HBoxContainer holding the chain-dot indicator sprites.
## Hidden outside combat; Story 004 populates it.
var chain_dots_container: HBoxContainer = null


# ── Private state ─────────────────────────────────────────────────────────────

## True after player_died fires; all H&D signal handlers early-return while dead.
## Reset to false on run_started.
var _dead: bool = false

## The HP value the bar is animating FROM (visual position when animation started).
var _hp_start: float = FAYDE_MAX_HP

## The HP value the bar is animating TOWARD.
var _hp_target: float = FAYDE_MAX_HP

## Countdown timer for the HP bar animation. Decrements each _process frame.
## Animation is complete when this reaches 0. Value == 0 means no animation running.
var _hp_timer: float = 0.0

## Total duration of the current HP animation (stored for lerp calculation).
var _hp_duration: float = 0.0

## Countdown timer for the green heal tint. When it reaches 0, _revert_zone_color() fires.
var _tint_timer: float = 0.0

## The current HP zone, tracked so _revert_zone_color() restores the correct color.
## Defaults to FULL; updated by _on_hp_zone_changed.
var _current_zone: GameEnums.HPZone = GameEnums.HPZone.FULL


# ── Built-in virtual methods ──────────────────────────────────────────────────

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_create_ui_nodes()
	HealthAndDamage.damage_taken.connect(_on_damage_taken)
	HealthAndDamage.health_restored.connect(_on_health_restored)
	HealthAndDamage.player_died.connect(_on_player_died)
	HealthAndDamage.player_hp_zone_changed.connect(_on_hp_zone_changed)
	GameStateManager.run_started.connect(_on_run_started)
	GameStateManager.preparation_started.connect(_on_preparation_started)
	GameStateManager.combat_started.connect(_on_combat_started)
	SpellCastingEffects.chain_index_changed.connect(_on_chain_index_changed)
	SpellCastingEffects.spell_hit_element.connect(_on_spell_hit_element)


func _process(delta: float) -> void:
	# HP bar float accumulator (ADR-0004)
	if _hp_timer > 0.0:
		_hp_timer -= delta
		if _hp_timer <= 0.0:
			_hp_timer = 0.0
			hp_bar.value = _hp_target
		else:
			var t: float = 1.0 - (_hp_timer / _hp_duration)
			hp_bar.value = lerpf(_hp_start, _hp_target, t)

	# Heal tint float accumulator (ADR-0004)
	if _tint_timer > 0.0:
		_tint_timer -= delta
		if _tint_timer <= 0.0:
			_tint_timer = 0.0
			_revert_zone_color()


func _exit_tree() -> void:
	if HealthAndDamage.damage_taken.is_connected(_on_damage_taken):
		HealthAndDamage.damage_taken.disconnect(_on_damage_taken)
	if HealthAndDamage.health_restored.is_connected(_on_health_restored):
		HealthAndDamage.health_restored.disconnect(_on_health_restored)
	if HealthAndDamage.player_died.is_connected(_on_player_died):
		HealthAndDamage.player_died.disconnect(_on_player_died)
	if HealthAndDamage.player_hp_zone_changed.is_connected(_on_hp_zone_changed):
		HealthAndDamage.player_hp_zone_changed.disconnect(_on_hp_zone_changed)
	if GameStateManager.run_started.is_connected(_on_run_started):
		GameStateManager.run_started.disconnect(_on_run_started)
	if GameStateManager.preparation_started.is_connected(_on_preparation_started):
		GameStateManager.preparation_started.disconnect(_on_preparation_started)
	if GameStateManager.combat_started.is_connected(_on_combat_started):
		GameStateManager.combat_started.disconnect(_on_combat_started)
	if SpellCastingEffects.chain_index_changed.is_connected(_on_chain_index_changed):
		SpellCastingEffects.chain_index_changed.disconnect(_on_chain_index_changed)
	if SpellCastingEffects.spell_hit_element.is_connected(_on_spell_hit_element):
		SpellCastingEffects.spell_hit_element.disconnect(_on_spell_hit_element)


# ── Private methods ───────────────────────────────────────────────────────────

## Creates all child UI nodes programmatically.
## Called once from _ready(). Kept separate so tests can inspect node state
## after construction without needing a full scene instantiation.
func _create_ui_nodes() -> void:
	hp_bar = ProgressBar.new()
	hp_bar.max_value = FAYDE_MAX_HP
	hp_bar.value = FAYDE_MAX_HP
	hp_bar.step = 0.01  # fractional values required during animation
	hp_bar.modulate = HP_COLOR_FULL
	add_child(hp_bar)

	hp_label = Label.new()
	hp_label.text = "%d / %d" % [FAYDE_MAX_HP, FAYDE_MAX_HP]
	hp_label.add_theme_color_override(&"font_color", HP_COLOR_LABEL_FULL)
	add_child(hp_label)

	chain_dots_container = HBoxContainer.new()
	chain_dots_container.visible = false
	add_child(chain_dots_container)


## Starts a float-accumulator HP bar animation toward [param target] hp value.
## Captures the current visual position (hp_bar.value) as the start — this ensures
## rapid mid-animation hits begin from the current visual position, not the old start
## (AC-HUD-22).
##
## [param target] the HP value to animate toward.
## [param duration] animation duration in seconds (HP_BAR_DRAIN_DURATION or HP_BAR_FILL_DURATION).
func _start_hp_animation(target: float, duration: float) -> void:
	_hp_start = hp_bar.value   # capture current visual position (critical for AC-HUD-22)
	_hp_target = target
	_hp_duration = duration
	_hp_timer = duration


## Reverts hp_bar.modulate and hp_label font color to the color matching _current_zone.
## Called by the tint timer expiry and by _on_hp_zone_changed when not dead.
func _revert_zone_color() -> void:
	_on_hp_zone_changed(_current_zone)


## Frees all floating damage label nodes spawned during combat.
## Stub — implemented in Story 003.
func _free_all_damage_labels() -> void:
	pass  # Story 003


## Spawns a floating damage label anchored to [param target]'s screen position.
## Stub — implemented in Story 003.
##
## [param _target] the enemy node that was hit.
## [param _damage] the final damage value to display.
func _spawn_damage_label_for_enemy(_target: Node, _damage: int) -> void:
	pass  # Story 003


# ── Signal callbacks ──────────────────────────────────────────────────────────

## Handles damage_taken from HealthAndDamage.
## Updates the HP label immediately (same frame) and starts the drain animation.
## Enemy hits (non-player targets) always route to _spawn_damage_label_for_enemy,
## even after death (queued spells can still land after player_died fires).
## Player HP updates are skipped if Fayde is dead.
func _on_damage_taken(target: Node, final_damage: int, current_hp: int) -> void:
	if not target.is_in_group(&"player"):
		_spawn_damage_label_for_enemy(target, final_damage)
		return
	if _dead:
		return
	hp_label.text = "%d / %d" % [current_hp, FAYDE_MAX_HP]
	_start_hp_animation(float(current_hp), HP_BAR_DRAIN_DURATION)


## Handles health_restored from HealthAndDamage.
## Updates the HP label, starts the fill animation, and applies the heal tint.
## Skips if the target is not the player or if Fayde is dead.
func _on_health_restored(target: Node, _healed_amount: int, current_hp: int) -> void:
	if not target.is_in_group(&"player"):
		return
	if _dead:
		return
	hp_label.text = "%d / %d" % [current_hp, FAYDE_MAX_HP]
	_start_hp_animation(float(current_hp), HP_BAR_FILL_DURATION)
	hp_bar.modulate = HEAL_TINT_COLOR
	_tint_timer = HEAL_TINT_DURATION


## Handles player_died from HealthAndDamage.
## Enters dead state: cancels any running HP animation and snaps bar to 0.
func _on_player_died() -> void:
	_dead = true
	_hp_timer = 0.0
	_tint_timer = 0.0
	hp_bar.value = 0.0
	hp_label.text = "0 / %d" % FAYDE_MAX_HP


## Handles player_hp_zone_changed from HealthAndDamage.
## Applies the zone-appropriate color to hp_bar.modulate and hp_label font color.
## No-op when dead (dead state uses its own visual treatment).
func _on_hp_zone_changed(zone: GameEnums.HPZone) -> void:
	if _dead:
		return
	_current_zone = zone
	match zone:
		GameEnums.HPZone.FULL:
			hp_bar.modulate = HP_COLOR_FULL
			hp_label.add_theme_color_override(&"font_color", HP_COLOR_LABEL_FULL)
		GameEnums.HPZone.CAREFUL:
			hp_bar.modulate = HP_COLOR_CAREFUL
			hp_label.add_theme_color_override(&"font_color", HP_COLOR_CAREFUL)
		GameEnums.HPZone.DESPERATE:
			hp_bar.modulate = HP_COLOR_DESPERATE
			hp_label.add_theme_color_override(&"font_color", HP_COLOR_DESPERATE)
		_:
			push_warning("CombatHUD: unhandled HPZone value %d — zone color not updated" % zone)


## Handles run_started from GameStateManager.
## Resets all HUD state to match a fresh run: HP to max, no tween, FULL zone colors,
## chain dots hidden, all floating damage labels freed.
func _on_run_started() -> void:
	_dead = false
	_hp_timer = 0.0
	_tint_timer = 0.0
	_current_zone = GameEnums.HPZone.FULL
	hp_bar.value = FAYDE_MAX_HP
	hp_label.text = "%d / %d" % [FAYDE_MAX_HP, FAYDE_MAX_HP]
	hp_bar.modulate = HP_COLOR_FULL
	hp_label.add_theme_color_override(&"font_color", HP_COLOR_LABEL_FULL)
	chain_dots_container.visible = false
	_free_all_damage_labels()


## Handles preparation_started from GameStateManager.
## Hides the chain-dot container between waves.
func _on_preparation_started(_idx: int, _rem: int) -> void:
	chain_dots_container.visible = false


## Handles combat_started from GameStateManager.
## Chain dots are shown when chain_index_changed fires (Story 004).
func _on_combat_started(_is_boss: bool) -> void:
	pass  # Story 004 shows chain dots on first chain_index_changed


## Handles chain_index_changed from SpellCastingEffects.
## Stub — chain-dot indicator logic implemented in Story 004.
func _on_chain_index_changed(_combo_idx: int, _combo_count: int) -> void:
	pass  # Story 004


## Handles spell_hit_element from SpellCastingEffects.
## Stub — damage number coloring logic implemented in Story 003.
func _on_spell_hit_element(_target: Node, _prana_type_id: int) -> void:
	pass  # Story 003
