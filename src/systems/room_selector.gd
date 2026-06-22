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
	{"path": "res://assets/data/room_templates/template_corridor.tres", "weight": 2.0},
	{"path": "res://assets/data/room_templates/template_arena.tres",    "weight": 2.0},
]

const L1_ELITE_PRELOADS: Array[Dictionary] = [
	{"path": "res://assets/data/room_templates/template_split.tres",    "weight": 2.0},
	{"path": "res://assets/data/room_templates/template_corridor.tres", "weight": 2.0},
	{"path": "res://assets/data/room_templates/template_gauntlet.tres", "weight": 1.0},
]

const L1_REST_PRELOADS: Array[Dictionary] = [
	{"path": "res://assets/data/room_templates/template_rest.tres", "weight": 1.0},
]

const L1_BOSS_PRELOADS: Array[Dictionary] = [
	{"path": "res://assets/data/room_templates/template_boss.tres", "weight": 1.0},
]


# ── Variety constraint ─────────────────────────────────────────────────────────

## How many of the most-recently-assigned templates to avoid when picking the next
## one. 1 = only avoid the immediately-previous template (no back-to-back repeats).
## 2 = avoid the last two, forcing any three consecutive rooms to be distinct shapes —
## the default, which noticeably diversifies a floor. Always clamped to pool.size()-1
## so a pick can never exhaust its pool (single-template pools still reuse). (LD-18)
var variety_window: int = 2


# ── State ─────────────────────────────────────────────────────────────────────

var _combat_pool: Array[Dictionary] = []   ## [{template: RoomTemplate, weight: float}]
var _elite_pool:  Array[Dictionary] = []
var _rest_pool:   Array[Dictionary] = []
var _boss_pool:   Array[Dictionary] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _recent: Array[RoomTemplate] = []      ## rolling history of assigned templates (variety window)
var _assigned: Array[RoomTemplate] = []    ## per-index record, for diagnostics


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _init() -> void:
	_rng.randomize()
	_load_default_layer1_pools()


# ── Public API ─────────────────────────────────────────────────────────────────

## Assigns a RoomTemplate to each room in [param graph] based on its type.
## All four room types (Combat/Elite/Rest/Boss) draw from their respective pools.
## O(N) — walks rooms once in index order.
func assign(graph: DungeonGraph) -> void:
	_recent.clear()
	_assigned.clear()
	for i: int in range(graph.room_count()):
		var room: Dictionary = graph.get_room(i)
		var pool: Array[Dictionary] = _get_pool_for_type(int(room["type"]))
		var tmpl: RoomTemplate = null
		if not pool.is_empty():
			tmpl = _pick(pool, _recent)
		room["template"] = tmpl
		_assigned.append(tmpl)
		_recent.append(tmpl)


## Returns the template assigned to room [param idx] after the last assign() call.
## Returns null if idx is out of bounds or assign() hasn't been called.
func last_assigned_template(idx: int) -> RoomTemplate:
	if idx < 0 or idx >= _assigned.size():
		return null
	return _assigned[idx]


## Overrides all pools at once. Each entry is {template, weight}.
## Pass empty arrays to suppress template assignment for a type.
## Resets ALL four pools — rest and boss default to empty (null assignment) if omitted.
## Used by tests to inject controlled pools.
func set_pools(combat: Array[Dictionary], elite: Array[Dictionary],
		rest: Array[Dictionary] = [], boss: Array[Dictionary] = []) -> void:
	_combat_pool = combat
	_elite_pool = elite
	_rest_pool = rest
	_boss_pool = boss


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
	_rest_pool   = _resolve_preloads(L1_REST_PRELOADS)
	_boss_pool   = _resolve_preloads(L1_BOSS_PRELOADS)


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
		DungeonGraph.ROOM_TYPE_REST:
			return _rest_pool
		DungeonGraph.ROOM_TYPE_BOSS:
			return _boss_pool
		_:
			return []


## Weighted random pick from [param pool], avoiding the templates most recently
## assigned. The avoid set is the last min(variety_window, pool.size()-1) entries of
## [param recent], so a three-room run draws three distinct shapes when variety_window
## is 2. The pool.size()-1 clamp guarantees at least one candidate always survives, so
## single-template pools still reuse and the function never falls through empty. (LD-18)
func _pick(pool: Array[Dictionary], recent: Array[RoomTemplate]) -> RoomTemplate:
	var candidates: Array[Dictionary] = pool
	var window: int = mini(maxi(variety_window, 0), pool.size() - 1)
	if window > 0 and not recent.is_empty():
		var avoid: Dictionary = {}
		for k: int in range(1, window + 1):
			var idx: int = recent.size() - k
			if idx < 0:
				break
			var t: RoomTemplate = recent[idx]
			if t != null:
				avoid[t] = true
		if not avoid.is_empty():
			candidates = []
			for e: Dictionary in pool:
				if not avoid.has(e["template"]):
					candidates.append(e)
			if candidates.is_empty():
				candidates = pool   # all entries were avoided — fall back to full pool

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
