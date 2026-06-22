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

# ── Boon tuning values (demo) ─────────────────────────────────────────────────
# TODO(data-driven): demo debt — these tuning values and the element names below
# should load from a config resource, not be hardcoded (coding-standards.md).
const _DMG_BOON: float = 1.20        ## +20% spell damage
const _DMG_BOON_BIG: float = 1.35    ## +35% spell damage
const _MOVE_BOON: float = 1.15       ## +15% move speed
const _DASH_BOON: float = 0.75       ## -25% dash cooldown
const _HEAL_BOON: float = 40.0       ## flat HP restored

## Id prefix marking a Prana reward card. apply_boon() detects this prefix and
## routes the card to the PranaBag instead of the boon dispatch table.
const _PRANA_ID_PREFIX: String = "prana_"

## Full element names per Prana type_id (0–4), used in Prana card titles. Mirrors the
## Art Bible palette order in PranaTypeToken.TYPE_COLORS / TYPE_NAMES.
const _PRANA_FULL_NAMES: Array[String] = ["Ashfire", "Voidblue", "Stormgold", "Deepfrost", "Verdant"]

## Static boon catalog. Each entry: id, title, desc. The effect is dispatched by
## id in apply_boon(). Kept as a data table so roll/apply logic is value-driven.
## The full reward pool also includes Prana cards built in _build_prana_cards().
const _CATALOG: Array[Dictionary] = [
	{"id": &"damage",     "title": "Sharpened Cipher", "desc": "+20% spell damage"},
	{"id": &"overcharge", "title": "Overcharge",       "desc": "+35% spell damage"},
	{"id": &"move_speed", "title": "Swift Step",        "desc": "+15% move speed"},
	{"id": &"dash_cd",    "title": "Quick Recovery",    "desc": "-25% dash cooldown"},
	{"id": &"heal",       "title": "Second Wind",       "desc": "Restore 40 HP"},
]

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
	var pool: Array[Dictionary] = _CATALOG.duplicate(true)
	pool.append_array(_build_prana_cards())
	return pool


## Builds one Prana reward card per type_id (0–4). Each card carries a "prana_type"
## key so the overlay can tint it and apply_boon() can route it to the bag.
func _build_prana_cards() -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	for type_id: int in _PRANA_FULL_NAMES.size():
		var full_name: String = _PRANA_FULL_NAMES[type_id]
		cards.append({
			"id": StringName(_PRANA_ID_PREFIX + str(type_id)),
			"title": "Gain %s" % full_name,
			"desc": "+1 %s Prana to your bag" % full_name,
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
			SpellCastingEffects.apply_damage_mult(_DMG_BOON)
		&"overcharge":
			SpellCastingEffects.apply_damage_mult(_DMG_BOON_BIG)
		&"move_speed":
			var p1: Node = _player_provider.call()
			if is_instance_valid(p1) and p1.has_method(&"apply_move_speed_mult"):
				p1.apply_move_speed_mult(_MOVE_BOON)
		&"dash_cd":
			var p2: Node = _player_provider.call()
			if is_instance_valid(p2) and p2.has_method(&"apply_dash_cooldown_mult"):
				p2.apply_dash_cooldown_mult(_DASH_BOON)
		&"heal":
			var p3: Node = _player_provider.call()
			if is_instance_valid(p3):
				HealthAndDamage.apply_heal(p3, _HEAL_BOON)
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
	heading.text = "ROOM CLEARED — Choose a Reward"
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

## TODO(i18n): demo debt — card titles/descriptions and the overlay heading are
## hardcoded user-facing strings; route through the localization system (ui-code.md).
## Builds a single clickable reward card button. Prana cards (carrying a "prana_type"
## key) are tinted with the element's Art Bible colour so they read distinctly from
## stat boons in the mixed menu.
func _make_boon_card(boon: Dictionary) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(220, 120)
	card.add_theme_font_size_override(&"font_size", 18)
	card.text = "%s\n\n%s" % [boon["title"], boon["desc"]]
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if boon.has("prana_type"):
		var type_id: int = boon["prana_type"]
		if type_id >= 0 and type_id < PranaTypeToken.TYPE_COLORS.size():
			card.add_theme_color_override(&"font_color", PranaTypeToken.TYPE_COLORS[type_id])
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
