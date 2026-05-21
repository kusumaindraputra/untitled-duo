# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does the drag-and-drop rune grid feel like a game mechanic (not an inventory screen)?
# Date: 2026-05-20
#
# Hypothesis: Player in live combat pressure will spontaneously REARRANGE the grid
# (not just mash cast). Proven if player says "let me try..." or swaps runes unprompted.
#
# Controls:
#   Drag runes between grid slots to rearrange
#   SPACE = Cast current combo
#   R = Restart scene

extends Node2D

# ── Rune data ────────────────────────────────────────────────────────────────
const RUNE_TYPES: Dictionary = {
	"fire":      {"symbol": "F", "color": Color(1.0, 0.35, 0.1),  "name": "Fire"},
	"ice":       {"symbol": "I", "color": Color(0.25, 0.75, 1.0), "name": "Ice"},
	"lightning": {"symbol": "L", "color": Color(1.0, 1.0,  0.15), "name": "Lightning"},
	"shadow":    {"symbol": "S", "color": Color(0.65, 0.1, 0.9),  "name": "Shadow"},
	"earth":     {"symbol": "E", "color": Color(0.55, 0.38, 0.15),"name": "Earth"},
}
const RUNE_KEYS: Array = ["fire", "ice", "lightning", "shadow", "earth"]

# ── Layout constants ──────────────────────────────────────────────────────────
const SCREEN_SIZE     := Vector2(1024, 600)
const PLAYER_POS      := Vector2(580, 300)
const SLOT_SIZE       := Vector2(62, 62)
const GRID_ORIGIN     := Vector2(24, 50)
const GRID_PADDING    := 4.0

# ── Game state ────────────────────────────────────────────────────────────────
var grid: Dictionary = {}          # slot_index (0-8) -> rune_key
var slot_controls: Array = []
var enemies: Array        = []
var player_hp: int        = 100
var score: int            = 0
var alive: bool           = true
var spawn_elapsed: float  = 0.0
const SPAWN_INTERVAL: float = 3.5

# ── UI refs ───────────────────────────────────────────────────────────────────
var combo_label:  Label
var hp_label:     Label
var score_label:  Label
var cast_hint:    Label

# ═══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	_build_background()
	_build_arena()
	_build_grid_panel()
	_build_hud()
	_fill_grid_random()
	# Spawn 2 enemies immediately so player is under pressure from the start
	_spawn_enemy()
	_spawn_enemy()

# ── Background ────────────────────────────────────────────────────────────────
func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color   = Color(0.07, 0.07, 0.11)
	bg.size    = SCREEN_SIZE
	bg.position = Vector2.ZERO
	add_child(bg)

# ── Arena (player marker) ─────────────────────────────────────────────────────
func _build_arena() -> void:
	# Divider between grid panel and arena
	var divider := ColorRect.new()
	divider.color    = Color(0.18, 0.18, 0.25)
	divider.position = Vector2(255, 0)
	divider.size     = Vector2(2, SCREEN_SIZE.y)
	add_child(divider)

	# Player (static green square)
	var player := ColorRect.new()
	player.color    = Color(0.15, 0.9, 0.25)
	player.size     = Vector2(30, 30)
	player.position = PLAYER_POS - Vector2(15, 15)
	add_child(player)

	var plabel := Label.new()
	plabel.text     = "YOU"
	plabel.position = PLAYER_POS + Vector2(-14, 18)
	plabel.add_theme_color_override("font_color", Color(0.15, 0.9, 0.25))
	add_child(plabel)

