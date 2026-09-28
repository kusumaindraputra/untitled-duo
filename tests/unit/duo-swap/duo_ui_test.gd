## duo_ui_test.gd — the UI pass for the Ayden/Faith duo (ADR-0058).
##
## Coverage:
##   DUI-01: HUD faces sit Ayden left, heart, Faith right; the cooldown shade drains
##   DUI-02: DuoPortraits takes the state it is given
##   DUI-03: main menu backdrop stands Ayden left of Faith, both on the lit floor
##   DUI-04: the backdrop heart beats between 0 and 1
##   DUI-05: the duo preview line and the grid's hand labels use each brother's colour
##   DUI-06: the controls line names the swap and that only Faith dashes
##   DUI-07: no player-facing copy calls the player "Fayde"
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const Tracker = preload("res://src/core/input_prompts.gd")
const AYDEN: int = DuoSwap.Character.AYDEN
const FAITH: int = DuoSwap.Character.FAITH


# ── DUI-01 ────────────────────────────────────────────────────────────────────

func test_duo_faces_put_ayden_left_and_faith_right_of_the_heart() -> void:
	var box: Vector2 = DuoPortraits.box_size()

	assert_float(DuoPortraits.box_x(AYDEN)).is_equal(0.0)
	assert_float(DuoPortraits.box_x(FAITH)).is_greater(box.x + DuoPortraits.HEART_SIZE)


func test_duo_cooldown_shade_drains_as_the_swap_recharges() -> void:
	assert_float(DuoPortraits.shade_height(1.0, 28.0)).is_equal(28.0)
	assert_float(DuoPortraits.shade_height(0.5, 28.0)).is_equal(14.0)
	assert_float(DuoPortraits.shade_height(0.0, 28.0)).is_equal(0.0)
	assert_float(DuoPortraits.shade_height(-1.0, 28.0)).is_equal(0.0)


# ── DUI-02 ────────────────────────────────────────────────────────────────────

func test_duo_portraits_take_the_state() -> void:
	var p := DuoPortraits.new()

	p.set_state(FAITH, 0.25, 0.8, true)

	assert_int(p.active).is_equal(FAITH)
	assert_float(p.cooldown).is_equal(0.25)
	assert_float(p.heart).is_equal(0.8)
	assert_bool(p.severed).is_true()
	assert_float(p.size.x).is_greater(DuoPortraits.box_size().x * 2.0)
	p.free()


# ── DUI-03 / DUI-04 ───────────────────────────────────────────────────────────

func test_backdrop_stands_ayden_left_of_faith_on_one_floor() -> void:
	var area := Vector2(1600, 900)
	var a: Vector2 = MenuBackdrop.feet_position(AYDEN, area)
	var f: Vector2 = MenuBackdrop.feet_position(FAITH, area)

	assert_float(a.x).is_less(f.x)
	assert_float(a.y).is_equal(f.y)
	# Far enough apart that the two sprites don't overlap.
	assert_float(f.x - a.x).is_greater_equal(MenuBackdrop.IDLE_FRAME.size.x * MenuBackdrop.FIGURE_SCALE)
	assert_float(f.x).is_less(area.x)


func test_backdrop_heart_beats_between_zero_and_one() -> void:
	assert_float(MenuBackdrop.heart_pulse(0.0)).is_equal_approx(1.0, 0.0001)
	for i in 20:
		assert_float(MenuBackdrop.heart_pulse(float(i) * 0.137)).is_between(0.0, 1.0)


func test_backdrop_builds_both_brothers() -> void:
	var bd: MenuBackdrop = auto_free(MenuBackdrop.new())
	add_child(bd)

	assert_int(bd._figures.size()).is_equal(2)
	assert_bool(bd._figures.has(AYDEN)).is_true()
	assert_bool(bd._figures.has(FAITH)).is_true()


# ── DUI-05 ────────────────────────────────────────────────────────────────────

func test_duo_line_tints_each_brother() -> void:
	var line: String = COPY.duo_cores_format % ["Ashfire", "Deepfrost"]

	var out: String = SpellPreview.tint_brothers(line)

	assert_str(out).contains(DuoSwap.hud_color(AYDEN).to_html(false))
	assert_str(out).contains(DuoSwap.hud_color(FAITH).to_html(false))
	assert_str(out).contains("Ashfire")
	assert_str(out).contains("Deepfrost")


func test_hand_labels_take_each_brothers_colour() -> void:
	var ayden: Color = PranaGrid.hand_label_color(AYDEN, true)
	var faith_empty: Color = PranaGrid.hand_label_color(FAITH, false)

	assert_str(ayden.to_html(false)).is_equal(DuoSwap.hud_color(AYDEN).to_html(false))
	assert_float(ayden.a).is_equal(1.0)
	assert_str(faith_empty.to_html(false)).is_equal(DuoSwap.hud_color(FAITH).to_html(false))
	assert_float(faith_empty.a).is_less(1.0)


# ── DUI-06 ────────────────────────────────────────────────────────────────────

func test_controls_line_names_the_swap_and_faiths_dash() -> void:
	var t: Node = Tracker.new()
	t.using_pad = false

	var kb: String = t.controls_line()
	t.using_pad = true
	var pad: String = t.controls_line()

	assert_str(kb).contains("Swap")
	assert_str(kb).contains("Faith")
	assert_str(pad).contains("Swap")
	t.free()


# ── DUI-07 ────────────────────────────────────────────────────────────────────

func test_player_facing_copy_does_not_call_the_player_fayde() -> void:
	for text: String in [COPY.menu_subtitle, COPY.death_unknown, COPY.controls_format,
			COPY.controls_pad, COPY.dash_hint_benched]:
		assert_str(text).not_contains("Fayde")
