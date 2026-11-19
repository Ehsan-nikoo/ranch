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


func upgrades() -> Array:
	return [2000, 4000]


func upgrade_text() -> String:
	return "مریض‌ها زودتر خوب می‌شن و دامپزشک و واکسن ارزون‌تر می‌شه"


func _foot() -> Rect2:
	var x0 := -W - 0.5 - (4.0 if level >= 2 else 0.0)  # sick ward on -x from level 2
	var z0 := -D - 0.5 - (4.4 if level >= 3 else 0.0)  # recovery pen out the back at level 3
	return Rect2(x0, z0, W + CHUTE + 0.9 - x0, D + 2.1 - z0)


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
	if level >= 2:  # a ward for the sick cows
		var ward := _wing(Vector3(-W - 1.95, 0, -0.3), 1.9, 2.4, 2.7, 3.9, siding, true)
		ward._window(Vector3(0, 1.6, 2.4), Vector3(0, 0, 1), white, green)
		ward._box(Vector3(0.6, 0.6, 0.06), Vector3(0, 3.0, 2.46), red)
		MeshMerge.boxes(ward)
	if level >= 3:  # a recovery pen behind
		_box(Vector3(W * 2, 0.05, 4.0), Vector3(0, 0.025, -D - 2.4), _mud())
		_pen(Vector3(0, 0, -D - 2.4), W, 2.0, white, 0.0, 1.3)
	MeshMerge.boxes(self)
