## sigil_reroll_test.gd — Sigil reroll price and offer size (ADR-0033).
##
## Coverage:
##   AC-RR-01: the first paid reroll costs reroll_hp_cost and pays it through the payer
##   AC-RR-02: each paid reroll raises the next price by reroll_hp_step
##   AC-RR-03: a price that would leave Fayde below 1 HP is refused and nothing is paid
##   AC-RR-04: free rerolls cost 0, are used first, and refill on the next screen
##   AC-RR-05: offer_cards sets how many cards an offer rolls
##
## HP is injected through set_hp_seams(), so no HealthAndDamage autoload state is touched.
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const SigilManagerScript = preload("res://src/systems/sigil_manager.gd")
const CONFIG: SigilConfig = preload("res://assets/data/sigil_config.tres")

## Fake HP pool: [hp] shared by the provider and payer closures, plus a payment log.
var _hp: Array[int] = [100]
var _paid: Array[int] = []


func before_test() -> void:
	_hp = [100]
	_paid = []


func _make_sm() -> SigilManager:
	var sm: SigilManager = SigilManagerScript.new()
	sm.set_hp_seams(
		func() -> int: return _hp[0],
		func(amount: int) -> bool:
			if _hp[0] - amount < 1:
				return false
			_hp[0] -= amount
			_paid.append(amount)
			return true)
	sm.begin_screen()
	return sm


func test_reroll_first_paid_costs_base_price() -> void:
	var sm: SigilManager = _make_sm()

	assert_int(sm.reroll_cost()).is_equal(CONFIG.reroll_hp_cost)
	assert_bool(sm.try_reroll()).is_true()

	assert_array(_paid).is_equal([CONFIG.reroll_hp_cost])
	assert_int(_hp[0]).is_equal(100 - CONFIG.reroll_hp_cost)
	sm.free()


func test_reroll_price_rises_by_step_each_paid_reroll() -> void:
	var sm: SigilManager = _make_sm()

	sm.try_reroll()
	sm.try_reroll()

	assert_int(sm.reroll_cost()).is_equal(CONFIG.reroll_hp_cost + 2 * CONFIG.reroll_hp_step)
	# The rising price carries across reward screens within the run.
	sm.begin_screen()
	assert_int(sm.reroll_cost()).is_equal(CONFIG.reroll_hp_cost + 2 * CONFIG.reroll_hp_step)
	sm.free()


func test_reroll_lethal_price_is_refused() -> void:
	var sm: SigilManager = _make_sm()
	_hp[0] = CONFIG.reroll_hp_cost  # paying would leave 0 HP

	assert_bool(sm.can_reroll(_hp[0])).is_false()
	assert_bool(sm.try_reroll()).is_false()

	assert_array(_paid).is_empty()
	assert_int(sm.reroll_cost()).is_equal(CONFIG.reroll_hp_cost)
	sm.free()


func test_reroll_free_rerolls_used_first_and_refill_per_screen() -> void:
	var sm: SigilManager = _make_sm()
	sm.free_rerolls_per_offer = 1
	sm.begin_screen()
	_hp[0] = 1  # too weak to pay anything

	assert_int(sm.reroll_cost()).is_equal(0)
	assert_bool(sm.try_reroll()).is_true()
	assert_array(_paid).is_empty()
	# The free one is spent; the next is priced and refused at 1 HP.
	assert_bool(sm.try_reroll()).is_false()

	sm.begin_screen()
	assert_int(sm.reroll_cost()).is_equal(0)
	sm.free()


func test_reroll_emits_hp_paid() -> void:
	var sm: SigilManager = _make_sm()
	var got: Array[int] = []
	sm.rerolled.connect(func(hp_paid: int) -> void: got.append(hp_paid))
	sm.free_rerolls_per_offer = 1
	sm.begin_screen()

	sm.try_reroll()
	sm.try_reroll()

	assert_array(got).is_equal([0, CONFIG.reroll_hp_cost])
	sm.free()


func test_reroll_offer_cards_default_and_override() -> void:
	var sm: SigilManager = _make_sm()
	assert_int(sm.offer_cards).is_equal(CONFIG.offer_cards)

	sm.offer_cards = 4
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	assert_int(sm.roll_choices(sm.offer_cards, rng).size()).is_equal(4)
	sm.free()
