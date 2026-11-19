## Owns the sky, sun/moon light and environment; blends between keyframed times of day.
class_name DayCycle
extends Node

signal hour_changed(hour: float)
signal day_changed(day: int)

const SECONDS_PER_HOUR := 75.0  # full day = 30 real minutes at 1x
const DAYS_PER_SEASON := 3       # a season is 90 real minutes at 1x, a year six hours
enum { SPRING, SUMMER, AUTUMN, WINTER }
const SEASON_NAMES := ["بهار", "تابستان", "پاییز", "زمستان"]

# hour, sun color, sun energy, sky top, sky horizon, ambient color, ambient energy, fog color, window glow
const KEYS := [
	[0.0, Color(0.55, 0.65, 1.0), 0.28, Color(0.02, 0.03, 0.08), Color(0.08, 0.1, 0.18), Color(0.3, 0.4, 0.7), 0.35, Color(0.08, 0.1, 0.16), 1.0],
	[5.0, Color(0.55, 0.65, 1.0), 0.25, Color(0.05, 0.07, 0.16), Color(0.25, 0.22, 0.32), Color(0.35, 0.42, 0.7), 0.35, Color(0.2, 0.2, 0.28), 1.0],
	[6.3, Color(1.0, 0.6, 0.4), 1.2, Color(0.25, 0.35, 0.6), Color(0.98, 0.62, 0.45), Color(0.5, 0.55, 0.8), 0.45, Color(0.85, 0.62, 0.52), 0.3],
	[8.0, Color(1.0, 0.88, 0.72), 2.0, Color(0.3, 0.5, 0.8), Color(0.82, 0.8, 0.75), Color(0.55, 0.65, 0.85), 0.55, Color(0.78, 0.76, 0.72), 0.0],
	[12.5, Color(1.0, 0.96, 0.88), 2.0, Color(0.24, 0.47, 0.85), Color(0.72, 0.8, 0.88), Color(0.55, 0.68, 0.9), 0.5, Color(0.62, 0.7, 0.8), 0.0],
	[16.5, Color(1.0, 0.85, 0.62), 2.3, Color(0.25, 0.42, 0.75), Color(0.92, 0.75, 0.55), Color(0.5, 0.6, 0.85), 0.5, Color(0.88, 0.74, 0.58), 0.0],
	[18.0, Color(1.0, 0.7, 0.45), 2.0, Color(0.22, 0.32, 0.6), Color(0.99, 0.62, 0.38), Color(0.45, 0.55, 0.85), 0.45, Color(0.9, 0.68, 0.52), 0.2],
	# dusk leans blue-violet, not red: the old red key tinted the whole ranch maroon
	[19.2, Color(0.85, 0.52, 0.48), 0.5, Color(0.14, 0.17, 0.38), Color(0.72, 0.46, 0.44), Color(0.4, 0.46, 0.78), 0.45, Color(0.4, 0.37, 0.48), 0.8],
	[20.5, Color(0.55, 0.65, 1.0), 0.28, Color(0.03, 0.04, 0.1), Color(0.1, 0.1, 0.2), Color(0.3, 0.4, 0.7), 0.35, Color(0.1, 0.1, 0.18), 1.0],
	[24.0, Color(0.55, 0.65, 1.0), 0.28, Color(0.02, 0.03, 0.08), Color(0.08, 0.1, 0.18), Color(0.3, 0.4, 0.7), 0.35, Color(0.08, 0.1, 0.16), 1.0],
]

var hour := 17.2
var day := 0  # days since the ranch started; day 0 is the first day of spring
var speed := 1.0
var overcast := 0.0  # set by Weather: clouds dim the sun and grey the sky
var haze := 0.0      # drought dust: a yellow-brown haze
var flash := 0.0     # lightning
var env := Environment.new()
var sky_mat := ShaderMaterial.new()
var dome := MeshInstance3D.new()
var light := DirectionalLight3D.new()
var lamp := OmniLight3D.new()


