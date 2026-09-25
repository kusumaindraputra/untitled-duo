// Screen vignette (ADR-0021): darkens the frame edges so the eye settles on the room.
shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.0, 0.8);
	float v = smoothstep(0.35, 0.75, length(d));
	COLOR = vec4(0.0, 0.0, 0.0, v * strength);
}
