## bullet_art_test.gd — Baked enemy bullet art (ADR-0050).
##
## Coverage:
##   one baked texture per radius / outline key, reused on the next call
##   the outline option widens the body to the white ring when it passes the glow
##   disc coverage is 1 inside, 0 outside and anti-aliased across the edge
##   the baked texture keeps the family rim colour on the rim ring and a clear corner
extends GdUnitTestSuite

const RIM: Color = Color(1.0, 0.2, 0.62, 1.0)
const SEP: Color = Color(0.05, 0.02, 0.1, 0.85)


func before_test() -> void:
	BulletArt.clear_cache()


func after_test() -> void:
	BulletArt.clear_cache()


func test_same_key_reuses_texture() -> void:
	var a: BulletArt = BulletArt.for_bullet(4.0, false, RIM, SEP)
	var b: BulletArt = BulletArt.for_bullet(4.0, false, RIM, SEP)
	assert_object(a).is_same(b)
	assert_int(BulletArt.cache_size()).is_equal(1)


func test_outline_is_its_own_key() -> void:
	BulletArt.for_bullet(4.0, false, RIM, SEP)
	BulletArt.for_bullet(4.0, true, RIM, SEP)
	assert_int(BulletArt.cache_size()).is_equal(2)


func test_body_radius_is_glow_without_outline() -> void:
	assert_float(BulletArt.body_radius(4.0, false)).is_equal_approx(4.0 * BulletArt.GLOW_MULT, 0.001)


func test_body_radius_takes_outline_ring_when_larger() -> void:
	# 3.5 × 2.5 = 8.75 < 3.5 + 5.5 = 9.0
	assert_float(BulletArt.body_radius(3.5, true)).is_equal_approx(3.5 + Projectile.OUTLINE_WHITE, 0.001)


func test_disc_coverage_inside_edge_outside() -> void:
	assert_float(BulletArt.disc_coverage(2.0, 8.0)).is_equal(1.0)
	assert_float(BulletArt.disc_coverage(8.0, 8.0)).is_equal_approx(0.5, 0.001)
	assert_float(BulletArt.disc_coverage(9.0, 8.0)).is_equal(0.0)


func test_body_quad_covers_the_glow() -> void:
	var art: BulletArt = BulletArt.for_bullet(4.0, false, RIM, SEP)
	assert_float(art.body_half).is_greater_equal(BulletArt.body_radius(4.0, false))
	assert_float(art.core_half).is_greater_equal(4.0)


func test_baked_rim_ring_is_rim_colour() -> void:
	var art: BulletArt = BulletArt.for_bullet(4.0, false, RIM, SEP)
	var img: Image = art.image
	var s: float = float(BulletArt.TEXELS_PER_PX)
	# Body cell centre, then step out to the middle of the rim ring (between r+1 and r+2.5).
	var cx: float = art.body_uv.get_center().x * float(img.get_width())
	var cy: float = art.body_uv.get_center().y * float(img.get_height())
	var ring_px: float = (4.0 + 1.75) * s
	var c: Color = img.get_pixel(int(cx + ring_px), int(cy))
	assert_float(c.r).is_equal_approx(RIM.r, 0.02)
	assert_float(c.g).is_equal_approx(RIM.g, 0.02)
	assert_float(c.a).is_greater(0.9)


func test_baked_corner_is_clear() -> void:
	var art: BulletArt = BulletArt.for_bullet(4.0, false, RIM, SEP)
	assert_float(art.image.get_pixel(0, 0).a).is_equal(0.0)
