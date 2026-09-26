## SpellPreview — turns an in-progress Prana grid into the spell card shown in the
## preparation panel (beta plan U1).
##
## Pure and stateless: PranaGrid gathers the build summary from
## CombinationResolution.preview_build() and the recognition layer from
## CombinationResolution.compute_recognition(), then calls [method build] for the
## structured lines and [method to_bbcode] for the panel text. Every player-facing word
## comes from UICopy, so the card stays data-driven and ready for localization.
class_name SpellPreview
extends RefCounted

## Resolution thresholds, read from the CombinationResolution script so the preview
## never drifts from the tiers combat uses.
const _CR := preload("res://src/systems/combination_resolution.gd")

## Highest primary tier a core can reach.
const MAX_TIER: int = 3

## Muted colour for hint lines (next tier, empty grid).
const HINT_COLOR := Color(0.6, 0.6, 0.66)
## Colour of reaction and cascade lines.
const REACTION_COLOR := Color(1.0, 0.84, 0.4)


## Returns how many more core-type Prana are needed for the next primary tier, or 0 when
## the core is already at [constant MAX_TIER] (or there is no core).
static func more_for_next_tier(primary_count: int, primary_tier: int) -> int:
	if primary_tier <= 0 or primary_tier >= MAX_TIER:
		return 0
	var next_min: int = (_CR.PRIMARY_T1_MAX if primary_tier == 1 else _CR.PRIMARY_T2_MAX) + 1
	return maxi(next_min - primary_count, 0)


## Builds the spell card as plain structured lines.
##
## [param summary] is the Dictionary from CombinationResolution.preview_build().
## [param reactions] is the armed ReactionDef list, [param cascade] the CascadeEffect or
## null, [param names] the full element names in type_id order (PranaCatalog), and
## [param copy] the UICopy resource.
##
## Returns a Dictionary:
##   empty:      bool — true when the centre slot is empty (only [code]hint[/code] is set)
##   primary:    int — core type id, or -1
##   title:      String — element, tier and hits per cast
##   summary:    String — what the core spell does
##   hint:       String — next-tier hint, max-tier note, or the empty-grid prompt
##   modifiers:  Array of { "type": int, "text": String }
##   reactions:  Array[String] — "Name: what it does"
##   cascade:    String — empty when no cascade fires
static func build(summary: Dictionary, reactions: Array, cascade: CascadeEffect,
		names: Array, copy: UICopy) -> Dictionary:
	var out: Dictionary = {
		"empty": true, "primary": -1, "title": "", "summary": "", "hint": copy.spell_preview_empty,
		"modifiers": [], "reactions": [], "cascade": "",
	}
	var primary: int = summary.get("primary_type", -1)
	if primary < 0:
		return out
	var tier: int = summary.get("primary_tier", 1)
	var count: int = summary.get("primary_count", 1)
	out["empty"] = false
	out["primary"] = primary
	var elem_name: String = _name_of(primary, names)
	# combo_attack_count mirrors primary_tier (CombinationResolution._resolve).
	out["title"] = copy.spell_preview_title_format % [elem_name.to_upper(), tier, MAX_TIER, tier]
	out["summary"] = _entry(copy.prana_cast_summaries, primary)
	var more: int = more_for_next_tier(count, tier)
	out["hint"] = copy.spell_preview_next_tier_format % [more, elem_name, tier + 1] if more > 0 \
		else copy.spell_preview_max_tier

	var mods: Array = []
	for np: Dictionary in summary.get("nonprimary", []):
		var t: int = np["type"]
		var text: String = _entry(copy.prana_modifier_summaries, t)
		if int(np["tier"]) >= 2:
			text += copy.spell_preview_modifier_strong
		mods.append({"type": t, "text": text})
	out["modifiers"] = mods

	var lines: Array[String] = []
	for entry: Variant in reactions:
		var r: ReactionDef = entry as ReactionDef
		if r == null:
			continue
		var what: String = copy.reaction_summaries.get(r.id, r.description)
		lines.append("%s: %s" % [r.name, what])
	out["reactions"] = lines

	if cascade != null:
		out["cascade"] = copy.spell_preview_cascade_format % cascade.cascade_mult
	return out


## Renders a [method build] result as bbcode for the panel's RichTextLabel.
## [param colors] are element colours and [param abbrevs] short element names, both in
## type_id order.
static func to_bbcode(card: Dictionary, colors: Array, abbrevs: Array) -> String:
	if card["empty"]:
		return "[color=#%s]%s[/color]" % [HINT_COLOR.to_html(false), card["hint"]]
	var primary: int = card["primary"]
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[b][color=#%s]%s[/color][/b]" % [_color_hex(primary, colors), card["title"]])
	lines.append(card["summary"])
	lines.append("[color=#%s]%s[/color]" % [HINT_COLOR.to_html(false), card["hint"]])
	for m: Dictionary in card["modifiers"]:
		var t: int = m["type"]
		lines.append("[color=#%s]+ %s[/color]  %s" % [_color_hex(t, colors), _entry(abbrevs, t), m["text"]])
	var gold: String = REACTION_COLOR.to_html(false)
	for r: String in card["reactions"]:
		lines.append("[color=#%s]%s[/color]" % [gold, r])
	if card["cascade"] != "":
		lines.append("[color=#%s]%s[/color]" % [gold, card["cascade"]])
	return "\n".join(lines)


static func _name_of(type_id: int, names: Array) -> String:
	return str(names[type_id]) if type_id >= 0 and type_id < names.size() else "?"


static func _entry(list: Array, type_id: int) -> String:
	return str(list[type_id]) if type_id >= 0 and type_id < list.size() else ""


static func _color_hex(type_id: int, colors: Array) -> String:
	if type_id >= 0 and type_id < colors.size():
		return (colors[type_id] as Color).to_html(false)
	return Color.WHITE.to_html(false)
