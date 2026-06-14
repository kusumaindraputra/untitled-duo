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
## Story S5-05: Dash discoverability hint + cooldown icon (AC-DH-01–AC-DH-07).
##
## ADR: ADR-0003 (Signal-Driven Architecture), ADR-0004 (Float Accumulator Timers),
##      ADR-0005 (Persistent HUD Sub-Scene Swap)
class_name CombatHUD
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

## Maximum floating damage labels allowed on screen simultaneously (TR-CH-006).
const DAMAGE_LABEL_POOL_CAP: int = 12

## Vertical distance a damage label floats upward during animation (pixels).
const DAMAGE_FLOAT_DISTANCE: float = 32.0

## Total duration of the float + fade animation in seconds.
const DAMAGE_FLOAT_DURATION: float = 0.8

## Duration of the chain-dot flash when a cast fires (playtest feedback).
const CAST_FLASH_DURATION: float = 0.15

## Seconds after animation start before the fade-out begins.
const DAMAGE_FADE_START: float = 0.5

## Opacity of DashCooldownIcon when dash is on cooldown (AC-DH-04).
const DASH_COOLDOWN_DIMMED_ALPHA: float = 0.4

## Hint text shown to player during first combat encounter (AC-DH-03).
# TODO(l10n): localize before shipping
const DASH_HINT_TEXT: String = "Shift / LT — Dash"


# ── Public child node references (created in _ready() for testability) ────────

## The ProgressBar node displaying Fayde's HP fraction.
## Created programmatically so tests can instantiate CombatHUD without a .tscn.
var hp_bar: ProgressBar = null

## The Label node displaying "current / max" HP as integers.
var hp_label: Label = null

## HBoxContainer holding the chain-dot indicator sprites.
## Hidden outside combat; Story 004 populates it.
var chain_dots_container: HBoxContainer = null

## @export var to receive PlayerController from scene (S5-05, AC-DH-04, AC-DH-05).
## Null in headless tests — all dash handlers null-guard on this.
@export var player_controller: PlayerController = null

## Label shown during Combat Phase with the dash keybinding hint (AC-DH-01, AC-DH-03).
## Null in headless tests.
var _dash_hint_label: Label = null

## ColorRect icon dimmed when dash is on cooldown (AC-DH-04, AC-DH-05).
## Null in headless tests.
var _dash_cooldown_icon: ColorRect = null


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

## Looping Tween that scales hp_bar between 1.0 and 1.03 while zone is DESPERATE (AC-HUD-24).
## Null when no pulse is running. Killed and set to null in _stop_pulse().
var _pulse_tween: Tween = null

## Per-frame element map: target Node → prana_type_id received via spell_hit_element.
## Consumed once by _on_damage_taken and erased per-target (TR-CH-005).
var _pending_element: Dictionary = {}

## Active floating damage label pool. Filtered on each spawn call for eviction (TR-CH-006).
var _active_damage_labels: Array[Label] = []

## Countdown for chain-dot cast flash. Resets to CAST_FLASH_DURATION on cast_hit_started.
var _cast_flash_timer: float = 0.0

## Primary Prana type index cached from the last combo_resolved signal.
## -1 means no spell resolved this combat.
var _current_primary_type: int = -1


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
	SpellCastingEffects.cast_hit_started.connect(_on_cast_hit_started)
	CombinationResolution.combo_resolved.connect(_on_combo_resolved)
	if player_controller != null:
		player_controller.dash_cooldown_changed.connect(_on_dash_cooldown_changed)


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

	# Cast flash float accumulator
	if _cast_flash_timer > 0.0:
		_cast_flash_timer -= delta
		if _cast_flash_timer <= 0.0:
			_cast_flash_timer = 0.0
			chain_dots_container.modulate = Color.WHITE


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
	if SpellCastingEffects.cast_hit_started.is_connected(_on_cast_hit_started):
		SpellCastingEffects.cast_hit_started.disconnect(_on_cast_hit_started)
	if CombinationResolution.combo_resolved.is_connected(_on_combo_resolved):
		CombinationResolution.combo_resolved.disconnect(_on_combo_resolved)
	if is_instance_valid(player_controller) and \
			player_controller.dash_cooldown_changed.is_connected(_on_dash_cooldown_changed):
		player_controller.dash_cooldown_changed.disconnect(_on_dash_cooldown_changed)


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
	hp_bar.position = Vector2(8, 8)
	hp_bar.size = Vector2(200, 20)
	add_child(hp_bar)

	hp_label = Label.new()
	hp_label.text = "%d / %d" % [FAYDE_MAX_HP, FAYDE_MAX_HP]
	hp_label.add_theme_color_override(&"font_color", HP_COLOR_LABEL_FULL)
	hp_label.position = Vector2(8, 32)
	hp_label.size = Vector2(200, 20)
	add_child(hp_label)

	chain_dots_container = HBoxContainer.new()
	chain_dots_container.visible = false
	chain_dots_container.position = Vector2(8, 56)
	add_child(chain_dots_container)

	_dash_hint_label = Label.new()
	_dash_hint_label.text = DASH_HINT_TEXT
	_dash_hint_label.position = Vector2(8, 80)
	_dash_hint_label.size = Vector2(200, 20)
	_dash_hint_label.visible = false
	add_child(_dash_hint_label)

	_dash_cooldown_icon = ColorRect.new()
	_dash_cooldown_icon.custom_minimum_size = Vector2(16, 16)
	_dash_cooldown_icon.size = Vector2(16, 16)
	_dash_cooldown_icon.position = Vector2(8, 104)
	_dash_cooldown_icon.color = Color("#FFFFFF")
	_dash_cooldown_icon.color.a = 1.0
	_dash_cooldown_icon.visible = false
	add_child(_dash_cooldown_icon)


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


