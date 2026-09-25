## generate_character_sprites.gd — builds every character sprite sheet (ADR-0022).
##
## Run from the project root:
##   godot --headless --path . -s tools/art-gen/generate_character_sprites.gd
##
## Each sheet is FRAMES columns × 2 rows: row 0 idle, row 1 moving. Designs follow
## the art bible (§3.2 silhouettes, §4 palette, §5 character direction): warm or
## cool neutral bodies, a desaturated Prana "transformation marker" on enemies,
## and Fayde's hand/lens glow drawn on a separate white glow sheet so the game can
## tint it with the active Prana. Output goes to assets/art/characters/.
extends SceneTree

const PixelPainter = preload("res://tools/art-gen/pixel_painter.gd")

const OUT_DIR: String = "res://assets/art/characters/"
const FRAMES: int = 4

# Art bible palette.
const OUTLINE := Color("#17121A")
const E3 := Color("#5E4E3D")
const E7 := Color("#8E7358")
const SKIN := Color("#E6BE94")
const HAIR := Color("#2C2434")
const COAT := Color("#8A7358")
const TUNIC := Color("#C2AA82")
const TROUSER := Color("#3E3644")
const BOOT := Color("#2A2228")
const STRAP := Color("#4B3A2B")
const METAL := Color("#7A7A86")
const METAL_WARM := Color("#8C8274")
const STONE := Color("#6E6660")
const B1_VIOLET := Color("#9B2ED4")
const B2_TEAL := Color("#23B39A")

# Prana colours (assets/data/prana_types).
const ASHFIRE := Color(0.949, 0.298, 0.114)
const VOIDBLUE := Color(0.290, 0.369, 0.961)
const STORMGOLD := Color(1.0, 0.8, 0.0)
const DEEPFROST := Color(0.239, 0.851, 0.941)
const VERDANT := Color(0.102, 0.788, 0.325)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_sheet("fayde", 20, 32, _fayde, _fayde_glow)
	_sheet("drifter", 22, 18, _drifter)
	_sheet("charger", 14, 26, _charger)
	_sheet("cluster", 26, 24, _cluster)
	_sheet("weaver", 20, 20, _weaver)
	_sheet("mortar", 18, 20, _mortar)
	_sheet("rifter", 20, 24, _rifter)
	_sheet("sniper", 16, 28, _sniper)
	_sheet("spinner", 22, 18, _spinner)
	_sheet("splitter", 18, 18, _splitter)
	_sheet("warped_warden", 48, 48, _warden)
	_sheet("vault_sentinel", 48, 48, _sentinel)
	print("sprites written to ", OUT_DIR)
	quit()


func _sheet(name: String, cw: int, ch: int, body: Callable, glow: Callable = Callable()) -> void:
	var img := Image.create(cw * FRAMES, ch * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var p := PixelPainter.new(img, cw, ch)
	for row: int in 2:
		for f: int in FRAMES:
			p.cell(f, row)
			body.call(p, f, row == 1)
			p.outline(OUTLINE)
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + name + ".png"))
	if glow.is_valid():
		var gimg := Image.create(cw * FRAMES, ch * 2, false, Image.FORMAT_RGBA8)
		gimg.fill(Color(0, 0, 0, 0))
		var g := PixelPainter.new(gimg, cw, ch)
		for row: int in 2:
			for f: int in FRAMES:
				g.cell(f, row)
				glow.call(g, f, row == 1)
		gimg.save_png(ProjectSettings.globalize_path(OUT_DIR + name + "_glow.png"))


# ── Fayde ────────────────────────────────────────────────────────────────────
# Discoverer, not fighter: slight build, hooded coat to mid-calf, satchel strap,
# hood peak as the single vertical accent, Prana glow in the hands and lens.

## Upper body, facing right (rows 0–26). Key: C coat, c coat fold, H hair, S skin,
## s skin shade, E eye, T tunic, B satchel strap, A clasp. Hands are the S pairs on
## rows 21–22; they and the lens (near eye) glow on the glow sheet.
const _FAYDE_UPPER: Array[String] = [
	"......c.............",
	".....cc.............",
	".....cCc............",
	"....cCCCCCc.........",
	"...cCCHHHHHCc.......",
	"...cCHHHHHHHHc......",
	"...cHHHHHHHHHHc.....",
	"...cHHHHSHHSHHc.....",
	"...cHHSSSSSSSSs.....",
	"...cHHSSESSSESs.....",
	"...cHHSSSSSSSSs.....",
	"...ccHsSSSsSSSs.....",
	"....ccsSSSSSSs......",
	".....cCcsssss.......",
	"....cCCCCATCCc......",
	"...cCCCCCTTCBCc.....",
	"...cCCCCCTTBCCCc....",
	"..ccCCCCCTBCCCCcc...",
	"..cCcCCCCBTCCCcCc...",
	"..cCcCCCBTTCCCcCc...",
	"..cCcCCBCTTCCCcCc...",
	"..SScCBBBTTCCCcSS...",
	"..SScCBBBTTCCCcSS...",
	"...cCCBBBTTCCCCc....",
	"...cCCCCCTTCCCCc....",
	"..cCCCCCCTTCCCCCc...",
	"..cccCCCCTTCCCCcc...",
]

