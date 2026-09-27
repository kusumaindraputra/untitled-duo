## art_consistency_test.gd — art bible colour rules for UI, props and boss arenas (ADR-0039).
extends GdUnitTestSuite

const ROOM_SCENE: PackedScene = preload("res://src/scenes/IsometricRoom.tscn")
const THEME: Theme = preload("res://assets/ui/game_theme.tres")
const CORES: CoreRoster = preload("res://assets/data/cores/core_roster.tres")
const ROSTER: BossRoster = preload("res://assets/data/bosses/boss_roster.tres")
const THEME_PATHS: Array[String] = [
	"res://assets/data/floor_themes/floor_theme_1.tres",
	"res://assets/data/floor_themes/floor_theme_2.tres",
	"res://assets/data/floor_themes/floor_theme_3.tres",
]
## Art bible §2 rule 1 and §4.1: non-magic colours stay at or below 40 % saturation.
const SATURATION_CAP: float = 0.40
## Art bible §4.3 reserved boss colours by EnemyType id.
const BOSS_COLORS: Dictionary = {
	5: Color("#23B39A"),   # Vault Sentinel — B2 Vault Teal
	3: Color("#9B2ED4"),   # Warped Warden — B1 Corruption Violet
	11: Color("#D42E5E"),  # Cipher Keeper — B3 Cipher Rose
}


## Images store 8-bit channels, so compare within one step.
func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


func _hue_gap(a: Color, b: Color) -> float:
	var d: float = absf(a.h - b.h) * 360.0
	return minf(d, 360.0 - d)


# ── UI palette ─────────────────────────────────────────────────────────────────

func test_ui_palette_colors_stay_under_saturation_cap() -> void:
	for c: Color in UIPalette.capped_colors():
		assert_float(UIPalette.hsl_saturation(c)).is_less_equal(SATURATION_CAP)


func test_hsl_saturation_of_known_colours() -> void:
	# HSL(0, 50 %, 50 %) and a neutral grey.
	assert_float(UIPalette.hsl_saturation(Color(0.75, 0.25, 0.25))).is_equal_approx(0.5, 0.001)
	assert_float(UIPalette.hsl_saturation(Color(0.5, 0.5, 0.5))).is_equal(0.0)


func test_theme_label_colour_is_palette_text() -> void:
	var c: Color = THEME.get_color(&"font_color", &"Label")
	assert_bool(c.is_equal_approx(UIPalette.TEXT)).is_true()


func test_minimap_markers_avoid_prana_and_boss_colours() -> void:
	for c: Color in UIPalette.MAP_ROOM:
		assert_float(UIPalette.hsl_saturation(c)).is_less_equal(SATURATION_CAP)
	assert_float(UIPalette.hsl_saturation(UIPalette.MAP_CURSED)).is_less_equal(SATURATION_CAP)


func test_core_accents_are_not_jewel_tones() -> void:
	for v: Variant in CORES.cores:
		var core := v as CoreFrame
		assert_float(UIPalette.hsl_saturation(core.accent)).is_less_equal(SATURATION_CAP)


# ── Title glow ─────────────────────────────────────────────────────────────────

func test_title_glow_without_prana_is_accent() -> void:
	var none: Array[Color] = []
	assert_bool(UIPalette.title_glow(3.0, none).is_equal_approx(UIPalette.ACCENT)).is_true()


func test_title_glow_peaks_on_the_prana_colour() -> void:
	var prana: Array[Color] = [Color("#F24C1D"), Color("#4A5EF5")]
	# Breath peaks at t = 1 s (half of the 2 s breath).
	var c: Color = UIPalette.title_glow(UIPalette.TITLE_BREATH_SEC * 0.5, prana)
	assert_bool(c.is_equal_approx(prana[0])).is_true()


func test_title_glow_moves_to_the_next_prana_colour() -> void:
	var prana: Array[Color] = [Color("#F24C1D"), Color("#4A5EF5")]
	var t: float = UIPalette.TITLE_CYCLE_SEC + UIPalette.TITLE_BREATH_SEC * 0.5
	assert_bool(UIPalette.title_glow(t, prana).is_equal_approx(prana[1])).is_true()


func test_title_glow_dims_toward_text_between_breaths() -> void:
	var prana: Array[Color] = [Color("#F24C1D")]
	var c: Color = UIPalette.title_glow(0.0, prana)
	assert_bool(c.is_equal_approx(prana[0].lerp(UIPalette.TEXT, 0.3))).is_true()


