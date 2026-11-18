## Animal sounds out in the world: now and then a cow moos from somewhere in the herd and a hand's
## horse snorts or neighs, each from where the animal stands so near ones are loud and far ones faint.
## At night a wolf howls far off now and then (sounds made in tools/sounds.py). Plus a quiet western tune that loops, which the player can turn off (Hud). Recordings: Freesound, CC0.
class_name Sfx
extends Node3D

const COWS := ["cow_1", "cow_2", "cow_3", "cow_4", "cow_5", "cow_6"]
const HORSES := ["horse_1", "horse_2", "horse_3", "horse_4", "horse_5"]
const MUSIC := "res://sounds/music.ogg"
const MUSIC_DB := -17.0

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


func _ready() -> void:
	_rng.randomize()
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
