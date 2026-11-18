## Weather you can see and hear: spells of rain (with thunderstorms in summer), snow in winter, a
## heavy blizzard when Events brings one, and a dusty yellow haze in a drought. Clouds dim the sun and
## grey the sky (DayCycle.overcast). Rain makes the grass grow back faster and the cows less thirsty.
## The rain and snow fall around the camera only, so a few hundred particles fill the view.
class_name Weather
extends Node3D

enum { CLEAR, RAIN, STORM, SNOW }
const NAMES := ["آفتابی", "بارونی", "طوفانی", "برفی"]
# chance of a spell starting each half day, by season: rain, storm, snow
const ODDS := [[0.35, 0.1, 0.0], [0.12, 0.18, 0.0], [0.3, 0.06, 0.0], [0.05, 0.0, 0.45]]

var day: DayCycle
var events: Events
var herd: Herd
var rig: Node3D            # the camera rig: weather follows what you're looking at

var now := CLEAR
var detail := 1.0          # share of the particles drawn, set by the quality button
var until := 0.0           # game hour (day * 24 + hour) the spell ends
var _next_roll := 0.0
var _rain := CPUParticles3D.new()
var _snow := CPUParticles3D.new()
var _rain_snd := AudioStreamPlayer.new()
var _thunder := AudioStreamPlayer.new()
var _thunders: Array[AudioStream] = []
var _bolt := 6.0
var _flash := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_rain.mesh = _streak(Vector2(0.05, 1.1), Color(0.78, 0.84, 0.95, 0.42))
	_rain.amount = 1400
	_rain.lifetime = 0.9
	_rain.preprocess = 0.9  # already falling when it starts
	_rain.direction = Vector3(0.15, -1, 0)
	_rain.spread = 4.0
	_rain.initial_velocity_min = 26.0
	_rain.initial_velocity_max = 32.0
	_rain.gravity = Vector3(0, -10, 0)
	_snow.mesh = _streak(Vector2(0.2, 0.2), Color(1, 1, 1, 0.9))
	_snow.amount = 1100
	_snow.lifetime = 7.0
	_snow.preprocess = 7.0
	_snow.direction = Vector3(0.3, -1, 0.1)
	_snow.spread = 25.0
	_snow.initial_velocity_min = 2.0
	_snow.initial_velocity_max = 3.5
	_snow.gravity = Vector3(0, -0.6, 0)
	for p: CPUParticles3D in [_rain, _snow]:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(45, 1, 45)
		p.position = Vector3(0, 24, 0)
		p.local_coords = false
		p.emitting = false
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.visibility_aabb = AABB(Vector3(-60, -40, -60), Vector3(120, 50, 120))
		add_child(p)
	_snow.emission_box_extents = Vector3(32, 1, 32)  # snow drifts slowly: keep it close to the view
	_snow.position.y = 18.0
	var r: AudioStreamWAV = load("res://sounds/rain.wav")
	r.loop_mode = AudioStreamWAV.LOOP_FORWARD
	r.loop_end = int(r.get_length() * r.mix_rate)
	_rain_snd.stream = r
	_rain_snd.volume_db = -80.0
	add_child(_rain_snd)
	_rain_snd.play()
	for n in ["thunder_1", "thunder_2"]:
		_thunders.append(load("res://sounds/%s.wav" % n))
	_thunder.volume_db = -6.0
	add_child(_thunder)


## A camera-facing quad: rain streaks and snowflakes.
func _streak(size: Vector2, color: Color) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y if size.y > size.x * 2.0 else BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	q.material = m
	return q


## Turns a fall on or off and sets how thick it is (changing the amount restarts it, so only on change).
func _fall(p: CPUParticles3D, on: bool, amount: int) -> void:
	amount = maxi(100, int(amount * detail))
	if on and p.amount != amount:
		p.amount = amount
	p.emitting = on


func time() -> float:
	return day.day * 24.0 + day.hour


func _roll() -> void:
	var t := time()
	if t < _next_roll:
		return
	_next_roll = t + 12.0
	if now != CLEAR and t < until:
		return
	now = CLEAR
	if events.active("drought"):
		return  # no rain in a drought
	var odds: Array = ODDS[day.season()]
	var r := _rng.randf()
	if r < odds[0]:
		now = RAIN
	elif r < odds[0] + odds[1]:
		now = STORM
	elif r < odds[0] + odds[1] + odds[2]:
		now = SNOW
	until = t + _rng.randf_range(3.0, 9.0)


func _process(delta: float) -> void:
	_roll()
	if now != CLEAR and time() >= until:
		now = CLEAR
	var blizzard := events.active("blizzard")
	var rain := now in [RAIN, STORM] and day.season() != DayCycle.WINTER
	var snow := now == SNOW or blizzard or (now in [RAIN, STORM] and day.season() == DayCycle.WINTER)
	position = Vector3(rig.position.x, 0, rig.position.z)
	_fall(_rain, rain, 1400 if now == STORM else 850)
	_fall(_snow, snow, 1500 if blizzard else 900)
	_snow.direction = Vector3(1.6 if blizzard else 0.3, -1, 0.4 if blizzard else 0.1)
	_snow.initial_velocity_max = 9.0 if blizzard else 3.5
	var want := 0.0
	if blizzard:
		want = 0.85
	elif now == STORM:
		want = 0.75
	elif now != CLEAR:
		want = 0.5
	day.overcast = move_toward(day.overcast, want, delta * 0.25)
	day.haze = move_toward(day.haze, 1.0 if events.active("drought") else 0.0, delta * 0.2)
	_rain_snd.volume_db = linear_to_db(maxf(0.001, 0.0 if not rain else (0.9 if now == STORM else 0.55)))
	# gameplay: rain greens the pasture and the cows drink less
	herd.rain_mul = 1.6 if rain else 1.0
	herd.wet_mul = 0.75 if rain else 1.0
	# lightning: a white flash, the rumble a moment later
	if now == STORM and day.season() != DayCycle.WINTER:
		_bolt -= delta
		if _bolt <= 0.0:
			_bolt = _rng.randf_range(5.0, 14.0)
			_flash = 1.0
			get_tree().create_timer(_rng.randf_range(0.4, 1.8)).timeout.connect(func():
				_thunder.stream = _thunders[_rng.randi() % _thunders.size()]
				_thunder.pitch_scale = _rng.randf_range(0.85, 1.1)
				_thunder.play())
	_flash = maxf(0.0, _flash - delta * 5.0)
	day.flash = _flash * (0.6 + 0.4 * absf(sin(_flash * 30.0)))  # flickers as it fades


func to_save() -> Dictionary:
	return {now = now, until = until}


func from_save(d: Dictionary) -> void:
	now = int(d.now)
	until = d.until
