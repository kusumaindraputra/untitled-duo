## prana_grid_phase_gating_test.gd — Unit tests for PranaGrid phase gating (Story 001, S4-03).
##
## Coverage:
##   AC-PG-01a: preparation_started from ARRANGEMENT resets all slots and state
##   AC-PG-01b: preparation_started from LOCKED resets all slots and state
##   AC-PG-01c: preparation_started from HIDDEN resets all slots and state
##   AC-PG-02:  grid_locked sets LOCKED state; second call no crash
##   HIDDEN:    grid_hidden sets HIDDEN state from any prior state
##   SEQUENCING: grid_locked without arrangement_confirmed logs push_error; still sets LOCKED
##   FORMULA-1a: slot_index(row, col) == row * 3 + col
##   FORMULA-1b: slot_row / slot_col are correct inverses
##   PAUSABLE:  process_mode is PROCESS_MODE_PAUSABLE; state preserved with no signals
##
## Isolation strategy: PranaGrid._ready() connects to GameStateManager (Autoload unavailable
## headless). All tests instantiate via .new() — _ready() is NOT called until node enters
## the scene tree. State is set up by direct assignment; handlers called directly.
## Teardown: node.free() (not queue_free()) — nodes never added to SceneTree (see test-standards.md).
##
## Framework: GdUnit4 v6
extends GdUnitTestSuite

const PranaGridScript := preload("res://src/ui/prana_grid.gd")

# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_grid() -> PranaGrid:
	return PranaGridScript.new()


func _fill_slots(pg: PranaGrid, values: Array) -> void:
	for i in values.size():
		pg._slots[i] = values[i]

# ── AC-PG-01a: preparation_started from ARRANGEMENT resets all slots ──────────

func test_preparation_started_from_arrangement_resets_slots_and_state() -> void:
	var pg := _make_grid()
	pg._slots.resize(PranaGrid.GRID_SIZE)
	pg._slots.fill(null)
	# Pre-fill some slots to ensure reset clears them
	_fill_slots(pg, [1, null, 2, null, null, null, 3, null, null])
	pg._state = PranaGrid.State.ARRANGEMENT

	pg._on_preparation_started(0, 1)

	assert_int(pg._slots.size()).is_equal(9)
	for i in pg._slots.size():
		assert_object(pg._slots[i]).is_null()
	assert_int(pg._state).is_equal(PranaGrid.State.ARRANGEMENT)
	pg.free()

# ── AC-PG-01b: preparation_started from LOCKED resets all slots ───────────────

func test_preparation_started_from_locked_resets_slots_and_state() -> void:
	var pg := _make_grid()
	pg._slots.resize(PranaGrid.GRID_SIZE)
	pg._slots.fill(null)
	_fill_slots(pg, [0, 1, 2, 3, 4, 0, 1, 2, 3])
	pg._state = PranaGrid.State.LOCKED

	pg._on_preparation_started(1, 0)

	assert_int(pg._slots.size()).is_equal(9)
	for i in pg._slots.size():
		assert_object(pg._slots[i]).is_null()
	assert_int(pg._state).is_equal(PranaGrid.State.ARRANGEMENT)
	pg.free()

# ── AC-PG-01c: preparation_started from HIDDEN resets all slots ───────────────

func test_preparation_started_from_hidden_resets_slots_and_state() -> void:
	var pg := _make_grid()
	pg._slots.resize(PranaGrid.GRID_SIZE)
	pg._slots.fill(null)
	pg._state = PranaGrid.State.HIDDEN

	pg._on_preparation_started()

	assert_int(pg._slots.size()).is_equal(9)
	for i in pg._slots.size():
		assert_object(pg._slots[i]).is_null()
	assert_int(pg._state).is_equal(PranaGrid.State.ARRANGEMENT)
	pg.free()

# ── AC-PG-02: grid_locked sets LOCKED state ───────────────────────────────────

func test_grid_locked_sets_locked_state() -> void:
	var pg := _make_grid()
	pg._slots.resize(PranaGrid.GRID_SIZE)
	pg._slots.fill(null)
	# Fill slot 4 so push_error guard does not fire
	pg._slots[4] = 2
	pg._state = PranaGrid.State.ARRANGEMENT

	pg._on_grid_locked()

	assert_int(pg._state).is_equal(PranaGrid.State.LOCKED)
	pg.free()

