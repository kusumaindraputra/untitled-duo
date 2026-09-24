## StyleMeter — pure style meter and room-end rank (ADR-0019).
##
## Kills, grazes, Perfect Casts and Perfect Dodges raise the meter; taking damage
## drops it, and it decays after a short idle grace. The room rank (S, A, B, C, D)
## comes from the meter's time-weighted average across the room's combat, so a long
## aggressive streak beats one lucky burst. No nodes: PaceDirector owns one and
## feeds it, and every rule here is covered by headless unit tests.
class_name StyleMeter
extends RefCounted

enum Rank { S = 0, A = 1, B = 2, C = 3, D = 4 }

const RANK_LETTERS: Array[String] = ["S", "A", "B", "C", "D"]

var tuning: PaceTuning = null

var _value: float = 0.0
var _idle: float = 0.0
## Time-weighted sum of the meter and elapsed combat time for the current room.
var _area: float = 0.0
var _elapsed: float = 0.0
var _in_room: bool = false


func _init(t: PaceTuning) -> void:
	tuning = t


## Current meter value (0..style_max).
func get_value() -> float:
	return _value


## Meter as 0..1 of style_max.
func get_ratio() -> float:
	return 0.0 if tuning.style_max <= 0.0 else _value / tuning.style_max


## Adds [param amount] style and restarts the idle grace.
func add(amount: float) -> void:
	if amount <= 0.0:
		return
	_value = minf(_value + amount, tuning.style_max)
	_idle = 0.0


## Fayde took damage: drops style by style_hit_penalty.
func on_hit() -> void:
	_value = maxf(_value - tuning.style_hit_penalty, 0.0)
	_idle = 0.0


## Advances idle decay and the room average by [param delta] seconds.
func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	_idle += delta
	if _idle > tuning.style_idle_grace_sec:
		_value = maxf(_value - tuning.style_decay_per_sec * delta, 0.0)
	if _in_room:
		_area += _value * delta
		_elapsed += delta


## Starts rank tracking for a new room. The meter itself carries over, so a
## stylish finish gives the next room a head start.
func begin_room() -> void:
	_area = 0.0
	_elapsed = 0.0
	_in_room = true


## Ends rank tracking and returns the room's rank.
func end_room() -> Rank:
	_in_room = false
	return rank_for(get_room_average())


## Time-weighted average of the meter over the current (or last) room.
func get_room_average() -> float:
	return 0.0 if _elapsed <= 0.0 else _area / _elapsed


## Rank for a room average of [param average] using tuning.rank_thresholds.
func rank_for(average: float) -> Rank:
	var th: PackedFloat32Array = tuning.rank_thresholds
	for i: int in th.size():
		if average >= th[i]:
			return i as Rank
	return Rank.D


## Rank the meter shows right now (live HUD letter).
func get_live_rank() -> Rank:
	return rank_for(_value)


## Clears the meter (new run).
func reset() -> void:
	_value = 0.0
	_idle = 0.0
	_area = 0.0
	_elapsed = 0.0
	_in_room = false


## Letter for [param rank].
static func letter(rank: Rank) -> String:
	return RANK_LETTERS[clampi(rank, 0, RANK_LETTERS.size() - 1)]


## Per-rank value from [param table] (S..D order), 0 when the table is short.
static func pick(table: PackedFloat32Array, rank: Rank) -> float:
	return table[rank] if rank < table.size() else 0.0
