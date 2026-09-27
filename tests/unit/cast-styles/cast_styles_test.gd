## cast_styles_test.gd — Fayde's per-Prana cast poses (ADR-0056).
extends GdUnitTestSuite

const FAYDE_SHEET: String = "res://assets/art/characters/fayde.png"
const CAST_SHEET: String = "res://assets/art/characters/fayde_casts.png"
const CAST_GLOW: String = "res://assets/art/characters/fayde_casts_glow.png"
const PLAYER_SCENE: String = "res://src/scenes/PlayerController.tscn"
const PRANA_DIR: String = "res://assets/data/prana_types/"
## Release column: the pose each style is recognised by.
const RELEASE_COL: int = 1


func _pc() -> PixelCharacter:
	var pc := PixelCharacter.new()
	pc.sheet = load(FAYDE_SHEET)
	pc.cast_sheet = load(CAST_SHEET)
	pc.cast_glow_sheet = load(CAST_GLOW)
	return pc


func _cell(img: Image, col: int, row: int) -> Image:
	var cw: int = img.get_width() / PixelCharacter.FRAMES
	var ch: int = img.get_height() / PixelCharacter.CAST_STYLES
	return img.get_region(Rect2i(col * cw, row * ch, cw, ch))


# ── Sheets ───────────────────────────────────────────────────────────────────

func test_cast_sheet_has_one_row_per_style_in_the_main_cell_size() -> void:
	var main: Texture2D = load(FAYDE_SHEET)
	var casts: Texture2D = load(CAST_SHEET)
	assert_int(casts.get_width()).is_equal(main.get_width())
	assert_int(casts.get_height() / PixelCharacter.CAST_STYLES).is_equal(main.get_height() / PixelCharacter.ROWS)
	assert_int(casts.get_height() % PixelCharacter.CAST_STYLES).is_equal(0)


func test_cast_glow_matches_cast_sheet() -> void:
	var casts: Texture2D = load(CAST_SHEET)
	var glow: Texture2D = load(CAST_GLOW)
	assert_int(glow.get_width()).is_equal(casts.get_width())
	assert_int(glow.get_height()).is_equal(casts.get_height())


func test_every_style_has_a_different_release_pose() -> void:
	var img: Image = (load(CAST_SHEET) as Texture2D).get_image()
	for a: int in PixelCharacter.CAST_STYLES:
		for b: int in range(a + 1, PixelCharacter.CAST_STYLES):
			var same: bool = _cell(img, RELEASE_COL, a).get_data() == _cell(img, RELEASE_COL, b).get_data()
			assert_bool(same).override_failure_message("styles %d and %d share a release pose" % [a, b]).is_false()


func test_every_prana_type_maps_to_a_cast_style_row() -> void:
	var seen: Dictionary = {}
	for f: String in DirAccess.get_files_at(PRANA_DIR):
		if not f.ends_with(".tres"):
			continue
		var t: PranaType = load(PRANA_DIR + f) as PranaType
		var style: int = int(t.cast_animation)
		assert_int(style).is_between(0, PixelCharacter.CAST_STYLES - 1)
		seen[style] = true
	# Five Prana, five distinct poses.
	assert_int(seen.size()).is_equal(PixelCharacter.CAST_STYLES)


# ── Frame selection ──────────────────────────────────────────────────────────

func test_styled_frames_walk_the_style_row() -> void:
	for style: int in PixelCharacter.CAST_STYLES:
		var start: int = style * PixelCharacter.FRAMES
		assert_int(PixelCharacter.styled_cast_frame_for(0.0, 0.4, style)).is_equal(start)
		assert_int(PixelCharacter.styled_cast_frame_for(0.15, 0.4, style)).is_equal(start + 1)
		assert_int(PixelCharacter.styled_cast_frame_for(5.0, 0.4, style)).is_equal(start + 3)


func test_styled_cast_shows_the_cast_sheet_then_returns_to_the_main_sheet() -> void:
	var pc := _pc()
	pc.play_cast(0.3, 2)
	assert_int(pc.get_cast_style()).is_equal(2)
	assert_int(pc.get_frame()).is_equal(2 * PixelCharacter.FRAMES)
	var body: Sprite2D = pc.get_child(0) as Sprite2D
	assert_object(body.texture).is_same(pc.cast_sheet)
	assert_int(body.vframes).is_equal(PixelCharacter.CAST_STYLES)
	pc.advance_fx(0.4)
	pc._update_frame()
	assert_int(pc.get_cast_style()).is_equal(-1)
	assert_object(body.texture).is_same(pc.sheet)
	assert_int(body.vframes).is_equal(PixelCharacter.ROWS)
	pc.free()


func test_plain_cast_without_style_uses_the_main_cast_row() -> void:
	var pc := _pc()
	pc.play_cast(0.3)
	assert_int(pc.get_cast_style()).is_equal(-1)
	assert_int(pc.get_frame()).is_equal(PixelCharacter.ROW_CAST * PixelCharacter.FRAMES)
	pc.free()


func test_style_is_ignored_without_a_cast_sheet() -> void:
	var pc := PixelCharacter.new()
	pc.sheet = load(FAYDE_SHEET)
	pc.play_cast(0.3, 0)
	assert_int(pc.get_cast_style()).is_equal(-1)
	assert_int(pc.get_frame()).is_equal(PixelCharacter.ROW_CAST * PixelCharacter.FRAMES)
	pc.free()


func test_out_of_range_style_falls_back_to_the_plain_row() -> void:
	var pc := _pc()
	pc.play_cast(0.3, PixelCharacter.CAST_STYLES)
	assert_int(pc.get_cast_style()).is_equal(-1)
	pc.free()


func test_player_scene_wires_the_cast_sheets() -> void:
	var player: Node = (load(PLAYER_SCENE) as PackedScene).instantiate()
	var pc: PixelCharacter = player.get_node(^"PixelCharacter") as PixelCharacter
	assert_object(pc.cast_sheet).is_not_null()
	assert_object(pc.cast_glow_sheet).is_not_null()
	player.free()
