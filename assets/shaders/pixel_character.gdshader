// Pixel character effects (ADR-0034): solid hit flash and the death dissolve.
// Used by PixelCharacter on its body and glow sprites. Everything is computed on the
// sheet's pixel grid, so the effect stays as chunky as the sprite itself.
shader_type canvas_item;

// 0 = normal, 1 = every opaque pixel is flash_color (alpha kept).
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
// 0 = whole, 1 = gone. Pixels vanish in 2×2 clusters, top rows first.
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dissolve_color : source_color = vec4(1.0);
uniform float dissolve_edge : hint_range(0.0, 0.5) = 0.14;
uniform float dissolve_rise : hint_range(0.0, 1.0) = 0.45;
// Rows in the sheet, so the top-down bias is measured inside one frame.
uniform float sheet_rows = 3.0;

float cluster_noise(vec2 cell) {
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 c = COLOR;
	c.rgb = mix(c.rgb, flash_color.rgb, flash_amount);
	if (dissolve > 0.0) {
		vec2 sheet_px = floor(UV / TEXTURE_PIXEL_SIZE);
		float n = cluster_noise(floor(sheet_px / 2.0));
		float frame_y = fract(UV.y * sheet_rows);
		float key = mix(n, frame_y, dissolve_rise);
		float front = dissolve * (1.0 + dissolve_edge);
		if (key < front - dissolve_edge) {
			c.a = 0.0;
		} else if (key < front) {
			c.rgb = dissolve_color.rgb;
		}
	}
	COLOR = c;
}
