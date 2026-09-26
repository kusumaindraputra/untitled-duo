## GameSettings — display, comfort and control options (ADR-0026).
##
## Stored in user://settings.cfg next to the audio volumes (AudioSystem owns the
## "audio" section; this class owns "game" and "keys" and keeps the others intact).
##   display  — fullscreen, window size, vsync
##   comfort  — screen shake strength (0–100 %), reduced screen flashes
##   controls — keyboard key per remappable action
##
## Plain RefCounted like MetaProgress. `current` is the loaded instance the game
## reads through the static helpers (shake_multiplier, flash_multiplier); tests pass
## their own path and assign `current` themselves.
class_name GameSettings
extends RefCounted

const DEFAULT_PATH: String = "user://settings.cfg"
const _SECTION: String = "game"
const _KEYS_SECTION: String = "keys"

## Window sizes offered in windowed mode (16:9; the game renders at 1152×648 and
## scales, so every size shows the same view).
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080),
]
## Actions the player can rebind on the keyboard, in menu order.
const REMAPPABLE: Array[StringName] = [
	&"move_up", &"move_down", &"move_left", &"move_right", &"dash", &"cast", &"special",
]
## Default keyboard keys for remappable actions the run scene registers itself
## (cast / special come from SpellCastingEffects). Lets the main menu's Settings show
## and rebind them before a run has started.
const DEFAULT_KEYS: Dictionary[StringName, Key] = {
	&"move_up": KEY_W, &"move_down": KEY_S, &"move_left": KEY_A, &"move_right": KEY_D,
	&"dash": KEY_SHIFT,
}
## Screen flash strength when reduce_flashes is on.
const REDUCED_FLASH_SCALE: float = 0.3

## The settings in effect. Loaded on first use of active().
static var current: GameSettings = null
static var _display_applied: bool = false
## Keyboard key of each remappable action before any override, captured once.
static var _default_keys: Dictionary[StringName, int] = {}

var fullscreen: bool = false
var resolution_idx: int = 0
var vsync: bool = true
## Screen shake strength, 0.0 (off) to 1.0 (full).
var screen_shake: float = 1.0
var reduce_flashes: bool = false
## Skips screen fades and typewriter text and stills menu motion (U9).
var reduce_motion: bool = false
## Action → keycode for rebound actions only; unbound actions keep their defaults.
var key_overrides: Dictionary[StringName, int] = {}


## The settings in effect, loading them from disk the first time.
static func active() -> GameSettings:
	if current == null:
		current = load_from()
	return current


## Multiplier for camera shake / trauma (1.0 when no settings are loaded).
static func shake_multiplier() -> float:
	return clampf(current.screen_shake, 0.0, 1.0) if current != null else 1.0


## True when menus and screens should skip fades, typewriter text and idle motion.
static func motion_reduced() -> bool:
	return current != null and current.reduce_motion


## Multiplier for full-screen flash opacity (1.0, or REDUCED_FLASH_SCALE).
static func flash_multiplier() -> float:
	return REDUCED_FLASH_SCALE if current != null and current.reduce_flashes else 1.0


# ── Display ───────────────────────────────────────────────────────────────────

## The windowed size for the current resolution_idx (clamped to RESOLUTIONS).
func window_size() -> Vector2i:
	return RESOLUTIONS[clampi(resolution_idx, 0, RESOLUTIONS.size() - 1)]


## Applies window mode, size and vsync. Skipped when running headless.
func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var size: Vector2i = window_size()
	var screen: Rect2i = DisplayServer.screen_get_usable_rect()
	if screen.size.x > 0 and (size.x > screen.size.x or size.y > screen.size.y):
		return  # leave the window alone rather than open it off-screen
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)


## Applies the display settings once per launch (scene reloads do not re-apply).
func apply_display_once() -> void:
	if _display_applied:
		return
	_display_applied = true
	apply_display()


# ── Controls ──────────────────────────────────────────────────────────────────

## Rebinds [param action]'s keyboard key to [param keycode] in the InputMap, keeping
## its gamepad and mouse events. Records the override. Returns false for an action
## that is not remappable or does not exist.
func rebind(action: StringName, keycode: Key) -> bool:
	if not REMAPPABLE.has(action) or not InputMap.has_action(action) or keycode == KEY_NONE:
		return false
	capture_default_keys()
	key_overrides[action] = keycode
	set_action_key(action, keycode)
	return true


