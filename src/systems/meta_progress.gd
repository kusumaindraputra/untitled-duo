## MetaProgress — the player's progress between runs (ADR-0025).
##
## Holds Cipher Shards (earned at the end of every run), lifetime stats, which
## Heirlooms are unlocked, which one is equipped, and whether Hard Mode is on.
## Persisted as a ConfigFile at user://progress.cfg, separate from settings.cfg so
## wiping progress never touches the player's volume settings.
##
## Plain RefCounted with no scene-tree or Autoload access: the main menu and the run
## scene each load it from disk, change it and save it back, and tests pass their
## own path. Every rule here is covered by headless unit tests.
class_name MetaProgress
extends RefCounted

const DEFAULT_PATH: String = "user://progress.cfg"
## Heirloom titles and descriptions are the stat-sigil catalog entries.
const _SIGILS: SigilConfig = preload("res://assets/data/sigil_config.tres")
const _SECTION: String = "progress"
## Bumped when the saved layout changes; older files are read field by field.
const SAVE_VERSION: int = 1

## Spendable shards.
var shards: int = 0
## Every shard ever earned (never goes down). Shown on the menu.
var lifetime_shards: int = 0
var runs: int = 0
var wins: int = 0
var best_floor: int = 0
var unlocked: Array[StringName] = []
## Heirloom granted at the next run start; &"" = none.
var equipped: StringName = &""
var hard_mode: bool = false
## Ascension (ADR-0052): the level picked for the next run (0 = plain Hard Mode) and the
## highest level unlocked so far. Only in effect while Hard Mode is.
var ascension: int = 0
var ascension_unlocked: int = 0
## True once the in-combat tutorial coach has been completed.
var tutorial_done: bool = false
## True once the guided first room (ADR-0055) was finished or skipped. Saves from before
## it existed count as done when the player already finished the coach or a run.
var tutorial_room_done: bool = false
## Cipher Core picked for the last run (ADR-0033); the pick screen starts on it.
var last_core: StringName = &""
## Memory fragments recovered so far, in story order (ADR-0027).
var fragments_found: int = 0
## True once the ending with fragments missing has played.
var ending_seen: bool = false
## True once the ending with every fragment has played.
var true_ending_seen: bool = false
## Spellbook discoveries (F1): core Prana types cast, reaction ids armed, sigil ids
## taken, enemy type ids defeated. See Spellbook.
var codex_spells: Array[int] = []
var codex_reactions: Array[StringName] = []
var codex_sigils: Array[StringName] = []
var codex_enemies: Array[int] = []
## Records (F3): fastest winning run and fastest kill per boss type id, in seconds.
## 0 / missing = no record yet. Runs with Assist on do not set records.
var best_win_sec: float = 0.0
var boss_best_sec: Dictionary[int, float] = {}


# ── Payout ────────────────────────────────────────────────────────────────────

## Shards earned by a run that reached [param floor_reached], cleared
## [param rooms] rooms and slew [param kills] enemies. See design/gdd/meta-progression.md.
static func shards_for_run(t: MetaTuning, floor_reached: int, rooms: int, kills: int,
		win: bool, hard: bool, ascension_bonus: float = 0.0) -> int:
	var total: int = t.shards_per_floor * maxi(floor_reached, 1) \
		+ t.shards_per_room * maxi(rooms, 0) \
		+ (maxi(kills, 0) / maxi(t.kills_per_shard, 1)) \
		+ (t.win_bonus if win else 0)
	if hard:
		total = roundi(float(total) * (t.hard_mode_shard_mult + maxf(ascension_bonus, 0.0)))
	return total


