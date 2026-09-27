## generate_character_sprites.gd — builds every character sprite sheet (ADR-0022, ADR-0034).
##
## Run from the project root:
##   godot --headless --path . -s tools/art-gen/generate_character_sprites.gd
##
## Each sheet is FRAMES columns × ROWS rows: row 0 idle, row 1 moving, row 2 cast
## (Fayde) or attack wind-up (enemies). Every sheet pixel is one world pixel, bosses
## included, so all characters share Fayde's pixel size. Designs follow the art bible
## (§3.2 silhouettes, §4 palette, §5 character direction): warm or cool neutral bodies,
## a desaturated Prana "transformation marker" on enemies, one reserved colour per
## boss, and Fayde's hand/lens glow drawn on a separate white glow sheet so the game
## can tint it with the active Prana. Output goes to assets/art/characters/.
extends SceneTree

const PixelPainter = preload("res://tools/art-gen/pixel_painter.gd")

const OUT_DIR: String = "res://assets/art/characters/"
const FRAMES: int = 4
const ROWS: int = 3
const IDLE: int = 0
const MOVE: int = 1
const CAST: int = 2

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
const B3_ROSE := Color("#D42E5E")
# Cipher Keeper body neutrals (≤ 40 % saturation, art bible §5.2).
const KEEPER_ROBE := Color("#4E4152")
const KEEPER_BRONZE := Color("#8A7A5E")
const KEEPER_TRIM := Color("#AE9A70")
const KEEPER_VOID := Color("#1B1620")

# Prana colours (assets/data/prana_types).
const ASHFIRE := Color(0.949, 0.298, 0.114)
const VOIDBLUE := Color(0.290, 0.369, 0.961)
const STORMGOLD := Color(1.0, 0.8, 0.0)
const DEEPFROST := Color(0.239, 0.851, 0.941)
const VERDANT := Color(0.102, 0.788, 0.325)

## Standard-enemy wind-up row, per column: upper-body lean (px, + = forward), and how
## much the Prana marker brightens (the "agitated" read in art bible §5.3).
const _WINDUP_LEAN: Array[int] = [-1, 1, 1, 0]
const _WINDUP_GLOW: Array[float] = [0.2, 0.55, 0.45, 0.25]
## Pixels at or above this HSV saturation count as the Prana marker.
const _MARKER_SAT: float = 0.42


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_sheet("fayde", 20, 32, _fayde, _fayde_glow, true)
	_crumple_strip()
	_cast_styles_sheet()
	_sheet("drifter", 22, 18, _drifter)
	_sheet("charger", 14, 26, _charger)
	_sheet("cluster", 26, 24, _cluster)
	_sheet("weaver", 20, 20, _weaver)
	_sheet("mortar", 18, 20, _mortar)
	_sheet("rifter", 20, 24, _rifter)
	_sheet("sniper", 16, 28, _sniper)
	_sheet("spinner", 22, 18, _spinner)
	_sheet("splitter", 18, 18, _splitter)
	_sheet("vault_sentinel", 96, 96, _sentinel, Callable(), true)
	_sheet("warped_warden", 96, 96, _warden, Callable(), true)
	_sheet("cipher_keeper", 144, 144, _keeper, Callable(), true)
	print("sprites written to ", OUT_DIR)
	quit()


## Writes [param name].png. A [param posed] body takes (painter, column, row) and draws
## its own cast row; otherwise it takes (painter, column, moving) and the wind-up row
## is its idle pose leaned and agitated by _windup().
func _sheet(name: String, cw: int, ch: int, body: Callable, glow: Callable = Callable(), posed: bool = false) -> void:
	var img := Image.create(cw * FRAMES, ch * ROWS, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var p := PixelPainter.new(img, cw, ch)
	for row: int in ROWS:
		for f: int in FRAMES:
			p.cell(f, row)
			if posed:
				body.call(p, f, row)
			elif row == CAST:
				body.call(p, f, false)
				_windup(p, f)
			else:
				body.call(p, f, row == MOVE)
			p.outline(OUTLINE)
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + name + ".png"))
	if glow.is_valid():
		var gimg := Image.create(cw * FRAMES, ch * ROWS, false, Image.FORMAT_RGBA8)
		gimg.fill(Color(0, 0, 0, 0))
		var g := PixelPainter.new(gimg, cw, ch)
		for row: int in ROWS:
			for f: int in FRAMES:
				g.cell(f, row)
				glow.call(g, f, row)
		gimg.save_png(ProjectSettings.globalize_path(OUT_DIR + name + "_glow.png"))


## Turns an idle frame into a wind-up frame: the upper half leans (a stair-step shear,
## twice as far in the top quarter) and marker-coloured pixels brighten.
func _windup(p: PixelPainter, f: int) -> void:
	var src: Array[Color] = []
	for y: int in p.h:
		for x: int in p.w:
			src.append(p.get_px(x, y))
	p.rect(0, 0, p.w, p.h, Color(0, 0, 0, 0))
	var lean: int = _WINDUP_LEAN[f]
	for y: int in p.h:
		var dx: int = lean * 2 if y < p.h / 4 else (lean if y < p.h / 2 else 0)
		for x: int in p.w:
			var c: Color = src[y * p.w + x]
			if c.a <= 0.0:
				continue
			if c.s >= _MARKER_SAT:
				c = c.lightened(_WINDUP_GLOW[f])
			p.px(x + dx, y, c)
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




