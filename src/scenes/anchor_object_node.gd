## anchor_object_node.gd — Runtime node for a placed memory anchor object.
##
## Area2D that watches for Fayde proximity and emits memory_fragment_triggered
## when Fayde enters its radius. One-shot per run: triggers exactly once, then
## becomes inert. State reset is intentionally NOT done on preparation_started —
## anchor objects are one-shot per run, not per wave.
##
## Story: LD-22 — AnchorObject resource + placement
## Design: design/anchor-objects.md
class_name AnchorObjectNode
extends Area2D

# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted when Fayde enters the proximity radius and trigger condition is met.
## [param memory_id] matches AnchorObject.memory_id — consumed by LD-23 narrative system.
signal memory_fragment_triggered(memory_id: StringName)

# ── Exports ───────────────────────────────────────────────────────────────────

## The anchor data resource. Must be set before _ready() or via set_anchor_data().
@export var anchor_data: AnchorObject = null

# ── Private state ─────────────────────────────────────────────────────────────

var _triggered: bool = false

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _label: Label = $Label

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 0  # anchors do not occupy a physics layer
	collision_mask = 2   # bit 1: player layer — detect Fayde's CharacterBody2D
	monitoring = true
	monitorable = false
	if anchor_data != null:
		_apply_anchor_data()


## Configures the node from a resource after instantiation.
## Call this before add_child() in the spawning code.
func set_anchor_data(data: AnchorObject) -> void:
	anchor_data = data
	if is_node_ready():
		_apply_anchor_data()


## Returns true if this anchor has already fired this run.
func is_triggered() -> bool:
	return _triggered

# ── Private ───────────────────────────────────────────────────────────────────

func _apply_anchor_data() -> void:
	if anchor_data == null:
		return
	var circle := CircleShape2D.new()
	circle.radius = anchor_data.trigger_radius
	if is_instance_valid(_shape):
		_shape.shape = circle
	if is_instance_valid(_label):
		_label.text = anchor_data.display_name


func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if not body.is_in_group(&"player"):
		return
	if anchor_data == null:
		push_error("AnchorObjectNode: body_entered with no anchor_data set")
		return
	if anchor_data.trigger_condition != AnchorObject.TriggerCondition.PROXIMITY:
		return
	_triggered = true
	monitoring = false  # stop receiving overlaps — we're done
	memory_fragment_triggered.emit(anchor_data.memory_id)