## Records a finished run, pays its shards and returns how many were paid.
## [param run_data] is RunManager.get_run_data(), optionally carrying "bonus_shards"
## (flawless Challenge rooms, ADR-0026), which is added after the Hard Mode multiplier.
## A win on Hard Mode at the highest unlocked Ascension opens the next level (ADR-0052).
func record_run(t: MetaTuning, run_data: Dictionary, win: bool) -> int:
	var floor_reached: int = int(run_data.get("current_floor", 1))
	var hard: bool = hard_mode_active(t)
	var level: int = active_ascension(t)
	var bonus: float = t.ascension.stacked(level).shard_bonus if t.ascension != null else 0.0
	var earned: int = shards_for_run(t, floor_reached, int(run_data.get("rooms_cleared", 0)),
		int(run_data.get("enemies_killed", 0)), win, hard, bonus) \
		+ maxi(int(run_data.get("bonus_shards", 0)), 0)
	if win and hard and level >= ascension_unlocked and ascension_unlocked < max_ascension(t):
		ascension_unlocked += 1
	shards += earned
	lifetime_shards += earned
	runs += 1
	if win:
		wins += 1
	best_floor = maxi(best_floor, floor_reached)
	return earned


# ── Heirlooms and Hard Mode ───────────────────────────────────────────────────

## The stat-sigil catalog entry ({id, title, desc}) for [param id], or {} if unknown.
static func heirloom_info(id: StringName) -> Dictionary:
	for entry: Dictionary in _SIGILS.sigils:
		if StringName(entry.get("id", &"")) == id:
			return entry
	return {}


func is_unlocked(id: StringName) -> bool:
	return unlocked.has(id)


## True once enough memories are recovered to buy [param id] (F4).
func is_revealed(t: MetaTuning, id: StringName) -> bool:
	return fragments_found >= t.memories_needed(id)


## True when [param id] is an Heirloom that is still locked, revealed and affordable.
func can_unlock(t: MetaTuning, id: StringName) -> bool:
	var cost: int = t.cost_of(id)
	return cost >= 0 and not is_unlocked(id) and is_revealed(t, id) and shards >= cost


## Spends shards to unlock [param id] and equips it. Returns false when not allowed.
func unlock(t: MetaTuning, id: StringName) -> bool:
	if not can_unlock(t, id):
		return false
	shards -= t.cost_of(id)
	unlocked.append(id)
	equipped = id
	return true


## Equips an unlocked Heirloom, or clears the slot when it is already equipped.
## Returns false for a locked id.
func toggle_equip(id: StringName) -> bool:
	if not is_unlocked(id):
		return false
	equipped = &"" if equipped == id else id
	return true


## The Heirloom to grant at run start, or &"" (also when the equipped id was locked).
func run_heirloom() -> StringName:
	return equipped if is_unlocked(equipped) else &""


func is_hard_mode_unlocked(t: MetaTuning) -> bool:
	return wins >= t.hard_mode_wins_required


## Hard Mode actually in effect: switched on and unlocked.
func hard_mode_active(t: MetaTuning) -> bool:
	return hard_mode and is_hard_mode_unlocked(t)


## Returns a copy of [param cfg] with Hard Mode applied. [param cfg] is not changed
## (the floor configs are shared, preloaded resources).
static func apply_hard_mode(cfg: EnemyPoolConfig, t: MetaTuning) -> EnemyPoolConfig:
	if cfg == null:
		return null
	var hard: EnemyPoolConfig = cfg.duplicate() as EnemyPoolConfig
	hard.bullet_speed_mult = cfg.bullet_speed_mult * t.hard_bullet_speed_mult
	hard.fire_rate_mult = cfg.fire_rate_mult * t.hard_fire_rate_mult
	hard.telegraph_mult = cfg.telegraph_mult * t.hard_telegraph_mult
	hard.threat_budget_min = cfg.threat_budget_min + t.hard_extra_enemies
	hard.threat_budget_max = cfg.threat_budget_max + t.hard_extra_enemies
	if cfg.enemy_count_max > 0:
		hard.enemy_count_max = cfg.enemy_count_max + t.hard_extra_enemies
	hard.elite_chance = clampf(cfg.elite_chance + t.hard_elite_chance_bonus, 0.0, 1.0)
	return hard


# ── Ascension (ADR-0052) ──────────────────────────────────────────────────────

## Highest Ascension level the tuning defines (0 when it has none).
static func max_ascension(t: MetaTuning) -> int:
	return t.ascension.max_level() if t != null and t.ascension != null else 0


