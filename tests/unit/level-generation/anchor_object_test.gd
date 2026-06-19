## anchor_object_test.gd — Unit tests for AnchorObject resource and AnchorObjectNode.
##
## Story: LD-22 — AnchorObject resource + placement
## Design: design/anchor-objects.md
extends GdUnitTestSuite

const _ANCHOR_SCENE: PackedScene = preload("res://src/scenes/AnchorObjectNode.tscn")

# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_anchor_data(
		anchor_id: StringName = &"test_anchor",
		memory_id: StringName = &"mem_test_anchor",
		radius: float = 48.0,
		condition: AnchorObject.TriggerCondition = AnchorObject.TriggerCondition.PROXIMITY
) -> AnchorObject:
	var data := AnchorObject.new()
	data.anchor_id = anchor_id
	data.display_name = "Test Anchor"
	data.visual_description = "A test anchor for unit tests."
	data.memory_id = memory_id
	data.trigger_radius = radius
	data.trigger_condition = condition
	return data


func _make_node(data: AnchorObject = null) -> AnchorObjectNode:
	var node: AnchorObjectNode = _ANCHOR_SCENE.instantiate() as AnchorObjectNode
	if data != null:
		node.anchor_data = data
	add_child(node)
	return node


func _make_fake_player() -> CharacterBody2D:
	# Not added to scene tree — is_in_group() checks pending groups, works without add_child.
	var body := CharacterBody2D.new()
	body.add_to_group(&"player")
	return body

# ── AnchorObject resource ─────────────────────────────────────────────────────

func test_anchor_object_default_trigger_is_proximity() -> void:
	var data := AnchorObject.new()
	assert_int(data.trigger_condition).is_equal(AnchorObject.TriggerCondition.PROXIMITY)


func test_anchor_object_default_radius_is_48() -> void:
	var data := AnchorObject.new()
	assert_float(data.trigger_radius).is_equal(48.0)


func test_anchor_object_fields_round_trip() -> void:
	var data := _make_anchor_data(&"worn_journal", &"mem_worn_journal", 64.0)
	assert_str(String(data.anchor_id)).is_equal("worn_journal")
	assert_str(String(data.memory_id)).is_equal("mem_worn_journal")
	assert_float(data.trigger_radius).is_equal(64.0)

# ── AnchorObjectNode — initial state ─────────────────────────────────────────

func test_node_not_triggered_initially() -> void:
	var node := _make_node(_make_anchor_data())
	assert_bool(node.is_triggered()).is_false()
	node.free()


func test_node_monitoring_enabled_on_ready() -> void:
	var node := _make_node(_make_anchor_data())
	assert_bool(node.monitoring).is_true()
	node.free()

# ── AnchorObjectNode — trigger logic ─────────────────────────────────────────

func test_trigger_emits_memory_fragment_triggered() -> void:
	var node := _make_node(_make_anchor_data(&"carved_toy", &"mem_carved_toy"))
	var received: Array[StringName] = []
	node.memory_fragment_triggered.connect(func(mid: StringName) -> void:
		received.append(mid))

	var player := _make_fake_player()
	node._on_body_entered(player)
	player.free()

	assert_array(received).has_size(1)
	assert_str(String(received[0])).is_equal("mem_carved_toy")
	node.free()


func test_trigger_fires_only_once() -> void:
	var node := _make_node(_make_anchor_data())
	var received: Array[StringName] = []
	node.memory_fragment_triggered.connect(func(mid: StringName) -> void:
		received.append(mid))

	var player := _make_fake_player()
	node._on_body_entered(player)
	node._on_body_entered(player)
	node._on_body_entered(player)
	player.free()

	assert_array(received).has_size(1)
	node.free()


func test_trigger_sets_triggered_flag() -> void:
	var node := _make_node(_make_anchor_data())
	var player := _make_fake_player()
	node._on_body_entered(player)
	player.free()
	assert_bool(node.is_triggered()).is_true()
	node.free()


func test_trigger_disables_monitoring_after_fire() -> void:
	var node := _make_node(_make_anchor_data())
	var player := _make_fake_player()
	node._on_body_entered(player)
	player.free()
	assert_bool(node.monitoring).is_false()
	node.free()


func test_trigger_ignores_non_player_body() -> void:
	var node := _make_node(_make_anchor_data())
	var count: int = 0
	node.memory_fragment_triggered.connect(func(_mid: StringName) -> void:
		count += 1)

	var non_player := Node2D.new()
	node._on_body_entered(non_player)
	non_player.free()

	assert_int(count).is_equal(0)
	assert_bool(node.is_triggered()).is_false()
	node.free()


func test_trigger_ignores_room_cleared_condition() -> void:
	var data := _make_anchor_data(
		&"test", &"mem_test", 48.0, AnchorObject.TriggerCondition.ROOM_CLEARED)
	var node := _make_node(data)
	var count: int = 0
	node.memory_fragment_triggered.connect(func(_mid: StringName) -> void:
		count += 1)

	# PROXIMITY path should not fire when condition is ROOM_CLEARED.
	var player := _make_fake_player()
	node._on_body_entered(player)
	player.free()

	assert_int(count).is_equal(0)
	assert_bool(node.is_triggered()).is_false()
	node.free()


func test_no_anchor_data_does_not_crash() -> void:
	var node := _make_node(null)
	# Should push_error but not crash — triggered stays false with null data.
	var player := _make_fake_player()
	node._on_body_entered(player)
	player.free()
	assert_bool(node.is_triggered()).is_false()
	node.free()

# ── set_anchor_data ───────────────────────────────────────────────────────────

func test_set_anchor_data_updates_memory_id() -> void:
	var node := _make_node(null)
	var data := _make_anchor_data(&"rusted_key", &"mem_rusted_key")
	node.set_anchor_data(data)
	assert_str(String(node.anchor_data.memory_id)).is_equal("mem_rusted_key")
	node.free()
