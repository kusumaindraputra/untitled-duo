## duo_swap_test.gd — Ayden and Faith, the swappable brothers (ADR-0058,
## design/gdd/duo-swap.md).
##
## Covers the swap state (cooldown, tag-in i-frames, Perfect Swap once per swap), the
## per-brother rules (grid hands, damage, range), the hand-off bonuses in
## SpellCastingEffects, PlayerController's swap, and the HUD duo row. Expected values
## come from assets/data/duo_tuning.tres so the tests follow the knobs.
extends GdUnitTestSuite

const SCEScript = preload("res://src/systems/spell_casting_effects.gd")
const PlayerControllerScript: GDScript = preload("res://src/gameplay/player_controller.gd")
const T: DuoTuning = preload("res://assets/data/duo_tuning.tres")
const COPY: UICopy = preload("res://assets/data/ui_copy.tres")

const AYDEN: DuoSwap.Character = DuoSwap.Character.AYDEN
const FAITH: DuoSwap.Character = DuoSwap.Character.FAITH


class MockHealthAndDamage:
	var amounts: Array[float] = []

	func apply_damage(_target: Node, amount: float, _element: GameEnums.DamageClass, _source: GameEnums.DamageSource) -> void:
		amounts.append(amount)

	func apply_heal(_target: Node, _amount: float) -> void:
		pass


class MockStatusEffects:
	var durations: Array[float] = []
	## When true, every enemy reads as carrying a status (Faith's setup).
	var has_any: bool = false

	func apply_status(_target: Node, _status: GameEnums.BaseStatus, duration: float, _base: float = 0.0) -> void:
		durations.append(duration)

	func has_status(_target: Node, status: GameEnums.BaseStatus) -> bool:
		return has_any and status == GameEnums.BaseStatus.FREEZE

	func check_and_apply_shatter(_target: Node, base_damage: float) -> float:
		return base_damage


class MockEnemy extends Node2D:
	func is_alive() -> bool: return true
	func apply_speed_modifier(_mult: float) -> void: pass
	func apply_stun(_duration: float) -> void: pass
	func apply_knockback(_direction: Vector2, _distance: float) -> void: pass


# ── Swap state ───────────────────────────────────────────────────────────────

func test_swap_starts_with_ayden_and_flips_to_faith() -> void:
	var duo := DuoSwap.new()
	assert_int(duo.active()).is_equal(AYDEN)
	assert_bool(duo.try_swap()).is_true()
	assert_int(duo.active()).is_equal(FAITH)


func test_swap_on_cooldown_is_ignored() -> void:
	var duo := DuoSwap.new()
	duo.try_swap()
	assert_bool(duo.try_swap()).is_false()
	assert_int(duo.active()).is_equal(FAITH)
	duo.tick(T.swap_cooldown_sec + 0.01)
	assert_bool(duo.try_swap()).is_true()
	assert_int(duo.active()).is_equal(AYDEN)


func test_touching_hands_shorten_the_cooldown() -> void:
	var duo := DuoSwap.new()
	duo.try_swap(true)
	assert_float(duo.cooldown_remaining()).is_equal_approx(
		T.swap_cooldown_sec * T.touch_swap_cooldown_mult, 0.0001)


func test_tag_in_iframes_last_swap_iframe_sec() -> void:
	var duo := DuoSwap.new()
	duo.try_swap()
	assert_bool(duo.is_tagging_in()).is_true()
	duo.tick(T.swap_iframe_sec + 0.01)
	assert_bool(duo.is_tagging_in()).is_false()


func test_perfect_swap_counts_once_per_swap_and_only_while_tagging_in() -> void:
	var duo := DuoSwap.new()
	assert_bool(duo.try_count_perfect()).is_false()
	duo.try_swap()
	assert_bool(duo.try_count_perfect()).is_true()
	assert_bool(duo.try_count_perfect()).is_false()


func test_reset_timers_keeps_the_brother_and_clears_cooldown() -> void:
	var duo := DuoSwap.new()
	duo.try_swap()
	duo.reset_timers()
	assert_int(duo.active()).is_equal(FAITH)
	assert_bool(duo.can_swap()).is_true()
	assert_bool(duo.is_tagging_in()).is_false()


# ── Rules ────────────────────────────────────────────────────────────────────

func test_each_grid_hand_powers_only_its_brother() -> void:
	assert_float(DuoSwap.power_hand(AYDEN, 1.2)).is_equal(1.2)
	assert_float(DuoSwap.power_hand(FAITH, 1.2)).is_equal(1.0)
	assert_float(DuoSwap.control_hand(FAITH, 1.5)).is_equal(1.5)
	assert_float(DuoSwap.control_hand(AYDEN, 1.5)).is_equal(1.0)


