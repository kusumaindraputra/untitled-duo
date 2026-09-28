## GameSettings — display, comfort and control options (ADR-0026).
##
## Stored in user://settings.cfg next to the audio volumes (AudioSystem owns the
## "audio" section; this class owns "game" and "keys" and keeps the others intact).
##   display  — fullscreen, window size, vsync
##   comfort  — screen shake strength (0–100 %), reduced screen flashes, text size and
##              high-contrast bullet outlines (ADR-0032), colour-blind Prana palette
##              (ADR-0047)
##   controls — keyboard key per remappable action, gamepad button per combat action
##   feel     — gamepad rumble strength (0–100 %)
##   hud      — HUD scale, HUD card opacity and the optional run timer (ADR-0046)
##
## The "game" section carries a `version` (ADR-0031). load_from() upgrades older
## files step by step through migrate(), so a tester's settings survive updates.
##
## Plain RefCounted like MetaProgress. `current` is the loaded instance the game
## reads through the static helpers (shake_multiplier, flash_multiplier); tests pass
## their own path and assign `current` themselves.
class_name GameSettings
extends RefCounted

const DEFAULT_PATH: String = "user://settings.cfg"
const _SECTION: String = "game"
const _KEYS_SECTION: String = "keys"
const _PAD_SECTION: String = "pad"

## Settings file format. v1 = files written before ADR-0031 (no version key).
## v2 adds the "pad" section and rumble. v3 adds the HUD options (ADR-0046). Bump this and add a step to migrate()
## whenever a key is renamed, moved or reinterpreted.
const SETTINGS_VERSION: int = 3

## Window sizes offered in windowed mode (16:9; the game renders at 1152×648 and
## scales, so every size shows the same view).
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080),
]
## Actions the player can rebind on the keyboard, in menu order.
const REMAPPABLE: Array[StringName] = [
	&"move_up", &"move_down", &"move_left", &"move_right", &"dash", &"cast", &"special",
	&"swap",
]
## Default keyboard keys for remappable actions the run scene registers itself
## (cast / special come from SpellCastingEffects). Lets the main menu's Settings show
## and rebind them before a run has started.
const DEFAULT_KEYS: Dictionary[StringName, Key] = {
	&"move_up": KEY_W, &"move_down": KEY_S, &"move_left": KEY_A, &"move_right": KEY_D,
	&"dash": KEY_SHIFT, &"swap": KEY_Q,
}
## Actions the player can rebind on the gamepad, in menu order. Movement stays on
## the left stick; the grid keeps its own buttons (it only runs between fights).
const PAD_REMAPPABLE: Array[StringName] = [&"dash", &"cast", &"special", &"swap"]
## Default gamepad button per PAD_REMAPPABLE action (Xbox layout names).
const DEFAULT_PAD: Dictionary[StringName, JoyButton] = {
	&"dash": JOY_BUTTON_X, &"cast": JOY_BUTTON_A, &"special": JOY_BUTTON_Y,
	&"swap": JOY_BUTTON_LEFT_SHOULDER,
}
## Buttons a combat action may use. Start pauses, Back/Guide belong to the system
## and the D-pad drives menus, so those are never offered.
const PAD_BINDABLE: Array[JoyButton] = [
	JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y,
	JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER,
	JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK,
]
## Assist ranges (F2, beta plan): damage taken 50–100 %, game speed 70–100 %.
const ASSIST_DAMAGE_MIN: float = 0.5
const ASSIST_SPEED_MIN: float = 0.7
## Screen flash strength when reduce_flashes is on.
const REDUCED_FLASH_SCALE: float = 0.3
## Text size choices (ADR-0032): multipliers on every UI font size, in menu order.
const TEXT_SCALES: Array[float] = [1.0, 1.15, 1.3]
## HUD scale choices (ADR-0046): multipliers on the corner HUD (left card, floor map,
## toasts, run timer), in menu order. Index 1 is the default 100 %.
const HUD_SCALES: Array[float] = [0.85, 1.0, 1.15, 1.3]
const HUD_SCALE_DEFAULT_IDX: int = 1
## Lowest HUD card opacity offered, so the card never vanishes behind its text.
const HUD_CARD_OPACITY_MIN: float = 0.3
## Colour-vision modes for the Prana palette (ADR-0047), in menu order.
enum ColorMode { OFF, DEUTERANOPIA, PROTANOPIA, TRITANOPIA }
## Palette file per ColorMode; OFF keeps the PranaType colours.
const PRANA_PALETTES: Dictionary[int, String] = {
	ColorMode.DEUTERANOPIA: "res://assets/data/prana_palettes/prana_palette_deuteranopia.tres",
	ColorMode.PROTANOPIA: "res://assets/data/prana_palettes/prana_palette_protanopia.tres",
	ColorMode.TRITANOPIA: "res://assets/data/prana_palettes/prana_palette_tritanopia.tres",
}

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
## Index into TEXT_SCALES (ADR-0032).
var text_scale_idx: int = 0
## Draws enemy bullets with a thick white-and-black outline (ADR-0032).
var bullet_outline: bool = false
## Prana colour palette for colour-blind players, a ColorMode value (ADR-0047).
var color_mode: int = ColorMode.OFF
## Assist (F2) master switch. When off, the options below keep their values but
## have no effect.
var assist_enabled: bool = false
## Assist (F2): share of damage Fayde takes, game speed during runs, and auto-dash.
var assist_damage: float = 1.0
var assist_speed: float = 1.0
var assist_auto_dash: bool = false
## Action → keycode for rebound actions only; unbound actions keep their defaults.
var key_overrides: Dictionary[StringName, int] = {}
## Action → gamepad button for rebound PAD_REMAPPABLE actions only.
var pad_overrides: Dictionary[StringName, int] = {}
## Gamepad rumble strength, 0.0 (off) to 1.0 (full).
var rumble: float = 1.0
## Index into HUD_SCALES (ADR-0046).
var hud_scale_idx: int = HUD_SCALE_DEFAULT_IDX
## Opacity of the HUD card backgrounds, HUD_CARD_OPACITY_MIN to 1.0 (ADR-0046).
var hud_card_opacity: float = 1.0
## Shows the run clock in the HUD (ADR-0046). Off by default.
var show_run_timer: bool = false


