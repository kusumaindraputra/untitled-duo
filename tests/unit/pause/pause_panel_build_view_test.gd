## pause_panel_build_view_test.gd — Pause shows the current build (beta plan U6).
##
## Coverage:
##   PB-01: repeated sigil picks group into one line with a stack count
##   PB-02: no sigils shows the empty text
##   PB-03: the spell card uses the same SpellPreview text as the preparation panel
##   PB-04: every button emits its signal
##   PB-05: PranaGrid exposes a copy of its slots for the view
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const PranaGridScript = preload("res://src/ui/prana_grid.gd")
const NAMES: Array = ["Ashfire", "Voidblue", "Stormgold", "Deepfrost", "Verdant"]
const COLORS: Array = [Color.RED, Color.BLUE, Color.YELLOW, Color.CYAN, Color.GREEN]


func _make_panel(data: Dictionary) -> PausePanel:
	var panel := PausePanel.new()
	add_child(panel)
	panel.setup(data)
	return panel


func _teardown(panel: PausePanel) -> void:
	remove_child(panel)
	panel.free()


# ── PB-01 ─────────────────────────────────────────────────────────────────────

func test_pause_sigil_lines_group_repeats_with_stack_count() -> void:
	var sigils: Array = [
		{"title": "Overcharge", "desc": "+35% spell damage"},
		{"title": "Swift Step", "desc": "+15% move speed"},
		{"title": "Overcharge", "desc": "+35% spell damage"},
	]

	var lines: Array[String] = PausePanel.sigil_lines(sigils, COPY)

	assert_int(lines.size()).is_equal(2)
	assert_str(lines[0]).is_equal(COPY.pause_sigil_format % ["Overcharge", COPY.pause_sigil_stack_format % 2, "+35% spell damage"])
	assert_str(lines[1]).is_equal(COPY.pause_sigil_format % ["Swift Step", "", "+15% move speed"])


# ── PB-02 ─────────────────────────────────────────────────────────────────────

func test_pause_no_sigils_shows_empty_text() -> void:
	var panel := _make_panel({})

	assert_str(panel.sigil_label.text).is_equal(COPY.pause_no_sigils)
	_teardown(panel)


# ── PB-03 ─────────────────────────────────────────────────────────────────────

func test_pause_spell_card_matches_preparation_preview() -> void:
	var summary: Dictionary = {"primary_type": 0, "primary_tier": 1, "primary_count": 1, "nonprimary": []}
	var card: Dictionary = SpellPreview.build(summary, [], null, NAMES, COPY)
	var grid: Array = [null, null, null, null, 0, null, null, null, null]

	var panel := _make_panel({"grid": grid, "spell_card": card, "colors": COLORS, "abbrevs": COPY.type_abbrevs})

	assert_str(panel.spell_label.text).is_equal(SpellPreview.to_bbcode(card, COLORS, COPY.type_abbrevs))
	_teardown(panel)


# ── PB-04 ─────────────────────────────────────────────────────────────────────

func test_pause_buttons_emit_signals() -> void:
	var panel := _make_panel({})
	var hits: Array[String] = []
	panel.resume_pressed.connect(func() -> void: hits.append("resume"))
	panel.settings_pressed.connect(func() -> void: hits.append("settings"))
	panel.quit_pressed.connect(func() -> void: hits.append("quit"))

	panel.resume_button.pressed.emit()
	panel.settings_button.pressed.emit()
	var buttons: Array[Node] = panel.resume_button.get_parent().get_children()
	(buttons[buttons.size() - 1] as Button).pressed.emit()

	assert_array(hits).contains_exactly(["resume", "settings", "quit"])
	_teardown(panel)


# ── PB-05 ─────────────────────────────────────────────────────────────────────

func test_prana_grid_slot_types_is_a_copy() -> void:
	var pg: PranaGrid = PranaGridScript.new()
	pg._slots.resize(PranaGrid.GRID_SIZE)
	pg._slots.fill(null)
	pg._slots[4] = 2

	var slots: Array = pg.get_slot_types()
	slots[4] = 0

	assert_int(pg._slots[4]).is_equal(2)
	assert_int(pg.get_type_colors().size()).is_equal(PranaTypeToken.type_count())
	pg.free()
