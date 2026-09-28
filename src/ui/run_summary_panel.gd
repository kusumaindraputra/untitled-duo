## RunSummaryPanel — the end-of-run screen (beta plan U5).
##
## Shows the result, floor and rooms, a stat column (time, enemies, best combo, bosses
## beaten, room ranks, Cipher Shards), the sigils taken this run and the memories
## recovered, with Run Again and Main Menu buttons. Built from a plain Dictionary so it
## never reads game state itself; the game loop assembles the data and wires the buttons
## (parent-owned wiring). All text comes from UICopy.
##
## Data keys: win (bool), floor (int), rooms (int), time_sec (float), enemies (int),
## best_combo (int), bosses (int), ranks (Array[String]), shards (int),
## sigils (Array[String] titles), memories_new (int), memories_found (int),
## memories_total (int), hard_unlocked (bool), ascension_unlocked (int: level a win just
## opened, 0 = none), ascension (int: level played), assist (bool), records (Array[String]
## lines for records set this run), death (String: the DeathRecap line; shown on a loss),
## prana_color (Color: the last Prana in Fayde's hands; tints the crumple on a loss).
class_name RunSummaryPanel
extends Control

## Pressed Run Again / Main Menu.
signal run_again_pressed
signal main_menu_pressed

const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")
## Rank display order, best first.
const RANK_ORDER: Array[String] = ["S", "A", "B", "C", "D"]
const WIN_COLOR := UIPalette.ACCENT
## Defeat is "a story cut short", not punishment (art bible §2.5): cool, not red.
const LOSS_COLOR := UIPalette.COOL
const LABEL_COLOR := UIPalette.TEXT_DIM
const VALUE_COLOR := Color(1.0, 0.92, 0.7)
const CARD_BG := UIPalette.CARD_SOLID
const DEATH_COLOR := UIPalette.WARN
## ADR-0042 — the defeat crumple portrait: drained of warmth (§2.5), so the last
## Prana in Fayde's hands is the only warm colour left.
const CRUMPLE_TINT := Color(0.7, 0.75, 0.86)
const _JUICE: HudJuiceTuning = preload("res://assets/data/hud_juice_tuning.tres")

## The Run Again button (focused on open so Enter / A replays). Null until setup().
var run_again_button: Button = null
## Opens the feedback form (ADR-0045). Null when no form URL is configured.
var feedback_button: Button = null
## The death recap line (null on a win or without one). For tests.
var death_label: Label = null
## The crumple portrait beside the stat cards (null on a win). For tests.
var crumple: CrumplePose = null


## Formats seconds as M:SS.
static func format_time(seconds: float) -> String:
	var total: int = int(seconds)
	return "%d:%02d" % [total / 60, total % 60]


## Counts room ranks best-first, e.g. ["B","A","B"] → "A×1  B×2". Unknown letters go last.
static func rank_summary(ranks: Array, empty_text: String) -> String:
	if ranks.is_empty():
		return empty_text
	var counts: Dictionary = {}
	for r: Variant in ranks:
		counts[str(r)] = int(counts.get(str(r), 0)) + 1
	var parts: PackedStringArray = PackedStringArray()
	for letter: String in RANK_ORDER:
		if counts.has(letter):
			parts.append("%s×%d" % [letter, counts[letter]])
			counts.erase(letter)
	for letter: String in counts:
		parts.append("%s×%d" % [letter, counts[letter]])
	return "  ".join(parts)


## The stat rows as [label, value] pairs, in display order.
static func stat_rows(data: Dictionary, copy: UICopy) -> Array:
	return [
		[copy.summary_time, format_time(float(data.get("time_sec", 0.0)))],
		[copy.summary_enemies, str(int(data.get("enemies", 0)))],
		[copy.summary_best_combo, "x%d" % int(data.get("best_combo", 0))],
		[copy.summary_bosses, str(int(data.get("bosses", 0)))],
		[copy.summary_ranks, rank_summary(data.get("ranks", []), copy.summary_no_ranks)],
		[copy.shards_earned_label, "+%d" % int(data.get("shards", 0))],
	]


func _ready() -> void:
	UIFeel.fade_in(self)


