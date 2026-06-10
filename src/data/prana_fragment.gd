## PranaFragment — A single Prana tile placed on the combination grid (GDD Rule 1).
##
## Represents one placed fragment at a grid position. `level` determines the
## fragment's tier weight and how many adjacency effects it contributes (N = level).
## `adjacency_effects` carries the effects this fragment may activate based on its
## neighbors at evaluation time (CR Story 005).
##
## This Resource is authored in the editor (PranaCatalog .tres files) and consumed
## read-only by CombinationResolution. Use `duplicate_deep()` if a per-instance
## mutable copy is needed (ADR-0008).
class_name PranaFragment
extends Resource

## Prana type identifier. 0=Ashfire, 1=Voidblue, 2=Stormgold, 3=Deepfrost,
## 4=Verdant. -1 = invalid / empty slot.
@export var type_id: int = -1

## Fragment level (tier). Must be >= 1. Determines tier weight used in primary
## type resolution and the number of adjacency effects this fragment contributes.
@export var level: int = 1

## Per-fragment stat property bonuses contributed to the wave's aggregate bonus.
## Keys are StringName stat IDs (e.g. &"ASH_DMG"). Values are additive float deltas.
## Untyped Dictionary — typed Dictionary[StringName, float] cannot be used with
## @export in GDScript 4.6.
@export var stat_property: Dictionary = {}

## Adjacency effects this fragment can activate based on its grid neighbors.
## Array[AdjacencyEffect]. Evaluated by the adjacency resolution pass (CR Story 005).
## Empty required_neighbors on an AdjacencyEffect means it always fires (GDD Rule 8).
@export var adjacency_effects: Array = []
