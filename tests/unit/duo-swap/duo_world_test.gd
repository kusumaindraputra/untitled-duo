## duo_world_test.gd — the world answering the duo (ADR-0058, design/gdd/duo-swap.md
## Rules 6h–6j): duo foes that resist one brother, the music leaning to the brother
## in the arena, and duo Cipher Cores. Expected
## values come from the shipped tuning so the tests follow the knobs.
extends GdUnitTestSuite

const T: DuoTuning = preload("res://assets/data/duo_tuning.tres")
const COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const CORES: CoreRoster = preload("res://assets/data/cores/core_roster.tres")
const EnemyScene: PackedScene = preload("res://src/gameplay/EnemyInstance.tscn")

const AYDEN: int = DuoSwap.Character.AYDEN
const FAITH: int = DuoSwap.Character.FAITH


# ── Duo foes: pure rules ─────────────────────────────────────────────────────

func test_duo_foe_warded_resists_faith_and_flitting_resists_ayden() -> void:
	assert_float(DuoFoe.hit_mult(DuoFoe.Kind.WARDED, AYDEN)).is_equal(1.0)
	assert_float(DuoFoe.hit_mult(DuoFoe.Kind.WARDED, FAITH)).is_equal_approx(T.wrong_brother_mult, 0.0001)
	assert_float(DuoFoe.hit_mult(DuoFoe.Kind.FLITTING, FAITH)).is_equal(1.0)
	assert_float(DuoFoe.hit_mult(DuoFoe.Kind.FLITTING, AYDEN)).is_equal_approx(T.wrong_brother_mult, 0.0001)


func test_duo_foe_plain_enemies_and_no_duo_take_full_damage() -> void:
	assert_float(DuoFoe.hit_mult(DuoFoe.Kind.NONE, FAITH)).is_equal(1.0)
	assert_float(DuoFoe.hit_mult(DuoFoe.Kind.WARDED, DuoSwap.NONE)).is_equal(1.0)


func test_duo_foe_roll_uses_chance_then_share() -> void:
	assert_int(DuoFoe.roll(T.duo_foe_chance + 0.01, 0.0)).is_equal(DuoFoe.Kind.NONE)
	assert_int(DuoFoe.roll(0.0, 0.0)).is_equal(DuoFoe.Kind.WARDED)
	assert_int(DuoFoe.roll(0.0, 0.99)).is_equal(DuoFoe.Kind.FLITTING)


func test_duo_foe_flits_only_from_ayden_close_and_off_cooldown() -> void:
	var near := Vector2(T.flit_radius - 1.0, 0.0)
	assert_bool(DuoFoe.should_flit(DuoFoe.Kind.FLITTING, AYDEN, near, Vector2.ZERO, 0.0)).is_true()
	assert_bool(DuoFoe.should_flit(DuoFoe.Kind.FLITTING, FAITH, near, Vector2.ZERO, 0.0)).is_false()
	assert_bool(DuoFoe.should_flit(DuoFoe.Kind.FLITTING, AYDEN, near * 3.0, Vector2.ZERO, 0.0)).is_false()
	assert_bool(DuoFoe.should_flit(DuoFoe.Kind.FLITTING, AYDEN, near, Vector2.ZERO, 0.5)).is_false()
	assert_bool(DuoFoe.should_flit(DuoFoe.Kind.WARDED, AYDEN, near, Vector2.ZERO, 0.0)).is_false()


# ── Duo foes: enemy state ────────────────────────────────────────────────────

func _enemy() -> EnemyInstance:
	var e: EnemyInstance = EnemyScene.instantiate() as EnemyInstance
	add_child(e)
	e.init(0)
	return e


func _free(e: EnemyInstance) -> void:
	remove_child(e)
	e.free()


func test_duo_foe_ayden_breaks_a_ward_after_ward_hits() -> void:
	var e := _enemy()
	e.make_duo_foe(DuoFoe.Kind.WARDED)
	assert_int(e.get_ward_left()).is_equal(T.ward_hits)
	var bounced: Dictionary = e.take_duo_hit(FAITH)
	assert_float(float(bounced["mult"])).is_equal_approx(T.wrong_brother_mult, 0.0001)
	assert_bool(bool(bounced["hint"])).is_true()
	assert_bool(bool(e.take_duo_hit(FAITH)["hint"])).is_false()  # hints are throttled
	for i: int in T.ward_hits - 1:
		assert_bool(bool(e.take_duo_hit(AYDEN)["broke"])).is_false()
	assert_bool(bool(e.take_duo_hit(AYDEN)["broke"])).is_true()
	assert_int(e.get_duo_foe()).is_equal(DuoFoe.Kind.NONE)
	assert_float(float(e.take_duo_hit(FAITH)["mult"])).is_equal(1.0)
	_free(e)


func test_duo_foe_bosses_never_become_duo_foes() -> void:
	var e := _enemy()
	e._archetype = GameEnums.EnemyArchetype.BOSS
	e.make_duo_foe(DuoFoe.Kind.WARDED)
	assert_int(e.get_duo_foe()).is_equal(DuoFoe.Kind.NONE)
	_free(e)