# ── Boss colours ───────────────────────────────────────────────────────────────

func test_boss_reserved_colours_match_art_bible() -> void:
	for type_id: int in BOSS_COLORS:
		var profile: BossProfile = ROSTER.profile_for(type_id)
		assert_object(profile).is_not_null()
		assert_bool(profile.reserved_color.is_equal_approx(BOSS_COLORS[type_id])).override_failure_message(
			"boss %d reserved colour" % type_id).is_true()


func test_boss_banners_share_their_boss_hue() -> void:
	for type_id: int in BOSS_COLORS:
		var profile: BossProfile = ROSTER.profile_for(type_id)
		assert_float(_hue_gap(profile.banner_color, profile.reserved_color)).is_less(12.0)


func test_boss_ambience_is_a_tint_not_a_takeover() -> void:
	for type_id: int in BOSS_COLORS:
		var profile: BossProfile = ROSTER.profile_for(type_id)
		assert_float(profile.ambience_strength).is_between(0.05, 0.4)
		assert_float(profile.ambience_fade_sec).is_greater(0.0)


func test_ambience_tint_weight_zero_is_base() -> void:
	var base := Color(0.9, 0.95, 1.0, 1.0)
	assert_bool(IsometricRoom.ambience_tint(base, Color.RED, 0.0).is_equal_approx(base)).is_true()


func test_ambience_tint_full_weight_multiplies_and_keeps_alpha() -> void:
	var base := Color(1.0, 1.0, 1.0, 0.8)
	var out: Color = IsometricRoom.ambience_tint(base, Color(0.5, 0.25, 1.0), 1.0)
	assert_bool(out.is_equal_approx(Color(0.5, 0.25, 1.0, 0.8))).is_true()


func test_ambience_tint_clamps_weight() -> void:
	var a: Color = IsometricRoom.ambience_tint(Color.WHITE, Color.BLUE, 3.0)
	var b: Color = IsometricRoom.ambience_tint(Color.WHITE, Color.BLUE, 1.0)
	assert_bool(a.is_equal_approx(b)).is_true()


func test_set_ambience_instant_tints_floor_and_clears() -> void:
	var room: IsometricRoom = ROOM_SCENE.instantiate()
	room.decor_seed = 3
	add_child(room)
	var tiles: TileMapLayer = room.get_node("TileMapLayer")
	room.set_ambience(Color(0.5, 0.5, 1.0), 0.5, 0.0)
	assert_bool(tiles.modulate.is_equal_approx(Color(0.75, 0.75, 1.0))).is_true()
	room.set_ambience(Color.WHITE, 0.0, 0.0)
	assert_bool(tiles.modulate.is_equal_approx(Color.WHITE)).is_true()
	remove_child(room)
	room.free()


# ── Environment props ──────────────────────────────────────────────────────────

func test_floor_pillars_and_rune_glow_stay_under_cap() -> void:
	for path: String in THEME_PATHS:
		var theme: FloorTheme = load(path) as FloorTheme
		assert_float(UIPalette.hsl_saturation(theme.pillar_color)).is_less_equal(SATURATION_CAP)
		assert_float(UIPalette.hsl_saturation(theme.look.prop_glow)).is_less_equal(SATURATION_CAP)


func test_pillar_rune_band_is_not_a_prana_colour() -> void:
	assert_float(UIPalette.hsl_saturation(CoverPillar.RUNE_COLOR)).is_less_equal(SATURATION_CAP)
	var p := CoverPillar.new()
	p.setup(10, 18.0, Color.GRAY, Color(0.4, 0.3, 0.2))
	assert_bool(p.rune_color.is_equal_approx(Color(0.4, 0.3, 0.2))).is_true()
	p.free()


func test_rubble_is_painted_in_the_floor_palette() -> void:
	for path: String in THEME_PATHS:
		var look: RoomLook = (load(path) as FloorTheme).look
		var img: Image = PropArt.build_image(PropArt.Prop.RUBBLE, look)
		assert_int(img.get_width()).is_equal(24)
		assert_int(img.get_height()).is_equal(20)
		var found_mid: bool = false
		for y: int in img.get_height():
			for x: int in img.get_width():
				var c: Color = img.get_pixel(x, y)
				if c.a > 0.0 and _close(c, look.prop_mid):
					found_mid = true
		assert_bool(found_mid).is_true()


func test_rubble_is_a_standing_prop() -> void:
	assert_bool(PropArt.hangs(PropArt.Prop.RUBBLE)).is_false()