## Legs (rows 27–31): P trousers, K boots. Index 0 standing, 1 left leg forward,
## 2 right leg forward.
const _FAYDE_LEGS: Array = [
	["....ccPP..PPcc......", "......PP..PP........", "......PP..PP........", ".....KKK..KKK.......", ".....KKK..KKK......."],
	["....ccPP...PPc......", ".....PP.....PP......", ".....PP.....PP......", "....KKK.....KKK.....", "....KKK......KK....."],
	["....cPP...PPcc......", "......PP..PP........", ".......PP.PP........", "......KKKKKK........", "......KKK.KKK......."],
]

const _FAYDE_COLOURS: Dictionary = {
	"C": Color("#9C8264"), "c": Color("#6E5A45"), "H": HAIR, "S": SKIN,
	"s": Color("#C49A74"), "E": Color("#1E1A28"), "T": Color("#D4BC90"),
	"B": STRAP, "A": E7, "P": TROUSER, "K": BOOT,
}


## Returns (body drop, leg variant, hem sway) for a frame.
func _fayde_pose(f: int, moving: bool) -> Vector3i:
	if moving:
		var legs: Array[int] = [1, 0, 2, 0]
		var drop: Array[int] = [1, 0, 1, 0]
		var sway: Array[int] = [1, 0, -1, 0]
		return Vector3i(drop[f], legs[f], sway[f])
	var breathe: Array[int] = [0, 0, 1, 1]
	return Vector3i(breathe[f], 0, 0)


func _fayde(p: PixelPainter, f: int, moving: bool) -> void:
	var pose: Vector3i = _fayde_pose(f, moving)
	var legs: Array = _FAYDE_LEGS[pose.y]
	for r: int in legs.size():
		_ascii_row(p, legs[r], 27 + r, 0)
	for r: int in _FAYDE_UPPER.size():
		var shift: int = pose.z if r >= 24 else 0
		_ascii_row(p, _FAYDE_UPPER[r], r + pose.x, shift)


func _ascii_row(p: PixelPainter, row: String, y: int, dx: int) -> void:
	for x: int in row.length():
		var k: String = row[x]
		if _FAYDE_COLOURS.has(k):
			p.px(x + dx, y, _FAYDE_COLOURS[k])


func _fayde_glow(g: PixelPainter, f: int, moving: bool) -> void:
	var d: int = _fayde_pose(f, moving).x
	# Hands.
	for y: int in [21, 22]:
		for x: int in [2, 3, 15, 16]:
			g.px(x, y + d, Color.WHITE)
	if f % 2 == 0:
		g.px(1, 22 + d, Color(1, 1, 1, 0.5))
		g.px(17, 22 + d, Color(1, 1, 1, 0.5))
	# Prana-sensing lens over the near eye, and the collar clasp.
	g.px(12, 9 + d, Color.WHITE)
	g.px(9, 14 + d, Color(1, 1, 1, 0.7))


# ── Standard enemies ─────────────────────────────────────────────────────────
# Warped machines (§5.2): neutral body, one desaturated Prana marker.

## Drifter (Voidblue): wide low lantern-floater that sags and re-inflates.
func _drifter(p: PixelPainter, f: int, moving: bool) -> void:
	var sag: Array[int] = [0, 1, 1, 0]
	var s: int = sag[f]
	var hover: int = -1 if moving and f % 2 == 1 else 0
	var mk: Color = PixelPainter.marker(VOIDBLUE)
	p.ellipse(11.0, 16.5, 6.0, 1.2, Color(0, 0, 0, 0.0))  # keep the hover gap clear
	# Hanging tendrils.
	for x: int in [6, 11, 16]:
		p.line(x, 11 + hover, x + (1 if f % 2 == 0 else -1), 15 + hover, E3)
	# Body: wide flat dome, stained on one edge.
	p.ellipse(11.0, 8.0 + s + hover, 10.0, 4.5 - s * 0.5, METAL_WARM, true)
	p.ellipse(16.5, 8.5 + s + hover, 3.5, 3.0 - s * 0.3, mk, true)
	# Lantern window.
	p.rect(8, 7 + s + hover, 6, 2, mk.lightened(0.25))
	p.px(9 + f % 3, 7 + s + hover, mk.lightened(0.6))