func test_no_duo_keeps_the_pre_duo_numbers() -> void:
	assert_float(DuoSwap.power_hand(DuoSwap.NONE, 1.2)).is_equal(1.2)
	assert_float(DuoSwap.control_hand(DuoSwap.NONE, 1.5)).is_equal(1.5)
	assert_float(DuoSwap.damage_mult(DuoSwap.NONE)).is_equal(1.0)
	assert_float(DuoSwap.range_mult(DuoSwap.NONE)).is_equal(1.0)
	assert_float(DuoSwap.speed_mult(DuoSwap.NONE)).is_equal(1.0)


func test_ayden_is_short_and_heavy_faith_is_long_and_light() -> void:
	assert_float(DuoSwap.damage_mult(AYDEN)).is_greater(DuoSwap.damage_mult(FAITH))
	assert_float(DuoSwap.range_mult(FAITH)).is_greater(DuoSwap.range_mult(AYDEN))


# ── Combat (SpellCastingEffects) ─────────────────────────────────────────────

var _hd: MockHealthAndDamage
var _sem: MockStatusEffects
var _sce: Node
var _target: MockEnemy
var _fayde: Node2D


func _make_sce() -> void:
	_hd = MockHealthAndDamage.new()
	_sem = MockStatusEffects.new()
	_fayde = Node2D.new()
	add_child(_fayde)
	_target = MockEnemy.new()
	_target.position = Vector2(10, 0)
	add_child(_target)
	_sce = SCEScript.new()
	_sce._health_and_damage = _hd
	_sce._status_effects = _sem
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	_sce._rng = rng
	add_child(_sce)
	_sce.set_process(false)
	_sce._fayde_ref = _fayde
	var enemies: Array[Node] = [_target]
	_sce._get_enemies = func() -> Array[Node]: return enemies
	_sce._on_combat_started(false)
	var se := SpellEffect.new()
	se.primary_type = 1  # Voidblue: Blind, no crit roll
	se.primary_tier = 1
	se.combo_attack_count = 1
	se.base_damage_modifier = 0.9
	se.hand_power_mult = 1.2
	se.hand_control_mult = 1.5
	_sce._on_combo_resolved(se)
	_sce._override_target = _target


func after_test() -> void:
	for n: Node in [_sce, _target, _fayde]:
		if is_instance_valid(n):
			if n.is_inside_tree():
				remove_child(n)
			n.free()
	_sce = null
	_target = null
	_fayde = null


## Casts once with [param c] active (no swap) and returns [damage, status duration].
func _cast_as(c: int) -> Array:
	_make_sce()
	_sce.set_active_character(c, false)
	_sce._trigger_cast()
	return [_hd.amounts[0], _sem.durations[0]]


func test_ayden_gets_his_hand_and_weight_but_not_faiths_hand() -> void:
	var plain: Array = _cast_as(DuoSwap.NONE)
	after_test()
	var ayden: Array = _cast_as(AYDEN)
	# NONE applies both hands; Ayden keeps the power hand, loses the control hand.
	assert_float(ayden[0]).is_equal_approx(plain[0] * T.ayden_damage_mult, 0.001)
	assert_float(ayden[1]).is_equal_approx(plain[1] / 1.5, 0.001)


func test_faith_gets_her_hand_but_not_ayden_power_hand() -> void:
	var plain: Array = _cast_as(DuoSwap.NONE)
	after_test()
	var faith: Array = _cast_as(FAITH)
	assert_float(faith[0]).is_equal_approx(plain[0] / 1.2 * T.faith_damage_mult, 0.001)
	assert_float(faith[1]).is_equal_approx(plain[1], 0.001)


func test_ayden_handoff_hits_harder_on_a_status_and_only_once() -> void:
	_make_sce()
	_sem.has_any = true
	_sce.set_active_character(AYDEN, true)
	assert_bool(_sce.is_handoff_open()).is_true()
	var paid: Array = []
	_sce.handoff_hit.connect(func(_p: Vector2, c: int) -> void: paid.append(c))
	_sce._trigger_cast()
	_sce._cast_lock_timer = 0.0
	_sce._trigger_cast()
	assert_float(_hd.amounts[0]).is_equal_approx(_hd.amounts[1] * T.handoff_damage_mult, 0.001)
	assert_bool(_sce.is_handoff_open()).is_false()
	assert_array(paid).contains_exactly([AYDEN])


func test_ayden_without_a_status_gets_no_handoff_bonus() -> void:
	_make_sce()
	_sce.set_active_character(AYDEN, true)
	_sce._trigger_cast()
	_sce._cast_lock_timer = 0.0
	_sce._trigger_cast()
	assert_float(_hd.amounts[0]).is_equal_approx(_hd.amounts[1], 0.001)