## Cast row, per column: upper-body lean back (px), extra hem sway, leg variant.
## Wind-up, release, hold, recover (art bible §5.3: "hands pull back, then arms
## extended, coat blown back 1 px").
const _FAYDE_CAST_LEAN: Array[int] = [-1, -1, -1, 0]
const _FAYDE_CAST_HEM: Array[int] = [0, -1, -1, 0]
const _FAYDE_CAST_LEGS: Array[int] = [0, 1, 1, 0]


func _fayde(p: PixelPainter, f: int, row: int) -> void:
	if row == CAST:
		_fayde_cast(p, f)
		return
	var pose: Vector3i = _fayde_pose(f, row == MOVE)
	var legs: Array = _FAYDE_LEGS[pose.y]
	for r: int in legs.size():
		_ascii_row(p, legs[r], 27 + r, 0)
	for r: int in _FAYDE_UPPER.size():
		var shift: int = pose.z if r >= 24 else 0
		_ascii_row(p, _FAYDE_UPPER[r], r + pose.x, shift)


func _fayde_cast(p: PixelPainter, f: int) -> void:
	var lean: int = _FAYDE_CAST_LEAN[f]
	var legs: Array = _FAYDE_LEGS[_FAYDE_CAST_LEGS[f]]
	for r: int in legs.size():
		_ascii_row(p, legs[r], 27 + r, 0)
	for r: int in _FAYDE_UPPER.size():
		var shift: int = lean + (_FAYDE_CAST_HEM[f] if r >= 24 else 0)
		# The hanging hands (rows 21–22) are redrawn where the pose puts them.
		_ascii_row(p, _FAYDE_UPPER[r], r, shift, r == 21 or r == 22)
	var sleeve: Color = _FAYDE_COLOURS["C"]
	var fold: Color = _FAYDE_COLOURS["c"]
	if f == 1 or f == 2:
		# Front sleeve leaves the body: clear it, then draw the arm reaching forward.
		for y: int in range(18, 23):
			for x: int in [15 + lean, 16 + lean]:
				p.px(x, y, Color(0, 0, 0, 0))
		var arm: Array[Vector2i] = [Vector2i(13, 16), Vector2i(14, 16), Vector2i(15, 16), Vector2i(16, 16)]
		if f == 2:
			arm = [Vector2i(13, 16), Vector2i(14, 15), Vector2i(15, 14), Vector2i(16, 13)]
		for a: Vector2i in arm:
			p.px(a.x, a.y, sleeve)
			p.px(a.x, a.y + 1, fold)
	for h: Vector2i in _fayde_cast_hands(f):
		p.rect(h.x, h.y, 2, 2, SKIN)
		p.px(h.x + 1, h.y + 1, _FAYDE_COLOURS["s"])


## Top-left corner of each 2×2 hand in cast column [param f] (front hand first).
func _fayde_cast_hands(f: int) -> Array[Vector2i]:
	match f:
		0:
			return [Vector2i(12, 18), Vector2i(1, 19)]
		1:
			return [Vector2i(17, 16), Vector2i(15, 19)]
		2:
			return [Vector2i(17, 12), Vector2i(16, 17)]
	return [Vector2i(15, 20), Vector2i(2, 21)]


func _ascii_row(p: PixelPainter, row: String, y: int, dx: int, skip_skin: bool = false) -> void:
	for x: int in row.length():
		var k: String = row[x]
		if skip_skin and k == "S":
			continue
		if _FAYDE_COLOURS.has(k):
			p.px(x + dx, y, _FAYDE_COLOURS[k])


func _fayde_glow(g: PixelPainter, f: int, row: int) -> void:
	if row == CAST:
		var lean: int = _FAYDE_CAST_LEAN[f]
		var hands: Array[Vector2i] = _fayde_cast_hands(f)
		for h: Vector2i in hands:
			g.rect(h.x, h.y, 2, 2, Color.WHITE)
		if f == 1 or f == 2:
			# Release: a soft halo round the reaching hand.
			var front: Vector2i = hands[0]
			for d: Vector2i in [Vector2i(-1, 0), Vector2i(2, 0), Vector2i(0, -1), Vector2i(1, -1), Vector2i(0, 2), Vector2i(1, 2)]:
				g.px(front.x + d.x, front.y + d.y, Color(1, 1, 1, 0.5))
		g.px(12 + lean, 9, Color.WHITE)
		g.px(9 + lean, 14, Color.WHITE if f == 1 else Color(1, 1, 1, 0.7))
		return
	var d: int = _fayde_pose(f, row == MOVE).x
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


# ── Fayde cast styles (ADR-0056) ────────────────────────────────────────────
# One row per Prana cast style (GameEnums.CastAnimation), in enum order: Ashfire
# fire dance, Voidblue reach-and-pull, Stormgold snap, Deepfrost horse-stance push,
# Verdant bloom. Same 20×32 cell and feet-on-origin as the main sheet, written to
# fayde_casts.png (+ _glow). Four columns: wind-up, release, follow-through, recover.

