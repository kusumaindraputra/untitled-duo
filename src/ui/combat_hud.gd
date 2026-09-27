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

## HP bar modulate for the FULL zone — the art bible's dedicated health red (§4.4, ADR-0035).
const HP_COLOR_FULL: Color = Color("#E61A0D")

## HP bar modulate for the CAREFUL zone — same health red; the numeric label turns amber.
const HP_COLOR_CAREFUL: Color = Color("#E61A0D")

## HP bar modulate for the DESPERATE zone — hotter red, paired with the scale pulse.
const HP_COLOR_DESPERATE: Color = Color("#FF3333")

## HP label font color for normal (FULL) zone.
const HP_COLOR_LABEL_FULL: Color = Color("#FFFFFF")

## HP label font color for the CAREFUL zone — amber, so the zone still reads at a glance.
const HP_COLOR_LABEL_CAREFUL: Color = Color("#FFA500")

## HP label font color for the DESPERATE zone.
const HP_COLOR_LABEL_DESPERATE: Color = Color("#FF3333")

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

## Centralized player-facing UI copy (dash hint, etc.), staged for localization
## (see /localize). Preloaded so it resolves without _ready() in headless tests.
const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")

## Upward pixel offset for chain dots above Fayde's world position in screen-space (AC-HUD-27).
const DOT_OFFSET_ABOVE_PLAYER: float = 48.0
## World-space height the chain dots float above Fayde's feet: clears the top of his
## 32 px sprite (ADR-0022) at any camera zoom. Never closer than DOT_OFFSET_ABOVE_PLAYER.
const DOT_WORLD_LIFT: float = 38.0


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
## True while the Special meter is full (its label shows the ready prompt).
var _special_ready: bool = false

## Special meter bar (beside the dash icon); fills from SpellCastingEffects.special_meter_changed.
var _special_bar: ProgressBar = null

## Text over the Special meter: "SPECIAL" while charging, the ready prompt when full.
var _special_label: Label = null

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

## Recognition callout — a centred top banner announcing a fired Cascade or armed
## Prana Reaction on combo_resolved, making the ADR-0016 recognition layer legible.
## Pop-in scale + auto-fade, mirroring the combo counter's feedback style.
var _recognition_callout_label: Label = null
var _recognition_callout_tween: Tween = null

## Floor indicator label — shows "Floor N · name" in the top-left corner.
var _floor_label: Label = null
## ADR-0020 — the live floor-intro banner, so a new one replaces it instead of stacking.
var _floor_banner: Label = null
var _room_banner: Label = null

## Run-progress breadcrumb — shows "Room X / Y" under the floor label so the player
## can sense how far into the floor they are. Driven by debug_game_loop on each
## room transition via set_room_progress(). null until _build_hud() runs.
var _room_label: Label = null

## Floor minimap — a top-right row of one marker per room on the current floor,
## colour-coded by room type, with the current room outlined and cleared rooms
## filled. Rebuilt each call to set_minimap(). null in headless tests.
var _minimap_root: Control = null
var _minimap_markers: Array[Panel] = []
## U4 node map; replaces the marker strip when the floor's edges are known. Null until used.
var _floor_map: FloorMap = null

## Marker dimensions and spacing (px) for the floor minimap.
const _MINIMAP_MARKER_SIZE: float = 20.0
const _MINIMAP_MARKER_SEP: float = 8.0
const _MINIMAP_MARGIN: float = 12.0

## Room-type marker colours (mirrors DungeonGraph.ROOM_TYPE_* ordering: Combat/Elite/Rest/Boss).
## Art bible §4.4: stone, brass, moss, rust — never a Prana or boss colour (ADR-0039).
const _MINIMAP_TYPE_COLORS: Array[Color] = UIPalette.MAP_ROOM

## Per-type letter glyph so the minimap is readable without relying on colour alone
## (colorblind accessibility, ui-code.md). Parallel to _MINIMAP_TYPE_COLORS.
const _MINIMAP_TYPE_LETTERS: Array[String] = ["C", "E", "R", "B"]
## ADR-0026 room modifiers, indexed by RoomModifiers value (NONE, CHALLENGE, CURSED).
const _MINIMAP_MOD_LETTERS: Array[String] = ["", "!", "X"]
const _MINIMAP_MOD_COLORS: Array[Color] = [Color.TRANSPARENT, Color(1.0, 1.0, 1.0), UIPalette.MAP_CURSED]

## Full-screen danger vignette (DESPERATE zone only). Pulses at ≤1.25Hz per HUD
## seizure-safety note. Separate from hp_bar pulse so edge signal is visible while
## the player's focus is on the arena centre (Gamefeel Audit Issue 5.3).
var _vignette: ColorRect = null
var _vignette_tween: Tween = null

## Boss intro UI — name card label and a large top-centre HP bar. Hidden until a
## boss spawns (WaveManager.boss_spawned). _boss_ref tracks the live boss so
## _on_damage_taken can drain the bar; cleared when the boss dies.
var _boss_name_label: Label = null
var _boss_bar: BossHealthBar = null
var _boss_ref: Node = null
var _boss_intro_tween: Tween = null

