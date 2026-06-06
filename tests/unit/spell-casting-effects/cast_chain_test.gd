## cast_chain_test.gd — Unit tests for SC&E cast input, float accumulators, and chain timing.
##
## Coverage:
##   AC-SC-02: Cast rejected in IDLE state — _combo_index remains 0
##   AC-SC-03: Cast rejected when _cast_lock_timer > 0 — _combo_index unchanged
##   AC-SC-04: _combo_index advances on successive casts within window (Deepfrost T3)
##   AC-SC-05: Chain window expiry resets _combo_index=0, _state=READY
##   AC-SC-10a: Voidblue T1 lock duration == 0.12
##   AC-SC-10b: Ashfire T1 lock duration == 0.20
##
## Setup pattern:
##   - SC&E instantiated with SCEScript.new() and added via add_child() — not add_child_autofree()
##     because we need explicit teardown via remove_child() + free() (not queue_free — exit 101).
##   - Signal handlers called directly (_on_combat_started, _on_combo_resolved) for state setup.
##   - Cast input simulated via Input.action_press(&"cast") before _process(delta),
##     then Input.action_release(&"cast") after — established headless pattern.
##   - State assertions used throughout; no monitor_signals() to avoid cross-test contamination.
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

const SCEScript = preload("res://src/systems/spell_casting_effects.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_sce() -> Node:
	var sce: Node = SCEScript.new()
	add_child(sce)
	return sce


func _teardown_sce(sce: Node) -> void:
	remove_child(sce)
	sce.free()


## Builds a minimal SpellEffect with the given primary_type, combo_attack_count, and tier.
## [param tier] must have enough ATTACK_DATA entries to cover the combo_count.
## Default tier=1 gives one entry; set tier=N for combo_count=N.
func _make_spell_effect(pt: int, combo_count: int = 1, tier: int = 1) -> SpellEffect:
	var se: SpellEffect = SpellEffect.new()
	se.primary_type = pt
	se.primary_tier = tier
	se.base_damage_modifier = 1.0
	se.combo_attack_count = combo_count
	se.aggregate_stat_bonus = {}
	return se


## Puts SC&E into READY state with the given SpellEffect cached.
func _ready_sce_with_effect(sce: Node, se: SpellEffect) -> void:
	sce._on_combat_started(false)
	sce._on_combo_resolved(se)


## Simulates one cast press: action_press → _process(delta) → action_release.
## Input.action_press/release per the headless pattern (PlayerController Story 002).
func _press_cast(sce: Node, delta: float = 0.001) -> void:
	Input.action_press(&"cast")
	sce._process(delta)
	Input.action_release(&"cast")


# ── before_test: ensure "cast" action is registered ──────────────────────────

func before_test() -> void:
	if not InputMap.has_action(&"cast"):
		InputMap.add_action(&"cast")


# ── AC-SC-02: Cast rejected in IDLE ──────────────────────────────────────────

## GIVEN SC&E in IDLE (no combo_resolved received)
## WHEN cast action pressed
## THEN _combo_index remains 0 and _state remains IDLE
func test_sce_cast_rejected_in_idle_combo_index_stays_zero() -> void:
	var sce = _make_sce()
	# Do NOT call _on_combat_started or _on_combo_resolved — state stays IDLE

	_press_cast(sce)

	assert_int(sce._combo_index).is_equal(0)
	assert_int(sce._state).is_equal(sce.SCEState.IDLE)

	_teardown_sce(sce)


# ── AC-SC-03: Cast rejected when cast-locked ─────────────────────────────────

## GIVEN SC&E in READY state with valid SpellEffect and _cast_lock_timer = 0.05
## WHEN cast action fires
## THEN _combo_index unchanged (still 0) — lock blocks input
func test_sce_cast_rejected_when_cast_lock_timer_nonzero_combo_index_unchanged() -> void:
	var sce = _make_sce()
	_ready_sce_with_effect(sce, _make_spell_effect(1))  # Voidblue T1
	sce._cast_lock_timer = 0.05

	_press_cast(sce)

	assert_int(sce._combo_index).is_equal(0)

	_teardown_sce(sce)


# ── AC-SC-04: _combo_index advances on successive casts ──────────────────────

## GIVEN Deepfrost T3 SpellEffect (combo_attack_count=3) cached; SC&E in READY
## WHEN first cast fires; _process(0.13) called to expire lock; second cast fires
## THEN _combo_index == 2 after second press
##
## Note: _trigger_cast() called directly (not via _press_cast) because
## Input.is_action_just_pressed() does not advance its "just pressed" frame
## counter between _process() calls in headless mode — the lock-expiry
## _process(0.13) would spuriously re-fire the cast. This tests AC-SC-04's
## contract (combo_index advances) without relying on headless input frames.
func test_sce_combo_index_advances_on_successive_casts_within_window() -> void:
	var sce = _make_sce()
	_ready_sce_with_effect(sce, _make_spell_effect(3, 3, 3))  # Deepfrost T3 — tier=3, combo_attack_count=3

	# First cast (direct call bypasses headless is_action_just_pressed limitation)
	sce._trigger_cast()
	assert_int(sce._combo_index).is_equal(1)

	# Expire the cast lock — 0.13s > CAST_LOCK_DURATION (0.12s)
	sce._process(0.13)
	assert_int(sce._state).is_equal(sce.SCEState.CHAINING)

	# Second cast
	sce._trigger_cast()
	assert_int(sce._combo_index).is_equal(2)

	_teardown_sce(sce)


# ── AC-SC-05: Chain window expiry resets chain to READY ──────────────────────

## GIVEN SC&E in CHAINING state with _combo_index=1, _combo_window_timer=2.0
## WHEN _process(2.1) called (> COMBO_CONTINUATION_WINDOW=2.0)
## THEN _combo_index == 0, _state == READY
func test_sce_chain_window_expiry_resets_combo_index_and_state_to_ready() -> void:
	var sce = _make_sce()
	_ready_sce_with_effect(sce, _make_spell_effect(1, 3))  # Voidblue, combo_count=3

	# Manually put SC&E into CHAINING with _combo_index=1 and window running
	sce._state = sce.SCEState.CHAINING
	sce._combo_index = 1
	sce._combo_window_timer = 2.0

	# Advance time past the window
	sce._process(2.1)

	assert_int(sce._combo_index).is_equal(0)
	assert_int(sce._state).is_equal(sce.SCEState.READY)

	_teardown_sce(sce)


# ── AC-SC-10a: Voidblue T1 uses default cast lock duration ───────────────────

## GIVEN SC&E in READY with Voidblue T1 SpellEffect (primary_type=1)
## WHEN cast fires
## THEN _cast_lock_timer == CAST_LOCK_DURATION (0.12)
func test_sce_voidblue_cast_sets_lock_timer_to_default_duration() -> void:
	var sce = _make_sce()
	_ready_sce_with_effect(sce, _make_spell_effect(1))  # Voidblue — primary_type=1

	_press_cast(sce)

	assert_float(sce._cast_lock_timer).is_equal_approx(sce.CAST_LOCK_DURATION, 0.001)

	_teardown_sce(sce)


# ── AC-SC-10b: Ashfire T1 uses extended cast lock duration ───────────────────

## GIVEN SC&E in READY with Ashfire T1 SpellEffect (primary_type=0)
## WHEN cast fires
## THEN _cast_lock_timer == ASHFIRE_CAST_LOCK_DURATION (0.20)
func test_sce_ashfire_cast_sets_lock_timer_to_extended_duration() -> void:
	var sce = _make_sce()
	_ready_sce_with_effect(sce, _make_spell_effect(0))  # Ashfire — primary_type=0

	_press_cast(sce)

	assert_float(sce._cast_lock_timer).is_equal_approx(sce.ASHFIRE_CAST_LOCK_DURATION, 0.001)

	_teardown_sce(sce)
