// Sky as a plain gradient dome around the camera. Godot's built-in Sky re-filters a radiance
// cubemap whenever its colors change (every frame with a day-night cycle): ~100 ms/frame on a Mali-G57.
// Changing uniforms here costs nothing extra.
shader_type spatial;
render_mode unshaded, cull_front, fog_disabled, shadows_disabled, depth_draw_never;

uniform vec3 top_color : source_color;
uniform vec3 horizon_color : source_color;
uniform vec3 below_color : source_color;   // matches fog so the ground fades into it
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_color : source_color;
uniform float sun_visible = 1.0;

varying vec3 dir;

void vertex() {
	dir = VERTEX;
}

void fragment() {
	vec3 d = normalize(dir);
	vec3 c;
	if (d.y > 0.0) {
		c = mix(horizon_color, top_color, pow(smoothstep(0.0, 1.0, d.y), 0.55));
	} else {
		c = mix(horizon_color, below_color, smoothstep(0.0, 0.06, -d.y));
	}
	float s = max(dot(d, normalize(sun_dir)), 0.0);
	c += sun_color * sun_visible * (pow(s, 900.0) * 6.0 + pow(s, 12.0) * 0.35);
	ALBEDO = c;
}
