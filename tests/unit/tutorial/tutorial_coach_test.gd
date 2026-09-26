## tutorial_coach_test.gd — tutorial hint bookkeeping (ADR-0031).
## The coach is never added to the tree here, so it is freed with free().
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const COPY: UICopy = preload("res://assets/data/ui_copy.tres")


func after_test() -> void:
	InputPrompts.using_pad = false


func test_tutorial_coach_starts_on_first_hint_of_each_phase() -> void:
	var c := TutorialCoach.new()
	assert_str(String(c.current_step(TutorialCoach.Phase.PREP))).is_equal("confirm")
	assert_str(String(c.current_step(TutorialCoach.Phase.COMBAT))).is_equal("move")
	assert_str(String(c.current_step(TutorialCoach.Phase.NONE))).is_equal("")
	assert_bool(c.is_done()).is_false()
	c.free()


func test_tutorial_coach_shows_one_hint_at_a_time_in_order() -> void:
	var c := TutorialCoach.new()
	c.notify(&"move")
	assert_str(String(c.current_step(TutorialCoach.Phase.COMBAT))).is_equal("cast")
	c.notify(&"cast")
	c.notify(&"dash")
	assert_str(String(c.current_step(TutorialCoach.Phase.COMBAT))).is_equal("perfect_dodge")
	c.free()


func test_tutorial_coach_steps_tick_in_any_order() -> void:
	var c := TutorialCoach.new()
	assert_bool(c.notify(&"special")).is_true()
	assert_bool(c.is_step_done(&"special")).is_true()
	assert_str(String(c.current_step(TutorialCoach.Phase.COMBAT))).is_equal("move")
	assert_int(c.done_count()).is_equal(1)
	c.free()


func test_tutorial_coach_combat_start_ticks_the_prep_hint_on_screen() -> void:
	var c := TutorialCoach.new()
	c.on_combat_started(false)
	assert_bool(c.is_step_done(&"confirm")).is_true()
	assert_str(String(c.current_step(TutorialCoach.Phase.PREP))).is_equal("tiers")
	c.on_combat_started(true)
	assert_bool(c.is_step_done(&"tiers")).is_true()
	assert_str(String(c.current_step(TutorialCoach.Phase.PREP))).is_equal("")
	c.free()


func test_tutorial_coach_repeat_and_unknown_steps_are_ignored() -> void:
	var c := TutorialCoach.new()
	c.notify(&"cast")
	assert_bool(c.notify(&"cast")).is_false()
	assert_bool(c.notify(&"fly")).is_false()
	c.free()


func test_tutorial_coach_completes_once_after_all_steps() -> void:
	var c := TutorialCoach.new()
	var fired: Array[int] = [0]
	c.completed.connect(func() -> void: fired[0] += 1)
	for id: StringName in TutorialCoach.STEPS:
		c.notify(id)
	c.notify(&"move")
	assert_bool(c.is_done()).is_true()
	assert_str(String(c.current_step(TutorialCoach.Phase.COMBAT))).is_equal("")
	assert_str(String(c.current_step(TutorialCoach.Phase.PREP))).is_equal("")
	assert_int(fired[0]).is_equal(1)
	c.free()


func test_tutorial_coach_signal_adapters_tick_their_steps() -> void:
	var c := TutorialCoach.new()
	c.on_cast_started(null)
	c.on_perfect_dodge(Vector2.ZERO)
	c.on_perfect_cast(Vector2.ZERO, 1)
	c.on_special_fired(0, Vector2.ZERO, 10.0)
	for id: StringName in [&"cast", &"perfect_dodge", &"perfect_cast", &"special"]:
		assert_bool(c.is_step_done(id)).is_true()
	assert_bool(c.is_step_done(&"dash")).is_false()
	c.free()


func test_tutorial_coach_tables_line_up_with_steps() -> void:
	assert_int(TutorialCoach.STEP_PHASES.size()).is_equal(TutorialCoach.STEPS.size())
	assert_int(TutorialCoach.STEP_ACTIONS.size()).is_equal(TutorialCoach.STEPS.size())
	assert_int(COPY.coach_steps_kb.size()).is_equal(TutorialCoach.STEPS.size())
	assert_int(COPY.coach_steps_pad.size()).is_equal(TutorialCoach.STEPS.size())


func test_tutorial_coach_hint_names_the_bound_key_and_button() -> void:
	var kb: String = TutorialCoach.hint_text(&"dash", false)
	assert_str(kb).is_equal(COPY.coach_steps_kb[3] % InputPrompts.key_label(&"dash"))
	var pad: String = TutorialCoach.hint_text(&"dash", true)
	assert_str(pad).is_equal(COPY.coach_steps_pad[3] % InputPrompts.pad_label(&"dash"))
	assert_str(TutorialCoach.hint_text(&"tiers", true)).is_equal(COPY.coach_steps_pad[4])
	assert_str(TutorialCoach.hint_text(&"fly", false)).is_equal("")


func test_tutorial_coach_hints_are_short() -> void:
	# One line each: a hint must never grow into a card that covers the screen.
	for line: String in COPY.coach_steps_kb + COPY.coach_steps_pad:
		assert_int(line.length()).is_less(60)


func test_meta_progress_tutorial_flag_round_trips() -> void:
	var path := "user://test_progress_tutorial.cfg"
	var p := MetaProgress.new()
	p.tutorial_done = true
	p.save_to(path)
	assert_bool(MetaProgress.load_from(path).tutorial_done).is_true()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
