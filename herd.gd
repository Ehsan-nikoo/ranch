## The cattle herd: each cow gets hungry and thirsty, grazes the grass under it, walks to a
## windmill stock tank to drink, and gains or loses weight. In winter, when grass stops growing,
## hungry cows walk to a barn or silo and eat stored hay; cows without room in a barn suffer the cold.
## Breeding: a bull in the herd gets well-fed breeding cows in calf, and each calves after GESTATION.
## Health: cows can fall sick (more often when hungry, thirsty, cold or around other sick cows); a sick
## cow loses weight and dies if no vet comes in time. Vaccinated cows rarely catch anything.
## Drawn as one MultiMesh (1 draw call). Also owns the grass grid that cows eat and that regrows.
class_name Herd
extends Node3D

signal died(cause: String)
signal born
signal fell_sick

const SPAN := 240.0       # grass grid covers world x/z in [-SPAN/2, SPAN/2], same as the ground mask
const N := 60             # grid cells per side (4 m each)
const MAX_COWS := 80
const READY_KG := 500.0   # sale weight
const WALK := 1.15        # m/s
const HAY_PER_HUNGER := 0.67  # bales eaten to go from starving to full: about 1 bale per cow per day
# Economy rhythm (see Market): a 220 kg calf reaches READY_KG in about 2 game days on good grass and water,
# so one season (3 days) fits a whole buy-raise-sell cycle. Past READY_KG gains taper off toward MAX_KG,
# so holding a ready cow only pays when the price is about to rise.
const GAIN := 4.5         # kg per game hour when fully fed and watered: a calf takes about 4 days to fatten
const MAX_KG := 680.0
const GROWTH := [1.6, 1.0, 0.35, 0.0]   # grass regrowth per season: spring, summer, autumn, winter
const SEP := 1.7          # personal space between cows, m
enum { WANDER, GRAZE, TO_WATER, DRINK, IDLE, TO_FEED, FEED, TO_PEN, SLEEP }
# FEEDER: raised for sale (bought calves and the calves born here); BREEDER: kept to calve; BULL: sires
enum { FEEDER, BREEDER, BULL }
const BIRTH_KG := 90.0
const GESTATION := 96.0   # game hours in calf: 4 days. With the rest and the wait for the bull, about 2 calves a year
const REST := 24.0        # hours after calving before a cow takes the bull again
const BREED_KG := 400.0   # a breeding cow this thin doesn't come in calf
const KEEP_KG := 350.0    # a feeder heifer can join the breeding herd from this weight
const COWS_PER_BULL := 20
const SICK_RATE := 0.0008  # chance per cow per game hour when well kept; stress and contagion add to it
const SICK_DEATH := 36.0   # game hours a sick cow lasts without a vet
const VACCINE_DAYS := 12   # one year
# breeds: name, what it's like, weight gain, cold, thirst, sale price per kg, calf price (all multipliers)
const BREEDS := [
	{name = "معمولی", about = "همه‌جوره، نه خیلی گرون نه خیلی ارزون", gain = 1.0, cold = 1.0, thirst = 1.0, sale = 1.0, calf = 1.0},
	{name = "سیاه", about = "زود چاق می‌شه و گوشتش گرون‌تره، ولی گرون‌تره و سرما اذیتش می‌کنه", gain = 1.2, cold = 1.25, thirst = 1.0, sale = 1.1, calf = 1.5},
	{name = "شاخ‌بلند", about = "ارزون و جون‌سخت: سرما و تشنگی کمتر اذیتش می‌کنه، ولی دیرتر چاق می‌شه", gain = 0.85, cold = 0.5, thirst = 0.7, sale = 0.95, calf = 0.75},
]
const NAMES := ["گلی", "ابری", "خال‌خالی", "ماه‌پری", "شکلات", "پنبه", "قهوه", "زری", "نازی", "سیاهه", "بلوطی", "عسل",
	"مخملی", "لیلی", "تپلی", "شیرین", "گندم", "کهربا", "ستاره", "دودی", "خانم‌گل", "قندی", "فندق", "نارنج", "مهتاب", "پاپی",
	"کوکو", "بابونه", "زعفرون", "دارچین", "خرمالو", "گیلاس"]
