## RoomClearMoment — the payoff when the last enemy of a room falls (ADR-0041).
##
## On room_cleared in a room that had kills: a short slow-mo right after the last
## kill (through DeferredWarp, so the kill hitstop reads first), and a big CLEAR
## banner on the HUD layer. The other two parts of the moment live with their owners:
## PaceDirector pulls every orb to Fayde (PickupOrb draws the pull streak), and
## RoomExitDoor bursts when it unlocks. Boss rooms skip this: BossDeathCinematic
## is their moment.
## Created by debug_game_loop, which wires [member wave_manager] and
## [member banner_layer] in its _ready().
class_name RoomClearMoment
extends Node

## Fired when the moment plays (the banner is up and the slow-mo is queued).
signal played

const TUNING: BigMomentTuning = preload("res://assets/data/big_moment_tuning.tres")

## Read for the current room type. Null = treated as a combat room.
var wave_manager: WaveManager = null
## CanvasLayer the CLEAR banner goes on. Null = no banner (headless tests).
var banner_layer: CanvasLayer = null

var _in_combat: bool = false
var _kills: int = 0
var _warp: DeferredWarp = DeferredWarp.new()


func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	GameStateManager.combat_started.connect(_on_combat_started)
	GameStateManager.room_cleared.connect(_on_room_cleared)
	HealthAndDamage.enemy_killed.connect(_on_enemy_killed)


func _exit_tree() -> void:
	if GameStateManager.combat_started.is_connected(_on_combat_started):
		GameStateManager.combat_started.disconnect(_on_combat_started)
	if GameStateManager.room_cleared.is_connected(_on_room_cleared):
		GameStateManager.room_cleared.disconnect(_on_room_cleared)
	if HealthAndDamage.enemy_killed.is_connected(_on_enemy_killed):
		HealthAndDamage.enemy_killed.disconnect(_on_enemy_killed)


func _process(delta: float) -> void:
	if _warp.is_pending():
		_warp.tick(get_tree(), minf(DeferredWarp.real_delta(delta), 0.1))


## True when a clear with [param kills] kills in a room of [param room_type] gets
## the moment: something was fought, and it was not the boss room.
static func should_play(kills: int, room_type: int) -> bool:
	return kills > 0 and room_type != DungeonGraph.ROOM_TYPE_BOSS


## Real seconds the between-room reward waits after a clear: long enough for the
## CLEAR banner to punch in and hold, never less than the old 0.5 s.
static func reward_delay_sec(t: BigMomentTuning = TUNING) -> float:
	return maxf(0.5, t.clear_in_sec + t.clear_hold_sec)


## Kills counted in the current room (for tests).
func get_room_kills() -> int:
	return _kills


## True while the room clear slow-mo is waiting for a hitstop to end.
func is_slowmo_pending() -> bool:
	return _warp.is_pending()


## Plays the moment: queues the slow-mo and shows the banner. Public for tests.
func play() -> void:
	_warp.request(TUNING.clear_slowmo_scale, TUNING.clear_slowmo_sec, TUNING.slowmo_wait_sec)
	if is_inside_tree():
		_warp.tick(get_tree(), 0.0)
	if is_instance_valid(banner_layer):
		var banner := ClearBanner.new()
		banner.name = "ClearBanner"
		banner.setup()
		banner_layer.add_child(banner)
		banner.play()
	played.emit()


# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_combat_started(_is_boss: bool) -> void:
	_in_combat = true
	_kills = 0


func _on_enemy_killed(_instance_id: int, _type_id: int, _affiliation: GameEnums.DamageClass) -> void:
	if _in_combat:
		_kills += 1


## Deferred to the end of the frame: room_cleared fires from inside the last kill's
## enemy_killed dispatch, before this node's own enemy_killed handler counts it.
func _on_room_cleared() -> void:
	if _in_combat:
		call_deferred(&"finish_room")


## Ends the room and plays the moment when it earned one. Public for tests.
func finish_room() -> void:
	if not _in_combat:
		return
	_in_combat = false
	var room_type: int = wave_manager.room_type if is_instance_valid(wave_manager) \
		else DungeonGraph.ROOM_TYPE_COMBAT
	if should_play(_kills, room_type):
		play()
