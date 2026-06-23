## BoonManager — between-room reward system for the demo run.
##
## After clearing a combat/elite room, offer_boons() presents a choice of three
## random reward cards drawn from a mixed pool: persistent stat boons AND Prana
## cards. A boon applies a run modifier through its owning system (PlayerController
## speed/dash, SpellCastingEffects damage, HealthAndDamage heal); a Prana card drops
## one fragment into the PranaBag for placement in the next preparation phase
## (grid-as-build model). No central stat store — each system stays authoritative.
##
## Logic (catalog / roll_choices / apply_boon) is separated from presentation
## (offer_boons builds the overlay) so the selection math is unit-testable headlessly.
##
## Created programmatically by debug_game_loop so both main.tscn and demo.tscn get
## it without scene edits. Not an Autoload — it is run-scoped, freed with the scene.
class_name BoonManager
extends Node

## Emitted after a reward is applied, carrying its id (boon id or "prana_<n>").
## For HUD/audio feedback.
signal boon_applied(boon_id: StringName)

# ── Config ────────────────────────────────────────────────────────────────────
## Data-driven boon tuning + copy: multipliers, catalog, heading, and Prana-card
## templates. Preloaded as a const so it resolves without _ready() — BoonManager is
## unit-tested via .new() with no SceneTree (see boon_manager_test.gd). Element
## names and colours come from PranaCatalog (the canonical Prana type data), so no
## Prana names are duplicated here.
const CONFIG: BoonConfig = preload("res://assets/data/boon_config.tres")

## Id prefix marking a Prana reward card. apply_boon() detects this prefix and
## routes the card to the PranaBag instead of the boon dispatch table.
const _PRANA_ID_PREFIX: String = "prana_"

## Resolves the player node. Overridable in tests via set_player_provider().
var _player_provider: Callable = func() -> Node:
	return get_tree().get_first_node_in_group(&"player")

## Resolves the PranaBag node. Overridable in tests via set_bag_provider().
var _bag_provider: Callable = func() -> Node:
	return get_tree().get_first_node_in_group(&"prana_bag")

## The live choice overlay while a selection is pending; null otherwise.
var _overlay: CanvasLayer = null

# ── Public API ────────────────────────────────────────────────────────────────

## Returns a copy of the full reward pool (stat boons + one Prana card per type).
func get_catalog() -> Array[Dictionary]:
	return _build_reward_pool()


## Builds the combined reward pool: all stat boons followed by one Prana card per
## Prana type. Rebuilt each call (cheap) so callers always get fresh copies.
func _build_reward_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = CONFIG.boons.duplicate(true)
	pool.append_array(_build_prana_cards())
	return pool


## Builds one Prana reward card per Prana type. Names come from PranaCatalog (the
## canonical type data) and the title/desc templates from CONFIG. Each card carries
## a "prana_type" key so the overlay can tint it and apply_boon() can route it to
## the bag.
func _build_prana_cards() -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	for type_id: int in PranaCatalog.type_count():
		var type_data: PranaType = PranaCatalog.get_type(type_id)
		var full_name: String = type_data.name if type_data != null else "Prana"
		cards.append({
			"id": StringName(_PRANA_ID_PREFIX + str(type_id)),
			"title": CONFIG.prana_card_title % full_name,
			"desc": CONFIG.prana_card_desc % full_name,
			"prana_type": type_id,
		})
	return cards


## Returns [param count] distinct random rewards from the pool. If count exceeds
## the pool size, returns the whole pool (shuffled). Uses [param rng] when
## provided (deterministic tests); otherwise a fresh randomized RNG.
func roll_choices(count: int, rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var r: RandomNumberGenerator = rng
	if r == null:
		r = RandomNumberGenerator.new()
		r.randomize()
	var pool: Array[Dictionary] = _build_reward_pool()
	# Fisher–Yates shuffle using the injected RNG (Array.shuffle() ignores our seed).
	for i: int in range(pool.size() - 1, 0, -1):
		var j: int = r.randi_range(0, i)
		var tmp: Dictionary = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, mini(count, pool.size()))