# ── Grid panel ────────────────────────────────────────────────────────────────
func _build_grid_panel() -> void:
	var panel := ColorRect.new()
	panel.color    = Color(0.12, 0.12, 0.18)
	panel.position = Vector2(0, 0)
	panel.size     = Vector2(255, SCREEN_SIZE.y)
	add_child(panel)

	var title := Label.new()
	title.text     = "RUNE GRID"
	title.position = Vector2(24, 18)
	title.add_theme_color_override("font_color", Color(0.65, 0.65, 0.85))
	add_child(title)

	# 3×3 grid slots  (slot 4 = center — has a distinct ring drawn around it)
	for i in range(9):
		var row: int = i / 3
		var col: int = i % 3
		var pos := GRID_ORIGIN + Vector2(col, row) * (SLOT_SIZE + Vector2(GRID_PADDING, GRID_PADDING))
		var slot := RuneSlot.new(i, self, i == 4)
		slot.position = pos
		add_child(slot)
		slot_controls.append(slot)

	var center_hint := Label.new()
	center_hint.text     = "▲ CENTER = spell type"
	center_hint.position = Vector2(24, GRID_ORIGIN.y + 3 * (SLOT_SIZE.y + GRID_PADDING) + 2)
	center_hint.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	add_child(center_hint)

# ── HUD ───────────────────────────────────────────────────────────────────────
func _build_hud() -> void:
	var y := GRID_ORIGIN.y + 3.0 * (SLOT_SIZE.y + GRID_PADDING) + 16.0

	combo_label = _make_label("Combo: —", Vector2(24, y), Color(1.0, 0.9, 0.25))
	add_child(combo_label)

	hp_label = _make_label("HP: 100", Vector2(24, y + 28), Color(0.2, 1.0, 0.35))
	add_child(hp_label)

	score_label = _make_label("Score: 0", Vector2(24, y + 56), Color(1.0, 1.0, 1.0))
	add_child(score_label)

	cast_hint = _make_label("[SPACE] Cast  |  Drag runes to rearrange", Vector2(24, SCREEN_SIZE.y - 28), Color(0.5, 0.5, 0.6))
	add_child(cast_hint)

	var combo_title := _make_label("DETECTED COMBO:", Vector2(24, y - 20), Color(0.45, 0.45, 0.6))
	add_child(combo_title)

