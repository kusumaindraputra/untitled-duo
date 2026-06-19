## RoomExitDoor — exit trigger placed in dungeon rooms (LD-20).
##
## Area2D that detects when Fayde enters, then signals RoomTransitionManager
## to begin a room transition. Locked until the room is cleared (all enemies defeated).
##
## Visual: _DoorBeacon inner class draws a procedural indicator.
##   Locked  — dim cool-gray ring + slow-pulse chevron.
##   Unlocked — dual expanding gold rings + bouncing gold chevron.
## Colors match wave-clear gold wash (debug_game_loop._on_wave_ended, Art Bible §2.4).
##
## Each door carries its destination_room_idx (set by RoomTransitionManager._wire_exit_doors())
## and the destination room type (for display). Multiple doors exist at branch points.
##
## Usage:
##   # Set by RoomTransitionManager after scene load:
##   door.destination_idx = 3
##   door.set_destination_type(DungeonGraph.ROOM_TYPE_ELITE)
##
## GDD:  design/room-connection-model.md (LD-09 § Door UX)
## Roadmap: design/level-design-roadmap.md (LD-20)
class_name RoomExitDoor
extends Area2D

## Must match PlayerController.COLLISION_LAYER_PLAYER — no global constant exists yet.
const _PLAYER_LAYER: int = 2

## Emitted when an unlocked door is entered by the player.
signal player_entered(destination_idx: int)

## Room index in DungeonGraph this door leads to. Set by RoomTransitionManager.
var destination_idx: int = -1

## Room type of the destination (Combat/Elite/Rest/Boss). Drives visual label.
var destination_type: int = DungeonGraph.ROOM_TYPE_COMBAT

## True until room_cleared signal is received.
var _locked: bool = true

var _label: Label = null
var _beacon: _DoorBeacon = null


