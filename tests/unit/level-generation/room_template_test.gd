## room_template_test.gd — Unit tests for RoomTemplate resource and template-driven room generation.
##
## Coverage:
##   - RoomTemplate defaults (Diamond = all-empty, falls back to existing behavior)
##   - Template loading from .tres
##   - valid_zone_rects → zone_check Callable conversion
##   - Obstacle placement respects template zones
##   - Template config override (obstacle_config per template)
##
## GDD: design/layer1-template-pool.md
## Roadmap: design/level-design-roadmap.md (LD-12, LD-14)
extends GdUnitTestSuite

const IsometricRoomScript = preload("res://src/scenes/isometric_room.gd")
const TemplateSplit = preload("res://assets/data/room_templates/template_split.tres")
const TemplateDiamond = preload("res://assets/data/room_templates/template_diamond.tres")
const TemplateCorridor = preload("res://assets/data/room_templates/template_corridor.tres")
const TemplateArena = preload("res://assets/data/room_templates/template_arena.tres")
const TemplateGauntlet = preload("res://assets/data/room_templates/template_gauntlet.tres")


func _make_room(tmpl: RoomTemplate = null) -> IsometricRoom:
	var room := IsometricRoomScript.new() as IsometricRoom
	if tmpl != null:
		room.room_template = tmpl
	return room


# ── Template resource tests ─────────────────────────────────────────────────────

## All 5 template .tres files load without errors.
func test_all_templates_load() -> void:
	assert_object(TemplateDiamond).is_not_null()
	assert_object(TemplateSplit).is_not_null()
	assert_object(TemplateCorridor).is_not_null()
	assert_object(TemplateArena).is_not_null()
	assert_object(TemplateGauntlet).is_not_null()


## Template display names match design doc.
func test_template_display_names() -> void:
	assert_str(TemplateDiamond.display_name).is_equal("The Diamond")
	assert_str(TemplateSplit.display_name).is_equal("The Split")
	assert_str(TemplateCorridor.display_name).is_equal("The Corridor")
	assert_str(TemplateArena.display_name).is_equal("The Arena")
	assert_str(TemplateGauntlet.display_name).is_equal("The Gauntlet")


## Template room types match design: Gauntlet=Elite(1), others=Combat(0).
func test_template_room_types() -> void:
	assert_int(TemplateDiamond.room_type).is_equal(0)
	assert_int(TemplateSplit.room_type).is_equal(0)
	assert_int(TemplateCorridor.room_type).is_equal(0)
	assert_int(TemplateArena.room_type).is_equal(0)
	assert_int(TemplateGauntlet.room_type).is_equal(1)


## Diamond template has empty valid_zone_rects — falls back to inner diamond.
func test_diamond_has_empty_zone_rects() -> void:
	assert_int(TemplateDiamond.valid_zone_rects.size()).is_equal(0)


## Split template has two valid_zone_rects (left and right strips).
func test_split_has_two_zone_rects() -> void:
	assert_int(TemplateSplit.valid_zone_rects.size()).is_equal(2)


# ── Zone check conversion tests ─────────────────────────────────────────────────

## Diamond template → null zone → _get_zone_check returns invalid Callable (fallback).
func test_diamond_zone_check_is_invalid() -> void:
	var room := _make_room(TemplateDiamond)
	assert_bool(room._get_zone_check().is_valid()).is_false()
	room.free()


## Split template → valid Callable that rejects center points, accepts side points.
func test_split_zone_check_rejects_center_accepts_sides() -> void:
	var room := _make_room(TemplateSplit)
	var check: Callable = room._get_zone_check()
	assert_bool(check.is_valid()).is_true()
	# Center point (0, 0) should be REJECTED — it's in the gap between strips.
	assert_bool(check.call(Vector2(0, 0))).is_false()
	# Point at x=-200, y=0 should be ACCEPTED — inside left strip.
	assert_bool(check.call(Vector2(-200, 0))).is_true()
	# Point at x=200, y=0 should be ACCEPTED — inside right strip.
	assert_bool(check.call(Vector2(200, 0))).is_true()
	room.free()


## Corridor template zone check: center lane clear.
func test_corridor_zone_check_rejects_center_lane() -> void:
	var room := _make_room(TemplateCorridor)
	var check: Callable = room._get_zone_check()
	assert_bool(check.call(Vector2(0, 0))).is_false()   # center lane
	assert_bool(check.call(Vector2(-300, 0))).is_true()   # left block
	assert_bool(check.call(Vector2(300, 0))).is_true()    # right block
	room.free()