const CAST_STYLES: int = 5
## Sleeve colours for an arm drawn over the coat (lit core, dark edge).
const _SLEEVE_LIT := Color("#B89C7A")
const _SLEEVE_EDGE := Color("#4E3E30")
const STYLE_ASHFIRE: int = 0
const STYLE_VOIDBLUE: int = 1
const STYLE_STORMGOLD: int = 2
const STYLE_DEEPFROST: int = 3
const STYLE_VERDANT: int = 4

## Extra stances for the styles, rows 27–31. 3 wide horse stance, 4 front-leg kick,
## 5 deep lunge.
const _STYLE_LEGS: Array = [
	["....cPPP..PPPc......", "...PPP......PPP.....", "..PPP........PPP....", "..KKK.........KKK...", ".KKKK.........KKKK.."],
	["....ccPP..PPPPPPPPKK", "......PP....PPPPPPKK", "......PP............", ".....KKK............", ".....KKK............"],
	["....cPP....PPc......", "...PP.......PP......", "..PP.........PP.....", ".KK..........KKK....", "KK...........KKK...."],
]

## Per style, per column: [lean px, body drop px, legs, front hand, back hand, mirror].
## Legs index _FAYDE_LEGS (0–2) or _STYLE_LEGS (3–5). Hands are the top-left of a 2×2
## hand in cell pixels. Mirror draws the frame turned away (the Ashfire spin).
const _STYLE_POSES: Array = [
	[ # Ashfire: chamber low, palm strike from a lunge, spin, sweeping kick.
		[-1, 1, 3, Vector2i(11, 20), Vector2i(0, 15), false],
		[1, 1, 5, Vector2i(18, 14), Vector2i(5, 20), false],
		[0, 0, 0, Vector2i(18, 15), Vector2i(0, 15), true],
		[-1, 0, 4, Vector2i(16, 9), Vector2i(1, 11), false],
	],
	[ # Voidblue: reach low, claw out, pull the shadow back to the chest.
		[1, 0, 1, Vector2i(18, 19), Vector2i(3, 21), false],
		[1, 0, 1, Vector2i(18, 16), Vector2i(1, 17), false],
		[-1, 0, 2, Vector2i(13, 17), Vector2i(0, 18), false],
		[0, 0, 0, Vector2i(14, 19), Vector2i(2, 20), false],
	],
	[ # Stormgold: cock the hand by the ear, snap two fingers forward, hold, drop.
		[-1, 0, 0, Vector2i(12, 7), Vector2i(2, 20), false],
		[1, 0, 1, Vector2i(18, 11), Vector2i(1, 17), false],
		[1, 0, 1, Vector2i(18, 11), Vector2i(1, 17), false],
		[0, 0, 0, Vector2i(15, 17), Vector2i(2, 20), false],
	],
	[ # Deepfrost: sink into a horse stance, palms at the chest, push, hold, rise.
		[-1, 2, 3, Vector2i(12, 17), Vector2i(10, 18), false],
		[0, 2, 3, Vector2i(17, 16), Vector2i(16, 19), false],
		[0, 2, 3, Vector2i(18, 16), Vector2i(17, 19), false],
		[0, 1, 3, Vector2i(15, 18), Vector2i(3, 20), false],
	],
	[ # Verdant: cupped hands low, raised to the chin, opened wide like a flower.
		[0, 1, 0, Vector2i(11, 20), Vector2i(9, 20), false],
		[0, 0, 0, Vector2i(11, 14), Vector2i(8, 14), false],
		[0, 0, 0, Vector2i(17, 8), Vector2i(0, 8), false],
		[0, 0, 0, Vector2i(18, 11), Vector2i(0, 11), false],
	],
]


func _cast_styles_sheet() -> void:
	var cw: int = 20
	var ch: int = 32
	var img := Image.create(cw * FRAMES, ch * CAST_STYLES, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var p := PixelPainter.new(img, cw, ch)
	var gimg := Image.create(cw * FRAMES, ch * CAST_STYLES, false, Image.FORMAT_RGBA8)
	gimg.fill(Color(0, 0, 0, 0))
	var g := PixelPainter.new(gimg, cw, ch)
	for style: int in CAST_STYLES:
		for f: int in FRAMES:
			var pose: Array = _STYLE_POSES[style][f]
			p.cell(f, style)
			g.cell(f, style)
			_fayde_styled(p, pose)
			_fayde_styled_glow(g, style, f, pose)
			if pose[5]:
				_mirror_cell(p, cw, ch)
				_mirror_cell(g, cw, ch)
			p.outline(OUTLINE)
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + "fayde_casts.png"))
	gimg.save_png(ProjectSettings.globalize_path(OUT_DIR + "fayde_casts_glow.png"))


func _fayde_styled(p: PixelPainter, pose: Array) -> void:
	var lean: int = pose[0]
	var drop: int = pose[1]
	var li: int = pose[2]
	var legs: Array = _FAYDE_LEGS[li] if li < 3 else _STYLE_LEGS[li - 3]
	for r: int in legs.size():
		_ascii_row(p, legs[r], 27 + r, 0)
	for r: int in _FAYDE_UPPER.size():
		if r + drop >= 27 and li != 4:
			break # the crouch tucks the coat hem behind the bent legs
		_ascii_row(p, _FAYDE_UPPER[r], r + drop, lean, r == 21 or r == 22)
	# Both sleeves leave the body: clear them, then draw each arm to its hand.
	for y: int in range(17 + drop, 23 + drop):
		for x: int in [2, 3, 4, 14, 15, 16]:
			p.px(x + lean, y, Color(0, 0, 0, 0))
	var back: Vector2i = pose[4]
	var front: Vector2i = pose[3]
	_style_arm(p, Vector2i(4 + lean, 16 + drop), back)
	_style_arm(p, Vector2i(14 + lean, 16 + drop), front)