func test_duo_foe_health_and_damage_scales_a_resisted_hit() -> void:
	var e := _enemy()
	HealthAndDamage.register_enemy(e, 0, 10.0)
	e.make_duo_foe(DuoFoe.Kind.FLITTING)
	var hits: Array = []
	var hook: Callable = func(_t: Node, c: int, broke: bool) -> void: hits.append([c, broke])
	HealthAndDamage.duo_foe_hit.connect(hook)
	var saved: Callable = HealthAndDamage._duo_character_provider
	HealthAndDamage._duo_character_provider = func() -> int: return AYDEN
	var dealt: Array = []
	var on_dmg: Callable = func(t: Node, d: int, _hp: int) -> void:
		if t == e:
			dealt.append(d)
	HealthAndDamage.damage_taken.connect(on_dmg)
	HealthAndDamage.apply_damage(e, 20.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.DIRECT)
	HealthAndDamage.damage_taken.disconnect(on_dmg)
	assert_array(dealt).contains_exactly([roundi(20.0 * T.wrong_brother_mult)])
	assert_array(hits).contains_exactly([[AYDEN, false]])
	HealthAndDamage._duo_character_provider = saved
	HealthAndDamage.duo_foe_hit.disconnect(hook)
	HealthAndDamage.unregister_enemy(e.get_instance_id())
	_free(e)


func test_duo_foe_callout_names_the_brother_to_swap_to() -> void:
	assert_str(CombatHUD.duo_foe_callout(FAITH, false)).is_equal(COPY.foe_swap_format % "AYDEN")
	assert_str(CombatHUD.duo_foe_callout(AYDEN, true)).is_equal(COPY.foe_broken_label)


# ── Duo music ────────────────────────────────────────────────────────────────

func test_duo_music_leans_to_the_brother_in_the_arena() -> void:
	assert_that(DuoMusic.voice_gains(AYDEN)).is_equal(Vector2(T.voice_gain, 1.0))
	assert_that(DuoMusic.voice_gains(FAITH)).is_equal(Vector2(1.0, T.voice_gain))
	assert_that(DuoMusic.voice_gains(DuoSwap.NONE)).is_equal(Vector2.ONE)
	assert_float(DuoMusic.thump_pitch(FAITH)).is_equal(T.faith_thump_pitch)
	assert_float(DuoMusic.thump_pitch(AYDEN)).is_equal(1.0)


func test_duo_music_thump_is_a_short_mono_wav() -> void:
	var wav: AudioStreamWAV = DuoMusic.make_thump(0.1, 8000)
	assert_int(wav.data.size()).is_equal(800 * 2)
	assert_bool(wav.stereo).is_false()
	assert_float(wav.get_length()).is_equal_approx(0.1, 0.01)


func test_duo_music_swap_sets_the_shelf_gains_and_flattens_on_exit() -> void:
	var music := DuoMusic.new()
	var t: DuoTuning = T.duplicate() as DuoTuning
	t.voice_fade_sec = 0.0
	music.tuning = t
	add_child(music)
	music.on_character_swapped(FAITH)
	assert_that(music.get_gains()).is_equal(Vector2(1.0, t.voice_gain))
	remove_child(music)
	assert_that(music.get_gains()).is_equal(Vector2.ONE)
	music.free()


func test_duo_heartbeat_is_taken_once_per_beat() -> void:
	var duo := DuoSwap.new()
	assert_bool(duo.take_beat()).is_false()
	duo.tick(T.heartbeat_sec * 0.5)
	assert_bool(duo.take_beat()).is_false()
	duo.tick(T.heartbeat_sec * 0.6)
	assert_bool(duo.take_beat()).is_true()
	assert_bool(duo.take_beat()).is_false()
	duo.reset_timers()
	duo.tick(T.heartbeat_sec * 1.01)
	assert_bool(duo.take_beat()).is_true()


# ── Duo Cipher Cores ─────────────────────────────────────────────────────────

class _Spells:
	var brother: Dictionary = {}
	var link: float = 1.0
	var damage: float = 1.0
	func apply_damage_mult(f: float) -> void: damage *= f
	func apply_brother_damage_mult(c: int, f: float) -> void: brother[c] = f
	func apply_link_radius_mult(f: float) -> void: link *= f


class _Player extends Node:
	var swap_mult: float = 1.0
	func apply_swap_cooldown_mult(f: float) -> void: swap_mult *= f


func test_duo_cores_lean_toward_one_brother_or_the_swap() -> void:
	var anvil: CoreFrame = CORES.get_core(&"anvil")
	var kite: CoreFrame = CORES.get_core(&"kite")
	var tether: CoreFrame = CORES.get_core(&"tether")
	assert_str(String(anvil.id)).is_equal("anvil")
	var s := _Spells.new()
	anvil.apply(null, s, null)
	assert_float(float(s.brother[AYDEN])).is_greater(1.0)
	assert_float(float(s.brother[FAITH])).is_less(1.0)
	s = _Spells.new()
	kite.apply(null, s, null)
	assert_float(float(s.brother[FAITH])).is_greater(1.0)
	s = _Spells.new()
	var p := _Player.new()
	tether.apply(p, s, null)
	assert_float(p.swap_mult).is_less(1.0)
	assert_float(s.link).is_greater(1.0)
	p.free()


func test_duo_core_swap_cooldown_mult_shortens_the_swap() -> void:
	var duo := DuoSwap.new()
	duo.apply_cooldown_mult(0.5)
	duo.try_swap()
	assert_float(duo.cooldown_remaining()).is_equal_approx(DuoSwap.cooldown_for(false) * 0.5, 0.0001)


func test_duo_core_brother_damage_resets_with_the_run() -> void:
	SpellCastingEffects.apply_brother_damage_mult(AYDEN, 1.3)
	assert_float(SpellCastingEffects.get_brother_damage_mult(AYDEN)).is_equal_approx(1.3, 0.0001)
	assert_float(SpellCastingEffects.get_brother_damage_mult(FAITH)).is_equal(1.0)
	SpellCastingEffects.reset_run_damage_mult()
	assert_float(SpellCastingEffects.get_brother_damage_mult(AYDEN)).is_equal(1.0)