## The settings in effect, loading them from disk the first time.
static func active() -> GameSettings:
	if current == null:
		current = load_from()
	return current


## Multiplier for camera shake / trauma (1.0 when no settings are loaded).
static func shake_multiplier() -> float:
	return clampf(current.screen_shake, 0.0, 1.0) if current != null else 1.0


## Multiplier for gamepad rumble (1.0 when no settings are loaded).
static func rumble_multiplier() -> float:
	return clampf(current.rumble, 0.0, 1.0) if current != null else 1.0


## True when Assist is switched on and any option differs from the default.
func assist_active() -> bool:
	return assist_enabled and (assist_damage < 1.0 or assist_speed < 1.0 or assist_auto_dash)


## Damage share in effect: the assist value when Assist is on, else 1.0.
func effective_damage() -> float:
	return clampf(assist_damage, ASSIST_DAMAGE_MIN, 1.0) if assist_enabled else 1.0


## Game speed in effect: the assist value when Assist is on, else 1.0.
func effective_speed() -> float:
	return clampf(assist_speed, ASSIST_SPEED_MIN, 1.0) if assist_enabled else 1.0


## Auto-dash in effect: only when Assist is on.
func effective_auto_dash() -> bool:
	return assist_enabled and assist_auto_dash


## Engine.time_scale for normal play in a run: the assist game speed, else 1.0.
## Slow-mo effects scale from it and restore to it.
static func base_time_scale() -> float:
	return current.effective_speed() if current != null else 1.0


## True when menus and screens should skip fades, typewriter text and idle motion.
static func motion_reduced() -> bool:
	return current != null and current.reduce_motion


## Multiplier on UI font sizes (1.0 when no settings are loaded).
static func text_scale() -> float:
	return current.text_scale_value() if current != null else 1.0


## This instance's text multiplier from text_scale_idx.
func text_scale_value() -> float:
	return TEXT_SCALES[clampi(text_scale_idx, 0, TEXT_SCALES.size() - 1)]


## Multiplier on the corner HUD (1.0 when no settings are loaded).
static func hud_scale() -> float:
	return current.hud_scale_value() if current != null else 1.0


## This instance's HUD multiplier from hud_scale_idx.
func hud_scale_value() -> float:
	return HUD_SCALES[clampi(hud_scale_idx, 0, HUD_SCALES.size() - 1)]


## Opacity multiplier for HUD card backgrounds (1.0 when no settings are loaded).
static func hud_card_alpha() -> float:
	return clampf(current.hud_card_opacity, HUD_CARD_OPACITY_MIN, 1.0) if current != null else 1.0


## True when the HUD should show the run clock.
static func run_timer_on() -> bool:
	return current != null and current.show_run_timer


## True when enemy bullets should draw their high-contrast outline.
static func bullet_outline_on() -> bool:
	return current != null and current.bullet_outline


## Multiplier for full-screen flash opacity (1.0, or REDUCED_FLASH_SCALE).
static func flash_multiplier() -> float:
	return REDUCED_FLASH_SCALE if current != null and current.reduce_flashes else 1.0


