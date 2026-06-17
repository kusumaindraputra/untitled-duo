## spell_vfx.gd — SpellVFX Autoload #10.
## Visual routing layer for spell cast readiness and hit feedback (GDD Rule 1,
## Visual/Audio Requirements Quick Spec 2026-06-12).
##
## Listens to SC&E signals and routes them to the correct visual systems:
##   - cast_started      → modulate pulse on Fayde (cast readiness cue)
##   - spell_hit_element → per-type GPUParticles2D hit burst at target position
##   - cast_hit_started  → stub (FP; MVP: flash Fayde cast-lock indicator)
##
## ADR: ADR-0003 (Signal-Driven Architecture), ADR-0015 (SpellVFX Particle Pool)
## Story: SC&E Story 005 — Prana Type Visual Differentiation (S5-03)
##        S7-05 — SpellVFX particle pre-pool (PERF-C1 fix)
##
## Registration: Autoload #10 in project.godot (after SpellCastingEffects).
## No class_name — Godot 4.6 rejects class_name matching the Autoload node name.
extends Node


# Pre-allocated pool: one GPUParticles2D per VfxBurstShape (indices 0–4).
# Shape params and materials are fully configured at _ready(). Hot path is zero-allocation:
# only modulate color and global_position change per hit.
var _pool: Dictionary = {}


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	SpellCastingEffects.cast_started.connect(_on_cast_started)
	SpellCastingEffects.spell_hit_element.connect(_on_spell_hit_element)
	SpellCastingEffects.cast_hit_started.connect(_on_cast_hit_started)
	HealthAndDamage.damage_taken.connect(_on_damage_taken)
	_init_pool()


func _exit_tree() -> void:
	if SpellCastingEffects.cast_started.is_connected(_on_cast_started):
		SpellCastingEffects.cast_started.disconnect(_on_cast_started)
	if SpellCastingEffects.spell_hit_element.is_connected(_on_spell_hit_element):
		SpellCastingEffects.spell_hit_element.disconnect(_on_spell_hit_element)
	if SpellCastingEffects.cast_hit_started.is_connected(_on_cast_hit_started):
		SpellCastingEffects.cast_hit_started.disconnect(_on_cast_hit_started)
	if HealthAndDamage.damage_taken.is_connected(_on_damage_taken):
		HealthAndDamage.damage_taken.disconnect(_on_damage_taken)


# ── Signal handlers ────────────────────────────────────────────────────────────

## Brief modulate pulse on Fayde when a cast begins.
## Per-type color pulse deferred to MVP (art assets required).
## [param _spell_effect] reserved for per-type pulse color at MVP scope.
func _on_cast_started(_spell_effect: SpellEffect) -> void:
	if get_tree() == null:
		return
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player == null or not player is CanvasItem:
		return
	var tween: Tween = create_tween()
	tween.tween_property(player as CanvasItem, "modulate:a", 0.6, 0.05)
	tween.tween_property(player as CanvasItem, "modulate:a", 1.0, 0.10)


## Zero-allocation hot path (ADR-0015): looks up pool node by shape,
## updates position and color, then restarts emission.
func _on_spell_hit_element(target: Node, prana_type_id: int) -> void:
	var type_data: PranaType = PranaCatalog.get_type(prana_type_id)
	if type_data == null:
		push_warning("SpellVFX: PranaCatalog.get_type(%d) returned null — no burst." % prana_type_id)
		return
	if not target is Node2D:
		push_warning("SpellVFX: target '%s' is not Node2D — no burst." % target.name)
		return
	_reuse_from_pool((target as Node2D).global_position, type_data)


## FP stub — MVP: flash Fayde cast-lock indicator for lock_duration.
func _on_cast_hit_started(_lock_duration: float) -> void:
	pass


## Flashes the damaged entity: red on player, white on enemy.
## Fires from HealthAndDamage.damage_taken — zero-allocation hot path via Tween.
func _on_damage_taken(target: Node, _final_damage: int, _current_hp: int) -> void:
	if not target is CanvasItem:
		return
	var ci: CanvasItem = target as CanvasItem
	if target.is_in_group(&"player"):
		var tw: Tween = create_tween()
		tw.tween_property(ci, "modulate", Color(2.0, 0.25, 0.25, 1.0), 0.0)
		tw.tween_property(ci, "modulate", Color.WHITE, 0.18)
	else:
		_flash_enemy_white(ci)


