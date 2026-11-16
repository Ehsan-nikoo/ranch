## The cattle herd: each cow gets hungry and thirsty, grazes the grass under it, walks to a
## windmill stock tank to drink, and gains or loses weight. Drawn as one MultiMesh (1 draw call).
## Also owns the grass grid that cows eat and that slowly regrows.
class_name Herd
extends Node3D

signal died(cause: String)

const SPAN := 160.0       # grass grid covers world x/z in [-SPAN/2, SPAN/2], same as the ground mask
const N := 40             # grid cells per side (4 m each)
const MAX_COWS := 80
const BOUNDS := Rect2(-60, -60, 120, 120)
const READY_KG := 500.0   # sale weight
const WALK := 1.15        # m/s
enum { WANDER, GRAZE, TO_WATER, DRINK, IDLE }

var day: DayCycle
var world: Node3D
var extra_blocked: Array[Rect2] = []  # corral etc.
var cows: Array[Dictionary] = []
var grass := PackedFloat32Array()     # 0..1 per cell
var grass_cap := PackedFloat32Array() # max grass per cell (bare dirt grows none)
var grass_tex: ImageTexture

var _mm := MultiMesh.new()
var _rects: Array[Rect2] = []
var _tanks: Array[Vector3] = []
var _scan := 0.0
var _tex_t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.mesh = CowMesh.mesh()
	_mm.instance_count = MAX_COWS
	_mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.material_override = CowMesh.material()
	add_child(mmi)


## Grass starts full except on the dirt painted in the ground mask (R channel).
func init_grass(mask: Image) -> void:
	grass.resize(N * N)
	grass_cap.resize(N * N)
	for y in N:
		for x in N:
			var m := mask.get_pixel(int((x + 0.5) / N * mask.get_width()), int((y + 0.5) / N * mask.get_height()))
			grass_cap[y * N + x] = clampf(1.0 - m.r * 1.6, 0.0, 1.0)
			grass[y * N + x] = grass_cap[y * N + x]
	grass_tex = ImageTexture.create_from_image(_grass_image())


func _grass_image() -> Image:
	var b := PackedByteArray()
	b.resize(N * N)
	for i in N * N:
		b[i] = int(grass[i] * 255.0)
	return Image.create_from_data(N, N, false, Image.FORMAT_R8, b)


func _cell(p: Vector3) -> int:
	var x := clampi(int((p.x + SPAN * 0.5) / SPAN * N), 0, N - 1)
	var y := clampi(int((p.z + SPAN * 0.5) / SPAN * N), 0, N - 1)
	return y * N + x


func add_cow(pos: Vector3, weight: float) -> void:
	if cows.size() >= MAX_COWS:
		return
	cows.append({
		pos = pos, yaw = _rng.randf() * TAU, target = pos, state = IDLE, timer = _rng.randf_range(1, 4),
		hunger = _rng.randf_range(0.2, 0.5), thirst = _rng.randf_range(0.1, 0.4), weight = weight,
		phase = 0.0, head = 0.0, walk = 0.0,
		coat = (_rng.randi_range(0, 3) + _rng.randf() * 0.99) / 4.0,  # type in the integer part of coat*4, see cow.gdshader
	})


## A free spot near `p` (not inside a building, in bounds), or `p` itself if none found.
func free_spot(p: Vector3, radius: float) -> Vector3:
	for k in 20:
		var q := p + Vector3(_rng.randf_range(-radius, radius), 0, _rng.randf_range(-radius, radius))
		if not _blocked(q):
			return q
	return p


func ready_count() -> int:
	return cows.filter(func(c): return c.weight >= READY_KG and not c.has("dying")).size()


## Removes cows at sale weight and returns their total kg.
func sell_ready() -> float:
	var kg := 0.0
	for c in cows.filter(func(c): return c.weight >= READY_KG and not c.has("dying")):
		kg += c.weight
		cows.erase(c)
	return kg


func _blocked(p: Vector3) -> bool:
	if not BOUNDS.has_point(Vector2(p.x, p.z)):
		return true
	var q := Vector2(p.x, p.z)
	for r in _rects:
		if r.has_point(q):
			return true
	for t in _tanks:
		if Vector2(t.x, t.z).distance_to(q) < Windmill.TANK_R + 0.6:
			return true
	return false


## Re-reads buildings: footprints to avoid, windmill tanks to drink from.
func _rescan() -> void:
	_rects = extra_blocked.duplicate()
	_tanks.clear()
	for n in world.get_children():
		if n is not Building or n.has_node("Marker"):  # Marker = still a ghost being placed
			continue
		if n is Windmill:
			_rects.append(n.world_footprint(Rect2(-1.6, -1.6, 3.2, 3.2)))  # tower only, tank is a circle
			_tanks.append(n.to_global(Windmill.TANK))
		else:
			_rects.append(n.world_footprint().grow(0.4))


func _process(delta: float) -> void:
	_scan -= delta
	if _scan <= 0.0:
		_scan = 1.0
		_rescan()
	var hours := delta * day.speed / DayCycle.SECONDS_PER_HOUR
	for c in cows:
		if c.has("dying"):  # plays the model's death clip, lies there a moment, then is gone
			c.dying += delta
			c.walk = 0.0
			continue
		_needs(c, hours)
		_act(c, delta, hours)
		if c.weight < 180.0:
			c.dying = 0.0
			died.emit("thirst" if c.thirst > c.hunger else "hunger")
	_separate()
	for c in cows.filter(func(c): return c.has("dying") and c.dying > 5.0):
		cows.erase(c)
	for i in N * N:  # grass regrows to full in about four days
		grass[i] = minf(grass_cap[i], grass[i] + hours / 96.0)
	_tex_t -= delta
	if _tex_t <= 0.0:
		_tex_t = 0.3
		grass_tex.update(_grass_image())
	_draw()


