## UIPalette — the art bible §4.4 UI colours in one place (ADR-0039).
##
## UI draws from the environment palette (E1–E7) and the Prana palette only, plus the
## dedicated health red. Every colour here stays at or below 40 % HSL saturation so
## that full jewel tones keep meaning "magic" (art bible §2, rule 3). Prana colours
## still come from PranaType resources; boss colours stay off the UI entirely.
##
## These are art-direction constants mirrored from the art bible table, not gameplay
## values, so they live in code where `const` declarations can use them.
class_name UIPalette
extends RefCounted

## E1 Dungeon Stone — main panel fill (used at 90 % opacity).
const PANEL := Color("#3A3530")
## E6 Atmosphere Haze — empty slots, deepest backgrounds.
const VOID := Color("#1B1B22")
## E7 Warm Lantern Bleed — panel borders.
const BORDER := Color("#8E7358")
## HUD cards over the world: E1 in shadow, translucent so the room reads through.
const CARD := Color(0.125, 0.113, 0.1, 0.78)
## Cards on overlays (pause, run summary): E1 in shadow, nearly opaque.
const CARD_SOLID := Color(0.125, 0.113, 0.1, 0.94)
## Hairline border for HUD cards: E7 at low alpha.
const CARD_BORDER := Color(0.557, 0.451, 0.345, 0.4)

## Static labels (§4.4 "UI text / labels").
const TEXT := Color("#D4C9B8")
## Secondary labels (captions, hints).
const TEXT_DIM := Color("#AEA598")
## Tertiary labels (version, locked notes).
const TEXT_FAINT := Color("#83796D")

## E7 brightened toward 70 % lightness — headings and "touched by warmth" highlights.
## Replaces the old saturated gold that sat on Stormgold's hue.
const ACCENT := Color("#CEB68D")
## A quieter accent for footnotes and counters.
const ACCENT_DIM := Color("#AB9269")

## Positive feedback (step done, ready to continue). Sage, not Verdant.
const GOOD := Color("#90BB81")
## Warnings and the death cause line. Dusty rose, not health red.
const WARN := Color("#C48A82")
## Neutral information (assist notes).
const COOL := Color("#9DB6C8")

## Floor-map room markers, in DungeonGraph.ROOM_TYPE_* order (Combat, Elite, Rest, Boss).
## Letters carry the meaning; colour only groups.
const MAP_ROOM: Array[Color] = [
	Color("#8E857B"),  # Combat — worn stone
	Color("#B99764"),  # Elite — brass
	Color("#6FA465"),  # Rest — moss
	Color("#B2574D"),  # Boss — rust
]
## Cursed room ring: dusty plum, well below Corruption Violet's saturation.
const MAP_CURSED := Color("#9C7BA3")
## Neutral legend swatch.
const SWATCH := Color("#58524B")

## Defeat screen wash (§2.5): cool, desaturated, the world drained of warmth.
const DEFEAT_WASH := Color(0.07, 0.09, 0.13, 0.9)
## Victory / run-summary wash (§2.6): warm and low.
const VICTORY_WASH := Color(0.09, 0.07, 0.05, 0.9)

## One title breath takes this long (§2.1: one breath per two seconds).
const TITLE_BREATH_SEC: float = 2.0
## Seconds each Prana colour holds the title before blending to the next.
const TITLE_CYCLE_SEC: float = 6.0


## Every palette entry that must obey the saturation cap, for tests.
static func capped_colors() -> Array[Color]:
	var out: Array[Color] = [PANEL, VOID, BORDER, TEXT, TEXT_DIM, TEXT_FAINT, ACCENT,
		ACCENT_DIM, GOOD, WARN, COOL, MAP_CURSED, SWATCH]
	out.append_array(MAP_ROOM)
	return out


## HSL saturation (0–1) of [param c], the measure the art bible uses.
static func hsl_saturation(c: Color) -> float:
	var hi: float = maxf(c.r, maxf(c.g, c.b))
	var lo: float = minf(c.r, minf(c.g, c.b))
	var l: float = (hi + lo) * 0.5
	if is_equal_approx(hi, lo):
		return 0.0
	return (hi - lo) / (1.0 - absf(2.0 * l - 1.0))


## Title colour at [param t] seconds (§2.1): slowly cycles through [param prana]
## colours and breathes once every TITLE_BREATH_SEC. Pure, so it can be tested.
## Falls back to ACCENT with no Prana colours.
static func title_glow(t: float, prana: Array[Color]) -> Color:
	if prana.is_empty():
		return ACCENT
	var n: int = prana.size()
	var pos: float = fposmod(t / TITLE_CYCLE_SEC, float(n))
	var i: int = floori(pos)
	var blend: float = smoothstep(0.7, 1.0, pos - float(i))
	var base: Color = prana[i].lerp(prana[(i + 1) % n], blend)
	# Breath: dip toward the warm text colour and back, never below 70 % of the jewel.
	var breath: float = 0.5 - 0.5 * cos(TAU * t / TITLE_BREATH_SEC)
	return base.lerp(TEXT, 0.3 * (1.0 - breath))
