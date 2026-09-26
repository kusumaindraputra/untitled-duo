## PausePanel — the pause overlay with the current build beside the menu (beta plan U6).
##
## Left: the menu buttons. Right: the active Prana grid as a small 3×3, the spell it
## casts (the same SpellPreview card the preparation panel shows) and the sigils taken
## this run with what each does. Built from a plain Dictionary so it never reads game
## state itself; the game loop assembles the data and connects the signals
## (parent-owned wiring). All text comes from UICopy.
##
## Data keys: grid (Array of 9 type ids or null), spell_card (Dictionary from
## PranaGrid.build_spell_card()), colors (Array[Color]) and abbrevs (Array[String]) in
## type_id order, sigils (Array of { "title": String, "desc": String }, one per pick),
## map (FloorMap.snapshot() of the HUD map; when set, a third column shows it larger
## with a legend of room letters and enemy threat icons, ADR-0032).
class_name PausePanel
extends Control

signal resume_pressed
signal restart_pressed
signal settings_pressed
signal spellbook_pressed
signal tutorial_pressed
signal main_menu_pressed
signal quit_pressed

const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const BG_COLOR := Color(0.04, 0.03, 0.06, 0.9)
const TITLE_COLOR := Color(1.0, 0.85, 0.3)
const CARD_BG := Color(0.05, 0.05, 0.07, 0.92)
const CARD_BORDER := Color(1.0, 1.0, 1.0, 0.12)
const LABEL_COLOR := Color(0.62, 0.62, 0.68)
const EMPTY_SLOT := Color(0.14, 0.14, 0.18)
const BUTTON_SIZE := Vector2(240, 48)
const CARD_WIDTH: float = 360.0
const CELL_SIZE: float = 30.0
## Size of the pause floor map relative to the HUD one.
const MAP_SCALE: float = 1.25
## Legend swatch size and text size.
const SWATCH_SIZE: float = 18.0
const LEGEND_FONT_SIZE: int = 13

## Holds the title and both columns; hidden while the Settings panel is open.
var menu_box: VBoxContainer = null
## Focused on open so Enter / A resumes.
var resume_button: Button = null
## Focus returns here when the Spellbook closes.
var spellbook_button: Button = null
## Focus returns here when Settings closes.
var settings_button: Button = null
## The spell card text, for tests.
var spell_label: RichTextLabel = null
## The sigil list text, for tests.
var sigil_label: Label = null
## The large floor map (null without map data). For tests.
var floor_map: FloorMap = null
## Legend rows text, in order. For tests.
var legend_texts: Array[String] = []


## Groups repeated picks: [{title, desc}, …] → one line per sigil in first-pick order,
## with a stack count when taken more than once.
static func sigil_lines(sigils: Array, copy: UICopy) -> Array[String]:
	var order: Array[String] = []
	var counts: Dictionary = {}
	var descs: Dictionary = {}
	for s: Dictionary in sigils:
		var title: String = str(s.get("title", ""))
		if not counts.has(title):
			order.append(title)
			counts[title] = 0
			descs[title] = str(s.get("desc", ""))
		counts[title] = int(counts[title]) + 1
	var lines: Array[String] = []
	for title in order:
		var n: int = counts[title]
		var stack: String = copy.pause_sigil_stack_format % n if n > 1 else ""
		lines.append(copy.pause_sigil_format % [title, stack, descs[title]])
	return lines


func _ready() -> void:
	UIFeel.fade_in(self)


