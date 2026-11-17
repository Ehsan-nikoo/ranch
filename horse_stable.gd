## Long, low red horse stable with a row of Dutch stall doors under a shed roof, a cupola and a
## hitching rail. Mounted hands can look after more cattle. Front faces +Z.
class_name HorseStable
extends Building

const W := 6.5    # half length (x), ridge runs along x
const D := 3.0    # half depth (z)
const EAVE := 3.0
const RIDGE := 4.8
const OVER := 0.4
const SHED := 2.0  # shed roof over the stall doors

const STALLS := 5


func _foot() -> Rect2:
	return Rect2(-W - 0.5, -D - 0.5, W * 2 + 1.0, D * 2 + SHED + 2.2)  # shed and hitching rail on +z


func _ready() -> void:
	eave = EAVE
	var st := _st()
	var t: float = red.get_meta("tile")
	for s in [-1.0, 1.0]:
		_wall(st, Vector3(-W * s, 0, D * s), Vector3(W * s, 0, D * s), EAVE, Vector3(0, 0, s), t, true)
		var x: float = W * s
		_wall(st, Vector3(x, 0, D * s), Vector3(x, 0, -D * s), EAVE, Vector3(s, 0, 0), t, false)
		_poly(st, [Vector3(x, EAVE, -D), Vector3(x, EAVE, D), Vector3(x, RIDGE, 0)], Vector3(s, 0, 0), Vector3.DOWN, Vector3.BACK, t)
	_commit(st, red)
	_box(Vector3(W * 2 + 0.3, 0.3, D * 2 + 0.3), Vector3(0, 0.1, 0), stone)  # footing
	for x in [-W, W]:
		for z in [-D, D]:
			_box(Vector3(0.18, EAVE, 0.18), Vector3(x, EAVE * 0.5, z), white)  # corner boards
	_roof()
	_stalls()
	_cupola()
	_rail()
	MeshMerge.boxes(self)


func _roof() -> void:
	var st := _st()
	var along := Vector3(W + OVER, 0, 0)
	var top := Vector3(0, RIDGE, 0)
	for s in [-1.0, 1.0]:
		var e := Vector3(0, EAVE, D * s)
		e += (e - top).normalized() * OVER
		_slab(st, top, e, along, roof.get_meta("tile"))
		_box(Vector3(along.x * 2, 0.16, 0.06), e + Vector3(0, -0.05, 0.03 * s), white)  # fascia
	# shed roof over the stall doors, on posts
	_slab(st, Vector3(0, EAVE - 0.1, D + 0.05), Vector3(0, EAVE - 0.6, D + SHED), Vector3(W + 0.2, 0, 0), roof.get_meta("tile"))
	_commit(st, roof)
	_box(Vector3(along.x * 2, 0.12, 0.4), Vector3(0, RIDGE + THICK + 0.02, 0), roof)  # ridge cap
	for k in 5:
		var x := lerpf(-W, W, k / 4.0)
		_box(Vector3(0.18, EAVE - 0.6, 0.18), Vector3(x, (EAVE - 0.6) * 0.5, D + SHED - 0.15), wood)
	_box(Vector3(W * 2 + 0.2, 0.2, 0.16), Vector3(0, EAVE - 0.7, D + SHED - 0.15), wood)  # beam


## Dutch doors: the top half open on a dark stall, white X on the bottom half.
func _stalls() -> void:
	var z := D + 0.04
	for i in STALLS:
		var x := lerpf(-W + 1.3, W - 1.3, i / float(STALLS - 1))
		_box(Vector3(1.3, 2.3, 0.06), Vector3(x, 1.15, z), white)  # frame
		_box(Vector3(1.05, 0.9, 0.08), Vector3(x, 1.75, z + 0.01), glass)  # open top half: dark inside
		_x_panel(x, 0.6, 1.05, 1.1, z + 0.05)
		_box(Vector3(0.12, 0.9, 0.5), Vector3(x + 0.5, 1.75, z + 0.27), red)  # top half swung open
	for s in [-1.0, 1.0]:
		_window(Vector3(W * s, 1.9, 0.0), Vector3(s, 0, 0))


func _cupola() -> void:
	_box(Vector3(1.2, 0.9, 1.2), Vector3(0, RIDGE + 0.45, 0), white)
	_box(Vector3(0.9, 0.5, 1.25), Vector3(0, RIDGE + 0.5, 0), glass)  # louvres
	_cyl(0.95, 0.6, Vector3(0, RIDGE + 1.2, 0), roof, 4, 0.05).rotation.y = PI / 4.0
	_beam(Vector3(0, RIDGE + 1.4, 0), Vector3(0, RIDGE + 2.3, 0), 0.05, iron)
	_box(Vector3(0.7, 0.3, 0.04), Vector3(0.15, RIDGE + 2.1, 0), iron)  # vane


func _rail() -> void:
	var z := D + SHED + 1.4
	for x in [-3.5, 0.0, 3.5]:
		_box(Vector3(0.16, 1.1, 0.16), Vector3(x, 0.55, z), wood)
	_box(Vector3(7.4, 0.12, 0.12), Vector3(0, 1.0, z), wood)
	_box(Vector3(2.4, 0.5, 0.7), Vector3(4.8, 0.25, z), wood)  # water trough
	_box(Vector3(2.2, 0.03, 0.55), Vector3(4.8, 0.47, z), water)
