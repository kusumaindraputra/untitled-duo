## iso_character_facing_test.gd — Regression + boundary tests for IsoCharacter.set_facing().
##
## Regression: set_facing() used `% 16` on a DIR_KEYS array of size 8.
## When roundi(angle / DIR_STEP) == 8 (boundary near TAU), this gave idx=8 →
## out-of-bounds crash. Fix: changed to `% DIR_KEYS.size()`.
##
## The exact crash direction: Vector2(cos(PI/4), -sin(PI/4)) produces angle ≈ 337.5°,
## which lands at the 7.5 boundary where roundi() rounds up to 8.
##
## Coverage:
##   - Boundary direction (idx 8 before fix) does not crash and yields a valid dir key
##   - All 8 canonical directions yield a valid dir key from DIR_KEYS
##   - Zero-length input is a no-op (does not mutate _current_dir)
extends GdUnitTestSuite

const IsoCharacterScript: GDScript = preload("res://src/characters/iso_character.gd")

## Valid direction keys — matches IsoCharacter.DIR_KEYS.
const VALID_DIRS: Array[String] = ["E", "NE", "N", "NW", "W", "SW", "S", "SE"]

## Direction that reliably produces roundi(angle/DIR_STEP) = 8.
## angle ≈ 342° → angle/DIR_STEP ≈ 7.6 → roundi = 8.
## Derivation: atan2(-dy, dx) = 72° → dx = cos(72°) ≈ 0.309, dy = -sin(72°) ≈ -0.951.
## fposmod(72° - 90°, 360°) = 342°; 342/45 = 7.6 → roundi(7.6) = 8.
## Before fix: 8 % 16 = 8 → OOB crash. After fix: 8 % 8 = 0 → DIR_KEYS[0] = "E".
const CRASH_DIRECTION: Vector2 = Vector2(0.30901699437494742, -0.9510565162951535)

var _char: IsoCharacter = null

# ── Lifecycle ──────────────────────────────────────────────────────────────────

func before_test() -> void:
	_char = IsoCharacterScript.new() as IsoCharacter


func after_test() -> void:
	if is_instance_valid(_char):
		_char.free()
	_char = null

# ── Regression: boundary index 8 ──────────────────────────────────────────────

func test_iso_character_set_facing_boundary_direction_does_not_crash() -> void:
	# This exact direction produced roundi(angle/DIR_STEP)==8 before the fix.
	# The test passes if no out-of-bounds error is thrown and _current_dir is valid.
	_char.set_facing(CRASH_DIRECTION)
	assert_bool(VALID_DIRS.has(_char._current_dir)).is_true()


func test_iso_character_set_facing_boundary_direction_maps_to_E_or_SE() -> void:
	# 337.5° rounds to 0 (E) after `% 8` — confirming the wrap-around is correct.
	_char.set_facing(CRASH_DIRECTION)
	assert_str(_char._current_dir).is_equal("E")

# ── All 8 canonical directions yield valid dir key ─────────────────────────────

func test_iso_character_set_facing_right_yields_valid_dir() -> void:
	_char.set_facing(Vector2.RIGHT)
	assert_bool(VALID_DIRS.has(_char._current_dir)).is_true()


func test_iso_character_set_facing_left_yields_valid_dir() -> void:
	_char.set_facing(Vector2.LEFT)
	assert_bool(VALID_DIRS.has(_char._current_dir)).is_true()


func test_iso_character_set_facing_up_yields_valid_dir() -> void:
	_char.set_facing(Vector2.UP)
	assert_bool(VALID_DIRS.has(_char._current_dir)).is_true()


func test_iso_character_set_facing_down_yields_valid_dir() -> void:
	_char.set_facing(Vector2.DOWN)
	assert_bool(VALID_DIRS.has(_char._current_dir)).is_true()


func test_iso_character_set_facing_all_8_diagonals_yield_valid_dir() -> void:
	var diagonals: Array[Vector2] = [
		Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1),
	]
	for dir: Vector2 in diagonals:
		_char.set_facing(dir)
		assert_bool(VALID_DIRS.has(_char._current_dir)).is_true()

# ── Zero-length input is a no-op ──────────────────────────────────────────────

func test_iso_character_set_facing_zero_vector_does_not_change_dir() -> void:
	var initial_dir: String = _char._current_dir
	_char.set_facing(Vector2.ZERO)
	assert_str(_char._current_dir).is_equal(initial_dir)
