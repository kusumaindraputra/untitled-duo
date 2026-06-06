## combination_resolution.gd — CombinationResolution Autoload #8.
##
## FP stub: emits a hardcoded Ashfire T1 SpellEffect on every combat_started.
## Satisfies ADR-0002 (all 10 Autoloads registered) and enables SC&E to
## transition IDLE → READY without a live PranaGrid or resolution algorithm.
##
## MVP replacement: replace _on_combat_started with the real pipeline that reads
## PranaGrid.committed_fragments and resolves tier/modifiers/adjacency.
##
## Registration: Autoload #8 in project.godot (ADR-0002).
## No class_name — Godot 4 rejects class_name matching the Autoload node name
## ("hides autoload singleton" parse error).
## Access: CombinationResolution.combo_resolved.connect(...)
extends Node


# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted once per wave when the spell payload is resolved.
## SpellCastingEffects is the sole authorised subscriber (ADR-0009).
signal combo_resolved(spell_effect: SpellEffect)


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	GameStateManager.preparation_started.connect(_on_preparation_started)
	GameStateManager.combat_started.connect(_on_combat_started)


func _exit_tree() -> void:
	if GameStateManager.preparation_started.is_connected(_on_preparation_started):
		GameStateManager.preparation_started.disconnect(_on_preparation_started)
	if GameStateManager.combat_started.is_connected(_on_combat_started):
		GameStateManager.combat_started.disconnect(_on_combat_started)


# ── Signal handlers ───────────────────────────────────────────────────────────

## Wave reset hook — no state to clear in the FP stub.
func _on_preparation_started(_idx: int, _rem: int) -> void:
	pass


## FP stub: creates and emits a hardcoded Ashfire T1 SpellEffect.
## TODO(MVP): replace with real PranaGrid resolution pipeline.
func _on_combat_started(_is_boss: bool) -> void:
	var effect: SpellEffect = SpellEffect.new()
	effect.primary_type = 0            # Ashfire
	effect.primary_tier = 1
	effect.base_damage_modifier = 1.25
	effect.combo_attack_count = 1
	effect.aggregate_stat_bonus = {}
	combo_resolved.emit(effect)