func _make_label(text: String, pos: Vector2, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text     = text
	lbl.position = pos
	lbl.add_theme_color_override("font_color", color)
	return lbl

# ── Grid fill / refresh ───────────────────────────────────────────────────────
func _fill_grid_random() -> void:
	for i in range(9):
		grid[i] = RUNE_KEYS[randi() % RUNE_KEYS.size()]
	_refresh_visuals()

func _partial_refresh_grid() -> void:
	# Replace 3 random slots with new runes — keeps some of what player built
	var indices := range(9)
	indices.shuffle()
	for i in indices.slice(0, 3):
		grid[i] = RUNE_KEYS[randi() % RUNE_KEYS.size()]
	_refresh_visuals()

func _refresh_visuals() -> void:
	for i in range(9):
		if i < slot_controls.size():
			slot_controls[i].set_rune(grid.get(i, ""))
	_update_combo_label()

func swap_slots(from_idx: int, to_idx: int) -> void:
	var tmp: String = grid.get(from_idx, "")
	grid[from_idx] = grid.get(to_idx, "")
	grid[to_idx]   = tmp
	_refresh_visuals()

# ── Combo evaluation (center-slot-based) ─────────────────────────────────────
# Grid layout:  0 1 2
#               3 4 5   ← slot 4 is CENTER (determines spell type)
#               6 7 8
# Neighbors of center that amplify or hybridize: 0,1,2,3,5,6,7,8
func _evaluate_combo() -> String:
	var center: String = grid.get(4, "")
	if center == "":
		return "basic_bolt"

	var adj := [0, 1, 2, 3, 5, 6, 7, 8]
	var same_count: int = 0
	var neighbor_set: Dictionary = {}
	for n in adj:
		var r: String = grid.get(n, "")
		if r == "":
			continue
		if r == center:
			same_count += 1
		else:
			neighbor_set[r] = true

	# Cross-type hybrids take priority over same-type scaling
	if center == "fire"   and "ice"       in neighbor_set: return "steam"
	if center == "ice"    and "lightning" in neighbor_set: return "blizzard"
	if center == "shadow" and "earth"     in neighbor_set: return "void_spike"

	# Same-type power scaling
	if center == "fire":
		return "mega_inferno" if same_count >= 4 else ("inferno" if same_count >= 1 else "basic_bolt")

	return "basic_bolt"

func _update_combo_label() -> void:
	var combo := _evaluate_combo()
	var display: Dictionary = {
		"mega_inferno": "MEGA INFERNO  (center Fire + 4 Fire neighbors)",
		"inferno":      "Inferno  (center Fire + Fire neighbor)",
		"blizzard":     "Blizzard  (center Ice + Lightning neighbor)",
		"steam":        "Steam Cloud  (center Fire + Ice neighbor)",
		"void_spike":   "Void Spike  (center Shadow + Earth neighbor)",
		"basic_bolt":   "Basic Bolt  (no combo — put a rune in CENTER slot)",
	}
	combo_label.text = "Combo: " + display.get(combo, combo)
	_highlight_active_runes(combo)

# Dims non-contributing slots; brightens active ones so player sees what matters.
func _highlight_active_runes(combo: String) -> void:
	var active: Array = []
	var center: String = grid.get(4, "")

	if center != "" and combo != "basic_bolt":
		active.append(4)
		var adj := [0, 1, 2, 3, 5, 6, 7, 8]
		for n in adj:
			var r: String = grid.get(n, "")
			if r == "" : continue
			match combo:
				"mega_inferno", "inferno": if r == "fire":    active.append(n)
				"blizzard":                if r == "lightning" or r == "ice": active.append(n)
				"steam":                   if r == "fire" or r == "ice":      active.append(n)
				"void_spike":              if r == "shadow" or r == "earth":  active.append(n)

	for i in range(9):
		if i < slot_controls.size():
			slot_controls[i].set_highlight(i in active)

# ── Input ─────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			get_tree().reload_current_scene()
			return
		if not alive:
			return
		if event.keycode == KEY_SPACE:
			_cast()

# ── Casting ───────────────────────────────────────────────────────────────────
func _cast() -> void:
	var combo := _evaluate_combo()
	match combo:
		"mega_inferno":
			_damage_radius(PLAYER_POS, 320, 60)
			_spawn_fx(PLAYER_POS, 320, Color(1.0, 0.2, 0.0), 0.55)
		"inferno":
			_damage_radius(PLAYER_POS, 220, 35)
			_spawn_fx(PLAYER_POS, 220, Color(1.0, 0.4, 0.1), 0.45)
		"blizzard":
			_damage_radius(PLAYER_POS, 200, 18)
			_slow_radius(PLAYER_POS, 200, 2.5)
			_spawn_fx(PLAYER_POS, 200, Color(0.3, 0.8, 1.0), 0.5)
		"steam":
			_spawn_zone(PLAYER_POS, 160, 12, 2.0, Color(0.75, 0.9, 0.95, 0.5))
		"void_spike":
			# Piercing bolt toward nearest enemy — damages all enemies in a narrow cone
			var target := _nearest_enemy()
			var dir := Vector2.RIGHT
			var fx_pos := PLAYER_POS + Vector2(220, 0)
			if target:
				dir     = (target.position - PLAYER_POS).normalized()
				fx_pos  = target.position
			for e in enemies.duplicate():
				if not is_instance_valid(e): continue
				var node := e as Node2D
				if node == null: continue
				var to_e: Vector2 = node.position - PLAYER_POS
				var dot: float    = to_e.normalized().dot(dir)
				if dot > 0.65 and to_e.length() < 420.0:
					e.take_damage(45)
			_spawn_fx(fx_pos, 28, Color(0.7, 0.1, 1.0), 0.35)
			# Second ring at midpoint so it looks like a travelling bolt
			_spawn_fx((PLAYER_POS + fx_pos) * 0.5, 16, Color(0.8, 0.3, 1.0), 0.2)
		_:  # basic_bolt
			var nearest = _nearest_enemy()
			if nearest:
				nearest.take_damage(22)
				_spawn_fx(nearest.position, 28, Color(0.9, 0.9, 0.9), 0.2)

	# Grid stays persistent — player rearranges manually between casts

# ── Enemy spawning ────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if not alive:
		return
	spawn_elapsed += delta
	if spawn_elapsed >= SPAWN_INTERVAL:
		spawn_elapsed = 0.0
		_spawn_enemy()
		if score > 50:   # spawn two at a time when score gets higher
			_spawn_enemy()
	enemies = enemies.filter(func(e): return is_instance_valid(e))

func _spawn_enemy() -> void:
	var e := Enemy.new(self)
	# Spawn from a random screen edge, in the right half (arena)
	var side := randi() % 4
	match side:
		0: e.position = Vector2(randf_range(270, SCREEN_SIZE.x), -40)
		1: e.position = Vector2(SCREEN_SIZE.x + 40, randf_range(0, SCREEN_SIZE.y))
		2: e.position = Vector2(randf_range(270, SCREEN_SIZE.x), SCREEN_SIZE.y + 40)
		3: e.position = Vector2(270, randf_range(0, SCREEN_SIZE.y))
	add_child(e)
	enemies.append(e)

# ── Combat helpers ────────────────────────────────────────────────────────────
func _damage_radius(center: Vector2, radius: float, dmg: int) -> void:
	for e in enemies.duplicate():
		if is_instance_valid(e) and e.position.distance_to(center) <= radius:
			e.take_damage(dmg)

func _slow_radius(center: Vector2, radius: float, duration: float) -> void:
	for e in enemies.duplicate():
		if is_instance_valid(e) and e.position.distance_to(center) <= radius:
			e.apply_slow(duration)

func _nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var best: float     = 9999.0
	for e in enemies:
		if is_instance_valid(e):
			var node := e as Node2D
			if node == null:
				continue
			var d: float = node.position.distance_to(PLAYER_POS)
			if d < best:
				best    = d
				nearest = node
	return nearest

func _spawn_fx(center: Vector2, radius: float, color: Color, duration: float) -> void:
	var fx := CastFX.new(center, radius, color, duration)
	add_child(fx)

func _spawn_zone(center: Vector2, radius: float, dpt: int, duration: float, color: Color) -> void:
	var z := DamageZone.new(center, radius, dpt, duration, color, self)
	add_child(z)

# ── Events called by enemies / slots ─────────────────────────────────────────
func on_enemy_reached_player(dmg: int) -> void:
	if not alive:
		return
	player_hp -= dmg
	player_hp = max(0, player_hp)
	var t: float = float(player_hp) / 100.0
	hp_label.text = "HP: " + str(player_hp)
	hp_label.add_theme_color_override("font_color", Color(1.0 - t * 0.8, t * 0.9 + 0.1, t * 0.3))
	if player_hp <= 0:
		_game_over()

func on_enemy_killed() -> void:
	score += 10
	score_label.text = "Score: " + str(score)

func _game_over() -> void:
	alive = false
	var overlay := ColorRect.new()
	overlay.color    = Color(0.0, 0.0, 0.0, 0.6)
	overlay.size     = SCREEN_SIZE
	overlay.position = Vector2.ZERO
	add_child(overlay)
	var lbl := Label.new()
	lbl.text     = "GAME OVER\nScore: " + str(score) + "\n\n[R] Restart"
	lbl.position = Vector2(380, 220)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	lbl.add_theme_font_size_override("font_size", 32)
	add_child(lbl)


# ═══════════════════════════════════════════════════════════════════════════════
# INNER CLASS: RuneSlot
# A single drag-and-drop cell in the 3×3 rune grid.
# ═══════════════════════════════════════════════════════════════════════════════
class RuneSlot extends Control:
	var slot_index: int
	var _main: Node
	var _bg:    ColorRect
	var _label: Label
	var _current_rune: String = ""

	var _is_center: bool = false

	func _init(index: int, main_node: Node, is_center: bool = false) -> void:
		slot_index  = index
		_main       = main_node
		_is_center  = is_center
		custom_minimum_size = Vector2(62, 62)
		size                = Vector2(62, 62)

	func _ready() -> void:
		# Slot itself must capture mouse; children must pass through so drag fires on the slot
		mouse_filter = Control.MOUSE_FILTER_STOP

		_bg            = ColorRect.new()
		_bg.size       = Vector2(62, 62)
		_bg.color      = Color(0.18, 0.18, 0.25)
		_bg.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(_bg)

		var border := ColorRect.new()
		border.size        = Vector2(62, 62)
		border.color       = Color(0.28, 0.28, 0.38)
		border.position    = Vector2.ZERO
		border.mouse_filter = Control.MOUSE_FILTER_PASS
		var inner := ColorRect.new()
		inner.size         = Vector2(58, 58)
		inner.position     = Vector2(2, 2)
		inner.color        = Color(0.18, 0.18, 0.25)
		inner.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(border)
		add_child(inner)

		_label                      = Label.new()
		_label.size                 = Vector2(62, 62)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 26)
		_label.mouse_filter         = Control.MOUSE_FILTER_PASS
		add_child(_label)

		# Center slot gets a gold border to signal it's the spell core
		if _is_center:
			var ring := ColorRect.new()
			ring.size        = Vector2(62, 62)
			ring.color       = Color(1.0, 0.85, 0.2, 0.55)
			ring.mouse_filter = Control.MOUSE_FILTER_PASS
			var ring_inner := ColorRect.new()
			ring_inner.size        = Vector2(56, 56)
			ring_inner.position    = Vector2(3, 3)
			ring_inner.color       = Color(0, 0, 0, 0)
			ring_inner.mouse_filter = Control.MOUSE_FILTER_PASS
			ring.add_child(ring_inner)
			add_child(ring)

	func set_rune(rune_key: String) -> void:
		_current_rune = rune_key
		if rune_key == "":
			_bg.color   = Color(0.18, 0.18, 0.25)
			_label.text = ""
			return
		var data: Dictionary = _main.RUNE_TYPES[rune_key]
		_bg.color = data["color"] * 0.45
		_label.text = data["symbol"]
		_label.add_theme_color_override("font_color", data["color"])

	# Active slots glow full brightness; inactive slots dim to show they don't contribute.
	func set_highlight(active: bool) -> void:
		if _current_rune == "":
			return
		var data: Dictionary = _main.RUNE_TYPES[_current_rune]
		_bg.color = data["color"] * (0.75 if active else 0.22)
		_label.add_theme_color_override(
			"font_color",
			data["color"] if active else data["color"] * 0.45
		)

	func _get_drag_data(_pos: Vector2) -> Variant:
		if _current_rune == "":
			return null
		var preview := ColorRect.new()
		preview.size  = Vector2(40, 40)
		preview.color = _main.RUNE_TYPES[_current_rune]["color"] * 0.8
		var plabel := Label.new()
		plabel.text = _main.RUNE_TYPES[_current_rune]["symbol"]
		plabel.size = Vector2(40, 40)
		plabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plabel.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		plabel.add_theme_font_size_override("font_size", 20)
		plabel.add_theme_color_override("font_color", Color.WHITE)
		preview.add_child(plabel)
		set_drag_preview(preview)
		return {"rune": _current_rune, "from": slot_index}

	func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
		return data is Dictionary and "rune" in data and "from" in data

	func _drop_data(_pos: Vector2, data: Variant) -> void:
		_main.swap_slots(data["from"], slot_index)