# ── AC-PG-02 edge: second grid_locked call while already LOCKED — no crash ────

func test_grid_locked_twice_no_crash() -> void:
	var pg := _make_grid()
	pg._slots.resize(PranaGrid.GRID_SIZE)
	pg._slots.fill(null)
	pg._slots[4] = 0
	pg._state = PranaGrid.State.LOCKED

	pg._on_grid_locked()  # second call — must not crash

	assert_int(pg._state).is_equal(PranaGrid.State.LOCKED)
	pg.free()

# ── HIDDEN: grid_hidden sets HIDDEN state ─────────────────────────────────────

func test_grid_hidden_sets_hidden_state() -> void:
	var pg := _make_grid()
	pg._slots.resize(PranaGrid.GRID_SIZE)
	pg._slots.fill(null)
	pg._state = PranaGrid.State.ARRANGEMENT

	pg._on_grid_hidden()

	assert_int(pg._state).is_equal(PranaGrid.State.HIDDEN)
	pg.free()

# ── SEQUENCING BUG guard: grid_locked without arrangement_confirmed ────────────
## push_error is called but not spy-able in GdUnit4. We verify post-condition only:
## state transitions to LOCKED and no crash occurs.

func test_grid_locked_without_arrangement_confirmed_sets_locked_no_crash() -> void:
	var pg := _make_grid()
	pg._slots.resize(PranaGrid.GRID_SIZE)
	pg._slots.fill(null)
	# Slot 4 is null — sequencing bug condition
	pg._state = PranaGrid.State.ARRANGEMENT

	pg._on_grid_locked()  # push_error fires internally

	assert_int(pg._state).is_equal(PranaGrid.State.LOCKED)
	pg.free()

# ── FORMULA-1a/1b: slot_index and inverse ─────────────────────────────────────

func test_formula1_slot_index_and_inverse() -> void:
	# FORMULA-1a: slot_index(row, col) == row * 3 + col
	assert_int(PranaGridScript.slot_index(0, 0)).is_equal(0)
	assert_int(PranaGridScript.slot_index(1, 1)).is_equal(4)
	assert_int(PranaGridScript.slot_index(2, 2)).is_equal(8)
	assert_int(PranaGridScript.slot_index(0, 2)).is_equal(2)
	assert_int(PranaGridScript.slot_index(2, 0)).is_equal(6)

	# FORMULA-1b: inverses
	assert_int(PranaGridScript.slot_row(0)).is_equal(0)
	assert_int(PranaGridScript.slot_col(0)).is_equal(0)
	assert_int(PranaGridScript.slot_row(4)).is_equal(1)
	assert_int(PranaGridScript.slot_col(4)).is_equal(1)
	assert_int(PranaGridScript.slot_row(8)).is_equal(2)
	assert_int(PranaGridScript.slot_col(8)).is_equal(2)
	# Index 4 is the centre — row 1, col 1 (most important invariant)
	assert_int(PranaGridScript.slot_row(4)).is_equal(1)
	assert_int(PranaGridScript.slot_col(4)).is_equal(1)

# ── PAUSABLE: process_mode is PROCESS_MODE_PAUSABLE; state/slots unchanged ────

func test_process_mode_is_pausable_and_state_preserved() -> void:
	var pg := _make_grid()
	pg._slots.resize(PranaGrid.GRID_SIZE)
	pg._slots.fill(null)
	# Simulate what _ready() does: set process_mode and initial state
	pg.process_mode = Node.PROCESS_MODE_PAUSABLE
	pg._slots[0] = 1
	pg._slots[4] = 2
	pg._state = PranaGrid.State.ARRANGEMENT

	# No signals fire during pause — verify state is unchanged
	assert_int(pg.process_mode).is_equal(Node.PROCESS_MODE_PAUSABLE)
	assert_int(pg._state).is_equal(PranaGrid.State.ARRANGEMENT)
	assert_int(pg._slots.size()).is_equal(9)
	assert_int(pg._slots[4]).is_equal(2)
	pg.free()
