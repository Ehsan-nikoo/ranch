// Grass tufts: vertex-colored blades that sway, with gust waves rolling across the prairie.
shader_type spatial;
render_mode cull_disabled, world_vertex_coords, specular_disabled, diffuse_lambert_wrap;

uniform sampler2D gust_noise : filter_linear, repeat_enable;
uniform vec2 wind_dir = vec2(0.94, 0.33);
uniform float strength = 0.35;

void vertex() {
	float h = max(VERTEX.y, 0.0);
	float gust = textureLod(gust_noise, VERTEX.xz / 40.0 - wind_dir * TIME * 0.06, 0.0).r;
	float sway = sin(TIME * 2.3 + VERTEX.x * 0.9 + VERTEX.z * 0.7) * 0.25;
	vec2 off = wind_dir * (gust * 1.4 + sway) * strength * h * h;
	VERTEX.xz += off;
	VERTEX.y -= length(off) * 0.3;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	BACKLIGHT = COLOR.rgb * 0.5;  // thin blades glow when the low sun is behind them
	// world-up normal on both faces so blades never go dark when seen from behind
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
