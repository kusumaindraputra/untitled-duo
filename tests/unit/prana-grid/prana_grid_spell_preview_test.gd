## prana_grid_spell_preview_test.gd — Spell preview in the preparation panel (beta plan U1).
##
## Covers SpellPreview.build()/to_bbcode() (pure) and PranaGrid.build_spell_card(), which
## feeds it from the live CombinationResolution autoload so preview and combat share rules.
##
## Coverage:
##   SP-01: empty centre shows the empty prompt only
##   SP-02: core title, summary and next-tier hint
##   SP-03: next-tier counts at every tier boundary
##   SP-04: modifiers listed, "strong" suffix at modifier tier 2
##   SP-05: reactions use UICopy text; unknown ids fall back to the ReactionDef description
##   SP-06: cascade line shows the multiplier
##   SP-07: every reaction in assets/data/reactions/ has player text in UICopy
##   SP-08: PranaGrid.build_spell_card() matches CombinationResolution for a live grid
##   SP-09: to_bbcode renders the title for a build and the prompt for an empty grid
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const PranaGridScript = preload("res://src/ui/prana_grid.gd")
const COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const NAMES: Array = ["Ashfire", "Voidblue", "Stormgold", "Deepfrost", "Verdant"]
const ASH := 0
const VOID := 1
const STORM := 2


func _summary(primary: int, tier: int, count: int, nonprimary: Array = []) -> Dictionary:
	return {"primary_type": primary, "primary_tier": tier, "primary_count": count, "nonprimary": nonprimary}


func _card(summary: Dictionary, reactions: Array = [], cascade: CascadeEffect = null) -> Dictionary:
	return SpellPreview.build(summary, reactions, cascade, NAMES, COPY)


# ── SP-01 ─────────────────────────────────────────────────────────────────────

func test_spell_preview_empty_centre_shows_prompt_only() -> void:
	var card: Dictionary = _card(_summary(-1, 0, 0))

	assert_bool(card["empty"]).is_true()
	assert_str(card["hint"]).is_equal(COPY.spell_preview_empty)
	assert_str(card["title"]).is_empty()


# ── SP-02 ─────────────────────────────────────────────────────────────────────

func test_spell_preview_single_core_title_summary_and_hint() -> void:
	var card: Dictionary = _card(_summary(ASH, 1, 1))

	assert_bool(card["empty"]).is_false()
	assert_str(card["title"]).contains("ASHFIRE").contains("Tier 1 of 3").contains("1-hit combo")
	assert_str(card["summary"]).is_equal(COPY.prana_cast_summaries[ASH])
	assert_str(card["hint"]).is_equal(COPY.spell_preview_next_tier_format % [2, "Ashfire", 2])


func test_spell_preview_max_tier_shows_max_note() -> void:
	var card: Dictionary = _card(_summary(STORM, 3, 6))

	assert_str(card["hint"]).is_equal(COPY.spell_preview_max_tier)


# ── SP-03 ─────────────────────────────────────────────────────────────────────

func test_spell_preview_more_for_next_tier_at_boundaries() -> void:
	assert_int(SpellPreview.more_for_next_tier(1, 1)).is_equal(2)
	assert_int(SpellPreview.more_for_next_tier(2, 1)).is_equal(1)
	assert_int(SpellPreview.more_for_next_tier(3, 2)).is_equal(3)
	assert_int(SpellPreview.more_for_next_tier(5, 2)).is_equal(1)
	assert_int(SpellPreview.more_for_next_tier(6, 3)).is_equal(0)
	assert_int(SpellPreview.more_for_next_tier(0, 0)).is_equal(0)


func test_spell_preview_next_tier_hint_matches_resolution_tiers() -> void:
	# Adding the hinted count must actually reach the next tier in CombinationResolution.
	for count: int in range(1, 6):
		var ids: Array = []
		ids.resize(9)
		ids[4] = ASH
		var placed: int = 1
		for i: int in [0, 1, 2, 3, 5, 6, 7, 8]:
			if placed >= count:
				break
			ids[i] = ASH
			placed += 1
		var before: Dictionary = CombinationResolution.preview_build(ids)
		var more: int = SpellPreview.more_for_next_tier(count, before["primary_tier"])
		var after_count: int = count + more
		var tier_after: int = CombinationResolution._compute_primary_tier(after_count)
		assert_int(tier_after).is_equal(int(before["primary_tier"]) + 1)
		assert_int(CombinationResolution._compute_primary_tier(after_count - 1)).is_equal(before["primary_tier"])


# ── SP-04 ─────────────────────────────────────────────────────────────────────

