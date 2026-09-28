## duo_link_test.gd — the duo's second layer (ADR-0058, design/gdd/duo-swap.md):
## Link Burst Special, the severed link of the Cipher Keeper, duo sigils (Wide Link,
## Deep Heartbeat, Echo Brother), and duo style + run log counts. Expected values come
## from the shipped tuning resources so the tests follow the knobs.
extends GdUnitTestSuite

const SCEScript = preload("res://src/systems/spell_casting_effects.gd")
const PlayerControllerScript: GDScript = preload("res://src/gameplay/player_controller.gd")
const T: DuoTuning = preload("res://assets/data/duo_tuning.tres")
const ATTACK: AttackTuning = preload("res://assets/data/attack_tuning.tres")
const PACE: PaceTuning = preload("res://assets/data/pace_tuning.tres")
const SIGILS: SigilConfig = preload("res://assets/data/sigil_config.tres")
const COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const ROSTER: BossRoster = preload("res://assets/data/bosses/boss_roster.tres")

const AYDEN: DuoSwap.Character = DuoSwap.Character.AYDEN
const FAITH: DuoSwap.Character = DuoSwap.Character.FAITH
const KEEPER_TYPE_ID: int = 11


class MockHealthAndDamage:
	var amounts: Array[float] = []

	func apply_damage(_target: Node, amount: float, _element: GameEnums.DamageClass, _source: GameEnums.DamageSource) -> void:
		amounts.append(amount)

	func apply_heal(_target: Node, _amount: float) -> void:
		pass


class MockStatusEffects:
	var durations: Array[float] = []

	func apply_status(_target: Node, _status: GameEnums.BaseStatus, duration: float, _base: float = 0.0) -> void:
		durations.append(duration)

	func has_status(_target: Node, _status: GameEnums.BaseStatus) -> bool:
		return false

	func check_and_apply_shatter(_target: Node, base_damage: float) -> float:
		return base_damage


class MockEnemy extends Node2D:
	var pulls: int = 0
	func is_alive() -> bool: return true
	func apply_speed_modifier(_mult: float) -> void: pass
	func apply_stun(_duration: float) -> void: pass
	func apply_knockback(_direction: Vector2, _distance: float) -> void: pulls += 1


var _hd: MockHealthAndDamage
var _sem: MockStatusEffects
var _sce: Node
var _target: MockEnemy
var _fayde: Node2D


## An SCE on a Voidblue wave with one enemy 10 px from Fayde.
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
	se.primary_type = 1  # Voidblue
	se.primary_tier = 1
	se.combo_attack_count = 1
	se.base_damage_modifier = 0.9
	_sce._on_combo_resolved(se)
	_sce._override_target = _target


## Ayden's face is Deepfrost (palm), Faith keeps the Voidblue grid.
func _give_faces() -> void:
	var base: SpellEffect = _sce._base_spell_effect
	var ayden := SpellEffect.new()
	ayden.primary_type = 3  # Deepfrost
	ayden.primary_tier = 1
	ayden.combo_attack_count = 1
	ayden.base_damage_modifier = 1.0
	base.faces = {AYDEN: ayden, FAITH: base}


func after_test() -> void:
	for n: Node in [_sce, _target, _fayde]:
		if is_instance_valid(n):
			if n.is_inside_tree():
				remove_child(n)
			n.free()
	_sce = null
	_target = null
	_fayde = null


# ── Link Burst ───────────────────────────────────────────────────────────────

func test_link_burst_joins_the_special_when_the_cores_differ() -> void:
	_make_sce()
	_give_faces()
	_sce.set_active_character(FAITH, false)
	_target.position = Vector2(60, 0)  # inside the Special, outside the 24 px pull stop
	var bursts: Array = []
	_sce.link_burst.connect(func(n: String, _p: Vector2, r: float, c: int) -> void: bursts.append([n, r, c]))
	_sce._special_meter = ATTACK.special_meter_max
	var special_damage: float = _sce.get_special_damage()
	_sce._trigger_special()
	var reaction: ReactionDef = CombinationResolution.get_reaction(3, 1)
	assert_array(bursts).contains_exactly([[reaction.name,
		ATTACK.special_radius * T.link_burst_radius_mult, FAITH]])
	# The Special's own hit, then the burst's.
	assert_float(_hd.amounts[_hd.amounts.size() - 1]).is_equal_approx(
		special_damage * T.link_burst_damage_mult, 0.001)
	assert_int(_target.pulls).is_greater(0)  # Voidblue in the pair pulls enemies in


func test_no_link_burst_when_both_brothers_share_a_core() -> void:
	_make_sce()  # no faces: both cast Voidblue
	_sce.set_active_character(FAITH, false)
	var bursts: Array = []
	_sce.link_burst.connect(func(n: String, _p: Vector2, _r: float, _c: int) -> void: bursts.append(n))
	_sce._special_meter = ATTACK.special_meter_max
	_sce._trigger_special()
	assert_array(bursts).is_empty()
	assert_array(_sce.duo_cores()).is_empty()