## ADR-0019 style widget: live rank letter + meter, and the room-clear rank banner.
var _style_label: Label = null
var _style_bar: ProgressBar = null
var _rank_banner: Label = null
var _rank_reward_label: Label = null
var _rank_tween: Tween = null
## Last live rank letter shown (pops the label when it changes).
var _style_letter: String = ""
## Top-left column width: the boss UI is kept clear of it (ADR-0019 HUD fix).
const LEFT_COLUMN_WIDTH: float = 232.0
## U3 left HUD card colours. Its height follows the rows it shows (ADR-0035).
const LEFT_PANEL_BG: Color = UIPalette.CARD
const LEFT_PANEL_BORDER: Color = UIPalette.CARD_BORDER
## ADR-0035 left card metrics: inner padding, gap between rows, bar width and the
## minimum bar heights (bars grow to fit their label at larger text sizes).
const LEFT_PAD: float = 12.0
const LEFT_ROW_GAP: float = 6.0
const LEFT_INNER_WIDTH: float = 208.0
const HP_BAR_MIN_HEIGHT: float = 22.0
const SPECIAL_BAR_MIN_HEIGHT: float = 16.0
## Whether the left card is laid out for combat (re-used when text size changes).
var _left_combat: bool = false
var _left_layout_queued: bool = false
## Style rank badge edge length in px.
const STYLE_BADGE_SIZE: float = 34.0
## U3 — card behind the left column. Null in headless tests.
var _left_panel: Panel = null
## ADR-0045 — Core + sigil chips under the left card. Fed by the game loop.
var _sigil_strip: SigilStrip = null
## Style rank badge (frame tinted by rank; _style_label is its child). Null headless.
var _style_badge: Panel = null
## "STYLE" caption beside the badge. Null headless.
var _style_caption: Label = null
## U3 — dash charges / recharge ring under Fayde. Null in headless tests.
var _dash_ring: DashRing = null
## HP bar flash on a hit (U3): the white fill shows through untinted.
const HIT_FLASH_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const HIT_FLASH_DURATION: float = 0.12
## Ring centre offset below Fayde's origin, in screen px.
const DASH_RING_DROP: float = 10.0
const STYLE_RANK_COLORS: Dictionary = {
	"S": Color(1.0, 0.82, 0.25), "A": Color(1.0, 0.55, 0.3), "B": Color(0.55, 0.85, 1.0),
	"C": Color(0.75, 0.75, 0.8), "D": Color(0.5, 0.5, 0.55),
}

# ── Built-in virtual methods ──────────────────────────────────────────────────

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	# ADR-0019 HUD fix: the root used to be 0×0 (anchors_preset 0 in the scene), so every
	# anchored child (boss bar, name card, callout, vignette) collapsed onto the top-left
	# corner over Fayde's HP bar. Fill the viewport, but never eat mouse input.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_create_ui_nodes()
	get_viewport().size_changed.connect(_layout_boss_ui)
	InputPrompts.device_changed.connect(_on_device_changed)
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
	SpellCastingEffects.special_meter_changed.connect(_on_special_meter_changed)
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
		var zoom_y: float = get_viewport().get_canvas_transform().get_scale().y
		var lift: float = maxf(DOT_OFFSET_ABOVE_PLAYER, DOT_WORLD_LIFT * zoom_y)
		var dot_y: float = maxf(screen_pos.y - lift, 0.0)
		chain_dots_container.position = Vector2(dot_x, dot_y)

	_update_dash_ring()


## U3 — keeps the dash ring under Fayde during combat, fed from the PlayerController.
func _update_dash_ring() -> void:
	if _dash_ring == null:
		return
	var in_combat: bool = _dash_hint_label != null and _dash_hint_label.visible
	if not in_combat or not is_instance_valid(player_controller) or not is_instance_valid(fayde_node):
		_dash_ring.visible = false
		return
	_dash_ring.set_state(player_controller.get_dash_charges(), player_controller.get_max_dash_charges(),
		player_controller.get_dash_recharge_remaining(), player_controller.get_dash_recharge_duration())
	if _dash_ring.visible:
		var screen_pos: Vector2 = get_viewport().get_canvas_transform() * fayde_node.global_position
		_dash_ring.position = screen_pos + Vector2(0.0, DASH_RING_DROP) - _dash_ring.size * 0.5


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
	if SpellCastingEffects.special_meter_changed.is_connected(_on_special_meter_changed):
		SpellCastingEffects.special_meter_changed.disconnect(_on_special_meter_changed)
	if CombinationResolution.combo_resolved.is_connected(_on_combo_resolved):
		CombinationResolution.combo_resolved.disconnect(_on_combo_resolved)
	if get_viewport() != null and get_viewport().size_changed.is_connected(_layout_boss_ui):
		get_viewport().size_changed.disconnect(_layout_boss_ui)
	if is_instance_valid(player_controller) and \
			player_controller.dash_cooldown_changed.is_connected(_on_dash_cooldown_changed):
		player_controller.dash_cooldown_changed.disconnect(_on_dash_cooldown_changed)


# ── Private methods ───────────────────────────────────────────────────────────

