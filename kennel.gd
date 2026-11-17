## Dog kennel: three little doghouses in a fenced run, with water bowls and two cattle dogs.
## The dogs help the hands move the herd and bark the wolves away. Front faces +Z.
class_name Kennel
extends Building

const HX := 4.2
const HZ := 2.8


func _foot() -> Rect2:
	return Rect2(-HX - 0.4, -HZ - 0.4, HX * 2 + 0.8, HZ * 2 + 0.8)


func _ready() -> void:
	_box(Vector3(HX * 2, 0.06, HZ * 2), Vector3(0, 0.03, 0), _mud())
	_pen(Vector3.ZERO, HX, HZ, white, 1.4)
	for x in [-2.7, 0.0, 2.7]:
		_doghouse(Vector3(x, 0, -HZ + 1.0))
	for x in [-1.3, 1.4]:
		_cyl(0.22, 0.12, Vector3(x, 0.06, -0.2), steel, 12)
		_cyl(0.18, 0.02, Vector3(x, 0.12, -0.2), water, 12)
	_dog(Vector3(-1.6, 0, 1.0), 0.6, Color(0.15, 0.12, 0.1))
	_dog(Vector3(1.9, 0, 0.6), -0.9, Color(0.55, 0.36, 0.2))
	MeshMerge.boxes(self)


func _doghouse(at: Vector3) -> void:
	_box(Vector3(1.3, 0.9, 1.1), at + Vector3(0, 0.45, 0), red)
	_box(Vector3(0.5, 0.6, 0.04), at + Vector3(0, 0.32, 0.56), glass)  # dark door hole
	for s in [-1.0, 1.0]:  # two roof boards meeting at the ridge
		_box(Vector3(0.95, 0.07, 1.3), at + Vector3(0.36 * s, 1.15, 0), roof, Vector3(0, 0, -0.62 * s))
	_box(Vector3(0.3, 0.06, 0.06), at + Vector3(0, 0.8, 0.57), white)  # name board


## A cattle dog standing, built from boxes; faces +z before `yaw`.
func _dog(at: Vector3, yaw: float, coat: Color) -> void:
	var fur := _plain(coat, 0.95)
	var dog := Node3D.new()
	dog.position = at
	dog.rotation.y = yaw
	add_child(dog)
	var parts := [
		_box(Vector3(0.3, 0.3, 0.78), Vector3(0, 0.55, 0), fur),
		_box(Vector3(0.24, 0.26, 0.28), Vector3(0, 0.78, 0.48), fur),
		_box(Vector3(0.13, 0.12, 0.18), Vector3(0, 0.72, 0.68), fur),
		_box(Vector3(0.06, 0.05, 0.04), Vector3(0, 0.76, 0.78), iron),  # nose
		_box(Vector3(0.07, 0.14, 0.05), Vector3(0.09, 0.96, 0.44), fur, Vector3(0, 0, -0.2)),
		_box(Vector3(0.07, 0.14, 0.05), Vector3(-0.09, 0.96, 0.44), fur, Vector3(0, 0, 0.2)),
		_box(Vector3(0.06, 0.06, 0.4), Vector3(0, 0.72, -0.52), fur, Vector3(0.7, 0, 0)),  # tail up
	]
	for x in [-0.1, 0.1]:
		for z in [-0.28, 0.28]:
			parts.append(_box(Vector3(0.08, 0.42, 0.08), Vector3(x, 0.21, z), fur))
	for p in parts:
		p.reparent(dog, false)
	MeshMerge.boxes(dog)