func _ready() -> void:
	collision_mask = _PLAYER_LAYER  # detect CharacterBody2D on player physics layer
	body_entered.connect(_on_body_entered)
	monitoring = false   # locked at spawn — wait for room_cleared

	_beacon = _DoorBeacon.new()
	_beacon.position = Vector2(0.0, -18.0)
	add_child(_beacon)

	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", 13)
	_label.position = Vector2(-50.0, -68.0)
	_label.size = Vector2(100.0, 18.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.modulate = Color(0.95, 0.95, 1.0, 0.85)
	add_child(_label)

	if GameStateManager != null:
		GameStateManager.room_cleared.connect(_on_room_cleared)
	_update_label()


func _exit_tree() -> void:
	if GameStateManager != null \
			and GameStateManager.room_cleared.is_connected(_on_room_cleared):
		GameStateManager.room_cleared.disconnect(_on_room_cleared)


# ── Public API ─────────────────────────────────────────────────────────────────

## Sets the destination room type and updates the door label.
func set_destination_type(type: int) -> void:
	destination_type = type
	_update_label()


# ── Private ────────────────────────────────────────────────────────────────────

func _on_room_cleared() -> void:
	_locked = false
	monitoring = true
	if is_instance_valid(_beacon):
		_beacon.unlocked = true
	_update_label()


func _on_body_entered(body: Node2D) -> void:
	if _locked or destination_idx < 0:
		return
	if body.is_in_group(&"player"):
		player_entered.emit(destination_idx)


func _update_label() -> void:
	if _label == null:
		return
	var type_names: Array[String] = ["⚔ Combat", "💀 Elite", "♥ Rest", "👑 Boss"]
	var suffix: String = " [LOCKED]" if _locked else " ▼"
	var base: String = type_names[destination_type] if destination_type < type_names.size() else "Exit"
	_label.text = base + suffix
	_label.modulate.a = 0.5 if _locked else 0.92


# ── _DoorBeacon ────────────────────────────────────────────────────────────────

## Procedural exit-door indicator.
##
## Locked  — dim cool-gray slow-pulse ring + static downward chevron.
##           Always visible so the player knows exit location before clearing.
## Unlocked — dual expanding gold rings (staggered 0.5-cycle offset) +
##           gold chevron bouncing downward at 1.4 Hz.
##           Intentionally eye-catching — mirrors Hades archway-open effect.
##
## Sizes respect the 30 px minimum for procedural _draw() shapes (VFX rule).
class _DoorBeacon extends Node2D:
	var unlocked: bool = false

	var _t: float = 0.0

	## Matches debug_game_loop._on_wave_ended gold wash (Art Bible §2.4).
	const GOLD: Color        = Color(1.0,  0.85, 0.4,  1.0)
	const LOCKED_GRAY: Color = Color(0.55, 0.58, 0.72, 1.0)

	const RING_R_MIN: float  = 34.0
	const RING_R_MAX: float  = 56.0
	const RING_CYCLE: float  = 0.85   # seconds per ring expansion
	const RING_WIDTH: float  = 2.5

	const CHEVRON_HALF: float = 24.0  # half-width of the V shape
	const CHEVRON_DEPTH: float = 14.0 # vertical extent
	const CHEVRON_W: float    = 3.5
	const BOUNCE_AMP: float   = 6.0
	const BOUNCE_HZ: float    = 1.4


	func _ready() -> void:
		z_index = 8


	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()


	func _draw() -> void:
		if unlocked:
			_draw_unlocked()
		else:
			_draw_locked()


	## Dim gray static ring + slow-pulsing downward chevron.
	func _draw_locked() -> void:
		var alpha: float = 0.28 + 0.12 * sin(_t * TAU * 0.45)
		var c: Color = Color(LOCKED_GRAY.r, LOCKED_GRAY.g, LOCKED_GRAY.b, alpha)
		draw_arc(Vector2.ZERO, RING_R_MIN, 0.0, TAU, 32, c, RING_WIDTH, true)
		_draw_chevron(Vector2.ZERO, c, CHEVRON_HALF * 0.8, CHEVRON_DEPTH * 0.8, CHEVRON_W * 0.9)


	## Dual expanding gold rings + bouncing gold chevron.
	func _draw_unlocked() -> void:
		# Ring A — full cycle
		_draw_ring(_t)
		# Ring B — half-cycle offset so one ring is always mid-expansion
		_draw_ring(_t + RING_CYCLE * 0.5)

		# Small inner glow disk at center
		var glow_a: float = 0.18 + 0.10 * sin(_t * TAU * 2.0)
		draw_circle(Vector2.ZERO, 12.0, Color(GOLD.r, GOLD.g, GOLD.b, glow_a))

		# Bouncing chevron — sine offset downward so it nudges toward the door
		var bounce_y: float = BOUNCE_AMP * sin(_t * TAU * BOUNCE_HZ)
		var chevron_a: float = 0.75 + 0.25 * sin(_t * TAU * BOUNCE_HZ)
		var c: Color = Color(GOLD.r, GOLD.g, GOLD.b, chevron_a)
		_draw_chevron(Vector2(0.0, bounce_y), c, CHEVRON_HALF, CHEVRON_DEPTH, CHEVRON_W)


	## One expanding-ring pulse: radius RING_R_MIN→RING_R_MAX, fades as it grows.
	## [param time_offset] drives the phase; wraps every RING_CYCLE seconds.
	func _draw_ring(time_offset: float) -> void:
		var p: float = fmod(time_offset, RING_CYCLE) / RING_CYCLE  # 0.0 → 1.0
		var r: float = lerpf(RING_R_MIN, RING_R_MAX, p)
		var a: float = (1.0 - p) * 0.85
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 36,
				Color(GOLD.r, GOLD.g, GOLD.b, a), RING_WIDTH, true)


	## Downward-pointing V chevron (∨) centered at [param pos].
	func _draw_chevron(pos: Vector2, c: Color,
			half: float, depth: float, width: float) -> void:
		draw_line(pos + Vector2(-half, -depth * 0.5),
				  pos + Vector2(0.0,   depth * 0.5), c, width, true)
		draw_line(pos + Vector2(0.0,   depth * 0.5),
				  pos + Vector2(half,  -depth * 0.5), c, width, true)
