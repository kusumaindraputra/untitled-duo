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


# ── Payout ────────────────────────────────────────────────────────────────────

## Shards earned by a run that reached [param floor_reached], cleared
## [param rooms] rooms and slew [param kills] enemies. See design/gdd/meta-progression.md.
static func shards_for_run(t: MetaTuning, floor_reached: int, rooms: int, kills: int,
		win: bool, hard: bool) -> int:
	var total: int = t.shards_per_floor * maxi(floor_reached, 1) \
		+ t.shards_per_room * maxi(rooms, 0) \
		+ (maxi(kills, 0) / maxi(t.kills_per_shard, 1)) \
		+ (t.win_bonus if win else 0)
	if hard:
		total = roundi(float(total) * t.hard_mode_shard_mult)
	return total


## Records a finished run, pays its shards and returns how many were paid.
## [param run_data] is RunManager.get_run_data().
func record_run(t: MetaTuning, run_data: Dictionary, win: bool) -> int:
	var floor_reached: int = int(run_data.get("current_floor", 1))
	var earned: int = shards_for_run(t, floor_reached, int(run_data.get("rooms_cleared", 0)),
		int(run_data.get("enemies_killed", 0)), win, hard_mode)
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


## True when [param id] is an Heirloom that is still locked and affordable.
func can_unlock(t: MetaTuning, id: StringName) -> bool:
	var cost: int = t.cost_of(id)
	return cost >= 0 and not is_unlocked(id) and shards >= cost


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
	return cfg.save(path)