## The Prana palette for this instance's color_mode, or null for OFF (ADR-0047).
func prana_palette() -> PranaPalette:
	if not PRANA_PALETTES.has(color_mode):
		return null
	return load(PRANA_PALETTES[color_mode]) as PranaPalette


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


## Creates any missing remappable action with its DEFAULT_KEYS key, and gives every
## PAD_REMAPPABLE action without a gamepad button its DEFAULT_PAD one. Existing
## bindings are left untouched.
static func ensure_actions() -> void:
	for action: StringName in DEFAULT_KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		var k := InputEventKey.new()
		k.keycode = DEFAULT_KEYS[action]
		InputMap.action_add_event(action, k)
	for action: StringName in DEFAULT_PAD:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		if pad_button(action) == JOY_BUTTON_INVALID:
			var joy := InputEventJoypadButton.new()
			joy.button_index = DEFAULT_PAD[action]
			InputMap.action_add_event(action, joy)


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


## Applies every saved key and gamepad override to the InputMap. Call after actions
## are registered.
func apply_keys() -> void:
	capture_default_keys()
	for action: StringName in key_overrides:
		if InputMap.has_action(action):
			set_action_key(action, key_overrides[action] as Key)
	for action: StringName in pad_overrides:
		if InputMap.has_action(action):
			set_action_pad(action, pad_overrides[action] as JoyButton)


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


# ── Gamepad ───────────────────────────────────────────────────────────────────

## Rebinds [param action]'s gamepad button to [param button], keeping its keyboard,
## mouse and stick events. Records the override. Returns false for an action that is
## not pad-remappable or missing, or a button outside PAD_BINDABLE.
func rebind_pad(action: StringName, button: JoyButton) -> bool:
	if not PAD_REMAPPABLE.has(action) or not InputMap.has_action(action) \
			or not PAD_BINDABLE.has(button):
		return false
	pad_overrides[action] = button
	set_action_pad(action, button)
	return true


## Forgets every gamepad override and puts DEFAULT_PAD back.
func reset_pad() -> void:
	pad_overrides.clear()
	for action: StringName in DEFAULT_PAD:
		if InputMap.has_action(action):
			set_action_pad(action, DEFAULT_PAD[action])


## Replaces the gamepad button events of [param action] with one [param button].
static func set_action_pad(action: StringName, button: JoyButton) -> void:
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton:
			InputMap.action_erase_event(action, ev)
	var joy := InputEventJoypadButton.new()
	joy.button_index = button
	InputMap.action_add_event(action, joy)


## First gamepad button bound to [param action], or JOY_BUTTON_INVALID.
static func pad_button(action: StringName) -> JoyButton:
	if not InputMap.has_action(action):
		return JOY_BUTTON_INVALID
	for ev: InputEvent in InputMap.action_get_events(action):
		var joy := ev as InputEventJoypadButton
		if joy != null:
			return joy.button_index
	return JOY_BUTTON_INVALID


## Pad-remappable action already using [param button], or &"" when free.
static func action_using_pad(button: JoyButton) -> StringName:
	for action: StringName in PAD_REMAPPABLE:
		if pad_button(action) == button:
			return action
	return &""


# ── Persistence ───────────────────────────────────────────────────────────────

