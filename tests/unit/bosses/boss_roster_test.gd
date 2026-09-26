## boss_roster_test.gd — Floor bosses and their per-run variants (ADR-0028).
##
## Coverage:
##   each floor spawns its own boss, and no two bosses share a bullet layer
##   every boss has a profile, banners for every phase and three variants with titles
##   a variant's extra layers never add an HP phase
##   pick_variant is stable for one seed and reaches every variant across seeds
##   BossDirector applies a variant's extra arena events
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const ROSTER: BossRoster = preload("res://assets/data/bosses/boss_roster.tres")
const COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const BOSS_POOLS: Array[String] = [
	"res://assets/data/enemy_pool_configs/enemy_pool_boss.tres",
	"res://assets/data/enemy_pool_configs/enemy_pool_boss_f2.tres",
	"res://assets/data/enemy_pool_configs/enemy_pool_boss_f3.tres",
]
const SENTINEL_ID: int = 5
const WARDEN_ID: int = 3
const KEEPER_ID: int = 11


## Stand-in boss exposing the calls BossDirector uses.
class _FakeBoss extends Node2D:
	signal phase_changed(phase: int)
	var type_id: int = 0
	var variant: BossVariant = null
	func get_type_id() -> int:
		return type_id
	func get_boss_variant() -> BossVariant:
		return variant


## Distinct HP thresholds (< 1) among [param layers]: the boss's phase count.
func _thresholds(layers: Array) -> Dictionary:
	var out: Dictionary = {}
	for layer: Variant in layers:
		var p := layer as BulletPattern
		if p != null and p.hp_threshold < 1.0:
			out[p.hp_threshold] = true
	return out


## The roster's profiles, typed (a const-preloaded resource's typed array cannot be
## iterated with a class-typed loop variable in a test script).
func _profiles() -> Array[BossProfile]:
	var out: Array[BossProfile] = []
	for p: Variant in ROSTER.profiles:
		out.append(p as BossProfile)
	return out


func _floor_boss_ids() -> Array[int]:
	var ids: Array[int] = []
	for path: String in BOSS_POOLS:
		var cfg: EnemyPoolConfig = load(path) as EnemyPoolConfig
		ids.append(cfg.guaranteed_types[0])
	return ids


func test_boss_roster_each_floor_spawns_its_own_boss() -> void:
	var ids: Array[int] = _floor_boss_ids()
	assert_array(ids).contains_exactly([SENTINEL_ID, WARDEN_ID, KEEPER_ID])
	for id: int in ids:
		assert_object(ROSTER.profile_for(id)).is_not_null()


func test_boss_roster_bosses_share_no_bullet_layer() -> void:
	var seen: Dictionary = {}
	for id: int in _floor_boss_ids():
		var et: EnemyType = EnemyCatalog.get_type(id)
		assert_int(et.archetype).is_equal(GameEnums.EnemyArchetype.BOSS)
		for layer: BulletPattern in et.pattern_layers:
			assert_bool(seen.has(layer.resource_path)).is_false()
			seen[layer.resource_path] = id


func test_boss_roster_every_phase_has_a_banner_and_events_fit() -> void:
	for profile: BossProfile in _profiles():
		var et: EnemyType = EnemyCatalog.get_type(profile.boss_type_id)
		var phases: int = _thresholds(et.pattern_layers).size()
		assert_int(phases).is_greater(0)
		for phase: int in range(1, phases + 1):
			assert_str(BossDirector.banner_for_phase(profile, phase)).is_not_empty()
		assert_str(BossDirector.banner_for_phase(profile, phases + 1)).is_empty()
		for ev: BossPhaseEvent in profile.events:
			assert_int(ev.phase).is_between(1, phases)
		for v: BossVariant in profile.variants:
			for ev: BossPhaseEvent in v.extra_events:
				assert_int(ev.phase).is_between(1, phases)


func test_boss_roster_each_boss_has_three_titled_variants() -> void:
	var ids: Dictionary = {}
	for profile: BossProfile in _profiles():
		assert_int(profile.variants.size()).is_equal(3)
		for v: BossVariant in profile.variants:
			assert_bool(ids.has(v.id)).is_false()
			ids[v.id] = true
			assert_bool(COPY.boss_variant_titles.has(String(v.id))).is_true()


func test_boss_roster_variant_layers_add_no_phase() -> void:
	for profile: BossProfile in _profiles():
		var base: Dictionary = _thresholds(EnemyCatalog.get_type(profile.boss_type_id).pattern_layers)
		for v: BossVariant in profile.variants:
			for t: Variant in _thresholds(v.extra_layers).keys():
				assert_bool(base.has(t)).is_true()


func test_boss_roster_pick_is_stable_for_one_seed() -> void:
	for profile: BossProfile in _profiles():
		var a: BossVariant = BossRoster.pick_variant(profile, 12345)
		var b: BossVariant = BossRoster.pick_variant(profile, 12345)
		assert_object(a).is_same(b)


func test_boss_roster_seeds_reach_every_variant() -> void:
	for profile: BossProfile in _profiles():
		var seen: Dictionary = {}
		for s: int in 64:
			seen[BossRoster.pick_variant(profile, s * 977).id] = true
		assert_int(seen.size()).is_equal(profile.variants.size())


func test_boss_roster_pick_all_covers_every_boss() -> void:
	var picks: Dictionary = ROSTER.pick_all(42)
	assert_array(picks.keys()).contains_exactly_in_any_order([SENTINEL_ID, WARDEN_ID, KEEPER_ID])


func test_boss_roster_profile_without_variants_picks_null() -> void:
	var p := BossProfile.new()
	p.boss_type_id = 99
	assert_object(BossRoster.pick_variant(p, 1)).is_null()
	assert_object(ROSTER.profile_for(99)).is_null()


func test_boss_director_applies_variant_extra_event() -> void:
	var profile: BossProfile = ROSTER.profile_for(WARDEN_ID)
	var unstable: BossVariant = null
	for v: BossVariant in profile.variants:
		if v.id == &"unstable":
			unstable = v
	assert_object(unstable).is_not_null()
	# Base Warden adds no sweep pylon at phase 2; the Unstable variant does.
	assert_array(BossDirector.hazards_for_phase(profile, 2)).is_empty()
	var d := BossDirector.new()
	add_child(d)
	var room := Node2D.new()
	add_child(room)
	var boss := _FakeBoss.new()
	boss.type_id = WARDEN_ID
	boss.variant = unstable
	room.add_child(boss)
	assert_bool(d.attach(boss, room)).is_true()
	boss.phase_changed.emit(2)
	var sweeps: int = 0
	var vents: int = 0
	for c: Node in room.get_children():
		if c is HazardSweepLaser:
			sweeps += 1
		elif c is HazardFloorZone:
			vents += 1
	assert_int(sweeps).is_equal(1)
	assert_int(vents).is_equal(3)  # phase 1 was skipped, so it is applied too
	room.free()
	d.free()


func test_boss_director_sentinel_phase1_places_turrets() -> void:
	var hazards: Array[HazardSpec] = BossDirector.hazards_for_phase(ROSTER.profile_for(SENTINEL_ID), 1)
	assert_int(hazards.size()).is_equal(2)
	for h: HazardSpec in hazards:
		assert_int(h.kind).is_equal(HazardSpec.Kind.TURRET)
		assert_object(h.pattern).is_not_null()
