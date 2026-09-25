## sigil_bullet_hell_test.gd — ADR-0019 bullet-hell sigils against a real PlayerController.
##
## Coverage:
##   dash_charge adds a dash charge (max and current)
##   dash_cut sets the dash-cut radius from SigilConfig
##   graze_ring scales the graze radius, and stacks multiplicatively
##   the three new ids are in the catalog
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const SigilManagerScript = preload("res://src/systems/sigil_manager.gd")
const PlayerScript = preload("res://src/gameplay/player_controller.gd")
const BHT: BulletHellTuning = preload("res://assets/data/bullet_hell_tuning.tres")


func _make(player: Node) -> SigilManager:
	var sm: SigilManager = SigilManagerScript.new()
	sm.set_player_provider(func() -> Node: return player)
	return sm


func test_sigil_dash_charge_adds_one_charge() -> void:
	var pc: PlayerController = PlayerScript.new()
	var sm: SigilManager = _make(pc)
	var base_max: int = pc.get_max_dash_charges()

	sm.apply_sigil(&"dash_charge")

	assert_int(pc.get_max_dash_charges()).is_equal(base_max + SigilManager.CONFIG.dash_charge_bonus)
	assert_int(pc.get_dash_charges()).is_equal(base_max + SigilManager.CONFIG.dash_charge_bonus)
	sm.free()
	pc.free()


func test_sigil_dash_cut_sets_cut_radius() -> void:
	var pc: PlayerController = PlayerScript.new()
	var sm: SigilManager = _make(pc)
	assert_float(pc.get_dash_cut_radius()).is_equal(0.0)

	sm.apply_sigil(&"dash_cut")

	assert_float(pc.get_dash_cut_radius()).is_equal(SigilManager.CONFIG.dash_cut_radius)
	sm.free()
	pc.free()


func test_sigil_graze_ring_scales_and_stacks() -> void:
	var pc: PlayerController = PlayerScript.new()
	var sm: SigilManager = _make(pc)
	var mult: float = SigilManager.CONFIG.graze_radius_mult

	sm.apply_sigil(&"graze_ring")
	assert_float(pc.get_graze_radius()).is_equal_approx(BHT.graze_radius * mult, 0.001)
	sm.apply_sigil(&"graze_ring")
	assert_float(pc.get_graze_radius()).is_equal_approx(BHT.graze_radius * mult * mult, 0.001)
	sm.free()
	pc.free()


func test_sigil_catalog_contains_bullet_hell_ids() -> void:
	var sm: SigilManager = SigilManagerScript.new()
	var ids: Array = []
	for c: Dictionary in sm.get_catalog():
		ids.append(String(c["id"]))
	assert_array(ids).contains(["dash_charge", "dash_cut", "graze_ring"])
	sm.free()
