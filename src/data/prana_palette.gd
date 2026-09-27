## PranaPalette — a replacement set of Prana colours for one colour-vision mode
## (ADR-0047).
##
## The PranaType .tres files keep the art-bible colours for normal vision. When the
## player picks a colour-blind mode in Settings, PranaCatalog serves the matching
## palette's colours instead, so every grid slot, token, spell and hit tint changes
## at once. Shape icons (ADR-0036) stay the same and still tell the types apart.
##
## Each palette keeps its five colours apart under its own deficiency and away from
## the hostile bullet rim (ADR-0037); tests/unit/prana-palette checks both.
## Data: assets/data/prana_palettes/*.tres
class_name PranaPalette
extends Resource

## Colour per Prana type, in catalog id order (Ashfire, Voidblue, Stormgold,
## Deepfrost, Verdant).
@export var colors: Array[Color] = []


## Colour for Prana type [param id], or [param fallback] when the palette has none.
func color_for(id: int, fallback: Color) -> Color:
	if id < 0 or id >= colors.size():
		return fallback
	return colors[id]
