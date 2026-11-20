// The ranch horse (HorseMesh): legs swing from the hips by the leg weights in COLOR, with a little
// knee bend on the way forward; the coat is the texture times a tint.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float pale = 0.0;          // toward grey: a grey horse from the bay texture; past 1 toward white
uniform bool cutout = false;
uniform vec4 pivots;               // hip height, fore pivot z, hind pivot z, knee height
instance uniform float phase = 0.0;
instance uniform float amp = 0.0;  // swing in radians (0 = standing)

vec3 rot_x(vec3 p, vec2 pivot, float a) {
	vec2 q = p.yz - pivot;
	float c = cos(a), s = sin(a);
	return vec3(p.x, pivot + vec2(c * q.x + s * q.y, -s * q.x + c * q.y));
}

void vertex() {
	float w = COLOR.r;
	if (w > 0.0 && amp > 0.0) {
		float ph = phase + (COLOR.g > 0.5 ? 0.0 : PI);
		float swing = sin(ph) * amp;
		float bend = max(0.0, cos(ph)) * amp * 1.6;   // the knee folds while the hoof comes forward
		float z = COLOR.b > 0.5 ? pivots.y : pivots.z;
		vec3 p = VERTEX;
		vec3 n = NORMAL;
		// knee first (lower leg about the knee), then the whole leg about the hip
		float kb = COLOR.b > 0.5 ? bend : -bend;
		p = mix(p, rot_x(p, vec2(pivots.w, z), kb), COLOR.a);
		p = mix(p, rot_x(p, vec2(pivots.x, z), swing), w);
		n = mix(n, rot_x(n, vec2(0.0), swing), w);
		VERTEX = p;
		NORMAL = normalize(n);
	}
}

void fragment() {
	vec4 c = texture(tex, UV);
	if (cutout && c.a < 0.12) {
		discard;
	}
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 a = mix(c.rgb * tint.rgb, vec3(0.16 + l * 2.2), min(pale, 1.0));
	ALBEDO = mix(a, vec3(0.9, 0.88, 0.84) * (0.8 + l * 0.6), clamp(pale - 1.0, 0.0, 1.0));  // past 1: on toward white
	ROUGHNESS = 0.9;
}
