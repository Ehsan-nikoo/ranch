## Stone smithy with a big forge chimney, an open-sided shoeing shed with an anvil, and a wagon
## wheel waiting for a new rim. The smith mends windmills and fences: no breakdowns, cheaper upkeep.
## Front faces +Z.
class_name Blacksmith
extends Building

const W := 3.2
const D := 2.6
const EAVE := 2.8
const RIDGE := 4.3
const OVER := 0.4
const SHED := 3.2  # open shed on +x


func upgrades() -> Array:
	return [2500, 5000]


func upgrade_text() -> String:
	return "خرج هر گاو روزی ۱ دلار دیگه هم کمتر می‌شه"


## Dollars off each cow's daily upkeep.
func saving() -> int:
	return 2 + (level - 1)


func _foot() -> Rect2:
	var x0 := -W - 0.5 - (4.8 if level >= 3 else 0.0)  # the wagon shop on -x at level 3
	return Rect2(x0, -D - 0.5, W + SHED + 0.7 - x0, D * 2 + 1.6)


func _ready() -> void:
	eave = EAVE
	# dark board walls on a stone footing; the door opening is left in the front wall
	var st := _st()
	var t := 2.6
	var dw := 0.6  # half door width
	_wall(st, Vector3(W, 0, -D), Vector3(-W, 0, -D), EAVE, Vector3(0, 0, -1), t, true)
	_wall(st, Vector3(-W, 0, D), Vector3(-dw, 0, D), EAVE, Vector3(0, 0, 1), t, true)
	_wall(st, Vector3(dw, 0, D), Vector3(W, 0, D), EAVE, Vector3(0, 0, 1), t, true)
	_poly(st, [Vector3(-dw, EAVE - 0.6, D), Vector3(dw, EAVE - 0.6, D), Vector3(dw, EAVE, D), Vector3(-dw, EAVE, D)], Vector3(0, 0, 1), Vector3.RIGHT, Vector3.DOWN, t)
	for sx in [-1.0, 1.0]:
		_wall(st, Vector3(W * sx, 0, D * sx), Vector3(W * sx, 0, -D * sx), EAVE, Vector3(sx, 0, 0), t, true)
	for sz in [-1.0, 1.0]:
		_poly(st, [Vector3(-W, EAVE, D * sz), Vector3(W, EAVE, D * sz), Vector3(0, RIDGE, D * sz)], Vector3(0, 0, sz), Vector3.RIGHT, Vector3.DOWN, t)
	_commit(st, wood)
	_box(Vector3(W * 2 + 0.3, 0.4, D * 2 + 0.3), Vector3(0, 0.12, 0), stone)  # footing
	for x in [-W, W]:
		for z in [-D, D]:
			_box(Vector3(0.2, EAVE, 0.2), Vector3(x, EAVE * 0.5, z), iron)  # dark corner posts
	_box(Vector3(dw * 2, EAVE - 0.6, 0.06), Vector3(0, (EAVE - 0.6) * 0.5, D - 0.4), window_mat)  # forge glow through the door
	_box(Vector3(0.1, EAVE - 0.6, dw * 2), Vector3(dw + 0.35, (EAVE - 0.6) * 0.5, D + 0.4), wood, Vector3(0, -0.6, 0))  # door, swung open
	_window(Vector3(-W * 0.55, 1.6, D), Vector3(0, 0, 1), iron)
	_window(Vector3(W * 0.55, 1.6, D), Vector3(0, 0, 1), iron)
	st = _st()
	var along := Vector3(0, 0, D + OVER)
	var top := Vector3(0, RIDGE, 0)
	for s in [-1.0, 1.0]:
		var e := Vector3(W * s, EAVE, 0)
		e += (e - top).normalized() * OVER
		_slab(st, top, e, along, roof.get_meta("tile"))
	# open shed roof on +x, held up by two posts
	_slab(st, Vector3(W, EAVE - 0.1, 0), Vector3(W + SHED, EAVE - 0.6, 0), Vector3(0, 0, D), roof.get_meta("tile"))
	_commit(st, roof)
	for z in [-D + 0.2, D - 0.2]:
		_box(Vector3(0.2, EAVE - 0.6, 0.2), Vector3(W + SHED - 0.2, (EAVE - 0.6) * 0.5, z), wood)
	# forge chimney through the roof
	_box(Vector3(1.2, RIDGE + 1.6, 1.2), Vector3(-W + 1.0, (RIDGE + 1.6) * 0.5, -0.6), stone)
	_box(Vector3(1.35, 0.14, 1.35), Vector3(-W + 1.0, RIDGE + 1.65, -0.6), iron)
	# under the shed: anvil on a stump, quench barrel, horseshoes on a post
	var ax := W + SHED * 0.5
	_cyl(0.35, 0.6, Vector3(ax, 0.3, 0.4), wood, 10)
	_box(Vector3(0.7, 0.18, 0.28), Vector3(ax, 0.72, 0.4), iron)
	_box(Vector3(0.3, 0.12, 0.2), Vector3(ax + 0.42, 0.75, 0.4), iron)  # horn
	_box(Vector3(0.36, 0.14, 0.2), Vector3(ax, 0.6, 0.4), iron)
	_cyl(0.32, 0.8, Vector3(ax + 0.9, 0.4, -1.2), wood, 12)
	_cyl(0.3, 0.02, Vector3(ax + 0.9, 0.79, -1.2), water, 12)
	for k in 3:
		_box(Vector3(0.22, 0.04, 0.03), Vector3(W + SHED - 0.2, 1.1 + k * 0.3, -D + 0.32), iron)
	# wagon wheel leaning on the front wall
	var wheel := Node3D.new()
	wheel.position = Vector3(W * 0.55, 0.7, D + 0.25)
	wheel.rotation = Vector3(-0.2, 0, 0)
	add_child(wheel)
	for a in 8:
		var r := a * PI / 4.0
		_beam(Vector3.ZERO, Vector3(sin(r), cos(r), 0) * 0.65, 0.05, wood).reparent(wheel, false)
		_beam(Vector3(sin(r), cos(r), 0) * 0.68, Vector3(sin(r + PI / 4.0), cos(r + PI / 4.0), 0) * 0.68, 0.09, wood).reparent(wheel, false)
	if level >= 2:  # a second forge: another chimney, and a heap of coal by the door
		_box(Vector3(1.0, RIDGE + 1.2, 1.0), Vector3(W - 1.0, (RIDGE + 1.2) * 0.5, -0.8), stone)
		_box(Vector3(1.15, 0.12, 1.15), Vector3(W - 1.0, RIDGE + 1.25, -0.8), iron)
		var coal := _plain(Color(0.08, 0.08, 0.08), 0.9)
		for k in 5:
			_box(Vector3(0.5, 0.3, 0.45), Vector3(-W * 0.7 + (k % 3) * 0.42, 0.15 + (k / 3) * 0.24, D + 0.6), coal, Vector3(0, k * 0.7, 0))
	if level >= 3:  # a wagon shop with a wagon waiting outside
		var shop := _wing(Vector3(-W - 2.45, 0, 0), 2.3, 2.4, 2.8, 4.2, red)
		shop._x_panel(0, 1.2, 2.0, 2.2, 2.45)
		MeshMerge.boxes(shop)
		var bed := Vector3(-W - 2.4, 0, D + 1.1)
		_box(Vector3(2.6, 0.12, 1.2), bed + Vector3(0, 0.9, 0), wood)
		for s in [-0.6, 0.6]:
			_box(Vector3(2.6, 0.35, 0.06), bed + Vector3(0, 1.12, s), wood)
	MeshMerge.boxes(self)
	MeshMerge.boxes(wheel)
