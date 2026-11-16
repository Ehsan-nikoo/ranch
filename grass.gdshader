// Grass tufts: vertex-colored blades that sway, with gust waves rolling across the prairie.
// Lit per vertex (not per pixel) because grass covers most of the screen and phone GPUs are fill-rate bound.
shader_type spatial;
render_mode cull_disabled, world_vertex_coords, specular_disabled, vertex_lighting;

uniform vec2 wind_dir = vec2(0.94, 0.33);
uniform float strength = 0.35;
uniform vec3 to_sun = vec3(0.0, 1.0, 0.0);  // set by main.gd as the sun moves
uniform sampler2D grazed : filter_linear, repeat_disable;  // herd grass grid, 1 = full
uniform float span = 160.0;

void vertex() {
	// grazed-down cells shrink the tufts toward stubble
	vec3 root = MODEL_MATRIX[3].xyz;
	float g = textureLod(grazed, root.xz / span + 0.5, 0.0).r;
	VERTEX = root + (VERTEX - root) * vec3(1.0, mix(0.12, 1.0, g), 1.0);
	float h = max(VERTEX.y, 0.0);
	float along = dot(VERTEX.xz, wind_dir);
	float gust = sin(along * 0.12 - TIME * 1.4) * 0.5 + 0.5;
	gust *= sin(along * 0.05 + VERTEX.z * 0.03 - TIME * 0.6) * 0.3 + 0.7;
	float sway = sin(TIME * 2.3 + VERTEX.x * 0.9 + VERTEX.z * 0.7) * 0.25;
	vec2 off = wind_dir * (gust * 1.4 + sway) * strength * h * h;
	VERTEX.xz += off;
	VERTEX.y -= length(off) * 0.3;
	// lean normals toward the sun: thin blades catch low evening light instead of going dull
	NORMAL = normalize(vec3(0.0, 1.0, 0.0) + to_sun * 0.9);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
