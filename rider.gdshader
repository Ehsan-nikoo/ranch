// The ranch hand's texture with his grey plaid shirt dyed the colour of his job: the shirt is the only
// grey cloth on him, so grey pixels (little saturation, not too dark or bright) take the tint.
shader_type spatial;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 shirt : source_color = vec4(0.5, 0.5, 0.5, 1.0);

void fragment() {
	vec3 c = texture(tex, UV).rgb;
	float hi = max(c.r, max(c.g, c.b));
	float lo = min(c.r, min(c.g, c.b));
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	float grey = smoothstep(0.07, 0.025, hi - lo) * smoothstep(0.03, 0.08, l) * smoothstep(0.9, 0.75, l);
	ALBEDO = mix(c, shirt.rgb * l * 2.4, grey);
	ROUGHNESS = 0.9;
}
