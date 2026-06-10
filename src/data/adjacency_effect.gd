## AdjacencyEffect — An effect that fires when a fragment's neighbor conditions are met.
##
## Each PranaFragment carries N AdjacencyEffect entries (N = fragment level, GDD Rule 1).
## During the adjacency evaluation pass (CR Story 005), each effect's
## `required_neighbors` conditions are checked against the grid. If all conditions
## pass, `effect_id` is added to SpellEffect.active_adjacency_effects.
##
## An empty `required_neighbors` array is vacuously satisfied — the effect always
## fires regardless of neighbors (GDD Rule 8). This is the intended authoring
## pattern for unconditional effects like &"ADJ_DOUBLE_HIT".
class_name AdjacencyEffect
extends Resource

## Neighbor conditions that must all be satisfied for this effect to activate.
## Array[NeighborCondition]. Empty = vacuously satisfied = always fires.
@export var required_neighbors: Array = []

## Identifier for the effect to apply when conditions are satisfied.
## Matches an EffectModifier entry in the effect pool (wired in CR Story 005).
## Example values: &"ADJ_DOUBLE_HIT", &"ADJ_PIERCE".
@export var effect_id: StringName = &""
