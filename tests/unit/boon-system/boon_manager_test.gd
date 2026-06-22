## boon_manager_test.gd — Unit tests for BoonManager selection + application logic.
##
## Coverage:
##   AC-BM-01: roll_choices(3) returns 3 distinct boons
##   AC-BM-02: roll_choices is deterministic given a seeded RNG
##   AC-BM-03: roll_choices(count > catalog size) returns the whole catalog
##   AC-BM-04: apply_boon("damage") multiplies SpellCastingEffects damage mult
##   AC-BM-05: apply_boon("move_speed") calls the player's apply_move_speed_mult
##   AC-BM-06: apply_boon emits boon_applied with the boon id
##   AC-BM-07: apply_boon(unknown id) does not emit boon_applied
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const BoonManagerScript = preload("res://src/systems/boon_manager.gd")


## Minimal stand-in for PlayerController that records boon calls.
class _FakePlayer extends Node:
	var move_calls: Array[float] = []
	var dash_calls: Array[float] = []
	func apply_move_speed_mult(factor: float) -> void:
		move_calls.append(factor)
	func apply_dash_cooldown_mult(factor: float) -> void:
		dash_calls.append(factor)


## Minimal stand-in for PranaBag that records add() calls.
class _FakeBag extends Node:
	var added: Array[int] = []
	func add(type_id: int) -> void:
		added.append(type_id)


## Creates a BoonManager NOT added to the tree (these tests never call offer_boons,
## so no SceneTree is required). Caller frees it via bm.free().
func _make_bm() -> BoonManager:
	return BoonManagerScript.new()


# ── AC-BM-01: roll_choices(3) returns 3 distinct boons ───────────────────────

func test_boon_manager_roll_choices_returns_three_distinct() -> void:
	var bm: BoonManager = _make_bm()

	var choices: Array[Dictionary] = bm.roll_choices(3)

	assert_int(choices.size()).is_equal(3)
	var ids: Array = []
	for c: Dictionary in choices:
		ids.append(c["id"])
	assert_int(ids.size()).is_equal(_unique_count(ids))

	bm.free()


# ── AC-BM-02: roll_choices deterministic with a seeded RNG ───────────────────

func test_boon_manager_roll_choices_is_deterministic_with_seeded_rng() -> void:
	var bm: BoonManager = _make_bm()
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 12345
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 12345

	var first: Array[Dictionary] = bm.roll_choices(3, rng_a)
	var second: Array[Dictionary] = bm.roll_choices(3, rng_b)

	assert_str(str(first[0]["id"])).is_equal(str(second[0]["id"]))
	assert_str(str(first[1]["id"])).is_equal(str(second[1]["id"]))
	assert_str(str(first[2]["id"])).is_equal(str(second[2]["id"]))

	bm.free()


# ── AC-BM-03: roll_choices caps at catalog size ──────────────────────────────

func test_boon_manager_roll_choices_caps_at_catalog_size() -> void:
	var bm: BoonManager = _make_bm()
	var catalog_size: int = bm.get_catalog().size()

	var choices: Array[Dictionary] = bm.roll_choices(99)

	assert_int(choices.size()).is_equal(catalog_size)

	bm.free()


# ── AC-BM-04: apply_boon("damage") multiplies SCE damage mult ────────────────

func test_boon_manager_apply_damage_boon_multiplies_spell_damage() -> void:
	var bm: BoonManager = _make_bm()
	var before: float = SpellCastingEffects.get_damage_mult()

	bm.apply_boon(&"damage")

	assert_float(SpellCastingEffects.get_damage_mult()).is_equal_approx(before * 1.20, 0.0001)
	# Restore the autoload so other suites see an unmodified multiplier.
	SpellCastingEffects._run_damage_mult = before

	bm.free()


# ── AC-BM-05: apply_boon("move_speed") calls the player ──────────────────────

func test_boon_manager_apply_move_speed_boon_calls_player() -> void:
	var bm: BoonManager = _make_bm()
	var fake := _FakePlayer.new()
	bm.set_player_provider(func() -> Node: return fake)

	bm.apply_boon(&"move_speed")

	assert_int(fake.move_calls.size()).is_equal(1)
	assert_float(fake.move_calls[0]).is_equal_approx(1.15, 0.0001)

	bm.free()
	fake.free()


# ── AC-BM-06: apply_boon emits boon_applied with the id ──────────────────────

func test_boon_manager_apply_boon_emits_boon_applied_signal() -> void:
	var bm: BoonManager = _make_bm()
	var fake := _FakePlayer.new()
	bm.set_player_provider(func() -> Node: return fake)
	var received: Array = []
	bm.boon_applied.connect(func(id: StringName) -> void: received.append(id))

	bm.apply_boon(&"dash_cd")

	assert_int(received.size()).is_equal(1)
	assert_str(str(received[0])).is_equal("dash_cd")

	bm.free()
	fake.free()


# ── AC-BM-07: apply_boon(unknown) does not emit ──────────────────────────────

func test_boon_manager_apply_unknown_boon_does_not_emit() -> void:
	var bm: BoonManager = _make_bm()
	var received: Array = []
	bm.boon_applied.connect(func(id: StringName) -> void: received.append(id))

	bm.apply_boon(&"not_a_real_boon")

	assert_int(received.size()).is_equal(0)

	bm.free()


# ── AC-BM-08: reward pool includes Prana cards ───────────────────────────────

func test_boon_manager_catalog_includes_prana_cards() -> void:
	var bm: BoonManager = _make_bm()

	var catalog: Array[Dictionary] = bm.get_catalog()

	# Pool = 5 stat boons + 5 Prana cards (one per type).
	assert_int(catalog.size()).is_equal(10)
	var prana_ids: Array = []
	for c: Dictionary in catalog:
		if String(c["id"]).begins_with("prana_"):
			prana_ids.append(c["id"])
	assert_int(prana_ids.size()).is_equal(5)

	bm.free()


# ── AC-BM-09: apply Prana card adds to the bag and emits ──────────────────────

func test_boon_manager_apply_prana_card_adds_to_bag() -> void:
	var bm: BoonManager = _make_bm()
	var fake_bag := _FakeBag.new()
	bm.set_bag_provider(func() -> Node: return fake_bag)
	var received: Array = []
	bm.boon_applied.connect(func(id: StringName) -> void: received.append(id))

	bm.apply_boon(&"prana_3")

	assert_int(fake_bag.added.size()).is_equal(1)
	assert_int(fake_bag.added[0]).is_equal(3)
	assert_int(received.size()).is_equal(1)
	assert_str(str(received[0])).is_equal("prana_3")

	bm.free()
	fake_bag.free()


# ── Helpers ──────────────────────────────────────────────────────────────────

func _unique_count(arr: Array) -> int:
	var seen: Array = []
	for v in arr:
		if not seen.has(v):
			seen.append(v)
	return seen.size()
