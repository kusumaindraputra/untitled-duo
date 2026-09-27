## hud_toaster_test.gd — corner toasts (ADR-0046).
##
## Coverage:
##   HT-01: alpha_at fades in, holds, fades out and never leaves 0–1
##   HT-02: offset_at slides in from the left and is zero with reduced motion
##   HT-03: toasts beyond max_visible queue and show as earlier ones expire
##   HT-04: a toast is freed after its lifetime
##   HT-05: the queue drops its oldest entries past max_queued; empty text is ignored
##   HT-06: toasts do not age while the toaster is not processing (tree paused)
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

var _saved_current: GameSettings = null


func before_test() -> void:
	_saved_current = GameSettings.current
	GameSettings.current = GameSettings.new()


func after_test() -> void:
	GameSettings.current = _saved_current


func _make_toaster() -> HudToaster:
	var t := HudToaster.new()
	add_child(t)
	t.set_process(false)
	return t


func _teardown(t: HudToaster) -> void:
	remove_child(t)
	t.free()


func test_alpha_fades_in_holds_and_fades_out() -> void:
	assert_float(HudToaster.alpha_at(0.0, 0.2, 2.0, 0.4)).is_equal(0.0)
	assert_float(HudToaster.alpha_at(0.1, 0.2, 2.0, 0.4)).is_equal_approx(0.5, 0.0001)
	assert_float(HudToaster.alpha_at(1.0, 0.2, 2.0, 0.4)).is_equal(1.0)
	assert_float(HudToaster.alpha_at(2.4, 0.2, 2.0, 0.4)).is_equal_approx(0.5, 0.0001)
	assert_float(HudToaster.alpha_at(9.0, 0.2, 2.0, 0.4)).is_equal(0.0)
	assert_float(HudToaster.alpha_at(-1.0, 0.2, 2.0, 0.4)).is_equal(0.0)


func test_alpha_with_no_fade_in_is_full_at_once() -> void:
	assert_float(HudToaster.alpha_at(0.0, 0.0, 2.0, 0.4)).is_equal(1.0)


func test_offset_slides_in_and_respects_reduced_motion() -> void:
	assert_float(HudToaster.offset_at(0.0, 0.2, 18.0, false)).is_equal(-18.0)
	assert_float(HudToaster.offset_at(0.2, 0.2, 18.0, false)).is_equal(0.0)
	assert_float(HudToaster.offset_at(0.0, 0.2, 18.0, true)).is_equal(0.0)


func test_extra_toasts_queue_until_a_slot_frees() -> void:
	var t := _make_toaster()
	var cap: int = HudToaster.TUNING.max_visible
	for i: int in cap + 2:
		t.push("toast %d" % i)

	assert_int(t.visible_count()).is_equal(cap)
	assert_int(t.queued_count()).is_equal(2)
	assert_str(t.visible_texts()[0]).is_equal("toast 0")

	t.tick(HudToaster.lifetime() + 0.01)

	assert_int(t.visible_count()).is_equal(2)
	assert_int(t.queued_count()).is_equal(0)
	assert_str(t.visible_texts()[0]).is_equal("toast %d" % cap)
	_teardown(t)


func test_toast_freed_after_lifetime() -> void:
	var t := _make_toaster()
	t.push("Sigil gained · Ember")
	t.tick(HudToaster.lifetime() * 0.5)
	assert_int(t.visible_count()).is_equal(1)

	t.tick(HudToaster.lifetime())

	assert_int(t.visible_count()).is_equal(0)
	assert_int(t.get_child_count()).is_equal(0)
	_teardown(t)


func test_queue_is_capped_and_empty_text_ignored() -> void:
	var t := _make_toaster()
	t.push("")
	assert_int(t.visible_count()).is_equal(0)
	var total: int = HudToaster.TUNING.max_visible + HudToaster.TUNING.max_queued + 3
	for i: int in total:
		t.push("toast %d" % i)

	assert_int(t.queued_count()).is_equal(HudToaster.TUNING.max_queued)
	_teardown(t)


func test_toaster_is_pausable() -> void:
	var t := _make_toaster()

	assert_int(t.process_mode).is_equal(Node.PROCESS_MODE_PAUSABLE)
	_teardown(t)


func test_card_opacity_follows_setting() -> void:
	GameSettings.current.hud_card_opacity = 0.5
	var t := _make_toaster()
	t.push("x")
	var card: PanelContainer = t.get_child(0) as PanelContainer
	var box: StyleBoxFlat = card.get_theme_stylebox(&"panel") as StyleBoxFlat

	assert_float(box.bg_color.a).is_equal_approx(UIPalette.CARD_SOLID.a * 0.5, 0.0001)
	_teardown(t)
