## RunSave — the run in progress, written at the start of every room (ADR-0048).
##
## The game loop writes one snapshot each time Fayde enters a room (and right after the
## core pick), so a run closed mid-room — window closed, tab closed, Quit — continues
## from the start of that room: same floor graph, build, bag, sigils, HP and run stats.
## The file is removed when the run ends (win or death) or is abandoned with Restart.
##
## Plain static helpers over a ConfigFile at user://run_save.cfg, separate from
## progress.cfg and settings.cfg. The snapshot is a plain Dictionary that the game loop
## builds and reads back; this class only stores it, checks it and hands it over.
class_name RunSave
extends RefCounted

const DEFAULT_PATH: String = "user://run_save.cfg"
const _SECTION: String = "run"
## Bumped when the snapshot layout changes. A save with another version is dropped:
## a lost run is better than a broken one.
const SAVE_VERSION: int = 1
## Keys every snapshot must carry to be resumable.
const REQUIRED_KEYS: Array[String] = [
	"floor", "total_floors", "graph", "room_idx", "rooms_entered", "loadout", "hp",
]

## Set by the main menu's Continue button, read once by the run scene's _ready().
static var resume_requested: bool = false


## Writes [param snapshot] to [param path]. Returns the ConfigFile error.
static func write(snapshot: Dictionary, path: String = DEFAULT_PATH) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value(_SECTION, "version", SAVE_VERSION)
	cfg.set_value(_SECTION, "data", snapshot)
	return cfg.save(path)


## The snapshot at [param path], or {} when there is none or it can't be resumed.
static func read(path: String = DEFAULT_PATH) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return {}
	if int(cfg.get_value(_SECTION, "version", 0)) != SAVE_VERSION:
		return {}
	var data: Variant = cfg.get_value(_SECTION, "data", {})
	if not data is Dictionary or not is_valid(data as Dictionary):
		return {}
	return data as Dictionary


## True when [param path] holds a snapshot that can be resumed.
static func exists(path: String = DEFAULT_PATH) -> bool:
	return not read(path).is_empty()


## Deletes the save at [param path]. Safe when there is none.
static func clear(path: String = DEFAULT_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Returns and resets [member resume_requested], so a Restart after a resume
## starts a fresh run.
static func take_resume_request() -> bool:
	var wanted: bool = resume_requested
	resume_requested = false
	return wanted


## Checks the shape of [param data]: required keys, a floor inside the run, a
## non-empty graph with the current room in range, a 9-slot loadout and HP above 0.
static func is_valid(data: Dictionary) -> bool:
	for key: String in REQUIRED_KEYS:
		if not data.has(key):
			return false
	var floor_num: int = int(data["floor"])
	if floor_num < 1 or floor_num > int(data["total_floors"]):
		return false
	var graph: Variant = data["graph"]
	if not graph is Dictionary:
		return false
	var rooms: Variant = (graph as Dictionary).get("rooms", [])
	if not rooms is Array or (rooms as Array).is_empty():
		return false
	var room_idx: int = int(data["room_idx"])
	if room_idx < 0 or room_idx >= (rooms as Array).size():
		return false
	var loadout: Variant = data["loadout"]
	if not loadout is Array or (loadout as Array).size() != PranaLoadout.SLOT_COUNT:
		return false
	return int(data["hp"]) > 0


## Menu line values for a snapshot: Vector2i(floor, room entered on that floor).
static func progress_of(data: Dictionary) -> Vector2i:
	return Vector2i(int(data.get("floor", 1)), int(data.get("rooms_entered", 1)))