## The Ascension level in effect for the next run: the picked level, capped by what is
## unlocked, and 0 unless Hard Mode is active.
func active_ascension(t: MetaTuning) -> int:
	if not hard_mode_active(t):
		return 0
	return clampi(ascension, 0, mini(ascension_unlocked, max_ascension(t)))


## Steps the picked level by [param step], wrapping between 0 and the highest unlocked
## level. Returns the new level.
func cycle_ascension(t: MetaTuning, step: int = 1) -> int:
	var top: int = mini(ascension_unlocked, max_ascension(t))
	if top <= 0:
		ascension = 0
		return 0
	ascension = posmod(clampi(ascension, 0, top) + step, top + 1)
	return ascension


## Returns a copy of [param cfg] with the active Ascension applied, or [param cfg]
## itself at level 0.
func apply_ascension(cfg: EnemyPoolConfig, t: MetaTuning) -> EnemyPoolConfig:
	var level: int = active_ascension(t)
	if level <= 0 or t.ascension == null:
		return cfg
	return t.ascension.apply(cfg, level)


# ── Story (ADR-0027) ──────────────────────────────────────────────────────────

## Recovers the next fragment of a [param total]-fragment story. Returns its
## 0-based story position, or -1 when every fragment is already found.
func recover_fragment(total: int) -> int:
	if fragments_found >= total:
		return -1
	fragments_found += 1
	return fragments_found - 1


## Marks an ending as seen; [param is_true] picks which one.
func record_ending(is_true: bool) -> void:
	if is_true:
		true_ending_seen = true
	else:
		ending_seen = true


# ── Spellbook (F1) ────────────────────────────────────────────────────────────

## Marks core Prana [param type_id] as cast. Returns true when it is new.
func discover_spell(type_id: int) -> bool:
	return _add_int(codex_spells, type_id)


## Marks reaction [param id] as armed. Returns true when it is new.
func discover_reaction(id: StringName) -> bool:
	return _add_name(codex_reactions, id)


## Marks sigil [param id] as taken. Returns true when it is new.
func discover_sigil(id: StringName) -> bool:
	return _add_name(codex_sigils, id)


## Marks enemy type [param type_id] as defeated. Returns true when it is new.
func discover_enemy(type_id: int) -> bool:
	return _add_int(codex_enemies, type_id)


static func _add_int(list: Array[int], v: int) -> bool:
	if v < 0 or list.has(v):
		return false
	list.append(v)
	return true


static func _add_name(list: Array[StringName], v: StringName) -> bool:
	if v == &"" or list.has(v):
		return false
	list.append(v)
	return true


# ── Records (F3) ──────────────────────────────────────────────────────────────

## Records a winning run of [param sec] seconds. Returns true when it is a new best.
func record_win_time(sec: float) -> bool:
	if sec <= 0.0 or (best_win_sec > 0.0 and sec >= best_win_sec):
		return false
	best_win_sec = sec
	return true


## Records a kill of boss [param boss_id] after [param sec] seconds. Returns true
## when it is a new best for that boss.
func record_boss_time(boss_id: int, sec: float) -> bool:
	if boss_id < 0 or sec <= 0.0:
		return false
	if boss_best_sec.has(boss_id) and sec >= boss_best_sec[boss_id]:
		return false
	boss_best_sec[boss_id] = sec
	return true


# ── Persistence ───────────────────────────────────────────────────────────────

