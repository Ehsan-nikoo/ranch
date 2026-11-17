## The cattle herd: each cow gets hungry and thirsty, grazes the grass under it, walks to a
## windmill stock tank to drink, and gains or loses weight. In winter, when grass stops growing,
## hungry cows walk to a barn or silo and eat stored hay; cows without room in a barn suffer the cold.
## Drawn as one MultiMesh (1 draw call). Also owns the grass grid that cows eat and that regrows.
class_name Herd
extends Node3D

signal died(cause: String)

const SPAN := 160.0       # grass grid covers world x/z in [-SPAN/2, SPAN/2], same as the ground mask
const N := 40             # grid cells per side (4 m each)
const MAX_COWS := 80
const BOUNDS := Rect2(-60, -60, 120, 120)
const READY_KG := 500.0   # sale weight
const WALK := 1.15        # m/s
const HAY_PER_HUNGER := 0.67  # bales eaten to go from starving to full: about 1 bale per cow per day
# Economy rhythm (see Market): a 220 kg calf reaches READY_KG in about 2 game days on good grass and water,
# so one season (3 days) fits a whole buy-raise-sell cycle. Past READY_KG gains taper off toward MAX_KG,
# so holding a ready cow only pays when the price is about to rise.
const GAIN := 11.0        # kg per game hour when fully fed and watered
const MAX_KG := 680.0
const GROWTH := [1.6, 1.0, 0.35, 0.0]   # grass regrowth per season: spring, summer, autumn, winter
const SEP := 1.7          # personal space between cows, m
enum { WANDER, GRAZE, TO_WATER, DRINK, IDLE, TO_FEED, FEED }

var day: DayCycle
var world: Node3D
var extra_blocked: Array[Rect2] = []  # corral etc.
var cows: Array[Dictionary] = []
var grass := PackedFloat32Array()     # 0..1 per cell
var grass_cap := PackedFloat32Array() # max grass per cell (bare dirt grows none)
var grass_tex: ImageTexture
var hay := 30.0                       # bales in storage
var hay_cap := 0                      # bales the barns and silos can hold
var shelter := 0                      # cows the barns can house in winter
var cost_ms := 0.0                    # smoothed time this script takes per frame, shown in the HUD

var _mm := MultiMesh.new()
var _buf := PackedFloat32Array()
var _rects: Array[Rect2] = []
var _tanks: Array[Vector3] = []
var _feeders: Array[Vector3] = []
var _scan := 0.0
var _tex_t := 0.0
var _grow_hours := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.mesh = CowMesh.mesh()
	_mm.instance_count = MAX_COWS
	_buf.resize(MAX_COWS * 16)  # 12 transform + 4 custom floats per cow
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


func add_cow(pos: Vector3, weight: float) -> Dictionary:
	if cows.size() >= MAX_COWS:
		return {}
	var c := {
		pos = pos, yaw = _rng.randf() * TAU, target = pos, state = IDLE, budget = 0.0, timer = _rng.randf_range(1, 4),
		hunger = _rng.randf_range(0.2, 0.5), thirst = _rng.randf_range(0.1, 0.4), weight = weight,
		phase = 0.0, head = 0.0, walk = 0.0,
		coat = (_rng.randi_range(0, 3) + _rng.randf() * 0.99) / 4.0,  # type in the integer part of coat*4, see cow.gdshader
	}
	cows.append(c)
	return c


## A free spot near `p` (not inside a building, in bounds), or `p` itself if none found.
func free_spot(p: Vector3, radius: float) -> Vector3:
	for k in 20:
		var q := p + Vector3(_rng.randf_range(-radius, radius), 0, _rng.randf_range(-radius, radius))
		if not _blocked(q):
			return q
	return p


func alive() -> Array:
	return cows.filter(func(c): return not c.has("dying"))


func ready_count() -> int:
	return alive().filter(func(c): return c.weight >= READY_KG).size()


## Removes up to `n` cows of at least `min_kg`, heaviest first, and returns their total kg.
func sell(n: int, min_kg: float) -> float:
	var pick := alive().filter(func(c): return c.weight >= min_kg)
	pick.sort_custom(func(a, b): return a.weight > b.weight)
	var kg := 0.0
	for c in pick.slice(0, n):
		kg += c.weight
		cows.erase(c)
	return kg