## Creates all child UI nodes programmatically.
## Called once from _ready(). Kept separate so tests can inspect node state
## after construction without needing a full scene instantiation.
func _create_ui_nodes() -> void:
	# U3 — one framed card behind the left column so HP, Special, dash, floor and Style
	# read as a single HUD block instead of loose labels over the room.
	_left_panel = Panel.new()
	var card := StyleBoxFlat.new()
	card.bg_color = LEFT_PANEL_BG
	card.border_color = LEFT_PANEL_BORDER
	card.set_border_width_all(1)
	card.set_corner_radius_all(6)
	_left_panel.add_theme_stylebox_override(&"panel", card)
	_left_panel.position = Vector2(4, 4)
	_left_panel.size = Vector2(LEFT_COLUMN_WIDTH, HP_BAR_MIN_HEIGHT + LEFT_PAD * 2.0)  # re-stacked below
	_left_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_left_panel)
	# ADR-0045 — the run's Core and sigils as chips under the left card.
	_sigil_strip = SigilStrip.new()
	_sigil_strip.max_width = LEFT_COLUMN_WIDTH
	_sigil_strip.layout_changed.connect(_queue_left_layout)
	add_child(_sigil_strip)

	hp_bar = ProgressBar.new()
	hp_bar.max_value = FAYDE_MAX_HP
	hp_bar.value = FAYDE_MAX_HP
	hp_bar.step = 0.01  # fractional values required during animation
	hp_bar.show_percentage = false
	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.16, 0.16, 0.19, 1.0)
	hp_bg.border_color = Color(1.0, 1.0, 1.0, 0.14)
	hp_bg.set_border_width_all(1)
	hp_bg.set_corner_radius_all(3)
	hp_bar.add_theme_stylebox_override(&"background", hp_bg)
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color.WHITE  # tinted by modulate (zone colour)
	hp_fill.set_corner_radius_all(3)
	hp_bar.add_theme_stylebox_override(&"fill", hp_fill)
	hp_bar.modulate = HP_COLOR_FULL
	hp_bar.position = Vector2(LEFT_PAD, LEFT_PAD)
	hp_bar.size = Vector2(LEFT_INNER_WIDTH, HP_BAR_MIN_HEIGHT)
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hp_bar)

	# HP number sits inside the bar, right-aligned, outlined so it reads on any fill.
	hp_label = Label.new()
	hp_label.text = "%d / %d" % [FAYDE_MAX_HP, FAYDE_MAX_HP]
	hp_label.add_theme_color_override(&"font_color", HP_COLOR_LABEL_FULL)
	hp_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	hp_label.add_theme_constant_override(&"outline_size", 5)
	hp_label.add_theme_font_size_override(&"font_size", 14)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.position = Vector2(LEFT_PAD, LEFT_PAD)
	hp_label.size = Vector2(LEFT_INNER_WIDTH - 6.0, HP_BAR_MIN_HEIGHT)
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hp_label)

	chain_dots_container = HBoxContainer.new()
	chain_dots_container.visible = false
	chain_dots_container.position = Vector2(8, 56)
	add_child(chain_dots_container)

	_dash_hint_label = Label.new()
	_dash_hint_label.text = InputPrompts.dash_hint()
	_dash_hint_label.add_theme_font_size_override(&"font_size", 13)
	_dash_hint_label.add_theme_color_override(&"font_color", UIPalette.TEXT)
	_dash_hint_label.position = Vector2(30, 58)
	_dash_hint_label.size = Vector2(190, 18)
	_dash_hint_label.visible = false
	add_child(_dash_hint_label)

	_dash_cooldown_icon = ColorRect.new()
	_dash_cooldown_icon.custom_minimum_size = Vector2(12, 12)
	_dash_cooldown_icon.size = Vector2(12, 12)
	_dash_cooldown_icon.position = Vector2(12, 61)
	_dash_cooldown_icon.color = Color("#FFFFFF")
	_dash_cooldown_icon.color.a = 1.0
	_dash_cooldown_icon.visible = false
	add_child(_dash_cooldown_icon)

	_special_bar = ProgressBar.new()
	_special_bar.max_value = 100.0
	_special_bar.value = 0.0
	_special_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.16, 0.16, 0.19, 1.0)
	bg.border_color = Color(1.0, 1.0, 1.0, 0.14)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(3)
	_special_bar.add_theme_stylebox_override(&"background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color.WHITE  # tinted via modulate: grey while charging, core colour when full
	fill.set_corner_radius_all(3)
	_special_bar.add_theme_stylebox_override(&"fill", fill)
	_special_bar.position = Vector2(12, 38)
	_special_bar.size = Vector2(208, 16)
	_special_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_special_bar.modulate = Color(0.75, 0.75, 0.75)
	_special_bar.visible = false
	add_child(_special_bar)

	_special_label = Label.new()
	_special_label.text = _COPY.special_label
	_special_label.add_theme_font_size_override(&"font_size", 12)
	_special_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_special_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_special_label.add_theme_constant_override(&"outline_size", 4)
	_special_label.position = Vector2(16, 38)
	_special_label.visible = false
	add_child(_special_label)

	_combo_counter_label = Label.new()
	_combo_counter_label.visible = false
	_combo_counter_label.add_theme_font_size_override(&"font_size", 18)
	_combo_counter_label.position = Vector2(8, 0.0)  # y set by _layout_left_column
	add_child(_combo_counter_label)

	# Recognition callout — full-width top-centre banner for Cascades / Reactions
	# (ADR-0016). Anchored so it stays centred at any resolution; ignores mouse.
	_recognition_callout_label = Label.new()
	_recognition_callout_label.visible = false
	_recognition_callout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_recognition_callout_label.add_theme_font_size_override(&"font_size", 26)
	_recognition_callout_label.anchor_left = 0.0
	_recognition_callout_label.anchor_right = 1.0
	_recognition_callout_label.offset_top = 96.0
	_recognition_callout_label.offset_bottom = 140.0
	_recognition_callout_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_recognition_callout_label)

	_floor_label = Label.new()
	_floor_label.text = floor_label_text(1)
	_floor_label.add_theme_font_size_override(&"font_size", 14)
	_floor_label.position = Vector2(12, 80)
	_floor_label.size = Vector2(208, 20)
	add_child(_floor_label)

	_room_label = Label.new()
	_room_label.text = "Room 1 / 7"
	_room_label.add_theme_font_size_override(&"font_size", 13)
	_room_label.add_theme_color_override(&"font_color", UIPalette.TEXT_DIM)
	_room_label.position = Vector2(12, 98)
	_room_label.size = Vector2(120, 18)
	add_child(_room_label)

	_dash_ring = DashRing.new()
	_dash_ring.visible = false
	add_child(_dash_ring)

	# Floor minimap — top-right room-path strip. Empty until set_minimap() runs;
	# markers are built/positioned there (viewport width is known by then).
	_minimap_root = Control.new()
	_minimap_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_minimap_root)

	# DESPERATE vignette — full-screen dark red overlay, starts invisible.
	# z_index below all other HUD elements so text/bars remain legible.
	_vignette = ColorRect.new()
	_vignette.color = Color(0.75, 0.0, 0.0, 0.0)
	_vignette.anchor_right = 1.0
	_vignette.anchor_bottom = 1.0
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.z_index = -1
	add_child(_vignette)

	# Boss HP bar — top-centre, hidden until a boss spawns. ADR-0045: phase notches,
	# ghost chunk and phase flash are drawn by BossHealthBar.
	_boss_bar = BossHealthBar.new()
	_boss_bar.size = Vector2(BOSS_BAR_WIDTH, BOSS_BAR_HEIGHT)
	_boss_bar.visible = false
	add_child(_boss_bar)

	# Boss name card — centred title that fades in on spawn, sits above the bar.
	_boss_name_label = Label.new()
	_boss_name_label.add_theme_font_size_override(&"font_size", 30)
	_boss_name_label.add_theme_color_override(&"font_color", UIPalette.ACCENT)
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_label.anchor_left = 0.0
	_boss_name_label.anchor_right = 1.0
	_boss_name_label.offset_top = 56.0
	_boss_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_name_label.visible = false
	add_child(_boss_name_label)
	_layout_boss_ui()

	# ADR-0019 style meter — U3: a rank badge (letter in a frame tinted by rank) with a
	# small caption and the meter bar beside it, at the bottom of the left card.
	_style_badge = Panel.new()
	var badge := StyleBoxFlat.new()
	badge.bg_color = Color(0.06, 0.06, 0.08, 0.9)
	badge.set_border_width_all(2)
	badge.border_color = Color.WHITE
	badge.set_corner_radius_all(4)
	_style_badge.add_theme_stylebox_override(&"panel", badge)
	_style_badge.position = Vector2(12, 122)
	_style_badge.size = Vector2(STYLE_BADGE_SIZE, STYLE_BADGE_SIZE)
	_style_badge.pivot_offset = Vector2(STYLE_BADGE_SIZE, STYLE_BADGE_SIZE) * 0.5
	_style_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_badge.visible = false
	add_child(_style_badge)

	_style_label = Label.new()
	_style_label.add_theme_font_size_override(&"font_size", 20)
	_style_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_style_label.add_theme_constant_override(&"outline_size", 4)
	_style_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label.size = Vector2(STYLE_BADGE_SIZE, STYLE_BADGE_SIZE)
	_style_label.visible = false
	_style_badge.add_child(_style_label)

	_style_caption = Label.new()
	_style_caption.text = _COPY.style_label
	_style_caption.add_theme_font_size_override(&"font_size", 12)
	_style_caption.add_theme_color_override(&"font_color", UIPalette.TEXT_DIM)
	_style_caption.position = Vector2(20 + STYLE_BADGE_SIZE, 122)
	_style_caption.visible = false
	add_child(_style_caption)

	_style_bar = ProgressBar.new()
	_style_bar.show_percentage = false
	_style_bar.max_value = 100.0
	var sbg := StyleBoxFlat.new()
	sbg.bg_color = Color(0.08, 0.08, 0.10, 0.85)
	var sfill := StyleBoxFlat.new()
	sfill.bg_color = Color.WHITE
	_style_bar.add_theme_stylebox_override(&"background", sbg)
	_style_bar.add_theme_stylebox_override(&"fill", sfill)
	_style_bar.position = Vector2(20 + STYLE_BADGE_SIZE, 144)
	_style_bar.size = Vector2(200 - STYLE_BADGE_SIZE, 8)
	_style_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_bar.visible = false
	add_child(_style_bar)

	# Room-clear rank banner — centred, above the middle of the screen.
	_rank_banner = Label.new()
	_rank_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_banner.add_theme_font_size_override(&"font_size", 34)
	_rank_banner.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_rank_banner.add_theme_constant_override(&"outline_size", 6)
	_rank_banner.anchor_left = 0.0
	_rank_banner.anchor_right = 1.0
	_rank_banner.anchor_top = 0.28
	_rank_banner.anchor_bottom = 0.28
	_rank_banner.offset_bottom = 84.0
	_rank_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rank_banner.visible = false
	add_child(_rank_banner)
	# Reward line under the letter, smaller so the rank reads first.
	_rank_reward_label = Label.new()
	_rank_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_reward_label.add_theme_font_size_override(&"font_size", 18)
	_rank_reward_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_rank_reward_label.add_theme_constant_override(&"outline_size", 4)
	_rank_reward_label.position = Vector2(0.0, 44.0)
	_rank_reward_label.anchor_right = 1.0
	_rank_reward_label.offset_right = 0.0
	_rank_reward_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rank_banner.add_child(_rank_reward_label)

	# ADR-0035: rows are stacked from their measured heights, so re-stack whenever a
	# text size changes (the Text size setting is applied a frame after creation).
	for l: Label in [hp_label, _special_label, _dash_hint_label, _floor_label, _room_label, _style_caption]:
		l.minimum_size_changed.connect(_queue_left_layout)
	_layout_left_column(false)


