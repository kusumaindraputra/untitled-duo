## PranaHands — pure rules for the grid's two hands (ADR-0057, combination-resolution.md
## Rule 18). Works on any 9-slot array where a non-null entry is a filled slot, so the
## same rules serve combat (PranaFragment arrays) and the prep preview (type ids).
class_name PranaHands
extends RefCounted

const TUNING: HandsTuning = preload("res://assets/data/hands_tuning.tres")


## Number of filled slots of [param slots] in [param grid].
static func count(grid: Array, slots: PackedInt32Array) -> int:
	var n: int = 0
	for i: int in slots:
		if i >= 0 and i < grid.size() and grid[i] != null:
			n += 1
	return n


## True when both hands hold Prana and hold the same number of them.
static func touching(ayden: int, faith: int) -> bool:
	return ayden > 0 and ayden == faith


## Damage multiplier from Ayden's hand (1.0 when it is empty).
static func power_mult(ayden: int, faith: int, tuning: HandsTuning = TUNING) -> float:
	var bonus: float = tuning.power_per_prana * float(ayden)
	if touching(ayden, faith):
		bonus *= tuning.touch_mult
	return 1.0 + bonus


## Status duration multiplier from Faith's hand (1.0 when it is empty).
static func control_mult(ayden: int, faith: int, tuning: HandsTuning = TUNING) -> float:
	var bonus: float = tuning.control_per_prana * float(faith)
	if touching(ayden, faith):
		bonus *= tuning.touch_mult
	return 1.0 + bonus


## Everything the grid's hands give, for [param grid]:
## { ayden: int, faith: int, touch: bool, power_mult: float, control_mult: float }.
static func read(grid: Array, tuning: HandsTuning = TUNING) -> Dictionary:
	var a: int = count(grid, tuning.ayden_slots)
	var f: int = count(grid, tuning.faith_slots)
	return {
		"ayden": a, "faith": f, "touch": touching(a, f),
		"power_mult": power_mult(a, f, tuning), "control_mult": control_mult(a, f, tuning),
	}
