## SigilManager — between-room reward system for the demo run.
##
## After clearing a combat/elite room, offer_sigils() presents a choice of three
## random reward cards drawn from a mixed pool: persistent stat sigils AND Prana
## sigils. A stat sigil applies a run modifier through its owning system
## (PlayerController speed/dash, SpellCastingEffects damage, HealthAndDamage heal);
## a Prana sigil drops one fragment into the PranaBag for placement in the next
## preparation phase (grid-as-build model). No central stat store — each system
## stays authoritative.
##
## "Sigil" is the project's umbrella term for the between-room reward (replacing the
## genre-generic "boon"): an inscribed mark Fayde takes to grow his recovered power.
##
## Logic (catalog / roll_choices / apply_sigil) is separated from presentation
## (offer_sigils builds the overlay) so the selection math is unit-testable headlessly.
##
## Created programmatically by debug_game_loop so both main.tscn and demo.tscn get
## it without scene edits. Not an Autoload — it is run-scoped, freed with the scene.
class_name SigilManager
extends Node

## Emitted after a reward is applied, carrying its id (sigil id or "prana_<n>").
## For HUD/audio feedback.
signal sigil_applied(sigil_id: StringName)

# ── Config ────────────────────────────────────────────────────────────────────
## Data-driven sigil tuning + copy: multipliers, catalog, heading, and Prana-card
## templates. Preloaded as a const so it resolves without _ready() — SigilManager is
## unit-tested via .new() with no SceneTree (see sigil_manager_test.gd). Element
## names and colours come from PranaCatalog (the canonical Prana type data), so no
## Prana names are duplicated here.
const CONFIG: SigilConfig = preload("res://assets/data/sigil_config.tres")

## Id prefix marking a Prana reward card. apply_sigil() detects this prefix and
## routes the card to the PranaBag instead of the sigil dispatch table.
const _PRANA_ID_PREFIX: String = "prana_"

const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")

## Resolves the player node. Overridable in tests via set_player_provider().
var _player_provider: Callable = func() -> Node:
	return get_tree().get_first_node_in_group(&"player")

## Resolves the PranaBag node. Overridable in tests via set_bag_provider().
var _bag_provider: Callable = func() -> Node:
	return get_tree().get_first_node_in_group(&"prana_bag")

## The live choice overlay while a selection is pending; null otherwise.
var _overlay: CanvasLayer = null

## Picks still owed in the current offer (ADR-0026: Cursed / flawless Challenge give 2).
var _picks_left: int = 0
var _picks_total: int = 0

## Emitted when the last owed pick of an offer has been made and the overlay closed.
signal offer_finished

## Runtime for behaviour sigils (ADR-0026). Set by debug_game_loop; when null a
## behaviour sigil is ignored with a warning.
var effects: SigilEffects = null

# ── Public API ────────────────────────────────────────────────────────────────

## Returns a copy of the full reward pool (stat sigils + one Prana sigil per type).
func get_catalog() -> Array[Dictionary]:
	return _build_reward_pool()


## Builds the combined reward pool: all stat sigils followed by one Prana sigil per
## Prana type. Rebuilt each call (cheap) so callers always get fresh copies.
func _build_reward_pool() -> Array[Dictionary]:
	var pool: Array[Dictionary] = CONFIG.sigils.duplicate(true)
	pool.append_array(_build_prana_cards())
	return pool


## Builds one Prana reward card per Prana type. Names come from PranaCatalog (the
## canonical type data) and the title/desc templates from CONFIG. Each card carries
## a "prana_type" key so the overlay can tint it and apply_sigil() can route it to
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


