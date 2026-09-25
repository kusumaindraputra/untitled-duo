// Room backdrop (ADR-0021): vertical void gradient, a soft glow pooled behind
// the room, slow fog bands and sparse drifting dust motes.
shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.106, 0.106, 0.133, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.055, 0.051, 0.071, 1.0);
uniform vec4 glow_color : source_color = vec4(0.227, 0.180, 0.149, 1.0);
uniform vec4 dust_color : source_color = vec4(0.557, 0.451, 0.345, 1.0);
uniform float dust_density = 0.08;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top_color.rgb, bottom_color.rgb, uv.y);
	// Glow pooled a little below centre, where the room sits.
	vec2 g = (uv - vec2(0.5, 0.55)) * vec2(1.2, 1.9);
	col += glow_color.rgb * smoothstep(1.0, 0.0, length(g)) * 0.9;
	// Slow fog bands.
	float fog = noise(uv * vec2(3.0, 6.0) + vec2(TIME * 0.02, TIME * 0.01));
	col += glow_color.rgb * (fog - 0.5) * 0.25;
	// Dust motes: one candidate per grid cell, drifting upwards.
	vec2 grid = vec2(48.0, 27.0);
	vec2 p = uv * grid + vec2(0.0, TIME * 0.15);
	vec2 cell = floor(p);
	float h = hash(cell);
	if (h < dust_density) {
		vec2 c = vec2(hash(cell + 3.1), hash(cell + 7.7));
		float d = length(fract(p) - c);
		float twinkle = 0.5 + 0.5 * sin(TIME * 1.3 + h * 60.0);
		col += dust_color.rgb * smoothstep(0.09, 0.0, d) * 0.55 * twinkle;
	}
	COLOR = vec4(col, 1.0);
}