const BULL_NAMES := ["رستم", "پهلوون", "غول", "سلطان", "تندر", "داش‌آکل", "سهراب", "شیرعلی"]

var day: DayCycle
var world: Node3D
var land: Land             # cows stay on owned plots
var extra_blocked: Array[Rect2] = []  # corral etc.
var cows: Array[Dictionary] = []
var grass := PackedFloat32Array()     # 0..1 per cell
var grass_cap := PackedFloat32Array() # max grass per cell (bare dirt grows none)
var grass_tex: ImageTexture
var hay := 30.0                       # bales in storage
var hay_cap := 0                      # bales the barns and silos can hold
var shelter := 0                      # cows the barns can house in winter
var cost_ms := 0.0                    # smoothed time this script takes per frame, shown in the HUD
# set by Events (drought, blizzard) and Workers (herders, too few hands)
var growth_mul := 1.0
var thirst_mul := 1.0
var cold_mul := 1.0
var sick_mul := 1.0
var cure_mul := 1.0
var gain_mul := 1.0       # the fattening pen: sale cattle put on weight faster...
var appetite_mul := 1.0   # ...and eat more
var rain_mul := 1.0       # set by Weather: rain greens the pasture...
var wet_mul := 1.0        # ...and the cows drink less

var _mm := MultiMesh.new()
var _buf := PackedFloat32Array()
var _rects: Array[Rect2] = []
var _tanks: Array[Vector3] = []
var _tank_r: Array[float] = []        # radius of each water: windmill tank or pond
var _feeders: Array[Vector3] = []
var _pens: Array[Vector3] = []        # barn doors: at night cows go in and sleep there
var _pen_room: Array[int] = []
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


func add_cow(pos: Vector3, weight: float, kind := FEEDER, female := -1, breed := 0) -> Dictionary:
	if cows.size() >= MAX_COWS:
		return {}
	var c := {
		breed = breed, fav = false,
		name = BULL_NAMES[_rng.randi() % BULL_NAMES.size()] if kind == BULL else NAMES[_rng.randi() % NAMES.size()],
		kind = kind, female = (kind == BREEDER) if kind != FEEDER else (_rng.randf() < 0.5 if female < 0 else female == 1),
		preg = 0.0,      # game hours left in calf, 0 = open
		rest = 0.0,      # hours left before she can be bred again
		sick = -1.0,     # hours since falling sick, -1 = healthy
		vacc = -1,       # vaccinated until this day
		peak = weight,   # heaviest so far: a cow dies when she wastes to well under it

		pos = pos, yaw = _rng.randf() * TAU, target = pos, state = IDLE, budget = 0.0, timer = _rng.randf_range(1, 4),
		hunger = _rng.randf_range(0.2, 0.5), thirst = _rng.randf_range(0.1, 0.4), weight = weight,
		phase = 0.0, head = 0.0, walk = 0.0,
		coat = (_rng.randi_range(0, 3) + _rng.randf() * 0.99) / 4.0,  # type in the integer part of coat*4, see cow.gdshader
	}
	if breed == 1:  # black all over
		c.coat = (3.0 + _rng.randf() * 0.99) / 4.0
	elif breed == 2:  # red and white
		c.coat = (1.0 + _rng.randf() * 0.99) / 4.0
	elif floorf(c.coat * 4.0) == 3.0:  # the plain kind isn't black
		c.coat = (_rng.randi_range(0, 2) + _rng.randf() * 0.99) / 4.0
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


## Cattle raised for sale; breeding cows and bulls are never sold with them.
func feeders() -> Array:
	return cows.filter(func(c): return not c.has("dying") and c.kind == FEEDER)


