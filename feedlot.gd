## Fattening pen: a plank-fenced dirt lot with a long roofed feed bunk full of hay along the back and
## a water trough in the corner. Grain and hay on demand put weight on the sale cattle faster, but
## they eat more. Gate faces +Z.
class_name Feedlot
extends Building

const PX := 6.5
const PZ := 4.5


func hay_room() -> int:
	return 30


func _foot() -> Rect2:
	return Rect2(-PX - 0.5, -PZ - 0.5, PX * 2 + 1.0, PZ * 2 + 1.0)


func _ready() -> void:
	_box(Vector3(PX * 2, 0.06, PZ * 2), Vector3(0, 0.03, 0), _mud())
	_pen(Vector3.ZERO, PX, PZ, white, 3.0)
	for s in [-1.0, 1.0]:  # gate leaves swung open
		_box(Vector3(1.5, 1.2, 0.08), Vector3(1.5 * s + 0.3 * s, 0.9, PZ + 0.7), red, Vector3(0, 0.9 * s, 0))
	# feed bunk along the back fence under a lean-to roof
	var z := -PZ + 0.8
	_box(Vector3(PX * 2 - 1.0, 0.6, 0.9), Vector3(0, 0.3, z), wood)
	_box(Vector3(PX * 2 - 1.2, 0.08, 0.7), Vector3(0, 0.62, z), _straw())
	for k in 5:
		var x := lerpf(-PX + 0.6, PX - 0.6, k / 4.0)
		_box(Vector3(0.18, 2.6, 0.18), Vector3(x, 1.3, z + 0.9), wood)
		_box(Vector3(0.18, 3.0, 0.18), Vector3(x, 1.5, -PZ - 0.1), wood)
	var st := _st()
	_slab(st, Vector3(0, 3.1, -PZ - 0.4), Vector3(0, 2.6, z + 1.3), Vector3(PX, 0, 0), roof.get_meta("tile"))
	_commit(st, roof)
	for k in 3:  # a few bales waiting by the bunk
		_box(Vector3(1.2, 0.5, 0.6), Vector3(-PX + 1.4 + k * 1.3, 0.3, z + 1.5), _straw())
	_box(Vector3(0.6, 0.5, 2.2), Vector3(PX - 0.8, 0.25, 1.5), steel)  # water trough
	_box(Vector3(0.5, 0.03, 2.0), Vector3(PX - 0.8, 0.49, 1.5), water)
	MeshMerge.boxes(self)
