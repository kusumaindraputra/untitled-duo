## game_enums_test.gd — Unit tests for GameEnums (ADR-0006).
##
## Coverage:
##   - All enum types exist and are accessible via GameEnums.*
##   - All integer assignments are explicit and stable (not reordered)
##   - Sentinel values are correct (DamageClass.NONE = -1)
##   - No overlap between distinct enum types (sanity checks)
##
## Framework: GDUnit4
## Run: godot --headless --script tests/gdunit4_runner.gd
extends GdUnitTestSuite


# ── DamageClass ───────────────────────────────────────────────────────────────

func test_game_enums_damage_class_none_is_sentinel() -> void:
	# Arrange / Act / Assert — value is a compile-time constant
	assert_int(GameEnums.DamageClass.NONE).is_equal(-1)
	# Spec requires explicit negative check: NONE must be < 0 (not merely any wrong value)
	assert_bool(GameEnums.DamageClass.NONE < 0).is_true()


func test_game_enums_damage_class_explicit_integers() -> void:
	assert_int(GameEnums.DamageClass.FIRE).is_equal(0)
	assert_int(GameEnums.DamageClass.SHADOW).is_equal(1)
	assert_int(GameEnums.DamageClass.LIGHTNING).is_equal(2)
	assert_int(GameEnums.DamageClass.ICE).is_equal(3)
	assert_int(GameEnums.DamageClass.NATURE).is_equal(4)


# ── DamageSource ──────────────────────────────────────────────────────────────

func test_game_enums_damage_source_explicit_integers() -> void:
	assert_int(GameEnums.DamageSource.DIRECT).is_equal(0)
	assert_int(GameEnums.DamageSource.DOT).is_equal(1)
	assert_int(GameEnums.DamageSource.CONTACT).is_equal(2)


# ── BaseStatus ────────────────────────────────────────────────────────────────

func test_game_enums_base_status_explicit_integers() -> void:
	assert_int(GameEnums.BaseStatus.BURN).is_equal(0)
	assert_int(GameEnums.BaseStatus.BLIND).is_equal(1)
	assert_int(GameEnums.BaseStatus.STUN).is_equal(2)
	assert_int(GameEnums.BaseStatus.FREEZE).is_equal(3)
	assert_int(GameEnums.BaseStatus.REGENERATE).is_equal(4)
	assert_int(GameEnums.BaseStatus.CHILL).is_equal(5)
	assert_int(GameEnums.BaseStatus.STAGGER).is_equal(6)


func test_game_enums_base_status_chill_exists() -> void:
	# CHILL and STAGGER were added after initial BaseStatus definition (ADR-0006 §GDD).
	# This test fails fast if someone removes or renames either value.
	assert_bool(GameEnums.BaseStatus.has("CHILL")).is_true()


func test_game_enums_base_status_stagger_exists() -> void:
	assert_bool(GameEnums.BaseStatus.has("STAGGER")).is_true()


# ── HPZone ────────────────────────────────────────────────────────────────────

func test_game_enums_hp_zone_explicit_integers() -> void:
	assert_int(GameEnums.HPZone.FULL).is_equal(0)
	assert_int(GameEnums.HPZone.CAREFUL).is_equal(1)
	assert_int(GameEnums.HPZone.DESPERATE).is_equal(2)


# ── GameState ─────────────────────────────────────────────────────────────────

func test_game_enums_game_state_explicit_integers() -> void:
	assert_int(GameEnums.GameState.MAIN_MENU).is_equal(0)
	assert_int(GameEnums.GameState.PREPARATION_PHASE).is_equal(1)
	assert_int(GameEnums.GameState.COMBAT_PHASE).is_equal(2)
	assert_int(GameEnums.GameState.PAUSED).is_equal(3)
	assert_int(GameEnums.GameState.RUN_SUMMARY).is_equal(4)
	assert_int(GameEnums.GameState.DEATH_SCREEN).is_equal(5)


# ── RunOutcome ────────────────────────────────────────────────────────────────

func test_game_enums_run_outcome_none_is_in_progress_default() -> void:
	# NONE = 0 is the "run still in progress" default, not a negative sentinel.
	# Unlike DamageClass.NONE (-1), this value is 0 — check by name, not sign.
	assert_int(GameEnums.RunOutcome.NONE).is_equal(0)


func test_game_enums_run_outcome_explicit_integers() -> void:
	assert_int(GameEnums.RunOutcome.WIN).is_equal(1)
	assert_int(GameEnums.RunOutcome.LOSS).is_equal(2)


# ── EnemyArchetype ────────────────────────────────────────────────────────────