func of_kind(kind: int) -> Array:
	return cows.filter(func(c): return not c.has("dying") and c.kind == kind)


func ready_count() -> int:
	return feeders().filter(func(c): return c.weight >= READY_KG and not c.fav).size()


func sick_count() -> int:
	return alive().filter(func(c): return c.sick >= 0.0).size()


func unvaccinated() -> Array:
	return alive().filter(func(c): return c.vacc < day.day)


## The vet treats every sick cow; returns how many.
func cure() -> int:
	var n := 0
	for c in alive():
		if c.sick >= 0.0:
			c.sick = -1.0
			n += 1
	return n


## Vaccinates every cow that isn't covered; returns how many.
func vaccinate() -> int:
	var todo := unvaccinated()
	for c in todo:
		c.vacc = day.day + VACCINE_DAYS
	return todo.size()


## The heaviest healthy feeder heifer of at least KEEP_KG joins the breeding herd.
func keep_heifer() -> bool:
	var pick := feeders().filter(func(c): return c.female and c.weight >= KEEP_KG and c.sick < 0.0)
	if pick.is_empty():
		return false
	pick.sort_custom(func(a, b): return a.weight > b.weight)
	pick[0].kind = BREEDER
	return true


## Removes up to `n` feeders of at least `min_kg`, heaviest first (never a favourite), and returns
## their total kg, each counted at its breed's price (a black cow's kilo fetches more).
func sell(n: int, min_kg: float) -> float:
	var pick := sale_lot(n, min_kg)
	var kg := 0.0
	for c in pick:
		kg += c.weight * BREEDS[c.breed].sale
		cows.erase(c)
	return kg


## The cows `sell` would take.
func sale_lot(n: int, min_kg: float) -> Array:
	var pick := feeders().filter(func(c): return c.weight >= min_kg and not c.fav)
	pick.sort_custom(func(a, b): return a.weight > b.weight)
	return pick.slice(0, n)


## One cow sold on her own at today's per-kg price; returns the cash.
func sell_one(c: Dictionary, per_kg: float) -> int:
	cows.erase(c)
	return int(c.weight * BREEDS[c.breed].sale * per_kg)


## Animals lost to wolves (the smallest first) or rustlers (the heaviest feeders first); returns how many.
func take(n: int, smallest: bool) -> int:
	var pick := alive() if smallest else feeders()
	pick.sort_custom(func(a, b): return a.weight < b.weight if smallest else a.weight > b.weight)
	pick = pick.slice(0, n)
	for c in pick:
		cows.erase(c)
	return pick.size()


## Every unvaccinated cow falls sick with chance `p`; returns how many did.
func outbreak(p: float) -> int:
	var n := 0
	for c in alive():
		if c.sick < 0.0 and c.vacc < day.day and _rng.randf() < p:
			c.sick = 0.0
			n += 1
	return n


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
		if not land.is_open(Vector3((i % N + 0.5) * SPAN / N - SPAN * 0.5, 0, (i / N + 0.5) * SPAN / N - SPAN * 0.5)):
			continue  # only cut hay on your own land
		var cut := grass[i] - 0.1  # leave stubble
		grass[i] -= cut
		got += cut * 0.5
	got = floorf(got)
	hay += got
	return int(got)


func _blocked(p: Vector3) -> bool:
	if not land.is_open(p):
		return true
	var q := Vector2(p.x, p.z)
	for r in _rects:
		if r.has_point(q):
			return true
	for i in _tanks.size():
		if Vector2(_tanks[i].x, _tanks[i].z).distance_to(q) < _tank_r[i] + 0.6:
			return true
	return false


