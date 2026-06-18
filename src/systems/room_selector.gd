## RoomSelector — template picker for typed dungeon rooms (LD-18).
##
## Walks a DungeonGraph (already typed by PathBuilder) and assigns a RoomTemplate
## to each room based on type and layer identity pools. Pool entries are weighted
## and support a variety constraint (no same template twice consecutively).
##
## Pure algorithm (RefCounted, no scene dependency). Consumed by DungeonGenerator
## (LD-19); input produced by PathBuilder (LD-17).
##
## Layer 1 pools are loaded on _init() from design/layer-identity.md.
## Override via set_pools() for Layer 2+ or unit test injection.
##
## Usage:
##   var graph: DungeonGraph = PathBuilder.new().generate(7)
##   var sel := RoomSelector.new()
##   sel.assign(graph)
##   var tmpl: RoomTemplate = sel.last_assigned_template(2)  # room 2's template
##
## GDD:     design/room-type-taxonomy.md (LD-06)
##          design/layer-identity.md     (LD-11)
## Roadmap: design/level-design-roadmap.md (LD-18)
class_name RoomSelector
extends RefCounted


# ── Default Layer 1 pools (from layer-identity.md § Template Pool) ────────────

const L1_COMBAT_PRELOADS: Array[Dictionary] = [
	{"path": "res://assets/data/room_templates/template_diamond.tres",  "weight": 3.0},
	{"path": "res://assets/data/room_templates/template_split.tres",    "weight": 2.0},
	{"path": "res://assets/data/room_templates/template_corridor.tres", "weight": 1.0},
	{"path": "res://assets/data/room_templates/template_arena.tres",    "weight": 2.0},
]

const L1_ELITE_PRELOADS: Array[Dictionary] = [
	{"path": "res://assets/data/room_templates/template_split.tres",    "weight": 2.0},
	{"path": "res://assets/data/room_templates/template_corridor.tres", "weight": 1.0},
	{"path": "res://assets/data/room_templates/template_gauntlet.tres", "weight": 1.0},
]


# ── State ─────────────────────────────────────────────────────────────────────

var _combat_pool: Array[Dictionary] = []   ## [{template: RoomTemplate, weight: float}]
var _elite_pool:  Array[Dictionary] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _last_template: RoomTemplate = null
var _assigned: Array[RoomTemplate] = []    ## per-index record, for diagnostics


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _init() -> void:
	_rng.randomize()
	_load_default_layer1_pools()


# ── Public API ─────────────────────────────────────────────────────────────────

## Assigns a RoomTemplate to each room in [param graph] based on its type.
## Rooms of type Rest (2) and Boss (3) get null — they have no templates yet.
## O(N) — walks rooms once in index order.
func assign(graph: DungeonGraph) -> void:
	_last_template = null
	_assigned.clear()
	for i: int in range(graph.room_count()):
		var room: Dictionary = graph.get_room(i)
		var pool: Array[Dictionary] = _get_pool_for_type(int(room["type"]))
		var tmpl: RoomTemplate = null
		if not pool.is_empty():
			tmpl = _pick(pool, _last_template)
		room["template"] = tmpl
		_assigned.append(tmpl)
		_last_template = tmpl


## Returns the template assigned to room [param idx] after the last assign() call.
## Returns null if idx is out of bounds or assign() hasn't been called.
func last_assigned_template(idx: int) -> RoomTemplate:
	if idx < 0 or idx >= _assigned.size():
		return null
	return _assigned[idx]


## Overrides the default Layer 1 pools. Each entry is {template, weight}.
## Pass empty arrays to suppress template assignment for a type.
## Used by tests to inject controlled pools.
func set_pools(combat: Array[Dictionary], elite: Array[Dictionary]) -> void:
	_combat_pool = combat
	_elite_pool = elite


## Returns the current combat pool (for test inspection).
func get_combat_pool() -> Array[Dictionary]:
	return _combat_pool


## Returns the current elite pool (for test inspection).
func get_elite_pool() -> Array[Dictionary]:
	return _elite_pool


# ── Private helpers ────────────────────────────────────────────────────────────

func _load_default_layer1_pools() -> void:
	_combat_pool = _resolve_preloads(L1_COMBAT_PRELOADS)
	_elite_pool  = _resolve_preloads(L1_ELITE_PRELOADS)


func _resolve_preloads(entries: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for e: Dictionary in entries:
		var path: String = str(e["path"])
		var res: Resource = load(path)
		if res != null and res is RoomTemplate:
			result.append({"template": res, "weight": float(e["weight"])})
		else:
			push_warning("RoomSelector: failed to load template at %s" % path)
	return result


func _get_pool_for_type(type: int) -> Array[Dictionary]:
	match type:
		DungeonGraph.ROOM_TYPE_COMBAT:
			return _combat_pool
		DungeonGraph.ROOM_TYPE_ELITE:
			return _elite_pool
		_:
			return []


## Weighted random pick from [param pool], avoiding [param avoid] unless the pool
## has only one entry (in which case consecutive reuse is allowed).
func _pick(pool: Array[Dictionary], avoid: RoomTemplate) -> RoomTemplate:
	var candidates: Array[Dictionary] = pool
	if avoid != null and pool.size() > 1:
		candidates = []
		for e: Dictionary in pool:
			if e["template"] != avoid:
				candidates.append(e)
		if candidates.is_empty():
			candidates = pool   # all entries were avoid — fall back to full pool

	var total: float = 0.0
	for c: Dictionary in candidates:
		total += float(c["weight"])

	var dart: float = _rng.randf() * total
	var accum: float = 0.0
	for c: Dictionary in candidates:
		accum += float(c["weight"])
		if dart < accum:
			return c["template"] as RoomTemplate

	# Floating-point fallback: return last candidate.
	return candidates[candidates.size() - 1]["template"] as RoomTemplate
