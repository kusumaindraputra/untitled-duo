## KnockbackMotion — keeps knockback and pull offsets inside the arena.
##
## Knockback is a position tween, and a tween moves a body without asking the
## physics server, so a hit near the edge used to carry an enemy straight through
## ArenaBounds (or a pillar) and leave it stranded outside. This sweeps the body's
## own collision shape along the offset first and shortens it to the last safe point.
class_name KnockbackMotion
extends RefCounted

## Layers a knockback must not cross: walls (1) + half-cover debris (16) +
## full-cover pillars (32). Same set as EnemyInstance.collision_mask.
const BLOCKING_MASK: int = 49


## Returns [param offset] shortened so [param body] stops at the first blocking
## surface on [param mask]. Returns the offset unchanged when the body is outside
## the tree or has no direct CollisionShape2D child to sweep with.
static func clamp_offset(body: CollisionObject2D, offset: Vector2, mask: int = BLOCKING_MASK) -> Vector2:
	if offset == Vector2.ZERO or body == null or not body.is_inside_tree():
		return offset
	var col: CollisionShape2D = null
	for child: Node in body.get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).shape != null:
			col = child as CollisionShape2D
			break
	if col == null:
		return offset
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = col.shape
	params.transform = col.global_transform
	params.motion = offset
	params.collision_mask = mask
	params.exclude = [body.get_rid()]
	var space: PhysicsDirectSpaceState2D = body.get_world_2d().direct_space_state
	var fractions: PackedFloat32Array = space.cast_motion(params)
	# cast_motion returns [safe, unsafe]; [1, 1] means the path is clear.
	if fractions.size() < 1:
		return offset
	return offset * fractions[0]
