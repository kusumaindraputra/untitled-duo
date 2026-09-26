## BossProfile — what makes one floor boss its own fight (ADR-0028).
##
## The boss's bullets live on its EnemyType (pattern layers gated by HP). This
## resource adds what happens to the arena at each HP phase, the phase banners, and
## the per-run variants BossRoster picks from.
class_name BossProfile
extends Resource

## EnemyType id of the boss.
@export var boss_type_id: int = -1
## Arena changes per phase.
@export var events: Array[BossPhaseEvent] = []
## UICopy property holding this boss's phase banners (one String per phase).
@export var banner_copy_key: StringName = &""
## Colour of the phase banners.
@export var banner_color: Color = Color(0.85, 0.65, 1.0)
## Camera trauma on each phase change.
@export var phase_trauma: float = 0.5
## Per-run variants. One is picked per run; empty = the boss never varies.
@export var variants: Array[BossVariant] = []


## Events for [param phase]: the profile's own, then [param variant]'s.
func events_for_phase(phase: int, variant: BossVariant = null) -> Array[BossPhaseEvent]:
	var out: Array[BossPhaseEvent] = []
	for ev: BossPhaseEvent in events:
		if ev != null and ev.phase == phase:
			out.append(ev)
	if variant != null:
		for ev: BossPhaseEvent in variant.extra_events:
			if ev != null and ev.phase == phase:
				out.append(ev)
	return out