# ═══════════════════════════════════════════════════════════════════════════════
# INNER CLASS: Enemy
# Walks toward the player, deals contact damage, has HP.
# ═══════════════════════════════════════════════════════════════════════════════
class Enemy extends Node2D:
	var _main:        Node
	var _max_hp:      int   = 30
	var _hp:          int   = 30
	var _speed:       float = 75.0
	var _slow_timer:  float = 0.0
	var _body:        ColorRect
	var _hp_bar:      ColorRect
	var _hp_bar_bg:   ColorRect

	func _init(main_node: Node) -> void:
		_main = main_node

	func _ready() -> void:
		_body          = ColorRect.new()
		_body.size     = Vector2(26, 26)
		_body.position = Vector2(-13, -13)
		_body.color    = Color(0.85, 0.18, 0.18)
		add_child(_body)

		_hp_bar_bg          = ColorRect.new()
		_hp_bar_bg.size     = Vector2(30, 4)
		_hp_bar_bg.position = Vector2(-15, -20)
		_hp_bar_bg.color    = Color(0.25, 0.0, 0.0)
		add_child(_hp_bar_bg)

		_hp_bar          = ColorRect.new()
		_hp_bar.size     = Vector2(30, 4)
		_hp_bar.position = Vector2(-15, -20)
		_hp_bar.color    = Color(0.9, 0.15, 0.15)
		add_child(_hp_bar)

	func _process(delta: float) -> void:
		if _slow_timer > 0:
			_slow_timer -= delta

		var eff_speed: float = _speed * (0.28 if _slow_timer > 0 else 1.0)
		var dir: Vector2     = (_main.PLAYER_POS - position).normalized()
		position            += dir * eff_speed * delta

		if position.distance_to(_main.PLAYER_POS) < 22.0:
			_main.on_enemy_reached_player(8)
			queue_free()

	func take_damage(amount: int) -> void:
		_hp -= amount
		_hp_bar.size.x = 30.0 * clampf(float(_hp) / float(_max_hp), 0.0, 1.0)
		if _hp <= 0:
			_main.on_enemy_killed()
			queue_free()

	func apply_slow(duration: float) -> void:
		_slow_timer = duration
		_body.color = Color(0.4, 0.4, 0.95)


