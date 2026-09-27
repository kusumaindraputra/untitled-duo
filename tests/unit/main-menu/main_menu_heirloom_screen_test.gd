## main_menu_heirloom_screen_test.gd — Main menu layout and the Heirloom screen (beta plan U7).
##
## Coverage:
##   MM-01: button text follows locked / unlocked / equipped state
##   MM-02: pressing a locked, affordable Heirloom unlocks it, saves and signals the menu
##   MM-03: pressing an unlocked Heirloom equips it; pressing again unequips it
##   MM-04: description hint says "not enough shards" when the player cannot afford it
##   MM-05: menu buttons run Play / Heirlooms / Spellbook / Memories / Settings / Quit in order
##   MM-06: backdrop motes wrap inside the area and hold still without animation
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const META: MetaTuning = preload("res://assets/data/meta_tuning.tres")
const MainMenuScript = preload("res://src/scenes/main_menu.gd")
const PATH: String = "user://test_heirloom_screen.cfg"


func after_test() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _screen(p: MetaProgress) -> HeirloomScreen:
	var screen := HeirloomScreen.new()
	screen.progress = p
	screen.progress_path = PATH
	add_child(screen)
	return screen


func _teardown(screen: HeirloomScreen) -> void:
	remove_child(screen)
	screen.free()


func _title(id: StringName) -> String:
	return str(MetaProgress.heirloom_info(id).get("title", id))


# ── MM-01 ─────────────────────────────────────────────────────────────────────

func test_heirloom_button_text_follows_state() -> void:
	var id: StringName = META.heirloom_ids[0]
	var p := MetaProgress.new()

	assert_str(HeirloomScreen.button_text(p, id)).is_equal(COPY.heirloom_locked_format % [_title(id), META.cost_of(id)])
	p.unlocked.append(id)
	assert_str(HeirloomScreen.button_text(p, id)).is_equal(COPY.heirloom_unlocked_format % _title(id))
	p.equipped = id
	assert_str(HeirloomScreen.button_text(p, id)).is_equal(COPY.heirloom_equipped_format % _title(id))


# ── MM-02 ─────────────────────────────────────────────────────────────────────

func test_heirloom_press_unlocks_saves_and_signals() -> void:
	var id: StringName = META.heirloom_ids[0]
	var p := MetaProgress.new()
	p.shards = META.cost_of(id)
	var screen := _screen(p)
	var signalled: Array[bool] = [false]
	screen.progress_changed.connect(func() -> void: signalled[0] = true)

	screen.press(id)

	assert_bool(p.is_unlocked(id)).is_true()
	assert_bool(signalled[0]).is_true()
	assert_bool(MetaProgress.load_from(PATH).is_unlocked(id)).is_true()
	assert_str(screen.buttons()[0].text).is_not_equal(COPY.heirloom_locked_format % [_title(id), META.cost_of(id)])
	_teardown(screen)


# ── MM-03 ─────────────────────────────────────────────────────────────────────

func test_heirloom_press_toggles_equip() -> void:
	var id: StringName = META.heirloom_ids[1]
	var p := MetaProgress.new()
	p.unlocked.append(id)
	var screen := _screen(p)

	screen.press(id)
	assert_str(String(p.equipped)).is_equal(String(id))
	screen.press(id)
	assert_str(String(p.equipped)).is_not_equal(String(id))
	_teardown(screen)


# ── MM-04 ─────────────────────────────────────────────────────────────────────

func test_heirloom_description_says_not_enough_shards() -> void:
	var id: StringName = META.heirloom_ids[0]
	var p := MetaProgress.new()
	p.shards = 0

	assert_str(HeirloomScreen.desc_text(p, id)).ends_with(COPY.heirloom_hint_poor)


# ── MM-05 ─────────────────────────────────────────────────────────────────────

func test_main_menu_buttons_in_order() -> void:
	var menu: Control = MainMenuScript.new()
	menu.progress = MetaProgress.new()
	menu.progress_path = PATH
	menu.run_save_path = "user://test_no_run_save.cfg"  # ADR-0048: no Continue button
	add_child(menu)
	# _ready() loads progress from progress_path (empty) and builds the layout.

	var texts: Array[String] = []
	for b: Node in menu._play_button.get_parent().get_children():
		# Hidden buttons (the ADR-0052 Ascension button without Hard Mode) are not in the menu.
		if b is Button and not b is CheckButton and (b as Button).visible:
			texts.append((b as Button).text)

	var book: Vector2i = Spellbook.progress(menu.progress)
	assert_array(texts).contains_exactly([COPY.menu_play, COPY.menu_heirlooms,
		COPY.spellbook_button_format % [book.x, book.y],
		COPY.memories_button_format % [0, StoryRules.total()], COPY.settings_button, COPY.menu_quit])
	remove_child(menu)
	menu.free()


# ── MM-06 ─────────────────────────────────────────────────────────────────────

func test_backdrop_motes_wrap_inside_area() -> void:
	var area := Vector2(400, 300)
	for i in MenuBackdrop.MOTE_COUNT:
		var p: Vector2 = MenuBackdrop.mote_position(i, 1000.0, area)
		assert_float(p.y).is_between(0.0, area.y)


func test_backdrop_holds_still_without_animation() -> void:
	var bd := MenuBackdrop.new()
	bd.animate = false

	bd._process(1.0)

	assert_float(bd._time).is_equal(0.0)
	bd.free()
