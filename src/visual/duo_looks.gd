## DuoLooks — the sprite sheets of Ayden and Faith (ADR-0058).
##
## Both brothers use Fayde's rig (20×32 cells, same rows and poses), built by
## tools/art-gen/generate_character_sprites.gd, so PixelCharacter and CrumplePose only
## swap textures. Fayde's own sheets stay for the menu and for DuoSwap.NONE.
class_name DuoLooks
extends RefCounted

const AYDEN: Dictionary = {
	"sheet": preload("res://assets/art/characters/ayden.png"),
	"glow": preload("res://assets/art/characters/ayden_glow.png"),
	"casts": preload("res://assets/art/characters/ayden_casts.png"),
	"casts_glow": preload("res://assets/art/characters/ayden_casts_glow.png"),
	"crumple": preload("res://assets/art/characters/ayden_crumple.png"),
	"crumple_glow": preload("res://assets/art/characters/ayden_crumple_glow.png"),
}
const FAITH: Dictionary = {
	"sheet": preload("res://assets/art/characters/faith.png"),
	"glow": preload("res://assets/art/characters/faith_glow.png"),
	"casts": preload("res://assets/art/characters/faith_casts.png"),
	"casts_glow": preload("res://assets/art/characters/faith_casts_glow.png"),
	"crumple": preload("res://assets/art/characters/faith_crumple.png"),
	"crumple_glow": preload("res://assets/art/characters/faith_crumple_glow.png"),
}
const FAYDE: Dictionary = {
	"sheet": preload("res://assets/art/characters/fayde.png"),
	"glow": preload("res://assets/art/characters/fayde_glow.png"),
	"casts": preload("res://assets/art/characters/fayde_casts.png"),
	"casts_glow": preload("res://assets/art/characters/fayde_casts_glow.png"),
	"crumple": preload("res://assets/art/characters/fayde_crumple.png"),
	"crumple_glow": preload("res://assets/art/characters/fayde_crumple_glow.png"),
}


## Sheets for [param character] (a DuoSwap.Character, or DuoSwap.NONE for Fayde).
static func for_character(character: int) -> Dictionary:
	match character:
		DuoSwap.Character.AYDEN: return AYDEN
		DuoSwap.Character.FAITH: return FAITH
	return FAYDE


## Puts [param character]'s sheets on [param pixel].
static func apply(pixel: PixelCharacter, character: int) -> void:
	var look: Dictionary = for_character(character)
	pixel.sheet = look["sheet"]
	pixel.glow_sheet = look["glow"]
	pixel.cast_sheet = look["casts"]
	pixel.cast_glow_sheet = look["casts_glow"]
