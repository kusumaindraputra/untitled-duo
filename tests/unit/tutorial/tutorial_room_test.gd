## tutorial_room_test.gd — guided first-room lessons (ADR-0055).
## The TutorialRoom is never added to the tree here, so it is freed with free().
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const _PATH: String = "user://test_progress_tutorial_room.cfg"


func after_test() -> void:
	InputPrompts.using_pad = false
	if FileAccess.file_exists(_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_PATH))


func test_tutorial_room_starts_on_the_grid_lesson() -> void:
	var t := TutorialRoom.new()
	assert_str(String(t.current_step())).is_equal("place")
	assert_int(t.done_count()).is_equal(0)
	assert_bool(t.is_done()).is_false()
	t.free()


func test_tutorial_room_lessons_show_in_order() -> void:
	var t := TutorialRoom.new()
	t.notify(&"place")
	assert_str(String(t.current_step())).is_equal("confirm")
	t.notify(&"confirm")
	t.notify(&"move")
	assert_str(String(t.current_step())).is_equal("dash")
	t.free()


func test_tutorial_room_lessons_tick_in_any_order() -> void:
	var t := TutorialRoom.new()
	assert_bool(t.notify(&"cast")).is_true()
	assert_bool(t.is_step_done(&"cast")).is_true()
	assert_str(String(t.current_step())).is_equal("place")
	t.free()


func test_tutorial_room_repeat_and_unknown_lessons_are_ignored() -> void:
	var t := TutorialRoom.new()
	t.notify(&"dash")
	assert_bool(t.notify(&"dash")).is_false()
	assert_bool(t.notify(&"fly")).is_false()
	assert_int(t.done_count()).is_equal(1)
	t.free()


func test_tutorial_room_combat_start_ticks_both_grid_lessons() -> void:
	var t := TutorialRoom.new()
	t.on_combat_started(false)
	assert_bool(t.is_step_done(&"place")).is_true()
	assert_bool(t.is_step_done(&"confirm")).is_true()
	assert_str(String(t.current_step())).is_equal("move")
	t.free()


func test_tutorial_room_bag_shrinking_ticks_place() -> void:
	var t := TutorialRoom.new()
	t.on_bag_changed([1])
	t.on_bag_changed([1, 1])
	assert_bool(t.is_step_done(&"place")).is_false()
	t.on_bag_changed([1])
	assert_bool(t.is_step_done(&"place")).is_true()
	t.free()


func test_tutorial_room_signals_tick_their_lessons() -> void:
	var t := TutorialRoom.new()
	t.on_perfect_dodge(Vector2.ZERO)
	assert_bool(t.is_step_done(&"perfect_dodge")).is_true()
	# Damage to anything but a training target is not the cast lesson.
	var other := Node.new()
	t.on_damage_taken(other, 5, 10)
	assert_bool(t.is_step_done(&"cast")).is_false()
	other.free()
	t.free()


func test_tutorial_room_finishes_once_after_all_lessons() -> void:
	var t := TutorialRoom.new()
	var calls: Array[bool] = []
	t.finished.connect(func(skipped: bool) -> void: calls.append(skipped))
	for id: StringName in TutorialRoom.STEPS:
		t.notify(id)
	assert_bool(t.is_done()).is_true()
	assert_bool(t.is_finished()).is_true()
	t.skip()
	assert_array(calls).is_equal([false])
	t.free()


func test_tutorial_room_skip_finishes_skipped_and_stops_ticking() -> void:
	var t := TutorialRoom.new()
	var calls: Array[bool] = []
	t.finished.connect(func(skipped: bool) -> void: calls.append(skipped))
	t.notify(&"place")
	t.skip()
	t.skip()
	assert_array(calls).is_equal([true])
	assert_bool(t.notify(&"move")).is_false()
	t.free()


func test_tutorial_room_copy_has_a_line_per_lesson() -> void:
	var n: int = TutorialRoom.STEPS.size()
	assert_int(TutorialRoom.STEP_PHASES.size()).is_equal(n)
	assert_int(TutorialRoom.STEP_ACTIONS.size()).is_equal(n)
	assert_int(COPY.tutorial_steps_kb.size()).is_equal(n)
	assert_int(COPY.tutorial_steps_pad.size()).is_equal(n)
	assert_int(COPY.tutorial_details.size()).is_equal(n)


