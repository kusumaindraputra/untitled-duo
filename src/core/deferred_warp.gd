## DeferredWarp — a TimeWarp slow-mo that waits for a running hitstop to end (ADR-0041).
##
## Big moments land on a kill, and every kill already starts a short hitstop, so a
## plain TimeWarp.try_apply() at that instant is refused. A DeferredWarp keeps
## retrying for up to [member wait_sec] real seconds: the hitstop freeze reads first,
## then the slow-mo takes over. It never overrides another warp (ADR-0019 rule).
## The owner calls [method tick] every frame; nothing here needs the scene tree
## except the SceneTree passed to tick for TimeWarp's timer.
class_name DeferredWarp
extends RefCounted

var _scale: float = 1.0
var _sec: float = 0.0
## Real seconds left to keep retrying; <= 0 means no request is pending.
var _wait_left: float = 0.0
var _applied: bool = false


## Real seconds behind a frame's scaled [param delta]: delta / Engine.time_scale.
## Unlike wall-clock ticks this also holds under Movie Maker's fixed frame rate.
static func real_delta(delta: float) -> float:
	return delta / maxf(Engine.time_scale, 0.01)


## Queues a slow-mo of [param scale] for [param sec] real seconds, retried for up to
## [param wait_sec] real seconds. Replaces any request still pending.
func request(scale: float, sec: float, wait_sec: float) -> void:
	_scale = scale
	_sec = sec
	_wait_left = maxf(wait_sec, 0.0001)
	_applied = false


## True while a request is still waiting for time to run normally.
func is_pending() -> bool:
	return _wait_left > 0.0


## True once the last request was applied.
func was_applied() -> bool:
	return _applied


## Drops the pending request.
func cancel() -> void:
	_wait_left = 0.0


## Tries the pending request against [param tree]. [param real_dt] is real seconds
## since the last tick. Returns true on the tick the slow-mo starts.
func tick(tree: SceneTree, real_dt: float) -> bool:
	if _wait_left <= 0.0:
		return false
	if TimeWarp.try_apply(tree, _scale, _sec):
		_wait_left = 0.0
		_applied = true
		return true
	_wait_left -= real_dt
	return false
