## spell_vfx.gd — SpellVFX Autoload #10.
## Visual routing layer for spell cast readiness and hit feedback (GDD Rule 1,
## Visual/Audio Requirements Quick Spec 2026-06-12).
##
## Listens to SC&E signals and routes them to the correct visual systems:
##   - cast_started      → modulate pulse on Fayde (cast readiness cue)
##   - spell_hit_element → per-type GPUParticles2D hit burst at target position
##   - cast_hit_started  → stub (FP; MVP: flash Fayde cast-lock indicator)
##
## ADR: ADR-0003 (Signal-Driven Architecture)
## Story: SC&E Story 005 — Prana Type Visual Differentiation (S5-03)
##
## Registration: Autoload #10 in project.godot (after SpellCastingEffects).
## No class_name — Godot 4.6 rejects class_name matching the Autoload node name.
extends Node


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	SpellCastingEffects.cast_started.connect(_on_cast_started)
	SpellCastingEffects.spell_hit_element.connect(_on_spell_hit_element)
	SpellCastingEffects.cast_hit_started.connect(_on_cast_hit_started)


func _exit_tree() -> void:
	if SpellCastingEffects.cast_started.is_connected(_on_cast_started):
		SpellCastingEffects.cast_started.disconnect(_on_cast_started)
	if SpellCastingEffects.spell_hit_element.is_connected(_on_spell_hit_element):
		SpellCastingEffects.spell_hit_element.disconnect(_on_spell_hit_element)
	if SpellCastingEffects.cast_hit_started.is_connected(_on_cast_hit_started):
		SpellCastingEffects.cast_hit_started.disconnect(_on_cast_hit_started)


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


## Spawns a one-shot hit burst at the target's position using the Prana type's
## color and vfx_burst_shape from PranaCatalog.
func _on_spell_hit_element(target: Node, prana_type_id: int) -> void:
	var type_data: PranaType = PranaCatalog.get_type(prana_type_id)
	if type_data == null:
		push_warning("SpellVFX: PranaCatalog.get_type(%d) returned null — no burst." % prana_type_id)
		return
	if not target is Node2D:
		push_warning("SpellVFX: target '%s' is not Node2D — no burst." % target.name)
		return
	_spawn_hit_burst((target as Node2D).global_position, type_data)


## FP stub — MVP: flash Fayde cast-lock indicator for lock_duration.
func _on_cast_hit_started(_lock_duration: float) -> void:
	pass


# ── Private helpers ────────────────────────────────────────────────────────────

## Instantiates a one-shot GPUParticles2D at [param pos]; auto-frees on finish.
func _spawn_hit_burst(pos: Vector2, type_data: PranaType) -> void:
	var burst := GPUParticles2D.new()
	add_child(burst)
	burst.global_position = pos
	burst.one_shot = true
	burst.emitting = false
	_configure_burst(burst, type_data)
	burst.emitting = true
	burst.finished.connect(burst.queue_free)


## Applies per-type particle parameters. Color always from type_data.color — no hardcoded hex.
func _configure_burst(burst: GPUParticles2D, type_data: PranaType) -> void:
	var mat := ParticleProcessMaterial.new()
	burst.modulate = type_data.color
	burst.process_material = mat
	mat.gravity = Vector3(0.0, 0.0, 0.0)
	_apply_burst_shape_params(burst, mat, type_data.vfx_burst_shape)


## Applies per-shape physics parameters to [param burst] and [param mat].
## Extracted to keep _configure_burst under the 40-line method limit.
func _apply_burst_shape_params(burst: GPUParticles2D, mat: ParticleProcessMaterial, shape: GameEnums.VfxBurstShape) -> void:
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