func test_tutorial_room_hint_text_fills_every_placeholder() -> void:
	for id: StringName in TutorialRoom.STEPS:
		for pad: bool in [false, true]:
			var line: String = TutorialRoom.hint_text(id, pad)
			assert_str(line).is_not_empty()
			assert_bool(line.contains("%")).override_failure_message(
				"%s (pad=%s) left a placeholder: %s" % [id, pad, line]).is_false()
	assert_str(TutorialRoom.hint_text(&"fly", false)).is_equal("")


func test_tutorial_room_pad_place_names_cycle_and_place_buttons() -> void:
	var line: String = TutorialRoom.hint_text(&"place", true)
	assert_str(line).contains(InputPrompts.pad_label(&"prana_type_cycle", "RB"))
	assert_str(line).contains(InputPrompts.pad_label(&"prana_place", "A"))


func test_tutorial_room_skip_prompt_names_the_device() -> void:
	assert_bool(TutorialRoom.skip_text(false).contains("%")).is_false()
	assert_bool(TutorialRoom.skip_text(true).contains("%")).is_false()


func test_tutorial_room_pick_spots_prefers_near_targets_and_turret_at_range() -> void:
	var spots: Array[Vector2] = [
		Vector2(40, 0),     # too close for a target
		Vector2(100, 0),
		Vector2(0, 120),
		Vector2(200, 0),
		Vector2(0, -400),
	]
	var picked: Dictionary = TutorialRoom.pick_spots(Vector2.ZERO, spots, 2, 90.0, 190.0)
	var targets: Array[Vector2] = []
	targets.assign(picked["targets"])
	assert_array(targets).is_equal([Vector2(100, 0), Vector2(0, 120)])
	assert_that(picked["turret"]).is_equal(Vector2(200, 0))


func test_tutorial_room_pick_spots_without_spare_spot_keeps_a_turret() -> void:
	var spots: Array[Vector2] = [Vector2(100, 0)]
	var picked: Dictionary = TutorialRoom.pick_spots(Vector2.ZERO, spots, 2, 90.0, 190.0)
	assert_int((picked["targets"] as Array).size()).is_equal(1)
	assert_that(picked["turret"]).is_not_equal(Vector2.ZERO)


func test_tutorial_room_tuning_is_sane() -> void:
	var tu: TutorialRoomTuning = TutorialRoom.TUNING
	assert_int(tu.bag_prana).is_greater(0)
	assert_int(tu.target_count).is_greater(0)
	assert_float(tu.shot_telegraph_sec).is_less(tu.shot_interval_sec)
	assert_float(tu.target_hp_mult).is_greater_equal(1.0)
	assert_int(tu.dodge_fallback_shots).is_greater(0)


func test_tutorial_room_flag_round_trips_through_progress() -> void:
	var p := MetaProgress.new()
	p.tutorial_room_done = true
	assert_int(p.save_to(_PATH)).is_equal(OK)
	assert_bool(MetaProgress.load_from(_PATH).tutorial_room_done).is_true()
	p.tutorial_room_done = false
	p.save_to(_PATH)
	assert_bool(MetaProgress.load_from(_PATH).tutorial_room_done).is_false()


func test_tutorial_room_old_saves_skip_the_room_for_returning_players() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "runs", 3)
	cfg.save(_PATH)
	assert_bool(MetaProgress.load_from(_PATH).tutorial_room_done).is_true()
	var fresh := ConfigFile.new()
	fresh.set_value("progress", "runs", 0)
	fresh.save(_PATH)
	assert_bool(MetaProgress.load_from(_PATH).tutorial_room_done).is_false()


func test_tutorial_coach_pretick_skips_room_lessons_quietly() -> void:
	var c := TutorialCoach.new()
	c.pretick([&"confirm", &"move", &"cast", &"dash", &"tiers", &"perfect_dodge"])
	assert_str(String(c.current_step(TutorialCoach.Phase.COMBAT))).is_equal("perfect_cast")
	assert_str(String(c.current_step(TutorialCoach.Phase.PREP))).is_equal("")
	assert_bool(c.is_done()).is_false()
	c.free()
