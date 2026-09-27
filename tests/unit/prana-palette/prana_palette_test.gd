## prana_palette_test.gd — Unit tests for the colour-blind Prana palettes (ADR-0047).
##
## Coverage:
##   each palette has one colour per Prana type
##   under its own colour-vision deficiency (Machado 2009, severity 1.0) every pair of
##   Prana colours stays apart, and further apart than the default colours
##   every palette colour stays away from the hostile bullet rim (ADR-0037)
##   GameSettings: color_mode picks the palette, survives save/load, bad values clamp
##   PranaCatalog: set_palette() swaps get_type_color() and get_type().color and signals
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const PranaCatalogScript: GDScript = preload("res://src/data/prana_catalog.gd")
const BULLET_PALETTE: EnemyBulletPalette = preload("res://assets/data/enemy_bullet_palette.tres")
const TYPES_DIR: String = "res://assets/data/prana_types/"
const TYPE_FILES: Array[String] = [
	"prana_fire.tres", "prana_shadow.tres", "prana_lightning.tres",
	"prana_ice.tres", "prana_nature.tres",
]
const TEST_PATH: String = "user://test_prana_palette_settings.cfg"

## Minimum CIE76 ΔE between two Prana colours as seen with the mode's deficiency.
## The default colours reach only 15–26 here; 40 is clearly distinct at a glance.
const MIN_PAIR_DELTA_E: float = 40.0
## Minimum ΔE between any Prana colour and the hostile bullet rim, in normal vision
## and with the mode's deficiency.
const MIN_RIM_DELTA_E: float = 25.0

## Machado, Oliveira & Fernandes (2009) simulation matrices, severity 1.0, applied to
## linear RGB. Rows are output R, G, B.
const CVD_MATRICES: Dictionary[int, Array] = {
	GameSettings.ColorMode.DEUTERANOPIA: [
		Vector3(0.367322, 0.860646, -0.227968),
		Vector3(0.280085, 0.672501, 0.047413),
		Vector3(-0.011820, 0.042940, 0.968881),
	],
	GameSettings.ColorMode.PROTANOPIA: [
		Vector3(0.152286, 1.052583, -0.204868),
		Vector3(0.114503, 0.786281, 0.099216),
		Vector3(-0.003882, -0.048116, 1.051998),
	],
	GameSettings.ColorMode.TRITANOPIA: [
		Vector3(1.255528, -0.076749, -0.178779),
		Vector3(-0.078411, 0.930809, 0.147602),
		Vector3(0.004733, 0.691367, 0.303900),
	],
}

var _saved_current: GameSettings = null


func before_test() -> void:
	_saved_current = GameSettings.current


func after_test() -> void:
	GameSettings.current = _saved_current
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


# ── Colour helpers ────────────────────────────────────────────────────────────

## [param c] as seen with the deficiency whose matrix rows are [param m].
func _simulate(c: Color, m: Array) -> Color:
	var lin := Vector3(c.srgb_to_linear().r, c.srgb_to_linear().g, c.srgb_to_linear().b)
	var out := Color(
		clampf((m[0] as Vector3).dot(lin), 0.0, 1.0),
		clampf((m[1] as Vector3).dot(lin), 0.0, 1.0),
		clampf((m[2] as Vector3).dot(lin), 0.0, 1.0))
	return out.linear_to_srgb()


