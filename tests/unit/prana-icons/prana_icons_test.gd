## prana_icons_test.gd — Prana shape icons for colour-blind readability (ADR-0036).
##
## Coverage:
##   PI-01: every shipped Prana type has a 12×12 shape icon
##   PI-02: the five silhouettes differ from each other, also squeezed to 8×8 (art bible §4.5)
##   PI-03: PranaIcon scales by whole numbers and caches per (type, scale)
##   PI-04: a grid slot shows the icon only while filled
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const TYPES_DIR: String = "res://assets/data/prana_types/"
const TYPE_FILES: Array[String] = [
	"prana_fire.tres", "prana_shadow.tres", "prana_lightning.tres", "prana_ice.tres", "prana_nature.tres",
]


func _icon_image(file: String) -> Image:
	var pt: PranaType = load(TYPES_DIR + file) as PranaType
	var img: Image = pt.icon.get_image().duplicate()
	if img.is_compressed():
		img.decompress()
	return img


## Opaque-pixel mask of [param img] after a nearest resize to [param size]².
func _mask(img: Image, size: int) -> PackedByteArray:
	var copy: Image = img.duplicate()
	copy.resize(size, size, Image.INTERPOLATE_NEAREST)
	var out := PackedByteArray()
	for y in size:
		for x in size:
			out.append(1 if copy.get_pixel(x, y).a > 0.5 else 0)
	return out


func test_every_type_has_12px_icon() -> void:
	for file: String in TYPE_FILES:
		var pt: PranaType = load(TYPES_DIR + file) as PranaType
		assert_object(pt.icon).is_not_null()
		assert_int(pt.icon.get_width()).is_equal(PranaIcon.NATIVE_SIZE)
		assert_int(pt.icon.get_height()).is_equal(PranaIcon.NATIVE_SIZE)


func test_silhouettes_are_distinct_at_12_and_8_px() -> void:
	for size: int in [12, 8]:
		var masks: Array[PackedByteArray] = []
		for file: String in TYPE_FILES:
			var m: PackedByteArray = _mask(_icon_image(file), size)
			assert_bool(m.has(1)).is_true()
			assert_bool(m.has(0)).is_true()
			masks.append(m)
		for i in masks.size():
			for j in range(i + 1, masks.size()):
				assert_bool(masks[i] == masks[j]).override_failure_message(
					"icons %d and %d share a silhouette at %d px" % [i, j, size]).is_false()


func test_texture_scales_by_whole_numbers_and_caches() -> void:
	PranaIcon.clear_cache()
	var t3: Texture2D = PranaIcon.texture(0, 3)
	assert_object(t3).is_not_null()
	assert_int(t3.get_width()).is_equal(PranaIcon.NATIVE_SIZE * 3)
	assert_object(PranaIcon.texture(0, 3)).is_same(t3)
	assert_object(PranaIcon.texture(1, 3)).is_not_same(t3)
	assert_int(PranaIcon.texture(2, 1).get_width()).is_equal(PranaIcon.NATIVE_SIZE)
	assert_object(PranaIcon.texture(99, 2)).is_null()
	PranaIcon.clear_cache()


func test_grid_slot_shows_icon_only_when_filled() -> void:
	var slot := PranaGridSlot.new()
	add_child(slot)
	assert_bool(slot._icon_rect.visible).is_false()
	slot.refresh(3)
	assert_bool(slot._icon_rect.visible).is_true()
	assert_object(slot._icon_rect.texture).is_same(PranaIcon.texture(3, PranaGridSlot.ICON_SCALE))
	slot.refresh(-1)
	assert_bool(slot._icon_rect.visible).is_false()
	remove_child(slot)
	slot.free()
