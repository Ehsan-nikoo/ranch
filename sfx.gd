## Animal sounds out in the world: now and then a cow moos from somewhere in the herd and a hand's
## horse snorts or neighs, each from where the animal stands so near ones are loud and far ones faint.
## At night a wolf howls far off now and then (sounds made in tools/sounds.py). Plus a quiet western tune that loops, which the player can turn off (Hud). Recordings: Freesound, CC0.
class_name Sfx
extends Node3D

const COWS := ["cow_1", "cow_2", "cow_3", "cow_4", "cow_5", "cow_6"]
const HORSES := ["horse_1", "horse_2", "horse_3", "horse_4", "horse_5"]
const MUSIC := "res://sounds/music.ogg"
const MUSIC_DB := -17.0
# one-shots and loops beyond the animals: sounds/<key>_1.ogg, _2.ogg... (whichever exist)
const KEYS := ["click", "coin", "hammer", "saw", "lasso", "gallop", "cheer", "ding", "handbell", "rooster", "birds",
	"dog", "anvil", "whistle", "fire", "water", "gavel", "crowd"]

static var me: Sfx   # the one in the game, so any board can make a sound

var herd: Herd
var crew: Crew
var day: DayCycle
var music := AudioStreamPlayer.new()
var _cow: Array[AudioStream] = []
var _horse: Array[AudioStream] = []
var _players: Array[AudioStreamPlayer3D] = []
var _next_cow := 3.0
var _next_horse := 8.0
var _next_howl := 30.0
var _howls: Array[AudioStream] = []
var _howl := AudioStreamPlayer.new()   # far off in the hills: not placed in the world
var _rng := RandomNumberGenerator.new()
var builder: Builder
var camera: Node3D
var gallop_if := func(): return false   # a chase or a race is on
var crowd_if := func(): return false    # the fair is open
var _bank := {}                        # key -> Array[AudioStream]
var _ui: Array[AudioStreamPlayer] = []
var _loops := {}                       # key -> AudioStreamPlayer (2D) or AudioStreamPlayer3D, faded in and out
var _next_build := 2.0
var _next_dog := 20.0
var _next_anvil := 10.0
var _next_whistle := 60.0
var _last_ding := -10.0
var _last_hour := -1.0
var _near := 0.0


func _ready() -> void:
	me = self
	_rng.randomize()
	for k in KEYS:
		var arr: Array[AudioStream] = []
		for i in range(1, 7):
			var path := "res://sounds/%s_%d.ogg" % [k, i]
			if ResourceLoader.exists(path):
				arr.append(load(path))
		if not arr.is_empty():
			_bank[k] = arr
	for i in 4:
		var u := AudioStreamPlayer.new()
		add_child(u)
		_ui.append(u)
	for k in ["birds", "gallop", "crowd"]:
		_loop2d(k)
	for k in ["fire", "water"]:
		if _bank.has(k):
			var p := AudioStreamPlayer3D.new()
			p.stream = _looped(_bank[k][0])
			p.unit_size = 6.0
			p.max_distance = 60.0
			p.volume_db = -80.0
			add_child(p)
			_loops[k] = p
	for n in COWS:
		_cow.append(load("res://sounds/%s.ogg" % n))
	for n in HORSES:
		_horse.append(load("res://sounds/%s.ogg" % n))
	for n in ["howl_1", "howl_2"]:
		_howls.append(load("res://sounds/%s.wav" % n))
	add_child(_howl)
	for i in 4:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 14.0
		p.max_distance = 140.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_players.append(p)
	var m: AudioStreamOggVorbis = load(MUSIC)
	m.loop = true
	music.stream = m
	music.volume_db = MUSIC_DB
	add_child(music)
	music.play()


func _looped(st: AudioStream) -> AudioStream:
	var o := st.duplicate() as AudioStreamOggVorbis
	if o:
		o.loop = true
		return o
	return st


func _loop2d(k: String) -> void:
	if not _bank.has(k):
		return
	var p := AudioStreamPlayer.new()
	p.stream = _looped(_bank[k][0])
	p.volume_db = -80.0
	add_child(p)
	_loops[k] = p


## A sound heard everywhere (a button, money, a cheer): `key` from KEYS, louder or softer by `db`.
static func play(key: String, db := 0.0) -> void:
	if me == null or not me._bank.has(key):
		return
	if key == "ding":  # many notices can come at once: one ding is enough
		var now := Time.get_ticks_msec() / 1000.0
		if now - me._last_ding < 2.5:
			return
		me._last_ding = now
	for u in me._ui:
		if not u.playing:
			var arr: Array = me._bank[key]
			u.stream = arr[me._rng.randi() % arr.size()]
			u.volume_db = db + me._level(key)
			u.pitch_scale = me._rng.randf_range(0.95, 1.05)
			u.play()
			return


## A sound from a spot in the ranch: loud near the camera, faint far off.
static func at(key: String, pos: Vector3, db := 0.0) -> void:
	if me == null or not me._bank.has(key):
		return
	var p := me._free_player()
	if p == null:
		return
	p.stream = me._bank[key][me._rng.randi() % me._bank[key].size()]
	p.position = pos + Vector3(0, 1.5, 0)
	p.volume_db = db + me._level(key)
	p.pitch_scale = me._rng.randf_range(0.94, 1.06)
	p.play()


## How loud each kind sits in the mix (the recordings are levelled, this is taste).
func _level(key: String) -> float:
	return {click = -12.0, coin = -6.0, ding = -10.0, gavel = -4.0, lasso = -2.0, cheer = -6.0, handbell = -8.0,
		rooster = -10.0, whistle = -6.0, dog = -4.0, anvil = -8.0, hammer = -4.0, saw = -8.0}.get(key, -6.0)


