## Puts every hired hand on the ranch as a cowboy on horseback, doing his job where you can see it:
## the herder rides around the herd, the night guard rides the fence line after dark, the mechanic
## goes back and forth between the windmills and the barn, the farmhand between the barn and the
## pasture. Off duty they wait by the ranch house. Purely for show: the skills work in Workers.
class_name Crew
extends Node3D

const HOME := Vector3(-8, 0, 32)   # in front of the ranch house porch
const RIDE := 2.6                  # m/s at normal speed

var workers: Workers
var herd: Herd
var day: DayCycle
var world: Node3D
var _riders := {}                  # worker name -> {node, target, wait}
var _sync := 0.0
var _rng := RandomNumberGenerator.new()


func _process(delta: float) -> void:
	_sync -= delta
	if _sync <= 0.0:
		_sync = 0.5
		_match_hired()
	for name in _riders:
		_ride(_riders[name], delta)


## One cowboy per hired hand: new hires ride out from the house, fired ones are gone.
func _match_hired() -> void:
	var names := workers.hired.map(func(w): return w.name)
	for name in _riders.keys():
		if not name in names:
			_riders[name].node.queue_free()
			_riders.erase(name)
	for w in workers.hired:
		if _riders.has(w.name):
			continue
		var c := Cowboy.new()
		c.skill = w.skill
		c.coat = absi(hash(w.name)) % Cowboy.COATS.size()
		c.position = herd.free_spot(HOME, 3.0)
		add_child(c)
		_riders[w.name] = {node = c, skill = w.skill, target = c.position, wait = _rng.randf_range(0.5, 3.0), leg = 0}


func _night() -> bool:
	return day.hour < 6.0 or day.hour > 19.5


## The next place this hand rides to, by job.
func _next(r: Dictionary) -> Vector3:
	r.leg += 1
	var cows := herd.alive()
	match r.skill:
		Workers.HERDER:
			if not cows.is_empty():  # circles the herd, a few steps out from one of the cows
				var c: Vector3 = cows[_rng.randi_range(0, cows.size() - 1)].pos
				var a := _rng.randf() * TAU
				return herd.free_spot(c + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(5.0, 9.0), 3.0)
		Workers.RIDER:
			if _night():  # rides the edge of the owned land, round and round
				var h := _edge()
				var a: float = TAU * (r.leg % 12) / 12.0
				return herd.free_spot(Vector3(cos(a), 0, sin(a)) * h, 3.0)
		Workers.MECHANIC:
			var spots := world.get_children().filter(func(n): return (n is Windmill or n is Barn) and not n.has_node("Marker"))
			if not spots.is_empty():
				var b: Building = spots[r.leg % spots.size()]
				return herd.free_spot(b.feed_spot() if b is Barn else b.to_global(Windmill.TANK + Vector3(0, 0, 3.6)), 2.0)
		Workers.HAND:
			if r.leg % 2 == 0:
				return herd.free_spot(Vector3(4, 0, 14), 3.0)  # the barn apron
			return herd.free_spot(Vector3(_rng.randf_range(-40, 40), 0, _rng.randf_range(-40, 40)), 6.0)
	return herd.free_spot(HOME, 4.0)


## How far out the night guard rides: inside the fence of the land you own.
func _edge() -> float:
	var far := 20.0
	for c in herd.alive():
		far = maxf(far, Vector2(c.pos.x, c.pos.z).length() + 6.0)
	return minf(far, Land.HALF - 4.0)


func _ride(r: Dictionary, delta: float) -> void:
	var c: Cowboy = r.node
	var to: Vector3 = r.target - c.position
	to.y = 0.0
	if to.length() < 0.6:
		c.walk(delta, 0.0)
		r.wait -= delta * day.speed
		if r.wait <= 0.0:
			r.target = _next(r)
			r.wait = _rng.randf_range(4.0, 12.0) if r.skill != Workers.RIDER or not _night() else 0.5
		return
	var dir := to.normalized()
	var step := minf(RIDE * day.speed * delta, to.length())
	var ahead := minf(step + 2.0, to.length())
	if herd._blocked(c.position + dir * ahead):  # ride round barns and towers like the cows do
		var side := herd._detour(c.position, dir, ahead)
		if side == Vector3.ZERO:
			r.target = _next(r)
			return
		dir = side
	c.position += dir * step
	c.rotation.y = lerp_angle(c.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 5.0 * maxf(1.0, day.speed)))
	c.walk(delta, step / maxf(delta, 0.0001) / maxf(day.speed, 1.0))


## The riders on the ranch now, for sounds.
func riders() -> Array:
	return _riders.values().map(func(r): return r.node)
