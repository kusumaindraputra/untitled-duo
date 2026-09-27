## enemy_bullet_palette_test.gd — Enemy shots keep their own colour family (ADR-0037).
##
## Coverage:
##   Rim and every accent core stay clear of all five Prana hues
##   The palette has the mob accent plus one distinct accent per boss
##   Every bullet pattern names a known accent; boss patterns use their boss accent
##   core_for() falls back to the mob core for an unknown accent
##   Projectile takes its core from the pattern accent and resets to the mob core
extends GdUnitTestSuite

const PALETTE: EnemyBulletPalette = preload("res://assets/data/enemy_bullet_palette.tres")
const PRANA_TYPES: Array[PranaType] = [
	preload("res://assets/data/prana_types/prana_fire.tres"),
	preload("res://assets/data/prana_types/prana_ice.tres"),
	preload("res://assets/data/prana_types/prana_lightning.tres"),
	preload("res://assets/data/prana_types/prana_nature.tres"),
	preload("res://assets/data/prana_types/prana_shadow.tres"),
]
const PATTERN_DIR: String = "res://assets/data/bullet_patterns/"
const BOSS_ACCENTS: Array[StringName] = [&"sentinel", &"warden", &"keeper"]
## Art bible §4.3: a colour this far round the hue wheel from a Prana colour cannot
## be mistaken for it...
const CLEAR_HUE_DEG: float = 40.0
## ...and a closer one must still be this far away and differ in saturation + value.
const MIN_HUE_DEG: float = 20.0
const MIN_SV_GAP: float = 0.2
## Below this saturation a colour reads as white / near-neutral, never as a Prana hue.
const NEUTRAL_SAT: float = 0.2
## Boss accents must differ this much from each other (RGB distance).
const MIN_ACCENT_DIST: float = 0.3


func _hue_gap_deg(a: Color, b: Color) -> float:
	var d: float = absf(a.h - b.h) * 360.0
	return minf(d, 360.0 - d)


func _clear_of_prana(c: Color) -> bool:
	if c.s < NEUTRAL_SAT:
		return true
	for v: Variant in PRANA_TYPES:
		var prana := v as PranaType
		var gap: float = _hue_gap_deg(c, prana.color)
		if gap >= CLEAR_HUE_DEG:
			continue
		var sv: float = absf(c.s - prana.color.s) + absf(c.v - prana.color.v)
		if gap < MIN_HUE_DEG or sv < MIN_SV_GAP:
			return false
	return true


func _rgb_dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func test_rim_is_clear_of_every_prana_hue() -> void:
	assert_bool(_clear_of_prana(PALETTE.rim)).is_true()


func test_every_accent_core_is_clear_of_every_prana_hue() -> void:
	for accent: StringName in PALETTE.cores:
		assert_bool(_clear_of_prana(PALETTE.core_for(accent))) \
			.override_failure_message("accent %s looks like a Prana colour" % accent) \
			.is_true()


func test_palette_has_mob_and_one_accent_per_boss() -> void:
	assert_bool(PALETTE.has_accent(EnemyBulletPalette.DEFAULT_ACCENT)).is_true()
	for accent: StringName in BOSS_ACCENTS:
		assert_bool(PALETTE.has_accent(accent)).is_true()


func test_boss_accents_differ_from_each_other_and_from_mobs() -> void:
	var ids: Array[StringName] = BOSS_ACCENTS.duplicate()
	ids.append(EnemyBulletPalette.DEFAULT_ACCENT)
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			var d: float = _rgb_dist(PALETTE.core_for(ids[i]), PALETTE.core_for(ids[j]))
			assert_float(d) \
				.override_failure_message("%s and %s are too alike" % [ids[i], ids[j]]) \
				.is_greater_equal(MIN_ACCENT_DIST)


func test_every_pattern_names_a_known_accent() -> void:
	var files: PackedStringArray = DirAccess.get_files_at(PATTERN_DIR)
	assert_int(files.size()).is_greater(0)
	for f: String in files:
		if not f.ends_with(".tres"):
			continue
		var p := load(PATTERN_DIR + f) as BulletPattern
		assert_bool(PALETTE.has_accent(p.accent)) \
			.override_failure_message("%s uses unknown accent %s" % [f, p.accent]) \
			.is_true()


func test_boss_patterns_use_their_boss_accent() -> void:
	for f: String in DirAccess.get_files_at(PATTERN_DIR):
		if not f.ends_with(".tres"):
			continue
		var prefix: StringName = StringName(f.get_slice("_", 0))
		if not BOSS_ACCENTS.has(prefix):
			continue
		var p := load(PATTERN_DIR + f) as BulletPattern
		assert_str(String(p.accent)).override_failure_message(f).is_equal(String(prefix))


func test_core_for_unknown_accent_falls_back_to_mob() -> void:
	assert_bool(PALETTE.core_for(&"no_such_boss") == PALETTE.core_for(&"mob")).is_true()


func test_projectile_takes_core_from_pattern_accent() -> void:
	var p := BulletPattern.new()
	p.accent = &"warden"
	var b := Projectile.new()
	b.launch_pattern(Vector2.RIGHT, 1.0, p, 100.0)
	assert_bool(b._color == PALETTE.core_for(&"warden")).is_true()
	b.reset_for_reuse()
	assert_bool(b._color == PALETTE.core_for(&"mob")).is_true()
	b.free()
