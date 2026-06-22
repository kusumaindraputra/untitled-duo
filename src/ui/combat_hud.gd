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
## Story S5-06: Chain dots repositioned above Fayde in screen-space (AC-HUD-27–AC-HUD-30).
##
## ADR: ADR-0003 (Signal-Driven Architecture), ADR-0004 (Float Accumulator Timers),
##      ADR-0005 (Persistent HUD Sub-Scene Swap)
class_name CombatHUD
extends Control


# ── Constants ─────────────────────────────────────────────────────────────────

## Fayde's maximum HP — matches HealthAndDamage.FAYDE_MAX_HP.
const FAYDE_MAX_HP: int = 100

## Boss HP bar dimensions (px) — wide, thin banner anchored top-centre.
const BOSS_BAR_WIDTH: float = 520.0
const BOSS_BAR_HEIGHT: float = 18.0

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

## Font color for "+N HP" floating heal labels (bright green).
const HEAL_LABEL_COLOR: Color = Color("#44FF88")

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

## Upward pixel offset for chain dots above Fayde's world position in screen-space (AC-HUD-27).
const DOT_OFFSET_ABOVE_PLAYER: float = 48.0


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
## Setter connects/disconnects dash_cooldown_changed when assigned after _ready().
@export var player_controller: PlayerController = null:
	set(pc):
		if is_instance_valid(player_controller) and \
				player_controller.dash_cooldown_changed.is_connected(_on_dash_cooldown_changed):
			player_controller.dash_cooldown_changed.disconnect(_on_dash_cooldown_changed)
		player_controller = pc
		if is_instance_valid(pc) and is_node_ready():
			pc.dash_cooldown_changed.connect(_on_dash_cooldown_changed)

## World-space Node2D whose position drives chain dot screen placement (AC-HUD-27–AC-HUD-29).
## Assign PlayerController in scene; plain Node2D is acceptable in headless tests.
@export var fayde_node: Node2D = null

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

## Active looping tweens for chain dot animations. Indexed parallel to dot children.
## Killed and cleared in _rebuild_dots before freeing children.
var _dot_tweens: Array[Tween] = []

## Combo counter label that appears above chain dots when chain_index >= 2.
## Shows "2x", "3x" with a pop-in animation; auto-fades after 0.6s.
var _combo_counter_label: Label = null
var _combo_counter_tween: Tween = null

## Floor indicator label — shows "Floor N" in the top-left corner.
var _floor_label: Label = null

## Run-progress breadcrumb — shows "Room X / Y" under the floor label so the player
## can sense how far into the floor they are. Driven by debug_game_loop on each
## room transition via set_room_progress(). null until _build_hud() runs.
var _room_label: Label = null

## Full-screen danger vignette (DESPERATE zone only). Pulses at ≤1.25Hz per HUD
## seizure-safety note. Separate from hp_bar pulse so edge signal is visible while
## the player's focus is on the arena centre (Gamefeel Audit Issue 5.3).
var _vignette: ColorRect = null
var _vignette_tween: Tween = null

## Boss intro UI — name card label and a large top-centre HP bar. Hidden until a
## boss spawns (WaveManager.boss_spawned). _boss_ref tracks the live boss so
## _on_damage_taken can drain the bar; cleared when the boss dies.
var _boss_name_label: Label = null
var _boss_bar: ProgressBar = null
var _boss_ref: Node = null
var _boss_intro_tween: Tween = null