## A 2 px sleeve from [param shoulder] to the hand whose top-left is [param hand].
func _style_arm(p: PixelPainter, shoulder: Vector2i, hand: Vector2i) -> void:
	var tip: Vector2i = hand + Vector2i(0 if hand.x >= shoulder.x else 1, 0)
	# Dark edge above and below, lit core: the arm reads even across the coat.
	p.line(shoulder.x, shoulder.y - 1, tip.x, tip.y - 1, _SLEEVE_EDGE)
	p.line(shoulder.x, shoulder.y + 1, tip.x, tip.y + 1, _SLEEVE_EDGE)
	p.line(shoulder.x, shoulder.y, tip.x, tip.y, _SLEEVE_LIT)
	p.rect(hand.x, hand.y, 2, 2, SKIN)
	p.px(hand.x + 1, hand.y + 1, _FAYDE_COLOURS["s"])


## Glow: both hands, the lens and clasp, and one small element mark per style on the
## release and follow-through columns, tinted in game with the cast's Prana colour.
func _fayde_styled_glow(g: PixelPainter, style: int, f: int, pose: Array) -> void:
	var lean: int = pose[0]
	var drop: int = pose[1]
	var front: Vector2i = pose[3]
	var back: Vector2i = pose[4]
	for h: Vector2i in [front, back]:
		g.rect(h.x, h.y, 2, 2, Color.WHITE)
	g.px(12 + lean, 9 + drop, Color.WHITE)
	g.px(9 + lean, 14 + drop, Color(1, 1, 1, 0.7))
	var soft := Color(1, 1, 1, 0.55)
	match style:
		STYLE_ASHFIRE:
			if f == 1: # flame licking off the striking palm
				for d: Vector2i in [Vector2i(0, -1), Vector2i(1, -2), Vector2i(-1, -1), Vector2i(-2, 0)]:
					g.px(front.x + d.x, front.y + d.y, soft)
			elif f == 2: # ring of fire round the spin
				for x: int in range(2, 18):
					g.px(x, 26 if (x % 3) != 0 else 25, soft)
			elif f == 3: # arc trailing the kicking foot
				for d: Vector2i in [Vector2i(17, 25), Vector2i(15, 24), Vector2i(13, 24), Vector2i(19, 26)]:
					g.px(d.x, d.y, soft)
		STYLE_VOIDBLUE:
			if f == 1: # threads reaching out from the claw
				g.px(front.x + 1, front.y - 2, soft)
				g.px(front.x - 1, front.y + 3, soft)
			elif f == 2: # the shadow reeled in along the pull
				for x: int in range(front.x + 2, 20, 2):
					g.px(x, front.y + 1, soft)
		STYLE_STORMGOLD:
			if f == 1 or f == 2: # spark jumping off the fingertips
				var zig: Array[Vector2i] = [Vector2i(0, -2), Vector2i(-1, -3), Vector2i(0, -4), Vector2i(-1, -5)]
				for d: Vector2i in zig:
					g.px(front.x + 1 + d.x, front.y + d.y, Color.WHITE if f == 1 else soft)
		STYLE_DEEPFROST:
			if f == 1 or f == 2: # frost shards between the pushing palms
				for d: Vector2i in [Vector2i(1, 2), Vector2i(0, 3), Vector2i(1, -1)]:
					g.px(front.x + d.x, front.y + d.y, soft)
			if f == 0: # breath held in the stance
				g.px(14 + lean, 11 + drop, soft)
		STYLE_VERDANT:
			if f >= 2: # petals drifting up between the open arms
				for d: Vector2i in [Vector2i(6, 6), Vector2i(9, 4), Vector2i(12, 6), Vector2i(9, 2)]:
					g.px(d.x, d.y + (f - 2), soft)


## Flips the current cell left-to-right in place.
func _mirror_cell(p: PixelPainter, cw: int, ch: int) -> void:
	for y: int in ch:
		for x: int in cw / 2:
			var a: Color = p.get_px(x, y)
			var b: Color = p.get_px(cw - 1 - x, y)
			p.px(x, y, b)
			p.px(cw - 1 - x, y, a)


# ── Fayde crumple (ADR-0042) ────────────────────────────────────────────────
# Art bible §5.3 defeat stage 1: "knees bent, arms loose, head down. Reads as
# exhausted, not dead." One row of CRUMPLE_FRAMES columns, same 20×32 cell and
# feet-on-origin as the main sheet, written to fayde_crumple.png (+ _glow).

