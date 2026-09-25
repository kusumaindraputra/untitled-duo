## RoomLook — the procedural environment palette of one floor (ADR-0021).
##
## Until illustrated tiles exist, the floor, platform edge and backdrop are built
## at runtime from these colours. Defaults follow the art bible environment
## palette (design/art/art-bible.md §4.1): E4 floor, E5 variation, E7 warm accent,
## E6 void. FloorTheme.look points at one RoomLook per floor.
## GDD: design/gdd/stage-layout.md
class_name RoomLook
extends Resource

@export_group("Floor Tiles")
## Dominant floor colour (art bible E4 Ancient Floor).
@export var floor_base: Color = Color("#4A4038")
## Worn-tile variation (art bible E5 Weathered Floor).
@export var floor_alt: Color = Color("#5C5040")
## Seam line drawn along the lower tile edges.
@export var floor_seam: Color = Color("#2A241F")
## Light catch along the upper tile edges.
@export var floor_highlight: Color = Color("#6E604F")
## Warm accent for the rare etched glyph tile (art bible E7 Warm Lantern Bleed).
@export var floor_accent: Color = Color("#8E7358")
## Strength of the per-pixel grain, 0 = flat colour.
@export_range(0.0, 0.2) var grain: float = 0.05
## Share of tiles drawn with the worn variation.
@export_range(0.0, 1.0) var worn_chance: float = 0.28
## Share of tiles drawn cracked.
@export_range(0.0, 1.0) var crack_chance: float = 0.1
## Share of tiles carrying an etched glyph (the art bible's "whimsy" detail).
@export_range(0.0, 1.0) var glyph_chance: float = 0.015

@export_group("Platform Edge")
## Colour of the slab face under the room's lower edges.
@export var edge_face: Color = Color("#2B2520")
## Colour the face fades to at its bottom.
@export var edge_face_bottom: Color = Color("#15130F")
## Height of the slab face in pixels.
@export_range(0.0, 96.0) var edge_depth: float = 28.0

@export_group("Backdrop")
## Void colour at the top of the screen (art bible E6 Atmosphere Haze).
@export var backdrop_top: Color = Color("#1B1B22")
## Void colour at the bottom of the screen.
@export var backdrop_bottom: Color = Color("#0E0D12")
## Soft light pooled behind the room.
@export var backdrop_glow: Color = Color("#3A2E26")
## Drifting dust motes.
@export var dust: Color = Color("#8E7358")
## Screen-edge darkening, 0 = none.
@export_range(0.0, 1.0) var vignette: float = 0.45
