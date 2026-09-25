## PaceDirector — run-scoped owner of the fast-paced layer (ADR-0019).
##
## Listens to combat events and turns them into momentum:
##   - Perfect Dodge (PlayerController.perfect_dodged): short slow-mo, Special meter,
##     a free Perfect on the next cast, style.
##   - Kills: HP / meter orbs from the corpse, a short hitstop, style.
##   - Grazes, Perfect Casts: style. Taking damage: style penalty.
##   - Room clear: rank S–D from the room's average style, heal by rank, a Special head
##     start for the next room, and every orb on the floor flies to Fayde.
## Pure rules live in StyleMeter, TimeWarp and PickupOrb; this node only wires them.
## Created by debug_game_loop (like SigilManager) and wired to the player and HUD in
## its _ready(). Not an Autoload.
class_name PaceDirector
extends Node

## Style meter moved (every combat frame). [param rank_letter] is the live rank.
signal style_changed(value: float, max_value: float, rank_letter: String)
## Room cleared with a rank. [param heal] and [param meter_bonus] are the rewards.
signal room_ranked(rank_letter: String, heal: float, meter_bonus: float)
## A Perfect Dodge counted at [param world_pos].
signal perfect_dodge_triggered(world_pos: Vector2)

const TUNING: PaceTuning = preload("res://assets/data/pace_tuning.tres")
## Real seconds a Perfect Dodge slow-mo waits for a running hitstop to end.
const SLOWMO_RETRY_SEC: float = 0.15
## Outward pop speed (px/s) of freshly dropped orbs.
const ORB_POP_SPEED: float = 90.0

var style: StyleMeter = StyleMeter.new(TUNING)

var _player: Node2D = null
var _in_combat: bool = false
var _room_kills: int = 0
## Special meter the next room starts with (last room's rank reward).
var _pending_meter_bonus: float = 0.0
## Real-time deadline (usec) for a Perfect Dodge slow-mo waiting on a hitstop; 0 = none.
var _slowmo_retry_until_us: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	_rng.randomize()
	HealthAndDamage.enemy_killed.connect(_on_enemy_killed)
	HealthAndDamage.damage_taken.connect(_on_damage_taken)
	SpellCastingEffects.grazed.connect(_on_grazed)
	SpellCastingEffects.perfect_cast.connect(_on_perfect_cast)
	GameStateManager.run_started.connect(_on_run_started)
	GameStateManager.preparation_started.connect(_on_preparation_started)
	GameStateManager.combat_started.connect(_on_combat_started)
	GameStateManager.room_cleared.connect(_on_room_cleared)


func _exit_tree() -> void:
	if HealthAndDamage.enemy_killed.is_connected(_on_enemy_killed):
		HealthAndDamage.enemy_killed.disconnect(_on_enemy_killed)
	if HealthAndDamage.damage_taken.is_connected(_on_damage_taken):
		HealthAndDamage.damage_taken.disconnect(_on_damage_taken)
	if SpellCastingEffects.grazed.is_connected(_on_grazed):
		SpellCastingEffects.grazed.disconnect(_on_grazed)
	if SpellCastingEffects.perfect_cast.is_connected(_on_perfect_cast):
		SpellCastingEffects.perfect_cast.disconnect(_on_perfect_cast)
	if GameStateManager.run_started.is_connected(_on_run_started):
		GameStateManager.run_started.disconnect(_on_run_started)
	if GameStateManager.preparation_started.is_connected(_on_preparation_started):
		GameStateManager.preparation_started.disconnect(_on_preparation_started)
	if GameStateManager.combat_started.is_connected(_on_combat_started):
		GameStateManager.combat_started.disconnect(_on_combat_started)
	if GameStateManager.room_cleared.is_connected(_on_room_cleared):
		GameStateManager.room_cleared.disconnect(_on_room_cleared)


func _process(delta: float) -> void:
	if _slowmo_retry_until_us > 0:
		if TimeWarp.try_apply(get_tree(), TUNING.perfect_dodge_time_scale, TUNING.perfect_dodge_slowmo_sec) \
				or Time.get_ticks_usec() >= _slowmo_retry_until_us:
			_slowmo_retry_until_us = 0
	if not _in_combat:
		return
	style.tick(delta)
	_emit_style()


## Wires the player (called from the parent's _ready). Connects Perfect Dodge.
func set_player(player: Node2D) -> void:
	if is_instance_valid(_player) and _player.has_signal(&"perfect_dodged") \
			and _player.is_connected(&"perfect_dodged", _on_perfect_dodged):
		_player.disconnect(&"perfect_dodged", _on_perfect_dodged)
	_player = player
	if is_instance_valid(player) and player.has_signal(&"perfect_dodged"):
		player.connect(&"perfect_dodged", _on_perfect_dodged)


## Test seam: seeds the orb-drop RNG.
func set_rng_seed(seed_value: int) -> void:
	_rng.seed = seed_value


## Special meter the next room will start with.
func get_pending_meter_bonus() -> float:
	return _pending_meter_bonus


## Orbs a kill drops: { "hp": int, "meter": int }. [param major] is an elite or boss.
## [param roll] is a 0..1 roll for the HP orb chance.
static func orb_drops(major: bool, roll: float, t: PaceTuning = TUNING) -> Dictionary:
	var hp: int = 1 if (major and t.elite_always_drops_hp) or roll < t.hp_orb_chance else 0
	var meter: int = maxi(t.meter_orbs_per_kill, 0) * (2 if major else 1)
	return { "hp": hp, "meter": meter }


# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_perfect_dodged(world_pos: Vector2) -> void:
	SpellCastingEffects.add_special_meter(TUNING.perfect_dodge_meter_gain)
	if TUNING.perfect_dodge_cast_window_sec > 0.0:
		SpellCastingEffects.grant_perfect_cast(TUNING.perfect_dodge_cast_window_sec)
	style.add(TUNING.style_perfect_dodge)
	if is_inside_tree() and not TimeWarp.try_apply(
			get_tree(), TUNING.perfect_dodge_time_scale, TUNING.perfect_dodge_slowmo_sec):
		_slowmo_retry_until_us = Time.get_ticks_usec() + int(SLOWMO_RETRY_SEC * 1_000_000.0)
	perfect_dodge_triggered.emit(world_pos)


func _on_enemy_killed(instance_id: int, _type_id: int, _affiliation: GameEnums.DamageClass) -> void:
	if not _in_combat:
		return
	_room_kills += 1
	var enemy: Node2D = instance_from_id(instance_id) as Node2D
	var major: bool = false
	if is_instance_valid(enemy):
		major = (enemy.has_method(&"is_elite") and enemy.is_elite()) \
			or (enemy.has_method(&"is_boss") and enemy.is_boss())
	style.add(TUNING.style_elite_kill if major else TUNING.style_kill)
	SpellVFX.request_hitstop(TUNING.elite_kill_hitstop_sec if major else TUNING.kill_hitstop_sec)
	if is_instance_valid(enemy):
		_drop_orbs(enemy, major)


func _on_damage_taken(target: Node, final_damage: int, _current_hp: int) -> void:
	if _in_combat and final_damage > 0 and target != null and target.is_in_group(&"player"):
		style.on_hit()


func _on_grazed(_world_pos: Vector2, _gain: float) -> void:
	if _in_combat:
		style.add(TUNING.style_graze)


func _on_perfect_cast(_world_pos: Vector2, _streak: int) -> void:
	if _in_combat:
		style.add(TUNING.style_perfect_cast)


func _on_run_started() -> void:
	style.reset()
	_pending_meter_bonus = 0.0
	_in_combat = false
	_emit_style()


func _on_preparation_started(_wave_index: int, _waves_remaining: int) -> void:
	_in_combat = false
	if is_inside_tree():
		PickupOrb.clear_all(get_tree())


func _on_combat_started(_is_boss: bool) -> void:
	_in_combat = true
	_room_kills = 0
	style.begin_room()
	if _pending_meter_bonus > 0.0:
		SpellCastingEffects.add_special_meter(_pending_meter_bonus)
	_pending_meter_bonus = 0.0


## Deferred to the end of the frame: room_cleared fires from inside the last kill's
## enemy_killed dispatch, so this waits until that kill has dropped its orbs and
## counted toward the room.
func _on_room_cleared() -> void:
	if _in_combat:
		call_deferred(&"finish_room")


## Ranks the room, pays the rank reward and pulls every orb to Fayde. Public for tests.
func finish_room() -> void:
	if not _in_combat:
		return
	_in_combat = false
	var rank: StyleMeter.Rank = style.end_room()
	if TUNING.collect_all_on_clear:
		# Deferred again so orbs the last kill queued (deferred add_child) exist first.
		call_deferred(&"_magnetize_orbs")
	if _room_kills <= 0:
		return  # rest rooms and empty rooms are not ranked
	var heal: float = StyleMeter.pick(TUNING.rank_heal, rank)
	_pending_meter_bonus = StyleMeter.pick(TUNING.rank_meter_bonus, rank)
	if heal > 0.0 and is_instance_valid(_player):
		HealthAndDamage.apply_heal(_player, heal)
	room_ranked.emit(StyleMeter.letter(rank), heal, _pending_meter_bonus)


# ── Private ───────────────────────────────────────────────────────────────────

func _magnetize_orbs() -> void:
	if is_inside_tree():
		PickupOrb.magnetize_all(get_tree(), TUNING.orb_clear_speed_mult)


func _drop_orbs(enemy: Node2D, major: bool) -> void:
	var parent_node: Node = enemy.get_parent()
	if parent_node == null:
		return
	var drops: Dictionary = orb_drops(major, _rng.randf())
	for i: int in int(drops["hp"]):
		_spawn_orb(parent_node, enemy.global_position, PickupOrb.Kind.HP, TUNING.hp_orb_heal)
	for i: int in int(drops["meter"]):
		_spawn_orb(parent_node, enemy.global_position, PickupOrb.Kind.METER, TUNING.meter_orb_gain)


func _spawn_orb(parent_node: Node, pos: Vector2, kind: PickupOrb.Kind, amount: float) -> void:
	var orb := PickupOrb.new()
	orb.kind = kind
	orb.amount = amount
	orb.pop_velocity = Vector2.from_angle(_rng.randf() * TAU) * ORB_POP_SPEED
	if is_instance_valid(_player):
		orb.set_player(_player)
	# Deferred: enemy_killed fires inside the physics step of the killing hit.
	parent_node.call_deferred(&"add_child", orb)
	orb.set_deferred(&"global_position", pos)


func _emit_style() -> void:
	style_changed.emit(style.get_value(), TUNING.style_max, StyleMeter.letter(style.get_live_rank()))
