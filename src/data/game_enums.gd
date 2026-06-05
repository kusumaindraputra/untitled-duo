## GameEnums — Shared enum container for all cross-system enum types.
##
## Usage (no import needed — class_name provides global access):
##   func take_damage(source: GameEnums.DamageSource) -> void:
##       if source == GameEnums.DamageSource.DOT:
##           _handle_dot_damage()
##
## Rules (enforced by ADR-0006 and CI):
##   - No preload(), load(), @onready, or extends beyond RefCounted.
##   - NOT registered as an Autoload — class_name provides equivalent access at zero cost.
##   - All constants carry explicit integer assignments for .tres serialization stability.
##   - Append-only: never reorder or renumber existing values.
##
## .tres stability note:
##   Godot 4.x serializes @export enum fields as integers. If enum order changes without
##   explicit assignments, saved .tres files silently load wrong values. Explicit integers
##   prevent this. See ADR-0006 stability constraint for the verification gate procedure.
class_name GameEnums
extends RefCounted

# ── Damage and targeting ──────────────────────────────────────────────────────
## Element / damage type applied by a Prana spell or effect.
## NONE (-1) is a sentinel used when no damage class applies (e.g. pure healing).
enum DamageClass  { NONE = -1, FIRE = 0, SHADOW = 1, LIGHTNING = 2, ICE = 3, NATURE = 4 }

## How damage is delivered to the target.
enum DamageSource { DIRECT = 0, DOT = 1, CONTACT = 2 }

# ── Status effects ────────────────────────────────────────────────────────────
## Every status effect that can be applied via apply_status().
## CHILL and STAGGER must exist before any apply_status() call referencing them compiles.
enum BaseStatus   { BURN = 0, BLIND = 1, STUN = 2, FREEZE = 3, REGENERATE = 4,
					CHILL = 5, STAGGER = 6 }

# ── HP state zones (for audio/visual danger feedback) ─────────────────────────
## Danger zone of the player's current HP (used by audio and visual systems).
enum HPZone       { FULL = 0, CAREFUL = 1, DESPERATE = 2 }

# ── Game state machine ────────────────────────────────────────────────────────
## Top-level game state. Driven by GameStateManager; consumed by all signal handlers.
enum GameState    { MAIN_MENU = 0, PREPARATION_PHASE = 1, COMBAT_PHASE = 2,
					PAUSED = 3, RUN_SUMMARY = 4, DEATH_SCREEN = 5 }

# ── Run outcome ───────────────────────────────────────────────────────────────
## Result of a completed run. NONE = run still in progress.
enum RunOutcome   { NONE = 0, WIN = 1, LOSS = 2 }

# ── Enemy archetypes ──────────────────────────────────────────────────────────
## Broad behavioural category that governs an enemy's AI profile.
enum EnemyArchetype { SEEKER = 0, RUSHER = 1, SWARMER = 2, BOSS = 3 }

# ── Enemy AI state ────────────────────────────────────────────────────────────
## Per-enemy state machine node. STUNNED maps to BaseStatus.STUN but is distinct
## from BaseStatus — see Enemy AI GDD: Stun != Slow.
enum EnemyState   { IDLE = 0, PURSUING = 1, ATTACKING = 2, STUNNED = 3, DEAD = 4 }

# ── Wave state ────────────────────────────────────────────────────────────────
## State of the current combat wave.
enum WaveState    { IDLE = 0, WAVE_ACTIVE = 1, WAVE_COMPLETE = 2 }

# ── Enemy catalog status ───────────────────────────────────────────────────────
## Lifecycle status of an EnemyType catalog entry.
## VS_SCOPE = defined but not spawnable at MVP; INACTIVE = deprecated (ID stability only).
enum EnemyStatus { ACTIVE = 0, VS_SCOPE = 1, INACTIVE = 2 }

# ── Visual and audio routing ──────────────────────────────────────────────────
## Animation variant played on the caster when a spell fires.
enum CastAnimation { CAST_THRUST = 0, CAST_REACH = 1, CAST_SNAP = 2,
					 CAST_PUSH = 3, CAST_BLOOM = 4 }

## Shape of the on-hit VFX burst spawned at the target.
enum VfxBurstShape { BURST_FLAME = 0, BURST_SPIRAL = 1, BURST_LIGHTNING = 2,
					 BURST_CRYSTAL = 3, BURST_VINE = 4 }