## Starts the looping DESPERATE pulse animation on hp_bar.scale (AC-HUD-24).
## No-op if a valid pulse tween is already running (idempotent).
func _start_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		return
	hp_bar.pivot_offset = hp_bar.size / 2.0  # center pivot so scale expands symmetrically
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_pulse_tween.tween_property(hp_bar, "scale", Vector2(1.03, 1.03), 0.4)
	_pulse_tween.tween_property(hp_bar, "scale", Vector2(1.0, 1.0), 0.4)


## Stops the DESPERATE pulse animation and snaps hp_bar.scale back to identity (AC-HUD-25).
## No-op if no pulse is currently running.
func _stop_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null
	hp_bar.scale = Vector2(1.0, 1.0)


## Frees all active floating damage label nodes and clears the pool.
## Called on run_started to reset the HUD for a new run.
func _free_all_damage_labels() -> void:
	for l: Label in _active_damage_labels:
		if is_instance_valid(l):
			l.free()
	_active_damage_labels.clear()


## Spawns a floating damage label at [param target]'s screen position.
##
## [param target] the hit node; world position read if it is a Node2D.
## [param damage] integer damage value shown as label text.
## [param color] font color: element color, grey (#AAAAAA) for Fayde, white (#FFFFFF) default.
func _spawn_damage_label(target: Node, damage: int, color: Color) -> void:
	_evict_if_at_cap()
	var label := Label.new()
	label.text = str(damage)
	label.add_theme_color_override(&"font_color", color)
	var world_pos: Vector2 = (target as Node2D).global_position if target is Node2D else Vector2.ZERO
	var vp_pos: Vector2 = get_viewport().get_canvas_transform() * world_pos
	label.position = vp_pos + Vector2(randf_range(-8.0, 8.0), 0.0)
	add_child(label)
	_active_damage_labels.append(label)
	_animate_damage_label(label)


## Evicts the oldest label from the pool when at capacity (TR-CH-006).
## Filters freed instances first, then pops front if pool is at or above DAMAGE_LABEL_POOL_CAP.
func _evict_if_at_cap() -> void:
	# Array[T].filter() returns untyped Array in Godot 4 — use assign() to retype.
	# Variant lambda parameter avoids cast errors on freed Label instances.
	_active_damage_labels.assign(_active_damage_labels.filter(
		func(l: Variant) -> bool: return is_instance_valid(l)
	))
	if _active_damage_labels.size() >= DAMAGE_LABEL_POOL_CAP:
		var oldest: Label = _active_damage_labels.pop_front()
		if is_instance_valid(oldest):
			oldest.free()


## Starts the float-up and fade-out tween animation for a damage label (GDD Formula 2).
##
## Position floats up DAMAGE_FLOAT_DISTANCE pixels over DAMAGE_FLOAT_DURATION seconds.
## Alpha fades from 1.0 to 0.0 over the final (DAMAGE_FLOAT_DURATION - DAMAGE_FADE_START) seconds.
## Label is freed via queue_free at animation end.
func _animate_damage_label(label: Label) -> void:
	var t: Tween = create_tween()
	t.set_parallel(true)
	t.tween_property(label, "position:y", label.position.y - DAMAGE_FLOAT_DISTANCE, DAMAGE_FLOAT_DURATION)
	t.tween_interval(DAMAGE_FADE_START)
	t.chain().tween_property(label, "modulate:a", 0.0, DAMAGE_FLOAT_DURATION - DAMAGE_FADE_START)
	t.chain().tween_callback(label.queue_free)


# ── Public methods ────────────────────────────────────────────────────────────

## Returns true if the DESPERATE pulse animation is currently running.
## Used by tests and Story 004 chain-dot indicator.
func is_pulse_active() -> bool:
	return _pulse_tween != null and _pulse_tween.is_valid()


# ── Signal callbacks ──────────────────────────────────────────────────────────

