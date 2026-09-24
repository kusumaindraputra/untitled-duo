## bullet_pool.gd — Reuses Projectile nodes so dense patterns stay inside the frame
## budget (ADR-0018). One pool lives under each arena parent (usually WaveManager),
## created on first use by BulletPool.for_parent().
##
## A spent bullet is hidden at once and handed back via call_deferred("release"),
## so its process mode (which also removes it from the physics space) never changes
## while the physics server is flushing a body_entered callback.
class_name BulletPool
extends Node2D

const NODE_NAME: StringName = &"BulletPool"
## Idle bullets kept for reuse; extras are freed.
const MAX_IDLE: int = 256

var _idle: Array[Projectile] = []


func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE


## Returns the pool under [param parent], creating it on first use.
## Returns null when [param parent] is null (headless tests without an arena).
static func for_parent(parent: Node) -> BulletPool:
	if parent == null:
		return null
	var existing: Node = parent.get_node_or_null(NodePath(String(NODE_NAME)))
	if existing is BulletPool:
		return existing as BulletPool
	var pool := BulletPool.new()
	pool.name = NODE_NAME
	parent.add_child(pool)
	return pool


## Returns a ready-to-launch bullet parented to this pool.
func acquire() -> Projectile:
	var p: Projectile = null
	while not _idle.is_empty() and p == null:
		var candidate: Projectile = _idle.pop_back()
		if is_instance_valid(candidate):
			p = candidate
	if p == null:
		p = Projectile.new()
		p._pool = self
		add_child(p)
	else:
		p.reset_for_reuse()
	return p


## Takes back a spent bullet. Called deferred by Projectile._despawn().
func release(p: Projectile) -> void:
	if not is_instance_valid(p) or p.is_live():
		return
	if _idle.size() >= MAX_IDLE:
		p.queue_free()
		return
	p.process_mode = PROCESS_MODE_DISABLED
	p.visible = false
	_idle.append(p)


## Number of bullets waiting for reuse (test hook).
func idle_count() -> int:
	return _idle.size()
