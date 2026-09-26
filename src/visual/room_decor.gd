## RoomDecor — the floor's background props and the room's whimsy detail (ADR-0038).
##
## Everything here sits OFF the walkable floor: a raised stone ledge runs along
## the far (upper) boundary edges, one tile outside the floor, and rim props and
## the whimsy detail stand on it; face props hang on the slab face under the near
## (lower) edges. The ledge is drawn only, never added to the TileMapLayer. No node owns a
## collision shape or navigation obstacle, so the stage layout, collision and
## enemy pathing are exactly what they were without decor.
##
## Prop kinds come from the floor's RoomLook.motif (PropArt), counts from the look
## (art bible §6.4). Boss rooms get a single architectural accent instead of props.
class_name RoomDecor
extends Node2D

## Height of the back ledge above the floor, in pixels.
const LEDGE_RISE: float = 8.0
## Half-size of an iso tile (64×32).
const _HALF := Vector2(32.0, 16.0)
## Props and the whimsy detail are drawn at 2 world pixels per art pixel, like the
## bosses, so they read at the prep zoom.
const PIXEL_SCALE: float = 2.0
## Minimum distance between two rim props (and between a prop and the whimsy spot).
const MIN_BETWEEN: float = 130.0
## Rim props keep this far from exit doors and other keep-clear points.
const KEEP_CLEAR: float = 90.0
## Minimum distance between two hanging face props.
const FACE_MIN_BETWEEN: float = 140.0

var _ledge: Node2D = null
var _rim: Node2D = null
var _face: Node2D = null
var _whimsy: WhimsyDetail = null


## Builds the decor. [param upper_edges] and [param lower_edges] are boundary
## edges as [a, b] pairs; [param keep_clear] are points (doors, spawns) props stay
## away from; [param is_boss] swaps the props for one accent. Deterministic for a
## given [param rng_seed].
func build(look: RoomLook, upper_edges: Array[PackedVector2Array], lower_edges: Array[PackedVector2Array],
		keep_clear: Array[Vector2], is_boss: bool, rng_seed: int) -> void:
	name = "RoomDecor"
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var cells: Array[Vector2] = ledge_cells(upper_edges)
	_build_ledge(cells, look)
	_rim = Node2D.new()
	_rim.name = "RimProps"
	add_child(_rim)
	_face = Node2D.new()
	_face.name = "FaceProps"
	_face.z_index = -1  # under the tiles, over the platform edge
	add_child(_face)

	var anchors: Array[Vector2] = []
	for c: Vector2 in cells:
		anchors.append(c - Vector2(0.0, LEDGE_RISE))
	var kinds: Array[int] = PropArt.rim_props(look.motif)
	var count: int = 1 if is_boss else rng.randi_range(look.rim_props_min, maxi(look.rim_props_max, look.rim_props_min))
	var spots: Array[Vector2] = IsometricRoom.pick_spread_positions(
		anchors, count, keep_clear, KEEP_CLEAR, MIN_BETWEEN, 0.0, rng.randi())
	var last: int = -1
	for spot: Vector2 in spots:
		var prop: int = PropArt.Prop.BROKEN_COLUMN
		if not is_boss:
			prop = kinds[rng.randi() % kinds.size()]
			if prop == last and kinds.size() > 1:
				prop = kinds[(kinds.find(prop) + 1) % kinds.size()]
		last = prop
		_rim.add_child(_make_prop(prop, look, spot, rng.randf() < 0.5))

	if not is_boss and look.face_props > 0:
		var face_spots: Array[Vector2] = IsometricRoom.pick_spread_positions(
			face_anchors(lower_edges), look.face_props, [], 0.0, FACE_MIN_BETWEEN, 0.0, rng.randi())
		for spot: Vector2 in face_spots:
			_face.add_child(_make_prop(PropArt.face_prop(look.motif), look, spot, rng.randf() < 0.5))

	# One whimsy detail on a free rim spot (falls back to any rim spot).
	var taken: Array[Vector2] = keep_clear.duplicate()
	taken.append_array(spots)
	var whimsy_spot: Array[Vector2] = IsometricRoom.pick_spread_positions(
		anchors, 1, taken, 70.0, 0.0, 0.0, rng.randi())
	if whimsy_spot.is_empty() and not anchors.is_empty():
		whimsy_spot = [anchors[rng.randi() % anchors.size()]]
	if not whimsy_spot.is_empty() and not look.whimsy_kinds.is_empty():
		_whimsy = WhimsyDetail.new()
		_whimsy.setup(look.whimsy_kinds[rng.randi() % look.whimsy_kinds.size()], look, rng.randf() * 10.0)
		_whimsy.position = whimsy_spot[0].round()
		_whimsy.scale = Vector2(PIXEL_SCALE, PIXEL_SCALE)
		_whimsy.z_index = _depth(whimsy_spot[0])
		add_child(_whimsy)


