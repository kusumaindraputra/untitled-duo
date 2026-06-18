## knight_character.gd — Knight sprite component using sprite-sheet atlas convention.
##
## Drop-in replacement for IsoCharacter. Same public API (configure, play_anim,
## set_facing, get_sprite, has_anim) but loads from sprite sheets instead of
## individual per-frame PNGs.
##
## Asset convention: {base_path}/{subfolder}/Knight_{AnimLabel}_dir{1-8}.png
##   paired with matching .json files (PixelOver format).
##
## Direction mapping (same angle math as iso_character.gd, -PI/2 offset):
##   dir1=E(screen-up), dir2=NE, dir3=N, dir4=NW,
##   dir5=W, dir6=SW, dir7=S, dir8=SE
##   Adjust DIR_OFFSET constant if dir1 maps to a different facing in your pack.
class_name KnightCharacter
extends Node2D

# ── Constants ─────────────────────────────────────────────────────────────────

const DIR_COUNT: int = 8
const DIR_STEP: float = TAU / float(DIR_COUNT)
const DEFAULT_FPS: float = 8.0

## Rotate the dir→angle mapping if dir1 is not the E/screen-up facing.
## 0 = no offset (dir1 ≡ E). Increase by 1 per 45° CW shift of dir1.
const DIR_OFFSET: int = 0

# ── Exports ───────────────────────────────────────────────────────────────────

## Root folder containing animation sub-packs (KnightBasic, KnightAdvCombat, …).
@export var base_path: String = ""

## Scale applied to the sprite. 1.5 gives Hades-like proportions for 256px canvas.
@export var sprite_scale: Vector2 = Vector2(1.5, 1.5)

## Positive = move sprite up to align feet with node origin.
@export var foot_offset: float = 0.0

# ── Private state ─────────────────────────────────────────────────────────────

var _anim_map: Dictionary = {}    # logical_name → "SubPack/AnimLabel"
var _current_anim: String = ""
var _current_dir: int = 1         # 1–8
var _sprite: AnimatedSprite2D = null
var _initialized: bool = false

# ── Built-in ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	if _sprite == null:
		_create_sprite()
	if not base_path.is_empty() and not _anim_map.is_empty():
		_build_all_frames()
		_initialized = true
	_apply_offset()


func _apply_offset() -> void:
	if _sprite != null:
		_sprite.scale = sprite_scale
		_sprite.offset = Vector2(0, foot_offset)


func _process(_delta: float) -> void:
	z_index = clamp(int(global_position.y) + 500, 1, 2000)

# ── Public API (matches IsoCharacter) ─────────────────────────────────────────

## Maps logical animation names to asset sub-paths.
## [param anim_map] maps "idle" → "KnightBasic/Idle", "walk" → "KnightBasic/Walk", etc.
func configure(anim_map: Dictionary) -> void:
	_anim_map = anim_map
	if base_path.is_empty() or not is_node_ready():
		return
	_build_all_frames()
	_initialized = true


## Updates facing direction from a movement vector (same math as IsoCharacter).
func set_facing(direction: Vector2) -> void:
	if direction.length_squared() < 0.0001:
		return
	var angle: float = fposmod(atan2(-direction.y, direction.x) - PI / 2.0, TAU)
	var idx: int = (roundi(angle / DIR_STEP) + DIR_OFFSET) % DIR_COUNT
	var new_dir: int = idx + 1  # 1-based
	if new_dir != _current_dir:
		_current_dir = new_dir
		_apply_animation()


## Plays a logical animation name with the current facing direction.
func play_anim(anim_name: String) -> void:
	if anim_name == _current_anim:
		return
	_current_anim = anim_name
	_apply_animation()


## Returns the AnimatedSprite2D for modulate, material, etc.
func get_sprite() -> AnimatedSprite2D:
	return _sprite


## Returns true if the logical animation exists for the current direction.
func has_anim(anim_name: String) -> bool:
	if _sprite == null or _sprite.sprite_frames == null:
		return false
	return _sprite.sprite_frames.has_animation(_full_anim_name(anim_name, _current_dir))


func _draw() -> void:
	pass

# ── Private ───────────────────────────────────────────────────────────────────

func _create_sprite() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "KnightSprite"
	_sprite.centered = true
	_sprite.offset = Vector2.ZERO
	_sprite.scale = sprite_scale
	add_child(_sprite)


## Builds SpriteFrames for every configured animation × 8 directions from sheet data.
func _build_all_frames() -> void:
	var frames := SpriteFrames.new()
	for logical_name: String in _anim_map:
		var sub_path: String = _anim_map[logical_name]          # e.g. "KnightBasic/Idle"
		var anim_label: String = sub_path.get_file()             # e.g. "Idle"
		for dir_num: int in range(1, DIR_COUNT + 1):
			var stem: String = "Knight_" + anim_label + "_dir" + str(dir_num)
			var png_path: String = base_path + sub_path + "/" + stem + ".png"
			var json_path: String = base_path + sub_path + "/" + stem + ".json"
			if not FileAccess.file_exists(png_path):
				push_warning("KnightCharacter: missing sheet %s" % png_path)
				continue
			var sheet: Texture2D = load(png_path) as Texture2D
			if sheet == null:
				continue
			var frame_rects: Array[Rect2] = _parse_frame_rects(json_path)
			if frame_rects.is_empty():
				continue
			var fps: float = _parse_fps(json_path, anim_label)
			var full_name: String = _full_anim_name(logical_name, dir_num)
			frames.add_animation(full_name)
			frames.set_animation_speed(full_name, fps)
			frames.set_animation_loop(full_name, true)
			for rect: Rect2 in frame_rects:
				var atlas := AtlasTexture.new()
				atlas.atlas = sheet
				atlas.region = rect
				frames.add_frame(full_name, atlas)
	_sprite.sprite_frames = frames
	if not _current_anim.is_empty():
		_apply_animation()


## Parses frame regions from a PixelOver JSON file.
func _parse_frame_rects(json_path: String) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if not FileAccess.file_exists(json_path):
		return result
	var text: String = FileAccess.get_file_as_string(json_path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return result
	for frame: Variant in (parsed as Dictionary).get("frames", []):
		if not frame is Dictionary:
			continue
		var f: Variant = (frame as Dictionary).get("frame", null)
		if not f is Dictionary:
			continue
		result.append(Rect2(f["x"], f["y"], f["w"], f["h"]))
	return result


## Reads animation FPS from the PixelOver JSON frameAnimations block.
func _parse_fps(json_path: String, anim_label: String) -> float:
	if not FileAccess.file_exists(json_path):
		return DEFAULT_FPS
	var text: String = FileAccess.get_file_as_string(json_path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return DEFAULT_FPS
	var meta: Variant = (parsed as Dictionary).get("meta", null)
	if not meta is Dictionary:
		return DEFAULT_FPS
	for fa: Variant in (meta as Dictionary).get("frameAnimations", []):
		if fa is Dictionary and (fa as Dictionary).get("name", "") == anim_label:
			return float((fa as Dictionary).get("fps", DEFAULT_FPS))
	return DEFAULT_FPS


func _full_anim_name(logical_name: String, dir_num: int) -> String:
	return logical_name + "_dir" + str(dir_num)


## Switches the sprite to the current animation + direction.
func _apply_animation() -> void:
	if _sprite == null or _current_anim.is_empty():
		return
	var full_name: String = _full_anim_name(_current_anim, _current_dir)
	var sf: SpriteFrames = _sprite.sprite_frames
	if sf != null and sf.has_animation(full_name):
		_sprite.play(full_name)
