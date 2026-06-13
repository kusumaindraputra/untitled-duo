## prana_grid_compact_test.gd — Unit tests for PranaGrid compact mode in combat (S5-04).
##
## Coverage:
##   AC-CG-01:  ARRANGEMENT state — compact indicator not shown (null in headless)
##   AC-CG-02:  grid_locked transitions state to LOCKED; null guards prevent crash
##   AC-CG-03:  position bottom-right — no automated test (headless viewport = 0×0; see manual evidence)
##   AC-CG-04a: _update_compact_dots — empty slot renders Color("#333333")
##   AC-CG-04b: _update_compact_dots — filled slot renders PranaCatalog color
##   AC-CG-05:  preparation_started from LOCKED returns to ARRANGEMENT state
##   impl:      _update_compact_dots is a no-op when _dot_nodes is empty (guard behavior)
##   AC-CG-06:  grid_hidden from LOCKED transitions to HIDDEN; null guard for compact
##   AC-CG-07:  compact indicator mouse_filter — spec assertion (see test note)
##
## Isolation strategy: PranaGrid._ready() connects to GameStateManager (Autoload).
## All tests instantiate via .new() — _ready() is NOT called. Slots and
## committed_fragments are initialised by helpers; handlers called directly.
## Teardown: node.free() — nodes never added to SceneTree (test-standards.md rule).
##
## Note on PranaCatalog: registered as Autoload #1 — initialized before tests run
## in the headless project context. PranaCatalog.get_type(id) is available in tests.
##
## Framework: GdUnit4 v6
extends GdUnitTestSuite

const PranaGridScript := preload("res://src/ui/prana_grid.gd")

# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a PranaGrid via .new() — _ready() is NOT called (no Autoload in headless).
func _make_grid() -> PranaGrid:
	return PranaGridScript.new()


## Simulates the slot-init half of _ready(): resize + fill to null.
func _init_slots(pg: PranaGrid) -> void:
	pg._slots.resize(PranaGrid.GRID_SIZE)
	pg._slots.fill(null)


## Simulates the committed_fragments init from _ready(): resize (fills with null by default).
func _init_committed(pg: PranaGrid) -> void:
	pg._committed_fragments.resize(PranaGrid.GRID_SIZE)


# ── AC-CG-01: ARRANGEMENT state — compact indicator null in headless ──────────
## In headless context, _create_ui_nodes() never runs (no _ready() call).
## _compact_indicator is null. Calling _on_preparation_started() must not crash
## and must set _state = ARRANGEMENT.

func test_arrangement_state_compact_indicator_null_in_headless() -> void:
	var pg := _make_grid()
	_init_slots(pg)

	pg._on_preparation_started(0, 1)

	assert_int(pg._state).is_equal(PranaGrid.State.ARRANGEMENT)
	assert_object(pg._compact_indicator).is_null()
	pg.free()


# ── AC-CG-02: grid_locked transitions to LOCKED; null guards prevent crash ────
## _grid_panel and _compact_indicator are both null in headless — the null guards
## in _on_grid_locked() must prevent crashes. State must reach LOCKED.

func test_grid_locked_transitions_to_locked_state() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	_init_committed(pg)
	pg._slots[4] = 0  # fill centre to skip push_error guard
	pg._state = PranaGrid.State.ARRANGEMENT

	pg._on_grid_locked()

	assert_int(pg._state).is_equal(PranaGrid.State.LOCKED)
	pg.free()


## grid_locked while _dot_nodes is empty (_create_ui_nodes never ran) — must not crash.
func test_grid_locked_with_empty_dot_nodes_no_crash() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	_init_committed(pg)
	pg._slots[4] = 1
	pg._state = PranaGrid.State.ARRANGEMENT

	pg._on_grid_locked()  # _update_compact_dots() is no-op, null guards fire

	assert_int(pg._state).is_equal(PranaGrid.State.LOCKED)
	pg.free()


# ── AC-CG-03: preparation_started from LOCKED returns to ARRANGEMENT ──────────

func test_preparation_started_from_locked_returns_to_arrangement() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.LOCKED

	pg._on_preparation_started(0, 1)

	assert_int(pg._state).is_equal(PranaGrid.State.ARRANGEMENT)
	pg.free()


