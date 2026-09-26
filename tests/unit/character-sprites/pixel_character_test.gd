## pixel_character_test.gd — pixel-art character sprites and their wiring (ADR-0022, ADR-0034).
extends GdUnitTestSuite

const ENEMY_DIR: String = "res://assets/data/enemy_types/"
const FAYDE_SHEET: String = "res://assets/art/characters/fayde.png"
const FAYDE_GLOW: String = "res://assets/art/characters/fayde_glow.png"
const PLAYER_SCENE: String = "res://src/scenes/PlayerController.tscn"


func _all_enemy_types() -> Array[EnemyType]:
	var out: Array[EnemyType] = []
	for f: String in DirAccess.get_files_at(ENEMY_DIR):
		if f.ends_with(".tres"):
			out.append(load(ENEMY_DIR + f) as EnemyType)
	return out


# ── Frame selection ──────────────────────────────────────────────────────────

func test_idle_frames_cycle_through_row_zero() -> void:
	var fps: float = 6.0
	for i: int in PixelCharacter.FRAMES * 2:
		var f: int = PixelCharacter.frame_for((i + 0.5) / fps, PixelCharacter.ROW_IDLE, fps)
		assert_int(f).is_equal(i % PixelCharacter.FRAMES)


func test_moving_frames_use_row_one() -> void:
	var f: int = PixelCharacter.frame_for(0.0, PixelCharacter.ROW_MOVE, 6.0)
	assert_int(f).is_equal(PixelCharacter.FRAMES)
	f = PixelCharacter.frame_for(3.5 / 6.0, PixelCharacter.ROW_MOVE, 6.0)
	assert_int(f).is_equal(PixelCharacter.FRAMES + 3)


# ── Sheets ───────────────────────────────────────────────────────────────────

func test_every_enemy_type_has_a_sheet_with_the_standard_layout() -> void:
	for et: EnemyType in _all_enemy_types():
		assert_object(et.sprite_sheet).override_failure_message("%s has no sprite_sheet" % et.name).is_not_null()
		assert_int(et.sprite_sheet.get_width() % PixelCharacter.FRAMES).is_equal(0)
		assert_int(et.sprite_sheet.get_height() % PixelCharacter.ROWS).is_equal(0)


func test_sprite_pixel_scale_is_a_whole_number() -> void:
	for et: EnemyType in _all_enemy_types():
		assert_float(fmod(et.sprite_pixel_scale, 1.0)).is_equal(0.0)


func test_fayde_glow_sheet_matches_body_sheet() -> void:
	var body: Texture2D = load(FAYDE_SHEET)
	var glow: Texture2D = load(FAYDE_GLOW)
	assert_int(glow.get_width()).is_equal(body.get_width())
	assert_int(glow.get_height()).is_equal(body.get_height())


# ── PixelCharacter node ──────────────────────────────────────────────────────

func test_feet_sit_on_the_node_origin() -> void:
	var pc := PixelCharacter.new()
	pc.sheet = load(FAYDE_SHEET)
	var size: Vector2i = pc.get_frame_size()
	assert_int(size.x).is_equal(20)
	assert_int(size.y).is_equal(32)
	var body: Sprite2D = pc.get_child(0)
	assert_object(body.offset).is_equal(Vector2(-size.x / 2.0, -float(size.y)))
	pc.free()


func test_facing_left_mirrors_body_and_glow() -> void:
	var pc := PixelCharacter.new()
	pc.sheet = load(FAYDE_SHEET)
	pc.glow_sheet = load(FAYDE_GLOW)
	pc.set_facing_left(true)
	assert_bool((pc.get_child(0) as Sprite2D).flip_h).is_true()
	assert_bool((pc.get_child(1) as Sprite2D).flip_h).is_true()
	pc.set_facing_left(false)
	assert_bool((pc.get_child(0) as Sprite2D).flip_h).is_false()
	pc.free()


func test_glow_is_hidden_without_a_glow_sheet() -> void:
	var pc := PixelCharacter.new()
	pc.sheet = load(FAYDE_SHEET)
	assert_bool((pc.get_child(1) as Sprite2D).visible).is_false()
	pc.free()


func test_sprites_use_nearest_filtering() -> void:
	var pc := PixelCharacter.new()
	assert_int((pc.get_child(0) as Sprite2D).texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)
	pc.free()


func test_ghost_copies_the_current_frame() -> void:
	var pc := PixelCharacter.new()
	pc.sheet = load(FAYDE_SHEET)
	pc.set_facing_left(true)
	var g: Sprite2D = pc.make_ghost()
	assert_object(g.texture).is_same(pc.sheet)
	assert_bool(g.flip_h).is_true()
	assert_int(g.frame).is_equal(pc.get_frame())
	g.free()
	pc.free()


# ── Wiring ───────────────────────────────────────────────────────────────────

func test_player_scene_uses_the_fayde_sprite() -> void:
	var player: Node = (load(PLAYER_SCENE) as PackedScene).instantiate()
	var pc: PixelCharacter = player.get_node("PixelCharacter")
	assert_object(pc.sheet).is_not_null()
	assert_object(pc.glow_sheet).is_not_null()
	assert_bool(player.get_node("DebugCircle").get("hide_body")).is_true()
	player.free()


func test_enemy_init_adds_sprite_and_hides_placeholder_body() -> void:
	var e: EnemyInstance = (load("res://src/gameplay/EnemyInstance.tscn") as PackedScene).instantiate()
	e.init(0)  # Drifter
	var pc: PixelCharacter = e.get_node_or_null("PixelCharacter")
	assert_object(pc).is_not_null()
	assert_object(pc.sheet).is_same(EnemyCatalog.get_type(0).sprite_sheet)
	assert_bool(e.get_node("DebugCircle").get("hide_body")).is_true()
	e.free()


func test_boss_sprite_is_counter_scaled_to_whole_pixels() -> void:
	var e: EnemyInstance = (load("res://src/gameplay/EnemyInstance.tscn") as PackedScene).instantiate()
	e.init(5)  # Vault Sentinel, base_scale 2.5
	var et: EnemyType = EnemyCatalog.get_type(5)
	var pc: PixelCharacter = e.get_node("PixelCharacter")
	assert_float(pc.pixel_scale * et.base_scale).is_equal_approx(et.sprite_pixel_scale, 0.001)
	e.free()