func test_no_link_burst_without_a_duo() -> void:
	_make_sce()
	_give_faces()
	_sce.set_active_character(DuoSwap.NONE, false)
	assert_array(_sce.duo_cores()).is_empty()


func test_duo_cores_lists_the_active_brother_first() -> void:
	_make_sce()
	_give_faces()
	_sce.set_active_character(AYDEN, false)
	assert_array(_sce.duo_cores()).contains_exactly([3, 1])


func test_swap_announces_the_brother_tagging_in() -> void:
	_make_sce()
	var tagged: Array = []
	_sce.brother_tagged_in.connect(func(c: int) -> void: tagged.append(c))
	_sce.set_active_character(AYDEN, false)
	_sce.set_active_character(FAITH, true)
	assert_array(tagged).contains_exactly([FAITH])


# ── Duo sigils ───────────────────────────────────────────────────────────────

func test_wide_link_widens_link_and_burst_and_resets_with_the_run() -> void:
	_make_sce()
	_sce.apply_link_radius_mult(SIGILS.wide_link_mult)
	assert_float(_sce.get_link_radius()).is_equal_approx(T.link_radius * SIGILS.wide_link_mult, 0.001)
	assert_float(_sce.link_burst_radius()).is_equal_approx(
		ATTACK.special_radius * T.link_burst_radius_mult * SIGILS.wide_link_mult, 0.001)
	_sce.reset_run_damage_mult()
	assert_float(_sce.get_link_radius()).is_equal_approx(T.link_radius, 0.001)


func test_deep_heartbeat_doubles_the_resonance_meter() -> void:
	_make_sce()
	_sce.apply_resonance_meter_mult(SIGILS.deep_heart_meter_mult)
	_sce.set_active_character(FAITH, true, true)
	assert_float(_sce.get_special_meter()).is_equal_approx(
		T.resonance_meter_gain * SIGILS.deep_heart_meter_mult, 0.001)


func test_deep_heartbeat_stretches_the_beat_and_its_window() -> void:
	var duo := DuoSwap.new()
	duo.apply_beat_mult(SIGILS.deep_heart_mult)
	assert_float(duo.heartbeat_period()).is_equal_approx(T.heartbeat_sec * SIGILS.deep_heart_mult, 0.001)
	# Just outside the plain window, but inside the stretched one.
	duo.tick(duo.heartbeat_period() + T.resonance_window_sec * 1.2)
	assert_bool(duo.is_on_beat()).is_true()
	duo.set_beat_mult(1.0)
	assert_float(duo.heartbeat_period()).is_equal_approx(T.heartbeat_sec, 0.001)


func test_beat_distance_uses_the_given_period() -> void:
	assert_float(DuoSwap.beat_distance(1.3, T, 1.4)).is_equal_approx(0.1, 0.0001)


func test_echo_strike_hits_with_the_benched_element_and_sets_up_a_link() -> void:
	_make_sce()
	_give_faces()
	_sce.set_active_character(FAITH, false)
	var links: Array = []
	_sce.link_reaction.connect(func(n: String, _p: Vector2, _c: int) -> void: links.append(n))
	var hit: Node2D = _sce.echo_strike(AYDEN, SIGILS.echo_damage, SIGILS.echo_range)
	assert_object(hit).is_same(_target)
	assert_float(_hd.amounts[0]).is_equal_approx(SIGILS.echo_damage, 0.001)
	_sce._trigger_cast()  # Faith's Voidblue on Ayden's Deepfrost mark
	assert_array(links).contains_exactly([CombinationResolution.get_reaction(3, 1).name])


func test_echo_strike_needs_an_enemy_in_range() -> void:
	_make_sce()
	_give_faces()
	_target.position = Vector2(SIGILS.echo_range + 50.0, 0)
	assert_object(_sce.echo_strike(AYDEN, SIGILS.echo_damage, SIGILS.echo_range)).is_null()
	assert_array(_hd.amounts).is_empty()


func test_duo_sigils_are_in_the_catalog_and_heirlooms() -> void:
	var ids: Array = []
	for entry: Dictionary in SIGILS.sigils:
		ids.append(StringName(entry["id"]))
	for id: StringName in [&"wide_link", &"deep_heart", &"echo_brother"]:
		assert_bool(ids.has(id)).override_failure_message("missing sigil %s" % id).is_true()
	assert_bool(SigilEffects.handles(&"echo_brother")).is_true()
	var meta: MetaTuning = preload("res://assets/data/meta_tuning.tres")
	assert_bool(meta.heirloom_ids.has(&"wide_link")).is_true()
	assert_bool(meta.heirloom_ids.has(&"echo_brother")).is_true()


# ── Severed link (Cipher Keeper) ─────────────────────────────────────────────

func test_severed_link_blocks_swaps_until_enough_hits_land() -> void:
	var duo := DuoSwap.new()
	duo.sever(3)
	assert_bool(duo.try_swap()).is_false()
	assert_bool(duo.note_hit()).is_false()
	assert_bool(duo.note_hit()).is_false()
	assert_int(duo.sever_hits_left()).is_equal(1)
	assert_bool(duo.note_hit()).is_true()
	assert_bool(duo.is_severed()).is_false()
	assert_bool(duo.try_swap()).is_true()
	assert_bool(duo.note_hit()).is_false()  # already linked