## Applies the reward identified by [param sigil_id] to its owning system.
## Prana sigils ("prana_<n>") drop a fragment into the PranaBag; stat sigils dispatch
## through the table below. No-op with a push_warning for an unknown id. Emits
## sigil_applied on success.
func apply_sigil(sigil_id: StringName) -> void:
	var id_str: String = String(sigil_id)
	if id_str.begins_with(_PRANA_ID_PREFIX):
		var type_id: int = id_str.substr(_PRANA_ID_PREFIX.length()).to_int()
		var bag: Node = _bag_provider.call()
		if is_instance_valid(bag) and bag.has_method(&"add"):
			bag.add(type_id)
		sigil_applied.emit(sigil_id)
		return
	if SigilEffects.handles(sigil_id):
		if not is_instance_valid(effects):
			push_warning("SigilManager.apply_sigil: no SigilEffects for '%s'" % sigil_id)
			return
		effects.add_stack(sigil_id)
		sigil_applied.emit(sigil_id)
		return
	match sigil_id:
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
		&"dash_charge":
			var p4: Node = _player_provider.call()
			if is_instance_valid(p4) and p4.has_method(&"add_dash_charges"):
				p4.add_dash_charges(CONFIG.dash_charge_bonus)
		&"dash_cut":
			var p5: Node = _player_provider.call()
			if is_instance_valid(p5) and p5.has_method(&"set_dash_cut_radius"):
				p5.set_dash_cut_radius(CONFIG.dash_cut_radius)
		&"graze_ring":
			var p6: Node = _player_provider.call()
			if is_instance_valid(p6) and p6.has_method(&"apply_graze_radius_mult"):
				p6.apply_graze_radius_mult(CONFIG.graze_radius_mult)
		_:
			push_warning("SigilManager.apply_sigil: unknown sigil id '%s'" % sigil_id)
			return
	sigil_applied.emit(sigil_id)


## Test seam: overrides how the player node is resolved.
func set_player_provider(provider: Callable) -> void:
	_player_provider = provider


## Test seam: overrides how the PranaBag node is resolved.
func set_bag_provider(provider: Callable) -> void:
	_bag_provider = provider


## Builds the modal choice overlay with three sigils and pauses the tree until the
## player picks one. [param picks] > 1 re-opens the overlay with fresh choices after
## each pick. No-op if an overlay is already open.
func offer_sigils(picks: int = 1) -> void:
	if _overlay != null:
		return
	_picks_total = maxi(picks, 1)
	_picks_left = _picks_total
	_open_overlay()


## Number of picks still owed in the current offer (0 when none is open).
func picks_left() -> int:
	return _picks_left


func _open_overlay() -> void:
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
	if _picks_total > 1:
		heading.text += _COPY.sigil_pick_format % [_picks_total - _picks_left + 1, _picks_total]
	heading.add_theme_font_size_override(&"font_size", 32)
	heading.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.4))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(heading)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 20)
	vbox.add_child(row)

	for sigil: Dictionary in choices:
		row.add_child(_make_sigil_card(sigil))

	add_child(_overlay)


# ── Private ───────────────────────────────────────────────────────────────────

## Builds a single clickable reward card button. Card titles/descriptions come from
## CONFIG (centralized copy, staged for localization — see /localize). Prana sigils
## (carrying a "prana_type" key) are tinted with the element's canonical colour from
## PranaCatalog so they read distinctly from stat sigils in the mixed menu. Behaviour
## sigils (carrying "behaviour") get the gold accent so play-changing picks stand out.
func _make_sigil_card(sigil: Dictionary) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(220, 120)
	card.add_theme_font_size_override(&"font_size", 18)
	card.text = "%s\n\n%s" % [sigil["title"], sigil["desc"]]
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if sigil.has("prana_type"):
		var type_id: int = sigil["prana_type"]
		if type_id >= 0 and type_id < PranaCatalog.type_count():
			card.add_theme_color_override(&"font_color", PranaCatalog.get_type_color(type_id))
	elif sigil.get("behaviour", false):
		card.add_theme_color_override(&"font_color", CONFIG.behaviour_card_color)
	var id: StringName = sigil["id"]
	card.pressed.connect(func() -> void: _on_sigil_chosen(id))
	return card


## Applies the chosen sigil and tears down the overlay. Re-opens it while picks are
## still owed; otherwise unpauses the tree and emits offer_finished.
func _on_sigil_chosen(sigil_id: StringName) -> void:
	apply_sigil(sigil_id)
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	_picks_left = maxi(_picks_left - 1, 0)
	if _picks_left > 0:
		_open_overlay()
		return
	get_tree().paused = false
	offer_finished.emit()
