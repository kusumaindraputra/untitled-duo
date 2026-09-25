## camera_tuning_test.gd — Unit tests for CameraTuning (ADR-0024).
##
## Coverage:
##   visible_area() maps zoom to visible game px on the 1152×648 base viewport
##   Shipped tuning: combat zoom inside the bullet-readable range, prep wider than
##   boss reveal, boss reveal wider than combat
##
## GdUnit4 v6.1.3 | Godot 4.6
extends GdUnitTestSuite

## Safe combat-zoom band from ADR-0024: below 1.5 Fayde is too small to read,
## above 2.6 a 150 px/s bullet from the screen edge leaves under ~0.85 s to react.
const MIN_COMBAT_ZOOM: float = 1.5
const MAX_COMBAT_ZOOM: float = 2.6


func test_camera_visible_area_at_zoom_two_is_half_viewport() -> void:
	var area: Vector2 = CameraTuning.visible_area(2.0, Vector2(1152.0, 648.0))

	assert_vector(area).is_equal(Vector2(576.0, 324.0))


func test_camera_visible_area_non_positive_zoom_returns_viewport() -> void:
	var area: Vector2 = CameraTuning.visible_area(0.0, Vector2(1152.0, 648.0))

	assert_vector(area).is_equal(Vector2(1152.0, 648.0))


func test_camera_shipped_combat_zoom_within_safe_band() -> void:
	var t: CameraTuning = PlayerController.CAMERA_TUNING

	assert_float(t.combat_zoom).is_between(MIN_COMBAT_ZOOM, MAX_COMBAT_ZOOM)


func test_camera_shipped_zoom_order_prep_wider_than_boss_reveal_wider_than_combat() -> void:
	var t: CameraTuning = PlayerController.CAMERA_TUNING

	assert_float(t.prep_zoom).is_less(t.boss_reveal_zoom)
	assert_float(t.boss_reveal_zoom).is_less(t.combat_zoom)