# ── Built-in virtual methods ──────────────────────────────────────────────────

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_create_ui_nodes()
	HealthAndDamage.damage_taken.connect(_on_damage_taken)
	HealthAndDamage.enemy_killed.connect(_on_enemy_killed)
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

	# Chain dot position tracking above Fayde in screen-space (AC-HUD-27, AC-HUD-28, AC-HUD-29)
	if chain_dots_container.visible and is_instance_valid(fayde_node):
		var screen_pos: Vector2 = get_viewport().get_canvas_transform() * fayde_node.global_position
		# Use get_minimum_size() not size: size is layout-deferred (starts at 0 until
		# NOTIFICATION_RESIZED fires); minimum_size is computed immediately from children's
		# custom_minimum_size, giving stable centering even on the first frame.
		var dot_x: float = screen_pos.x - chain_dots_container.get_minimum_size().x * 0.5
		var dot_y: float = maxf(screen_pos.y - DOT_OFFSET_ABOVE_PLAYER, 0.0)
		chain_dots_container.position = Vector2(dot_x, dot_y)


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

	_combo_counter_label = Label.new()
	_combo_counter_label.visible = false
	_combo_counter_label.add_theme_font_size_override(&"font_size", 18)
	_combo_counter_label.position = Vector2(8, 128)
	add_child(_combo_counter_label)

	_floor_label = Label.new()
	_floor_label.text = "Floor 1"
	_floor_label.add_theme_font_size_override(&"font_size", 14)
	_floor_label.position = Vector2(8, 152)
	_floor_label.size = Vector2(120, 20)
	add_child(_floor_label)

	_room_label = Label.new()
	_room_label.text = "Room 1 / 7"
	_room_label.add_theme_font_size_override(&"font_size", 12)
	_room_label.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.78))
	_room_label.position = Vector2(8, 170)
	_room_label.size = Vector2(120, 18)
	add_child(_room_label)

	# DESPERATE vignette — full-screen dark red overlay, starts invisible.
	# z_index below all other HUD elements so text/bars remain legible.
	_vignette = ColorRect.new()
	_vignette.color = Color(0.75, 0.0, 0.0, 0.0)
	_vignette.anchor_right = 1.0
	_vignette.anchor_bottom = 1.0
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.z_index = -1
	add_child(_vignette)

	# Boss HP bar — wide, anchored top-centre. Hidden until a boss spawns.
	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.anchor_left = 0.5
	_boss_bar.anchor_right = 0.5
	_boss_bar.offset_left = -BOSS_BAR_WIDTH * 0.5
	_boss_bar.offset_right = BOSS_BAR_WIDTH * 0.5
	_boss_bar.offset_top = 24.0
	_boss_bar.offset_bottom = 24.0 + BOSS_BAR_HEIGHT
	_boss_bar.add_theme_color_override(&"font_color", Color(1, 1, 1, 1))
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.78, 0.16, 0.18)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.12, 0.04, 0.05, 0.85)
	_boss_bar.add_theme_stylebox_override(&"fill", bar_fill)
	_boss_bar.add_theme_stylebox_override(&"background", bar_bg)
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar.visible = false
	add_child(_boss_bar)

	# Boss name card — centred title that fades in on spawn, sits above the bar.
	_boss_name_label = Label.new()
	_boss_name_label.add_theme_font_size_override(&"font_size", 30)
	_boss_name_label.add_theme_color_override(&"font_color", Color(1.0, 0.86, 0.4))
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_label.anchor_left = 0.0
	_boss_name_label.anchor_right = 1.0
	_boss_name_label.offset_top = 56.0
	_boss_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_name_label.visible = false
	add_child(_boss_name_label)

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
## Also starts the screen-edge vignette pulse. No-op if already running (idempotent).
func _start_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		return
	hp_bar.pivot_offset = hp_bar.size / 2.0  # center pivot so scale expands symmetrically
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_pulse_tween.tween_property(hp_bar, "scale", Vector2(1.03, 1.03), 0.4)
	_pulse_tween.tween_property(hp_bar, "scale", Vector2(1.0, 1.0), 0.4)
	_start_vignette_pulse()


## Stops the DESPERATE pulse animation and snaps hp_bar.scale back to identity (AC-HUD-25).
## Also stops the vignette pulse. No-op if no pulse is currently running.
func _stop_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null
	hp_bar.scale = Vector2(1.0, 1.0)
	_stop_vignette_pulse()


## Starts a looping red vignette pulse at ≤1.25 Hz (0.4s per half-cycle = 0.8s period).
## No-op if vignette is null (headless tests) or already pulsing.
func _start_vignette_pulse() -> void:
	if _vignette == null:
		return
	if _vignette_tween and _vignette_tween.is_valid():
		return
	_vignette_tween = create_tween().set_loops()
	_vignette_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_vignette_tween.tween_property(_vignette, "color:a", 0.28, 0.4)
	_vignette_tween.tween_property(_vignette, "color:a", 0.0, 0.4)


