## hud_readout_sigil_strip_test.gd — Core / sigil chip strip under the HUD card (ADR-0045).
##
## Coverage:
##   HR-10: tags are two letters from the title
##   HR-11: rows wrap to the strip width; empty strip has no height
##   HR-12: Core goes first and is replaced, repeat sigils stack instead of adding chips
##   HR-13: a pulse lights only a chip that exists and ends after the tuned time
##   HR-14: the HUD pushes the combo counter below a non-empty strip
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const TUNING: HudReadoutTuning = preload("res://assets/data/hud_readout_tuning.tres")
const CombatHUDScript = preload("res://src/ui/combat_hud.gd")


func test_tag_is_two_letters_from_title() -> void:
	assert_str(SigilStrip.tag_for("Ember Wake")).is_equal("EW")
	assert_str(SigilStrip.tag_for("Siphon")).is_equal("SI")
	assert_str(SigilStrip.tag_for("  glass core of doom ")).is_equal("GC")
	assert_str(SigilStrip.tag_for("")).is_equal("")


func test_rows_wrap_to_width() -> void:
	# 26 px chips with 4 px gaps: (208 + 4) / 30 = 7 per row.
	assert_int(SigilStrip.rows_for(0, 208.0, 26.0, 4.0)).is_equal(0)
	assert_int(SigilStrip.rows_for(7, 208.0, 26.0, 4.0)).is_equal(1)
	assert_int(SigilStrip.rows_for(8, 208.0, 26.0, 4.0)).is_equal(2)
	assert_int(SigilStrip.rows_for(3, 10.0, 26.0, 4.0)).is_equal(3)  # never 0 per row


func test_core_first_and_repeat_sigils_stack() -> void:
	var strip := SigilStrip.new()
	strip.add_sigil(&"damage", "Sharpened Focus", false)
	strip.set_core(&"glass", "Glass Core", Color.RED)
	strip.add_sigil(&"damage", "Sharpened Focus", false)
	strip.add_sigil(&"ember_wake", "Ember Wake", true)
	strip.set_core(&"gale", "Gale Core", Color.BLUE)

	var chips: Array[Dictionary] = strip.get_chips()
	assert_int(chips.size()).is_equal(3)
	assert_str(String(chips[0]["id"])).is_equal("gale")
	assert_int(chips[0]["kind"]).is_equal(SigilStrip.Kind.CORE)
	assert_int(chips[1]["stacks"]).is_equal(2)
	assert_int(chips[2]["kind"]).is_equal(SigilStrip.Kind.BEHAVIOUR)
	assert_float(strip.strip_height()).is_equal(TUNING.strip_chip_size)
	strip.reset()
	assert_int(strip.chip_count()).is_equal(0)
	assert_float(strip.strip_height()).is_equal(0.0)
	strip.free()


func test_pulse_lights_existing_chip_then_ends() -> void:
	var strip := SigilStrip.new()
	strip.add_sigil(&"siphon", "Siphon", true)

	strip.pulse(&"unravel")
	assert_bool(strip.is_pulsing(&"unravel")).is_false()
	strip.pulse(&"siphon")
	assert_bool(strip.is_pulsing(&"siphon")).is_true()
	strip.tick(TUNING.strip_pulse_sec + 0.01)
	assert_bool(strip.is_pulsing(&"siphon")).is_false()
	strip.free()


func test_hud_moves_combo_counter_below_strip() -> void:
	var hud: CombatHUD = CombatHUDScript.new()
	add_child(hud)
	hud.set_process(false)
	hud._layout_left_column(true)
	var before: float = hud._combo_counter_label.position.y

	hud.get_sigil_strip().add_sigil(&"damage", "Sharpened Focus", false)
	hud._layout_left_column(true)
	var strip: SigilStrip = hud.get_sigil_strip()
	assert_float(strip.position.y).is_greater(hud.get_left_card_height())
	assert_float(hud._combo_counter_label.position.y).is_greater_equal(before + strip.strip_height())

	remove_child(hud)
	hud.free()
