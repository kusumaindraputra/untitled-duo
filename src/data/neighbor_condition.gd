## NeighborCondition — One directional neighbor requirement for an AdjacencyEffect.
##
## An AdjacencyEffect's `required_neighbors` is an Array[NeighborCondition].
## Each condition specifies which cardinal direction to check and what Prana type
## (if any) must occupy that position. All conditions in the array must be
## satisfied for the parent AdjacencyEffect to fire (GDD Rule 9).
##
## `required_type_id == -1` is a wildcard: any non-null fragment in that direction
## satisfies the condition.
class_name NeighborCondition
extends Resource

## Cardinal directions relative to the fragment being evaluated.
enum Direction { ABOVE = 0, BELOW = 1, LEFT = 2, RIGHT = 3 }

## The grid direction to inspect for a qualifying neighbor.
## Stored as int (enum index) for @export compatibility.
@export var direction: int = NeighborCondition.Direction.ABOVE

## Prana type required in the specified direction.
## -1 = wildcard (any non-null fragment satisfies this condition).
## 0–4 = specific Prana type ID must match.
@export var required_type_id: int = -1
