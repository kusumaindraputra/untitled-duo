## PranaIcon — Shape icons that let each Prana type read without colour (ADR-0036).
##
## Each PranaType carries a 12×12 white silhouette (flame, eye, bolt, snowflake,
## clover — art bible §4.5). This helper scales it by a whole number with nearest
## filtering, so the pixels stay crisp whatever the project's default texture filter
## is, and caches the result per (type, scale). Tint with modulate or Button icon
## colours: black on a Prana-colour tile, Prana colour on a dark button.
class_name PranaIcon
extends RefCounted

## Native pixel size of the authored icons.
const NATIVE_SIZE: int = 12

## Tint for an icon drawn on its own Prana-colour tile (art bible: black on colour).
const ON_COLOR_TINT: Color = Color(0.04, 0.03, 0.06, 0.88)

## Scaled textures keyed by "type_id:scale".
static var _cache: Dictionary = {}


## The icon for [param type_id] scaled [param scale] times (nearest neighbour).
## Returns the unscaled texture when its pixels can't be read, and null for an
## unknown type.
static func texture(type_id: int, scale: int = 1) -> Texture2D:
	var src: Texture2D = PranaCatalog.get_type_icon(type_id)
	if src == null or scale <= 1:
		return src
	var key: String = "%d:%d" % [type_id, scale]
	if _cache.has(key):
		return _cache[key]
	var img: Image = src.get_image()
	if img == null or img.is_empty():
		return src
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## A centred, mouse-transparent [TextureRect] showing the icon for [param type_id]
## at [param scale], tinted [param tint]. Fills its parent when [param fill] is true.
static func make_rect(type_id: int, scale: int, tint: Color = ON_COLOR_TINT, fill: bool = true) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture(type_id, scale)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate = tint
	if fill:
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		rect.custom_minimum_size = Vector2(NATIVE_SIZE * scale, NATIVE_SIZE * scale)
	return rect


## Puts the icon for [param type_id] on [param button], tinted in the type's colour
## in every state so it matches the button's coloured text.
static func apply_to_button(button: Button, type_id: int, scale: int) -> void:
	var tex: Texture2D = texture(type_id, scale)
	if tex == null:
		return
	button.icon = tex
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var c: Color = PranaCatalog.get_type_color(type_id)
	for state: StringName in [&"icon_normal_color", &"icon_focus_color", &"icon_hover_color",
			&"icon_pressed_color", &"icon_hover_pressed_color"]:
		button.add_theme_color_override(state, c)


## Clears the scaled-texture cache (tests).
static func clear_cache() -> void:
	_cache.clear()