## Builds the screen for [param data] (see class doc for keys).
func setup(data: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var win: bool = data.get("win", false)

	var bg := ColorRect.new()
	bg.color = UIPalette.VICTORY_WASH if win else UIPalette.DEFEAT_WASH
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override(&"separation", 10)
	add_child(root)

	var title := _label(_COPY.summary_win_title if win else _COPY.summary_loss_title, 56,
		WIN_COLOR if win else LOSS_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var sub := _label(_COPY.summary_subtitle_format % [int(data.get("floor", 1)), int(data.get("rooms", 0))],
		22, UIPalette.TEXT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)

	# ADR-0032: what killed Fayde, so a loss teaches something.
	var death: String = str(data.get("death", ""))
	if not win and not death.is_empty():
		death_label = _label(death, 20, DEATH_COLOR)
		death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(death_label)

	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override(&"separation", 16)
	root.add_child(cards)

	# ADR-0042 (art bible §5.3): Fayde's crumple pose beside the stats on a loss.
	if not win:
		cards.add_child(_crumple_portrait(data.get("prana_color", UIPalette.ACCENT),
			int(data.get("character", DuoSwap.NONE))))

	# Left card: stats.
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override(&"h_separation", 32)
	stats.add_theme_constant_override(&"v_separation", 6)
	for row: Array in stat_rows(data, _COPY):
		stats.add_child(_label(row[0], 19, LABEL_COLOR))
		var v := _label(row[1], 19, VALUE_COLOR)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(v)
	cards.add_child(_card(stats, 300.0))

	# Right card: sigils taken and memories.
	var right := VBoxContainer.new()
	right.add_theme_constant_override(&"separation", 6)
	right.add_child(_label(_COPY.summary_sigils_title, 14, LABEL_COLOR))
	var sigils: Array = data.get("sigils", [])
	var list := _label(_COPY.summary_no_sigils if sigils.is_empty() else "\n".join(PackedStringArray(sigils)),
		17, VALUE_COLOR)
	list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.theme_type_variation = UIFeel.BODY_TEXT
	right.add_child(list)
	right.add_child(_spacer(6))
	right.add_child(_label(_COPY.summary_memories_format % [int(data.get("memories_new", 0)),
		int(data.get("memories_found", 0)), int(data.get("memories_total", 0))], 15, UIPalette.ACCENT_DIM))
	cards.add_child(_card(right, 280.0))

	for line: Variant in data.get("records", []):
		var rec := _label(str(line), 18, WIN_COLOR)
		rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(rec)

	if data.get("assist", false):
		var assist := _label(_COPY.summary_assist_note, 15, UIPalette.COOL)
		assist.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(assist)

	if data.get("hard_unlocked", false):
		var unlock := _label(_COPY.hard_mode_unlocked_banner, 18, UIPalette.ACCENT)
		unlock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(unlock)

	# ADR-0052: a Hard Mode win at the top Ascension opens the next one.
	if int(data.get("ascension_unlocked", 0)) > 0:
		var asc := _label(_COPY.ascension_unlocked_format % int(data["ascension_unlocked"]),
			18, UIPalette.ACCENT)
		asc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(asc)

	root.add_child(_spacer(8))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 16)
	root.add_child(buttons)
	run_again_button = _button(InputPrompts.pick(_COPY.summary_run_again, _COPY.summary_run_again_pad))
	run_again_button.pressed.connect(func() -> void: run_again_pressed.emit())
	buttons.add_child(run_again_button)
	var menu := _button(_COPY.summary_main_menu)
	menu.pressed.connect(func() -> void: main_menu_pressed.emit())
	buttons.add_child(menu)
	# ADR-0045 / beta plan 5.2: the run just ended, the best moment to ask.
	if FeedbackLink.is_available():
		feedback_button = _button(_COPY.summary_feedback)
		feedback_button.pressed.connect(func() -> void:
			FeedbackLink.open(str(ProjectSettings.get_setting("application/config/version", "dev"))))
		buttons.add_child(feedback_button)


## A box holding Fayde's crumple pose at the portrait scale, feet on its bottom edge.
func _crumple_portrait(glow: Color, character: int = DuoSwap.NONE) -> Control:
	var px: float = float(maxi(_JUICE.crumple_portrait_scale, 1))
	var box := Control.new()
	box.custom_minimum_size = Vector2(20.0 * px, 32.0 * px)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crumple = CrumplePose.new()
	crumple.set_character(character)
	crumple.scale = Vector2(px, px)
	crumple.position = Vector2(10.0 * px, 32.0 * px)
	crumple.setup(glow, CRUMPLE_TINT)
	if GameSettings.motion_reduced():
		crumple.advance(crumple.duration)
	box.add_child(crumple)
	return box


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", color)
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 48)
	b.add_theme_font_size_override(&"font_size", 20)
	return b


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _card(content: Control, min_width: float) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_BG
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(16)
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	card.add_theme_stylebox_override(&"panel", sb)
	card.custom_minimum_size = Vector2(min_width, 0)
	card.add_child(content)
	return card
