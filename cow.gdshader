// Herd cattle: one MultiMesh, poses read from a vertex-animation texture baked by tools/cow_bake.gd.
// Per-instance INSTANCE_CUSTOM:
//   r = walk cycle 0..1, g = head down 0..1 (graze/drink), or 2 + progress while dying,
//   b = coat (type in the integer part of b*4, shade in the fraction), a = walk amount 0..1
shader_type spatial;
render_mode specular_schlick_ggx;

uniform sampler2D vat_pos : filter_nearest, repeat_disable;
uniform sampler2D vat_nrm : filter_nearest, repeat_disable;
uniform sampler2D body_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D eye_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform int rows = 5;
uniform ivec2 idle_clip;
uniform ivec2 walk_clip;
uniform ivec2 graze_clip;
uniform ivec2 death_clip;

varying float coat;
varying float eye;

const int WIDTH = 1024;

ivec2 texel(int frame, int vid) {
	return ivec2(vid % WIDTH, frame * rows + vid / WIDTH);
}

// position (xyz) and normal of vertex `vid` at time t (0..1) of a clip, frames blended
void sample_clip(ivec2 clip, float t, bool loop, int vid, out vec3 p, out vec3 n) {
	float f = loop ? fract(t) * float(clip.y) : clamp(t, 0.0, 1.0) * float(clip.y - 1);
	int f0 = int(floor(f));
	int f1 = loop ? (f0 + 1) % clip.y : min(f0 + 1, clip.y - 1);
	float k = f - floor(f);
	p = mix(texelFetch(vat_pos, texel(clip.x + f0, vid), 0).xyz, texelFetch(vat_pos, texel(clip.x + f1, vid), 0).xyz, k);
	n = texelFetch(vat_nrm, texel(clip.x + (k < 0.5 ? f0 : f1), vid), 0).xyz * 2.0 - 1.0;
}

void vertex() {
	coat = INSTANCE_CUSTOM.b;
	eye = COLOR.r;
	float walk = INSTANCE_CUSTOM.a;
	float head = INSTANCE_CUSTOM.g;
	vec3 p;
	vec3 n;
	if (head >= 1.5) {
		sample_clip(death_clip, head - 2.0, false, VERTEX_ID, p, n);
	} else {
		float t0 = TIME / 3.6 + coat * 7.0;  // idle runs at the clip's own speed, each cow out of step
		sample_clip(idle_clip, t0, true, VERTEX_ID, p, n);
		if (head > 0.01) {
			vec3 gp; vec3 gn;
			sample_clip(graze_clip, TIME / 4.0 + coat * 3.0, true, VERTEX_ID, gp, gn);
			p = mix(p, gp, head);
			n = mix(n, gn, head);
		}
		if (walk > 0.01) {
			vec3 wp; vec3 wn;
			sample_clip(walk_clip, INSTANCE_CUSTOM.r, true, VERTEX_ID, wp, wn);
			p = mix(p, wp, walk);
			n = mix(n, wn, walk);
		}
	}
	VERTEX = p;
	NORMAL = normalize(n);
}

void fragment() {
	if (eye > 0.5) {
		ALBEDO = texture(eye_tex, UV).rgb;
		ROUGHNESS = 0.3;
	} else {
		vec3 c = texture(body_tex, UV).rgb;
		float type = floor(coat * 4.0);
		float shade = fract(coat * 4.0);
		// the texture is a Holstein: recolor its dark patches (and for some, the white too) per cow
		float dark = 1.0 - smoothstep(0.18, 0.42, dot(c, vec3(0.333)));
		vec3 patch_col = c;
		if (type > 0.5 && type < 1.5) {         // red and white
			patch_col = mix(vec3(0.22, 0.08, 0.035), vec3(0.34, 0.13, 0.05), shade) * (0.6 + 2.5 * c.r);
		} else if (type > 1.5 && type < 2.5) {  // dun and white
			patch_col = mix(vec3(0.3, 0.2, 0.12), vec3(0.42, 0.3, 0.18), shade) * (0.6 + 2.5 * c.r);
		}
		c = mix(c, patch_col, dark);
		if (type > 2.5) {                        // solid black, like an Angus
			c = mix(vec3(0.018, 0.016, 0.015), vec3(0.04, 0.034, 0.03), shade) * (0.8 + 0.4 * dot(c, vec3(0.333)));
		}
		c *= vec3(0.93, 0.9, 0.86);  // take the edge off the pure white
		ALBEDO = c;
		ROUGHNESS = 0.8;
	}
	SPECULAR = 0.3;
}