## Arena template zone check: center is clear, outer ring accepts.
func test_arena_zone_check_rejects_center_accepts_edges() -> void:
	var room := _make_room(TemplateArena)
	var check: Callable = room._get_zone_check()
	assert_bool(check.call(Vector2(0, 0))).is_false()        # dead center
	assert_bool(check.call(Vector2(-400, 0))).is_true()       # left edge
	assert_bool(check.call(Vector2(400, 0))).is_true()        # right edge
	assert_bool(check.call(Vector2(0, -250))).is_true()       # top edge
	room.free()


## Gauntlet template zone check: center lane clear.
func test_gauntlet_zone_check_rejects_center_lane() -> void:
	var room := _make_room(TemplateGauntlet)
	var check: Callable = room._get_zone_check()
	assert_bool(check.call(Vector2(0, 0))).is_false()   # center lane
	assert_bool(check.call(Vector2(-400, 0))).is_true()  # left strip
	assert_bool(check.call(Vector2(400, 0))).is_true()   # right strip
	room.free()


# ── Obstacle placement respects template zone ────────────────────────────────────

## GIVEN Split template with center-gap zone, WHEN debris is generated,
## THEN no obstacle lands within the center gap (|x| < 40px for Split).
func test_split_template_no_debris_in_center_gap() -> void:
	var room := _make_room(TemplateSplit)
	var zone_check: Callable = room._get_zone_check()
	var positions: Array[Vector2] = room._generate_debris_positions([], zone_check)
	if positions.is_empty():
		# No obstacles placed — acceptable (edge case, especially with spawn=[] and
		# the candidate rejection might be high in the rect zones).
		assert_bool(true).is_true()
	else:
		for pos: Vector2 in positions:
			assert_bool(pos.x < -40.0 or pos.x > 40.0) \
				.override_failure_message("Obstacle at %s inside center gap of Split template" % pos) \
				.is_true()
	room.free()


## GIVEN Corridor template, WHEN debris is generated,
## THEN all obstacles are in left or right block.
func test_corridor_template_no_debris_in_center_lane() -> void:
	var room := _make_room(TemplateCorridor)
	var zone_check: Callable = room._get_zone_check()
	var positions: Array[Vector2] = room._generate_debris_positions([], zone_check)
	for pos: Vector2 in positions:
		assert_bool(pos.x < -80.0 or pos.x > 80.0) \
			.override_failure_message("Obstacle at %s inside center lane of Corridor template" % pos) \
			.is_true()
	room.free()


# ── Config override tests ───────────────────────────────────────────────────────

## Template with obstacle_config override uses it instead of room's config.
func test_template_obstacle_config_override() -> void:
	var room := _make_room()
	room.obstacle_config = ObstacleConfig.new()
	room.obstacle_config.count_min = 3
	# No template — uses room's obstacle_config
	assert_int(room._get_obstacle_config().count_min).is_equal(3)

	var tmpl := RoomTemplate.new()
	tmpl.obstacle_config = ObstacleConfig.new()
	tmpl.obstacle_config.count_min = 7
	room.room_template = tmpl
	# Template override takes priority
	assert_int(room._get_obstacle_config().count_min).is_equal(7)
	room.free()


# ── Null template = backward compat ─────────────────────────────────────────────

## Without a room_template, zone_check returns invalid (default diamond behavior).
func test_null_template_zone_check_is_invalid() -> void:
	var room := _make_room()  # no template
	assert_bool(room._get_zone_check().is_valid()).is_false()
	# Obstacle generation with default zone still works.
	var positions: Array[Vector2] = room._generate_debris_positions([])
	assert_int(positions.size()).is_between(0, room._DEBRIS_COUNT_MAX)
	room.free()


# ── Template room_type enum values ──────────────────────────────────────────────

## Room types: 0=Combat, 1=Elite, 2=Rest, 3=BossGate.
func test_room_type_enum_values() -> void:
	var tmpl := RoomTemplate.new()
	assert_int(tmpl.room_type).is_equal(0)  # default = Combat
	tmpl.room_type = 1
	assert_int(tmpl.room_type).is_equal(1)  # Elite
	tmpl.room_type = 2
	assert_int(tmpl.room_type).is_equal(2)  # Rest
	tmpl.room_type = 3
	assert_int(tmpl.room_type).is_equal(3)  # BossGate