func test_faith_handoff_holds_longer_on_an_enemy_ayden_just_hit() -> void:
	_make_sce()
	_sce.set_active_character(AYDEN, false)
	_sce._trigger_cast()
	_sce._cast_lock_timer = 0.0
	_sce.set_active_character(FAITH, true)
	_sce._trigger_cast()  # hand-off: marked by Ayden
	_sce._cast_lock_timer = 0.0
	_sce._trigger_cast()  # window spent
	assert_float(_sem.durations[1]).is_equal_approx(_sem.durations[2] * T.handoff_status_mult, 0.001)


func test_ayden_mark_expires_after_ayden_mark_sec() -> void:
	_make_sce()
	_sce.set_active_character(AYDEN, false)
	_sce._trigger_cast()
	_sce._cast_lock_timer = 0.0
	_sce._duo_clock += T.ayden_mark_sec + 0.1
	_sce.set_active_character(FAITH, true)
	_sce._trigger_cast()
	_sce._cast_lock_timer = 0.0
	_sce._trigger_cast()
	assert_float(_sem.durations[1]).is_equal_approx(_sem.durations[2], 0.001)


func test_preparation_closes_the_handoff_window() -> void:
	_make_sce()
	_sce.set_active_character(AYDEN, true)
	_sce._on_preparation_started(0, 0)
	assert_bool(_sce.is_handoff_open()).is_false()


# ── PlayerController ─────────────────────────────────────────────────────────

func _make_pc() -> PlayerController:
	var pc: PlayerController = PlayerControllerScript.new() as PlayerController
	add_child(pc)
	return pc


func _free_pc(pc: PlayerController) -> void:
	remove_child(pc)
	pc.free()


func test_player_cannot_swap_outside_combat() -> void:
	var pc := _make_pc()
	assert_bool(pc.try_swap()).is_false()
	assert_int(pc.get_active_character()).is_equal(AYDEN)
	_free_pc(pc)


func test_player_swap_tags_in_faith_with_iframes_and_tells_combat() -> void:
	var pc := _make_pc()
	pc._on_combat_started(false)
	var swaps: Array = []
	pc.character_swapped.connect(func(c: int, _cd: float) -> void: swaps.append(c))
	assert_bool(pc.try_swap()).is_true()
	assert_int(pc.get_active_character()).is_equal(FAITH)
	assert_int(SpellCastingEffects.get_active_character()).is_equal(FAITH)
	assert_bool(pc.is_invincible()).is_true()
	assert_float(pc.get_swap_cooldown_remaining()).is_equal_approx(T.swap_cooldown_sec, 0.0001)
	assert_array(swaps).contains_exactly([FAITH])
	_free_pc(pc)
	assert_int(SpellCastingEffects.get_active_character()).is_equal(DuoSwap.NONE)


func test_hit_during_tag_in_is_a_perfect_swap_once() -> void:
	var pc := _make_pc()
	pc._on_combat_started(false)
	var perfect: Array = []
	pc.perfect_swapped.connect(func(p: Vector2) -> void: perfect.append(p))
	var dodged: Array = []
	pc.perfect_dodged.connect(func(p: Vector2) -> void: dodged.append(p))
	pc.try_swap()
	assert_bool(pc.register_perfect_dodge(Vector2.ZERO)).is_true()
	assert_bool(pc.register_perfect_dodge(Vector2.ZERO)).is_false()
	assert_int(perfect.size()).is_equal(1)
	assert_int(dodged.size()).is_equal(1)
	_free_pc(pc)


func test_faith_dash_cuts_bullets_and_ayden_dash_does_not() -> void:
	var pc := _make_pc()
	pc._on_combat_started(false)
	assert_float(pc.get_dash_cut_radius()).is_equal(0.0)
	pc.try_swap()
	assert_float(pc.get_dash_cut_radius()).is_equal(T.faith_dash_cut_radius)
	_free_pc(pc)


func test_preparation_resets_the_swap_cooldown() -> void:
	var pc := _make_pc()
	pc._on_combat_started(false)
	pc.try_swap()
	pc._on_preparation_started(0, 0)
	assert_float(pc.get_swap_cooldown_remaining()).is_equal(0.0)
	assert_int(pc.get_active_character()).is_equal(FAITH)
	_free_pc(pc)


# ── HUD ──────────────────────────────────────────────────────────────────────

func test_duo_row_shows_the_swap_key_when_ready() -> void:
	var text: String = CombatHUD.duo_row_text(AYDEN, 0.0, "Q")
	assert_str(text).is_equal(COPY.duo_row_format % ["AYDEN", "Q", "FAITH"])


func test_duo_row_shows_the_cooldown_while_waiting() -> void:
	var text: String = CombatHUD.duo_row_text(FAITH, 0.5, "Q")
	assert_str(text).is_equal(COPY.duo_row_cooldown_format % ["FAITH", "AYDEN", 0.5])