## Charger (Deepfrost): tall faceted spike, still at rest, leans hard when moving.
func _charger(p: PixelPainter, f: int, moving: bool) -> void:
	var lean: int = ([1, 2, 3, 2] as Array[int])[f] if moving else 0
	var mk: Color = PixelPainter.marker(DEEPFROST)
	# Coiled legs.
	p.poly(PackedVector2Array([Vector2(3, 25), Vector2(5, 19), Vector2(7, 25)]), E3, true)
	p.poly(PackedVector2Array([Vector2(7, 25), Vector2(9, 19), Vector2(11, 25)]), E3.darkened(0.15), true)
	# Tower body leaning forward (to the right).
	p.poly(PackedVector2Array([
		Vector2(3, 20), Vector2(4 + lean, 6), Vector2(7 + lean, 0),
		Vector2(10 + lean, 7), Vector2(11, 20),
	]), METAL, true)
	# Head spike.
	p.poly(PackedVector2Array([Vector2(7 + lean, 2), Vector2(12 + lean, 5), Vector2(8 + lean, 7)]), METAL.lightened(0.1), true)
	# Prana-scarring cracks, brighter when charging.
	var crack: Color = mk.lightened(0.35) if moving else mk
	p.line(6 + lean / 2, 8, 8, 13, crack)
	p.line(8, 13, 6, 17, crack)
	p.px(10 + lean, 5, mk.lightened(0.5))


## Cluster (Stormgold): opaque core with desynchronised orbiters.
func _cluster(p: PixelPainter, f: int, moving: bool) -> void:
	var mk: Color = PixelPainter.marker(STORMGOLD)
	var pulse: float = 0.5 if f % 2 == 0 else 0.0
	p.ellipse(13.0, 13.0, 5.5 + pulse, 5.0 + pulse, METAL_WARM, true)
	p.ellipse(13.0, 13.0, 2.5, 2.0, mk, true)
	var spin: float = float(f) / FRAMES * TAU * (1.5 if moving else 1.0)
	for i: int in 4:
		var a: float = spin * (1.0 + i * 0.15) + i * TAU / 4.0
		var c := Vector2(13.0, 13.0) + Vector2(cos(a) * 10.0, sin(a) * 7.5)
		p.ellipse(c.x, c.y, 2.0, 2.0, E7 if i % 2 == 0 else mk.darkened(0.1), true)


## Weaver (Stormgold): a shuttle that trails a woven thread.
func _weaver(p: PixelPainter, f: int, moving: bool) -> void:
	var mk: Color = PixelPainter.marker(STORMGOLD)
	var bob: int = -1 if f % 2 == 1 else 0
	var wave: Array[int] = [0, 2, 0, -2]
	# Thread loops on both sides.
	for side: int in [-1, 1]:
		var cx: int = 10 + side * 7
		p.line(10, 10 + bob, cx, 8 + wave[f] * side + bob, mk)
		p.line(cx, 8 + wave[f] * side + bob, cx, 13 - wave[f] * side + bob, mk)
		p.line(cx, 13 - wave[f] * side + bob, 10, 11 + bob, mk)
	# Shuttle body (diamond).
	p.poly(PackedVector2Array([
		Vector2(10, 2 + bob), Vector2(15, 10 + bob), Vector2(10, 18 + bob), Vector2(5, 10 + bob),
	]), METAL, true)
	p.rect(9, 8 + bob, 2, 4, mk.lightened(0.2))
	if moving:
		p.px(10, 19, mk)


## Mortar (Voidblue): squat pot with an upward barrel that recoils.
func _mortar(p: PixelPainter, f: int, moving: bool) -> void:
	var mk: Color = PixelPainter.marker(VOIDBLUE)
	var recoil: int = ([0, 1, 0, 0] as Array[int])[f]
	var step: int = (f % 2) if moving else 0
	# Stubby feet.
	p.rect(3, 17 - step, 3, 3 + step, E3)
	p.rect(12, 16 + step, 3, 4 - step, E3.darkened(0.15))
	# Pot body.
	p.ellipse(9.0, 12.0 + recoil, 7.5, 5.5, STONE, true)
	p.rect(3, 11 + recoil, 13, 1, mk)
	# Barrel.
	p.rect(7, 2 + recoil * 2, 5, 7, METAL, )
	p.rect(7, 2 + recoil * 2, 5, 1, METAL.lightened(0.2))
	p.rect(8, 3 + recoil * 2, 3, 1, mk.darkened(0.3))


