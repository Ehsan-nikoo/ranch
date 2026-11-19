## Horse breeding: buy mares and stallions, let them breed, raise the foals and sell them. A horse has
## 1 to 5 stars (how good a horse it is). A foal gets about its parents' average and often a little
## better, so breeding your best pairs pays more and more. Horses need stalls (HorseStable); by day they
## graze in the corral (or in front of the stable), at night they go in. A corral grows foals faster.
class_name Horses
extends Node3D

const ADULT := 8.0          # game days until a foal is grown
const GESTATION := 96.0     # game hours in foal: 4 days
const REST := 36.0          # hours after foaling before a mare takes the stallion again
const FOAL_CHANCE := 0.45   # each day, for a grown mare with a grown stallion on the ranch
const UPKEEP := 10          # dollars a horse a day: hay, oats and shoes
const MARE := 1000          # price of a mare (1 or 2 stars)
const STALLION := 2000      # price of a stallion (2 or 3 stars)
const NAMES := ["باد", "طوفان", "یال‌طلا", "ستاره", "غزال", "آهو", "شبرنگ", "برق", "تندباد", "سپیده", "کهر", "نسیم",
	"مه‌پاره", "زرین", "شاهین", "سیمین", "رعد", "خورشید", "مهتاب", "سرخه", "شیرین", "پیچک", "آتش", "گلبو"]
const WALK := 1.1           # m/s grazing pace

var day: DayCycle
var world: Node3D
var herd: Herd
var builder: Builder
var notify: Callable
var list: Array = []        # {id, name, female, age (days), stars, coat, foal (hours left, 0 = none), sire (foal's stars), rest}
var _next_id := 1
var version := 0            # goes up whenever the list or a horse changes, for the board
var _shown := {}            # id -> {node, target, wait, phase}
var _rng := RandomNumberGenerator.new()
static var _no_saddle: ShaderMaterial


func _ready() -> void:
	_rng.randomize()


# ---------- the horses ----------

## Stalls on the ranch: every finished stable counts.
func room() -> int:
	var n := 0
	for b in world.get_children():
		if b is HorseStable and b.works():
			n += b.stalls()
	return n


func grown(h: Dictionary) -> bool:
	return h.age >= ADULT


## What a buyer pays: good horses fetch a lot more; a foal goes cheap.
func value(h: Dictionary) -> int:
	var v: int = 500 + 200 * h.stars * h.stars
	return v if grown(h) else int(v * 0.45 / 10.0) * 10


func _add(female: bool, stars: int, age: float) -> Dictionary:
	var used := list.map(func(x): return x.name)
	var free := NAMES.filter(func(n): return not n in used)
	var nm: String = free[_rng.randi() % free.size()] if not free.is_empty() else "اسب %s" % UiTheme.fa(_next_id)
	var h := {id = _next_id, name = nm, female = female, age = age, stars = stars, coat = _rng.randi() % Cowboy.COATS.size(), foal = 0.0, sire = 0, rest = 0.0}
	_next_id += 1
	list.append(h)
	version += 1
	return h


func can_buy(female: bool) -> bool:
	return list.size() < room() and builder.money >= (MARE if female else STALLION)


func buy(female: bool) -> void:
	if not can_buy(female):
		return
	builder.add_money(-(MARE if female else STALLION), "horses")
	var h := _add(female, _rng.randi_range(1, 2) if female else _rng.randi_range(2, 3), ADULT + _rng.randf_range(0.0, 6.0))
	notify.call("%s اومد به رنچ (%s)" % [h.name, stars_text(h.stars)])


func sell(h: Dictionary) -> void:
	if not h in list:
		return
	builder.add_money(value(h), "horses")
	list.erase(h)
	version += 1
	notify.call("%s رو فروختی:  %s+ دلار" % [h.name, UiTheme.fa(value(h))])


static func stars_text(n: int) -> String:
	return "★".repeat(n) + "☆".repeat(5 - n)


## The corral that hurries the foals along (the best one), or null.
func _corral() -> Corral:
	var best: Corral = null
	for b in world.get_children():
		if b is Corral and b.works() and (best == null or b.level > best.level):
			best = b
	return best


func _stable() -> HorseStable:
	for b in world.get_children():
		if b is HorseStable and b.works():
			return b
	return null


## Each morning: feed bill, the foals grow, mares with a stallion about may come in foal.
func new_day(_d: int) -> void:
	if list.is_empty():
		return
	version += 1
	builder.add_money(-UPKEEP * list.size(), "horses")
	var c := _corral()
	var grow := c.foal_mul() if c else 1.0
	var stallion := list.any(func(h): return not h.female and grown(h))
	var best_sire := 0
	for h in list:
		if not h.female and grown(h):
			best_sire = maxi(best_sire, h.stars)
	for h in list:
		var was := grown(h)
		h.age += grow if not grown(h) else 1.0
		if not was and grown(h):
			notify.call("%s بزرگ شد: یه اسب %s" % [h.name, stars_text(h.stars)])
		if h.female and grown(h) and stallion and h.foal <= 0.0 and h.rest <= 0.0 and _rng.randf() < FOAL_CHANCE:
			h.foal = GESTATION
			h.sire = best_sire
			notify.call("%s حامله شد" % h.name)