## Stops the vignette pulse and hides it. No-op if not running.
func _stop_vignette_pulse() -> void:
	if _vignette_tween and _vignette_tween.is_valid():
		_vignette_tween.kill()
		_vignette_tween = null
	if _vignette != null:
		_vignette.color.a = 0.0


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
		if target == _boss_ref:
			_boss_bar.value = float(current_hp)
			if current_hp <= 0:
				_hide_boss_ui()
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


## Boss-intro handler: connected to WaveManager.boss_spawned by the game loop.
## Shows the name card + top-centre HP bar and triggers the camera reveal zoom.
func _on_boss_spawned(boss: Node) -> void:
	if not is_instance_valid(boss):
		return
	_boss_ref = boss
	var max_hp: float = float(boss.get_max_hp()) if boss.has_method(&"get_max_hp") else 100.0
	_boss_bar.max_value = max_hp
	_boss_bar.value = max_hp
	_boss_bar.visible = true

	var raw_name: String = boss.get_display_name() if boss.has_method(&"get_display_name") else "BOSS"
	_boss_name_label.text = _humanize_name(raw_name)
	_boss_name_label.visible = true

	# Name card fade: in fast, hold, then fade to a dim persistent label over the bar.
	if _boss_intro_tween:
		_boss_intro_tween.kill()
	_boss_name_label.modulate = Color(1, 1, 1, 0)
	_boss_intro_tween = create_tween()
	_boss_intro_tween.tween_property(_boss_name_label, "modulate:a", 1.0, 0.4)
	_boss_intro_tween.tween_interval(1.6)
	_boss_intro_tween.tween_property(_boss_name_label, "modulate:a", 0.65, 0.5)

	# Camera reveal — only touches zoom, safe against look-ahead (PlayerController).
	if is_instance_valid(player_controller) and player_controller.has_method(&"boss_reveal_zoom"):
		player_controller.boss_reveal_zoom()


## Hides the boss intro UI when the tracked boss is killed. Covers death paths
## that bypass damage_taken (e.g. the F2 debug kill) so the name card/bar never
## linger onto the end screen.
func _on_enemy_killed(instance_id: int, _type_id: int, _affiliation: GameEnums.DamageClass) -> void:
	if is_instance_valid(_boss_ref) and _boss_ref.get_instance_id() == instance_id:
		_hide_boss_ui()


## Hides the boss intro UI and clears the boss reference (on death or teardown).
func _hide_boss_ui() -> void:
	_boss_ref = null
	if _boss_intro_tween:
		_boss_intro_tween.kill()
	if is_instance_valid(_boss_bar):
		_boss_bar.visible = false
	if is_instance_valid(_boss_name_label):
		_boss_name_label.visible = false


## Converts a PascalCase EnemyType name ("VaultSentinel") to a spaced upper-case
## display title ("VAULT SENTINEL").
func _humanize_name(raw: String) -> String:
	var spaced: String = ""
	for i: int in raw.length():
		var ch: String = raw[i]
		if i > 0 and ch == ch.to_upper() and ch != ch.to_lower():
			spaced += " "
		spaced += ch
	return spaced.to_upper()


## Handles health_restored from HealthAndDamage.
## Updates the HP label, starts the fill animation, applies the heal tint,
## and spawns a "+N HP" floating label above Fayde.
## Skips if the target is not the player or if Fayde is dead.
func _on_health_restored(target: Node, healed_amount: int, current_hp: int) -> void:
	if not target.is_in_group(&"player"):
		return
	if _dead:
		return
	hp_label.text = "%d / %d" % [current_hp, FAYDE_MAX_HP]
	_start_hp_animation(float(current_hp), HP_BAR_FILL_DURATION)
	hp_bar.modulate = HEAL_TINT_COLOR
	_tint_timer = HEAL_TINT_DURATION
	if healed_amount > 0:
		_spawn_heal_label(target, healed_amount)


