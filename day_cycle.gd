## Owns the sky, sun/moon light and environment; blends between keyframed times of day.
class_name DayCycle
extends Node

signal hour_changed(hour: float)

const SECONDS_PER_HOUR := 20.0  # full day = 8 real minutes at 1x

# hour, sun color, sun energy, sky top, sky horizon, ambient color, ambient energy, fog color, window glow
const KEYS := [
	[0.0, Color(0.55, 0.65, 1.0), 0.28, Color(0.02, 0.03, 0.08), Color(0.08, 0.1, 0.18), Color(0.3, 0.4, 0.7), 0.35, Color(0.08, 0.1, 0.16), 1.0],
	[5.0, Color(0.55, 0.65, 1.0), 0.25, Color(0.05, 0.07, 0.16), Color(0.25, 0.22, 0.32), Color(0.35, 0.42, 0.7), 0.35, Color(0.2, 0.2, 0.28), 1.0],
	[6.3, Color(1.0, 0.6, 0.4), 1.2, Color(0.25, 0.35, 0.6), Color(0.98, 0.62, 0.45), Color(0.5, 0.55, 0.8), 0.45, Color(0.85, 0.62, 0.52), 0.3],
	[8.0, Color(1.0, 0.88, 0.72), 2.0, Color(0.3, 0.5, 0.8), Color(0.82, 0.8, 0.75), Color(0.55, 0.65, 0.85), 0.55, Color(0.78, 0.76, 0.72), 0.0],
	[12.5, Color(1.0, 0.96, 0.88), 2.0, Color(0.24, 0.47, 0.85), Color(0.72, 0.8, 0.88), Color(0.55, 0.68, 0.9), 0.5, Color(0.62, 0.7, 0.8), 0.0],
	[16.5, Color(1.0, 0.85, 0.62), 2.3, Color(0.25, 0.42, 0.75), Color(0.92, 0.75, 0.55), Color(0.5, 0.6, 0.85), 0.5, Color(0.88, 0.74, 0.58), 0.0],
	[18.0, Color(1.0, 0.68, 0.42), 2.0, Color(0.22, 0.32, 0.6), Color(0.99, 0.6, 0.35), Color(0.45, 0.55, 0.85), 0.45, Color(0.92, 0.64, 0.45), 0.2],
	[19.2, Color(0.9, 0.42, 0.3), 0.6, Color(0.12, 0.14, 0.32), Color(0.65, 0.32, 0.3), Color(0.35, 0.4, 0.7), 0.4, Color(0.45, 0.3, 0.32), 0.8],
	[20.5, Color(0.55, 0.65, 1.0), 0.28, Color(0.03, 0.04, 0.1), Color(0.1, 0.1, 0.2), Color(0.3, 0.4, 0.7), 0.35, Color(0.1, 0.1, 0.18), 1.0],
	[24.0, Color(0.55, 0.65, 1.0), 0.28, Color(0.02, 0.03, 0.08), Color(0.08, 0.1, 0.18), Color(0.3, 0.4, 0.7), 0.35, Color(0.08, 0.1, 0.16), 1.0],
]

var hour := 17.2
var speed := 1.0
var env := Environment.new()
var sky_mat := ProceduralSkyMaterial.new()
var light := DirectionalLight3D.new()
var lamp := OmniLight3D.new()


func _ready() -> void:
	sky_mat.sky_curve = 0.09
	sky_mat.ground_bottom_color = Color(0.15, 0.12, 0.09)
	sky_mat.sun_angle_max = 25.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME  # cheap enough for a procedural sky, needed as colors change
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.04
	env.fog_enabled = true
	env.fog_density = 0.0022
	env.fog_sky_affect = 0.15
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.05
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	light.shadow_enabled = true
	light.shadow_blur = 1.5
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	light.directional_shadow_max_distance = 80.0
	add_child(light)

	# lantern over the barn doors, lit at night
	lamp.position = Vector3(0, 4.9, Barn.L + 0.8)
	lamp.light_color = Color(1.0, 0.72, 0.4)
	lamp.omni_range = 12.0
	lamp.shadow_enabled = false
	add_child(lamp)
	_apply()


func _process(delta: float) -> void:
	hour = fmod(hour + delta * speed / SECONDS_PER_HOUR, 24.0)
	_apply()


func _apply() -> void:
	var i := 0
	while KEYS[i + 1][0] <= hour:
		i += 1
	var a: Array = KEYS[i]
	var b: Array = KEYS[i + 1]
	var t := smoothstep(0.0, 1.0, inverse_lerp(a[0], b[0], hour))

	var elev := sin((hour - 6.0) / 12.0 * PI) * 62.0
	var is_sun := elev > -4.0
	# sun travels east->west; at night the moon light hangs at a fixed angle
	var yaw := -35.0 + (hour - 17.5) * 15.0
	light.rotation_degrees = Vector3(-maxf(elev, 4.0), yaw, 0) if is_sun else Vector3(-38, 150, 0)
	var energy: float = lerpf(a[2], b[2], t)
	if is_sun:
		energy *= clampf(inverse_lerp(-4.0, 6.0, elev), 0.0, 1.0)
	else:
		energy *= clampf(inverse_lerp(-4.0, -12.0, elev), 0.0, 1.0)
	light.light_color = a[1].lerp(b[1], t)
	light.light_energy = energy
	sky_mat.sky_top_color = a[3].lerp(b[3], t)
	sky_mat.sky_horizon_color = a[4].lerp(b[4], t)
	sky_mat.ground_horizon_color = a[4].lerp(b[4], t).darkened(0.25)
	env.ambient_light_color = a[5].lerp(b[5], t)
	env.ambient_light_energy = lerpf(a[6], b[6], t)
	env.fog_light_color = a[7].lerp(b[7], t)
	var glow: float = lerpf(a[8], b[8], t)
	Barn.window_mat.emission_energy_multiplier = glow * 2.5
	lamp.light_energy = glow * 2.0
	lamp.visible = glow > 0.01
	hour_changed.emit(hour)
