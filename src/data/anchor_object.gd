## anchor_object.gd — Data resource for a single memory anchor object.
##
## AnchorObject defines what a memory anchor IS (its identity and trigger rules).
## AnchorObjectNode (src/scenes/anchor_object_node.gd) is what gets placed in a room.
##
## Story: LD-22 — AnchorObject resource + placement
## Design: design/anchor-objects.md
class_name AnchorObject
extends Resource

# ── Enums ─────────────────────────────────────────────────────────────────────

## How proximity or game state fires the memory fragment.
## ROOM_CLEARED is reserved for LD-23+ — not yet implemented.
enum TriggerCondition {
	PROXIMITY = 0,     ## Fayde enters the anchor's Area2D — default and only FP scope trigger.
	ROOM_CLEARED = 1,  ## Wave cleared before triggering. Reserved — not implemented until LD-23.
}

# ── Exports ───────────────────────────────────────────────────────────────────

## Unique identifier for this anchor type. Matches a catalog entry in design/anchor-objects.md.
@export var anchor_id: StringName = &""

## Human-readable name shown in debug overlays and editor.
@export var display_name: String = ""

## One-sentence visual description for the art placeholder and future art brief.
@export var visual_description: String = ""

## Memory ID emitted to the narrative system when triggered.
## Convention: "mem_[anchor_id]" (e.g. "mem_worn_journal"). Consumed by LD-23.
@export var memory_id: StringName = &""

## Proximity trigger radius in world pixels. Area2D CollisionShape2D uses this.
## Default 48px — comfortably discoverable, not accidental.
@export var trigger_radius: float = 48.0

## Which condition fires the memory fragment.
@export var trigger_condition: TriggerCondition = TriggerCondition.PROXIMITY
