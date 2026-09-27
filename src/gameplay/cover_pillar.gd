## cover_pillar.gd — Full-cover pillar that stops enemy bullets and lasers (ADR-0020).
##
## Debris is half cover: it blocks movement, and bullets fly over it. A pillar is
## full cover: it blocks movement AND enemy fire. Every bullet that hits it chips it,
## and after [member max_hits] hits it crumbles, so hiding behind it only buys time.
## Mortars arc over pillars. Fayde's Prana passes through (spell queries ignore the layer).
##
## Physics: layer 6 (value 32, FULL_COVER). Projectile, PlayerController and
## EnemyInstance include this bit in their masks.
## GDD: design/gdd/stage-layout.md
class_name CoverPillar
extends StaticBody2D

## Emitted once when the pillar crumbles, with its global position.
signal destroyed(world_pos: Vector2)

## Physics layer value for full cover (layer 6 in the Godot UI).
const LAYER_FULL_COVER: int = 32
## Group every live pillar joins, for tests and debug overlays.
const GROUP: StringName = &"cover_pillar"
## Hits a laser beam deals to a pillar it is cut short by.
const LASER_HITS: int = 3
## Crack stages drawn as the pillar wears down (0 = intact).
const CRACK_STAGES: int = 3
## Seconds of white flash after a hit.
const HIT_FLASH_SEC: float = 0.08
## Visual column height above the footprint, in pixels.
const COLUMN_HEIGHT: float = 52.0
## Default rune band colour: E7 Warm Lantern Bleed (art bible §4.1). Environment
## glows never use a jewel tone, so the band is lantern-warm, not Prana cyan.
const RUNE_COLOR: Color = Color(0.659, 0.525, 0.376, 1.0)
## Outline tone for the column silhouette (art bible §5.4 outline colour).
const OUTLINE_COLOR: Color = Color(0.09, 0.07, 0.1, 1.0)

## Hits absorbed before crumbling. Set by setup() from ObstacleConfig.pillar_hits.
var max_hits: int = 14
## Collision / footprint radius in pixels.
var radius: float = 20.0
## Stone colour; floor themes tint it.
var color: Color = Color(0.46, 0.44, 0.52, 1.0)
## Rune band colour; the room passes its RoomLook.prop_glow (ADR-0039).
var rune_color: Color = RUNE_COLOR

var _hits_left: int = 14
var _flash: float = 0.0
var _broken: bool = false


func _init() -> void:
	collision_layer = LAYER_FULL_COVER
	collision_mask = 0


## Configures durability, size, stone colour and rune band colour. Call before add_child().
func setup(hits: int, pillar_radius: float, pillar_color: Color = Color(0.46, 0.44, 0.52, 1.0),
		band_color: Color = RUNE_COLOR) -> void:
	rune_color = band_color
	max_hits = maxi(hits, 1)
	_hits_left = max_hits
	radius = maxf(pillar_radius, 4.0)
	color = pillar_color


func _ready() -> void:
	_hits_left = mini(_hits_left, max_hits)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	add_to_group(GROUP)
	z_index = 5


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		queue_redraw()


## Absorbs [param amount] hits. Returns true when this call broke the pillar.
## No-op once broken.
func take_hit(amount: int = 1) -> bool:
	if _broken or amount <= 0:
		return false
	var before: int = crack_stage()
	_hits_left = maxi(_hits_left - amount, 0)
	_flash = HIT_FLASH_SEC
	queue_redraw()
	if _hits_left == 0:
		_break()
		return true
	if crack_stage() > before and is_inside_tree():
		_spawn_chips(4)
	return false


## Hits still needed to break the pillar.
func get_hits_left() -> int:
	return _hits_left


## True once the pillar has crumbled.
func is_broken() -> bool:
	return _broken


## 0 (intact) to CRACK_STAGES (about to break), from the hits taken so far.
func crack_stage() -> int:
	return crack_stage_for(_hits_left, max_hits)


## Pure: crack stage for [param hits_left] out of [param total] hits.
static func crack_stage_for(hits_left: int, total: int) -> int:
	if total <= 0:
		return 0
	var worn: float = 1.0 - float(clampi(hits_left, 0, total)) / float(total)
	return clampi(floori(worn * float(CRACK_STAGES + 1)), 0, CRACK_STAGES)


## Casts a beam from [param from] along [param angle] for [param length] px and
## returns where the first pillar cuts it: { "length": float, "pillar": CoverPillar or null }.
## Used by enemy lasers and sweep hazards. Safe without a world (returns the full length).
## [param mask] adds other blockers (sweep hazards also stop at the arena walls, layer 1);
## "pillar" is only set when the blocker is a CoverPillar.
static func cast_beam(world: World2D, from: Vector2, angle: float, length: float,
		mask: int = LAYER_FULL_COVER) -> Dictionary:
	var result: Dictionary = { "length": length, "pillar": null }
	if world == null or length <= 0.0:
		return result
	var space: PhysicsDirectSpaceState2D = world.direct_space_state
	if space == null:
		return result
	var to: Vector2 = from + Vector2.from_angle(angle) * length
	var query := PhysicsRayQueryParameters2D.create(from, to, mask)
	query.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return result
	result["length"] = from.distance_to(hit["position"] as Vector2)
	result["pillar"] = hit.get("collider") as CoverPillar
	return result