## Spawns a "+N HP" floating label above [param target] in HEAL_LABEL_COLOR.
## Shares the damage-label pool, eviction logic, and float-up animation.
func _spawn_heal_label(target: Node, healed_amount: int) -> void:
	_evict_if_at_cap()
	var label := Label.new()
	label.text = "+%d HP" % healed_amount
	label.add_theme_color_override(&"font_color", HEAL_LABEL_COLOR)
	var world_pos: Vector2 = (target as Node2D).global_position if target is Node2D else Vector2.ZERO
	var vp_pos: Vector2 = get_viewport().get_canvas_transform() * world_pos
	label.position = vp_pos + Vector2(randf_range(-8.0, 8.0), -20.0)
	add_child(label)
	_active_damage_labels.append(label)
	_animate_damage_label(label)


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
	_stop_vignette_pulse()
	for tw in _dot_tweens:
		if is_instance_valid(tw):
			tw.kill()
	_dot_tweens.clear()
	_current_zone = GameEnums.HPZone.FULL
	hp_bar.value = FAYDE_MAX_HP
	hp_label.text = "%d / %d" % [FAYDE_MAX_HP, FAYDE_MAX_HP]
	hp_bar.modulate = HP_COLOR_FULL
	hp_label.add_theme_color_override(&"font_color", HP_COLOR_LABEL_FULL)
	chain_dots_container.visible = false
	if is_instance_valid(_combo_counter_label):
		_combo_counter_label.visible = false
	if _dash_hint_label != null:
		_dash_hint_label.visible = false
	if _dash_cooldown_icon != null:
		_dash_cooldown_icon.color.a = 1.0
		_dash_cooldown_icon.visible = false
	if _floor_label != null:
		_floor_label.text = "Floor 1"
	_free_all_damage_labels()


## Updates the run-progress breadcrumb ("Room X / Y"). Called by debug_game_loop on
## the initial room and after each room transition. No-op before the HUD is built.
func set_room_progress(current: int, total: int) -> void:
	if _room_label != null:
		_room_label.text = "Room %d / %d" % [current, total]


## Handles preparation_started from GameStateManager.
## Hides the chain-dot container between waves; updates floor number label.
func _on_preparation_started(_idx: int, _rem: int) -> void:
	_hide_boss_ui()
	for tw in _dot_tweens:
		if is_instance_valid(tw):
			tw.kill()
	_dot_tweens.clear()
	chain_dots_container.visible = false
	_current_primary_type = -1
	if is_instance_valid(_combo_counter_label):
		_combo_counter_label.visible = false
		_dash_hint_label.visible = false
	if _dash_cooldown_icon != null:
		_dash_cooldown_icon.color.a = 1.0
		_dash_cooldown_icon.visible = false
	if _floor_label != null:
		var floor_num: int = RunManager.get_run_data().get("current_floor", 1)
		_floor_label.text = "Floor %d" % floor_num


## Handles combat_started from GameStateManager.
func _on_combat_started(_is_boss: bool = false) -> void:
	if _dash_hint_label != null:
		_dash_hint_label.visible = true
	if _dash_cooldown_icon != null:
		_dash_cooldown_icon.visible = true
	# Show the chain dots immediately so the cast-flash is visible on the first cast.
	# _rebuild_dots with 1 gray dot = "ready to cast" baseline indicator.
	if chain_dots_container.get_child_count() == 0:
		_rebuild_dots(0, 1)
	chain_dots_container.visible = true


## Handles chain_index_changed from SpellCastingEffects.
## Shows chain dots and rebuilds them for the current combo state.
## Spawns a "2x", "3x" combo counter label when the chain advances beyond the first hit.
func _on_chain_index_changed(combo_idx: int, combo_count: int) -> void:
	chain_dots_container.visible = true
	_rebuild_dots(combo_idx, combo_count)
	# Combo counter: show "2x", "3x" on chain advance beyond first hit.
	if combo_idx >= 2 and is_instance_valid(_combo_counter_label):
		_combo_counter_label.text = "%dx" % combo_idx
		_combo_counter_label.visible = true
		# Per-type color for the counter text.
		if _current_primary_type >= 0:
			var prana_type := PranaCatalog.get_type(_current_primary_type)
			if prana_type != null:
				_combo_counter_label.add_theme_color_override(&"font_color", prana_type.color)
		# Pop-in animation: scale 0.8 → 1.2 → 1.0 + fade out after 0.6s.
		if _combo_counter_tween:
			_combo_counter_tween.kill()
		_combo_counter_label.scale = Vector2(0.8, 0.8)
		_combo_counter_label.modulate.a = 1.0
		_combo_counter_tween = create_tween()
		_combo_counter_tween.tween_property(_combo_counter_label, "scale", Vector2(1.2, 1.2), 0.10)
		_combo_counter_tween.tween_property(_combo_counter_label, "scale", Vector2(1.0, 1.0), 0.15)
		_combo_counter_tween.tween_interval(0.35)
		_combo_counter_tween.tween_property(_combo_counter_label, "modulate:a", 0.0, 0.15)


