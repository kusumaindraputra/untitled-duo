## ui_copy_accessors_test.gd — Regression coverage for the data-driven/i18n refactor.
##
## After centralizing UI copy into UICopy and routing Prana colours/names through
## PranaCatalog, the PranaTypeToken static accessors (type_count/type_color/
## type_abbrev) became load-bearing for grid slots, tokens, reward cards, and the
## build readout. These were previously hardcoded const arrays with no runtime
## coverage. This suite locks the accessors to the canonical sources.
##
## Uses the live /root/PranaCatalog autoload (real 5-type catalog) — the same
## singleton the production accessors read.
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const UICopyScript = preload("res://src/data/ui_copy.gd")

# ── type_count mirrors PranaCatalog ──────────────────────────────────────────

func test_token_type_count_matches_prana_catalog() -> void:
	assert_int(PranaTypeToken.type_count()).is_equal(PranaCatalog.type_count())
	assert_int(PranaTypeToken.type_count()).is_equal(5)


# ── type_color sources from PranaCatalog (single source of truth) ─────────────

func test_token_type_color_matches_catalog_color() -> void:
	for id: int in PranaCatalog.type_count():
		assert_object(PranaTypeToken.type_color(id)).is_equal(PranaCatalog.get_type_color(id))


func test_token_type_color_out_of_range_returns_grey() -> void:
	assert_object(PranaTypeToken.type_color(-1)).is_equal(Color(0.3, 0.3, 0.3))
	assert_object(PranaTypeToken.type_color(99)).is_equal(Color(0.3, 0.3, 0.3))


# ── type_abbrev sources from UICopy ──────────────────────────────────────────

func test_token_type_abbrev_matches_ui_copy() -> void:
	var copy: UICopy = load("res://assets/data/ui_copy.tres")
	for id: int in copy.type_abbrevs.size():
		assert_str(PranaTypeToken.type_abbrev(id)).is_equal(copy.type_abbrevs[id])


func test_token_type_abbrev_out_of_range_returns_question_mark() -> void:
	assert_str(PranaTypeToken.type_abbrev(-1)).is_equal("?")
	assert_str(PranaTypeToken.type_abbrev(99)).is_equal("?")


# ── UICopy fields are populated (centralization smoke) ───────────────────────

func test_ui_copy_resource_fields_are_non_empty() -> void:
	var copy: UICopy = load("res://assets/data/ui_copy.tres")

	assert_str(copy.prep_header).is_not_empty()
	assert_str(copy.prep_hint).is_not_empty()
	assert_str(copy.confirm_button).is_not_empty()
	assert_str(copy.dash_hint_format).is_not_empty()
	assert_str(copy.dash_hint_pad).is_not_empty()
	assert_int(copy.type_abbrevs.size()).is_equal(PranaCatalog.type_count())


# ── SigilConfig drives sigil tuning + Prana names come from PranaCatalog ──────

func test_sigil_prana_card_names_come_from_prana_catalog() -> void:
	var sm := preload("res://src/systems/sigil_manager.gd").new()

	var pool: Array[Dictionary] = sm.get_catalog()

	# Every Prana card's title embeds the canonical catalog name for its type.
	var checked := 0
	for card: Dictionary in pool:
		if card.has("prana_type"):
			var tid: int = card["prana_type"]
			var canonical_name: String = PranaCatalog.get_type(tid).name
			assert_str(String(card["title"])).contains(canonical_name)
			checked += 1
	assert_int(checked).is_equal(PranaCatalog.type_count())

	sm.free()