func _fade(key: String, want: float, delta: float) -> void:
	if not _loops.has(key):
		return
	var p = _loops[key]
	var to := want if want > -60.0 else -80.0
	p.volume_db = move_toward(p.volume_db, to, delta * 30.0)
	if p.volume_db > -70.0 and not p.playing:
		p.play(_rng.randf() * maxf(0.0, p.stream.get_length() - 1.0))
	elif p.volume_db <= -79.0 and p.playing:
		p.stop()


func _free_player() -> AudioStreamPlayer3D:
	for p in _players:
		if not p.playing:
			return p
	return null


func _play(streams: Array[AudioStream], at: Vector3, db: float) -> void:
	var p := _free_player()
	if p == null:
		return
	p.stream = streams[_rng.randi_range(0, streams.size() - 1)]
	p.position = at + Vector3(0, 1.4, 0)
	p.volume_db = db
	p.pitch_scale = _rng.randf_range(0.92, 1.08)   # no two moos quite alike
	p.play()


func _process(delta: float) -> void:
	_extras(delta)
	if day.speed <= 0.0:
		return
	_next_cow -= delta
	_next_horse -= delta
	var cows := herd.alive()
	if _next_cow <= 0.0 and not cows.is_empty():
		# a bigger herd moos more often, but never a din
		_next_cow = _rng.randf_range(6.0, 16.0) / sqrt(clampf(cows.size() / 10.0, 1.0, 4.0))
		_play(_cow, cows[_rng.randi_range(0, cows.size() - 1)].pos, _rng.randf_range(-6.0, 0.0))
	# now and then at night a wolf howls far away in the hills
	_next_howl -= delta
	if _next_howl <= 0.0:
		_next_howl = _rng.randf_range(40.0, 110.0)
		if day.hour > 20.5 or day.hour < 5.0:
			_howl.stream = _howls[_rng.randi() % _howls.size()]
			_howl.pitch_scale = _rng.randf_range(0.9, 1.1)
			_howl.volume_db = _rng.randf_range(-24.0, -16.0)
			_howl.play()
	if _next_horse <= 0.0:
		_next_horse = _rng.randf_range(14.0, 30.0)
		var riders := crew.riders()
		if not riders.is_empty():
			_play(_horse, riders[_rng.randi_range(0, riders.size() - 1)].global_position, _rng.randf_range(-8.0, -2.0))


## The newer sounds: birds by day and the rooster at dawn, building sites, the dogs and the smithy,
## the station's whistle, the fire and the water nearest the camera, and the chase or race gallop.
func _extras(delta: float) -> void:
	var h := day.hour
	_fade("birds", -20.0 if h > 5.5 and h < 18.5 and day.speed > 0.0 else -80.0, delta)
	_fade("gallop", -8.0 if gallop_if.call() else -80.0, delta * 2.0)
	_fade("crowd", -18.0 if crowd_if.call() else -80.0, delta)
	if _last_hour >= 0.0 and _last_hour < 5.6 and h >= 5.6 and day.speed > 0.0:
		play("rooster")
	_last_hour = h
	if day.speed <= 0.0 or builder == null:
		for k in ["fire", "water"]:
			_fade(k, -80.0, delta)
		return
	var world := builder.world
	_next_build -= delta
	if _next_build <= 0.0:
		_next_build = _rng.randf_range(1.8, 4.5)
		if not builder.sites.is_empty() and h > 6.0 and h < 20.0:
			var b: Building = builder.sites[_rng.randi() % builder.sites.size()]
			at("saw" if _rng.randf() < 0.3 else "hammer", b.global_position)
	_next_dog -= delta
	if _next_dog <= 0.0:
		_next_dog = _rng.randf_range(25.0, 70.0)
		var k := _first(world, "Kennel")
		if k:
			at("dog", k.global_position)
	_next_anvil -= delta
	if _next_anvil <= 0.0:
		_next_anvil = _rng.randf_range(10.0, 26.0)
		var s := _first(world, "Blacksmith")
		if s and h > 7.0 and h < 18.0:
			at("anvil", s.global_position)
	_next_whistle -= delta
	if _next_whistle <= 0.0:
		_next_whistle = _rng.randf_range(120.0, 260.0)
		var st := _first(world, "Station")
		if st:
			at("whistle", st.global_position, -4.0)
	# the fire and the water: one loop each, at the nearest campfire / fountain or pond, every second or so
	_near -= delta
	if _near <= 0.0:
		_near = 1.0
		var cam := camera.global_position if camera else Vector3.ZERO
		_place_loop("fire", _nearest(world, cam, func(n): return n is Decor and (n.kind == "campfire" or n.kind == "k_campfire")))
		_place_loop("water", _nearest(world, cam, func(n): return (n is Decor and n.kind == "fountain") or n is Pond))
	for k in ["fire", "water"]:
		if _loops.has(k):
			_fade(k, -6.0 if _loops[k].has_meta("on") else -80.0, delta)


func _first(world: Node, cls: String) -> Node3D:
	for n in world.get_children():
		var sc = n.get_script()
		if sc and sc.get_global_name() == cls and not n in builder.sites:
			return n
	return null


func _nearest(world: Node, from: Vector3, ok: Callable) -> Node3D:
	var best: Node3D = null
	var bd := 1e9
	for n in world.get_children():
		if n is Node3D and ok.call(n):
			var d: float = (n as Node3D).global_position.distance_to(from)
			if d < bd:
				bd = d
				best = n
	return best


func _place_loop(k: String, n: Node3D) -> void:
	if not _loops.has(k):
		return
	if n == null:
		_loops[k].remove_meta("on")
		return
	_loops[k].global_position = n.global_position + Vector3(0, 0.8, 0)
	_loops[k].set_meta("on", true)
