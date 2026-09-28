## heirloom_memory_gate_test.gd — Ten Heirlooms, new ones revealed by memories (beta plan F4).
##
## Coverage:
##   HG-01: ids, costs and memory gates are parallel arrays of 10, gates never decrease
##   HG-02: every Heirloom id exists in the SigilConfig catalog
##   HG-03: a gated Heirloom cannot be bought until enough memories are recovered
##   HG-04: heirlooms_revealed_between lists exactly the gates crossed
##   HG-05: button and hint text show the memory lock, then the shard cost
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const META: MetaTuning = preload("res://assets/data/meta_tuning.tres")


func _gated_tuning() -> MetaTuning:
	var t := MetaTuning.new()
	t.heirloom_ids = [&"damage", &"siphon", &"riposte"]
	t.heirloom_costs = [30, 60, 90]
	t.heirloom_memory_gates = [0, 3, 6]
	return t


func _rich(found: int) -> MetaProgress:
	var p := MetaProgress.new()
	p.shards = 1000
	p.fragments_found = found
	return p


# ── HG-01 / HG-02: shipped data ───────────────────────────────────────────────

func test_heirloom_data_arrays_parallel_and_twelve() -> void:
	assert_int(META.heirloom_ids.size()).is_equal(12)
	assert_int(META.heirloom_costs.size()).is_equal(META.heirloom_ids.size())
	assert_int(META.heirloom_memory_gates.size()).is_equal(META.heirloom_ids.size())
	for i: int in range(1, META.heirloom_memory_gates.size()):
		assert_bool(META.heirloom_memory_gates[i] >= META.heirloom_memory_gates[i - 1]).is_true()


func test_heirloom_data_ids_exist_in_sigil_catalog() -> void:
	for id: StringName in META.heirloom_ids:
		assert_bool(MetaProgress.heirloom_info(id).is_empty()) \
			.override_failure_message("unknown Heirloom id %s" % id).is_false()


# ── HG-03: gate blocks buying ─────────────────────────────────────────────────

func test_heirloom_gate_blocks_until_memories_found() -> void:
	var t := _gated_tuning()
	var p := _rich(2)
	assert_bool(p.can_unlock(t, &"damage")).is_true()
	assert_bool(p.can_unlock(t, &"siphon")).is_false()
	assert_bool(p.unlock(t, &"siphon")).is_false()
	p.fragments_found = 3
	assert_bool(p.is_revealed(t, &"siphon")).is_true()
	assert_bool(p.can_unlock(t, &"riposte")).is_false()
	assert_bool(p.unlock(t, &"siphon")).is_true()
	assert_int(p.shards).is_equal(940)


func test_heirloom_gate_unknown_id_needs_no_memories() -> void:
	assert_int(_gated_tuning().memories_needed(&"nope")).is_equal(0)


# ── HG-04: revealed between ───────────────────────────────────────────────────

func test_heirloom_revealed_between_lists_crossed_gates() -> void:
	var t := _gated_tuning()
	assert_array(t.heirlooms_revealed_between(2, 3)).contains_exactly([&"siphon"])
	assert_array(t.heirlooms_revealed_between(3, 6)).contains_exactly([&"riposte"])
	assert_array(t.heirlooms_revealed_between(0, 10)).contains_exactly([&"siphon", &"riposte"])
	assert_array(t.heirlooms_revealed_between(3, 3)).is_empty()


# ── HG-05: screen text ────────────────────────────────────────────────────────

func test_heirloom_button_text_shows_memory_lock_then_cost() -> void:
	var id: StringName = META.heirloom_ids[META.heirloom_ids.size() - 1]
	var gate: int = META.memories_needed(id)
	assert_int(gate).is_greater(0)
	var title: String = str(MetaProgress.heirloom_info(id).get("title", ""))
	var p := _rich(gate - 1)
	assert_str(HeirloomScreen.button_text(p, id)) \
		.is_equal(COPY.heirloom_memory_locked_format % [title, gate])
	assert_str(HeirloomScreen.desc_text(p, id)) \
		.contains(COPY.heirloom_hint_memories_format % gate)
	p.fragments_found = gate
	assert_str(HeirloomScreen.button_text(p, id)) \
		.is_equal(COPY.heirloom_locked_format % [title, META.cost_of(id)])