## Rifter (Verdant): split crystal with a living rift between the halves.
func _rifter(p: PixelPainter, f: int, moving: bool) -> void:
	var mk: Color = PixelPainter.marker(VERDANT)
	var gap: int = ([1, 2, 2, 1] as Array[int])[f]
	p.ox += 2
	var bob: int = -1 if moving and f % 2 == 1 else 0
	p.poly(PackedVector2Array([
		Vector2(7 - gap, 1 + bob), Vector2(7 - gap, 21 + bob), Vector2(1 - gap, 15 + bob), Vector2(2 - gap, 6 + bob),
	]).duplicate(), STONE.lightened(0.05), true)
	p.poly(PackedVector2Array([
		Vector2(9 + gap, 3 + bob), Vector2(15 + gap, 8 + bob), Vector2(14 + gap, 17 + bob), Vector2(9 + gap, 22 + bob),
	]), STONE.darkened(0.05), true)
	# Rift light.
	for y: int in range(4, 20):
		p.px(8, y + bob, mk.lightened(0.3) if (y + f) % 3 != 0 else mk)
	# Moss bleed on the left half.
	p.rect(2 - gap, 14 + bob, 3, 2, mk.darkened(0.2))
	p.ox -= 2


## Sniper (Deepfrost): tall tripod with a single long lens.
func _sniper(p: PixelPainter, f: int, moving: bool) -> void:
	var mk: Color = PixelPainter.marker(DEEPFROST)
	var step: int = (1 if f % 2 == 0 else -1) if moving else 0
	# Tripod legs.
	p.line(8, 14, 3 + step, 27, E3)
	p.line(8, 14, 13 - step, 27, E3)
	p.line(8, 14, 8, 27, E3.darkened(0.2))
	# Head housing.
	p.ellipse(8.0, 9.0, 5.0, 5.5, METAL, true)
	# Lens barrel pointing right, glint cycling.
	p.rect(10, 7, 6, 3, METAL.darkened(0.2))
	p.rect(14, 7, 2, 3, mk)
	p.px(14 + (f % 2), 7, mk.lightened(0.6))
	# Antenna (frost-scarred).
	p.line(6, 4, 5, 0, mk.darkened(0.2))


## Spinner (Ashfire): a top with blades; the blade marks rotate each frame.
func _spinner(p: PixelPainter, f: int, moving: bool) -> void:
	var mk: Color = PixelPainter.marker(ASHFIRE)
	# Spindle tip.
	p.poly(PackedVector2Array([Vector2(9, 12), Vector2(13, 12), Vector2(11, 17)]), E3, true)
	# Disc.
	p.ellipse(11.0, 9.0, 10.0, 4.0, METAL_WARM, true)
	var turns: int = f + (f if moving else 0)
	for i: int in 3:
		var a: float = float(turns) / FRAMES * TAU / 3.0 + i * TAU / 3.0
		var x: int = roundi(11.0 + cos(a) * 7.0)
		var y: int = roundi(9.0 + sin(a) * 2.5)
		p.rect(x - 1, y, 3, 1, mk)
	# Hub.
	p.ellipse(11.0, 7.0, 3.0, 2.0, STONE.lightened(0.1), true)
	p.px(11, 6, mk.lightened(0.5))


## Splitter (Verdant): round pod with a seam that bulges before it splits.
func _splitter(p: PixelPainter, f: int, moving: bool) -> void:
	var mk: Color = PixelPainter.marker(VERDANT)
	var bulge: float = ([0.0, 0.5, 1.0, 0.5] as Array[float])[f]
	var hop: int = -1 if moving and (f == 1 or f == 2) else 0
	p.ellipse(9.0, 10.0 + hop, 7.0 + bulge, 6.5 - bulge * 0.5, STONE.lightened(0.08), true)
	# Seam down the middle, glowing.
	for y: int in range(4, 16):
		p.px(9 + (1 if y % 4 == 0 else 0), y + hop, mk.lightened(0.2))
	# Sprouts on top (colour bleed).
	p.px(6, 3 + hop, mk)
	p.px(7, 2 + hop, mk)
	p.px(12, 3 + hop, mk.darkened(0.2))


