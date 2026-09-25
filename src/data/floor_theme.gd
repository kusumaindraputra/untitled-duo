## FloorTheme — the identity of one floor: which rooms it draws and how it looks (ADR-0020).
##
## Before ADR-0020 every floor drew from the same Layer 1 template pool. Each floor
## now has a FloorTheme .tres with its own weighted template pools per room type,
## a floor tint and a pillar colour. debug_game_loop applies the theme to the
## RoomSelector before generating the floor and hands it to every room it loads.
##
## Pools are parallel arrays (templates + weights) so they stay editable in the
## inspector. A missing weight counts as 1.0.
## GDD: design/gdd/stage-layout.md
class_name FloorTheme
extends Resource

@export_group("Template Pools")
@export var combat_templates: Array[RoomTemplate] = []
@export var combat_weights: Array[float] = []
@export var elite_templates: Array[RoomTemplate] = []
@export var elite_weights: Array[float] = []
@export var rest_templates: Array[RoomTemplate] = []
@export var boss_templates: Array[RoomTemplate] = []

@export_group("Look")
## Modulate applied to the floor tiles.
@export var floor_tint: Color = Color.WHITE
## Colour of full-cover pillars on this floor.
@export var pillar_color: Color = Color(0.46, 0.44, 0.52, 1.0)
## Modulate applied to half-cover debris.
@export var debris_tint: Color = Color.WHITE


## Builds a RoomSelector pool ([{template, weight}]) from parallel arrays.
## Null templates are skipped; a missing or non-positive weight counts as 1.0.
static func to_pool(templates: Array[RoomTemplate], weights: Array[float]) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for i: int in templates.size():
		if templates[i] == null:
			continue
		var w: float = weights[i] if i < weights.size() and weights[i] > 0.0 else 1.0
		pool.append({"template": templates[i], "weight": w})
	return pool


## Replaces [param selector]'s pools with this floor's pools.
func apply_to(selector: RoomSelector) -> void:
	if selector == null:
		return
	var no_weights: Array[float] = []
	selector.set_pools(
		to_pool(combat_templates, combat_weights),
		to_pool(elite_templates, elite_weights),
		to_pool(rest_templates, no_weights),
		to_pool(boss_templates, no_weights))