## Cuts up to `bales` of hay from the fullest pasture cells (two cells of full grass per bale).
## Returns how many bales were made; limited by grass and free storage.
func harvest(bales: int) -> int:
	var want := mini(bales, int(hay_cap - hay))
	if want <= 0:
		return 0
	var order := range(N * N)
	order.sort_custom(func(a, b): return grass[a] > grass[b])
	var got := 0.0
	for i in order:
		if got >= want or grass[i] < 0.5:
			break
		var cut := grass[i] - 0.1  # leave stubble
		grass[i] -= cut
		got += cut * 0.5
	got = floorf(got)
	hay += got
	return int(got)


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


## Re-reads buildings: footprints to avoid, tanks to drink from, feeders, hay storage, shelter.
func _rescan() -> void:
	_rects = extra_blocked.duplicate()
	_tanks.clear()
	_feeders.clear()
	hay_cap = 0
	shelter = 0
	for n in world.get_children():
		if n is not Building or n.has_node("Marker"):  # Marker = still a ghost being placed
			continue
		hay_cap += n.hay_room()
		shelter += n.shelter_room()
		if n.hay_room() > 0:
			_feeders.append(n.feed_spot())
		if n is Windmill:
			_rects.append(n.world_footprint(Rect2(-1.6, -1.6, 3.2, 3.2)))  # tower only, tank is a circle
			_tanks.append(n.to_global(Windmill.TANK))
		else:
			_rects.append(n.world_footprint().grow(0.4))
	hay = minf(hay, hay_cap)


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_scan -= delta
	if _scan <= 0.0:
		_scan = 1.0
		_rescan()
	var hours := delta * day.speed / DayCycle.SECONDS_PER_HOUR
	var season := day.season()
	var n_alive := 0
	for c in cows:
		if not c.has("dying"):
			n_alive += 1
	# cows beyond the barns' room lose weight to the winter cold
	var cold := 0.0
	if season == DayCycle.WINTER and n_alive > 0:
		cold = maxf(0.0, 1.0 - float(shelter) / n_alive) * 1.5
	for c in cows:
		if c.has("dying"):  # plays the model's death clip, lies there a moment, then is gone
			c.dying += delta
			c.walk = 0.0
			continue
		_needs(c, hours, cold)
		_act(c, delta, hours, season)
		if c.weight < 180.0:
			c.dying = 0.0
			died.emit("cold" if cold > 0.0 and c.hunger < 0.85 and c.thirst < 0.85 else ("thirst" if c.thirst > c.hunger else "hunger"))
	_separate()
	for c in cows.filter(func(c): return c.has("dying") and c.dying > 5.0):
		cows.erase(c)
	# grass regrowth is slow, so it's applied twice a second instead of every frame
	_grow_hours += hours
	_tex_t -= delta
	if _tex_t <= 0.0:
		_tex_t = 0.5
		var g: float = _grow_hours / 96.0 * GROWTH[season]  # full regrowth in about four summer days
		_grow_hours = 0.0
		if g > 0.0:
			for i in N * N:
				grass[i] = minf(grass_cap[i], grass[i] + g)
		grass_tex.update(_grass_image())
	_draw()
	cost_ms = lerpf(cost_ms, (Time.get_ticks_usec() - t0) / 1000.0, 0.05)


func _needs(c: Dictionary, hours: float, cold: float) -> void:
	c.hunger = minf(1.0, c.hunger + hours / 16.0)
	c.thirst = minf(1.0, c.thirst + hours / 18.0)
	if c.hunger < 0.7 and c.thirst < 0.7:
		var taper := 1.0 if c.weight < READY_KG else clampf((MAX_KG - c.weight) / (MAX_KG - READY_KG), 0.0, 1.0) ** 2
		c.weight = minf(c.weight + GAIN * hours * (1.0 - c.hunger) * (1.0 - c.thirst) * taper, MAX_KG)
	elif c.hunger > 0.85 or c.thirst > 0.85:
		c.weight -= 4.0 * hours
	c.weight -= cold * hours