func _break() -> void:
	_broken = true
	Sfx.play(&"sfx_pillar_break")
	destroyed.emit(global_position)
	if not is_inside_tree():
		return
	# Changing the layer inside a body_entered flush is not allowed; defer it.
	set_deferred(&"collision_layer", 0)
	_spawn_chips(10)
	queue_free()


func _draw() -> void:
	var r: float = radius
	var base: Color = color.lerp(Color.WHITE, clampf(_flash / HIT_FLASH_SEC, 0.0, 1.0) * 0.7)
	var dark: Color = base.darkened(0.35)
	var light: Color = base.lightened(0.25)
	# Shadow on the floor.
	draw_colored_polygon(_ellipse(Vector2(0, 2), r * 1.2, r * 0.55), Color(0.05, 0.04, 0.06, 0.55))
	# Column: two side faces so it reads as a solid block in isometric view.
	var h: float = COLUMN_HEIGHT
	draw_colored_polygon(PackedVector2Array([
		Vector2(-r, 0), Vector2(0, r * 0.5), Vector2(0, r * 0.5 - h), Vector2(-r, -h),
	]), dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, r * 0.5), Vector2(r, 0), Vector2(r, -h), Vector2(0, r * 0.5 - h),
	]), base)
	# Cap.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-r, -h), Vector2(0, r * 0.5 - h), Vector2(r, -h), Vector2(0, -r * 0.5 - h),
	]), light)
	# Silhouette outline, hard-edged like the pixel sprites (art bible §5.4).
	draw_polyline(PackedVector2Array([
		Vector2(-r, 0), Vector2(0, r * 0.5), Vector2(r, 0), Vector2(r, -h),
		Vector2(0, -r * 0.5 - h), Vector2(-r, -h), Vector2(-r, 0),
	]), OUTLINE_COLOR, 1.0, false)
	# Rune band — reads as "this blocks shots", distinct from plain rock debris.
	var band_y: float = -h * 0.55
	draw_line(Vector2(-r, band_y), Vector2(0, band_y + r * 0.5), rune_color, 2.0, false)
	draw_line(Vector2(0, band_y + r * 0.5), Vector2(r, band_y), rune_color, 2.0, false)
	# Cracks grow with wear.
	var stage: int = crack_stage()
	var crack: Color = Color(0.08, 0.06, 0.08, 0.9)
	if stage >= 1:
		draw_polyline(PackedVector2Array([Vector2(-r * 0.6, -h * 0.9), Vector2(-r * 0.4, -h * 0.65), Vector2(-r * 0.65, -h * 0.4)]), crack, 1.0, false)
	if stage >= 2:
		draw_polyline(PackedVector2Array([Vector2(r * 0.5, -h * 0.95), Vector2(r * 0.3, -h * 0.6), Vector2(r * 0.55, -h * 0.35), Vector2(r * 0.35, -h * 0.1)]), crack, 1.0, false)
	if stage >= 3:
		draw_polyline(PackedVector2Array([Vector2(-r * 0.2, -h * 0.3), Vector2(0, -h * 0.15), Vector2(-r * 0.15, r * 0.2)]), crack, 2.0, false)


static func _ellipse(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in 16:
		var a: float = TAU * float(i) / 16.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## Small stone chips that fly out on crack and break. Parented to the room so they
## outlive the pillar.
func _spawn_chips(n: int) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var chips := _Chips.new()
	chips.color = color
	chips.count = n
	chips.position = position + Vector2(0, -COLUMN_HEIGHT * 0.5)
	parent_node.add_child(chips)


## Inner class: short burst of chips, frees itself after LIFE seconds.
class _Chips extends Node2D:
	const LIFE: float = 0.45
	var color: Color = Color.GRAY
	var count: int = 6
	var _t: float = 0.0
	var _dirs: Array[Vector2] = []

	func _ready() -> void:
		z_index = 6
		for i: int in count:
			var a: float = TAU * float(i) / float(maxi(count, 1)) + randf() * 0.5
			_dirs.append(Vector2.from_angle(a) * randf_range(30.0, 70.0))

	func _process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var p: float = _t / LIFE
		for d: Vector2 in _dirs:
			var pos: Vector2 = d * p + Vector2(0, 60.0 * p * p)
			draw_rect(Rect2(pos - Vector2(2, 2), Vector2(4, 4)), Color(color.r, color.g, color.b, 1.0 - p))
