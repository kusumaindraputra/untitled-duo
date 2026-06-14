## combat_hud_dash_test.gd — Unit tests for CombatHUD dash discoverability + cooldown (S5-05).
##
## Coverage:
##   AC-DH-01: combat_started shows dash hint label
##   AC-DH-02: preparation_started hides dash hint label
##   AC-DH-03: dash hint label text contains "Shift"
##   AC-DH-04: dash_cooldown_changed(false) dims cooldown icon alpha
##   AC-DH-05: dash_cooldown_changed(true) restores cooldown icon alpha
##   AC-DH-06: preparation_started resets icon to ready alpha
##   AC-DH-07: run_started hides hint and resets icon alpha
##
## Setup pattern (matches combat_hud_test.gd convention):
##   - CombatHUD instantiated with add_child() — _ready() connects to Autoloads (always present).
##   - set_process(false) — no frame processing needed for dash tests.
##   - PlayerController.new() provides dash_cooldown_changed signal; NOT added to SceneTree.
##   - Signal connected manually: pc.dash_cooldown_changed.connect(hud._on_dash_cooldown_changed).
##   - Teardown: pc.free() → remove_child(hud) → hud.free() (not queue_free — headless rule).
##
## Note: hud typed as Node to avoid GdUnit4 type inference errors — CombatHUD has class_name but Node is safer here.
##
## Framework: GdUnit4 v6
extends GdUnitTestSuite

const CombatHUDScript = preload("res://src/ui/combat_hud.gd")
const PlayerControllerScript = preload("res://src/gameplay/player_controller.gd")


## Creates a CombatHUD in the scene tree with manual process control.
## Matches the _make_hud() pattern from combat_hud_test.gd.
func _make_hud() -> Node:
	var hud: Node = CombatHUDScript.new()
	add_child(hud)
	hud.set_process(false)
	return hud


## Removes and frees a CombatHUD created by _make_hud().
func _teardown_hud(hud: Node) -> void:
	remove_child(hud)
	hud.free()


## Creates a PlayerController — signal source only. NOT added to SceneTree.
func _make_pc() -> PlayerController:
	return PlayerControllerScript.new()


# ── AC-DH-01: combat_started shows dash hint label ───────────────────────────

func test_combat_started_shows_dash_hint_label() -> void:
	var hud: Node = _make_hud()

	hud._on_combat_started(false)

	assert_bool(hud._dash_hint_label.visible).is_true()
	_teardown_hud(hud)


# ── AC-DH-02: preparation_started hides dash hint label ──────────────────────

func test_preparation_started_hides_dash_hint_label() -> void:
	var hud: Node = _make_hud()
	hud._on_combat_started(false)

	hud._on_preparation_started(0, 1)

	assert_bool(hud._dash_hint_label.visible).is_false()
	_teardown_hud(hud)


# ── AC-DH-03: dash hint label text contains "Shift" ──────────────────────────

func test_dash_hint_label_text_contains_shift() -> void:
	var hud: Node = _make_hud()

	assert_bool(hud._dash_hint_label.text.contains("Shift")).is_true()
	_teardown_hud(hud)


# ── AC-DH-04: dash_cooldown_changed(false) dims cooldown icon alpha ───────────

func test_dash_cooldown_changed_false_dims_icon_alpha() -> void:
	var hud: Node = _make_hud()
	var pc: PlayerController = _make_pc()
	pc.dash_cooldown_changed.connect(hud._on_dash_cooldown_changed)

	pc.dash_cooldown_changed.emit(false)

	assert_float(hud._dash_cooldown_icon.color.a).is_less(1.0)
	pc.free()
	_teardown_hud(hud)


# ── AC-DH-05: dash_cooldown_changed(true) restores cooldown icon alpha ────────

func test_dash_cooldown_changed_true_restores_icon_alpha() -> void:
	var hud: Node = _make_hud()
	var pc: PlayerController = _make_pc()
	pc.dash_cooldown_changed.connect(hud._on_dash_cooldown_changed)
	pc.dash_cooldown_changed.emit(false)

	pc.dash_cooldown_changed.emit(true)

	assert_float(hud._dash_cooldown_icon.color.a).is_equal(1.0)
	pc.free()
	_teardown_hud(hud)


# ── AC-DH-06: preparation_started resets icon to ready alpha ─────────────────

func test_preparation_started_resets_cooldown_icon_alpha() -> void:
	var hud: Node = _make_hud()
	var pc: PlayerController = _make_pc()
	pc.dash_cooldown_changed.connect(hud._on_dash_cooldown_changed)
	pc.dash_cooldown_changed.emit(false)

	hud._on_preparation_started(0, 1)

	assert_float(hud._dash_cooldown_icon.color.a).is_equal(1.0)
	pc.free()
	_teardown_hud(hud)


# ── AC-DH-07: run_started hides hint and resets icon alpha ───────────────────

func test_run_started_hides_hint_and_resets_icon_alpha() -> void:
	var hud: Node = _make_hud()
	var pc: PlayerController = _make_pc()
	pc.dash_cooldown_changed.connect(hud._on_dash_cooldown_changed)
	hud._on_combat_started(false)
	pc.dash_cooldown_changed.emit(false)

	hud._on_run_started()

	assert_bool(hud._dash_hint_label.visible).is_false()
	assert_float(hud._dash_cooldown_icon.color.a).is_equal(1.0)
	pc.free()
	_teardown_hud(hud)