func test_preparation_heals_a_severed_link() -> void:
	var duo := DuoSwap.new()
	duo.sever(5)
	duo.reset_timers()
	assert_bool(duo.is_severed()).is_false()


func test_keeper_severs_the_link_in_its_second_phase() -> void:
	var profile: BossProfile = ROSTER.profile_for(KEEPER_TYPE_ID)
	assert_object(profile).is_not_null()
	assert_bool(BossDirector.severs_link(profile, 1)).is_false()
	assert_bool(BossDirector.severs_link(profile, 2)).is_true()
	assert_str(BossDirector.banner_for_phase(profile, 2).to_lower()).contains("separation")


func test_player_reconnects_after_the_hits_and_gets_meter() -> void:
	var pc: PlayerController = PlayerControllerScript.new() as PlayerController
	add_child(pc)
	pc._on_combat_started(false)
	var progress: Array = []
	var relinks: Array = []
	pc.relink_progress.connect(func(left: int) -> void: progress.append(left))
	pc.relinked.connect(func(_p: Vector2) -> void: relinks.append(true))
	pc.sever_link()
	assert_bool(pc.is_link_severed()).is_true()
	assert_bool(pc.try_swap()).is_false()
	var meter_before: float = SpellCastingEffects.get_special_meter()
	for i: int in T.sever_reconnect_hits:
		pc._on_spell_hit_element(null, 1)
	assert_int(progress.size()).is_equal(T.sever_reconnect_hits - 1)
	assert_array(relinks).has_size(1)
	assert_bool(pc.is_link_severed()).is_false()
	assert_float(SpellCastingEffects.get_special_meter()).is_greater_equal(
		minf(meter_before + T.relink_meter_gain, ATTACK.special_meter_max) - 0.001)
	SpellCastingEffects._on_preparation_started(0, 0)
	remove_child(pc)
	pc.free()


func test_duo_row_shows_the_hits_left_while_severed() -> void:
	var text: String = CombatHUD.duo_row_text(AYDEN, 0.0, "Q", 4)
	assert_str(text).is_equal(COPY.duo_row_severed_format % ["AYDEN", "FAITH", 4])


func test_partner_appears_beside_fayde_and_fades() -> void:
	var pc: PlayerController = PlayerControllerScript.new() as PlayerController
	add_child(pc)
	var partner: PixelCharacter = pc.show_partner(FAITH)
	assert_object(partner).is_not_null()
	assert_object(partner.get_parent()).is_same(pc)
	assert_object(partner.sheet).is_same(DuoLooks.FAITH["sheet"])
	assert_object(pc.show_partner(DuoSwap.NONE)).is_null()
	remove_child(pc)
	pc.free()


# ── Style and run log ────────────────────────────────────────────────────────

func test_duo_moves_feed_style_and_are_counted_per_fight() -> void:
	var pd := PaceDirector.new()
	add_child(pd)
	pd._on_combat_started(false)
	var counted: Array = []
	pd.duo_counted.connect(func(c: Dictionary) -> void: counted.append(c))
	pd._on_character_swapped(FAITH, 0.0)  # combat-start announcement: not a swap
	pd._on_character_swapped(FAITH, 0.6)
	var after_swap: float = pd.style.get_value()
	assert_float(after_swap).is_equal_approx(PACE.style_swap, 0.001)
	pd._on_character_swapped(AYDEN, 0.6)  # no hit in between: counted, no style
	assert_float(pd.style.get_value()).is_equal_approx(after_swap, 0.001)
	pd._on_spell_hit(null, 1)
	pd._on_link_reaction("Steam", Vector2.ZERO, AYDEN)
	pd._on_resonated(Vector2.ZERO)
	pd._on_link_burst("Steam", Vector2.ZERO, 80.0, AYDEN)
	assert_float(pd.style.get_value()).is_equal_approx(
		after_swap + PACE.style_link + PACE.style_resonance + PACE.style_link_burst, 0.001)
	pd.finish_room()
	assert_array(counted).has_size(1)
	assert_dict(counted[0]).is_equal({"swaps": 2, "links": 1, "resonances": 1, "link_bursts": 1})
	pd._on_preparation_started(0, 0)  # already flushed: no second tally
	assert_array(counted).has_size(1)
	remove_child(pd)
	pd.free()


func test_run_log_sums_the_duo_moves_of_every_fight() -> void:
	var builds: Array[Dictionary] = [
		{"floor": 1, "room": 1, "duo": {"swaps": 3, "links": 1, "resonances": 0, "link_bursts": 0}},
		{"floor": 1, "room": 2},
		{"floor": 1, "room": 3, "duo": {"swaps": 5, "links": 2, "resonances": 2, "link_bursts": 1}},
	]
	assert_dict(RunLog.duo_totals(builds)).is_equal(
		{"swaps": 8, "links": 3, "resonances": 2, "link_bursts": 1})
	var e: Dictionary = RunLog.entry(RunLog.OUTCOME_WIN, {}, {}, "", builds, "t", "v")
	assert_int(int(e["duo"]["links"])).is_equal(3)