## Rebuilds chain dot ColorRect children to match current combo state.
## Active dot uses per-type size + looping animation.
## Completed dots (before active) show a dimmed prana color — the trail you've left.
## Future dots (after active) are 8×8 gray — still waiting to be filled.
func _rebuild_dots(active_index: int, count: int) -> void:
	for tw in _dot_tweens:
		if is_instance_valid(tw):
			tw.kill()
	_dot_tweens.clear()
	for child in chain_dots_container.get_children():
		child.free()
	var type_color: Color = Color.WHITE
	if _current_primary_type >= 0:
		var prana_type := PranaCatalog.get_type(_current_primary_type)
		if prana_type != null:
			type_color = prana_type.color
	for i: int in range(count):
		var dot := ColorRect.new()
		var is_active: bool = (i == active_index)
		var is_completed: bool = (i < active_index)
		if is_active:
			dot.custom_minimum_size = _get_dot_size_for_type(_current_primary_type)
			dot.color = type_color
			_dot_tweens.append(_animate_active_dot(dot, _current_primary_type, type_color))
		elif is_completed:
			# Completed dot: prana color, slightly dimmed, no animation — solid trail marker.
			dot.custom_minimum_size = Vector2(6.0, 6.0)
			dot.color = type_color
			dot.color.a = 0.5
			_dot_tweens.append(null)
		else:
			# Future dot: gray, empty — waiting to be filled.
			dot.custom_minimum_size = Vector2(8.0, 8.0)
			dot.color = Color("#888888")
			_dot_tweens.append(null)
		chain_dots_container.add_child(dot)


## Returns the dot size for the active dot based on prana type visual identity.
## Each shape encodes the element's nature — bolt=wide/flat, void=tall/narrow, etc.
func _get_dot_size_for_type(type_id: int) -> Vector2:
	match type_id:
		GameEnums.DamageClass.FIRE:      return Vector2(13.0, 13.0)
		GameEnums.DamageClass.SHADOW:    return Vector2(8.0, 14.0)
		GameEnums.DamageClass.LIGHTNING: return Vector2(16.0, 7.0)
		GameEnums.DamageClass.ICE:       return Vector2(11.0, 11.0)
		GameEnums.DamageClass.NATURE:    return Vector2(12.0, 12.0)
		_:                               return Vector2(10.0, 10.0)


## Creates and returns a looping Tween animating the active dot per prana type.
## Fire=fast flicker, Shadow=slow pulse, Lightning=strobe, Ice=still, Nature=breathe.
## Returns null for ICE (no animation — crystallised/frozen feel).
func _animate_active_dot(dot: ColorRect, type_id: int, base_color: Color) -> Tween:
	match type_id:
		GameEnums.DamageClass.FIRE:
			var tw: Tween = create_tween().set_loops()
			tw.tween_property(dot, "color:a", 0.55, 0.10)
			tw.tween_property(dot, "color:a", 1.0,  0.10)
			return tw
		GameEnums.DamageClass.SHADOW:
			var tw: Tween = create_tween().set_loops()
			tw.tween_property(dot, "color:a", 0.35, 0.55)
			tw.tween_property(dot, "color:a", 1.0,  0.55)
			return tw
		GameEnums.DamageClass.LIGHTNING:
			var tw: Tween = create_tween().set_loops()
			tw.tween_property(dot, "color:a", 0.15, 0.06)
			tw.tween_property(dot, "color:a", 1.0,  0.06)
			return tw
		GameEnums.DamageClass.ICE:
			return null
		GameEnums.DamageClass.NATURE:
			var bright: Color = base_color.lightened(0.35)
			var tw: Tween = create_tween().set_loops()
			tw.tween_property(dot, "color", bright,     0.45)
			tw.tween_property(dot, "color", base_color, 0.45)
			return tw
		_:
			return null


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
