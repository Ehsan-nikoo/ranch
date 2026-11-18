## Deliveries: every calf, heifer, bull or hay purchase is brought by a truck that drives in along the ranch road,
## under the gate, loops in front of the barn to unload, and drives back out.
## The delivery timer runs on game time: the truck unloads ARRIVE game hours after the first purchase
## (a couple of real minutes at normal speed). Everything bought before it unloads rides on that same truck.
## Owns the road, the gate on it, and the trucks; none are direct children of the world,
## so the herd, the builder and the save file never mistake them for buildings.
class_name Delivery
extends Node3D

# all in game hours (one hour = DayCycle.SECONDS_PER_HOUR real seconds at normal speed); written for
# 30 s hours and scaled by K, so the truck keeps the same real pace whatever the length of a day
const K := 30.0 / DayCycle.SECONDS_PER_HOUR
const ARRIVE := 4.8 * K   # from the first purchase to unloading: 144 real seconds at normal speed
const DRIVE_IN := 2.0 * K # the truck is on screen for the last part of the wait
const UNLOAD := 0.32 * K
const DRIVE_OUT := 1.6 * K
const LANE := 1.1         # keep right, so an incoming and a leaving truck pass each other
const GATE_Z := Land.HALF  # the gate stands in the ranch fence where the road comes in
# road control points (x, z) from off the map, through the gate, up the wagon track, a loop on the barn apron, and back out
const ROUTE := [Vector2(9, 160), Vector2(9, 125), Vector2(8.5, Land.HALF), Vector2(9.5, 75), Vector2(10, 60), Vector2(8, 45),
	Vector2(3, 30), Vector2(0.6, 19), Vector2(3.4, 13.8), Vector2(0, 11.2), Vector2(-3.4, 13.8), Vector2(-0.6, 19),
	Vector2(3, 30), Vector2(8, 45), Vector2(10, 60), Vector2(9.5, 75), Vector2(8.5, Land.HALF), Vector2(9, 125), Vector2(9, 160)]
const STOP := 9           # control point where the truck stops to unload

var herd: Herd
var day: DayCycle
var notify: Callable
var gate := RanchGate.new()
var orders: Array = []    # {calves, heifers, bulls, hay, t, truck, done}
var _pts := PackedVector3Array()
var _dist := PackedFloat32Array()
var _stop_d := 0.0
var _label: Label
var _box: PanelContainer


func _init() -> void:
	_build_road()


func _ready() -> void:
	var p := point_at(_d_at_z(GATE_Z))
	var fwd: Vector3 = p[1]
	gate.position = p[0] - Vector3(-fwd.z, 0, fwd.x) * LANE  # back from the incoming lane to the road's center
	gate.rotation.y = atan2(fwd.x, fwd.z)
	add_child(gate)
	var ui := CanvasLayer.new()
	add_child(ui)
	_box = UiTheme.plank(21, Control.PRESET_TOP_RIGHT)  # under the money plank
	_box.offset_right = -12
	_box.offset_top = 100
	_box.visible = false
	_label = _box.get_child(0)
	ui.add_child(_box)