## Builds the overlay from [param data] (see class doc).
func setup(data: Dictionary) -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	menu_box = VBoxContainer.new()
	menu_box.anchor_right = 1.0
	menu_box.anchor_bottom = 1.0
	menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_box.add_theme_constant_override(&"separation", 22)
	add_child(menu_box)

	var title := Label.new()
	title.text = _COPY.pause_title
	title.add_theme_font_size_override(&"font_size", 52)
	title.add_theme_color_override(&"font_color", TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(title)

	var columns := HBoxContainer.new()
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_theme_constant_override(&"separation", 36)
	menu_box.add_child(columns)

	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 12)
	columns.add_child(buttons)
	resume_button = _button(buttons, InputPrompts.pick(_COPY.pause_resume, _COPY.pause_resume_pad), resume_pressed)
	_button(buttons, InputPrompts.pick(_COPY.pause_restart, _COPY.pause_restart_pad), restart_pressed)
	spellbook_button = _button(buttons, _COPY.spellbook_title.capitalize(), spellbook_pressed)
	settings_button = _button(buttons, _COPY.settings_button.capitalize(), settings_pressed)
	_button(buttons, _COPY.coach_replay_button, tutorial_pressed)
	_button(buttons, _COPY.pause_main_menu, main_menu_pressed)
	_button(buttons, _COPY.pause_quit, quit_pressed)

	columns.add_child(_build_card(data))
	var map: Dictionary = data.get("map", {})
	if not map.is_empty():
		columns.add_child(_build_map_card(map))


func _build_card(data: Dictionary) -> Control:
	var card := _card_panel()
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	card.add_child(box)
	box.add_child(_label(_COPY.pause_build_title, 14, LABEL_COLOR))

	var colors: Array = data.get("colors", [])
	var abbrevs: Array = data.get("abbrevs", [])
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	box.add_child(row)
	row.add_child(_mini_grid(data.get("grid", []), colors, abbrevs))

	spell_label = RichTextLabel.new()
	spell_label.bbcode_enabled = true
	spell_label.fit_content = true
	spell_label.scroll_active = false
	spell_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spell_label.add_theme_font_size_override(&"normal_font_size", 13)
	spell_label.add_theme_font_size_override(&"bold_font_size", 14)
	var spell_card: Dictionary = data.get("spell_card", {})
	if not spell_card.is_empty():
		spell_label.text = SpellPreview.to_bbcode(spell_card, colors, abbrevs)
	row.add_child(spell_label)

	box.add_child(_label(_COPY.pause_sigils_title, 14, LABEL_COLOR))
	var lines: Array[String] = sigil_lines(data.get("sigils", []), _COPY)
	sigil_label = _label(_COPY.pause_no_sigils if lines.is_empty() else "\n".join(PackedStringArray(lines)),
		13, Color.WHITE)
	sigil_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sigil_label.theme_type_variation = UIFeel.BODY_TEXT
	sigil_label.custom_minimum_size = Vector2(CARD_WIDTH - 32.0, 0)
	box.add_child(sigil_label)
	return card


## ADR-0032: the floor map at MAP_SCALE, then what its letters and rings mean, then
## the enemy threat icons shown during preparation.
func _build_map_card(map: Dictionary) -> Control:
	var card := _card_panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	card.add_child(box)
	box.add_child(_label(_COPY.map_title, 14, LABEL_COLOR))
	floor_map = FloorMap.from_snapshot(map, MAP_SCALE)
	floor_map.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(floor_map)

	var rooms := _legend_grid(box)
	var type_colors: Array = map.get("type_colors", [])
	var type_letters: Array = map.get("type_letters", [])
	for i in _COPY.map_room_names.size():
		var col: Color = type_colors[i] if i < type_colors.size() else Color.GRAY
		var letter: String = str(type_letters[i]) if i < type_letters.size() else "?"
		_legend_row(rooms, _COPY.map_room_names[i], _Swatch.room(col, letter, Color.TRANSPARENT))
	var mod_colors: Array = map.get("mod_colors", [])
	var mod_letters: Array = map.get("mod_letters", [])
	for i in range(1, _COPY.map_mod_names.size()):
		var ring: Color = mod_colors[i] if i < mod_colors.size() else Color.WHITE
		var letter: String = str(mod_letters[i]) if i < mod_letters.size() else "?"
		_legend_row(rooms, _COPY.map_mod_names[i], _Swatch.room(Color(0.35, 0.35, 0.4), letter, ring))
	_legend_row(rooms, _COPY.map_you_are_here, _Swatch.room(Color(0.35, 0.35, 0.4), "", FloorMap.CURRENT_RING))
	_legend_row(rooms, _COPY.map_visited, _Swatch.room(Color(0.35, 0.35, 0.4), "", FloorMap.EDGE_WALKED, true))

	box.add_child(_label(_COPY.map_threats_title, 14, LABEL_COLOR))
	var threats := _legend_grid(box)
	for k in _COPY.threat_names.size():
		_legend_row(threats, _COPY.threat_names[k], _Swatch.threat(k))
	return card


