## hud_juice_test.gd — ADR-0042: HP ghost chunk and jolt, prep→combat dim, the defeat
## crumple pose and the octagonal Prana grid with circular slots.
##
##   HJ-01..05  CombatHUD ghost chunk (hold, drain, bursts, heals, run reset)
##   HJ-06..08  HP bar jolt (maths, settles, off with Reduce motion)
##   HJ-09..10  Combat dim (tuning matches art bible §2.3, room floor dims and lifts)
##   HJ-11..13  CrumplePose frames, glow tint, defeat screen portrait on a loss only
##   HJ-14..16  PranaGridFrame octagon, slot circles, corner slots clear the frame
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const CombatHUDScript = preload("res://src/ui/combat_hud.gd")
const JUICE: HudJuiceTuning = preload("res://assets/data/hud_juice_tuning.tres")
const ROOM_SCENE: PackedScene = preload("res://src/scenes/IsometricRoom.tscn")

## Frame step used to drive CombatHUD._process by hand.
const STEP: float = 0.02


class MockFayde extends Node:
	func _ready() -> void:
		add_to_group(&"player")


var _saved_settings: GameSettings = null


func before_test() -> void:
	_saved_settings = GameSettings.current


func after_test() -> void:
	GameSettings.current = _saved_settings


func _make_hud() -> Node:
	var hud: Node = CombatHUDScript.new()
	add_child(hud)
	hud.set_process(false)
	return hud


func _free(n: Node) -> void:
	remove_child(n)
	n.free()


