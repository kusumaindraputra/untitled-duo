## FloorMap — the floor's rooms as a small node map in the top-right HUD (beta plan U4).
##
## Replaces the flat letter row: rooms are placed in columns by depth from the entry
## room, so the branch after room 2 reads as a fork, and edges are drawn as lines.
## Visited rooms and the path already walked are bright; the current room has a gold
## ring. Each node keeps its letter (C / E / R / B, or ! / X for Challenge / Cursed) so
## types never depend on colour alone.
##
## CombatHUD owns it and calls [method set_floor]. Layout is a pure static function so
## it is unit-testable without a scene tree.
class_name FloorMap
extends Control

## Node radius, and spacing between columns and rows, in px.
const NODE_RADIUS: float = 8.0
const COL_SPACING: float = 24.0
const ROW_SPACING: float = 20.0
## Outer padding of the map's backing card, in px.
const PAD: float = 8.0
## Colours for the backing card, edges and the "you are here" ring.
const CARD_BG := Color(0.04, 0.04, 0.06, 0.62)
const EDGE_DIM := Color(1.0, 1.0, 1.0, 0.3)
const EDGE_WALKED := Color(1.0, 0.84, 0.3, 0.85)
const CURRENT_RING := Color(1.0, 0.84, 0.3)
const GLYPH_COLOR := Color(0.06, 0.05, 0.08)

## Room fill colours by DungeonGraph room type (Combat / Elite / Rest / Boss).
var type_colors: Array[Color] = []
## Letters by room type, and by RoomModifiers value (index 0 = none).
var type_letters: Array[String] = []
var mod_letters: Array[String] = []
var mod_colors: Array[Color] = []

var _types: Array = []
var _states: Array = []
var _mods: Array = []
var _edges: Array = []
var _current: int = -1
var _cells: Array[Vector2i] = []


## Places rooms in a grid: column = longest edge distance from [param entry], row = order
## of the room among rooms in that column (by index), rows centred on the tallest column.
## [param edges] holds Vector2i(from, to). Rooms not reachable from the entry go in
## column 0. Returns one Vector2i(column, row) per room.
static func compute_layout(count: int, edges: Array, entry: int) -> Array[Vector2i]:
	var depth: Array[int] = []
	depth.resize(count)
	depth.fill(-1)
	if entry >= 0 and entry < count:
		depth[entry] = 0
	# Longest-path relaxation on a DAG: repeat until stable (count passes at most).
	for _pass in count:
		var changed: bool = false
		for e: Variant in edges:
			var v: Vector2i = e
			if v.x < 0 or v.x >= count or v.y < 0 or v.y >= count or depth[v.x] < 0:
				continue
			if depth[v.y] < depth[v.x] + 1:
				depth[v.y] = depth[v.x] + 1
				changed = true
		if not changed:
			break
	var per_col: Dictionary = {}
	for i in count:
		var c: int = maxi(depth[i], 0)
		if not per_col.has(c):
			per_col[c] = []
		(per_col[c] as Array).append(i)
	var tallest: int = 1
	for c: int in per_col:
		tallest = maxi(tallest, (per_col[c] as Array).size())
	var cells: Array[Vector2i] = []
	cells.resize(count)
	for c: int in per_col:
		var rooms: Array = per_col[c]
		# Centre shorter columns: offset in half-rows, doubled to stay in integers.
		var offset: int = tallest - rooms.size()
		for r in rooms.size():
			cells[rooms[r]] = Vector2i(c, r * 2 + offset)
	return cells


## Pixel size of a layout from [method compute_layout] (rows are in half-row units).
static func layout_size(cells: Array[Vector2i]) -> Vector2:
	var max_c: int = 0
	var max_r: int = 0
	for cell in cells:
		max_c = maxi(max_c, cell.x)
		max_r = maxi(max_r, cell.y)
	return Vector2(float(max_c) * COL_SPACING, float(max_r) * ROW_SPACING * 0.5) \
		+ Vector2(NODE_RADIUS + PAD, NODE_RADIUS + PAD) * 2.0


## Sets the floor to draw and resizes the map to fit. [param edges] holds Vector2i(from, to).
func set_floor(types: Array, states: Array, mods: Array, edges: Array, current: int, entry: int) -> void:
	_types = types
	_states = states
	_mods = mods
	_edges = edges
	_current = current
	_cells = compute_layout(types.size(), edges, entry)
	size = layout_size(_cells)
	queue_redraw()


## Centre of room [param idx] in local px.
func node_center(idx: int) -> Vector2:
	var cell: Vector2i = _cells[idx]
	return Vector2(PAD + NODE_RADIUS + float(cell.x) * COL_SPACING,
		PAD + NODE_RADIUS + float(cell.y) * ROW_SPACING * 0.5)


func _visited(idx: int) -> bool:
	var st: int = int(_states[idx]) if idx < _states.size() else 0
	return st != 0 or idx == _current  # 0 == DungeonGraph.ROOM_STATE_UNVISITED


func _draw() -> void:
	if _cells.is_empty():
		return
	var card := StyleBoxFlat.new()
	card.bg_color = CARD_BG
	card.set_corner_radius_all(6)
	draw_style_box(card, Rect2(Vector2.ZERO, size))
	for e: Variant in _edges:
		var v: Vector2i = e
		if v.x >= _cells.size() or v.y >= _cells.size():
			continue
		var walked: bool = _visited(v.x) and _visited(v.y)
		draw_line(node_center(v.x), node_center(v.y), EDGE_WALKED if walked else EDGE_DIM, 2.0, true)
	var font: Font = get_theme_default_font()
	for i in _cells.size():
		var c: Vector2 = node_center(i)
		var t: int = int(_types[i])
		var col: Color = type_colors[t] if t >= 0 and t < type_colors.size() else Color.GRAY
		var visited: bool = _visited(i)
		col.a = 1.0 if visited else 0.4
		var mod: int = int(_mods[i]) if i < _mods.size() else 0
		if i == _current:
			draw_circle(c, NODE_RADIUS + 3.0, CURRENT_RING)
		elif mod > 0 and mod < mod_colors.size():
			draw_circle(c, NODE_RADIUS + 2.0, mod_colors[mod])
		draw_circle(c, NODE_RADIUS, col)
		var letter: String = type_letters[t] if t >= 0 and t < type_letters.size() else "?"
		if mod > 0 and mod < mod_letters.size():
			letter = mod_letters[mod]
		if font != null:
			var fs: int = 11
			var w: float = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var glyph: Color = GLYPH_COLOR
			glyph.a = 1.0 if visited else 0.7
			draw_string(font, c + Vector2(-w * 0.5, fs * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, glyph)
