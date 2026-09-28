## duo_swap_test.gd — Ayden and Faith, the swappable brothers (ADR-0058,
## design/gdd/duo-swap.md).
##
## Covers the swap state (cooldown, tag-in i-frames, Perfect Swap once per swap), the
## per-brother rules (grid hands, damage, range), palm faces, Link Reactions and the
## heartbeat Resonance in SpellCastingEffects, PlayerController's swap, and the HUD duo row. Expected values
## come from assets/data/duo_tuning.tres so the tests follow the knobs.
extends GdUnitTestSuite

const SCEScript = preload("res://src/systems/spell_casting_effects.gd")
const HealthAndDamageScript = preload("res://src/systems/health_and_damage.gd")
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


## A player stand-in that reports Ayden's or Faith's incoming damage multiplier.
class MockBrother extends Node:
	var character: int = DuoSwap.Character.AYDEN

	func get_incoming_damage_mult() -> float:
		return DuoSwap.damage_taken_mult(character)


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


## Gives the wave two faces: Ayden casts Deepfrost (palm), Faith the Voidblue grid.
func _give_faces() -> void:
	var base: SpellEffect = _sce._base_spell_effect
	var ayden := SpellEffect.new()
	ayden.primary_type = 3  # Deepfrost
	ayden.primary_tier = 1
	ayden.combo_attack_count = 1
	ayden.base_damage_modifier = 1.0
	base.faces = {AYDEN: ayden, FAITH: base}


func test_swap_switches_to_the_brothers_face() -> void:
	_make_sce()
	_give_faces()
	var faces: Array = []
	_sce.face_changed.connect(func(se: SpellEffect) -> void: faces.append(se.primary_type))
	_sce.set_active_character(AYDEN, false)
	assert_int(_sce.get_cached_spell_effect().primary_type).is_equal(3)
	_sce.set_active_character(FAITH, true)
	assert_int(_sce.get_cached_spell_effect().primary_type).is_equal(1)
	assert_array(faces).contains_exactly([3, 1])


func test_link_reaction_fires_when_the_other_brother_hits_a_marked_enemy() -> void:
	_make_sce()
	_give_faces()
	var links: Array = []
	_sce.link_reaction.connect(func(n: String, _p: Vector2, c: int) -> void: links.append([n, c]))
	_sce.set_active_character(AYDEN, false)
	_sce._trigger_cast()  # leaves Deepfrost
	assert_array(links).is_empty()
	_sce._cast_lock_timer = 0.0
	_sce.set_active_character(FAITH, true)
	var hits_before: int = _hd.amounts.size()
	_sce._trigger_cast()  # Voidblue on Deepfrost
	var expected: ReactionDef = CombinationResolution.get_reaction(3, 1)
	assert_array(links).contains_exactly([[expected.name, FAITH]])
	# The cast's own hit plus the burst on the target.
	assert_int(_hd.amounts.size()).is_equal(hits_before + 2)
	assert_float(_hd.amounts[hits_before + 1]).is_equal_approx(
		SCEScript.BASE_SPELL_DAMAGE * T.link_damage_mult, 0.001)


func test_same_element_on_both_brothers_does_not_react() -> void:
	_make_sce()  # no faces: both brothers cast Voidblue
	var links: Array = []
	_sce.link_reaction.connect(func(n: String, _p: Vector2, _c: int) -> void: links.append(n))
	_sce.set_active_character(AYDEN, false)
	_sce._trigger_cast()
	_sce._cast_lock_timer = 0.0
	_sce.set_active_character(FAITH, true)
	_sce._trigger_cast()
	assert_array(links).is_empty()


func test_the_same_brother_hitting_again_does_not_react() -> void:
	_make_sce()
	_give_faces()
	var links: Array = []
	_sce.link_reaction.connect(func(n: String, _p: Vector2, _c: int) -> void: links.append(n))
	_sce.set_active_character(AYDEN, false)
	_sce._trigger_cast()
	_sce._cast_lock_timer = 0.0
	_sce._trigger_cast()
	assert_array(links).is_empty()