func test_spell_preview_modifiers_listed_with_strong_suffix_at_tier_two() -> void:
	var nps: Array = [{"type": VOID, "tier": 1, "count": 1}, {"type": STORM, "tier": 2, "count": 3}]
	var card: Dictionary = _card(_summary(ASH, 1, 1, nps))

	var mods: Array = card["modifiers"]
	assert_int(mods.size()).is_equal(2)
	assert_str(mods[0]["text"]).is_equal(COPY.prana_modifier_summaries[VOID])
	assert_str(mods[1]["text"]).is_equal(COPY.prana_modifier_summaries[STORM] + COPY.spell_preview_modifier_strong)


# ── SP-05 ─────────────────────────────────────────────────────────────────────

func test_spell_preview_reaction_uses_ui_copy_text() -> void:
	var r := ReactionDef.new()
	r.id = &"REACT_WILDFIRE"
	r.name = "Wildfire"
	r.description = "dev text"

	var card: Dictionary = _card(_summary(ASH, 1, 1), [r])

	assert_array(card["reactions"]).contains_exactly(["Wildfire: " + COPY.reaction_summaries[&"REACT_WILDFIRE"]])


func test_spell_preview_unknown_reaction_falls_back_to_description() -> void:
	var r := ReactionDef.new()
	r.id = &"REACT_NOT_IN_COPY"
	r.name = "Mystery"
	r.description = "Something happens"

	var card: Dictionary = _card(_summary(ASH, 1, 1), [r])

	assert_array(card["reactions"]).contains_exactly(["Mystery: Something happens"])


# ── SP-06 ─────────────────────────────────────────────────────────────────────

func test_spell_preview_cascade_line_shows_multiplier() -> void:
	var c := CascadeEffect.new()
	c.cascade_mult = 1.2

	var card: Dictionary = _card(_summary(ASH, 1, 1), [], c)

	assert_str(card["cascade"]).is_equal(COPY.spell_preview_cascade_format % 1.2)


func test_spell_preview_no_cascade_leaves_line_empty() -> void:
	assert_str(_card(_summary(ASH, 1, 1))["cascade"]).is_empty()


# ── SP-07 ─────────────────────────────────────────────────────────────────────

func test_spell_preview_every_reaction_has_player_text() -> void:
	var dir := DirAccess.open("res://assets/data/reactions/")
	assert_object(dir).is_not_null()
	var checked: int = 0
	for file: String in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var r: ReactionDef = load("res://assets/data/reactions/" + file) as ReactionDef
		assert_bool(COPY.reaction_summaries.has(r.id)).override_failure_message("no UICopy text for %s" % r.id).is_true()
		checked += 1
	assert_int(checked).is_greater(0)


func test_spell_preview_summaries_cover_every_prana_type() -> void:
	assert_int(COPY.prana_cast_summaries.size()).is_equal(PranaCatalog.type_count())
	assert_int(COPY.prana_modifier_summaries.size()).is_equal(PranaCatalog.type_count())


# ── SP-08 ─────────────────────────────────────────────────────────────────────

func test_prana_grid_spell_card_matches_combination_resolution() -> void:
	var pg: PranaGrid = PranaGridScript.new()
	pg._slots.resize(PranaGrid.GRID_SIZE)
	pg._slots.fill(null)
	pg._slots[4] = ASH
	pg._slots[1] = VOID
	pg._slots[3] = STORM

	var card: Dictionary = pg.build_spell_card()

	assert_int(card["primary"]).is_equal(ASH)
	assert_int((card["modifiers"] as Array).size()).is_equal(2)
	# Two distinct cardinal neighbours around the core fire a Cascade (Formula 10).
	assert_str(card["cascade"]).is_not_empty()
	pg.free()


func test_prana_grid_spell_card_empty_grid_is_empty() -> void:
	var pg: PranaGrid = PranaGridScript.new()
	pg._slots.resize(PranaGrid.GRID_SIZE)
	pg._slots.fill(null)

	assert_bool(pg.build_spell_card()["empty"]).is_true()
	pg.free()


# ── SP-09 ─────────────────────────────────────────────────────────────────────

func test_spell_preview_bbcode_contains_title_and_modifiers() -> void:
	var nps: Array = [{"type": VOID, "tier": 1, "count": 1}]
	var card: Dictionary = _card(_summary(ASH, 1, 1, nps))
	var colors: Array = [Color.RED, Color.BLUE, Color.YELLOW, Color.CYAN, Color.GREEN]

	var text: String = SpellPreview.to_bbcode(card, colors, COPY.type_abbrevs)

	assert_str(text).contains(card["title"]).contains(COPY.prana_modifier_summaries[VOID])


func test_spell_preview_bbcode_empty_is_prompt() -> void:
	var text: String = SpellPreview.to_bbcode(_card(_summary(-1, 0, 0)), [], [])

	assert_str(text).contains(COPY.spell_preview_empty)
