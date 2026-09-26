## Records — formats the player's records for the menu and the run summary (beta plan F3).
##
## MetaProgress stores the times; this turns them into text. Bosses are listed in floor
## order (EnemyCatalog BOSS entries sorted by HP, which rises with each floor).
class_name Records
extends RefCounted

const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")


## Boss type ids in floor order.
static func boss_ids() -> Array[int]:
	var bosses: Array[EnemyType] = []
	for id in EnemyCatalog.count():
		var et: EnemyType = EnemyCatalog.get_type(id)
		if et != null and et.archetype == GameEnums.EnemyArchetype.BOSS:
			bosses.append(et)
	bosses.sort_custom(func(a: EnemyType, b: EnemyType) -> bool: return a.base_hp < b.base_hp)
	var out: Array[int] = []
	for et in bosses:
		out.append(et.id)
	return out


## Display name of boss [param id] ("Vault Sentinel").
static func boss_name(id: int) -> String:
	var et: EnemyType = EnemyCatalog.get_type(id)
	return Spellbook.display_name(et.name) if et != null else "?"


## The menu records: best run and memories found, then each boss's best kill on a
## second line. Names keep their spaces unbroken so a wrap never splits one.
static func menu_line(p: MetaProgress, memories_total: int) -> String:
	var top: String = "%s      %s" % [_COPY.records_best_run_format % _time_or_none(p.best_win_sec),
		_COPY.records_memories_format % [mini(p.fragments_found, memories_total), memories_total]]
	var bosses: PackedStringArray = PackedStringArray()
	for id in boss_ids():
		var entry: String = _COPY.records_boss_format % [boss_name(id), _time_or_none(float(p.boss_best_sec.get(id, 0.0)))]
		bosses.append(entry.replace(" ", "\u00a0"))
	return top + "\n" + "     ".join(bosses)


## Summary line for a new best run time.
static func new_run_line(sec: float) -> String:
	return _COPY.record_new_run_format % RunSummaryPanel.format_time(sec)


## Summary line for a new best kill of boss [param id].
static func new_boss_line(id: int, sec: float) -> String:
	return _COPY.record_new_boss_format % [boss_name(id), RunSummaryPanel.format_time(sec)]


static func _time_or_none(sec: float) -> String:
	return RunSummaryPanel.format_time(sec) if sec > 0.0 else _COPY.records_none
