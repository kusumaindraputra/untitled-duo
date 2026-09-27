## EnemyBulletPalette — the one colour family every enemy bullet, beam and shell is
## drawn in, so hostile fire never reads as one of Fayde's Prana spells (ADR-0037).
##
## Every enemy shot wears the same hostile [member rim] ring and glow. Its core takes
## the colour of the pattern's [member BulletPattern.accent]: [code]mob[/code] for
## ordinary enemies and hazards, and each boss's reserved colour from the art bible
## (§4.3: Warden B1 violet, Keeper B3 rose; Sentinel a lighter mint of B2 teal,
## ADR-0037). Every colour here
## stays away from the five Prana hues (tests/unit/bullet-hell/enemy_bullet_palette_test.gd).
## Data: assets/data/enemy_bullet_palette.tres
class_name EnemyBulletPalette
extends Resource

## Accent used when a pattern names none, or one this palette does not know.
const DEFAULT_ACCENT: StringName = &"mob"

## Hostile family ring, glow and trail shared by every enemy shot.
@export var rim: Color = Color(1.0, 0.2, 0.62, 1.0)
## Thin dark ring between the rim and the core, so both read on bright effects.
@export var separator: Color = Color(0.05, 0.02, 0.1, 0.85)
## Core colour per accent id. Keys match BulletPattern.accent.
@export var cores: Dictionary[StringName, Color] = {
	&"mob": Color(1.0, 0.6, 0.86, 1.0),
}


## Core colour for [param accent]; falls back to the mob core for an unknown id.
func core_for(accent: StringName) -> Color:
	if cores.has(accent):
		return cores[accent]
	return cores.get(DEFAULT_ACCENT, rim)


## True when [param accent] has its own core colour.
func has_accent(accent: StringName) -> bool:
	return cores.has(accent)
