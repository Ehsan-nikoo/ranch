// Prairie ground: grass texture blended with dirt by a painted mask, plus large-scale color variation.
shader_type spatial;

uniform sampler2D grass_alb : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_alb : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D mask : filter_linear, repeat_disable;     // R dirt, G lush; covers [-span/2, span/2]
uniform sampler2D macro : filter_linear, repeat_enable;
uniform float span = 160.0;
uniform vec3 grass_tint : source_color = vec3(0.7, 0.68, 0.5);
uniform vec3 lush_tint : source_color = vec3(0.52, 0.62, 0.36);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz / 4.0;
	vec2 muv = wpos.xz / span + 0.5;
	vec4 m = texture(mask, muv);
	float inside = step(0.0, muv.x) * step(muv.x, 1.0) * step(0.0, muv.y) * step(muv.y, 1.0);
	float mac = texture(macro, wpos.xz / 97.0).r * 0.6 + texture(macro, wpos.xz / 23.0).r * 0.4;
	float lush = max(m.g * inside, smoothstep(0.62, 0.8, mac) * 0.6);
	vec3 g = texture(grass_alb, uv).rgb * mix(grass_tint, lush_tint, lush) * (0.8 + 0.4 * mac);
	vec3 d = texture(dirt_alb, uv * 1.3).rgb * vec3(1.05, 0.95, 0.85);
	float k = smoothstep(0.3, 0.65, m.r * inside + (mac - 0.5) * 0.25);
	ALBEDO = mix(g, d, k);
	NORMAL_MAP = mix(texture(grass_nrm, uv).rgb, texture(dirt_nrm, uv * 1.3).rgb, k);
	ROUGHNESS = 0.95;
}
