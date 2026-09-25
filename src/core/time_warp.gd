## TimeWarp — shared guard for short Engine.time_scale effects (ADR-0019).
##
## Hitstop, Perfect Dodge slow-mo and the death slow-mo all write Engine.time_scale.
## The rule that keeps them from fighting: a new warp only starts while time runs at
## normal speed, and a warp only restores 1.0 if the scale is still the value it set.
## So a death slow-mo that starts during a hitstop is never cut short by it, and two
## warps never stack. Timers ignore time_scale, so durations are real seconds.
class_name TimeWarp
extends RefCounted

## Scale at or above which time counts as running normally.
const NORMAL_THRESHOLD: float = 0.999


## True when no other warp owns Engine.time_scale.
static func is_free() -> bool:
	return Engine.time_scale >= NORMAL_THRESHOLD


## Sets Engine.time_scale to [param scale] for [param real_sec] real seconds.
## Returns false (and changes nothing) when another warp is active or [param tree]
## is null. [param scale] is clamped to 0.01..1.0.
static func try_apply(tree: SceneTree, scale: float, real_sec: float) -> bool:
	if tree == null or not is_free() or real_sec <= 0.0:
		return false
	var s: float = clampf(scale, 0.01, 1.0)
	Engine.time_scale = s
	tree.create_timer(real_sec, true, false, true).timeout.connect(func() -> void:
		release(s))
	return true


## Restores normal speed if Engine.time_scale is still [param scale].
static func release(scale: float) -> void:
	if is_equal_approx(Engine.time_scale, scale):
		Engine.time_scale = 1.0