func test_game_enums_enemy_archetype_explicit_integers() -> void:
	assert_int(GameEnums.EnemyArchetype.SEEKER).is_equal(0)
	assert_int(GameEnums.EnemyArchetype.RUSHER).is_equal(1)
	assert_int(GameEnums.EnemyArchetype.SWARMER).is_equal(2)
	assert_int(GameEnums.EnemyArchetype.BOSS).is_equal(3)


# ── EnemyState ────────────────────────────────────────────────────────────────

func test_game_enums_enemy_state_explicit_integers() -> void:
	assert_int(GameEnums.EnemyState.IDLE).is_equal(0)
	assert_int(GameEnums.EnemyState.PURSUING).is_equal(1)
	assert_int(GameEnums.EnemyState.ATTACKING).is_equal(2)
	assert_int(GameEnums.EnemyState.STUNNED).is_equal(3)
	assert_int(GameEnums.EnemyState.DEAD).is_equal(4)


func test_game_enums_enemy_state_stunned_distinct_from_base_status_stun() -> void:
	# EnemyState.STUNNED (3) and BaseStatus.STUN (2) are distinct integers and distinct types.
	# A match on one must never accept the other — GDScript enum types are not interchangeable
	# even when values are close. See Enemy AI GDD: Stun != Slow.
	assert_int(GameEnums.EnemyState.STUNNED).is_equal(3)
	assert_int(GameEnums.BaseStatus.STUN).is_equal(2)


# ── WaveState ─────────────────────────────────────────────────────────────────

func test_game_enums_wave_state_explicit_integers() -> void:
	assert_int(GameEnums.WaveState.IDLE).is_equal(0)
	assert_int(GameEnums.WaveState.WAVE_ACTIVE).is_equal(1)
	assert_int(GameEnums.WaveState.WAVE_COMPLETE).is_equal(2)


# ── CastAnimation ─────────────────────────────────────────────────────────────

func test_game_enums_cast_animation_explicit_integers() -> void:
	assert_int(GameEnums.CastAnimation.CAST_THRUST).is_equal(0)
	assert_int(GameEnums.CastAnimation.CAST_REACH).is_equal(1)
	assert_int(GameEnums.CastAnimation.CAST_SNAP).is_equal(2)
	assert_int(GameEnums.CastAnimation.CAST_PUSH).is_equal(3)
	assert_int(GameEnums.CastAnimation.CAST_BLOOM).is_equal(4)


# ── VfxBurstShape ─────────────────────────────────────────────────────────────

func test_game_enums_vfx_burst_shape_explicit_integers() -> void:
	assert_int(GameEnums.VfxBurstShape.BURST_FLAME).is_equal(0)
	assert_int(GameEnums.VfxBurstShape.BURST_SPIRAL).is_equal(1)
	assert_int(GameEnums.VfxBurstShape.BURST_LIGHTNING).is_equal(2)
	assert_int(GameEnums.VfxBurstShape.BURST_CRYSTAL).is_equal(3)
	assert_int(GameEnums.VfxBurstShape.BURST_VINE).is_equal(4)


# ── Cross-type isolation sanity checks ────────────────────────────────────────

func test_game_enums_damage_class_count_matches_spec() -> void:
	# 5 real values + NONE sentinel = 6 total keys.
	# If this count changes, the spec was updated without updating this test.
	assert_int(GameEnums.DamageClass.size()).is_equal(6)


func test_game_enums_base_status_count_matches_spec() -> void:
	# ADR-0006 §GDD Requirements: 7 statuses (BURN..STAGGER).
	assert_int(GameEnums.BaseStatus.size()).is_equal(7)


func test_game_enums_game_state_count_matches_spec() -> void:
	# 6 states: MAIN_MENU..DEATH_SCREEN. Count guard catches silent additions/removals
	# before downstream state machine match statements silently miss the new arm.
	assert_int(GameEnums.GameState.size()).is_equal(6)


func test_game_enums_enemy_state_count_matches_spec() -> void:
	# 5 states: IDLE..DEAD. Count guard for the enemy AI state machine.
	assert_int(GameEnums.EnemyState.size()).is_equal(5)


# ── AC-4: Class accessible without error ──────────────────────────────────────
# CI grep checks for forbidden patterns (preload, load, @onready, @export, extends Node)
# are a separate CI concern. This test confirms GameEnums is accessible at runtime.

func test_game_enums_class_loads_without_error() -> void:
	assert_object(GameEnums.new()).is_not_null()


# ── AC-5: .tres serialization verification gate (MANUAL — blocks Story 004) ───

func test_game_enums_tres_serialization_gate_pending(
		do_skip := true,
		skip_reason := "MANUAL GATE — AC-5: Before Story 004, create a throwaway TestResource with @export var dc: GameEnums.DamageClass, save as .tres, open in a text editor, confirm the value serializes as an integer (e.g. 0) not a string (e.g. 'FIRE'). See story-001 Acceptance Criteria and ADR-0006 verification gate procedure."
) -> void:
	pass