## Creates any missing remappable action with its DEFAULT_KEYS key. Existing
## actions are left untouched.
static func ensure_actions() -> void:
	for action: StringName in DEFAULT_KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		var k := InputEventKey.new()
		k.keycode = DEFAULT_KEYS[action]
		InputMap.action_add_event(action, k)


## Forgets every override and puts the default keys back.
func reset_keys() -> void:
	key_overrides.clear()
	for action: StringName in _default_keys:
		if InputMap.has_action(action):
			set_action_key(action, _default_keys[action] as Key)


## Records the current keyboard key of every remappable action as its default.
## Runs once; later calls are no-ops so overrides never become "defaults".
static func capture_default_keys() -> void:
	if not _default_keys.is_empty():
		return
	for action: StringName in REMAPPABLE:
		if not InputMap.has_action(action):
			continue
		for ev: InputEvent in InputMap.action_get_events(action):
			var k := ev as InputEventKey
			if k != null:
				_default_keys[action] = k.keycode if k.keycode != KEY_NONE else k.physical_keycode
				break


## Applies every saved override to the InputMap. Call after actions are registered.
func apply_keys() -> void:
	capture_default_keys()
	for action: StringName in key_overrides:
		if InputMap.has_action(action):
			set_action_key(action, key_overrides[action] as Key)


## Replaces the keyboard events of [param action] with one [param keycode] key.
static func set_action_key(action: StringName, keycode: Key) -> void:
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	var key := InputEventKey.new()
	key.keycode = keycode
	InputMap.action_add_event(action, key)


## Display name of [param action]'s first keyboard key, or "—" when it has none.
static func key_label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "—"
	for ev: InputEvent in InputMap.action_get_events(action):
		var k := ev as InputEventKey
		if k == null:
			continue
		var code: Key = k.keycode if k.keycode != KEY_NONE else k.physical_keycode
		return OS.get_keycode_string(code)
	return "—"


## Action already using [param keycode] among the remappable ones, or &"" when free.
static func action_using_key(keycode: Key) -> StringName:
	for action: StringName in REMAPPABLE:
		if not InputMap.has_action(action):
			continue
		for ev: InputEvent in InputMap.action_get_events(action):
			var k := ev as InputEventKey
			if k != null and (k.keycode == keycode or k.physical_keycode == keycode):
				return action
	return &""


# ── Persistence ───────────────────────────────────────────────────────────────

## Loads settings from [param path]. Missing or bad values keep their defaults.
static func load_from(path: String = DEFAULT_PATH) -> GameSettings:
	var s := GameSettings.new()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return s
	s.fullscreen = bool(cfg.get_value(_SECTION, "fullscreen", false))
	s.resolution_idx = clampi(int(cfg.get_value(_SECTION, "resolution_idx", 0)), 0, RESOLUTIONS.size() - 1)
	s.vsync = bool(cfg.get_value(_SECTION, "vsync", true))
	s.screen_shake = clampf(float(cfg.get_value(_SECTION, "screen_shake", 1.0)), 0.0, 1.0)
	s.reduce_flashes = bool(cfg.get_value(_SECTION, "reduce_flashes", false))
	s.reduce_motion = bool(cfg.get_value(_SECTION, "reduce_motion", false))
	if cfg.has_section(_KEYS_SECTION):
		for key: String in cfg.get_section_keys(_KEYS_SECTION):
			var action := StringName(key)
			var code: int = int(cfg.get_value(_KEYS_SECTION, key, 0))
			if REMAPPABLE.has(action) and code > 0:
				s.key_overrides[action] = code
	return s


## Writes settings to [param path], keeping other sections (audio). Returns the error.
func save_to(path: String = DEFAULT_PATH) -> Error:
	var cfg := ConfigFile.new()
	cfg.load(path)  # keep the audio section; a missing file is fine
	cfg.set_value(_SECTION, "fullscreen", fullscreen)
	cfg.set_value(_SECTION, "resolution_idx", resolution_idx)
	cfg.set_value(_SECTION, "vsync", vsync)
	cfg.set_value(_SECTION, "screen_shake", screen_shake)
	cfg.set_value(_SECTION, "reduce_flashes", reduce_flashes)
	cfg.set_value(_SECTION, "reduce_motion", reduce_motion)
	if cfg.has_section(_KEYS_SECTION):
		cfg.erase_section(_KEYS_SECTION)
	for action: StringName in key_overrides:
		cfg.set_value(_KEYS_SECTION, String(action), key_overrides[action])
	return cfg.save(path)