func _ready() -> void:
	# no engine Sky at all, see sky_dome.gdshader for why
	sky_mat.shader = load("res://sky_dome.gdshader")
	var sphere := SphereMesh.new()
	sphere.radius = 300.0
	sphere.height = 600.0
	sphere.radial_segments = 32
	sphere.rings = 16
	dome.mesh = sphere
	dome.material_override = sky_mat
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome)
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.04
	env.fog_enabled = true
	env.fog_density = 0.0022
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.05
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	light.shadow_enabled = true
	light.shadow_blur = 1.5
	add_child(light)

	# lantern over the barn doors, lit at night
	lamp.position = Vector3(0, 4.9, Barn.L + 0.8)
	lamp.light_color = Color(1.0, 0.72, 0.4)
	lamp.omni_range = 12.0
	lamp.shadow_enabled = false
	add_child(lamp)
	_apply()


var _lamp_scan := 0.0
var _barn := false


func _process(delta: float) -> void:
	_lamp_scan -= delta
	if _lamp_scan <= 0.0:  # the lantern hangs over the first barn's doors, wherever the player put it
		_lamp_scan = 2.0
		var barns := get_parent().get_children().filter(func(n): return n is Barn and n.works())
		_barn = not barns.is_empty()
		if _barn:
			lamp.global_position = barns[0].to_global(Vector3(0, 4.9, Barn.L + 0.8))
	hour += delta * speed / SECONDS_PER_HOUR
	if hour >= 24.0:
		hour -= 24.0
		day += 1
		day_changed.emit(day)
	var cam := get_viewport().get_camera_3d()
	if cam:
		dome.global_position = cam.global_position
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
	energy *= 1.0 - 0.8 * overcast
	light.light_color = a[1].lerp(b[1], t)
	light.light_energy = energy
	var fog: Color = _cloud(a[7].lerp(b[7], t))
	sky_mat.set_shader_parameter("top_color", _cloud(a[3].lerp(b[3], t)))
	sky_mat.set_shader_parameter("horizon_color", _cloud(a[4].lerp(b[4], t)))
	sky_mat.set_shader_parameter("below_color", fog)
	sky_mat.set_shader_parameter("sun_dir", light.global_basis.z)
	sky_mat.set_shader_parameter("sun_color", light.light_color)
	sky_mat.set_shader_parameter("sun_visible", (1.0 if is_sun and elev > -1.0 else 0.0) * (1.0 - overcast))
	env.background_color = fog
	env.ambient_light_color = a[5].lerp(b[5], t).lerp(Color(0.85, 0.88, 1.0), flash)
	env.ambient_light_energy = lerpf(a[6], b[6], t) * (1.0 - 0.3 * overcast) + flash * 2.5
	env.fog_light_color = fog
	env.fog_density = 0.0022 + 0.004 * overcast + 0.005 * haze
	var glow: float = lerpf(a[8], b[8], t)
	Building.window_mat.emission_energy_multiplier = glow * 2.5
	lamp.light_energy = glow * 2.0
	lamp.visible = glow > 0.01 and _barn
	hour_changed.emit(hour)


## A sky colour under today's weather: greyer and darker under clouds, dusty in a drought,
## white for an instant in a lightning flash.
func _cloud(c: Color) -> Color:
	var l := c.get_luminance()
	c = c.lerp(Color(l, l, l) * 0.8, overcast * 0.85)
	c = c.lerp(Color(0.86, 0.72, 0.48) * maxf(l * 1.3, 0.15), haze * 0.45)
	return c.lerp(Color(0.9, 0.92, 1.0), flash * 0.7)


func season() -> int:
	return (day / DAYS_PER_SEASON) % 4


## 0..1 through the current season.
func season_progress() -> float:
	return (float(day % DAYS_PER_SEASON) + hour / 24.0) / DAYS_PER_SEASON


## e.g. «پاییز، روز ۲ - سال ۱»
func date_text() -> String:
	return "%s، روز %s - سال %s" % [SEASON_NAMES[season()], UiTheme.fa(day % DAYS_PER_SEASON + 1), UiTheme.fa(day / (DAYS_PER_SEASON * 4) + 1)]