## Applies the reward identified by [param boon_id] to its owning system.
## Prana cards ("prana_<n>") drop a fragment into the PranaBag; stat boons dispatch
## through the table below. No-op with a push_warning for an unknown id. Emits
## boon_applied on success.
func apply_boon(boon_id: StringName) -> void:
	var id_str: String = String(boon_id)
	if id_str.begins_with(_PRANA_ID_PREFIX):
		var type_id: int = id_str.substr(_PRANA_ID_PREFIX.length()).to_int()
		var bag: Node = _bag_provider.call()
		if is_instance_valid(bag) and bag.has_method(&"add"):
			bag.add(type_id)
		boon_applied.emit(boon_id)
		return
	match boon_id:
		&"damage":
			SpellCastingEffects.apply_damage_mult(CONFIG.damage_mult)
		&"overcharge":
			SpellCastingEffects.apply_damage_mult(CONFIG.overcharge_mult)
		&"move_speed":
			var p1: Node = _player_provider.call()
			if is_instance_valid(p1) and p1.has_method(&"apply_move_speed_mult"):
				p1.apply_move_speed_mult(CONFIG.move_speed_mult)
		&"dash_cd":
			var p2: Node = _player_provider.call()
			if is_instance_valid(p2) and p2.has_method(&"apply_dash_cooldown_mult"):
				p2.apply_dash_cooldown_mult(CONFIG.dash_cooldown_mult)
		&"heal":
			var p3: Node = _player_provider.call()
			if is_instance_valid(p3):
				HealthAndDamage.apply_heal(p3, CONFIG.heal_amount)
		_:
			push_warning("BoonManager.apply_boon: unknown boon id '%s'" % boon_id)
			return
	boon_applied.emit(boon_id)


## Test seam: overrides how the player node is resolved.
func set_player_provider(provider: Callable) -> void:
	_player_provider = provider


## Test seam: overrides how the PranaBag node is resolved.
func set_bag_provider(provider: Callable) -> void:
	_bag_provider = provider


## Builds the modal choice overlay with three boons and pauses the tree until the
## player picks one. No-op if an overlay is already open.
func offer_boons() -> void:
	if _overlay != null:
		return
	var choices: Array[Dictionary] = roll_choices(3)
	get_tree().paused = true

	_overlay = CanvasLayer.new()
	_overlay.layer = 28
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.06, 0.82)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	_overlay.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override(&"separation", 16)
	_overlay.add_child(vbox)

	var heading := Label.new()
	heading.text = CONFIG.heading
	heading.add_theme_font_size_override(&"font_size", 32)
	heading.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.4))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(heading)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 20)
	vbox.add_child(row)

	for boon: Dictionary in choices:
		row.add_child(_make_boon_card(boon))

	add_child(_overlay)


# ── Private ───────────────────────────────────────────────────────────────────

## Builds a single clickable reward card button. Card titles/descriptions come from
## CONFIG (centralized copy, staged for localization — see /localize). Prana cards
## (carrying a "prana_type" key) are tinted with the element's canonical colour from
## PranaCatalog so they read distinctly from stat boons in the mixed menu.
func _make_boon_card(boon: Dictionary) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(220, 120)
	card.add_theme_font_size_override(&"font_size", 18)
	card.text = "%s\n\n%s" % [boon["title"], boon["desc"]]
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if boon.has("prana_type"):
		var type_id: int = boon["prana_type"]
		if type_id >= 0 and type_id < PranaCatalog.type_count():
			card.add_theme_color_override(&"font_color", PranaCatalog.get_type_color(type_id))
	var id: StringName = boon["id"]
	card.pressed.connect(func() -> void: _on_boon_chosen(id))
	return card


## Applies the chosen boon, tears down the overlay, and unpauses the tree.
func _on_boon_chosen(boon_id: StringName) -> void:
	apply_boon(boon_id)
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	get_tree().paused = false
