## DuoSwap — Ayden and Faith, the two brothers the player swaps between (ADR-0058).
##
## Pure rules plus the swap state PlayerController owns. Only one brother is in the
## arena at a time and only Faith can dash, so Ayden (sturdier, harder-hitting) gets
## out of trouble by swapping to her; the swap has a cooldown, gives the tagging-in brother a short
## i-frame window. The hand-off bonus on the next attack lives in SpellCastingEffects.
## Static helpers turn the active brother into the numbers combat uses, so
## SpellCastingEffects and PlayerController share one source of truth.
## Design: design/gdd/duo-swap.md
class_name DuoSwap
extends RefCounted

enum Character { AYDEN = 0, FAITH = 1 }

## Sentinel for "no duo wired" (tools and tests that never create a player): every
## multiplier is 1.0 and both grid hands apply, the pre-duo behaviour.
const NONE: int = -1

const TUNING: DuoTuning = preload("res://assets/data/duo_tuning.tres")

var _tuning: DuoTuning
var _active: Character = Character.AYDEN
var _cooldown: float = 0.0
var _iframe: float = 0.0
var _perfect_counted: bool = false


func _init(tuning: DuoTuning = TUNING) -> void:
	_tuning = tuning


# ── State ────────────────────────────────────────────────────────────────────

## The brother currently in the arena.
func active() -> Character:
	return _active


## Advances the cooldown and i-frame timers by [param delta] seconds.
func tick(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_iframe = maxf(_iframe - delta, 0.0)


## True when a swap is allowed now.
func can_swap() -> bool:
	return _cooldown <= 0.0


## Swaps to the other brother when the cooldown allows. [param hands_touching] shortens
## the cooldown (ADR-0057 touch). Returns true when the swap happened.
func try_swap(hands_touching: bool = false) -> bool:
	if not can_swap():
		return false
	_active = other(_active)
	_cooldown = cooldown_for(hands_touching, _tuning)
	_iframe = _tuning.swap_iframe_sec
	_perfect_counted = false
	return true


## Sets the active brother directly with no cooldown (between rooms, or a new run).
func set_active(c: Character) -> void:
	_active = c


## Clears every timer (preparation phase). The active brother stays.
func reset_timers() -> void:
	_cooldown = 0.0
	_iframe = 0.0
	_perfect_counted = false


## Seconds until the next swap is allowed.
func cooldown_remaining() -> float:
	return _cooldown


## True during the tag-in i-frames.
func is_tagging_in() -> bool:
	return _iframe > 0.0


## Counts a Perfect Swap once per swap, only inside the tag-in i-frames.
func try_count_perfect() -> bool:
	if not is_tagging_in() or _perfect_counted:
		return false
	_perfect_counted = true
	return true


# ── Rules ────────────────────────────────────────────────────────────────────

## The other brother.
static func other(c: Character) -> Character:
	return Character.FAITH if c == Character.AYDEN else Character.AYDEN


## Swap cooldown, shortened while the grid's hands touch.
static func cooldown_for(hands_touching: bool, t: DuoTuning = TUNING) -> float:
	return t.swap_cooldown_sec * (t.touch_swap_cooldown_mult if hands_touching else 1.0)


## Hit damage multiplier of [param c] ([constant NONE] → 1.0).
static func damage_mult(c: int, t: DuoTuning = TUNING) -> float:
	match c:
		Character.AYDEN: return t.ayden_damage_mult
		Character.FAITH: return t.faith_damage_mult
	return 1.0


## Cast range multiplier of [param c].
static func range_mult(c: int, t: DuoTuning = TUNING) -> float:
	match c:
		Character.AYDEN: return t.ayden_range_mult
		Character.FAITH: return t.faith_range_mult
	return 1.0


## Move speed multiplier of [param c].
static func speed_mult(c: int, t: DuoTuning = TUNING) -> float:
	match c:
		Character.AYDEN: return t.ayden_speed_mult
		Character.FAITH: return t.faith_speed_mult
	return 1.0


## True when [param c] can dash. Only Faith dashes; Ayden's way out is a swap to her
## ([constant NONE] → true, the pre-duo behaviour).
static func can_dash(c: int) -> bool:
	return c != Character.AYDEN


## Multiplier on damage [param c] takes: Ayden is sturdier, Faith takes it as is.
static func damage_taken_mult(c: int, t: DuoTuning = TUNING) -> float:
	return t.ayden_damage_taken_mult if c == Character.AYDEN else 1.0


## Multiplier on knock-back [param c] takes from contact hits.
static func knockback_mult(c: int, t: DuoTuning = TUNING) -> float:
	return t.ayden_knockback_mult if c == Character.AYDEN else 1.0


## Ayden's grid hand powers only Ayden: [param hand_power_mult] for him (or with no
## duo), 1.0 for Faith.
static func power_hand(c: int, hand_power_mult: float) -> float:
	return 1.0 if c == Character.FAITH else hand_power_mult


## Faith's grid hand holds status only for Faith: [param hand_control_mult] for her (or
## with no duo), 1.0 for Ayden.
static func control_hand(c: int, hand_control_mult: float) -> float:
	return 1.0 if c == Character.AYDEN else hand_control_mult


## Display name of [param c] for the HUD.
static func display_name(c: int) -> String:
	return "FAITH" if c == Character.FAITH else "AYDEN"


## HUD text colour of [param c]: Ayden's ember orange, Faith's sky blue.
static func hud_color(c: int) -> Color:
	return Color(0.55, 0.8, 1.0) if c == Character.FAITH else Color(1.0, 0.6, 0.4)