func _needs(c: Dictionary, hours: float) -> void:
	c.hunger = minf(1.0, c.hunger + hours / 16.0)
	c.thirst = minf(1.0, c.thirst + hours / 18.0)
	if c.hunger < 0.7 and c.thirst < 0.7:
		c.weight = minf(c.weight + 7.0 * hours * (1.0 - c.hunger) * (1.0 - c.thirst), 750.0)
	elif c.hunger > 0.85 or c.thirst > 0.85:
		c.weight -= 3.0 * hours


func _decide(c: Dictionary) -> void:
	if c.thirst > 0.55 and not _tanks.is_empty():
		var best: Vector3 = _tanks[0]
		for t in _tanks:
			if t.distance_to(c.pos) < best.distance_to(c.pos):
				best = t
		var a := _rng.randf() * TAU  # a spot on the rim of the tank
		c.target = best + Vector3(cos(a), 0, sin(a)) * (Windmill.TANK_R + 0.9)
		c.look = best
		c.state = TO_WATER
	elif c.hunger > 0.25:
		var best: Vector3 = c.pos
		var best_g := -1.0
		for k in 8:  # look around for the greenest reachable patch
			var q: Vector3 = c.pos + Vector3(_rng.randf_range(-14, 14), 0, _rng.randf_range(-14, 14))
			if _blocked(q):
				continue
			var g: float = grass[_cell(q)] + _rng.randf() * 0.1
			if g > best_g:
				best_g = g
				best = q
		c.target = best
		c.state = WANDER
	else:
		c.state = IDLE
		c.timer = _rng.randf_range(4.0, 12.0)


func _act(c: Dictionary, delta: float, hours: float) -> void:
	var moving := false
	match c.state:
		WANDER, TO_WATER:
			var to: Vector3 = c.target - c.pos
			to.y = 0.0
			if to.length() < 0.5:
				if c.state == TO_WATER:
					c.state = DRINK
					var l: Vector3 = c.look - c.pos
					c.yaw = atan2(l.x, l.z)
				else:
					c.state = GRAZE
					c.timer = _rng.randf_range(8.0, 20.0)
			else:
				c.yaw = lerp_angle(c.yaw, atan2(to.x, to.z), minf(1.0, delta * 3.0 * day.speed))
				# walking scales with game speed so needs and travel stay in balance when time is fast-forwarded;
				# big steps are taken in small pieces so a cow can't jump through a wall or past its goal
				var left := minf(WALK * day.speed * delta, to.length())
				var dir := Vector3(sin(c.yaw), 0, cos(c.yaw))
				while left > 0.0:
					var s := minf(left, 0.5)
					if _blocked(c.pos + dir * (s + 1.5)):
						_decide(c)  # something in the way: pick a new goal
						break
					c.pos += dir * s
					left -= s
					moving = true
		GRAZE:
			var i := _cell(c.pos)
			var eaten := minf(grass[i], 0.5 * hours)
			grass[i] -= eaten
			c.hunger = maxf(0.0, c.hunger - eaten * 2.0)
			c.timer -= delta
			if grass[i] < 0.12 or c.timer <= 0.0 or c.hunger < 0.05 or c.thirst > 0.6:
				_decide(c)
		DRINK:
			c.thirst = maxf(0.0, c.thirst - 1.5 * hours)
			if c.thirst < 0.05:
				_decide(c)
		IDLE:
			c.timer -= delta
			if c.timer <= 0.0 or c.thirst > 0.55 or c.hunger > 0.4:
				_decide(c)
	var k := minf(1.0, delta * 4.0)
	c.walk = lerpf(c.walk, 1.0 if moving else 0.0, k)
	c.head = lerpf(c.head, 1.0 if c.state in [GRAZE, DRINK] else 0.0, minf(1.0, delta * 2.0))
	if moving:
		c.phase = fmod(c.phase + delta * WALK * minf(day.speed, 3.0) * 3.6, TAU)  # legs capped, or they blur


## Cows keep a little personal space instead of standing inside each other.
func _separate() -> void:
	for i in cows.size():
		for j in range(i + 1, cows.size()):
			var d: Vector3 = cows[j].pos - cows[i].pos
			d.y = 0.0
			var l := d.length()
			if l < 1.7 and l > 0.001:
				var push := d / l * (1.7 - l) * 0.5
				if not _blocked(cows[i].pos - push):
					cows[i].pos -= push
				if not _blocked(cows[j].pos + push):
					cows[j].pos += push


func _draw() -> void:
	_mm.visible_instance_count = cows.size()
	for i in cows.size():
		var c: Dictionary = cows[i]
		var s := lerpf(0.68, 1.05, clampf((c.weight - 180.0) / 520.0, 0.0, 1.0))  # calves are smaller
		_mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, c.yaw).scaled(Vector3.ONE * s), c.pos))
		var head: float = 2.0 + minf(c.dying / 1.2, 1.0) if c.has("dying") else c.head
		_mm.set_instance_custom_data(i, Color(c.phase / TAU, head, c.coat, c.walk))
