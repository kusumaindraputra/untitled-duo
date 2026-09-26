## CoreRoster — every Cipher Core on the pick screen, in display order (ADR-0033).
##
## Authored as assets/data/cores/core_roster.tres. The first entry is the default
## (the neutral Steady Core), used when nothing else is picked or an id is unknown.
class_name CoreRoster
extends Resource

@export var cores: Array[CoreFrame] = []


## The default Core (first entry), or null for an empty roster.
func default_core() -> CoreFrame:
	return cores[0] if not cores.is_empty() else null


## The Core with [param id], or the default when the id is unknown.
func get_core(id: StringName) -> CoreFrame:
	for c: CoreFrame in cores:
		if c != null and c.id == id:
			return c
	return default_core()
