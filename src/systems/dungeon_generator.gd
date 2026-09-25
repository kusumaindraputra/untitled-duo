## DungeonGenerator — orchestrator for procedural dungeon generation (LD-19).
##
## Wires PathBuilder (LD-17) and RoomSelector (LD-18) to produce a fully-resolved
## DungeonGraph: rooms typed and templates assigned. Emits layer_generated on success.
##
## Pure algorithm (RefCounted, no scene dependency). Inject dependencies via
## set_path_builder() and set_room_selector() for tests or Layer 2+ configurations.
##
## Usage:
##   var gen := DungeonGenerator.new()
##   gen.layer_generated.connect(_on_layer_ready)
##   var graph := gen.generate(7, 1)
##
## GDD:     design/level-design-roadmap.md (LD-19)
## Depends: DungeonGraph (LD-16), PathBuilder (LD-17), RoomSelector (LD-18)
class_name DungeonGenerator
extends RefCounted

signal layer_generated(graph: DungeonGraph)

var _path_builder: PathBuilder = PathBuilder.new()
var _room_selector: RoomSelector = RoomSelector.new()


## Generates a fully-resolved [DungeonGraph] with [param room_count] rooms (≥5)
## on [param layer]. Returns null and push_warning on invalid input.
## Emits [signal layer_generated] on success.
func generate(room_count: int = 7, layer: int = 1) -> DungeonGraph:
	var graph: DungeonGraph = _path_builder.generate(room_count, layer)
	if graph == null:
		push_warning(
			"DungeonGenerator.generate: PathBuilder returned null for room_count=%d layer=%d."
				% [room_count, layer]
		)
		return null
	_room_selector.assign(graph)
	layer_generated.emit(graph)
	return graph


## Replaces the PathBuilder instance. Used for test injection or custom algorithms.
func set_path_builder(pb: PathBuilder) -> void:
	_path_builder = pb


## Uses [param theme]'s template pools for the next generate() calls (ADR-0020).
## null keeps the current pools.
func apply_floor_theme(theme: FloorTheme) -> void:
	if theme != null:
		theme.apply_to(_room_selector)


## Replaces the RoomSelector instance. Used for test injection or Layer 2+ pools.
func set_room_selector(rs: RoomSelector) -> void:
	_room_selector = rs