func _tick(hours: float) -> void:
	for h in list.duplicate():
		h.rest = maxf(0.0, h.rest - hours)
		if h.foal > 0.0:
			h.foal -= hours
			if h.foal <= 0.0:
				h.foal = 0.0
				h.rest = REST
				# about the parents' average, more often a little better than worse
				var s := clampi(roundi((h.stars + h.sire) * 0.5 + _rng.randf_range(-0.6, 1.0)), 1, 5)
				var f := _add(_rng.randf() < 0.5, s, 0.0)
				var tight := "؛ ولی اصطبل جا نداره!" if list.size() > room() else ""
				notify.call("%s یه کره‌اسب %s آورد: %s %s%s" % [h.name, "ماده" if f.female else "نر", f.name, stars_text(s), tight])


# ---------- on the ranch ----------

func _process(delta: float) -> void:
	var hours := delta * day.speed / DayCycle.SECONDS_PER_HOUR
	if hours > 0.0:
		_tick(hours)
	var ids := {}
	for h in list:
		ids[h.id] = true
		if not _shown.has(h.id):
			_show(h)
		_move(h, _shown[h.id], delta)
	for id in _shown.keys():
		if not ids.has(id):
			_shown[id].node.queue_free()
			_shown.erase(id)


func _night() -> bool:
	return day.hour >= 20.0 or day.hour < 6.0


func _spot() -> Vector3:
	var c := _corral()
	if c:
		return c.spot(_rng)
	var s := _stable()
	var at := s.door() + s.global_basis.z * 4.0 if s else Vector3.ZERO
	return herd.free_spot(at + Vector3(_rng.randf_range(-5, 5), 0, _rng.randf_range(-3, 3)), 3.0)


func _show(h: Dictionary) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = HorseMesh.mesh()
	var coat: Array = Cowboy.COATS[h.coat]
	for s in 2:
		mi.set_surface_override_material(s, HorseMesh.material(s, coat[0], coat[1] if s == 0 else 0.0))
	mi.set_surface_override_material(2, _bare())  # loose horses carry no saddle
	add_child(mi)
	mi.position = _spot()
	mi.rotation.y = _rng.randf() * TAU
	_shown[h.id] = {node = mi, target = mi.position, wait = _rng.randf_range(1.0, 6.0), phase = 0.0}


## A material that draws nothing: hides the saddle surface of the horse mesh.
static func _bare() -> ShaderMaterial:
	if _no_saddle == null:
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nvoid fragment() { discard; }\n"
		_no_saddle = ShaderMaterial.new()
		_no_saddle.shader = sh
	return _no_saddle


func _move(h: Dictionary, v: Dictionary, delta: float) -> void:
	var mi: MeshInstance3D = v.node
	var size := lerpf(0.62, 1.0, clampf(h.age / ADULT, 0.0, 1.0))  # foals are small
	mi.scale = Vector3.ONE * size
	var s := _stable()
	if _night() and s:  # in for the night: walk to the stable door, then out of sight
		v.target = s.door()
		if mi.position.distance_to(v.target) < 1.5:
			mi.visible = false
			return
	elif not mi.visible:  # morning: out of the door again
		mi.visible = true
		mi.position = s.door() if s else mi.position
		v.target = _spot()
	var speed := day.speed
	var to: Vector3 = v.target - mi.position
	to.y = 0.0
	var pace := 0.0
	if to.length() > 0.3 and speed > 0.0:
		var step := minf(to.length(), WALK * size * delta * minf(speed, 4.0))
		mi.position += to.normalized() * step
		mi.rotation.y = lerp_angle(mi.rotation.y, atan2(to.x, to.z), minf(1.0, delta * 4.0))
		pace = WALK * size
	elif speed > 0.0:
		v.wait -= delta * speed
		if v.wait <= 0.0:
			v.wait = _rng.randf_range(4.0, 14.0)
			v.target = _spot()
	v.phase = fmod(v.phase + delta * pace * 2.2, TAU)
	mi.set_instance_shader_parameter("phase", v.phase)
	mi.set_instance_shader_parameter("amp", 0.42 * clampf(pace / 2.0, 0.0, 1.0) * 1.6)


# ---------- save ----------

func to_save() -> Dictionary:
	return {list = list, next = _next_id}


func from_save(d: Dictionary) -> void:
	_next_id = int(d.get("next", 1))
	list = d.get("list", [])
	for h in list:  # JSON brings numbers back as floats
		h.id = int(h.id)
		h.stars = int(h.stars)
		h.coat = int(h.coat)
		h.sire = int(h.sire)
