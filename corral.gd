## Corral: a big rail-fenced dirt pen with a wide gate, a water trough and a stack of hay. The ranch
## horses spend their days in it, and the foals grow up faster here. Gate faces +Z.
## Bigger levels: a shelter roof in the back corner, then a hay rack and a second trough.
class_name Corral
extends Building

const HX := 9.0
const HZ := 7.5
const GATE := 4.0


func upgrades() -> Array:
	return [400, 800]


func upgrade_text() -> String:
	return "آغل بزرگ‌تر: کره‌اسب‌ها باز هم زودتر بزرگ می‌شن"


## How much faster foals grow up with the horses kept in here.
func foal_mul() -> float:
	return 1.3 + 0.15 * (level - 1)


func _foot() -> Rect2:
	return Rect2(-HX - 0.4, -HZ - 0.4, HX * 2 + 0.8, HZ * 2 + 0.8)


## A spot inside the fence, in world space, for a horse to wander to.
func spot(rng: RandomNumberGenerator) -> Vector3:
	return to_global(Vector3(rng.randf_range(-HX + 1.5, HX - 1.5), 0, rng.randf_range(-HZ + 1.5, HZ - 1.5)))


func _ready() -> void:
	_box(Vector3(HX * 2, 0.05, HZ * 2), Vector3(0, 0.025, 0), _mud())
	_pen(Vector3.ZERO, HX, HZ, wood, GATE, 1.5)
	_box(Vector3(GATE * 0.5, 1.2, 0.08), Vector3(GATE * 0.25 + GATE * 0.5 + 0.5, 0.8, HZ + 0.9), wood, Vector3(0, 0.9, 0))  # gate swung open
	# water trough by the fence, hay stacked in the back corner
	_box(Vector3(0.9, 0.6, 3.0), Vector3(HX - 1.2, 0.3, -1.0), wood)
	_box(Vector3(0.75, 0.02, 2.85), Vector3(HX - 1.2, 0.58, -1.0), water)
	var hay := _straw()
	for p in [Vector3(-0.6, 0.3, -0.5), Vector3(0.6, 0.3, -0.5), Vector3(-0.6, 0.3, 0.5), Vector3(0.6, 0.3, 0.5), Vector3(0, 0.9, 0)]:
		_box(Vector3(1.15, 0.6, 0.85), Vector3(-HX + 1.8, 0, -HZ + 1.5) + p, hay)
	if level >= 2:  # a shelter roof on posts over the back corner, out of the sun and snow
		var x0 := -HX + 0.4
		var x1 := -HX + 6.0
		var z0 := -HZ + 0.3
		var z1 := -HZ + 4.2
		for x in [x0, (x0 + x1) * 0.5, x1]:
			_box(Vector3(0.2, 2.9, 0.2), Vector3(x, 1.45, z0), wood)
			_box(Vector3(0.2, 2.4, 0.2), Vector3(x, 1.2, z1), wood)
		var st := _st()
		_slab(st, Vector3((x0 + x1) * 0.5, 2.95, z0 - 0.3), Vector3((x0 + x1) * 0.5, 2.45, z1 + 0.4), Vector3((x1 - x0) * 0.5 + 0.3, 0, 0), roof.get_meta("tile"))
		_commit(st, roof)
		_box(Vector3(x1 - x0, 1.2, 0.08), Vector3((x0 + x1) * 0.5, 1.5, z0 + 0.05), wood)  # back boards
	if level >= 3:  # a slatted hay rack, a second trough and a gate arch with a ranch sign
		var rx := HX - 3.5
		for k in 6:
			_box(Vector3(0.06, 1.2, 0.06), Vector3(rx - 1.25 + k * 0.5, 1.0, -HZ + 1.3), wood)
		_box(Vector3(3.0, 0.1, 0.9), Vector3(rx, 0.45, -HZ + 1.3), wood)
		_box(Vector3(2.8, 0.5, 0.7), Vector3(rx, 1.1, -HZ + 1.3), hay)
		_box(Vector3(3.0, 0.6, 0.9), Vector3(1.0, 0.3, -HZ + 1.0), wood)
		_box(Vector3(2.85, 0.02, 0.75), Vector3(1.0, 0.58, -HZ + 1.0), water)
		for s in [-1.0, 1.0]:
			_box(Vector3(0.28, 3.6, 0.28), Vector3(s * (GATE * 0.5 + 0.1), 1.8, HZ), wood)
		_box(Vector3(GATE + 0.9, 0.28, 0.3), Vector3(0, 3.45, HZ), wood)
		_box(Vector3(2.4, 0.6, 0.08), Vector3(0, 2.9, HZ + 0.12), white)
	MeshMerge.boxes(self)
