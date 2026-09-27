## ShakeHook — calls the ScreenShake autoload (ADR-0040) when it exists (ADR-0041).
##
## The big moments want a screen shake, and ADR-0040 makes ScreenShake the one owner
## of the camera offset. This hook looks the autoload up by path, so this code runs
## the same whether or not ScreenShake is registered yet, and it never touches a
## camera itself. Strength values mirror ShakeState.Strength (LIGHT, MEDIUM, HEAVY,
## MASSIVE).
##
## Usage:
##   ShakeHook.impact(ShakeHook.MASSIVE)
class_name ShakeHook
extends RefCounted

const LIGHT: int = 0
const MEDIUM: int = 1
const HEAVY: int = 2
const MASSIVE: int = 3
## Node path of the ScreenShake autoload.
const AUTOLOAD_PATH: NodePath = ^"/root/ScreenShake"


## Shakes by [param strength] with an optional kick along [param direction].
## Returns false (and does nothing) when ScreenShake is not available.
static func impact(strength: int, direction: Vector2 = Vector2.ZERO) -> bool:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null or loop.root == null:
		return false
	var shake: Node = loop.root.get_node_or_null(AUTOLOAD_PATH)
	if shake == null or not shake.has_method(&"impact"):
		return false
	shake.call(&"impact", clampi(strength, LIGHT, MASSIVE), direction)
	return true