func test_link_mark_expires_after_link_mark_sec() -> void:
	_make_sce()
	_give_faces()
	var links: Array = []
	_sce.link_reaction.connect(func(n: String, _p: Vector2, _c: int) -> void: links.append(n))
	_sce.set_active_character(AYDEN, false)
	_sce._trigger_cast()
	_sce._cast_lock_timer = 0.0
	_sce._duo_clock += T.link_mark_sec + 0.1
	_sce.set_active_character(FAITH, true)
	_sce._trigger_cast()
	assert_array(links).is_empty()


func test_resonance_makes_the_next_hit_react_with_the_benched_element() -> void:
	_make_sce()
	_give_faces()
	var links: Array = []
	_sce.link_reaction.connect(func(n: String, _p: Vector2, _c: int) -> void: links.append(n))
	_sce.set_active_character(AYDEN, false)
	_sce.set_active_character(FAITH, true, true)
	assert_bool(_sce.has_free_perfect()).is_true()
	assert_bool(_sce.is_resonance_pending()).is_true()
	assert_float(_sce.get_special_meter()).is_equal_approx(T.resonance_meter_gain, 0.001)
	_sce._trigger_cast()  # no mark yet: reacts with Ayden's Deepfrost
	assert_array(links).contains_exactly([CombinationResolution.get_reaction(3, 1).name])
	assert_bool(_sce.is_resonance_pending()).is_false()


func test_preparation_clears_link_marks_and_resonance() -> void:
	_make_sce()
	_give_faces()
	_sce.set_active_character(AYDEN, false)
	_sce._trigger_cast()
	_sce.set_active_character(FAITH, true, true)
	_sce._on_preparation_started(0, 0)
	assert_bool(_sce.is_resonance_pending()).is_false()
	assert_int(_sce._link_marks.size()).is_equal(0)
	assert_object(_sce.get_cached_spell_effect()).is_null()


# ── Palm faces ───────────────────────────────────────────────────────────────

func test_face_puts_the_palm_prana_in_the_centre() -> void:
	var grid: Array = [null, null, null, 0, 1, 3, null, null, null]
	assert_array(DuoSwap.face(grid, AYDEN)).is_equal([null, null, null, 1, 0, 3, null, null, null])
	assert_array(DuoSwap.face(grid, FAITH)).is_equal([null, null, null, 0, 3, 1, null, null, null])
	assert_array(grid).is_equal([null, null, null, 0, 1, 3, null, null, null])  # untouched


func test_empty_palm_keeps_the_centre() -> void:
	var grid: Array = [null, null, null, null, 1, 3, null, null, null]
	assert_array(DuoSwap.face(grid, AYDEN)).is_equal(grid)
	assert_int(DuoSwap.core_type(grid, AYDEN)).is_equal(1)
	assert_int(DuoSwap.core_type(grid, FAITH)).is_equal(3)
	assert_int(DuoSwap.core_type(grid, DuoSwap.NONE)).is_equal(1)


func test_combat_resolution_gives_each_brother_his_face() -> void:
	var fragments: Array = []
	fragments.resize(9)
	for pair: Array in [[3, 3], [4, 1]]:  # Deepfrost in Ayden's palm, Voidblue centre
		var f := PranaFragment.new()
		f.type_id = pair[1]
		fragments[pair[0]] = f
	var effect: SpellEffect = CombinationResolution._resolve(fragments)
	CombinationResolution._attach_faces(effect, fragments)
	assert_int(effect.primary_type).is_equal(1)
	assert_int((effect.faces[AYDEN] as SpellEffect).primary_type).is_equal(3)
	assert_object(effect.faces[FAITH]).is_same(effect)


