## cipher_core_test.gd — Cipher Cores (ADR-0033).
##
## Coverage:
##   AC-CC-01: the roster lists Steady first; an unknown id resolves to it
##   AC-CC-02: every Core has copy in UICopy and a unique id
##   AC-CC-03: apply() calls only the hooks a Core changes; Steady changes nothing
##   AC-CC-04: apply() sets the sigil offer size and free rerolls
##   AC-CC-05: a damage share above 1.0 (Glass Core) raises damage Fayde takes
##   AC-CC-06: MetaProgress.last_core survives save/load; old saves default to empty
##   AC-CC-07: SpellCastingEffects.reset_run_damage_mult() clears the run multiplier
##   AC-CC-08: the run scene script (core-pick screen) compiles
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const ROSTER: CoreRoster = preload("res://assets/data/cores/core_roster.tres")
const COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const SigilManagerScript = preload("res://src/systems/sigil_manager.gd")
const HealthAndDamageScript = preload("res://src/systems/health_and_damage.gd")
const _PATH: String = "user://test_progress_cores.cfg"


## Records the hooks a Core calls on the player.
class _FakePlayer extends Node:
	var speed_calls: Array[float] = []
	var dash_calls: Array[int] = []
	func apply_move_speed_mult(factor: float) -> void:
		speed_calls.append(factor)
	func add_dash_charges(count: int) -> void:
		dash_calls.append(count)


## Records spell-damage multipliers.
class _FakeSpells extends RefCounted:
	var mults: Array[float] = []
	func apply_damage_mult(factor: float) -> void:
		mults.append(factor)


func after_test() -> void:
	if FileAccess.file_exists(_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_PATH))


func _core(id: StringName) -> CoreFrame:
	return ROSTER.get_core(id)


func test_cipher_core_roster_default_is_steady() -> void:
	assert_int(ROSTER.cores.size()).is_greater_equal(4)
	assert_str(String(ROSTER.default_core().id)).is_equal("steady")
	assert_str(String(ROSTER.get_core(&"no_such_core").id)).is_equal("steady")
	assert_str(String(ROSTER.get_core(&"glass").id)).is_equal("glass")


func test_cipher_core_every_core_has_copy_and_unique_id() -> void:
	var seen: Dictionary = {}
	for v: Variant in ROSTER.cores:
		var c: CoreFrame = v as CoreFrame
		assert_object(c).is_not_null()
		assert_bool(seen.has(c.id)).is_false()
		seen[c.id] = true
		assert_bool(COPY.core_titles.has(String(c.id))).is_true()
		assert_bool(COPY.core_descs.has(String(c.id))).is_true()


func test_cipher_core_steady_changes_nothing() -> void:
	var player := _FakePlayer.new()
	var spells := _FakeSpells.new()
	var sm: SigilManager = SigilManagerScript.new()
	var cards_before: int = sm.offer_cards

	_core(&"steady").apply(player, spells, sm)

	assert_array(player.speed_calls).is_empty()
	assert_array(player.dash_calls).is_empty()
	assert_array(spells.mults).is_empty()
	assert_int(sm.offer_cards).is_equal(cards_before)
	assert_int(sm.free_rerolls_per_offer).is_equal(0)
	assert_float(_core(&"steady").damage_taken_mult).is_equal_approx(1.0, 0.0001)
	player.free()
	sm.free()


func test_cipher_core_gale_calls_player_and_spell_hooks() -> void:
	var gale: CoreFrame = _core(&"gale")
	var player := _FakePlayer.new()
	var spells := _FakeSpells.new()

	gale.apply(player, spells, null)

	assert_array(player.speed_calls).is_equal([gale.move_speed_mult])
	assert_array(player.dash_calls).is_equal([gale.bonus_dash_charges])
	assert_array(spells.mults).is_equal([gale.spell_damage_mult])
	player.free()


func test_cipher_core_echo_sets_offer_and_free_rerolls() -> void:
	var echo: CoreFrame = _core(&"echo")
	var sm: SigilManager = SigilManagerScript.new()

	echo.apply(null, null, sm)

	assert_int(sm.offer_cards).is_equal(echo.offer_cards)
	assert_int(sm.free_rerolls_per_offer).is_equal(echo.free_rerolls_per_offer)
	sm.begin_screen()
	assert_int(sm.reroll_cost()).is_equal(0)
	sm.free()


func test_cipher_core_glass_share_raises_damage_taken() -> void:
	var hd: Node = HealthAndDamageScript.new()
	hd.set_process(false)
	var fayde := Node.new()
	fayde.add_to_group(&"player")
	add_child(hd)
	add_child(fayde)
	hd._fayde_current_hp = 100
	hd.player_damage_mult = _core(&"glass").damage_taken_mult  # 1.25

	hd.apply_damage(fayde, 20.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT)

	assert_int(hd._fayde_current_hp).is_equal(75)
	remove_child(hd)
	remove_child(fayde)
	hd.free()
	fayde.free()


func test_cipher_core_last_core_round_trip() -> void:
	var p := MetaProgress.new()
	p.last_core = &"gale"
	p.save_to(_PATH)

	assert_str(String(MetaProgress.load_from(_PATH).last_core)).is_equal("gale")
	assert_str(String(MetaProgress.new().last_core)).is_equal("")


func test_cipher_core_run_damage_mult_resets() -> void:
	var before: float = SpellCastingEffects.get_damage_mult()
	SpellCastingEffects.apply_damage_mult(1.3)

	SpellCastingEffects.reset_run_damage_mult()

	assert_float(SpellCastingEffects.get_damage_mult()).is_equal_approx(1.0, 0.0001)
	SpellCastingEffects._run_damage_mult = before


func test_cipher_core_run_scene_script_compiles() -> void:
	# The core-pick screen lives in the run scene script, which no other suite loads.
	var script: GDScript = load("res://src/scenes/debug_game_loop.gd") as GDScript
	assert_object(script).is_not_null()
	assert_bool(script.can_instantiate()).is_true()
