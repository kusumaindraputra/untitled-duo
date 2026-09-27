## AscensionConfig — the Ascension ladder above Hard Mode (ADR-0052).
##
## Authored as assets/data/ascension/ascension_config.tres. [member levels] index 0 is
## Ascension 1. Pure data plus stacking helpers, unit-tested headless.
## Design: design/gdd/meta-progression.md (Ascension section)
class_name AscensionConfig
extends Resource

## Ascension 1..N in order; each level adds its own changes to every level below it.
@export var levels: Array[AscensionLevel] = []


## Highest Ascension level that exists.
func max_level() -> int:
	return levels.size()


## The combined changes of levels 1..[param level] as one AscensionLevel (level 0 or
## less returns neutral values). Multipliers multiply, bonuses add.
func stacked(level: int) -> AscensionLevel:
	var out := AscensionLevel.new()
	for i: int in clampi(level, 0, levels.size()):
		var l: AscensionLevel = levels[i]
		if l == null:
			continue
		out.enemy_hp_mult *= l.enemy_hp_mult
		out.boss_hp_mult *= l.boss_hp_mult
		out.bullet_speed_mult *= l.bullet_speed_mult
		out.fire_rate_mult *= l.fire_rate_mult
		out.telegraph_mult *= l.telegraph_mult
		out.extra_enemies += l.extra_enemies
		out.elite_chance_bonus += l.elite_chance_bonus
		out.heal_mult *= l.heal_mult
		out.shard_bonus += l.shard_bonus
	return out


## Returns a copy of [param cfg] with Ascension [param level] applied. [param cfg] is
## not changed (the floor configs are shared, preloaded resources). Level 0 returns
## [param cfg] itself.
func apply(cfg: EnemyPoolConfig, level: int) -> EnemyPoolConfig:
	if cfg == null or level <= 0:
		return cfg
	var s: AscensionLevel = stacked(level)
	var out: EnemyPoolConfig = cfg.duplicate() as EnemyPoolConfig
	out.bullet_speed_mult = clampf(cfg.bullet_speed_mult * s.bullet_speed_mult, 0.5, 2.0)
	out.fire_rate_mult = clampf(cfg.fire_rate_mult * s.fire_rate_mult, 0.5, 2.0)
	out.telegraph_mult = clampf(cfg.telegraph_mult * s.telegraph_mult, 0.3, 1.5)
	out.threat_budget_min = cfg.threat_budget_min + s.extra_enemies
	out.threat_budget_max = cfg.threat_budget_max + s.extra_enemies
	if cfg.enemy_count_max > 0:
		out.enemy_count_max = cfg.enemy_count_max + s.extra_enemies
	out.elite_chance = clampf(cfg.elite_chance + s.elite_chance_bonus, 0.0, 1.0)
	out.enemy_hp_mult = cfg.enemy_hp_mult * s.enemy_hp_mult
	out.boss_hp_mult = cfg.boss_hp_mult * s.boss_hp_mult
	return out