## ADR-0019 — places the boss bar and name card top-centre in absolute pixels, never
## over the top-left column (HP, dash, Special, floor). Re-run on viewport resize.
func _layout_boss_ui() -> void:
	if _boss_bar == null or not is_inside_tree():
		return
	var vp: Vector2 = get_viewport_rect().size
	var width: float = minf(BOSS_BAR_WIDTH, vp.x - LEFT_COLUMN_WIDTH * 2.0)
	width = maxf(width, 160.0)
	var left: float = maxf((vp.x - width) * 0.5, LEFT_COLUMN_WIDTH)
	_boss_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_boss_bar.position = Vector2(left, 16.0)
	_boss_bar.size = Vector2(width, BOSS_BAR_HEIGHT)
	_boss_name_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_boss_name_label.position = Vector2(left, 16.0 + BOSS_BAR_HEIGHT + 4.0)
	_boss_name_label.size = Vector2(width, 40.0)


## ADR-0045 — the Core / sigil chip strip, wired by the game loop.
func get_sigil_strip() -> SigilStrip:
	return _sigil_strip


## Boss bar rect in HUD pixels (test / QA hook).
func get_boss_bar_rect() -> Rect2:
	return Rect2(_boss_bar.position, _boss_bar.size) if _boss_bar != null else Rect2()