# ═══════════════════════════════════════════════════════════════════════════════
# INNER CLASS: CastFX
# Expanding ring visual for spell effects.
# ═══════════════════════════════════════════════════════════════════════════════
class CastFX extends Node2D:
	var _max_radius: float
	var _color:      Color
	var _duration:   float
	var _elapsed:    float = 0.0

	func _init(pos: Vector2, max_r: float, col: Color, dur: float) -> void:
		position    = pos
		_max_radius = max_r
		_color      = col
		_duration   = dur

	func _process(delta: float) -> void:
		_elapsed += delta
		if _elapsed >= _duration:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t:      float = _elapsed / _duration
		var radius: float = _max_radius * ease(t, -2.0)
		var alpha:  float = 1.0 - t
		draw_circle(Vector2.ZERO, radius, Color(_color.r, _color.g, _color.b, alpha * 0.3))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(_color.r, _color.g, _color.b, alpha), 2.5)


# ═══════════════════════════════════════════════════════════════════════════════
# INNER CLASS: DamageZone
# Persistent area that ticks damage (used by Steam combo).
# ═══════════════════════════════════════════════════════════════════════════════
class DamageZone extends Node2D:
	var _main:        Node
	var _radius:      float
	var _dpt:         int
	var _duration:    float
	var _zone_color:  Color
	var _elapsed:     float = 0.0
	var _tick_timer:  float = 0.0

	func _init(pos: Vector2, r: float, dpt: int, dur: float, col: Color, main_node: Node) -> void:
		position    = pos
		_main       = main_node
		_radius     = r
		_dpt        = dpt
		_duration   = dur
		_zone_color = col

	func _process(delta: float) -> void:
		_elapsed    += delta
		_tick_timer += delta
		if _elapsed >= _duration:
			queue_free()
			return
		if _tick_timer >= 0.5:
			_tick_timer = 0.0
			_main._damage_radius(position, _radius, _dpt)
		queue_redraw()

	func _draw() -> void:
		var alpha: float = (1.0 - _elapsed / _duration) * 0.45
		draw_circle(Vector2.ZERO, _radius, Color(_zone_color.r, _zone_color.g, _zone_color.b, alpha))
		draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 40,
			Color(_zone_color.r, _zone_color.g, _zone_color.b, alpha * 2.0), 1.5)