## Loads progress from [param path]. A missing or unreadable file gives fresh progress.
static func load_from(path: String = DEFAULT_PATH) -> MetaProgress:
	var p := MetaProgress.new()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return p
	p.shards = maxi(int(cfg.get_value(_SECTION, "shards", 0)), 0)
	p.lifetime_shards = maxi(int(cfg.get_value(_SECTION, "lifetime_shards", p.shards)), p.shards)
	p.runs = maxi(int(cfg.get_value(_SECTION, "runs", 0)), 0)
	p.wins = maxi(int(cfg.get_value(_SECTION, "wins", 0)), 0)
	p.best_floor = maxi(int(cfg.get_value(_SECTION, "best_floor", 0)), 0)
	for id: Variant in cfg.get_value(_SECTION, "unlocked", []):
		var sid := StringName(str(id))
		if not p.unlocked.has(sid):
			p.unlocked.append(sid)
	p.equipped = StringName(str(cfg.get_value(_SECTION, "equipped", "")))
	p.hard_mode = bool(cfg.get_value(_SECTION, "hard_mode", false))
	p.ascension_unlocked = maxi(int(cfg.get_value(_SECTION, "ascension_unlocked", 0)), 0)
	p.ascension = clampi(int(cfg.get_value(_SECTION, "ascension", 0)), 0, p.ascension_unlocked)
	p.tutorial_done = bool(cfg.get_value(_SECTION, "tutorial_done", false))
	p.tutorial_room_done = bool(cfg.get_value(_SECTION, "tutorial_room_done",
		p.tutorial_done or p.runs > 0))
	p.last_core = StringName(str(cfg.get_value(_SECTION, "last_core", "")))
	p.fragments_found = maxi(int(cfg.get_value(_SECTION, "fragments_found", 0)), 0)
	p.ending_seen = bool(cfg.get_value(_SECTION, "ending_seen", false))
	p.true_ending_seen = bool(cfg.get_value(_SECTION, "true_ending_seen", false))
	for v: Variant in cfg.get_value(_SECTION, "codex_spells", []):
		p.discover_spell(int(v))
	for v: Variant in cfg.get_value(_SECTION, "codex_reactions", []):
		p.discover_reaction(StringName(str(v)))
	for v: Variant in cfg.get_value(_SECTION, "codex_sigils", []):
		p.discover_sigil(StringName(str(v)))
	for v: Variant in cfg.get_value(_SECTION, "codex_enemies", []):
		p.discover_enemy(int(v))
	p.best_win_sec = maxf(float(cfg.get_value(_SECTION, "best_win_sec", 0.0)), 0.0)
	var bosses: Variant = cfg.get_value(_SECTION, "boss_best_sec", {})
	if bosses is Dictionary:
		for k: Variant in bosses:
			p.record_boss_time(int(k), float(bosses[k]))
	return p


## Writes progress to [param path]. Returns the ConfigFile error code.
func save_to(path: String = DEFAULT_PATH) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value(_SECTION, "version", SAVE_VERSION)
	cfg.set_value(_SECTION, "shards", shards)
	cfg.set_value(_SECTION, "lifetime_shards", lifetime_shards)
	cfg.set_value(_SECTION, "runs", runs)
	cfg.set_value(_SECTION, "wins", wins)
	cfg.set_value(_SECTION, "best_floor", best_floor)
	var ids: Array[String] = []
	for id: StringName in unlocked:
		ids.append(String(id))
	cfg.set_value(_SECTION, "unlocked", ids)
	cfg.set_value(_SECTION, "equipped", String(equipped))
	cfg.set_value(_SECTION, "hard_mode", hard_mode)
	cfg.set_value(_SECTION, "ascension", ascension)
	cfg.set_value(_SECTION, "ascension_unlocked", ascension_unlocked)
	cfg.set_value(_SECTION, "tutorial_done", tutorial_done)
	cfg.set_value(_SECTION, "tutorial_room_done", tutorial_room_done)
	cfg.set_value(_SECTION, "last_core", String(last_core))
	cfg.set_value(_SECTION, "fragments_found", fragments_found)
	cfg.set_value(_SECTION, "ending_seen", ending_seen)
	cfg.set_value(_SECTION, "true_ending_seen", true_ending_seen)
	cfg.set_value(_SECTION, "codex_spells", codex_spells.duplicate())
	cfg.set_value(_SECTION, "codex_reactions", codex_reactions.map(func(x: StringName) -> String: return String(x)))
	cfg.set_value(_SECTION, "codex_sigils", codex_sigils.map(func(x: StringName) -> String: return String(x)))
	cfg.set_value(_SECTION, "codex_enemies", codex_enemies.duplicate())
	cfg.set_value(_SECTION, "best_win_sec", best_win_sec)
	var bosses: Dictionary = {}
	for k: int in boss_best_sec:
		bosses[str(k)] = boss_best_sec[k]
	cfg.set_value(_SECTION, "boss_best_sec", bosses)
	return cfg.save(path)