## U3 / ADR-0035 — lays out the left card. In combat it holds HP, Special, dash and
## Style; the floor and room line shows only between rooms (the floor intro banner and
## the pause map carry it during a fight), so the corner stays light. Each row is
## placed from its measured height, so the card grows with the Text size setting
## instead of rows overlapping.
func _layout_left_column(combat: bool) -> void:
	_left_combat = combat
	if _left_panel == null:
		return
	var y: float = LEFT_PAD
	var hp_h: float = maxf(HP_BAR_MIN_HEIGHT, hp_label.get_combined_minimum_size().y + 2.0)
	hp_bar.position = Vector2(LEFT_PAD, y)
	hp_bar.size = Vector2(LEFT_INNER_WIDTH, hp_h)
	hp_bar.pivot_offset = hp_bar.size / 2.0
	hp_label.position = Vector2(LEFT_PAD, y)
	hp_label.size = Vector2(LEFT_INNER_WIDTH - 6.0, hp_h)
	y += hp_h + LEFT_ROW_GAP
	_floor_label.visible = not combat
	_room_label.visible = not combat
	if combat:
		var sp_h: float = maxf(SPECIAL_BAR_MIN_HEIGHT, _special_label.get_combined_minimum_size().y)
		_special_bar.position = Vector2(LEFT_PAD, y)
		_special_bar.size = Vector2(LEFT_INNER_WIDTH, sp_h)
		_special_label.position = Vector2(LEFT_PAD + 6.0, y)
		_special_label.size = Vector2(LEFT_INNER_WIDTH - 12.0, sp_h)
		y += sp_h + LEFT_ROW_GAP
		var dash_h: float = maxf(_dash_cooldown_icon.size.y, _dash_hint_label.get_combined_minimum_size().y)
		_dash_cooldown_icon.position = Vector2(LEFT_PAD, y + (dash_h - _dash_cooldown_icon.size.y) * 0.5)
		_dash_hint_label.position = Vector2(LEFT_PAD + _dash_cooldown_icon.size.x + 6.0, y)
		_dash_hint_label.size = Vector2(LEFT_INNER_WIDTH - _dash_cooldown_icon.size.x - 6.0, dash_h)
		y += dash_h + LEFT_ROW_GAP
		var cap_h: float = _style_caption.get_combined_minimum_size().y
		var badge: float = maxf(STYLE_BADGE_SIZE, cap_h + 12.0)
		_style_badge.position = Vector2(LEFT_PAD, y)
		_style_badge.size = Vector2(badge, badge)
		_style_badge.pivot_offset = _style_badge.size * 0.5
		_style_label.size = _style_badge.size
		var right_x: float = LEFT_PAD + badge + 8.0
		_style_caption.position = Vector2(right_x, y)
		_style_bar.position = Vector2(right_x, y + badge - 10.0)
		_style_bar.size = Vector2(LEFT_PAD + LEFT_INNER_WIDTH - right_x, 8.0)
		y += badge + LEFT_PAD
	else:
		var floor_h: float = _floor_label.get_combined_minimum_size().y
		_floor_label.position = Vector2(LEFT_PAD, y - 2.0)
		_floor_label.size = Vector2(LEFT_INNER_WIDTH, floor_h)
		y += floor_h - 2.0
		var room_h: float = _room_label.get_combined_minimum_size().y
		_room_label.position = Vector2(LEFT_PAD, y)
		_room_label.size = Vector2(LEFT_INNER_WIDTH, room_h)
		y += room_h + LEFT_PAD * 0.5
	_left_panel.size = Vector2(LEFT_COLUMN_WIDTH, y)
	var below: float = _left_panel.position.y + y + 8.0
	if _sigil_strip != null:  # ADR-0045 — chips sit between the card and the combo count.
		_sigil_strip.position = Vector2(_left_panel.position.x, below - 2.0)
		if _sigil_strip.chip_count() > 0:
			below += _sigil_strip.strip_height() + 6.0
	_combo_counter_label.position.y = below


## Re-stacks the left card once at the end of the frame (text size changed).
func _queue_left_layout() -> void:
	if _left_layout_queued:
		return
	_left_layout_queued = true
	(func() -> void:
		_left_layout_queued = false
		_layout_left_column(_left_combat)).call_deferred()


## Height of the left card in HUD px (test / QA hook).
func get_left_card_height() -> float:
	return _left_panel.size.y if _left_panel != null else 0.0


## Shows or hides every part of the Style meter together (badge, letter, caption, bar).
func _set_style_visible(on: bool) -> void:
	_style_label.visible = on
	_style_bar.visible = on
	if _style_badge != null:
		_style_badge.visible = on
	if _style_caption != null:
		_style_caption.visible = on


## ADR-0019 — live style meter from PaceDirector.style_changed.
func set_style(value: float, max_value: float, rank_letter: String) -> void:
	if _style_label == null:
		return
	_style_bar.max_value = maxf(max_value, 1.0)
	_style_bar.value = value
	var c: Color = STYLE_RANK_COLORS.get(rank_letter, Color.WHITE)
	_style_bar.modulate = c
	_style_label.text = rank_letter
	_style_label.add_theme_color_override(&"font_color", c)
	if _style_badge != null:
		var sb := _style_badge.get_theme_stylebox(&"panel") as StyleBoxFlat
		if sb != null:
			sb.border_color = c
	if rank_letter != _style_letter:
		_style_letter = rank_letter
		if _style_badge != null and _style_badge.is_inside_tree():
			_style_badge.scale = Vector2(1.3, 1.3)
			create_tween().tween_property(_style_badge, "scale", Vector2.ONE, 0.18)


## ADR-0019 — room-clear rank banner from PaceDirector.room_ranked.
func show_room_rank(rank_letter: String, heal: float, meter_bonus: float) -> void:
	if _rank_banner == null:
		return
	_rank_banner.text = _COPY.room_rank_format % rank_letter
	_rank_reward_label.text = _COPY.room_rank_reward_format % [roundi(heal), roundi(meter_bonus)] \
		if heal > 0.0 or meter_bonus > 0.0 else ""
	# The room is over: the live meter gives way to the room's rank.
	if _style_label != null:
		_set_style_visible(false)
	_rank_banner.add_theme_color_override(&"font_color", STYLE_RANK_COLORS.get(rank_letter, Color.WHITE))
	_rank_banner.visible = true
	if not _rank_banner.is_inside_tree():
		return
	if _rank_tween:
		_rank_tween.kill()
	_rank_banner.modulate = Color(1, 1, 1, 0)
	_rank_tween = create_tween()
	_rank_tween.tween_property(_rank_banner, "modulate:a", 1.0, 0.15)
	_rank_tween.tween_interval(1.4)
	_rank_tween.tween_property(_rank_banner, "modulate:a", 0.0, 0.4)
	_rank_tween.tween_callback(func() -> void: _rank_banner.visible = false)


## ADR-0020 — floor name for [param floor_num] (1-based), or "" past the list.
static func floor_name(floor_num: int) -> String:
	var names: Array[String] = _COPY.floor_names
	return names[floor_num - 1] if floor_num >= 1 and floor_num <= names.size() else ""


## ADR-0020 — HUD floor label text, e.g. "Floor 2 · Functional Corridors".
static func floor_label_text(floor_num: int) -> String:
	var n: String = floor_name(floor_num)
	return _COPY.floor_label_format % [floor_num, n] if n != "" else "Floor %d" % floor_num


