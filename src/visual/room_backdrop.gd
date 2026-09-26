## RoomBackdrop — screen-space void behind the room and vignette over it (ADR-0021).
##
## Two CanvasLayers so both stay fixed to the screen while the camera moves:
## a backdrop under the world (gradient, pooled glow, drifting dust) and a
## vignette over the world but under the HUD (CanvasLayer 10). Colours come
## from the floor's RoomLook; its motif adds far silhouettes (ADR-0038).
class_name RoomBackdrop
extends Node

## Layer of the void behind the world.
const BACK_LAYER: int = -10
## Layer of the vignette: above the world, below the HUD (10) and overlays.
const VIGNETTE_LAYER: int = 1

const _BACKDROP_SHADER: Shader = preload("res://assets/shaders/room_backdrop.gdshader")
const _VIGNETTE_SHADER: Shader = preload("res://assets/shaders/vignette.gdshader")

var _back_rect: ColorRect = null
var _vignette_rect: ColorRect = null


## Builds both layers for [param look]. Call once before adding to the tree.
func setup(look: RoomLook) -> void:
	var back := CanvasLayer.new()
	back.name = "Backdrop"
	back.layer = BACK_LAYER
	add_child(back)
	_back_rect = _full_rect(_BACKDROP_SHADER)
	var bm: ShaderMaterial = _back_rect.material
	bm.set_shader_parameter(&"top_color", look.backdrop_top)
	bm.set_shader_parameter(&"bottom_color", look.backdrop_bottom)
	bm.set_shader_parameter(&"glow_color", look.backdrop_glow)
	bm.set_shader_parameter(&"dust_color", look.dust)
	bm.set_shader_parameter(&"motif", int(look.motif))
	bm.set_shader_parameter(&"silhouette_color", look.silhouette)
	back.add_child(_back_rect)

	var front := CanvasLayer.new()
	front.name = "Vignette"
	front.layer = VIGNETTE_LAYER
	add_child(front)
	_vignette_rect = _full_rect(_VIGNETTE_SHADER)
	(_vignette_rect.material as ShaderMaterial).set_shader_parameter(&"strength", look.vignette)
	front.add_child(_vignette_rect)


## Returns the shader parameter [param param] of the backdrop (tests).
func get_backdrop_param(param: StringName) -> Variant:
	return (_back_rect.material as ShaderMaterial).get_shader_parameter(param)


## Returns the vignette strength (tests).
func get_vignette_strength() -> float:
	return float((_vignette_rect.material as ShaderMaterial).get_shader_parameter(&"strength"))


static func _full_rect(shader: Shader) -> ColorRect:
	var rect := ColorRect.new()
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	return rect
