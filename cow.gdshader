// Herd cattle drawn as one MultiMesh. Per-instance INSTANCE_CUSTOM:
//   r = stride phase (radians, wrapped), g = head down 0..1 (graze/drink), b = coat (type + shade), a = walk 0..1
// Vertex color from cow_mesh.gd: r white mask, g part id / 8, b dark mask.
shader_type spatial;
render_mode specular_schlick_ggx;

varying vec3 lpos;
varying vec3 vcol;
varying float coat;

const float HIP_Y = 0.95;

vec3 rot_x(vec3 p, vec3 pivot, float a) {
	p -= pivot;
	float c = cos(a), s = sin(a);
	return pivot + vec3(p.x, p.y * c - p.z * s, p.y * s + p.z * c);
}

vec3 rot_z(vec3 p, vec3 pivot, float a) {
	p -= pivot;
	float c = cos(a), s = sin(a);
	return pivot + vec3(p.x * c - p.y * s, p.x * s + p.y * c, p.z);
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	lpos = VERTEX;
	vcol = COLOR.rgb;
	coat = INSTANCE_CUSTOM.b;
	float part = floor(COLOR.g * 8.0 + 0.5);
	float phase = INSTANCE_CUSTOM.r;
	float head = INSTANCE_CUSTOM.g;
	float walk = INSTANCE_CUSTOM.a;
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	if (part >= 0.5 && part <= 4.5) {
		// diagonal leg pairs swing together, like a real walk
		float off = (part < 1.5 || part > 3.5) ? 0.0 : PI;
		float a = sin(phase + off) * 0.42 * walk;
		vec3 hip = vec3(0.0, HIP_Y, sign(v.z) * 0.62);
		v = rot_x(v, hip, a);
		n = rot_x(n, vec3(0.0), a);
	} else if (part > 4.5 && part < 5.5) {
		float a = head * 1.05 + sin(phase * 2.0) * 0.04 * walk + sin(TIME * 0.7 + coat * 40.0) * 0.03;
		v = rot_x(v, vec3(0.0, 1.25, 0.75), a);
		n = rot_x(n, vec3(0.0), a);
	} else if (part > 5.5) {
		float a = sin(TIME * 1.6 + coat * 25.0) * 0.25;  // swishing at flies
		v = rot_z(v, vec3(0.0, 1.36, -1.03), a);
	}
	v.y += abs(sin(phase)) * 0.025 * walk;  // body bobs with each step
	VERTEX = v;
	NORMAL = normalize(n);
}

void fragment() {
	float type = floor(coat * 3.0);
	float shade = fract(coat * 3.0);
	vec3 base;
	float white_amt;
	if (type < 0.5) {         // Hereford: red-brown with white face, belly and socks
		base = mix(vec3(0.17, 0.065, 0.03), vec3(0.26, 0.1, 0.045), shade);
		white_amt = vcol.r;
	} else if (type < 1.5) {  // Angus: solid black
		base = mix(vec3(0.035, 0.03, 0.03), vec3(0.08, 0.065, 0.055), shade);
		white_amt = 0.0;
	} else {                  // dun longhorn cross: tan with white patches
		base = mix(vec3(0.28, 0.19, 0.11), vec3(0.4, 0.29, 0.18), shade);
		white_amt = max(vcol.r * 0.3, smoothstep(0.66, 0.78, vnoise(lpos * 2.6 + shade * 30.0)));
	}
	vec3 col = mix(base, vec3(0.62, 0.58, 0.52), white_amt);
	col = mix(col, vec3(0.07, 0.055, 0.05), vcol.b);
	col *= 0.8 + 0.2 * vnoise(lpos * vec3(30.0, 60.0, 30.0)) * (0.7 + 0.3 * vnoise(lpos * 7.0));                    // hair texture
	col *= 0.72 + 0.28 * smoothstep(0.45, 1.35, lpos.y);       // belly and legs darker, like ambient occlusion
	ALBEDO = col;
	ROUGHNESS = mix(0.82, 0.45, vcol.b);
	SPECULAR = 0.3;
}