func _nearest(points: Array[Vector3], p: Vector3) -> Vector3:
	var best := points[0]
	for t in points:
		if t.distance_to(p) < best.distance_to(p):
			best = t
	return best


func _decide(c: Dictionary) -> void:
	var winter := day.season() == DayCycle.WINTER
	if c.thirst > 0.55 and not _tanks.is_empty():
		var t := _nearest(_tanks, c.pos)
		for k in 16:  # a free spot on the rim of the tank (the tower side is taken by its footings)
			var a := _rng.randf() * TAU
			c.target = t + Vector3(cos(a), 0, sin(a)) * (Windmill.TANK_R + 0.9)
			if not _blocked(c.target):
				break
		c.look = t
		_go(c, c.target, TO_WATER)
	elif winter and c.hunger > 0.3 and hay >= 0.5 and not _feeders.is_empty():
		_go(c, free_spot(_nearest(_feeders, c.pos), 5.0), TO_FEED)  # crowd around the hay at the barn door
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
		_go(c, best, WANDER)
	else:
		c.state = IDLE
		c.timer = _rng.randf_range(4.0, 12.0)


## Walk to `target`, with a time budget: a cow that's still not there long after it should be
## (wedged between buildings) gives up, steps out to open ground and thinks again.
func _go(c: Dictionary, target: Vector3, state: int) -> void:
	c.target = target
	c.state = state
	c.budget = c.pos.distance_to(target) / WALK * 2.5 + 6.0


func _act(c: Dictionary, delta: float, hours: float, season: int) -> void:
	var moving := false
	match c.state:
		WANDER, TO_WATER, TO_FEED:
			var to: Vector3 = c.target - c.pos
			to.y = 0.0
			# at a crowded tank or hay pile the exact spot is often taken by a neighbour; close is good enough
			if to.length() < (0.5 if c.state == WANDER else 1.4):
				if c.state == TO_WATER:
					c.state = DRINK
					var l: Vector3 = c.look - c.pos
					c.yaw = atan2(l.x, l.z)
				elif c.state == TO_FEED:
					c.state = FEED
				else:
					c.state = GRAZE
					c.timer = _rng.randf_range(8.0, 20.0)
			elif c.budget < 0.0:
				_go(c, free_spot(c.pos, 8.0), WANDER)
			else:
				c.budget -= delta * day.speed
				c.yaw = lerp_angle(c.yaw, atan2(to.x, to.z), minf(1.0, delta * 3.0 * day.speed))
				# walking scales with game speed so needs and travel stay in balance when time is fast-forwarded;
				# big steps are taken in small pieces so a cow can't jump through a wall or past its goal
				var left := minf(WALK * day.speed * delta, to.length())
				var dir := Vector3(sin(c.yaw), 0, cos(c.yaw))
				while left > 0.0:
					var s := minf(left, 0.5)
					# look a little ahead for walls, but never past the goal: goals sit right beside the
					# tank rim or barn door, and seeing those made cows turn back forever
					var ahead := minf(s + 1.5, (c.target - c.pos).length())
					if _blocked(c.pos + dir * ahead):
						# something in the way: veer left or right around it (a tower, a barn corner)
						var side := _detour(c.pos, dir, ahead)
						if side == Vector3.ZERO:
							_go(c, free_spot(c.pos, 8.0), WANDER)  # boxed in: step out to open ground
							break
						dir = side
						c.yaw = atan2(dir.x, dir.z)
					c.pos += dir * s
					left -= s
					moving = true
		GRAZE:
			var i := _cell(c.pos)
			# under winter snow a cow only gets a little of the grass that's there
			var eaten := minf(grass[i], 0.5 * hours)
			grass[i] -= eaten
			c.hunger = maxf(0.0, c.hunger - eaten * (0.6 if season == DayCycle.WINTER else 2.0))
			c.timer -= delta
			if grass[i] < 0.12 or c.timer <= 0.0 or c.hunger < 0.05 or c.thirst > 0.6:
				_decide(c)
		FEED:
			var ate := minf(1.2 * hours, c.hunger)
			ate = minf(ate, hay / HAY_PER_HUNGER)
			c.hunger -= ate
			hay -= ate * HAY_PER_HUNGER
			if c.hunger < 0.05 or hay < 0.01 or c.thirst > 0.6:
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
	c.head = lerpf(c.head, 1.0 if c.state in [GRAZE, DRINK, FEED] else 0.0, minf(1.0, delta * 2.0))
	if moving:
		c.phase = fmod(c.phase + delta * WALK * minf(day.speed, 3.0) * 3.6, TAU)  # legs capped, or they blur


