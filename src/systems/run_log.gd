## RunLog — a local, append-only log of finished runs for playtests (ADR-0048).
##
## One JSON object per line in user://run_log.jsonl: when the run ended, the game
## version, the outcome (win / death / abandoned), the floor reached, rooms cleared,
## run time, what killed Fayde, and the spells she cast (the grid of every fight, with
## its swaps, links, resonances and link bursts for tuning the duo, ADR-0058).
## Nothing leaves the machine; a playtester sends the file by hand. The file keeps the
## newest MAX_ENTRIES lines so it never grows without bound.
class_name RunLog
extends RefCounted

const DEFAULT_PATH: String = "user://run_log.jsonl"
## Newest lines kept; older ones are dropped on append.
const MAX_ENTRIES: int = 200

const OUTCOME_WIN: String = "win"
const OUTCOME_DEATH: String = "death"
const OUTCOME_ABANDONED: String = "abandoned"


## Builds one log entry. [param run] holds the run's facts (floor, rooms, run_sec,
## core, sigils, casts, assist, hard, resumes); [param death] is the last hit on
## Fayde (HealthAndDamage.last_player_hit, {} when she did not die) and
## [param death_line] its recap text; [param builds] is one {floor, room, core,
## grid, reactions} per fight. [param now_utc] is an ISO time, passed in by the
## caller so tests stay deterministic.
static func entry(outcome: String, run: Dictionary, death: Dictionary, death_line: String,
		builds: Array[Dictionary], now_utc: String, version: String) -> Dictionary:
	var spells: Array[String] = []
	for b: Dictionary in builds:
		var core_name: String = str(b.get("core", ""))
		if core_name != "" and not spells.has(core_name):
			spells.append(core_name)
	return {
		"time": now_utc,
		"version": version,
		"outcome": outcome,
		"floor": int(run.get("floor", 1)),
		"rooms_cleared": int(run.get("rooms", 0)),
		"run_sec": snappedf(float(run.get("run_sec", 0.0)), 0.1),
		"cause": {
			"attacker": str(death.get("attacker", "")),
			"attack": str(death.get("attack", "")),
			"text": death_line,
		} if outcome == OUTCOME_DEATH else {},
		"core": str(run.get("core", "")),
		"spells": spells,
		"builds": builds,
		"duo": duo_totals(builds),
		"casts": int(run.get("casts", 0)),
		"sigils": run.get("sigils", []),
		"assist": bool(run.get("assist", false)),
		"hard": bool(run.get("hard", false)),
		"resumes": int(run.get("resumes", 0)),
	}


## Appends [param e] as one JSON line to [param path], keeping the newest
## [param max_entries] lines. Returns OK or the FileAccess error.
static func append(e: Dictionary, path: String = DEFAULT_PATH,
		max_entries: int = MAX_ENTRIES) -> Error:
	var lines: PackedStringArray = _read_lines(path)
	lines.append(JSON.stringify(e))
	var start: int = maxi(lines.size() - maxi(max_entries, 1), 0)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	for i: int in range(start, lines.size()):
		f.store_line(lines[i])
	f.close()
	return OK


## Every entry in [param path], oldest first. Lines that aren't JSON objects are skipped.
static func read_all(path: String = DEFAULT_PATH) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var json := JSON.new()
	for line: String in _read_lines(path):
		if json.parse(line) == OK and json.data is Dictionary:
			out.append(json.data as Dictionary)
	return out


## One fight's build for the log: the core spell's name, the 9 slot type ids
## (-1 = empty) and the reaction ids armed.
static func build_entry(floor_num: int, room: int, slots: Array) -> Dictionary:
	var found: Dictionary = Spellbook.discoveries_from_grid(slots)
	var core_id: int = int(found["core"])
	var pt: PranaType = PranaCatalog.get_type(core_id) if core_id >= 0 else null
	var grid: Array[int] = []
	for v: Variant in slots:
		grid.append(int(v) if v != null else -1)
	var reactions: Array[String] = []
	for id: StringName in found["reactions"]:
		reactions.append(String(id))
	return {
		"floor": floor_num,
		"room": room,
		"core": pt.name if pt != null else "",
		"grid": grid,
		"reactions": reactions,
	}


## ADR-0058: the run's duo moves summed over [param builds] (each fight's "duo" tally).
static func duo_totals(builds: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = PaceDirector.empty_duo_counts()
	for b: Dictionary in builds:
		var d: Dictionary = b.get("duo", {})
		for k: String in out.keys():
			out[k] = int(out[k]) + int(d.get(k, 0))
	return out


static func _read_lines(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not FileAccess.file_exists(path):
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line: String = f.get_line().strip_edges()
		if line != "":
			out.append(line)
	f.close()
	return out
