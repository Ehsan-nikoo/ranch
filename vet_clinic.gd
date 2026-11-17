## Country vet's place: a small white clapboard house with a red cross over the porch, and a steel
## squeeze chute beside it for holding a cow still. Sick cattle mend sooner and the vet and vaccine
## cost half. Front faces +Z.
class_name VetClinic
extends Building

const W := 3.4
const D := 2.8
const EAVE := 3.0
const RIDGE := 4.6
const CHUTE := 3.6   # chute length on +x


func _foot() -> Rect2:
	return Rect2(-W - 0.5, -D - 0.5, W * 2 + CHUTE + 1.4, D * 2 + 2.6)


func _ready() -> void:
	_gabled(W, D, EAVE, RIDGE, 0.45, siding, true)
	_box(Vector3(W * 2 + 0.3, 0.35, D * 2 + 0.3), Vector3(0, 0.1, 0), stone)
	for x in [-W, W]:
		for z in [-D, D]:
			_box(Vector3(0.16, EAVE, 0.16), Vector3(x, EAVE * 0.5, z), white)
	# front door with a porch roof on two posts
	_box(Vector3(1.1, 2.1, 0.08), Vector3(0, 1.05, D + 0.03), green)
	_box(Vector3(0.08, 0.08, 0.1), Vector3(0.38, 1.05, D + 0.1), steel)
	_box(Vector3(3.2, 0.14, 1.9), Vector3(0, 0.12, D + 0.95), wood)
	for x in [-1.4, 1.4]:
		_box(Vector3(0.14, 2.5, 0.14), Vector3(x, 1.3, D + 1.75), white)
	var st := _st()
	_slab(st, Vector3(0, 2.8, D), Vector3(0, 2.5, D + 1.95), Vector3(1.7, 0, 0), roof.get_meta("tile"))
	_commit(st, roof)
	# the red cross sign over the porch
	_box(Vector3(1.1, 1.1, 0.08), Vector3(0, 3.55, D + 0.12), white)
	_box(Vector3(0.28, 0.8, 0.06), Vector3(0, 3.55, D + 0.18), red)
	_box(Vector3(0.8, 0.28, 0.06), Vector3(0, 3.55, D + 0.18), red)
	for x in [-W * 0.55, W * 0.6]:
		_window(Vector3(x, 1.7, D), Vector3(0, 0, 1), white, green)
	_window(Vector3(-W, 1.7, 0), Vector3(-1, 0, 0), white, green)
	# squeeze chute: two steel side panels, a head gate and a ramp in
	var cx := W + 0.9 + CHUTE * 0.5
	for s in [-0.45, 0.45]:
		for h in [0.5, 1.0, 1.5]:
			_box(Vector3(CHUTE, 0.08, 0.06), Vector3(cx, h, s), steel)
		for k in 4:
			_box(Vector3(0.1, 1.8, 0.1), Vector3(cx - CHUTE * 0.5 + k * CHUTE / 3.0, 0.9, s), iron)
	_box(Vector3(0.12, 1.9, 1.1), Vector3(cx + CHUTE * 0.5 + 0.1, 0.95, 0), iron)  # head gate
	_box(Vector3(0.12, 0.35, 1.1), Vector3(cx + CHUTE * 0.5 + 0.1, 1.55, 0), red)
	_box(Vector3(CHUTE, 0.1, 0.84), Vector3(cx, 0.1, 0), wood)
	MeshMerge.boxes(self)