const CRUMPLE_FRAMES: int = 4
## Per column: whole-body drop (px), extra head drop, head lean forward.
const _CRUMPLE_DROP: Array[int] = [1, 3, 5, 6]
const _CRUMPLE_HEAD_DROP: Array[int] = [0, 1, 1, 2]
const _CRUMPLE_HEAD_LEAN: Array[int] = [0, 1, 1, 1]
## Legs as the knees give: standing, bent outward, kneeling.
const _CRUMPLE_LEGS: Array = [
	["....ccPP..PPcc......", "......PP..PP........", "......PP..PP........", ".....KKK..KKK.......", ".....KKK..KKK......."],
	["....cPPP..PPPc......", "....PPP....PPP......", "....PP......PP......", "....KKK....KKK......"],
	["...PPPP....PPPP.....", "...KKKK....KKKK....."],
]


func _crumple_legs(f: int) -> Array:
	var d: int = _CRUMPLE_DROP[f]
	return _CRUMPLE_LEGS[0 if d <= 1 else (1 if d <= 3 else 2)]


func _crumple_strip() -> void:
	var cw: int = 20
	var ch: int = 32
	var img := Image.create(cw * CRUMPLE_FRAMES, ch, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var p := PixelPainter.new(img, cw, ch)
	var gimg := Image.create(cw * CRUMPLE_FRAMES, ch, false, Image.FORMAT_RGBA8)
	gimg.fill(Color(0, 0, 0, 0))
	var g := PixelPainter.new(gimg, cw, ch)
	for f: int in CRUMPLE_FRAMES:
		p.cell(f, 0)
		g.cell(f, 0)
		_fayde_crumple(p, f)
		p.outline(OUTLINE)
		_fayde_crumple_glow(g, f)
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + "fayde_crumple.png"))
	gimg.save_png(ProjectSettings.globalize_path(OUT_DIR + "fayde_crumple_glow.png"))


func _fayde_crumple(p: PixelPainter, f: int) -> void:
	var d: int = _CRUMPLE_DROP[f]
	var legs: Array = _crumple_legs(f)
	for r: int in legs.size():
		_ascii_row(p, legs[r], ch_bottom(legs.size()) + r, 0)
	# Torso first, then the head over it, so the dipped head sits in front of the collar.
	for r: int in range(14, _FAYDE_UPPER.size()):
		_ascii_row(p, _FAYDE_UPPER[r], r + d, 0)
	for r: int in range(0, 14):
		var row: String = _FAYDE_UPPER[r]
		if f >= 2:
			# Head down: the fringe falls over the brow and the eyes close.
			if r == 7:
				row = row.replace("S", "H")
			elif r == 9:
				row = row.replace("E", "s")
		_ascii_row(p, row, r + d + _CRUMPLE_HEAD_DROP[f], _CRUMPLE_HEAD_LEAN[f])


## First row of a leg block [param rows] tall that ends on the cell's last row.
func ch_bottom(rows: int) -> int:
	return 32 - rows


func _fayde_crumple_glow(g: PixelPainter, f: int) -> void:
	var d: int = _CRUMPLE_DROP[f]
	# Hands still hold the last Prana, fading as Fayde sinks.
	var a: float = 1.0 - 0.15 * float(f)
	for y: int in [21, 22]:
		for x: int in [2, 3, 15, 16]:
			g.px(x, y + d, Color(1, 1, 1, a))
	g.px(12 + _CRUMPLE_HEAD_LEAN[f], 9 + d + _CRUMPLE_HEAD_DROP[f], Color(1, 1, 1, a * 0.7))


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




# ── Bosses (native resolution, one sheet pixel = one world pixel) ───────────
# Each boss has one reserved colour outside the Prana hues (art bible §4.3):
# Sentinel B2 teal, Warden B1 violet, Keeper B3 rose. The cast row is the attack
# wind-up: crouch, release, hold, recover.

## Thick shaded limb from [param a] to [param b], [param width] px across.
func _limb(p: PixelPainter, a: Vector2, b: Vector2, width: float, c: Color) -> void:
	var n: Vector2 = (b - a).normalized().orthogonal() * width * 0.5
	p.poly(PackedVector2Array([a + n, b + n, b - n, a - n]), c, true)


## Riveted metal block with a lit top row and a dark bottom row.
func _plate(p: PixelPainter, x: int, y: int, w: int, h: int, c: Color) -> void:
	p.rect(x, y, w, h, c)
	p.rect(x, y, w, 1, c.lightened(0.25))
	p.rect(x, y + h - 1, w, 1, c.darkened(0.3))
	p.px(x + 1, y + h / 2, c.darkened(0.45))
	p.px(x + w - 2, y + h / 2, c.darkened(0.45))