## ADR-0020 — big "FLOOR N / name" banner when a floor starts. Fades out by itself.
func show_floor_intro(floor_num: int) -> void:
	if _floor_label != null:
		_floor_label.text = floor_label_text(floor_num)
	if not is_inside_tree():
		return
	if is_instance_valid(_floor_banner):
		_floor_banner.queue_free()
	var banner := Label.new()
	_floor_banner = banner
	banner.text = _COPY.floor_intro_format % [floor_num, floor_name(floor_num)]
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override(&"font_size", 30)
	banner.add_theme_color_override(&"font_color", UIPalette.ACCENT)
	banner.add_theme_color_override(&"font_outline_color", Color.BLACK)
	banner.add_theme_constant_override(&"outline_size", 6)
	banner.anchor_left = 0.0
	banner.anchor_right = 1.0
	banner.anchor_top = 0.16
	banner.anchor_bottom = 0.16
	banner.offset_bottom = 90.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate = Color(1, 1, 1, 0)
	add_child(banner)
	var tw: Tween = banner.create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.8)
	tw.tween_property(banner, "modulate:a", 0.0, 0.6)
	tw.tween_callback(banner.queue_free)


## ADR-0026 — short banner under the floor banner (Challenge / Cursed / results).
## Replaces any banner still showing. Fades out by itself.
func show_room_banner(text: String, color: Color) -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_room_banner):
		_room_banner.queue_free()
	var banner := Label.new()
	_room_banner = banner
	banner.text = text
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override(&"font_size", 22)
	banner.add_theme_color_override(&"font_color", color)
	banner.add_theme_color_override(&"font_outline_color", Color.BLACK)
	banner.add_theme_constant_override(&"outline_size", 5)
	banner.anchor_left = 0.0
	banner.anchor_right = 1.0
	banner.anchor_top = 0.3
	banner.anchor_bottom = 0.3
	banner.offset_bottom = 40.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate = Color(1, 1, 1, 0)
	add_child(banner)
	var tw: Tween = banner.create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.8)
	tw.tween_property(banner, "modulate:a", 0.0, 0.5)
	tw.tween_callback(banner.queue_free)


## ADR-0019 — "PERFECT DODGE" pops above Fayde and floats up.
func show_perfect_dodge(world_pos: Vector2) -> void:
	if not is_inside_tree():
		return
	var label := Label.new()
	label.text = _COPY.perfect_dodge_label
	label.add_theme_font_size_override(&"font_size", 18)
	label.add_theme_color_override(&"font_color", Color(0.7, 0.95, 1.0))
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * world_pos
	label.position = screen_pos + Vector2(-label.get_minimum_size().x * 0.5, -72.0)
	var tw: Tween = label.create_tween()
	tw.set_ignore_time_scale(true)  # reads at full speed through the slow-mo
	tw.tween_property(label, "position:y", label.position.y - 26.0, 0.6)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.25)
	tw.tween_callback(label.queue_free)

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
	# Dark outline keeps numbers legible over any floor/enemy colour.
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override(&"outline_size", 5)
	# Heavy hits punch larger so big damage reads at a glance.
	if damage >= HealthAndDamage.HEAVY_HIT_THRESHOLD:
		label.add_theme_font_size_override(&"font_size", 30)
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
		# U3 — brief flash on the bar so a hit registers where the player's eye goes.
		hp_bar.modulate = HIT_FLASH_COLOR
		_tint_timer = HIT_FLASH_DURATION


## Boss-intro handler: connected to WaveManager.boss_spawned by the game loop.
## Shows the name card + top-centre HP bar and triggers the camera reveal zoom.
func _on_boss_spawned(boss: Node) -> void:
	if not is_instance_valid(boss):
		return
	_boss_ref = boss
	var max_hp: float = float(boss.get_max_hp()) if boss.has_method(&"get_max_hp") else 100.0
	_boss_bar.max_value = max_hp
	_boss_bar.set_thresholds(boss.get_phase_thresholds() if boss.has_method(&"get_phase_thresholds") \
		else PackedFloat32Array())
	_boss_bar.visible = true

	_boss_name_label.text = boss_title(boss)
	_boss_name_label.visible = true
	# ADR-0018 — boss gains pattern layers per HP phase; call each one out.
	if boss.has_signal(&"phase_changed") and not boss.is_connected(&"phase_changed", _on_boss_phase_changed):
		boss.connect(&"phase_changed", _on_boss_phase_changed)

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


## Boss name for the name card, with this run's variant title when it has one
## (ADR-0028): "Vault Sentinel · Overclocked".
func boss_title(boss: Node) -> String:
	var raw_name: String = boss.get_display_name() if boss.has_method(&"get_display_name") else "BOSS"
	var title: String = _humanize_name(raw_name)
	var variant: BossVariant = boss.get_boss_variant() as BossVariant \
		if boss.has_method(&"get_boss_variant") else null
	if variant != null and _COPY.boss_variant_titles.has(String(variant.id)):
		title = _COPY.boss_variant_format % [title, String(_COPY.boss_variant_titles[String(variant.id)]).to_upper()]
	return title


## ADR-0018 — flashes "NAME — PHASE n" when the boss switches on a new pattern layer.
## [param phase] counts HP-gated layers (1 = first phase-up), so it reads as phase n+1.
func _on_boss_phase_changed(phase: int) -> void:
	if not is_instance_valid(_boss_ref) or not is_instance_valid(_boss_name_label):
		return
	_boss_name_label.text = "%s — %s %d" % [boss_title(_boss_ref), _COPY.boss_phase_label, phase + 1]
	_boss_bar.flash_phase()
	if _boss_intro_tween:
		_boss_intro_tween.kill()
	_boss_name_label.modulate = Color(1.6, 0.6, 0.6, 1.0)
	_boss_intro_tween = create_tween()
	_boss_intro_tween.tween_property(_boss_name_label, "modulate", Color(1, 1, 1, 1), 0.5)
	_boss_intro_tween.tween_interval(1.2)
	_boss_intro_tween.tween_property(_boss_name_label, "modulate:a", 0.65, 0.5)


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
			hp_label.add_theme_color_override(&"font_color", HP_COLOR_LABEL_CAREFUL)
			_stop_pulse()
		GameEnums.HPZone.DESPERATE:
			hp_bar.modulate = HP_COLOR_DESPERATE
			hp_label.add_theme_color_override(&"font_color", HP_COLOR_LABEL_DESPERATE)
			_start_pulse()
		_:
			push_warning("CombatHUD: unhandled HPZone value %d — zone color not updated" % zone)


