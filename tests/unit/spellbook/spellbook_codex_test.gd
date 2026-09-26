## spellbook_codex_test.gd — Spellbook discoveries and entries (beta plan F1).
##
## Coverage:
##   SB-01: discover_* adds once, ignores invalid ids, reports new vs known
##   SB-02: discoveries survive a save / load round trip
##   SB-03: every section lists the full catalog; locked entries hide their text
##   SB-04: a known entry shows its UICopy text
##   SB-05: discoveries_from_grid finds the core and the armed reactions
##   SB-06: display_name splits CamelCase enemy names
##   SB-07: the panel switches sections and shows the focused entry
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const PATH: String = "user://test_spellbook_progress.cfg"
const ASH := 0
const STORM := 2


func after_test() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


# ── SB-01 ─────────────────────────────────────────────────────────────────────

func test_spellbook_discover_adds_once() -> void:
	var p := MetaProgress.new()

	assert_bool(p.discover_spell(ASH)).is_true()
	assert_bool(p.discover_spell(ASH)).is_false()
	assert_bool(p.discover_spell(-1)).is_false()
	assert_bool(p.discover_reaction(&"")).is_false()
	assert_bool(p.discover_sigil(&"damage")).is_true()
	assert_array(p.codex_spells).contains_exactly([ASH])


# ── SB-02 ─────────────────────────────────────────────────────────────────────

func test_spellbook_discoveries_round_trip() -> void:
	var p := MetaProgress.new()
	p.discover_spell(STORM)
	p.discover_reaction(&"REACT_WILDFIRE")
	p.discover_sigil(&"overcharge")
	p.discover_enemy(7)
	p.save_to(PATH)

	var back := MetaProgress.load_from(PATH)

	assert_array(back.codex_spells).contains_exactly([STORM])
	assert_array(back.codex_reactions).contains_exactly([&"REACT_WILDFIRE"])
	assert_array(back.codex_sigils).contains_exactly([&"overcharge"])
	assert_array(back.codex_enemies).contains_exactly([7])


# ── SB-03 ─────────────────────────────────────────────────────────────────────

func test_spellbook_sections_list_full_catalog_locked() -> void:
	var p := MetaProgress.new()

	var spells: Array[Dictionary] = Spellbook.entries(Spellbook.Section.SPELLS, p)
	var reactions: Array[Dictionary] = Spellbook.entries(Spellbook.Section.REACTIONS, p)
	var enemies: Array[Dictionary] = Spellbook.entries(Spellbook.Section.ENEMIES, p)

	assert_int(spells.size()).is_equal(PranaCatalog.type_count())
	assert_int(reactions.size()).is_equal(Spellbook.reaction_defs().size())
	assert_int(reactions.size()).is_greater(0)
	assert_int(enemies.size()).is_equal(EnemyCatalog.count())
	for e: Dictionary in spells + reactions + enemies:
		assert_bool(e["known"]).is_false()
		assert_str(e["title"]).is_equal(COPY.spellbook_locked)
	assert_int(Spellbook.progress(p).x).is_equal(0)


# ── SB-04 ─────────────────────────────────────────────────────────────────────

func test_spellbook_known_entries_show_copy() -> void:
	var p := MetaProgress.new()
	p.discover_reaction(&"REACT_WILDFIRE")
	p.discover_sigil(&"overcharge")

	var wildfire: Dictionary = {}
	for e: Dictionary in Spellbook.entries(Spellbook.Section.REACTIONS, p):
		if e["id"] == &"REACT_WILDFIRE":
			wildfire = e
	var sigil: Dictionary = Spellbook.entries(Spellbook.Section.SIGILS, p) \
		.filter(func(x: Dictionary) -> bool: return x["id"] == &"overcharge")[0]

	assert_bool(wildfire["known"]).is_true()
	assert_str(wildfire["body"]).is_equal(COPY.reaction_summaries[&"REACT_WILDFIRE"])
	assert_str(sigil["title"]).is_equal("Overcharge")
	assert_int(Spellbook.progress(p).x).is_equal(2)


# ── SB-05 ─────────────────────────────────────────────────────────────────────

func test_spellbook_discoveries_from_grid_core_and_reactions() -> void:
	var slots: Array = [null, null, null, null, ASH, null, null, null, null]
	var fragments: Array = []
	fragments.resize(9)
	for i: int in [1, 3, 4]:
		slots[i] = ASH if i == 4 else (1 if i == 1 else STORM)
		var f := PranaFragment.new()
		f.type_id = slots[i]
		fragments[i] = f
	var expected: Array[StringName] = []
	for r: Variant in CombinationResolution.compute_recognition(fragments)["reactions"]:
		expected.append((r as ReactionDef).id)

	var found: Dictionary = Spellbook.discoveries_from_grid(slots)

	assert_int(found["core"]).is_equal(ASH)
	assert_array(found["reactions"]).contains_exactly(expected)


func test_spellbook_empty_centre_finds_nothing() -> void:
	var found: Dictionary = Spellbook.discoveries_from_grid([null, null, null, null, null, null, null, null, null])

	assert_int(found["core"]).is_equal(-1)
	assert_array(found["reactions"]).is_empty()


# ── SB-06 ─────────────────────────────────────────────────────────────────────

func test_spellbook_display_name_splits_camel_case() -> void:
	assert_str(Spellbook.display_name("VaultSentinel")).is_equal("Vault Sentinel")
	assert_str(Spellbook.display_name("Drifter")).is_equal("Drifter")


# ── SB-07 ─────────────────────────────────────────────────────────────────────

func test_spellbook_panel_switches_sections() -> void:
	var p := MetaProgress.new()
	p.discover_sigil(&"damage")
	var panel := SpellbookPanel.new()
	panel.progress = p
	add_child(panel)

	panel.show_section(Spellbook.Section.SIGILS)
	panel.select_entry(0)

	assert_int(panel.current_section()).is_equal(Spellbook.Section.SIGILS)
	assert_str(panel.detail_title()).is_equal("Sharpened Cipher")
	remove_child(panel)
	panel.free()