## Rim props (tests).
func get_rim_props() -> Array[Node]:
	return _rim.get_children() if _rim != null else []


## Hanging face props (tests).
func get_face_props() -> Array[Node]:
	return _face.get_children() if _face != null else []


## The room's whimsy detail, or null (tests).
func get_whimsy() -> WhimsyDetail:
	return _whimsy


## The raised back ledge node (tests).
func get_ledge() -> Node2D:
	return _ledge


## Centres of the tiles just outside each upper boundary edge: the tile that shares
## that edge with the floor, mirrored across it. Deduplicated, in edge order.
static func ledge_cells(upper_edges: Array[PackedVector2Array]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var seen: Dictionary = {}
	for e: PackedVector2Array in upper_edges:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var mid: Vector2 = (a + b) * 0.5
		# a is the left end. Rising edge (left corner → top corner): the outside tile
		# lies up-left; falling edge (top corner → right corner): up-right.
		var c: Vector2 = mid + (Vector2(-_HALF.x, -_HALF.y) if a.y > b.y else Vector2(_HALF.x, -_HALF.y)) * 0.5
		var key := Vector2i(roundi(c.x), roundi(c.y))
		if seen.has(key):
			continue
		seen[key] = true
		out.append(Vector2(key))
	return out


## Draws the raised ledge: a top diamond lifted by LEDGE_RISE with its two near
## faces dropping back to floor level. Drawn above the floor tiles (z 1) and below
## every character (z >= 1 + y offset keeps characters on top at the far rim).
func _build_ledge(cells: Array[Vector2], look: RoomLook) -> void:
	_ledge = Node2D.new()
	_ledge.name = "RimLedge"
	_ledge.z_index = 1
	add_child(_ledge)
	var top_col: Color = look.edge_face.lerp(look.floor_base, 0.55)
	var rise := Vector2(0.0, -LEDGE_RISE)
	# Far tiles first so nearer ledge caps cover the faces behind them.
	var ordered: Array[Vector2] = cells.duplicate()
	ordered.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.y < q.y)
	for c: Vector2 in ordered:
		var top := c + Vector2(0.0, -_HALF.y) + rise
		var right := c + Vector2(_HALF.x, 0.0) + rise
		var bottom := c + Vector2(0.0, _HALF.y) + rise
		var left := c + Vector2(-_HALF.x, 0.0) + rise
		var face_l := Polygon2D.new()
		face_l.polygon = PackedVector2Array([left, bottom, bottom - rise, left - rise])
		face_l.color = look.edge_face
		_ledge.add_child(face_l)
		var face_r := Polygon2D.new()
		face_r.polygon = PackedVector2Array([bottom, right, right - rise, bottom - rise])
		face_r.color = look.edge_face.darkened(0.25)
		_ledge.add_child(face_r)
		var cap := Polygon2D.new()
		cap.polygon = PackedVector2Array([top, right, bottom, left])
		cap.color = top_col
		_ledge.add_child(cap)
		var lip := Line2D.new()
		lip.points = PackedVector2Array([left, top, right])
		lip.width = 1.0
		lip.default_color = look.floor_highlight.darkened(0.2)
		_ledge.add_child(lip)


## Hang points on the slab face just under each lower boundary edge's midpoint.
static func face_anchors(lower_edges: Array[PackedVector2Array]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for e: PackedVector2Array in lower_edges:
		out.append((e[0] + e[1]) * 0.5 + Vector2(0.0, 1.0))
	return out


## Same depth rule as characters (z = y + 500), so anything nearer the camera draws over rim props.
static func _depth(p: Vector2) -> int:
	return clampi(int(p.y) + 500, 1, 2000)


func _make_prop(prop: int, look: RoomLook, anchor: Vector2, flip: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = str(PropArt.Prop.keys()[prop]).to_pascal_case()
	s.set_meta(&"prop", prop)
	s.texture = PropArt.texture(prop, look)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.flip_h = flip
	var h: float = s.texture.get_height()
	# Standing props rest their base on the anchor; hanging props dangle from it.
	s.offset = Vector2(0.0, h * 0.5) if PropArt.hangs(prop) else Vector2(0.0, -h * 0.5 + 2.0)
	s.position = anchor.round()
	s.scale = Vector2(PIXEL_SCALE, PIXEL_SCALE)
	if not PropArt.hangs(prop):
		s.z_index = _depth(anchor)
	return s