## Handles run_started from GameStateManager.
## Resets all HUD state to match a fresh run: HP to max, no tween, FULL zone colors,
## chain dots hidden, all floating damage labels freed.
func _on_run_started() -> void:
	_dead = false
	_layout_left_column(false)
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
	if is_instance_valid(_recognition_callout_label):
		_recognition_callout_label.visible = false
	if _dash_hint_label != null:
		_dash_hint_label.visible = false
	if _dash_cooldown_icon != null:
		_dash_cooldown_icon.color.a = 1.0
		_dash_cooldown_icon.visible = false
	if _special_bar != null:
		_special_bar.visible = false
		_special_label.visible = false
	if _floor_label != null:
		_floor_label.text = floor_label_text(1)
	_free_all_damage_labels()


## Updates the run-progress breadcrumb ("Room X / Y"). Called by debug_game_loop on
## the initial room and after each room transition. No-op before the HUD is built.
func set_room_progress(current: int, total: int) -> void:
	if _room_label != null:
		_room_label.text = "Room %d / %d" % [current, total]


## Rebuilds the top-right floor minimap from the current graph snapshot. Display-only:
## takes plain arrays so the HUD never holds a reference to game state (ui-code.md).
## [param room_types] / [param room_states] are parallel arrays (one entry per room,
## values from DungeonGraph.ROOM_TYPE_* / ROOM_STATE_*); [param current_idx] is the
## room the player currently occupies. No-op before the HUD is built (headless tests).
## [param modifiers] (optional, parallel to room_types) marks Challenge "!" and Cursed
## "X" rooms with their own letter and border (ADR-0026).
func set_minimap(room_types: Array, room_states: Array, current_idx: int,
		modifiers: Array = [], edges: Array = [], entry_idx: int = -1) -> void:
	if _minimap_root == null:
		return
	for m: Panel in _minimap_markers:
		if is_instance_valid(m):
			m.queue_free()
	_minimap_markers.clear()

	var count: int = room_types.size()
	if count == 0:
		return

	# U4 — with the floor's edges, draw a node map that shows the branches.
	if not edges.is_empty():
		_show_floor_map(room_types, room_states, modifiers, edges, current_idx, entry_idx)
		return
	if _floor_map != null:
		_floor_map.visible = false

	for i: int in range(count):
		var rtype: int = int(room_types[i])
		var rstate: int = int(room_states[i]) if i < room_states.size() else 0
		var is_current: bool = (i == current_idx)
		var base_col: Color = _MINIMAP_TYPE_COLORS[rtype] if rtype >= 0 and rtype < _MINIMAP_TYPE_COLORS.size() else Color.GRAY

		var marker := Panel.new()
		marker.custom_minimum_size = Vector2(_MINIMAP_MARKER_SIZE, _MINIMAP_MARKER_SIZE)
		marker.size = Vector2(_MINIMAP_MARKER_SIZE, _MINIMAP_MARKER_SIZE)
		marker.position = Vector2(i * (_MINIMAP_MARKER_SIZE + _MINIMAP_MARKER_SEP), 0.0)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		# Cleared/current rooms read at full strength; unvisited rooms are dimmed.
		var visited: bool = rstate != 0 or is_current  # 0 == UNVISITED
		var fill: Color = base_col
		fill.a = 1.0 if visited else 0.35
		style.bg_color = fill
		if is_current:
			# Gold ring marks "you are here".
			style.border_color = UIPalette.ACCENT
			style.set_border_width_all(3)
		var mod: int = int(modifiers[i]) if i < modifiers.size() else RoomModifiers.NONE
		if mod != RoomModifiers.NONE and not is_current:
			style.border_color = _MINIMAP_MOD_COLORS[mod]
			style.set_border_width_all(2)
		marker.add_theme_stylebox_override(&"panel", style)

		# Type letter — redundant non-colour cue so room types are distinguishable
		# without relying on hue alone (colorblind accessibility).
		var glyph := Label.new()
		glyph.text = _MINIMAP_TYPE_LETTERS[rtype] if rtype >= 0 and rtype < _MINIMAP_TYPE_LETTERS.size() else "?"
		if mod != RoomModifiers.NONE:
			glyph.text = _MINIMAP_MOD_LETTERS[mod]
		glyph.add_theme_font_size_override(&"font_size", 12)
		glyph.add_theme_color_override(&"font_color", Color(0.06, 0.05, 0.08, 1.0))
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.modulate.a = 1.0 if visited else 0.6
		marker.add_child(glyph)

		_minimap_root.add_child(marker)
		_minimap_markers.append(marker)

	# Pin the strip to the top-right of the viewport.
	var total_w: float = count * _MINIMAP_MARKER_SIZE + maxf(0.0, count - 1) * _MINIMAP_MARKER_SEP
	var vp_w: float = get_viewport_rect().size.x
	_minimap_root.position = Vector2(vp_w - total_w - _MINIMAP_MARGIN, _MINIMAP_MARGIN)


## U4 — draws the floor as a node map (FloorMap) pinned top-right.
func _show_floor_map(types: Array, states: Array, mods: Array, edges: Array,
		current_idx: int, entry_idx: int) -> void:
	if _floor_map == null:
		_floor_map = FloorMap.new()
		_floor_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_floor_map.type_colors.assign(_MINIMAP_TYPE_COLORS)
		_floor_map.type_letters.assign(_MINIMAP_TYPE_LETTERS)
		_floor_map.mod_letters.assign(_MINIMAP_MOD_LETTERS)
		_floor_map.mod_colors.assign(_MINIMAP_MOD_COLORS)
		_minimap_root.add_child(_floor_map)
	_floor_map.visible = true
	_floor_map.set_floor(types, states, mods, edges, current_idx, entry_idx)
	var vp_w: float = get_viewport_rect().size.x
	_minimap_root.position = Vector2(vp_w - _floor_map.size.x - _MINIMAP_MARGIN * 0.5, _MINIMAP_MARGIN * 0.5)