## Vault Sentinel (96×96): a walking vault door. Hinges down the left edge, a round
## lock in reserved teal (B2) whose bolts turn, and a crown ridge with a keystone.
## Wind-up: it crouches, the door seam splits with light and the bolts spin out.
func _sentinel(p: PixelPainter, f: int, row: int) -> void:
	var moving: bool = row == MOVE
	var casting: bool = row == CAST
	var b: int = ([0, 0, 1, 1] as Array[int])[f]
	if casting:
		b = ([3, -2, -2, 1] as Array[int])[f]
	var lift_l: int = 3 if moving and f % 2 == 0 else 0
	var lift_r: int = 3 if moving and f % 2 == 1 else 0
	var teal: Color = B2_TEAL.lightened(0.45) if casting and (f == 1 or f == 2) else B2_TEAL
	# Legs: thick pillars with wide foot plates.
	for leg: Vector2i in [Vector2i(22, lift_l), Vector2i(58, lift_r)]:
		var shade: Color = E3 if leg.x < 48 else E3.darkened(0.18)
		p.poly(PackedVector2Array([
			Vector2(leg.x, 72), Vector2(leg.x + 16, 72), Vector2(leg.x + 15, 90 - leg.y), Vector2(leg.x + 1, 90 - leg.y),
		]), shade, true)
		_plate(p, leg.x - 3, 89 - leg.y, 22, 6, shade.darkened(0.15))
	# Slab body.
	p.poly(PackedVector2Array([
		Vector2(12, 16 + b), Vector2(84, 16 + b), Vector2(88, 80 + b), Vector2(8, 80 + b),
	]), STONE, true)
	p.poly(PackedVector2Array([
		Vector2(18, 23 + b), Vector2(78, 23 + b), Vector2(81, 74 + b), Vector2(15, 74 + b),
	]), STONE.darkened(0.1))
	# Door-plate seams and rivet rows.
	p.line(17, 48 + b, 26, 48 + b, STONE.darkened(0.35))
	p.line(70, 48 + b, 80, 48 + b, STONE.darkened(0.35))
	for x: int in range(16, 82, 8):
		p.rect(x, 19 + b, 2, 1, STONE.lightened(0.35))
		p.rect(x, 77 + b, 2, 1, STONE.darkened(0.35))
	for y: int in range(28, 74, 9):
		p.px(80, y + b, STONE.lightened(0.2))
	# The door seam splits with teal light on release.
	if casting and (f == 1 or f == 2):
		p.rect(47, 23 + b, 2, 52, teal)
	# Hinges.
	for y: int in [26, 44, 62]:
		_plate(p, 3, y + b, 9, 8, METAL)
	# Prana-scar cracks (the transformation marker), brighter while winding up.
	var scar: Color = teal.darkened(0.25) if casting else B2_TEAL.darkened(0.35)
	p.line(26, 30 + b, 32, 37 + b, scar)
	p.line(32, 37 + b, 29, 43 + b, scar)
	p.line(66, 62 + b, 72, 70 + b, scar)
	p.line(72, 70 + b, 76, 69 + b, scar)
	# Lock: outer ring, recessed face, dial ticks, turning bolts, lit hub, keyhole.
	var cy: int = 48 + b
	p.ellipse(48.0, cy, 22.0, 22.0, METAL, true)
	p.ellipse(48.0, cy, 17.0, 17.0, METAL.darkened(0.35))
	for i: int in 16:
		var a: float = i * TAU / 16.0
		p.px(48 + roundi(cos(a) * 19.5), cy + roundi(sin(a) * 19.5), METAL.lightened(0.3))
	var spin: float = 1.0
	if moving:
		spin = 2.0
	elif casting:
		spin = 4.0
	var bolt_r: float = 17.0 if casting and (f == 1 or f == 2) else 13.0
	for i: int in 4:
		var a: float = float(f) / FRAMES * TAU / 4.0 * spin + i * TAU / 4.0
		p.rect(47 + roundi(cos(a) * bolt_r), cy - 1 + roundi(sin(a) * bolt_r), 3, 3, teal)
	p.ellipse(48.0, cy, 7.0, 7.0, METAL.lightened(0.1), true)
	var hub: Color = teal.lightened(0.2) if f % 2 == 0 or casting else teal
	p.ellipse(48.0, cy, 4.0, 4.0, hub, true)
	p.rect(47, cy - 2, 2, 2, OUTLINE)
	p.rect(47, cy, 2, 3, OUTLINE)
	# Crown ridge with a teal keystone.
	p.poly(PackedVector2Array([Vector2(28, 17 + b), Vector2(48, 2 + b), Vector2(68, 17 + b)]), METAL_WARM, true)
	p.line(29, 16 + b, 47, 3 + b, METAL_WARM.lightened(0.3))
	p.rect(46, 8 + b, 5, 5, teal)
	p.px(47, 9 + b, teal.lightened(0.5))


