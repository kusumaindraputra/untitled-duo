## combat_hud_layout_test.gd — HUD pass (beta plan U3).
##
## Coverage:
##   U3-01: DashRing hidden while every charge is full
##   U3-02: DashRing progress follows the recharge timer
##   U3-03: DashRing with a zero duration shows a full arc, never NaN
##   U3-04: set_state hides / shows the ring node
##   U3-05: left card shrinks between rooms and grows in combat; floor line moves with it
##   U3-06: Style badge, caption and bar show and hide together; badge shows the rank letter
##   U3-07: a hit flashes the HP bar, then it returns to the zone colour
##   U3-08: PlayerController recharge getters report the timer and sigil-scaled duration
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const CombatHUDScript = preload("res://src/ui/combat_hud.gd")
const PlayerControllerScript = preload("res://src/gameplay/player_controller.gd")


func _make_hud() -> Node:
	var hud: Node = CombatHUDScript.new()
	add_child(hud)
	hud.set_process(false)
	return hud


func _teardown_hud(hud: Node) -> void:
	remove_child(hud)
	hud.free()


# ── U3-01..03 ─────────────────────────────────────────────────────────────────

func test_dash_ring_hidden_when_all_charges_full() -> void:
	var st: Dictionary = DashRing.ring_state(2, 2, 0.0, 1.5)

	assert_bool(st["visible"]).is_false()


func test_dash_ring_progress_follows_recharge() -> void:
	var st: Dictionary = DashRing.ring_state(0, 2, 0.5, 2.0)

	assert_bool(st["visible"]).is_true()
	assert_float(st["progress"]).is_equal_approx(0.75, 0.0001)


func test_dash_ring_zero_duration_is_full_arc() -> void:
	var st: Dictionary = DashRing.ring_state(1, 2, 0.0, 0.0)

	assert_float(st["progress"]).is_equal(1.0)


# ── U3-04 ─────────────────────────────────────────────────────────────────────

func test_dash_ring_set_state_toggles_visibility() -> void:
	var ring := DashRing.new()

	ring.set_state(1, 2, 1.0, 2.0)
	assert_bool(ring.visible).is_true()
	assert_int(ring.charges).is_equal(1)

	ring.set_state(2, 2, 0.0, 2.0)
	assert_bool(ring.visible).is_false()
	ring.free()


# ── U3-05 ─────────────────────────────────────────────────────────────────────

func test_left_card_shrinks_between_rooms_and_grows_in_combat() -> void:
	var hud: Node = _make_hud()

	hud._on_preparation_started(0, 1)
	var prep_height: float = hud._left_panel.size.y
	var prep_floor_y: float = hud._floor_label.position.y
	hud._on_combat_started(false)

	assert_float(hud._left_panel.size.y).is_equal(hud.LEFT_PANEL_HEIGHT)
	assert_float(prep_height).is_less(hud.LEFT_PANEL_HEIGHT)
	assert_float(hud._floor_label.position.y).is_greater(prep_floor_y)
	assert_float(hud._room_label.position.y).is_greater(hud._floor_label.position.y)
	_teardown_hud(hud)


# ── U3-06 ─────────────────────────────────────────────────────────────────────

func test_style_parts_show_and_hide_together() -> void:
	var hud: Node = _make_hud()

	hud._on_combat_started(false)
	assert_bool(hud._style_badge.visible).is_true()
	assert_bool(hud._style_caption.visible).is_true()
	assert_bool(hud._style_bar.visible).is_true()

	hud._on_preparation_started(0, 1)
	assert_bool(hud._style_badge.visible).is_false()
	assert_bool(hud._style_caption.visible).is_false()
	assert_bool(hud._style_bar.visible).is_false()
	_teardown_hud(hud)


func test_style_badge_shows_rank_letter_in_rank_colour() -> void:
	var hud: Node = _make_hud()

	hud.set_style(40.0, 100.0, "B")

	assert_str(hud._style_label.text).is_equal("B")
	var sb := hud._style_badge.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_object(sb.border_color).is_equal(hud.STYLE_RANK_COLORS.get("B", Color.WHITE))
	_teardown_hud(hud)


# ── U3-07 ─────────────────────────────────────────────────────────────────────

func test_hit_flashes_hp_bar_then_returns_to_zone_colour() -> void:
	var hud: Node = _make_hud()
	var fayde := Node2D.new()
	fayde.add_to_group(&"player")
	add_child(fayde)

	hud._on_damage_taken(fayde, 10, 90)
	assert_object(hud.hp_bar.modulate).is_equal(hud.HIT_FLASH_COLOR)

	hud._process(hud.HIT_FLASH_DURATION + 0.01)
	assert_object(hud.hp_bar.modulate).is_equal(hud.HP_COLOR_FULL)

	remove_child(fayde)
	fayde.free()
	_teardown_hud(hud)


# ── U3-08 ─────────────────────────────────────────────────────────────────────

func test_player_recharge_getters_report_timer_and_duration() -> void:
	var pc: PlayerController = PlayerControllerScript.new()
	pc._dash_cooldown_timer = 0.4

	assert_float(pc.get_dash_recharge_remaining()).is_equal_approx(0.4, 0.0001)
	assert_float(pc.get_dash_recharge_duration()).is_equal_approx(pc._dash_recharge_duration(), 0.0001)
	assert_float(pc.get_dash_recharge_duration()).is_greater(0.0)
	pc.free()
