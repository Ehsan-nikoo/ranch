## One-story clapboard farmhouse with a front porch and stone chimney. Front faces +Z.
class_name RanchHouse
extends Building

const W := 4.5    # half width (x), ridge runs along x
const D := 3.5    # half depth (z)
const EAVE := 3.0
const RIDGE := 5.0
const OVER := 0.45
const PORCH := 2.4


## Hands who can sleep here.
func bunks() -> int:
	return 3 + 2 * (level - 1)


func upgrades() -> Array:
	return [1500, 3000]


func upgrade_text() -> String:
	return "جای خواب ۲ کارگر بیشتر"


func _foot() -> Rect2:
	var x0 := -W - 0.4 - (4.5 if level >= 3 else 0.0)  # bunk-room wings from level 2
	var x1 := W + 0.4 + (4.5 if level >= 2 else 0.0)
	return Rect2(x0, -D - 0.4, x1 - x0, D * 2 + PORCH + 1.4)  # porch and steps on +z


func _ready() -> void:
	eave = EAVE
	_walls()
	_roof()
	_porch()
	_openings()
	_box(Vector3(0.9, RIDGE + 0.9, 0.9), Vector3(-2.8, (RIDGE + 0.9) * 0.5, -1.2), stone)  # chimney
	_box(Vector3(1.05, 0.12, 1.05), Vector3(-2.8, RIDGE + 0.95, -1.2), iron)
	for side in ([1.0] if level == 2 else ([1.0, -1.0] if level >= 3 else [])):
		var wg := _wing(Vector3((W + 2.2) * side, 0, -0.3), 2.3, 2.9, 2.8, 4.3, siding, true)
		wg._window(Vector3(0, 1.6, 2.9), Vector3(0, 0, 1), null, green)
		wg._window(Vector3(2.3 * side, 1.6, 0), Vector3(side, 0, 0), null, green)
		if side < 0.0:  # a second chimney on the far wing
			wg._box(Vector3(0.8, 4.9, 0.8), Vector3(-1.2, 2.45, -1.0), stone)
		MeshMerge.boxes(wg)
	MeshMerge.boxes(self)


func _walls() -> void:
	var st := _st()
	var t: float = siding.get_meta("tile")
	for s in [-1.0, 1.0]:
		var n := Vector3(0, 0, s)
		_wall(st, Vector3(-W * s, 0, D * s), Vector3(W * s, 0, D * s), EAVE, n, t, true, true)
		var x: float = W * s
		_wall(st, Vector3(x, 0, D * s), Vector3(x, 0, -D * s), EAVE, Vector3(s, 0, 0), t, false, true)
		_poly(st, [Vector3(x, EAVE, -D), Vector3(x, EAVE, D), Vector3(x, RIDGE, 0)], Vector3(s, 0, 0), Vector3.DOWN, Vector3.BACK, t)
	_commit(st, siding)
	_box(Vector3(W * 2 + 0.3, 0.5, D * 2 + 0.3), Vector3(0, 0.15, 0), stone)  # foundation
	for x in [-W, W]:
		for z in [-D, D]:
			_box(Vector3(0.18, EAVE - 0.3, 0.18), Vector3(x, EAVE * 0.5 + 0.15, z), white)  # corner boards


func _roof() -> void:
	var st := _st()
	var along := Vector3(W + OVER, 0, 0)
	var top := Vector3(0, RIDGE, 0)
	for s in [-1.0, 1.0]:
		var e := Vector3(0, EAVE, D * s)
		e += (e - top).normalized() * OVER
		_slab(st, top, e, along, roof.get_meta("tile"))
		_box(Vector3(along.x * 2, 0.18, 0.06), e + Vector3(0, -0.05, 0.03 * s), white)  # fascia
		for x in [-1.0, 1.0]:
			_beam(Vector3(along.x * x, e.y, e.z), Vector3(along.x * x, RIDGE + THICK, 0), 0.16, white)  # rake board
	_commit(st, roof)
	_box(Vector3(along.x * 2, 0.12, 0.4), Vector3(0, RIDGE + THICK + 0.02, 0), roof)  # ridge cap


func _porch() -> void:
	var z1 := D + PORCH
	_box(Vector3(W * 2, 0.45, PORCH), Vector3(0, 0.22, D + PORCH * 0.5), wood)  # deck
	for k in 2:  # steps down the middle
		_box(Vector3(1.6, 0.15, 0.35), Vector3(0, 0.3 - k * 0.15, z1 + 0.17 + k * 0.33), wood)
	for x in [-4.2, -1.1, 1.1, 4.2]:
		_box(Vector3(0.16, 2.4, 0.16), Vector3(x, 1.65, z1 - 0.15), white)
	for span in [[-4.2, -1.1], [1.1, 4.2]]:  # railings, open at the steps
		var cx: float = (span[0] + span[1]) * 0.5
		var w: float = span[1] - span[0]
		_box(Vector3(w, 0.08, 0.08), Vector3(cx, 1.35, z1 - 0.15), white)
		for k in 7:
			_box(Vector3(0.05, 0.85, 0.05), Vector3(span[0] + w * (k + 1) / 8.0, 0.9, z1 - 0.15), white)
	var st := _st()
	_slab(st, Vector3(0, 2.95, D + 0.05), Vector3(0, 2.55, z1 + 0.35), Vector3(W + 0.3, 0, 0), roof.get_meta("tile"))
	_commit(st, roof)
	_box(Vector3(W * 2 + 0.6, 0.2, 0.16), Vector3(0, 2.75, z1 - 0.15), white)  # porch beam


func _openings() -> void:
	var z := D + 0.03
	_box(Vector3(1.3, 2.35, 0.06), Vector3(0, 0.45 + 1.15, z), white)  # door frame
	_box(Vector3(1.0, 2.1, 0.08), Vector3(0, 0.45 + 1.05, z + 0.02), green)
	_box(Vector3(0.9, 0.3, 0.09), Vector3(0, 0.45 + 2.35, z), window_mat)  # transom
	for x in [-2.6, 2.6]:
		_window(Vector3(x, 1.75, D), Vector3(0, 0, 1), null, green)
		_window(Vector3(x, 1.75, -D), Vector3(0, 0, -1), null, green)
	for s in [-1.0, 1.0]:
		_window(Vector3(W * s, 1.75, 0.9), Vector3(s, 0, 0), null, green)
