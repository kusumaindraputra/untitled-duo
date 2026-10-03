## BossPhaseEvent — one arena change a boss makes when it enters an HP phase (ADR-0028).
##
## BossDirector applies every event whose [member phase] the boss has reached. A hit
## that crosses two thresholds applies both phases' events.
class_name BossPhaseEvent
extends Resource

## Phase (1-based, as EnemyInstance.phase_changed counts) that triggers this event.
@export var phase: int = 1
## Stage hazards placed in the boss room. Room-centred unless the spec says otherwise.
@export var hazards: Array[HazardSpec] = []
## Wipes every enemy bullet on the field (a breather before a last stand).
@export var clear_bullets: bool = false
## ADR-0058: cuts the Ayden / Faith link (no swaps) until the player lands
## DuoTuning.sever_reconnect_hits hits.
@export var sever_link: bool = false
