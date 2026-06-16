## spell_vfx_pool_test.gd — Unit tests for SpellVFX particle pool (ADR-0015 / S7-05).
##
## Coverage:
##   1. Pool has exactly 5 entries after _ready() — one per VfxBurstShape
##   2. All pool keys match GameEnums.VfxBurstShape values (0–4)
##   3. All pool values are GPUParticles2D instances
##   4. All pool nodes start with emitting = false
##   5. All pool nodes have one_shot = true
##
## PERF-C1 fix verification: _pool populated at init, not per hit.
## Pool accessed via vfx.get("_pool") — no class_name on SpellVFX (ADR-0002 rule).
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

const SpellVFXScript := preload("res://src/ui/spell_vfx.gd")
const EXPECTED_POOL_SIZE: int = 5


func _make_vfx() -> Node:
	var vfx: Node = SpellVFXScript.new()
	add_child(vfx)
	auto_free(vfx)
	return vfx


# ── Test 1: pool size ─────────────────────────────────────────────────────────

func test_pool_has_five_entries_after_ready() -> void:
	var vfx: Node = _make_vfx()
	var pool: Dictionary = vfx.get("_pool") as Dictionary
	assert_int(pool.size()).is_equal(EXPECTED_POOL_SIZE)


# ── Test 2: pool keys ─────────────────────────────────────────────────────────

func test_pool_keys_match_vfx_burst_shape_values() -> void:
	var vfx: Node = _make_vfx()
	var pool: Dictionary = vfx.get("_pool") as Dictionary
	for shape: int in GameEnums.VfxBurstShape.values():
		assert_bool(pool.has(shape))\
			.override_failure_message("Pool missing entry for VfxBurstShape %d" % shape)\
			.is_true()


# ── Test 3: pool values are GPUParticles2D ────────────────────────────────────

func test_pool_values_are_gpu_particles2d() -> void:
	var vfx: Node = _make_vfx()
	var pool: Dictionary = vfx.get("_pool") as Dictionary
	for shape: int in GameEnums.VfxBurstShape.values():
		var node: Variant = pool.get(shape)
		assert_bool(node is GPUParticles2D)\
			.override_failure_message("Pool shape %d is not GPUParticles2D" % shape)\
			.is_true()


# ── Test 4: nodes idle at init ────────────────────────────────────────────────

func test_pool_nodes_not_emitting_at_init() -> void:
	var vfx: Node = _make_vfx()
	var pool: Dictionary = vfx.get("_pool") as Dictionary
	for shape: int in GameEnums.VfxBurstShape.values():
		var node: GPUParticles2D = pool.get(shape) as GPUParticles2D
		assert_bool(node.emitting)\
			.override_failure_message("Pool node shape %d should not be emitting at init" % shape)\
			.is_false()


# ── Test 5: nodes are one_shot ────────────────────────────────────────────────

func test_pool_nodes_are_one_shot() -> void:
	var vfx: Node = _make_vfx()
	var pool: Dictionary = vfx.get("_pool") as Dictionary
	for shape: int in GameEnums.VfxBurstShape.values():
		var node: GPUParticles2D = pool.get(shape) as GPUParticles2D
		assert_bool(node.one_shot)\
			.override_failure_message("Pool node shape %d must be one_shot" % shape)\
			.is_true()