# ── Pool ──────────────────────────────────────────────────────────────────────

## Pre-creates one GPUParticles2D + ParticleProcessMaterial per VfxBurstShape.
## All shape params configured here — nothing created on the hot path after this.
func _init_pool() -> void:
	for shape: int in GameEnums.VfxBurstShape.values():
		var node := GPUParticles2D.new()
		var mat := ParticleProcessMaterial.new()
		node.one_shot = true
		node.emitting = false
		node.process_material = mat
		mat.gravity = Vector3(0.0, 0.0, 0.0)
		_apply_burst_shape_params(node, mat, shape)
		add_child(node)
		_pool[shape] = node


## Hot path: teleport pool node, update color, restart.
## No allocation. Concurrent same-shape hits restart the previous burst.
func _reuse_from_pool(pos: Vector2, type_data: PranaType) -> void:
	var shape: int = type_data.vfx_burst_shape
	if not _pool.has(shape):
		push_warning("SpellVFX: no pool node for shape %d — skipping burst." % shape)
		return
	var node: GPUParticles2D = _pool[shape]
	node.global_position = pos
	node.modulate = type_data.color
	node.restart()
	node.emitting = true


# ── Private helpers ────────────────────────────────────────────────────────────

## Applies per-shape physics parameters. Called once per pool slot at init.
func _apply_burst_shape_params(burst: GPUParticles2D, mat: ParticleProcessMaterial, shape: int) -> void:
	match shape:
		GameEnums.VfxBurstShape.BURST_FLAME:
			burst.amount = 12
			burst.lifetime = 0.3
			mat.direction = Vector3(0.0, -1.0, 0.0)
			mat.spread = 90.0
			mat.initial_velocity_min = 120.0
			mat.initial_velocity_max = 180.0
			mat.gravity = Vector3(0.0, 40.0, 0.0)
		GameEnums.VfxBurstShape.BURST_SPIRAL:
			burst.amount = 8
			burst.lifetime = 0.35
			mat.direction = Vector3(0.0, -1.0, 0.0)
			mat.spread = 180.0
			mat.initial_velocity_min = 60.0
			mat.initial_velocity_max = 80.0
		GameEnums.VfxBurstShape.BURST_LIGHTNING:
			burst.amount = 6
			burst.lifetime = 0.15
			mat.direction = Vector3(1.0, 0.0, 0.0)
			mat.spread = 30.0
			mat.initial_velocity_min = 200.0
			mat.initial_velocity_max = 300.0
		GameEnums.VfxBurstShape.BURST_CRYSTAL:
			burst.amount = 8
			burst.lifetime = 0.4
			mat.direction = Vector3(0.0, -1.0, 0.0)
			mat.spread = 180.0
			mat.initial_velocity_min = 40.0
			mat.initial_velocity_max = 80.0
		GameEnums.VfxBurstShape.BURST_VINE:
			burst.amount = 10
			burst.lifetime = 0.3
			mat.direction = Vector3(0.0, -1.0, 0.0)
			mat.spread = 90.0
			mat.initial_velocity_min = 60.0
			mat.initial_velocity_max = 100.0
			mat.gravity = Vector3(0.0, 20.0, 0.0)
		_:
			burst.amount = 8
			burst.lifetime = 0.3
			mat.direction = Vector3(0.0, -1.0, 0.0)
			mat.spread = 180.0
			mat.initial_velocity_min = 80.0
			mat.initial_velocity_max = 120.0


## Overbrightens [param ci] to white then returns it to normal over 0.1 s.
## Called for enemy nodes — reuses any existing modulate without conflict because
## the tween immediately sets Color.WHITE as its final state.
func _flash_enemy_white(ci: CanvasItem) -> void:
	var tw: Tween = create_tween()
	tw.tween_property(ci, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.0)
	tw.tween_property(ci, "modulate", Color.WHITE, 0.10)