## Re-reads buildings: footprints to avoid, tanks to drink from, feeders, hay storage, shelter.
func _rescan() -> void:
	_rects = extra_blocked.duplicate()
	_tanks.clear()
	_tank_r.clear()
	_feeders.clear()
	_pens.clear()
	_pen_room.clear()
	hay_cap = 0
	shelter = 0
	for n in world.get_children():
		if n is not Building or n.has_node("Marker"):  # Marker = still a ghost being placed
			continue
		if n.work_left > 0.0 and not (n.upgrading and (n is Windmill or n is Pond)):
			_rects.append(n.work_rect.grow(0.4))  # a building site: keep off it (but not off the water)
		if not n.works():
			continue
		hay_cap += n.hay_room()
		shelter += n.shelter_room()
		if n.hay_room() > 0:
			_feeders.append(n.feed_spot())
		if n.shelter_room() > 0:
			_pens.append(n.door())
			_pen_room.append(n.shelter_room())
		if n is Windmill:
			_rects.append(n.world_footprint(Rect2(-1.6, -1.6, 3.2, 3.2)))  # tower only, tank is a circle
			if not n.broken:
				for t in n.tanks():
					_tanks.append(n.to_global(t))
					_tank_r.append(Windmill.TANK_R * n.scale.x)
		elif n is Pond:  # round water, no fence: cows walk right up to the rim
			_tanks.append(n.global_position)
			_tank_r.append(Pond.R * n.scale.x)
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
		cold = maxf(0.0, 1.0 - float(shelter) / n_alive) * 0.6 * cold_mul
	# one bull serves COWS_PER_BULL cows; sick cows spread it to the rest
	var bulls := 0
	var breeders := 0
	var sick := 0
	for c in cows:
		if not c.has("dying"):
			bulls += int(c.kind == BULL and c.sick < 0.0)
			breeders += int(c.kind == BREEDER)
			sick += int(c.sick >= 0.0)
	var service := minf(1.0, float(bulls * COWS_PER_BULL) / maxi(breeders, 1))
	var spread := float(sick) / maxi(n_alive, 1)
	var calving: Array[Dictionary] = []
	for c in cows:
		if c.has("dying"):  # plays the model's death clip, lies there a moment, then is gone
			c.dying += delta
			c.walk = 0.0
			continue
		_needs(c, hours, cold)
		_health(c, hours, cold, spread)
		if c.kind == BREEDER and _breed(c, hours, service, season):
			calving.append(c)
		_act(c, delta, hours, season)
		c.peak = maxf(c.peak, c.weight)
		if c.sick > SICK_DEATH or c.weight < minf(180.0, c.peak * 0.75):
			c.dying = 0.0
			if c.sick > SICK_DEATH:
				died.emit("sickness")
			else:
				died.emit("cold" if cold > 0.0 and c.hunger < 0.85 and c.thirst < 0.85 else ("thirst" if c.thirst > c.hunger else "hunger"))
	for m in calving:  # added after the loop: the list can't grow while it's walked
		var calf := add_cow(free_spot(m.pos + Vector3(sin(m.yaw), 0, cos(m.yaw)) * -1.5, 1.5), BIRTH_KG, FEEDER, -1, m.breed)
		if not calf.is_empty():
			if _rng.randf() < 0.6:  # takes after its mother's coat
				calf.coat = floorf(m.coat * 4.0) / 4.0 + _rng.randf() * 0.99 / 4.0
			calf.hunger = 0.1
			calf.thirst = 0.1
			born.emit()
	_separate()
	for c in cows.filter(func(c): return c.has("dying") and c.dying > 5.0):
		cows.erase(c)
	# grass regrowth is slow, so it's applied twice a second instead of every frame
	_grow_hours += hours
	_tex_t -= delta
	if _tex_t <= 0.0:
		_tex_t = 0.5
		var g: float = _grow_hours / 96.0 * GROWTH[season] * growth_mul * rain_mul  # full regrowth in about four summer days
		_grow_hours = 0.0
		if g > 0.0:
			for i in N * N:
				grass[i] = minf(grass_cap[i], grass[i] + g)
		grass_tex.update(_grass_image())
	_draw()
	cost_ms = lerpf(cost_ms, (Time.get_ticks_usec() - t0) / 1000.0, 0.05)


