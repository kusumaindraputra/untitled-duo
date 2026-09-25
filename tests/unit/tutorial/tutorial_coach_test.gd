## tutorial_coach_test.gd — in-combat tutorial checklist bookkeeping.
## The coach is never added to the tree here, so it is freed with free().
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite


func test_tutorial_coach_starts_on_first_step() -> void:
	var c := TutorialCoach.new()
	assert_str(String(c.current_step())).is_equal("move")
	assert_bool(c.is_done()).is_false()
	c.free()


func test_tutorial_coach_steps_tick_in_any_order() -> void:
	var c := TutorialCoach.new()
	assert_bool(c.notify(&"special")).is_true()
	assert_bool(c.is_step_done(&"special")).is_true()
	assert_str(String(c.current_step())).is_equal("move")
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
	assert_str(String(c.current_step())).is_equal("")
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


func test_tutorial_coach_copy_has_a_line_per_step() -> void:
	var copy: UICopy = load("res://assets/data/ui_copy.tres")
	assert_int(copy.coach_steps.size()).is_equal(TutorialCoach.STEPS.size())


func test_meta_progress_tutorial_flag_round_trips() -> void:
	var path := "user://test_progress_tutorial.cfg"
	var p := MetaProgress.new()
	p.tutorial_done = true
	p.save_to(path)
	assert_bool(MetaProgress.load_from(path).tutorial_done).is_true()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
