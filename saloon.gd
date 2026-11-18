## Ranch café and store: a weathered plank building with a tall square false front, a shady porch on
## posts, swinging doors, a sign board, barrels and a hitching rail. Neighbours and passers-by spend
## money here every season and talk the ranch up. Front faces +Z.
class_name Saloon
extends Building

const W := 4.5
const D := 3.5
const EAVE := 4.0
const RIDGE := 5.4
const FRONT := 6.6   # height of the false front
const PORCH := 2.4


func upgrades() -> Array:
	return [3000, 6000]


func upgrade_text() -> String:
	return "کافه بزرگ‌تر: هر فصل نصف بیشتر پول میاره"


func _foot() -> Rect2:
	return Rect2(-W - 0.5, -D - 0.5, W * 2 + 1.0, D * 2 + PORCH + 2.4)


func _ready() -> void:
	_gabled(W, D, EAVE, RIDGE, 0.35, wood)  # the false front hides the roof from the road
	_box(Vector3(W * 2 + 0.3, 0.3, D * 2 + 0.3), Vector3(0, 0.1, 0), stone)
	# false front: a tall flat board wall with a stepped cornice
	var z := D + 0.08
	_box(Vector3(W * 2 + 0.4, FRONT, 0.16), Vector3(0, FRONT * 0.5, z), siding)
	_box(Vector3(W * 2 + 0.7, 0.24, 0.3), Vector3(0, FRONT + 0.1, z), white)
	_box(Vector3(W * 1.0, 0.5, 0.18), Vector3(0, FRONT + 0.45, z), siding)
	_box(Vector3(W * 1.0 + 0.3, 0.16, 0.3), Vector3(0, FRONT + 0.75, z), white)
	# sign board: cream with a red band
	_box(Vector3(W * 1.5, 1.0, 0.08), Vector3(0, FRONT - 1.1, z + 0.1), white)
	_box(Vector3(W * 1.5, 0.22, 0.09), Vector3(0, FRONT - 1.1, z + 0.12), red)
	# swinging doors in a dark doorway, a window either side
	_box(Vector3(1.5, 2.4, 0.06), Vector3(0, 1.4, z + 0.06), glass)
	for s in [-1.0, 1.0]:
		_box(Vector3(0.68, 1.0, 0.06), Vector3(0.36 * s, 1.35, z + 0.12), wood)
		_window(Vector3(2.6 * s, 1.8, z + 0.05), Vector3(0, 0, 1), white)
	# porch floor and roof on posts
	_box(Vector3(W * 2 + 0.4, 0.2, PORCH), Vector3(0, 0.25, z + PORCH * 0.5), wood)
	for k in 4:
		var x := lerpf(-W, W, k / 3.0)
		_box(Vector3(0.18, 3.2, 0.18), Vector3(x, 1.75, z + PORCH - 0.15), wood)
	var st := _st()
	_slab(st, Vector3(0, 3.6, z), Vector3(0, 3.3, z + PORCH + 0.2), Vector3(W + 0.2, 0, 0), roof.get_meta("tile"))
	_commit(st, roof)
	for p in [Vector3(-W + 0.6, 0, z + 0.5), Vector3(-W + 1.3, 0, z + 0.45)]:  # barrels on the porch
		_cyl(0.32, 0.85, p + Vector3(0, 0.78, 0), wood, 12)
		_cyl(0.33, 0.06, p + Vector3(0, 0.95, 0), iron, 12)
	var rz := z + PORCH + 1.3
	for x in [-2.6, 2.6]:  # hitching rail
		_box(Vector3(0.16, 1.1, 0.16), Vector3(x, 0.55, rz), wood)
	_box(Vector3(5.6, 0.12, 0.12), Vector3(0, 1.0, rz), wood)
	MeshMerge.boxes(self)