func _needs(c: Dictionary, hours: float, cold: float) -> void:
	if c.state == SLEEP:  # resting through the night: hunger and thirst creep up slowly
		hours *= 0.35
	var fat: bool = c.kind == FEEDER  # the fattening pen feeds the sale cattle
	var br: Dictionary = BREEDS[c.breed]
	c.hunger = minf(1.0, c.hunger + hours / (13.0 if c.preg > 0.0 else 16.0) * (appetite_mul if fat else 1.0))  # eating for two
	c.thirst = minf(1.0, c.thirst + hours / 18.0 * thirst_mul * wet_mul * br.thirst)
	if c.sick >= 0.0:
		c.weight -= 1.0 * hours  # off its feed: no gain while sick
	elif c.hunger < 0.7 and c.thirst < 0.7:
		var taper := 1.0 if c.weight < READY_KG else clampf((MAX_KG - c.weight) / (MAX_KG - READY_KG), 0.0, 1.0) ** 2
		c.weight = minf(c.weight + GAIN * br.gain * (gain_mul if fat else 1.0) * hours * (1.0 - c.hunger) * (1.0 - c.thirst) * taper, MAX_KG)
	elif c.hunger > 0.85 or c.thirst > 0.85:
		c.weight -= 1.6 * hours
	c.weight -= cold * br.cold * hours


## Falls sick at random, more often under stress or near sick cows; vaccinated cows seldom do.
## A sick cow may shake it off by itself, but most need the vet before SICK_DEATH.
func _health(c: Dictionary, hours: float, cold: float, spread: float) -> void:
	if c.sick >= 0.0:
		c.sick += hours
		if _rng.randf() < 0.015 * cure_mul * hours:
			c.sick = -1.0
		return
	var stress := 1.0 + (2.0 if c.hunger > 0.85 or c.thirst > 0.85 else 0.0) + cold + (0.5 if c.weight < 150.0 else 0.0)
	var rate := (SICK_RATE * stress + 0.012 * spread) * sick_mul
	if c.vacc >= day.day:
		rate *= 0.1
	if _rng.randf() < rate * hours:
		c.sick = 0.0
		fell_sick.emit()


## Carries a calf to term; takes the bull when open, rested, healthy and in good condition
## (not in winter: cows here calve in spring, summer and autumn). True on the hour she calves.
func _breed(c: Dictionary, hours: float, service: float, season: int) -> bool:
	if c.preg > 0.0:
		c.preg -= hours
		if c.preg <= 0.0:
			c.preg = 0.0
			c.rest = REST
			return true
		return false
	c.rest = maxf(0.0, c.rest - hours)
	if c.rest <= 0.0 and c.sick < 0.0 and c.weight >= BREED_KG and c.hunger < 0.7 and season != DayCycle.WINTER:
		if _rng.randf() < 0.05 * service * hours:
			c.preg = GESTATION
	return false


func _nearest(points: Array[Vector3], p: Vector3) -> Vector3:
	var best := points[0]
	for t in points:
		if t.distance_to(p) < best.distance_to(p):
			best = t
	return best


## Night time: cows head for the barns and sleep till morning.
func night() -> bool:
	return day.hour >= 20.5 or day.hour < 5.5


func _decide(c: Dictionary) -> void:
	var winter := day.season() == DayCycle.WINTER
	if c.get("inside", false):  # morning (or a need) brings her out of the barn door
		c.inside = false
		c.pos = free_spot(c.pos, 2.5)
	if night() and c.thirst < 0.75 and c.hunger < 0.75:
		_bed(c)
		return
	if c.thirst > 0.55 and not _tanks.is_empty():
		var t := _nearest(_tanks, c.pos)
		var r := _tank_r[_tanks.find(t)]
		for k in 16:  # a free spot on the rim of the tank (the tower side is taken by its footings)
			var a := _rng.randf() * TAU
			c.target = t + Vector3(cos(a), 0, sin(a)) * (r + 0.9)
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