## The floor map's current contents (FloorMap.snapshot()), or {} when none is shown.
## The pause screen draws a larger copy with a legend (ADR-0032).
func get_floor_map_data() -> Dictionary:
	if _floor_map == null or not _floor_map.visible:
		return {}
	return _floor_map.snapshot()


## Bottom edge of the top-right floor map in HUD px (0 when none is shown), so panels
## on the right (the prep panel) can sit below it.
func get_floor_map_bottom() -> float:
	if _floor_map == null or not _floor_map.visible:
		return 0.0
	return _minimap_root.position.y + _floor_map.size.y


## Handles preparation_started from GameStateManager.
## Hides the chain-dot container between waves; updates floor number label.
func _on_preparation_started(_idx: int, _rem: int) -> void:
	_hide_boss_ui()
	_layout_left_column(false)
	for tw in _dot_tweens:
		if is_instance_valid(tw):
			tw.kill()
	_dot_tweens.clear()
	chain_dots_container.visible = false
	_current_primary_type = -1
	if is_instance_valid(_combo_counter_label):
		_combo_counter_label.visible = false
		_dash_hint_label.visible = false
	if is_instance_valid(_recognition_callout_label):
		_recognition_callout_label.visible = false
	if _dash_cooldown_icon != null:
		_dash_cooldown_icon.color.a = 1.0
		_dash_cooldown_icon.visible = false
	if _special_bar != null:
		_special_bar.visible = false
		_special_label.visible = false
	if _style_label != null:
		_set_style_visible(false)
	if _floor_label != null:
		var floor_num: int = RunManager.get_run_data().get("current_floor", 1)
		_floor_label.text = floor_label_text(floor_num)


## Handles combat_started from GameStateManager.
func _on_combat_started(_is_boss: bool = false) -> void:
	_layout_left_column(true)
	if _dash_hint_label != null:
		_dash_hint_label.visible = true
	if _dash_cooldown_icon != null:
		_dash_cooldown_icon.visible = true
	if _special_bar != null:
		_special_bar.visible = true
		_special_label.visible = true
	if _style_label != null:
		_set_style_visible(true)
	# Show the chain dots immediately so the cast-flash is visible on the first cast.
	# _rebuild_dots with 1 gray dot = "ready to cast" baseline indicator.
	if chain_dots_container.get_child_count() == 0:
		_rebuild_dots(0, 1)
	chain_dots_container.visible = true


## Rebuilds device-dependent prompts when the player switches keyboard ↔ pad (U8).
func _on_device_changed(_using_pad: bool) -> void:
	if _dash_hint_label != null:
		_dash_hint_label.text = InputPrompts.dash_hint()
	if _special_label != null and _special_ready:
		_special_label.text = InputPrompts.special_ready()


## Handles special_meter_changed from SpellCastingEffects: fills the bar, and when full
## tints it in the core Prana colour and swaps the label to the ready prompt.
func _on_special_meter_changed(value: float, max_value: float) -> void:
	if _special_bar == null:
		return
	_special_bar.max_value = max_value
	_special_bar.value = value
	var is_full: bool = max_value > 0.0 and value >= max_value
	_special_ready = is_full
	_special_label.text = InputPrompts.special_ready() if is_full else _COPY.special_label
	var tint: Color = Color(0.75, 0.75, 0.75)
	if is_full:
		tint = Color.WHITE
		if _current_primary_type >= 0:
			var prana_type := PranaCatalog.get_type(_current_primary_type)
			if prana_type != null:
				tint = prana_type.color
	_special_bar.modulate = tint


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


## Caches the primary Prana type from a resolved spell for chain dot colouring,
## then surfaces the wave's Cascade / Reaction callout (ADR-0016 recognition layer).
func _on_combo_resolved(spell_effect: SpellEffect) -> void:
	_current_primary_type = spell_effect.primary_type
	_show_recognition_callout(spell_effect)


## Announces this wave's recognition result (ADR-0016) via a centred pop-in banner.
## Priority: a fired Cascade (coloured by its lead Prana type, showing the burst
## multiplier) outranks armed Reactions. A reaction-only result shows the first
## reaction's name with a "+N" suffix when more are armed. Does nothing when neither
## fired, so plain single-type casts stay silent.
func _show_recognition_callout(spell_effect: SpellEffect) -> void:
	if not is_instance_valid(_recognition_callout_label):
		return
	var text: String = ""
	var color: Color = Color("#FFD66B")  # warm gold — default for Reactions
	var cascade: CascadeEffect = spell_effect.active_cascade
	if cascade != null:
		text = "✦ %s ×%.1f" % [_COPY.cascade_label, cascade.cascade_mult]
		var lead: PranaType = PranaCatalog.get_type(cascade.lead_type)
		if lead != null:
			color = lead.color
	elif not spell_effect.active_reactions.is_empty():
		var first: ReactionDef = spell_effect.active_reactions[0]
		text = "⚡ %s" % first.name
		var extra: int = spell_effect.active_reactions.size() - 1
		if extra > 0:
			text += "  +%d" % extra
	else:
		return
	_recognition_callout_label.text = text
	_recognition_callout_label.add_theme_color_override(&"font_color", color)
	_recognition_callout_label.pivot_offset = _recognition_callout_label.size * 0.5
	_recognition_callout_label.visible = true
	_recognition_callout_label.scale = Vector2(0.7, 0.7)
	_recognition_callout_label.modulate.a = 1.0
	if _recognition_callout_tween:
		_recognition_callout_tween.kill()
	_recognition_callout_tween = create_tween()
	_recognition_callout_tween.tween_property(_recognition_callout_label, "scale", Vector2(1.15, 1.15), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_recognition_callout_tween.tween_property(_recognition_callout_label, "scale", Vector2(1.0, 1.0), 0.12)
	_recognition_callout_tween.tween_interval(0.9)
	_recognition_callout_tween.tween_property(_recognition_callout_label, "modulate:a", 0.0, 0.25)


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
