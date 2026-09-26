// Room backdrop (ADR-0021): vertical void gradient, a soft glow pooled behind
// the room, slow fog bands and sparse drifting dust motes.
// ADR-0038: per-floor silhouettes in the void, drawn on a coarse pixel grid:
// motif 1 scrap heaps and girders, 2 pipe runs, 3 crystal shards. 0 = none.
shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.106, 0.106, 0.133, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.055, 0.051, 0.071, 1.0);
uniform vec4 glow_color : source_color = vec4(0.227, 0.180, 0.149, 1.0);
uniform vec4 dust_color : source_color = vec4(0.557, 0.451, 0.345, 1.0);
uniform float dust_density = 0.08;
uniform int motif = 0;
uniform vec4 silhouette_color : source_color = vec4(0.082, 0.075, 0.102, 1.0);
// Silhouettes are snapped to this grid so they read as pixel art.
uniform vec2 pixel_grid = vec2(384.0, 216.0);

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

// Stepped value noise: height profiles that change in flat pixel runs.
float ridge(float x, float freq, float seed) {
	return noise(vec2(x * freq, seed));
}

// Scrap yard: a far and a near junk-heap skyline with girders poking out.
// Returns x = far mask, y = near mask, z = small warm lights.
vec3 scrap(vec2 p) {
	float far_h = 0.30 + 0.12 * ridge(p.x, 5.0, 1.0) + 0.05 * ridge(p.x, 19.0, 2.0);
	float near_h = 0.16 + 0.09 * ridge(p.x, 8.0, 3.0) + 0.04 * ridge(p.x, 31.0, 4.0);
	float far_m = step(1.0 - far_h, p.y);
	float near_m = step(1.0 - near_h, p.y);
	// Girders: thin leaning posts above the near heap.
	float cell = floor(p.x * 14.0);
	float h = hash(vec2(cell, 9.0));
	if (h < 0.35) {
		float cx = (cell + 0.5) / 14.0;
		float top = 1.0 - near_h - 0.06 - 0.08 * hash(vec2(cell, 3.0));
		float lean = (hash(vec2(cell, 5.0)) - 0.5) * 0.25;
		float x_at = cx + (p.y - top) * lean;
		if (p.y > top && abs(p.x - x_at) < 0.0035) {
			near_m = 1.0;
		}
	}
	// Hanging wreckage from the top edge.
	float hang = 0.05 + 0.06 * ridge(p.x, 11.0, 7.0);
	near_m = max(near_m, step(p.y, hang * step(0.55, ridge(p.x, 4.0, 8.0))));
	float lights = far_m * (1.0 - near_m) * step(0.995, hash(floor(p * pixel_grid / 3.0)));
	return vec3(far_m, near_m, lights);
}

// Functional corridors: horizontal pipe runs with collars and vertical risers.
vec3 conduit(vec2 p) {
	float far_m = 0.0;
	float near_m = 0.0;
	float bands[4] = float[](0.12, 0.2, 0.8, 0.9);
	for (int i = 0; i < 4; i++) {
		float th = (i == 1 || i == 2) ? 0.012 : 0.022;
		float d = abs(p.y - bands[i]);
		float collar = step(0.94, fract(p.x * 9.0 + float(i) * 0.37)) * step(d, th * 1.6);
		float m = max(step(d, th), collar);
		if (i == 1 || i == 2) { far_m = max(far_m, m); } else { near_m = max(near_m, m); }
	}
	float cell = floor(p.x * 16.0);
	float h = hash(vec2(cell, 21.0));
	float cx = (cell + 0.3 + 0.4 * hash(vec2(cell, 22.0))) / 16.0;
	float riser = step(abs(p.x - cx), h < 0.2 ? 0.006 : 0.0035) * step(h, 0.45);
	if (h < 0.2) { near_m = max(near_m, riser); } else { far_m = max(far_m, riser); }
	// Slow drips of light along the near pipes.
	float lights = near_m * step(0.985, hash(floor(p * pixel_grid / 2.0) + floor(TIME * 0.5)));
	return vec3(far_m, near_m, lights);
}

// Cipher core: crystal shards rising from below and hanging from above.
vec3 crystal(vec2 p) {
	float far_m = 0.0;
	float near_m = 0.0;
	float edge = 0.0;
	for (int layer = 0; layer < 2; layer++) {
		float cols = layer == 0 ? 11.0 : 7.0;
		float cell = floor(p.x * cols);
		float h = hash(vec2(cell, 31.0 + float(layer)));
		float cx = (cell + 0.5) / cols;
		float half_w = (0.35 + 0.3 * hash(vec2(cell, 33.0))) / cols;
		float tall = layer == 0 ? 0.16 + 0.2 * h : 0.1 + 0.14 * h;
		float from_bottom = 1.0 - p.y;
		float from_top = p.y;
		float w_at = half_w * (1.0 - from_bottom / tall);
		float up = step(abs(p.x - cx), w_at) * step(from_bottom, tall);
		float w_top = half_w * 0.6 * (1.0 - from_top / (tall * 0.55));
		float down = step(abs(p.x - cx), w_top) * step(from_top, tall * 0.55) * step(0.5, h);
		float m = max(up, down);
		// A lit facet line down the middle of the near shards.
		edge = max(edge, float(layer) * m * step(abs(p.x - cx), 0.0015));
		if (layer == 0) { far_m = max(far_m, m); } else { near_m = max(near_m, m); }
	}
	return vec3(far_m, near_m, edge);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top_color.rgb, bottom_color.rgb, uv.y);
	if (motif > 0) {
		vec2 p = (floor(uv * pixel_grid) + 0.5) / pixel_grid;
		vec3 s = motif == 1 ? scrap(p) : (motif == 2 ? conduit(p) : crystal(p));
		col = mix(col, mix(col, silhouette_color.rgb, 0.55), s.x);
		col = mix(col, silhouette_color.rgb, s.y);
		col += dust_color.rgb * s.z * 0.35;
	}
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