## A place for the night: a barn with room left, or lie down where she is.
func _bed(c: Dictionary) -> void:
	var used := []
	used.resize(_pens.size())
	used.fill(0)
	for o in cows:
		if o != c and o.get("pen", -1) >= 0 and o.get("pen", -1) < _pens.size() and o.state in [TO_PEN, SLEEP]:
			used[o.pen] += 1
	var best := -1
	for i in _pens.size():
		if used[i] < _pen_room[i] and (best < 0 or _pens[i].distance_to(c.pos) < _pens[best].distance_to(c.pos)):
			best = i
	c.pen = best
	if best >= 0:
		_go(c, _pens[best], TO_PEN)
	else:
		c.state = SLEEP
		c.timer = 1.0


## Walk to `target`, with a time budget: a cow that's still not there long after it should be
## (wedged between buildings) gives up, steps out to open ground and thinks again.
func _go(c: Dictionary, target: Vector3, state: int) -> void:
	c.target = target
	c.state = state
	c.budget = c.pos.distance_to(target) / WALK * 2.5 + 6.0


func _act(c: Dictionary, delta: float, hours: float, season: int) -> void:
	var moving := false
	match c.state:
		WANDER, TO_WATER, TO_FEED, TO_PEN:
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
				elif c.state == TO_PEN:
					c.state = SLEEP
					c.inside = true
					c.timer = 1.0
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
				var left := minf(WALK * day.speed * delta * (0.5 if c.sick >= 0.0 else 1.0), to.length())
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
		SLEEP:
			c.timer -= delta
			if c.timer <= 0.0:
				c.timer = 1.0
				if not night() or c.thirst > 0.85 or c.hunger > 0.85:
					_decide(c)
		IDLE:
			c.timer -= delta
			if c.timer <= 0.0 or c.thirst > 0.55 or c.hunger > 0.4:
				_decide(c)
	var k := minf(1.0, delta * 4.0)
	c.walk = lerpf(c.walk, 1.0 if moving else 0.0, k)
	var down := 1.0 if c.state in [GRAZE, DRINK, FEED, SLEEP] else (0.55 if c.sick >= 0.0 else 0.0)  # sick cows hang their heads
	c.head = lerpf(c.head, down, minf(1.0, delta * 2.0))
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
		if cows[i].get("inside", false):  # in the barn: out of the way
			continue
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
		var w: float = c.weight
		var s := lerpf(0.68, 1.05, clampf((w - 180.0) / (MAX_KG - 180.0), 0.0, 1.0))  # calves are smaller
		if w < 180.0:  # newborns
			s = lerpf(0.42, 0.68, clampf((w - BIRTH_KG) / (180.0 - BIRTH_KG), 0.0, 1.0))
		if c.kind == BULL:
			s *= 1.12
		if c.get("inside", false):
			s = 0.0  # asleep in the barn
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
		cows = alive().map(func(c): return [c.pos.x, c.pos.z, c.yaw, c.hunger, c.thirst, c.weight, c.coat,
			c.kind, int(c.female), c.preg, c.rest, c.sick, c.vacc, c.peak, c.name, int(c.fav), c.breed]),
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
		if v.size() >= 14:  # saves from before breeding and health have only the first seven
			c.kind = int(v[7])
			c.female = v[8] == 1
			c.preg = v[9]
			c.rest = v[10]
			c.sick = v[11]
			c.vacc = int(v[12])
			c.peak = v[13]
		if v.size() >= 17:  # names, favourites and breeds came later
			c.name = v[14]
			c.fav = v[15] == 1
			c.breed = int(v[16])