## Runs the HUD for [param seconds] in STEP frames.
func _run(hud: Node, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds - 0.0001:
		hud._process(STEP)
		t += STEP


# ── Ghost chunk ──────────────────────────────────────────────────────────────

func test_ghost_holds_at_old_hp_then_drains_to_new_hp() -> void:
	var hud: Node = _make_hud()
	var fayde := MockFayde.new()
	add_child(fayde)
	hud._on_damage_taken(fayde, 30, 70)
	_run(hud, JUICE.ghost_hold_sec * 0.5)
	assert_float(hud.get_ghost_value()).is_equal_approx(100.0, 0.01)
	_run(hud, JUICE.ghost_hold_sec * 0.5 + JUICE.ghost_drain_sec + STEP * 2.0)
	assert_float(hud.get_ghost_value()).is_equal_approx(70.0, 0.01)
	_free(fayde)
	_free(hud)


func test_burst_of_hits_keeps_one_growing_chunk() -> void:
	var hud: Node = _make_hud()
	var fayde := MockFayde.new()
	add_child(fayde)
	hud._on_damage_taken(fayde, 10, 90)
	_run(hud, JUICE.ghost_hold_sec * 0.5)
	hud._on_damage_taken(fayde, 10, 80)
	_run(hud, JUICE.ghost_hold_sec * 0.8)
	# The second hit restarted the hold, and the chunk still starts at full HP.
	assert_float(hud.get_ghost_value()).is_equal_approx(100.0, 0.01)
	_run(hud, JUICE.ghost_hold_sec + JUICE.ghost_drain_sec)
	assert_float(hud.get_ghost_value()).is_equal_approx(80.0, 0.01)
	_free(fayde)
	_free(hud)


func test_ghost_drains_monotonically() -> void:
	var hud: Node = _make_hud()
	var fayde := MockFayde.new()
	add_child(fayde)
	hud._on_damage_taken(fayde, 40, 60)
	_run(hud, JUICE.ghost_hold_sec + STEP)
	var last: float = hud.get_ghost_value()
	for _i: int in 30:
		hud._process(STEP)
		var v: float = hud.get_ghost_value()
		assert_bool(v <= last + 0.0001).is_true()
		assert_bool(v >= 60.0 - 0.0001).is_true()
		last = v
	_free(fayde)
	_free(hud)


func test_heal_lifts_the_ghost_with_the_fill() -> void:
	var hud: Node = _make_hud()
	var fayde := MockFayde.new()
	add_child(fayde)
	hud._on_damage_taken(fayde, 50, 50)
	_run(hud, JUICE.ghost_hold_sec + JUICE.ghost_drain_sec + STEP * 2.0)
	hud._on_health_restored(fayde, 20, 70)
	assert_float(hud.get_ghost_value()).is_equal_approx(70.0, 0.01)
	_run(hud, 1.0)
	assert_float(hud.get_ghost_value()).is_equal_approx(70.0, 0.01)
	_free(fayde)
	_free(hud)


func test_run_started_resets_ghost_and_jolt() -> void:
	var hud: Node = _make_hud()
	var fayde := MockFayde.new()
	add_child(fayde)
	hud._on_damage_taken(fayde, 30, 70)
	hud._process(STEP)
	hud._on_run_started()
	assert_float(hud.get_ghost_value()).is_equal_approx(100.0, 0.01)
	assert_float(hud._jolt_timer).is_equal(0.0)
	assert_vector(hud.hp_bar.position).is_equal(hud._hp_row_pos)
	_free(fayde)
	_free(hud)


# ── Jolt ─────────────────────────────────────────────────────────────────────

func test_jolt_amplitude_scales_with_damage_between_half_and_full() -> void:
	var px: float = JUICE.jolt_px
	assert_float(CombatHUD.jolt_amplitude(1, 100, px, 0.15)).is_equal_approx(px * 0.5, 0.001)
	assert_float(CombatHUD.jolt_amplitude(15, 100, px, 0.15)).is_equal_approx(px, 0.001)
	assert_float(CombatHUD.jolt_amplitude(60, 100, px, 0.15)).is_equal_approx(px, 0.001)
	assert_float(CombatHUD.jolt_offset(0.0, 0.16, 3.0).length()).is_greater(0.0)
	assert_vector(CombatHUD.jolt_offset(0.16, 0.16, 3.0)).is_equal(Vector2.ZERO)
	assert_vector(CombatHUD.jolt_offset(0.05, 0.16, 3.0)).is_equal(CombatHUD.jolt_offset(0.05, 0.16, 3.0))


func test_jolt_moves_the_hp_row_and_settles_back() -> void:
	GameSettings.current = GameSettings.new()
	var hud: Node = _make_hud()
	var fayde := MockFayde.new()
	add_child(fayde)
	var home: Vector2 = hud._hp_row_pos
	hud._on_damage_taken(fayde, 20, 80)
	hud._process(STEP)
	assert_vector(hud.hp_bar.position).is_not_equal(home)
	assert_vector(hud.hp_label.position).is_equal(hud.hp_bar.position)
	_run(hud, JUICE.jolt_sec + STEP)
	assert_vector(hud.hp_bar.position).is_equal(home)
	_free(fayde)
	_free(hud)


func test_reduce_motion_turns_the_jolt_off() -> void:
	var s := GameSettings.new()
	s.reduce_motion = true
	GameSettings.current = s
	var hud: Node = _make_hud()
	var fayde := MockFayde.new()
	add_child(fayde)
	var home: Vector2 = hud._hp_row_pos
	hud._on_damage_taken(fayde, 20, 80)
	hud._process(STEP)
	assert_vector(hud.hp_bar.position).is_equal(home)
	_free(fayde)
	_free(hud)


# ── Combat dim ───────────────────────────────────────────────────────────────

func test_dim_tuning_matches_art_bible() -> void:
	# §2.3: ambient drops 15–20 % at wave start, over a 0.3 s dim.
	assert_float(JUICE.combat_dim).is_between(0.15, 0.2)
	assert_float(JUICE.dim_in_sec).is_equal_approx(0.3, 0.001)
	assert_object(IsometricRoom.dim_color(0.18)).is_equal(Color(0.82, 0.82, 0.82, 1.0))
	assert_object(IsometricRoom.dim_color(0.0)).is_equal(Color.WHITE)


func test_room_floor_dims_without_touching_the_boss_ambience() -> void:
	var room: IsometricRoom = ROOM_SCENE.instantiate()
	add_child(room)
	var tile_map: TileMapLayer = room.get_node(^"TileMapLayer")
	var ambience: Color = tile_map.modulate
	room.set_combat_dim(JUICE.combat_dim, 0.0)
	assert_object(tile_map.self_modulate).is_equal(IsometricRoom.dim_color(JUICE.combat_dim))
	assert_object(tile_map.modulate).is_equal(ambience)
	assert_float(room.get_combat_dim()).is_equal_approx(JUICE.combat_dim, 0.001)
	room.set_combat_dim(0.0, 0.0)
	assert_object(tile_map.self_modulate).is_equal(Color.WHITE)
	_free(room)


# ── Crumple pose ─────────────────────────────────────────────────────────────

func test_crumple_frames_play_once_and_hold() -> void:
	assert_int(CrumplePose.frame_at(0.0, 0.45)).is_equal(0)
	assert_int(CrumplePose.frame_at(0.2, 0.45)).is_equal(1)
	assert_int(CrumplePose.frame_at(0.45, 0.45)).is_equal(CrumplePose.FRAMES - 1)
	assert_int(CrumplePose.frame_at(9.0, 0.45)).is_equal(CrumplePose.FRAMES - 1)
	assert_int(CrumplePose.SHEET.get_width()).is_equal(20 * CrumplePose.FRAMES)
	assert_int(CrumplePose.SHEET.get_height()).is_equal(32)


func test_crumple_glow_carries_the_last_prana_colour() -> void:
	var pose := CrumplePose.new()
	var ash: Color = PranaTypeToken.type_color(0)
	pose.setup(ash, RunSummaryPanel.CRUMPLE_TINT)
	pose.advance(pose.duration)
	assert_object(pose.get_glow_color()).is_equal(ash)
	assert_int(pose.get_frame()).is_equal(CrumplePose.FRAMES - 1)
	pose.free()


func test_defeat_screen_shows_the_crumple_on_a_loss_only() -> void:
	var loss := RunSummaryPanel.new()
	add_child(loss)
	loss.setup({"win": false, "prana_color": PranaTypeToken.type_color(3)})
	var win := RunSummaryPanel.new()
	add_child(win)
	win.setup({"win": true})
	assert_object(loss.crumple).is_not_null()
	assert_object(loss.crumple.get_glow_color()).is_equal(PranaTypeToken.type_color(3))
	assert_object(win.crumple).is_null()
	_free(loss)
	_free(win)


# ── Octagonal grid, circular slots ───────────────────────────────────────────

func test_octagon_has_eight_corners_and_four_ornaments() -> void:
	var pts: PackedVector2Array = PranaGridFrame.octagon_points(Vector2(200, 200), 0.2)
	assert_int(pts.size()).is_equal(8)
	assert_vector(pts[0]).is_equal(Vector2(40, 0))
	assert_vector(pts[3]).is_equal(Vector2(200, 160))
	assert_int(PranaGridFrame.ornament_centres(pts).size()).is_equal(4)
	assert_vector(PranaGridFrame.ornament_centres(pts)[0]).is_equal(Vector2(20, 20))
	assert_int(PranaGridFrame.octagon_points(Vector2.ZERO, 0.2).size()).is_equal(0)


func test_slot_is_a_filled_circle() -> void:
	assert_float(PranaGridSlot.circle_radius(Vector2(54, 54))).is_equal(26.0)
	var slot := PranaGridSlot.new()
	add_child(slot)
	assert_object(slot.get_fill_color()).is_equal(PranaGridSlot.EMPTY_COLOR)
	slot.refresh(2)
	assert_object(slot.get_fill_color()).is_equal(PranaTypeToken.type_color(2))
	slot.refresh(-1)
	assert_object(slot.get_fill_color()).is_equal(PranaGridSlot.EMPTY_COLOR)
	_free(slot)


func test_corner_slots_stay_inside_the_octagon() -> void:
	# 3×3 slots with a 4 px gap, inset PAD px: the corner slot's circle must not cross
	# the cut edge x + y = cut.
	var side: float = PranaGrid.SLOT_SIZE * 3.0 + 8.0 + PranaGridFrame.PAD * 2.0
	var cut: float = side * PranaGridFrame.CUT_SHARE
	var centre: float = PranaGridFrame.PAD + PranaGrid.SLOT_SIZE * 0.5
	var dist: float = (centre + centre - cut) / sqrt(2.0)
	assert_float(dist).is_greater(PranaGridSlot.circle_radius(Vector2(PranaGrid.SLOT_SIZE, PranaGrid.SLOT_SIZE)))
