## iso_character.gd — Isometric character sprite component (16 compass directions).
##
## Manages an AnimatedSprite2D that auto-selects the correct direction frame
## based on a Vector2 facing direction. Built for the "Lords Of Pain" demo
## asset pack convention: {base_path}/{anim_folder}/{DIR}/{prefix}_{DIR}_{angle}_{frame}.png
##
## Usage:
##   var sprite := IsoCharacter.new()
##   sprite.base_path = "res://assets/art/characters/warrior/"
##   sprite.configure({
##       "idle": "warrior_armed_idle",
##       "walk": "warrior_armed_walk",
##   })
##   add_child(sprite)
##   sprite.play_anim("idle")
##   sprite.set_facing(Vector2(1, 0))   # face right
##
## Origin (0,0) = feet / ground-contact point. The AnimatedSprite2D is offset
## so the character's feet align with the parent node's position.
class_name IsoCharacter
extends Node2D

# ── Constants ─────────────────────────────────────────────────────────────────

## 8 compass directions in counter-clockwise order starting from E (0°).
## Lords Of Pain convention: E=screen-up, S=screen-right, W=screen-down, N=screen-left
## (see set_facing for the -PI/2 offset that compensates for this).
const DIR_KEYS: Array[String] = [
	"E", "NE", "N", "NW", "W", "SW", "S", "SE",
]

const DIR_STEP: float = TAU / 8.0  # 45°

## Default animation speed (frames per second) for sprite cycles.
const DEFAULT_FPS: float = 8.0

# ── Exports ──────────────────────────────────────────────────────────────────

## Base path to the character folder containing animation subdirectories.
@export var base_path: String = ""

## Scale factor applied to the AnimatedSprite2D. Tune for arena size match.
## Lords Of Pain sprites: visible art ~60px within 256×256 canvas. Scale 1.0 gives
## ~60px character = 1× tile width (64px), correct isometric proportion at 2× zoom.
@export var sprite_scale: Vector2 = Vector2(1.5, 1.5)

## Vertical offset in pixels to align feet with the node origin.
## Positive = move sprite up, negative = move sprite down.
## Tune so character feet touch the ground shadow.
@export var foot_offset: float = 0.0

# ── Private state ────────────────────────────────────────────────────────────

var _anim_folders: Dictionary = {}   # anim_name → folder_name
var _current_anim: String = ""
var _current_dir: String = "E"
var _sprite: AnimatedSprite2D = null
var _initialized: bool = false

# ── Built-in ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	if _sprite == null:
		_create_sprite()
	if not base_path.is_empty() and not _anim_folders.is_empty():
		_build_all_frames()
		_initialized = true
	_apply_offset()


func _apply_offset() -> void:
	if _sprite != null:
		_sprite.scale = sprite_scale
		_sprite.offset = Vector2(0, foot_offset)


func _process(_delta: float) -> void:
	# Sync z_index for isometric draw order — same pattern as PlayerController.
	# Higher Y = closer to viewer, draw on top (ADR-0001).
	z_index = clamp(int(global_position.y) + 500, 1, 2000)

# ── Public API ───────────────────────────────────────────────────────────────

## Configures the animation mapping for this character.
## [param anim_map] maps logical names ("idle", "walk") to asset folder names
##   ("warrior_armed_idle", "warrior_armed_walk").
func configure(anim_map: Dictionary) -> void:
	_anim_folders = anim_map
	if base_path and not is_node_ready():
		return  # defer to _ready()
	if base_path and is_node_ready():
		_build_all_frames()
		_initialized = true


## Sets the character facing direction from a movement vector.
## Snaps to the nearest 8-point compass direction.
func set_facing(direction: Vector2) -> void:
	if direction.length_squared() < 0.0001:
		return
	# Convert Godot Y-down atan2 to compass angle, then offset -90° to match
	# the Lords Of Pain sprite convention: E=screen-up, S=screen-right,
	# W=screen-down, N=screen-left (90° CCW from standard compass in screen space).
	var angle: float = fposmod(atan2(-direction.y, direction.x) - PI / 2.0, TAU)
	var idx: int = roundi(angle / DIR_STEP) % DIR_KEYS.size()
	var new_dir: String = DIR_KEYS[idx]
	if new_dir != _current_dir:
		_current_dir = new_dir
		_apply_animation()


## Plays the named animation with the current facing direction.
## [param anim_name] is the logical name registered via configure().
func play_anim(anim_name: String) -> void:
	if anim_name == _current_anim:
		return
	_current_anim = anim_name
	_apply_animation()


## Returns the current animated sprite (for modulate, material, etc.).
func get_sprite() -> AnimatedSprite2D:
	return _sprite


## Returns true if this IsoCharacter has the given logical animation name
## in its current direction.
func has_anim(anim_name: String) -> bool:
	if _sprite == null or _sprite.sprite_frames == null:
		return false
	var full: String = anim_name + "_" + _current_dir
	return _sprite.sprite_frames.has_animation(full)


## Placeholder colour for DebugCircle fallback rendering.
## Set to Color.TRANSPARENT when IsoCharacter is the primary visual.
func _draw() -> void:
	pass  # No procedural drawing — AnimatedSprite2D handles all visuals.

# ── Private ──────────────────────────────────────────────────────────────────

func _create_sprite() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "IsoSprite"
	# Lords Of Pain sprites: 256×256 canvas, but visible art is only ~60px wide (25% of canvas).
	# centered=true places canvas center (128,128) at node origin. Feet sit ~7px below origin.
	# Use foot_offset to fine-tune ground alignment. sprite_scale 1.0 gives ~1× tile width.
	_sprite.centered = true
	_sprite.offset = Vector2.ZERO
	_sprite.scale = sprite_scale
	add_child(_sprite)


## Scans animation folders and constructs SpriteFrames for all anims × directions.
func _build_all_frames() -> void:
	var frames := SpriteFrames.new()
	for anim_name: String in _anim_folders:
		var folder_name: String = _anim_folders[anim_name]
		for dir_key: String in DIR_KEYS:
			var dir_path: String = base_path + folder_name + "/" + dir_key + "/"
			if not DirAccess.dir_exists_absolute(dir_path):
				continue
			var png_files: Array[String] = _scan_png_files(dir_path)
			if png_files.is_empty():
				continue
			png_files.sort()
			var full_anim: String = anim_name + "_" + dir_key
			frames.add_animation(full_anim)
			frames.set_animation_speed(full_anim, DEFAULT_FPS)
			frames.set_animation_loop(full_anim, true)
			for fname: String in png_files:
				var tex: Texture2D = load(dir_path + fname) as Texture2D
				if tex != null:
					frames.add_frame(full_anim, tex)
	_sprite.sprite_frames = frames


## Returns sorted .png filenames from a directory path.
## Uses DirAccess for runtime compatibility (works in editor and exported builds).
func _scan_png_files(dir_path: String) -> Array[String]:
	var files: Array[String] = []
	var da := DirAccess.open(dir_path)
	if da == null:
		return files
	da.list_dir_begin()
	var fname: String = da.get_next()
	while not fname.is_empty():
		if not da.current_is_dir() and fname.ends_with(".png"):
			files.append(fname)
		fname = da.get_next()
	da.list_dir_end()
	return files


## Applies the current animation + direction to the AnimatedSprite2D.
func _apply_animation() -> void:
	if _sprite == null or _current_anim.is_empty() or _current_dir.is_empty():
		return
	var full_name: String = _current_anim + "_" + _current_dir
	var sf: SpriteFrames = _sprite.sprite_frames
	if sf != null and sf.has_animation(full_name):
		_sprite.play(full_name)
