## main_menu_first_run_test.gd — Main menu for a first-time player (menu clean-up, 2026-09-29).
##
## Coverage:
##   MF-01: stats show only once the player has finished a run
##   MF-02: a fresh save hides the progress and records lines
##   MF-03: after one run the progress and records lines show
##   MF-04: the menu no longer shows the controls line
##   MF-05: both enlarged brothers fit inside the default viewport
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const MainMenuScript = preload("res://src/scenes/main_menu.gd")
const PATH: String = "user://test_main_menu_first_run.cfg"
const NO_RUN_SAVE: String = "user://test_no_run_save.cfg"
const VIEWPORT := Vector2(1152, 648)


func after_test() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _menu() -> Control:
	var menu: Control = MainMenuScript.new()
	menu.progress_path = PATH
	menu.run_save_path = NO_RUN_SAVE
	add_child(menu)
	return menu


func _teardown(menu: Control) -> void:
	remove_child(menu)
	menu.free()


func _label_texts(menu: Control) -> Array[String]:
	var texts: Array[String] = []
	for n: Node in menu.find_children("*", "Label", true, false):
		texts.append((n as Label).text)
	return texts


# ── MF-01 ─────────────────────────────────────────────────────────────────────

func test_main_menu_shows_stats_only_after_first_run() -> void:
	var p := MetaProgress.new()

	assert_bool(MainMenuScript.shows_stats(null)).is_false()
	assert_bool(MainMenuScript.shows_stats(p)).is_false()
	p.runs = 1
	assert_bool(MainMenuScript.shows_stats(p)).is_true()


# ── MF-02 ─────────────────────────────────────────────────────────────────────

func test_main_menu_fresh_save_hides_stats() -> void:
	var menu := _menu()

	assert_bool(menu._progress_label.visible).is_false()
	assert_bool(menu._records_label.visible).is_false()
	_teardown(menu)


# ── MF-03 ─────────────────────────────────────────────────────────────────────

func test_main_menu_after_one_run_shows_stats() -> void:
	var p := MetaProgress.new()
	p.runs = 1
	p.save_to(PATH)

	var menu := _menu()

	assert_bool(menu._progress_label.visible).is_true()
	assert_bool(menu._records_label.visible).is_true()
	_teardown(menu)


# ── MF-04 ─────────────────────────────────────────────────────────────────────

func test_main_menu_has_no_controls_line() -> void:
	var menu := _menu()

	assert_array(_label_texts(menu)).not_contains([InputPrompts.controls_line()])
	_teardown(menu)


# ── MF-05 ─────────────────────────────────────────────────────────────────────

func test_backdrop_brothers_fit_the_viewport() -> void:
	var fig: Vector2 = MenuBackdrop.IDLE_FRAME.size * MenuBackdrop.FIGURE_SCALE
	for c: int in [DuoSwap.Character.AYDEN, DuoSwap.Character.FAITH]:
		var feet: Vector2 = MenuBackdrop.feet_position(c, VIEWPORT)
		assert_float(feet.y - fig.y).is_greater_equal(0.0)
		assert_float(feet.y).is_less_equal(VIEWPORT.y)
		assert_float(feet.x + fig.x * 0.5).is_less_equal(VIEWPORT.x)
		# Clear of the left menu column (COLUMN_LEFT + COLUMN_WIDTH).
		assert_float(feet.x - fig.x * 0.5).is_greater_equal(MainMenuScript.COLUMN_LEFT + MainMenuScript.COLUMN_WIDTH)