## Smooth road through ROUTE (Catmull-Rom), pushed LANE to the right of the direction of travel.
func _build_road() -> void:
	var c := ROUTE.map(func(v): return Vector3(v.x, 0, v.y))
	var center := PackedVector3Array()
	for i in c.size() - 1:
		var p0: Vector3 = c[maxi(i - 1, 0)]
		var p1: Vector3 = c[i]
		var p2: Vector3 = c[i + 1]
		var p3: Vector3 = c[mini(i + 2, c.size() - 1)]
		for k in 12:
			var t := k / 12.0
			center.append(0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	center.append(c[-1])
	var acc := 0.0
	for i in center.size():
		var a := center[maxi(i - 1, 0)]
		var b := center[mini(i + 1, center.size() - 1)]
		var fwd := (b - a).normalized()
		var right := Vector3(-fwd.z, 0, fwd.x)  # +x side when driving toward -z
		_pts.append(center[i] + right * LANE)
		if i > 0:
			acc += _pts[i].distance_to(_pts[i - 1])
		_dist.append(acc)
	_stop_d = _dist[STOP * 12]


func _d_at_z(z: float) -> float:
	for i in _pts.size():
		if _pts[i].z < z:
			return _dist[i]
	return 0.0


## [position, forward direction] at distance d along the road.
func point_at(d: float) -> Array:
	d = clampf(d, 0.0, _dist[-1])
	var i := 1
	while i < _dist.size() - 1 and _dist[i] < d:
		i += 1
	var seg := maxf(_dist[i] - _dist[i - 1], 0.001)
	var p := _pts[i - 1].lerp(_pts[i], (d - _dist[i - 1]) / seg)
	return [p, (_pts[i] - _pts[i - 1]).normalized()]


## Gate posts in world space, for the herd and builder to keep clear of.
func blocked_rects() -> Array[Rect2]:
	var r: Array[Rect2] = []
	for p in gate.posts():
		r.append(Rect2(p.x - 0.9, p.z - 0.9, 1.8, 1.8))
	return r


func order(calves: int, hay: int, heifers := 0, bulls := 0) -> void:
	for o in orders:
		if not o.done:  # a truck is already coming: it brings this too
			o.calves += calves
			o.heifers += heifers
			o.bulls += bulls
			o.hay += hay
			if o.truck != null:  # already on the road: reload it so the new cargo shows
				var old: Truck = o.truck
				o.truck = _truck(o)
				o.truck.transform = old.transform
				old.queue_free()
			return
	orders.append({calves = calves, heifers = heifers, bulls = bulls, hay = hay, t = 0.0, truck = null, done = false})


func _truck(o: Dictionary) -> Truck:
	var tr := Truck.new()
	tr.calves = o.calves + o.heifers + o.bulls  # all ride in the stock trailer
	tr.hay_bales = o.hay
	add_child(tr)
	return tr


func pending_calves() -> int:
	return orders.filter(func(o): return not o.done).reduce(func(a, o): return a + o.calves, 0)


## Every head of cattle on its way, for the herd size limit.
func pending_animals() -> int:
	return orders.filter(func(o): return not o.done).reduce(func(a, o): return a + o.calves + o.heifers + o.bulls, 0)


func pending_hay() -> int:
	return orders.filter(func(o): return not o.done).reduce(func(a, o): return a + o.hay, 0)


func _process(delta: float) -> void:
	var next := INF
	delta *= day.speed / DayCycle.SECONDS_PER_HOUR  # game hours
	for o in orders.duplicate():
		o.t += delta
		var t: float = o.t - (ARRIVE - DRIVE_IN)
		if t < 0.0:
			next = minf(next, ARRIVE - o.t)
			continue
		if o.truck == null:
			o.truck = _truck(o)
		var d: float
		if t < DRIVE_IN:                      # roll in, braking smoothly to a stop
			var u := t / DRIVE_IN
			d = _stop_d * (1.0 - (1.0 - u) * (1.0 - u))
			next = minf(next, ARRIVE - o.t)
		elif t < DRIVE_IN + UNLOAD:
			d = _stop_d
			if not o.done:
				_unload(o)
		elif t < DRIVE_IN + UNLOAD + DRIVE_OUT:  # pull away
			var u := (t - DRIVE_IN - UNLOAD) / DRIVE_OUT
			d = _stop_d + (_dist[-1] - _stop_d) * u * u
		else:
			o.truck.queue_free()
			orders.erase(o)
			continue
		var p := point_at(d)
		var tr: Truck = o.truck
		var moved := tr.position.distance_to(p[0])
		tr.position = p[0]
		tr.rotation.y = lerp_angle(tr.rotation.y, atan2(p[1].x, p[1].z), minf(1.0, delta * 50.0)) if moved < 5.0 else atan2(p[1].x, p[1].z)
		tr.roll(moved)
	var o_wait := orders.filter(func(o): return not o.done)
	if o_wait.is_empty():
		_box.visible = false
	else:
		var w := {calves = 0, heifers = 0, bulls = 0, hay = 0}
		for o in o_wait:
			for k in w:
				w[k] += o[k]
		var what := _cargo(w)
		var at := fmod(day.hour + next, 24.0)
		_box.visible = true
		_box.call_deferred("reset_size")
		_label.text = "کامیون (%s) ساعت %s می‌رسه
هر چی تا اون موقع بخری، با همین کامیون میاد" % [
			"، ".join(what), UiTheme.fa("%02d:%02d" % [int(at), int(fmod(at, 1.0) * 60.0)])]
		UiTheme.fit(_box)


func _unload(o: Dictionary) -> void:
	o.done = true
	var back: Vector3 = o.truck.to_global(Vector3(0, 0, -7.5 if o.calves + o.heifers + o.bulls > 0 else -3.5))
	for i in o.calves:
		herd.add_cow(herd.free_spot(back, 2.5), HerdUI.CALF_KG)
	for i in o.heifers:
		herd.add_cow(herd.free_spot(back, 2.5), HerdUI.HEIFER_KG, Herd.BREEDER)
	for i in o.bulls:
		herd.add_cow(herd.free_spot(back, 2.5), HerdUI.BULL_KG, Herd.BULL)
	herd.hay = minf(herd.hay + o.hay, herd.hay_cap)
	notify.call("کامیون رسید و %s رو آورد" % " و ".join(_cargo(o)))


func _cargo(o: Dictionary) -> Array:
	var what := []
	for k in [["calves", "گوساله"], ["heifers", "گاو مادر"], ["bulls", "گاو نر"], ["hay", "بسته یونجه"]]:
		if o[k[0]] > 0:
			what.append("%s %s" % [UiTheme.fa(o[k[0]]), k[1]])
	return what


## Undelivered goods; on load they're ordered again and arrive ARRIVE game hours later.
func to_save() -> Array:
	var w := orders.filter(func(o): return not o.done)
	return [pending_calves(), pending_hay(), w.reduce(func(a, o): return a + o.heifers, 0), w.reduce(func(a, o): return a + o.bulls, 0)]


func from_save(p: Array) -> void:
	var heifers := int(p[2]) if p.size() > 3 else 0  # older saves had calves and hay only
	var bulls := int(p[3]) if p.size() > 3 else 0
	if p[0] > 0 or p[1] > 0 or heifers > 0 or bulls > 0:
		order(int(p[0]), int(p[1]), heifers, bulls)
