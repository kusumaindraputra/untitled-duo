## StoryRules — when Fayde recovers a memory and which ending plays (ADR-0027).
##
## Stateless rules over a StoryConfig; the count of recovered fragments lives in
## MetaProgress (user://progress.cfg). Fragments unlock in story order, one per
## beat, so the story always reads front to back. Every rule has a headless test.
##
## Design: design/gdd/memory-fragments.md
class_name StoryRules
extends RefCounted

## The shipped story.
const CONFIG: StoryConfig = preload("res://assets/data/story/story_config.tres")

## A moment in a run that can recover a fragment.
enum Beat {
	FLOOR_CLEAR, ## A floor boss fell and the run goes on.
	DEATH,       ## Fayde died.
	WIN,         ## The last floor's boss fell.
}


## Number of fragments in the story.
static func total(cfg: StoryConfig = CONFIG) -> int:
	return cfg.fragments.size()


## True when [param beat] recovers a fragment. [param rooms_cleared] is the run's
## count so far (only deaths look at it).
static func beat_recovers(beat: Beat, rooms_cleared: int, cfg: StoryConfig = CONFIG) -> bool:
	match beat:
		Beat.FLOOR_CLEAR:
			return cfg.unlock_on_floor_clear
		Beat.DEATH:
			return cfg.unlock_on_death and rooms_cleared >= cfg.death_unlock_min_rooms
		Beat.WIN:
			return cfg.unlock_on_win
	return false


## The fragment at story position [param index] (0-based), or null when out of range.
static func fragment_at(index: int, cfg: StoryConfig = CONFIG) -> MemoryFragment:
	if index < 0 or index >= cfg.fragments.size():
		return null
	return cfg.fragments[index]


## Story position of the fragment with [param id], or -1.
static func index_of(id: StringName, cfg: StoryConfig = CONFIG) -> int:
	for i: int in cfg.fragments.size():
		if cfg.fragments[i] != null and cfg.fragments[i].id == id:
			return i
	return -1


## True when a win on [param floor_reached] should play an ending.
static func plays_ending(floor_reached: int, cfg: StoryConfig = CONFIG) -> bool:
	return floor_reached >= cfg.ending_min_floor


## True when [param found] fragments are the whole story.
static func is_complete(found: int, cfg: StoryConfig = CONFIG) -> bool:
	return found >= total(cfg) and total(cfg) > 0


## The ending to play with [param found] fragments recovered.
static func ending_for(found: int, cfg: StoryConfig = CONFIG) -> MemoryFragment:
	return cfg.ending_true if is_complete(found, cfg) else cfg.ending_partial