## Handles damage_taken from HealthAndDamage.
## Enemy hits always spawn a floating label (even after death — in-flight spells can still land).
## Element color from same-frame spell_hit_element overrides the default white (TR-CH-005).
## Player HP bar updates and grey label spawn are skipped if Fayde is dead.
func _on_damage_taken(target: Node, final_damage: int, current_hp: int) -> void:
	if not target.is_in_group(&"player"):
		if final_damage > 0:
			var color: Color = Color("#FFFFFF")
			if _pending_element.has(target):
				var prana_type: PranaType = PranaCatalog.get_type(_pending_element[target])
				if prana_type != null:
					color = prana_type.color
			_spawn_damage_label(target, final_damage, color)
		_pending_element.erase(target)
		return
	if _dead:
		return
	hp_label.text = "%d / %d" % [current_hp, FAYDE_MAX_HP]
	_start_hp_animation(float(current_hp), HP_BAR_DRAIN_DURATION)
	if final_damage > 0:
		_spawn_damage_label(target, final_damage, Color("#AAAAAA"))


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
	_stop_pulse()
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
			_stop_pulse()
		GameEnums.HPZone.CAREFUL:
			hp_bar.modulate = HP_COLOR_CAREFUL
			hp_label.add_theme_color_override(&"font_color", HP_COLOR_CAREFUL)
			_stop_pulse()
		GameEnums.HPZone.DESPERATE:
			hp_bar.modulate = HP_COLOR_DESPERATE
			hp_label.add_theme_color_override(&"font_color", HP_COLOR_DESPERATE)
			_start_pulse()
		_:
			push_warning("CombatHUD: unhandled HPZone value %d — zone color not updated" % zone)


## Handles run_started from GameStateManager.
## Resets all HUD state to match a fresh run: HP to max, no tween, FULL zone colors,
## chain dots hidden, all floating damage labels freed.
func _on_run_started() -> void:
	_dead = false
	_hp_timer = 0.0
	_tint_timer = 0.0
	_stop_pulse()
	_current_zone = GameEnums.HPZone.FULL
	hp_bar.value = FAYDE_MAX_HP
	hp_label.text = "%d / %d" % [FAYDE_MAX_HP, FAYDE_MAX_HP]
	hp_bar.modulate = HP_COLOR_FULL
	hp_label.add_theme_color_override(&"font_color", HP_COLOR_LABEL_FULL)
	chain_dots_container.visible = false
	if _dash_hint_label != null:
		_dash_hint_label.visible = false
	if _dash_cooldown_icon != null:
		_dash_cooldown_icon.color.a = 1.0
		_dash_cooldown_icon.visible = false
	_free_all_damage_labels()


## Handles preparation_started from GameStateManager.
## Hides the chain-dot container between waves.
func _on_preparation_started(_idx: int, _rem: int) -> void:
	chain_dots_container.visible = false
	_current_primary_type = -1
	if _dash_hint_label != null:
		_dash_hint_label.visible = false
	if _dash_cooldown_icon != null:
		_dash_cooldown_icon.color.a = 1.0
		_dash_cooldown_icon.visible = false


## Handles combat_started from GameStateManager.
func _on_combat_started(_is_boss: bool = false) -> void:
	if _dash_hint_label != null:
		_dash_hint_label.visible = true
	if _dash_cooldown_icon != null:
		_dash_cooldown_icon.visible = true


## Handles chain_index_changed from SpellCastingEffects.
## Shows chain dots and rebuilds them for the current combo state.
func _on_chain_index_changed(combo_idx: int, combo_count: int) -> void:
	chain_dots_container.visible = true
	_rebuild_dots(combo_idx, combo_count)


## Rebuilds chain dot ColorRect children to match current combo state.
## Uses _current_primary_type (cached from combo_resolved) for active dot color.
## Inactive dots are always Color("#888888"). Falls back to white if no type cached.
func _rebuild_dots(active_index: int, count: int) -> void:
	for child in chain_dots_container.get_children():
		child.free()
	var active_color: Color = Color.WHITE
	if _current_primary_type >= 0:
		active_color = PranaCatalog.get_type(_current_primary_type).color
	for i: int in range(count):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(6.0, 6.0)
		dot.color = active_color if i == active_index else Color("#888888")
		chain_dots_container.add_child(dot)


## Caches the primary Prana type from a resolved spell for use in chain dot coloring.
func _on_combo_resolved(spell_effect: SpellEffect) -> void:
	_current_primary_type = spell_effect.primary_type


## Handles cast_hit_started from SpellCastingEffects.
## Flashes chain_dots_container bright yellow as immediate cast confirmation (playtest feedback).
func _on_cast_hit_started(_lock_duration: float) -> void:
	chain_dots_container.modulate = Color(1.5, 1.5, 0.3, 1.0)
	_cast_flash_timer = CAST_FLASH_DURATION


## Handles spell_hit_element from SpellCastingEffects.
## Stores the element for per-frame correlation with the subsequent damage_taken signal (TR-CH-005).
func _on_spell_hit_element(target: Node, prana_type_id: int) -> void:
	_pending_element[target] = prana_type_id


## Handles dash_cooldown_changed from PlayerController (AC-DH-04, AC-DH-05).
## Dims icon when on cooldown; restores full opacity when dash is available.
func _on_dash_cooldown_changed(available: bool) -> void:
	if _dash_cooldown_icon == null:
		return
	_dash_cooldown_icon.color.a = 1.0 if available else DASH_COOLDOWN_DIMMED_ALPHA