func _legend_grid(parent: Control) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override(&"h_separation", 14)
	g.add_theme_constant_override(&"v_separation", 4)
	parent.add_child(g)
	return g


func _legend_row(grid: GridContainer, text: String, swatch: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	swatch.custom_minimum_size = Vector2(SWATCH_SIZE, SWATCH_SIZE)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatch)
	row.add_child(_label(text, LEGEND_FONT_SIZE, Color.WHITE))
	grid.add_child(row)
	legend_texts.append(text)


func _card_panel() -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_BG
	sb.border_color = CARD_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(16)
	card.add_theme_stylebox_override(&"panel", sb)
	return card


## A 3×3 of coloured cells with element abbreviations; empty slots stay dark.
func _mini_grid(grid: Array, colors: Array, abbrevs: Array) -> Control:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override(&"h_separation", 3)
	g.add_theme_constant_override(&"v_separation", 3)
	g.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for i in 9:
		var t: Variant = grid[i] if i < grid.size() else null
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(3)
		sb.bg_color = EMPTY_SLOT
		if t != null and int(t) >= 0 and int(t) < colors.size():
			sb.bg_color = colors[int(t)]
		if i == 4:
			sb.border_color = TITLE_COLOR
			sb.set_border_width_all(2)
		cell.add_theme_stylebox_override(&"panel", sb)
		if t != null and int(t) >= 0 and int(t) < abbrevs.size():
			var l := _label(str(abbrevs[int(t)]), 10, Color(0.06, 0.05, 0.08))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cell.add_child(l)
		g.add_child(cell)
	return g


func _button(parent: Control, text: String, sig: Signal) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	b.add_theme_font_size_override(&"font_size", 20)
	b.pressed.connect(func() -> void: sig.emit())
	parent.add_child(b)
	return b


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", color)
	return l


## One legend swatch: a room node (fill, letter, optional ring) or a threat icon.
class _Swatch extends Control:
	var fill: Color = Color.GRAY
	var letter: String = ""
	var ring: Color = Color.TRANSPARENT
	var dim_pair: bool = false
	var threat_kind: int = -1

	static func room(f: Color, l: String, r: Color, pair: bool = false) -> _Swatch:
		var s := _Swatch.new()
		s.fill = f
		s.letter = l
		s.ring = r
		s.dim_pair = pair
		return s

	static func threat(k: int) -> _Swatch:
		var s := _Swatch.new()
		s.threat_kind = k
		return s

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - 1.0
		if threat_kind >= 0:
			ThreatIcon.draw_icon(self, threat_kind as ThreatIcon.Kind, c, r, Color(0.7, 0.7, 0.75), false)
			return
		if dim_pair:
			# A bright node joined to a dim one: visited vs. not yet.
			draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), ring, 2.0, true)
			draw_circle(c + Vector2(-r * 0.55, 0), r * 0.5, Color(0.85, 0.85, 0.9))
			draw_circle(c + Vector2(r * 0.55, 0), r * 0.5, Color(0.85, 0.85, 0.9, 0.4))
			return
		if ring.a > 0.0:
			draw_circle(c, r, ring)
		draw_circle(c, r - (2.5 if ring.a > 0.0 else 0.0), fill)
		if not letter.is_empty():
			var font: Font = get_theme_default_font()
			var fs: int = 12
			var w: float = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, c + Vector2(-w * 0.5, fs * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				FloorMap.GLYPH_COLOR)