## Warped Warden (96×96): an ancient asymmetric guardian, heavy stone left side,
## lighter metal right arm, broken-Prana spiral in Corruption Violet (B1) at the centre.
## The body breathes on one cycle and the mark pulses on another (internal conflict).
## Wind-up: the right arm drops back, then heaves up crackling with violet arcs.
func _warden(p: PixelPainter, f: int, row: int) -> void:
	var moving: bool = row == MOVE
	var casting: bool = row == CAST
	var b: int = ([0, 1, 2, 1] as Array[int])[f]
	if casting:
		b = ([2, -1, -1, 1] as Array[int])[f]
	var lift_l: int = 3 if moving and f % 2 == 0 else 0
	var lift_r: int = 3 if moving and f % 2 == 1 else 0
	var hot: bool = casting and (f == 1 or f == 2)
	# Legs.
	p.poly(PackedVector2Array([
		Vector2(24, 74), Vector2(40, 74), Vector2(39, 91 - lift_l), Vector2(25, 91 - lift_l),
	]), E3, true)
	_plate(p, 21, 90 - lift_l, 21, 5, E3.darkened(0.15))
	p.poly(PackedVector2Array([
		Vector2(58, 78), Vector2(70, 78), Vector2(69, 91 - lift_r), Vector2(59, 91 - lift_r),
	]), E3.darkened(0.2), true)
	_plate(p, 56, 90 - lift_r, 17, 5, E3.darkened(0.3))
	# Heavy left shoulder mass, flecked stone.
	p.poly(PackedVector2Array([
		Vector2(4, 40 + b), Vector2(16, 16 + b), Vector2(36, 12 + b),
		Vector2(40, 60), Vector2(20, 80), Vector2(6, 68),
	]), STONE, true)
	for fl: Vector2i in [Vector2i(12, 30), Vector2i(20, 44), Vector2i(27, 24), Vector2i(13, 58), Vector2i(30, 52)]:
		p.px(fl.x, fl.y + b, STONE.darkened(0.3))
		p.px(fl.x + 1, fl.y + b - 1, STONE.lightened(0.2))
	# Main torso with a plate seam.
	p.poly(PackedVector2Array([
		Vector2(20, 24 + b), Vector2(48, 8 + b), Vector2(76, 20 + b),
		Vector2(84, 48), Vector2(72, 80), Vector2(28, 82),
	]), METAL_WARM, true)
	p.line(30, 66, 70, 62, METAL_WARM.darkened(0.3))
	for x: int in range(34, 70, 7):
		p.px(x, 63 + (70 - x) / 10, METAL_WARM.lightened(0.3))
	# Right arm: shoulder to fist; the fist moves with the wind-up.
	var fist := Vector2(84, 68)
	if casting:
		fist = ([Vector2(78, 76), Vector2(86, 18), Vector2(87, 14), Vector2(86, 48)] as Array[Vector2])[f]
		fist.y += b
	elif moving:
		fist.y += float(([0, -2, 0, 2] as Array[int])[f])
	var shoulder := Vector2(80, 30 + b)
	_limb(p, shoulder, fist, 11.0, METAL)
	p.ellipse(fist.x, fist.y, 6.5, 6.5, METAL.lightened(0.1), true)
	p.ellipse(shoulder.x, shoulder.y, 6.0, 6.0, METAL.darkened(0.1), true)
	# Arc remnants along the arm; live violet arcs on release.
	var mid: Vector2 = shoulder.lerp(fist, 0.5)
	p.px(roundi(mid.x) - 2, roundi(mid.y), METAL.lightened(0.35))
	p.px(roundi(mid.x) + 1, roundi(mid.y) + 3, METAL.lightened(0.35))
	if hot:
		var arc: Color = B1_VIOLET.lightened(0.4)
		for i: int in 6:
			var a: float = i * TAU / 6.0 + f
			var r: float = 9.0 + (i % 2) * 2.0
			p.px(roundi(fist.x + cos(a) * r), roundi(fist.y + sin(a) * r), arc)
		p.line(roundi(fist.x) - 3, roundi(fist.y) - 8, roundi(fist.x) + 2, roundi(fist.y) - 12, arc)
	# Head slit with one violet eye (the whole slit burns on release).
	p.rect(40, 18 + b, 20, 4, OUTLINE)
	p.rect(44, 19 + b, 6, 2, B1_VIOLET.lightened(0.3))
	if hot:
		p.rect(41, 19 + b, 18, 2, B1_VIOLET.lightened(0.5))
	# Orbiting shard off the broken left edge (fragmentation marker).
	var sh := Vector2i(([6, 8, 10, 8] as Array[int])[f], ([10, 8, 10, 12] as Array[int])[f] + b)
	p.poly(PackedVector2Array([Vector2(sh.x, sh.y), Vector2(sh.x + 5, sh.y - 3), Vector2(sh.x + 4, sh.y + 3)]), STONE.lightened(0.1), true)
	# Broken-Prana spiral: pulses on its own cycle, 2×2 pixel steps.
	var pulse: Color = B1_VIOLET.lightened(0.35) if f == 1 or f == 2 else B1_VIOLET
	if casting:
		pulse = B1_VIOLET.lightened(0.55) if hot else B1_VIOLET.lightened(0.2)
	var spiral: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(-1, 2),
		Vector2i(-2, 1), Vector2i(-2, 0), Vector2i(-2, -1), Vector2i(-1, -2), Vector2i(0, -3),
		Vector2i(1, -3), Vector2i(2, -2), Vector2i(3, -1), Vector2i(3, 1), Vector2i(3, 2),
	]
	for i: int in spiral.size():
		if i == 9:
			continue  # the break in the mark
		p.rect(52 + spiral[i].x * 2, 46 + b + spiral[i].y * 2, 2, 2, pulse)
	# Prana-scar cracks.
	var crack: Color = B1_VIOLET.lightened(0.2) if hot else B1_VIOLET.darkened(0.25)
	p.line(28, 32 + b, 36, 52 + b, crack)
	p.line(29, 32 + b, 37, 52 + b, crack)
	p.line(64, 58, 72, 70, crack)