## First direction, turning gradually further from `dir`, that is clear for `ahead` meters.
func _detour(p: Vector3, dir: Vector3, ahead: float) -> Vector3:
	for ang in [0.5, -0.5, 1.0, -1.0, 1.5, -1.5, 2.2, -2.2]:
		var d := dir.rotated(Vector3.UP, ang)
		if not _blocked(p + d * ahead):
			return d
	return Vector3.ZERO


## Cows keep a little personal space instead of standing inside each other.
## Bucketed into a grid so only neighbours are compared (all pairs got slow on phones with big herds).
func _separate() -> void:
	var grid := {}
	for i in cows.size():
		var p: Vector3 = cows[i].pos
		var key := Vector2i(floori(p.x / SEP), floori(p.z / SEP))
		if not grid.has(key):
			grid[key] = []
		grid[key].append(i)
	for i in cows.size():
		var p: Vector3 = cows[i].pos
		var kx := floori(p.x / SEP)
		var kz := floori(p.z / SEP)
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for j in grid.get(Vector2i(kx + dx, kz + dz), []):
					if j <= i:
						continue
					var d: Vector3 = cows[j].pos - cows[i].pos
					d.y = 0.0
					var l := d.length()
					if l < SEP and l > 0.001:
						var push := d / l * (SEP - l) * 0.5
						if not _blocked(cows[i].pos - push):
							cows[i].pos -= push
						if not _blocked(cows[j].pos + push):
							cows[j].pos += push


## All cows go to the GPU in one buffer upload instead of two calls per cow.
func _draw() -> void:
	_buf.fill(0.0)
	for i in cows.size():
		var c: Dictionary = cows[i]
		var s := lerpf(0.68, 1.05, clampf((c.weight - 180.0) / (MAX_KG - 180.0), 0.0, 1.0))  # calves are smaller
		var cs := cos(c.yaw) * s
		var sn := sin(c.yaw) * s
		var o := i * 16
		# rows of Basis(UP, yaw) * s, then origin; layout = MultiMesh TRANSFORM_3D + custom data
		_buf[o] = cs;   _buf[o + 1] = 0.0; _buf[o + 2] = sn;   _buf[o + 3] = c.pos.x
		_buf[o + 4] = 0.0; _buf[o + 5] = s; _buf[o + 6] = 0.0;  _buf[o + 7] = c.pos.y
		_buf[o + 8] = -sn; _buf[o + 9] = 0.0; _buf[o + 10] = cs; _buf[o + 11] = c.pos.z
		_buf[o + 12] = c.phase / TAU
		_buf[o + 13] = 2.0 + minf(c.dying / 1.2, 1.0) if c.has("dying") else c.head
		_buf[o + 14] = c.coat
		_buf[o + 15] = c.walk
	_mm.buffer = _buf
	_mm.visible_instance_count = cows.size()


# ---------- save / load ----------

func to_save() -> Dictionary:
	return {
		hay = hay,
		grass = Marshalls.raw_to_base64(grass.to_byte_array()),
		cows = alive().map(func(c): return [c.pos.x, c.pos.z, c.yaw, c.hunger, c.thirst, c.weight, c.coat]),
	}


func from_save(d: Dictionary) -> void:
	hay = d.hay
	var g := Marshalls.base64_to_raw(d.grass).to_float32_array()
	if g.size() == N * N:
		grass = g
		grass_tex.update(_grass_image())
	for v in d.cows:
		var c := add_cow(Vector3(v[0], 0, v[1]), v[5])
		if c.is_empty():
			break
		c.yaw = v[2]
		c.hunger = v[3]
		c.thirst = v[4]
		c.coat = v[6]
