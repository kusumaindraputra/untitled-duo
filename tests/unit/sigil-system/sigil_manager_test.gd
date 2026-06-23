## sigil_manager_test.gd — Unit tests for SigilManager selection + application logic.
##
## Coverage:
##   AC-SM-01: roll_choices(3) returns 3 distinct sigils
##   AC-SM-02: roll_choices is deterministic given a seeded RNG
##   AC-SM-03: roll_choices(count > catalog size) returns the whole catalog
##   AC-SM-04: apply_sigil("damage") multiplies SpellCastingEffects damage mult
##   AC-SM-05: apply_sigil("move_speed") calls the player's apply_move_speed_mult
##   AC-SM-06: apply_sigil emits sigil_applied with the sigil id
##   AC-SM-07: apply_sigil(unknown id) does not emit sigil_applied
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const SigilManagerScript = preload("res://src/systems/sigil_manager.gd")


## Minimal stand-in for PlayerController that records sigil calls.
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


## Creates a SigilManager NOT added to the tree (these tests never call offer_sigils,
## so no SceneTree is required). Caller frees it via sm.free().
func _make_sm() -> SigilManager:
	return SigilManagerScript.new()


# ── AC-SM-01: roll_choices(3) returns 3 distinct sigils ──────────────────────

func test_sigil_manager_roll_choices_returns_three_distinct() -> void:
	var sm: SigilManager = _make_sm()

	var choices: Array[Dictionary] = sm.roll_choices(3)

	assert_int(choices.size()).is_equal(3)
	var ids: Array = []
	for c: Dictionary in choices:
		ids.append(c["id"])
	assert_int(ids.size()).is_equal(_unique_count(ids))

	sm.free()


# ── AC-SM-02: roll_choices deterministic with a seeded RNG ───────────────────

func test_sigil_manager_roll_choices_is_deterministic_with_seeded_rng() -> void:
	var sm: SigilManager = _make_sm()
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 12345
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 12345

	var first: Array[Dictionary] = sm.roll_choices(3, rng_a)
	var second: Array[Dictionary] = sm.roll_choices(3, rng_b)

	assert_str(str(first[0]["id"])).is_equal(str(second[0]["id"]))
	assert_str(str(first[1]["id"])).is_equal(str(second[1]["id"]))
	assert_str(str(first[2]["id"])).is_equal(str(second[2]["id"]))

	sm.free()


# ── AC-SM-03: roll_choices caps at catalog size ──────────────────────────────

func test_sigil_manager_roll_choices_caps_at_catalog_size() -> void:
	var sm: SigilManager = _make_sm()
	var catalog_size: int = sm.get_catalog().size()

	var choices: Array[Dictionary] = sm.roll_choices(99)

	assert_int(choices.size()).is_equal(catalog_size)

	sm.free()


# ── AC-SM-04: apply_sigil("damage") multiplies SCE damage mult ───────────────

func test_sigil_manager_apply_damage_sigil_multiplies_spell_damage() -> void:
	var sm: SigilManager = _make_sm()
	var before: float = SpellCastingEffects.get_damage_mult()

	sm.apply_sigil(&"damage")

	assert_float(SpellCastingEffects.get_damage_mult()).is_equal_approx(before * 1.20, 0.0001)
	# Restore the autoload so other suites see an unmodified multiplier.
	SpellCastingEffects._run_damage_mult = before

	sm.free()


# ── AC-SM-05: apply_sigil("move_speed") calls the player ─────────────────────

func test_sigil_manager_apply_move_speed_sigil_calls_player() -> void:
	var sm: SigilManager = _make_sm()
	var fake := _FakePlayer.new()
	sm.set_player_provider(func() -> Node: return fake)

	sm.apply_sigil(&"move_speed")

	assert_int(fake.move_calls.size()).is_equal(1)
	assert_float(fake.move_calls[0]).is_equal_approx(1.15, 0.0001)

	sm.free()
	fake.free()


# ── AC-SM-06: apply_sigil emits sigil_applied with the id ────────────────────

func test_sigil_manager_apply_sigil_emits_sigil_applied_signal() -> void:
	var sm: SigilManager = _make_sm()
	var fake := _FakePlayer.new()
	sm.set_player_provider(func() -> Node: return fake)
	var received: Array = []
	sm.sigil_applied.connect(func(id: StringName) -> void: received.append(id))

	sm.apply_sigil(&"dash_cd")

	assert_int(received.size()).is_equal(1)
	assert_str(str(received[0])).is_equal("dash_cd")

	sm.free()
	fake.free()


# ── AC-SM-07: apply_sigil(unknown) does not emit ─────────────────────────────

func test_sigil_manager_apply_unknown_sigil_does_not_emit() -> void:
	var sm: SigilManager = _make_sm()
	var received: Array = []
	sm.sigil_applied.connect(func(id: StringName) -> void: received.append(id))

	sm.apply_sigil(&"not_a_real_sigil")

	assert_int(received.size()).is_equal(0)

	sm.free()


# ── AC-SM-08: reward pool includes Prana sigils ──────────────────────────────

func test_sigil_manager_catalog_includes_prana_cards() -> void:
	var sm: SigilManager = _make_sm()

	var catalog: Array[Dictionary] = sm.get_catalog()

	# Pool = 5 stat sigils + 5 Prana sigils (one per type).
	assert_int(catalog.size()).is_equal(10)
	var prana_ids: Array = []
	for c: Dictionary in catalog:
		if String(c["id"]).begins_with("prana_"):
			prana_ids.append(c["id"])
	assert_int(prana_ids.size()).is_equal(5)

	sm.free()


# ── AC-SM-09: apply Prana sigil adds to the bag and emits ─────────────────────

func test_sigil_manager_apply_prana_card_adds_to_bag() -> void:
	var sm: SigilManager = _make_sm()
	var fake_bag := _FakeBag.new()
	sm.set_bag_provider(func() -> Node: return fake_bag)
	var received: Array = []
	sm.sigil_applied.connect(func(id: StringName) -> void: received.append(id))

	sm.apply_sigil(&"prana_3")

	assert_int(fake_bag.added.size()).is_equal(1)
	assert_int(fake_bag.added[0]).is_equal(3)
	assert_int(received.size()).is_equal(1)
	assert_str(str(received[0])).is_equal("prana_3")

	sm.free()
	fake_bag.free()


# ── Helpers ──────────────────────────────────────────────────────────────────

func _unique_count(arr: Array) -> int:
	var seen: Array = []
	for v in arr:
		if not seen.has(v):
			seen.append(v)
	return seen.size()