func test_prep_preview_names_both_cores_and_their_link() -> void:
	var names: Array = ["Ashfire", "Voidblue", "Stormgold", "Deepfrost", "Verdant"]
	var line: String = SpellPreview.duo_line(3, 1, "Whiteout", names, COPY)
	assert_str(line).is_equal(COPY.duo_cores_format % ["Deepfrost", "Voidblue"]
		+ COPY.duo_link_format % "Whiteout")
	assert_str(SpellPreview.duo_line(1, 1, "", names, COPY)).is_equal(
		COPY.duo_cores_format % ["Voidblue", "Voidblue"])
	assert_str(SpellPreview.duo_line(-1, -1, "", names, COPY)).is_empty()


# ── Heartbeat ────────────────────────────────────────────────────────────────

func test_swap_on_the_heartbeat_resonates() -> void:
	var duo := DuoSwap.new()
	duo.tick(T.heartbeat_sec)
	assert_bool(duo.try_swap()).is_true()
	assert_bool(duo.last_swap_resonant()).is_true()


func test_swap_between_beats_does_not_resonate() -> void:
	var duo := DuoSwap.new()
	duo.tick(T.heartbeat_sec * 0.5)
	assert_bool(duo.try_swap()).is_true()
	assert_bool(duo.last_swap_resonant()).is_false()


func test_beat_distance_is_symmetric_around_the_beat() -> void:
	var early: float = T.heartbeat_sec - 0.1
	assert_float(DuoSwap.beat_distance(early)).is_equal_approx(0.1, 0.0001)
	assert_float(DuoSwap.beat_distance(T.heartbeat_sec + 0.1)).is_equal_approx(0.1, 0.0001)


func test_player_resonance_signal_on_a_beat_swap() -> void:
	var pc := _make_pc()
	pc._on_combat_started(false)
	var res: Array = []
	pc.resonated.connect(func(p: Vector2) -> void: res.append(p))
	pc._duo.tick(T.heartbeat_sec)
	assert_bool(pc.try_swap()).is_true()
	assert_int(res.size()).is_equal(1)
	_free_pc(pc)


func test_duo_row_glows_on_the_beat() -> void:
	assert_float(CombatHUD.heartbeat_alpha(0.0)).is_equal_approx(1.0, 0.0001)
	assert_float(CombatHUD.heartbeat_alpha(0.5)).is_equal_approx(0.55, 0.0001)
	assert_float(CombatHUD.heartbeat_alpha(0.95)).is_greater(0.9)


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


# ── Only Faith dashes ────────────────────────────────────────────────────────

func test_only_faith_can_dash() -> void:
	assert_bool(DuoSwap.can_dash(AYDEN)).is_false()
	assert_bool(DuoSwap.can_dash(FAITH)).is_true()
	assert_bool(DuoSwap.can_dash(DuoSwap.NONE)).is_true()


func test_dash_as_ayden_is_blocked_and_as_faith_dashes() -> void:
	var added: bool = not InputMap.has_action(&"dash")
	if added:
		InputMap.add_action(&"dash")
	var pc := _make_pc()
	pc._on_combat_started(false)
	var blocked: Array = []
	pc.dash_blocked.connect(func(p: Vector2) -> void: blocked.append(p))
	Input.action_press(&"dash")
	pc._physics_process(0.016)
	Input.action_release(&"dash")
	assert_int(blocked.size()).is_equal(1)
	assert_bool(pc.is_dashing()).is_false()
	assert_int(pc.get_dash_charges()).is_equal(pc.get_max_dash_charges())
	pc.set_active_character(FAITH)
	Input.action_press(&"dash")
	pc._physics_process(0.016)
	Input.action_release(&"dash")
	assert_bool(pc.is_dashing()).is_true()
	assert_int(blocked.size()).is_equal(1)
	_free_pc(pc)
	if added:
		InputMap.erase_action(&"dash")