## Cipher Keeper (144×144): the vault's last guardian. A hooded monolith that hovers,
## a turning cipher wheel behind its hood, one rose (B3) eye in the dark of the hood,
## and two detached gauntlets. Its hood echoes Fayde's: the keeper of the cipher
## he is carrying. Wind-up: gauntlets pull in to the chest, then rise and flare.
func _keeper(p: PixelPainter, f: int, row: int) -> void:
	var moving: bool = row == MOVE
	var casting: bool = row == CAST
	var hot: bool = casting and (f == 1 or f == 2)
	var b: int = ([0, -1, -2, -1] as Array[int])[f]
	if moving:
		b = ([0, -2, 0, -2] as Array[int])[f]
	elif casting:
		b = ([2, -3, -4, 0] as Array[int])[f]
	var rose: Color = B3_ROSE.lightened(0.4) if hot else B3_ROSE
	# Cipher wheel behind the hood: a ring of glyph notches, one notch per 4 frames.
	var wcy: int = 48 + b
	p.ellipse(72.0, wcy, 43.0, 43.0, KEEPER_BRONZE.darkened(0.25), true)
	p.ellipse(72.0, wcy, 37.0, 37.0, Color(0, 0, 0, 0))
	for i: int in 12:
		var a: float = (float(f) / FRAMES + i) * TAU / 12.0
		var gx: int = 72 + roundi(cos(a) * 40.0)
		var gy: int = wcy + roundi(sin(a) * 40.0)
		var lit: bool = casting or i % 3 == 0
		p.rect(gx - 1, gy - 1, 3, 3, rose if lit else KEEPER_TRIM)
	# Robe / monolith body.
	p.poly(PackedVector2Array([
		Vector2(72, 12 + b), Vector2(92, 30 + b), Vector2(100, 70 + b), Vector2(98, 104 + b),
		Vector2(86, 124 + b), Vector2(72, 130 + b), Vector2(58, 124 + b), Vector2(46, 104 + b),
		Vector2(44, 70 + b), Vector2(52, 30 + b),
	]), KEEPER_ROBE, true)
	p.line(52, 30 + b, 72, 12 + b, KEEPER_TRIM)
	p.line(72, 12 + b, 92, 30 + b, KEEPER_TRIM.darkened(0.2))
	# Hood opening and the rose eye.
	p.ellipse(72.0, 42.0 + b, 13.0, 15.0, KEEPER_VOID)
	# The eye is a lens ring, wider on release.
	var eye: float = 5.5 if hot else 4.5
	p.ellipse(72.0, 40.0 + b, eye, eye, rose)
	p.ellipse(72.0, 40.0 + b, eye - 2.0, eye - 2.0, KEEPER_VOID)
	p.rect(71, 39 + b, 2, 2, rose.lightened(0.5))
	# Mantle with rivets, chest cipher plate with a rose gem.
	p.poly(PackedVector2Array([
		Vector2(50, 58 + b), Vector2(94, 58 + b), Vector2(101, 71 + b), Vector2(43, 71 + b),
	]), KEEPER_BRONZE, true)
	for x: int in range(50, 96, 6):
		p.px(x, 60 + b, KEEPER_BRONZE.lightened(0.3))
	p.poly(PackedVector2Array([
		Vector2(72, 66 + b), Vector2(83, 79 + b), Vector2(72, 92 + b), Vector2(61, 79 + b),
	]), KEEPER_TRIM, true)
	p.ellipse(72.0, 79.0 + b, 3.5, 3.5, rose, true)
	# Chevron trim bands and the centre seam.
	for y: int in [96, 110]:
		p.line(50, y + b, 72, y + 8 + b, KEEPER_TRIM)
		p.line(72, y + 8 + b, 94, y + b, KEEPER_TRIM.darkened(0.2))
	p.line(72, 93 + b, 72, 128 + b, KEEPER_ROBE.darkened(0.35))
	# Broken hem: shards drifting under the body (fragmentation marker).
	var s: int = -b / 2
	for sh: Vector2i in [Vector2i(60, 133), Vector2i(72, 137), Vector2i(84, 132)]:
		p.poly(PackedVector2Array([
			Vector2(sh.x - 3, sh.y + s), Vector2(sh.x + 3, sh.y + s), Vector2(sh.x, sh.y + 5 + s),
		]), KEEPER_ROBE.lightened(0.1), true)
	# Gauntlets.
	var hands: Array[Vector2] = [Vector2(26, 84 - b), Vector2(118, 80 + b)]
	if moving:
		hands = [Vector2(30, 88 + b), Vector2(114, 84 + b)]
	elif casting:
		var poses: Array[Vector4] = [
			Vector4(48, 76, 96, 76), Vector4(20, 52, 124, 48),
			Vector4(18, 46, 126, 42), Vector4(24, 70, 120, 66),
		]
		hands = [Vector2(poses[f].x, poses[f].y), Vector2(poses[f].z, poses[f].w)]
	for h: Vector2 in hands:
		_keeper_gauntlet(p, h, rose, hot)


func _keeper_gauntlet(p: PixelPainter, at: Vector2, rose: Color, hot: bool) -> void:
	var x: float = at.x
	var y: float = at.y
	p.poly(PackedVector2Array([
		Vector2(x - 8, y - 9), Vector2(x + 8, y - 9), Vector2(x + 9, y + 5), Vector2(x, y + 11), Vector2(x - 9, y + 5),
	]), KEEPER_BRONZE, true)
	p.rect(roundi(x) - 6, roundi(y) + 2, 12, 2, KEEPER_TRIM)
	p.rect(roundi(x) - 1, roundi(y) - 4, 3, 3, rose)
	if hot:
		for i: int in 8:
			var a: float = i * TAU / 8.0
			p.px(roundi(x + cos(a) * 13.0), roundi(y + sin(a) * 13.0), rose)
