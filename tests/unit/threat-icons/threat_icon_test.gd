## threat_icon_test.gd — Threat icons over previewed enemies (ADR-0032).
##
## Coverage:
##   TI-01: kind follows archetype first (boss, rusher, swarmer)
##   TI-02: then the strongest pattern (laser, mortar, bullets), then a death pattern
##   TI-03: every shipped enemy type gets a kind with legend text
##   TI-04: swarm counts group by type and skip reinforcements
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const TYPES_DIR: String = "res://assets/data/enemy_types/"


func _type(archetype: GameEnums.EnemyArchetype, kinds: Array = [], splits: bool = false) -> EnemyType:
	var et := EnemyType.new()
	et.archetype = archetype
	for k: Variant in kinds:
		var p := BulletPattern.new()
		p.kind = k as BulletPattern.Kind
		et.pattern_layers.append(p)
	if splits:
		et.death_pattern = BulletPattern.new()
	return et


func test_kind_follows_archetype_first() -> void:
	assert_int(ThreatIcon.kind_for(_type(GameEnums.EnemyArchetype.BOSS, [BulletPattern.Kind.LASER]))) \
		.is_equal(ThreatIcon.Kind.BOSS)
	assert_int(ThreatIcon.kind_for(_type(GameEnums.EnemyArchetype.RUSHER))).is_equal(ThreatIcon.Kind.CHARGER)
	assert_int(ThreatIcon.kind_for(_type(GameEnums.EnemyArchetype.SWARMER, [BulletPattern.Kind.BULLETS]))) \
		.is_equal(ThreatIcon.Kind.SWARM)


func test_kind_then_follows_patterns() -> void:
	var S := GameEnums.EnemyArchetype.SHOOTER
	assert_int(ThreatIcon.kind_for(_type(S, [BulletPattern.Kind.BULLETS, BulletPattern.Kind.LASER]))) \
		.is_equal(ThreatIcon.Kind.LASER)
	assert_int(ThreatIcon.kind_for(_type(S, [BulletPattern.Kind.MORTAR]))).is_equal(ThreatIcon.Kind.MORTAR)
	assert_int(ThreatIcon.kind_for(_type(GameEnums.EnemyArchetype.SEEKER, [BulletPattern.Kind.BULLETS]))) \
		.is_equal(ThreatIcon.Kind.SHOOTER)
	assert_int(ThreatIcon.kind_for(_type(GameEnums.EnemyArchetype.SEEKER, [], true))).is_equal(ThreatIcon.Kind.SPLITTER)
	assert_int(ThreatIcon.kind_for(_type(GameEnums.EnemyArchetype.SEEKER))).is_equal(ThreatIcon.Kind.CHASER)
	assert_int(ThreatIcon.kind_for(null)).is_equal(ThreatIcon.Kind.CHASER)


func test_shipped_enemies_have_named_kinds() -> void:
	assert_int(COPY.threat_names.size()).is_equal(ThreatIcon.Kind.size())
	for f: String in DirAccess.get_files_at(TYPES_DIR):
		var name: String = f.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var et := load(TYPES_DIR + name) as EnemyType
		var k: int = ThreatIcon.kind_for(et)
		assert_bool(k >= 0 and k < COPY.threat_names.size()).override_failure_message(name).is_true()


func test_swarm_counts_group_by_type_and_skip_reinforcements() -> void:
	var SW: int = GameEnums.EnemyArchetype.SWARMER
	var comp: Array = [
		{"type_id": 2, "archetype": SW}, {"type_id": 2, "archetype": SW}, {"type_id": 9, "archetype": SW},
		{"type_id": 2, "archetype": SW, "group": 1}, {"type_id": 0, "archetype": GameEnums.EnemyArchetype.SEEKER},
	]

	var counts: Dictionary = WaveManager.threat_swarm_counts(comp)

	assert_int(int(counts[2])).is_equal(2)
	assert_int(int(counts[9])).is_equal(1)
	assert_bool(counts.has(0)).is_false()