# ── Bosses (48×48, scaled 2× in game) ───────────────────────────────────────

## Warped Warden: asymmetric guardian, heavy left side, broken-Prana spiral at centre
## in Corruption Violet (B1). Body breathes on one cycle, the mark pulses on another.
func _warden(p: PixelPainter, f: int, moving: bool) -> void:
	var breathe: int = ([0, 1, 1, 0] as Array[int])[f]
	var step: int = (f % 2) if moving else 0
	# Legs.
	p.rect(12, 38 - step, 7, 10 + step, E3)
	p.rect(29, 39 + step, 6, 9 - step, E3.darkened(0.2))
	# Heavy left shoulder mass.
	p.poly(PackedVector2Array([
		Vector2(2, 20 + breathe), Vector2(8, 8 + breathe), Vector2(18, 6 + breathe),
		Vector2(20, 30), Vector2(10, 40), Vector2(3, 34),
	]), STONE, true)
	# Main torso.
	p.poly(PackedVector2Array([
		Vector2(10, 12 + breathe), Vector2(24, 4 + breathe), Vector2(38, 10 + breathe),
		Vector2(42, 24), Vector2(36, 40), Vector2(14, 41),
	]), METAL_WARM, true)
	# Lighter right arm with arc remnants.
	p.poly(PackedVector2Array([
		Vector2(38, 14 + breathe), Vector2(45, 20 + breathe), Vector2(44, 32), Vector2(39, 30),
	]), METAL, true)
	p.ellipse(42.0, 34.0, 3.0, 3.0, METAL.lightened(0.1), true)
	# Head slit.
	p.rect(20, 9 + breathe, 10, 2, OUTLINE)
	p.rect(22, 9 + breathe, 3, 1, B1_VIOLET.lightened(0.3))
	# Broken-Prana spiral: pulses independently (offset cycle).
	var pulse: Color = B1_VIOLET.lightened(0.35) if f == 1 or f == 2 else B1_VIOLET
	var cx: int = 26
	var cy: int = 24
	var spiral: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(-1, 2),
		Vector2i(-2, 1), Vector2i(-2, 0), Vector2i(-2, -1), Vector2i(-1, -2), Vector2i(0, -3),
		Vector2i(1, -3), Vector2i(2, -2), Vector2i(3, -1), Vector2i(3, 1), Vector2i(3, 2),
	]
	for i: int in spiral.size():
		if i == 9:
			continue  # the break in the mark
		p.px(cx + spiral[i].x, cy + spiral[i].y, pulse)
	# Prana-scar cracks.
	p.line(14, 16, 18, 26, B1_VIOLET.darkened(0.25))
	p.line(34, 30, 38, 36, B1_VIOLET.darkened(0.25))


## Vault Sentinel: a walking vault door, round lock at the centre in reserved teal (B2).
func _sentinel(p: PixelPainter, f: int, moving: bool) -> void:
	var breathe: int = ([0, 0, 1, 1] as Array[int])[f]
	var step: int = (f % 2) if moving else 0
	p.rect(10, 38 - step, 8, 10 + step, E3)
	p.rect(30, 38 + step, 8, 10 - step, E3.darkened(0.2))
	# Slab body.
	p.poly(PackedVector2Array([
		Vector2(6, 8 + breathe), Vector2(42, 8 + breathe), Vector2(44, 40), Vector2(4, 40),
	]), STONE, true)
	# Rivet frame.
	for x: int in range(8, 42, 4):
		p.px(x, 10 + breathe, STONE.lightened(0.3))
		p.px(x, 38, STONE.darkened(0.3))
	# Lock ring, bolts rotating with the frame.
	p.ellipse(24.0, 24.0 + breathe, 10.0, 10.0, METAL, true)
	p.ellipse(24.0, 24.0 + breathe, 6.0, 6.0, METAL.darkened(0.3))
	for i: int in 4:
		var a: float = float(f) / FRAMES * TAU / 4.0 + i * TAU / 4.0
		p.rect(24 + roundi(cos(a) * 8.0), 24 + breathe + roundi(sin(a) * 8.0), 2, 2, B2_TEAL)
	p.ellipse(24.0, 24.0 + breathe, 3.0, 3.0, B2_TEAL.lightened(0.2) if f % 2 == 0 else B2_TEAL, true)
	# Crown ridge.
	p.poly(PackedVector2Array([Vector2(14, 8 + breathe), Vector2(24, 1 + breathe), Vector2(34, 8 + breathe)]), METAL_WARM, true)