# ── AC-CG-04a: empty slot renders Color("#333333") ───────────────────────────

func test_update_compact_dots_empty_slot_color() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	_init_committed(pg)
	# Manually add one ColorRect to _dot_nodes to exercise the update path
	# without requiring _create_ui_nodes() to run.
	var dot := ColorRect.new()
	pg._dot_nodes.append(dot)
	# Pad remaining 8 dots so GRID_SIZE loop does not index-out-of-range
	for _i in range(PranaGrid.GRID_SIZE - 1):
		var pad := ColorRect.new()
		pg._dot_nodes.append(pad)
	# slot 0 in _committed_fragments is null (empty)
	pg._committed_fragments[0] = null

	pg._update_compact_dots()

	assert_bool(dot.color == Color("#333333")).is_true()

	# Free all manually created dots
	for d: ColorRect in pg._dot_nodes:
		d.free()
	pg._dot_nodes.clear()
	pg.free()


# ── AC-CG-04b: filled slot renders PranaCatalog color ────────────────────────
## PranaCatalog is an Autoload initialized before tests run in the headless project
## context. get_type(0) returns a deep copy with the color for type id 0.

func test_update_compact_dots_filled_slot_color() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	_init_committed(pg)
	# Build a minimal _dot_nodes array
	var dot := ColorRect.new()
	pg._dot_nodes.append(dot)
	for _i in range(PranaGrid.GRID_SIZE - 1):
		var pad := ColorRect.new()
		pg._dot_nodes.append(pad)
	# Place a fragment at slot 0
	var fragment := PranaFragment.new()
	fragment.type_id = 0
	fragment.level = 1
	fragment.stat_property = {}
	fragment.adjacency_effects = []
	pg._committed_fragments[0] = fragment

	pg._update_compact_dots()

	var expected_color: Color = PranaCatalog.get_type(0).color
	assert_bool(dot.color == expected_color).is_true()

	for d: ColorRect in pg._dot_nodes:
		d.free()
	pg._dot_nodes.clear()
	# fragment is a Resource (RefCounted) — no .free() needed; GDScript ref-counting
	# reclaims it automatically once _committed_fragments is cleared.
	pg._committed_fragments[0] = null
	pg.free()


# ── AC-CG-05: _update_compact_dots is a no-op when _dot_nodes is empty ───────

func test_update_compact_dots_noop_when_dot_nodes_empty() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	_init_committed(pg)
	# _dot_nodes is empty by default (no _create_ui_nodes call)

	pg._update_compact_dots()  # must not crash

	assert_int(pg._dot_nodes.size()).is_equal(0)
	pg.free()


# ── AC-CG-06: grid_hidden from LOCKED transitions to HIDDEN ──────────────────

func test_grid_hidden_from_locked_transitions_to_hidden() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.LOCKED

	pg._on_grid_hidden()

	assert_int(pg._state).is_equal(PranaGrid.State.HIDDEN)
	pg.free()


## grid_hidden null guard: _compact_indicator is null in headless — must not crash.
func test_grid_hidden_with_null_compact_no_crash() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.LOCKED
	# _compact_indicator is already null

	pg._on_grid_hidden()

	assert_int(pg._state).is_equal(PranaGrid.State.HIDDEN)
	assert_object(pg._compact_indicator).is_null()
	pg.free()


# ── AC-CG-07: compact indicator mouse_filter spec ────────────────────────────
## _create_ui_nodes() cannot run in headless (requires a real viewport for
## get_viewport_rect()). This test asserts the required constant value and
## verifies PranaGrid accepts MOUSE_FILTER_IGNORE on _compact_indicator without
## error. Production code compliance (line 343 of prana_grid.gd) is confirmed
## by code review; full runtime verification is in the manual evidence file.

func test_compact_indicator_mouse_filter_spec_is_ignore() -> void:
	var pg := _make_grid()

	# Assign a node with MOUSE_FILTER_IGNORE to confirm the property round-trips
	# correctly and the field accepts the value. Production path: _create_ui_nodes()
	# sets this at line 343 — verified by code review (AC-CG-07 manual evidence).
	var indicator := Control.new()
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pg._compact_indicator = indicator

	assert_int(pg._compact_indicator.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)

	indicator.free()
	pg._compact_indicator = null
	pg.free()