## Loads settings from [param path]. Missing or bad values keep their defaults.
static func load_from(path: String = DEFAULT_PATH) -> GameSettings:
	var s := GameSettings.new()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return s
	migrate(cfg, file_version(cfg))
	s.fullscreen = bool(cfg.get_value(_SECTION, "fullscreen", false))
	s.resolution_idx = clampi(int(cfg.get_value(_SECTION, "resolution_idx", 0)), 0, RESOLUTIONS.size() - 1)
	s.vsync = bool(cfg.get_value(_SECTION, "vsync", true))
	s.screen_shake = clampf(float(cfg.get_value(_SECTION, "screen_shake", 1.0)), 0.0, 1.0)
	s.reduce_flashes = bool(cfg.get_value(_SECTION, "reduce_flashes", false))
	s.reduce_motion = bool(cfg.get_value(_SECTION, "reduce_motion", false))
	s.text_scale_idx = clampi(int(cfg.get_value(_SECTION, "text_scale_idx", 0)), 0, TEXT_SCALES.size() - 1)
	s.bullet_outline = bool(cfg.get_value(_SECTION, "bullet_outline", false))
	s.color_mode = clampi(int(cfg.get_value(_SECTION, "color_mode", ColorMode.OFF)),
			ColorMode.OFF, ColorMode.TRITANOPIA)
	s.assist_enabled = bool(cfg.get_value(_SECTION, "assist_enabled", false))
	s.assist_damage = clampf(float(cfg.get_value(_SECTION, "assist_damage", 1.0)), ASSIST_DAMAGE_MIN, 1.0)
	s.assist_speed = clampf(float(cfg.get_value(_SECTION, "assist_speed", 1.0)), ASSIST_SPEED_MIN, 1.0)
	s.assist_auto_dash = bool(cfg.get_value(_SECTION, "assist_auto_dash", false))
	if cfg.has_section(_KEYS_SECTION):
		for key: String in cfg.get_section_keys(_KEYS_SECTION):
			var action := StringName(key)
			var code: int = int(cfg.get_value(_KEYS_SECTION, key, 0))
			if REMAPPABLE.has(action) and code > 0:
				s.key_overrides[action] = code
	s.rumble = clampf(float(cfg.get_value(_SECTION, "rumble", 1.0)), 0.0, 1.0)
	s.hud_scale_idx = clampi(int(cfg.get_value(_SECTION, "hud_scale_idx", HUD_SCALE_DEFAULT_IDX)),
		0, HUD_SCALES.size() - 1)
	s.hud_card_opacity = clampf(float(cfg.get_value(_SECTION, "hud_card_opacity", 1.0)),
		HUD_CARD_OPACITY_MIN, 1.0)
	s.show_run_timer = bool(cfg.get_value(_SECTION, "show_run_timer", false))
	if cfg.has_section(_PAD_SECTION):
		for key: String in cfg.get_section_keys(_PAD_SECTION):
			var action := StringName(key)
			var button: int = int(cfg.get_value(_PAD_SECTION, key, -1))
			if PAD_REMAPPABLE.has(action) and PAD_BINDABLE.has(button as JoyButton):
				s.pad_overrides[action] = button
	return s


## Format version of a loaded settings file. Files without one are v1.
static func file_version(cfg: ConfigFile) -> int:
	return maxi(int(cfg.get_value(_SECTION, "version", 1)), 1)


## Upgrades [param cfg] in place from [param from_version] to SETTINGS_VERSION, one
## step at a time. Returns the version the data is at afterwards. Files from a newer
## build are left as they are; load_from() reads the keys it knows.
static func migrate(cfg: ConfigFile, from_version: int) -> int:
	var v: int = from_version
	while v < SETTINGS_VERSION:
		match v:
			1:
				# v1 → v2: nothing moved. The pad section and rumble are new and start
				# at their defaults; keys, audio and every "game" value carry over.
				pass
			2:
				# v2 → v3: the HUD options are new and start at their defaults.
				pass
		v += 1
	if v > from_version:
		cfg.set_value(_SECTION, "version", v)
	return v


## Writes settings to [param path], keeping other sections (audio). Returns the error.
func save_to(path: String = DEFAULT_PATH) -> Error:
	var cfg := ConfigFile.new()
	cfg.load(path)  # keep the audio section; a missing file is fine
	# Never stamp a lower version over a file a newer build wrote.
	cfg.set_value(_SECTION, "version", maxi(SETTINGS_VERSION, file_version(cfg)))
	cfg.set_value(_SECTION, "fullscreen", fullscreen)
	cfg.set_value(_SECTION, "resolution_idx", resolution_idx)
	cfg.set_value(_SECTION, "vsync", vsync)
	cfg.set_value(_SECTION, "screen_shake", screen_shake)
	cfg.set_value(_SECTION, "reduce_flashes", reduce_flashes)
	cfg.set_value(_SECTION, "reduce_motion", reduce_motion)
	cfg.set_value(_SECTION, "text_scale_idx", text_scale_idx)
	cfg.set_value(_SECTION, "bullet_outline", bullet_outline)
	cfg.set_value(_SECTION, "color_mode", color_mode)
	cfg.set_value(_SECTION, "assist_enabled", assist_enabled)
	cfg.set_value(_SECTION, "assist_damage", assist_damage)
	cfg.set_value(_SECTION, "assist_speed", assist_speed)
	cfg.set_value(_SECTION, "assist_auto_dash", assist_auto_dash)
	if cfg.has_section(_KEYS_SECTION):
		cfg.erase_section(_KEYS_SECTION)
	for action: StringName in key_overrides:
		cfg.set_value(_KEYS_SECTION, String(action), key_overrides[action])
	cfg.set_value(_SECTION, "rumble", rumble)
	cfg.set_value(_SECTION, "hud_scale_idx", hud_scale_idx)
	cfg.set_value(_SECTION, "hud_card_opacity", hud_card_opacity)
	cfg.set_value(_SECTION, "show_run_timer", show_run_timer)
	if cfg.has_section(_PAD_SECTION):
		cfg.erase_section(_PAD_SECTION)
	for action: StringName in pad_overrides:
		cfg.set_value(_PAD_SECTION, String(action), pad_overrides[action])
	return cfg.save(path)