## CIE L*a*b* (D65) of an sRGB colour.
func _lab(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	var x: float = (0.4124 * l.r + 0.3576 * l.g + 0.1805 * l.b) / 0.95047
	var y: float = 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b
	var z: float = (0.0193 * l.r + 0.1192 * l.g + 0.9505 * l.b) / 1.08883
	var fx: float = _lab_f(x)
	var fy: float = _lab_f(y)
	var fz: float = _lab_f(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


func _lab_f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0


func _delta_e(a: Color, b: Color) -> float:
	return _lab(a).distance_to(_lab(b))


## Smallest ΔE between any two of [param colors] as seen with [param mode].
func _min_pair(colors: Array[Color], mode: int) -> float:
	var m: Array = CVD_MATRICES[mode]
	var best: float = INF
	for i: int in colors.size():
		for j: int in range(i + 1, colors.size()):
			best = minf(best, _delta_e(_simulate(colors[i], m), _simulate(colors[j], m)))
	return best


func _default_colors() -> Array[Color]:
	var out: Array[Color] = []
	for f: String in TYPE_FILES:
		out.append((load(TYPES_DIR + f) as PranaType).color)
	return out


func _palette(mode: int) -> PranaPalette:
	var s := GameSettings.new()
	s.color_mode = mode
	return s.prana_palette()


# ── Palettes ──────────────────────────────────────────────────────────────────

func test_prana_palette_every_mode_has_one_colour_per_type() -> void:
	for mode: int in GameSettings.PRANA_PALETTES:
		var p: PranaPalette = _palette(mode)
		assert_object(p).override_failure_message("mode %d has no palette" % mode).is_not_null()
		assert_int(p.colors.size()).is_equal(TYPE_FILES.size())


func test_prana_palette_colours_stay_apart_under_own_deficiency() -> void:
	for mode: int in GameSettings.PRANA_PALETTES:
		var d: float = _min_pair(_palette(mode).colors, mode)
		assert_float(d).override_failure_message(
			"mode %d: closest Prana pair ΔE %.1f < %.1f" % [mode, d, MIN_PAIR_DELTA_E]
		).is_greater_equal(MIN_PAIR_DELTA_E)


func test_prana_palette_beats_default_colours_under_own_deficiency() -> void:
	var defaults: Array[Color] = _default_colors()
	for mode: int in GameSettings.PRANA_PALETTES:
		assert_float(_min_pair(_palette(mode).colors, mode)).is_greater(_min_pair(defaults, mode))


func test_prana_palette_colours_stay_away_from_hostile_rim() -> void:
	var rim: Color = BULLET_PALETTE.rim
	for mode: int in GameSettings.PRANA_PALETTES:
		var m: Array = CVD_MATRICES[mode]
		for c: Color in _palette(mode).colors:
			assert_float(_delta_e(c, rim)).is_greater_equal(MIN_RIM_DELTA_E)
			assert_float(_delta_e(_simulate(c, m), _simulate(rim, m))).override_failure_message(
				"mode %d: %s too close to the bullet rim" % [mode, c.to_html(false)]
			).is_greater_equal(MIN_RIM_DELTA_E)


func test_prana_palette_color_for_falls_back_out_of_range() -> void:
	var p := PranaPalette.new()
	p.colors = [Color.RED]
	assert_bool(p.color_for(0, Color.WHITE) == Color.RED).is_true()
	assert_bool(p.color_for(3, Color.WHITE) == Color.WHITE).is_true()
	assert_bool(p.color_for(-1, Color.WHITE) == Color.WHITE).is_true()


# ── GameSettings ──────────────────────────────────────────────────────────────

func test_prana_palette_settings_off_has_no_palette() -> void:
	var s := GameSettings.new()
	assert_int(s.color_mode).is_equal(GameSettings.ColorMode.OFF)
	assert_object(s.prana_palette()).is_null()


func test_prana_palette_settings_color_mode_round_trips() -> void:
	var s := GameSettings.new()
	s.color_mode = GameSettings.ColorMode.TRITANOPIA
	assert_int(s.save_to(TEST_PATH)).is_equal(OK)
	assert_int(GameSettings.load_from(TEST_PATH).color_mode).is_equal(GameSettings.ColorMode.TRITANOPIA)


func test_prana_palette_settings_bad_color_mode_clamps() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "color_mode", 99)
	cfg.save(TEST_PATH)
	assert_int(GameSettings.load_from(TEST_PATH).color_mode).is_equal(GameSettings.ColorMode.TRITANOPIA)


# ── PranaCatalog ──────────────────────────────────────────────────────────────

func test_prana_palette_catalog_serves_palette_colours() -> void:
	var catalog: Node = PranaCatalogScript.new()
	catalog._load_types()
	catalog._initialized = true
	var defaults: Array[Color] = _default_colors()
	var p: PranaPalette = _palette(GameSettings.ColorMode.DEUTERANOPIA)
	var signals: Array[int] = [0]
	catalog.palette_changed.connect(func() -> void: signals[0] += 1)

	catalog.set_palette(p)
	for id: int in TYPE_FILES.size():
		assert_bool(catalog.get_type_color(id) == p.colors[id]).is_true()
		assert_bool((catalog.get_type(id) as PranaType).color == p.colors[id]).is_true()
	assert_bool((catalog.get_all_types()[1] as PranaType).color == p.colors[1]).is_true()

	catalog.set_palette(null)
	for id: int in TYPE_FILES.size():
		assert_bool(catalog.get_type_color(id).is_equal_approx(defaults[id])).is_true()
	assert_int(signals[0]).is_equal(2)
	catalog.free()