func test_assist_auto_dash_swaps_ayden_out_instead() -> void:
	var pc := _make_pc()
	pc._on_combat_started(false)
	pc.auto_dash = true
	assert_bool(pc.try_auto_dash()).is_true()
	assert_int(pc.get_active_character()).is_equal(FAITH)
	assert_bool(pc.is_invincible()).is_true()
	assert_int(pc.get_dash_charges()).is_equal(pc.get_max_dash_charges())
	_free_pc(pc)


# ── Ayden is sturdy ──────────────────────────────────────────────────────────

func test_ayden_takes_less_damage_and_faith_takes_it_all() -> void:
	var hd: Node = HealthAndDamageScript.new()
	hd.set_process(false)
	var brother := MockBrother.new()
	brother.add_to_group(&"player")
	add_child(hd)
	add_child(brother)
	hd._fayde_current_hp = 100
	hd.apply_damage(brother, 20.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.DIRECT)
	assert_int(hd._fayde_current_hp).is_equal(100 - roundi(20.0 * T.ayden_damage_taken_mult))
	brother.character = FAITH
	hd._fayde_current_hp = 100
	hd.apply_damage(brother, 20.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.DIRECT)
	assert_int(hd._fayde_current_hp).is_equal(80)
	remove_child(hd)
	remove_child(brother)
	hd.free()
	brother.free()


func test_ayden_is_not_knocked_back_and_faith_is() -> void:
	var pc := _make_pc()
	pc._on_combat_started(false)
	pc.request_knockback(pc.global_position + Vector2.LEFT * 10.0, 200.0)
	assert_float(pc.velocity.length()).is_equal_approx(200.0 * T.ayden_knockback_mult, 0.001)
	pc.set_active_character(FAITH)
	pc.request_knockback(pc.global_position + Vector2.LEFT * 10.0, 200.0)
	assert_float(pc.velocity.length()).is_equal_approx(200.0, 0.001)
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
	assert_str(text).is_equal(COPY.duo_row_format % ["AYDEN", "Q"])


func test_duo_row_shows_the_cooldown_while_waiting() -> void:
	var text: String = CombatHUD.duo_row_text(FAITH, 0.5, "Q")
	assert_str(text).is_equal(COPY.duo_row_cooldown_format % ["FAITH", 0.5])


# ── Sprites (DuoLooks) ───────────────────────────────────────────────────────

func test_each_brother_has_his_own_sheets_on_fayde_rig() -> void:
	var a: Dictionary = DuoLooks.for_character(AYDEN)
	var f: Dictionary = DuoLooks.for_character(FAITH)
	assert_object(a["sheet"]).is_not_same(f["sheet"])
	assert_object(DuoLooks.for_character(DuoSwap.NONE)["sheet"]).is_same(DuoLooks.FAYDE["sheet"])
	# Same cell layout as Fayde, so PixelCharacter and CrumplePose need no other change.
	for key: String in ["sheet", "glow", "casts", "casts_glow", "crumple", "crumple_glow"]:
		var fayde_tex: Texture2D = DuoLooks.FAYDE[key]
		for look: Dictionary in [a, f]:
			var tex: Texture2D = look[key]
			assert_vector(tex.get_size()).is_equal(fayde_tex.get_size())


func test_swap_puts_the_brothers_sprite_on_the_player() -> void:
	var pc: PlayerController = PlayerControllerScript.new() as PlayerController
	var pixel := PixelCharacter.new()
	pixel.name = "PixelCharacter"
	pc.add_child(pixel)
	add_child(pc)
	pc._on_combat_started(false)
	assert_object(pixel.sheet).is_same(DuoLooks.AYDEN["sheet"])
	pc.try_swap()
	assert_object(pixel.sheet).is_same(DuoLooks.FAITH["sheet"])
	assert_object(pixel.cast_sheet).is_same(DuoLooks.FAITH["casts"])
	_free_pc(pc)


func test_crumple_shows_the_fallen_brother() -> void:
	var crumple := CrumplePose.new()
	crumple.set_character(FAITH)
	assert_object(crumple._body.texture).is_same(DuoLooks.FAITH["crumple"])
	crumple.free()
