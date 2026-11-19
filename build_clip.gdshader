// A building material for a building still going up: the same colour, texture and shading as its
// StandardMaterial3D (see Site.twin), but nothing above clip_y (world height) is drawn, so the walls
// rise course by course. Back faces are drawn too, so the open top shows the inside of the far wall.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness = 1.0;
uniform float metallic = 0.0;
uniform bool has_tex = false;
uniform bool has_normal = false;
uniform bool has_arm = false;
uniform bool triplanar = false;
uniform bool use_vcol = false;
uniform float tri_scale = 1.0;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D arm_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
instance uniform float clip_y = 1000.0;

varying vec3 world_pos;
varying vec3 obj_pos;
varying vec3 obj_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	obj_pos = VERTEX;
	obj_nrm = NORMAL;
}

void fragment() {
	if (world_pos.y > clip_y) {
		discard;
	}
	vec4 c = albedo;
	float rough = roughness;
	if (has_tex) {
		if (triplanar) {
			vec3 w = pow(abs(normalize(obj_nrm)), vec3(4.0));
			w /= (w.x + w.y + w.z);
			vec3 p = obj_pos * tri_scale;
			c *= texture(albedo_tex, p.zy) * w.x + texture(albedo_tex, p.xz) * w.y + texture(albedo_tex, p.xy) * w.z;
		} else {
			c *= texture(albedo_tex, UV);
			if (has_normal) {
				NORMAL_MAP = texture(normal_tex, UV).rgb;
			}
			if (has_arm) {
				vec3 arm = texture(arm_tex, UV).rgb;
				rough *= arm.g;
				AO = arm.r;
			}
		}
	}
	if (use_vcol) {
		c *= COLOR;
	}
	// a fresh top course is a shade lighter, like new mortar and sawn ends
	float fresh = 1.0 - smoothstep(0.0, 0.25, clip_y - world_pos.y);
	ALBEDO = mix(c.rgb, c.rgb * 1.25 + vec3(0.05), fresh * step(clip_y, 999.0));
	ROUGHNESS = rough;
	METALLIC = metallic;
}
