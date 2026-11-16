## Steel-lattice water-pumping windmill with a round stock tank. Wheel faces +Z.
class_name Windmill
extends Building

const TOP := 9.0
const BASE := 1.3   # half width of the footprint
const HEAD := 0.35  # half width at the top

var wheel := Node3D.new()


func _process(delta: float) -> void:
	wheel.rotation.z += delta * 2.2


func _ready() -> void:
	_tower()
	_head()
	_tank()
	MeshMerge.boxes(self)
	MeshMerge.boxes(wheel)


func _corner(i: int, y: float) -> Vector3:
	var h := lerpf(BASE, HEAD, y / TOP)
	return Vector3(h if i == 0 or i == 3 else -h, y, h if i < 2 else -h)


func _tower() -> void:
	for i in 4:
		_beam(_corner(i, 0.0), _corner(i, TOP), 0.09, steel)  # legs
	var levels := [0.4, 3.0, 5.4, 7.4, TOP]
	for k in levels.size():
		for i in 4:
			var j := (i + 1) % 4
			_beam(_corner(i, levels[k]), _corner(j, levels[k]), 0.05, steel)  # girts
			if k > 0:  # X braces on every face
				_beam(_corner(i, levels[k - 1]), _corner(j, levels[k]), 0.035, steel)
				_beam(_corner(j, levels[k - 1]), _corner(i, levels[k]), 0.035, steel)
	_box(Vector3(0.3, 0.3, 0.3), Vector3(0, 0.15, 0), stone)  # pump stand
	_box(Vector3(1.5, 0.08, 1.5), Vector3(0, TOP, 0), wood)  # platform
	_beam(Vector3(0, 0.3, 0), Vector3(0, TOP + 0.3, 0), 0.04, iron)  # pump rod
	for i in 4:  # concrete footings
		_box(Vector3(0.4, 0.25, 0.4), _corner(i, 0.1), concrete)


func _head() -> void:
	var y := TOP + 0.45
	_box(Vector3(0.45, 0.45, 1.0), Vector3(0, y, 0), iron)  # gearbox
	_beam(Vector3(0, y, -0.4), Vector3(0, y + 0.1, -2.6), 0.06, steel)  # tail boom
	_box(Vector3(0.03, 1.0, 1.5), Vector3(0, y + 0.25, -2.9), white)  # tail vane
	wheel.position = Vector3(0, y, 0.6)
	add_child(wheel)
	var blades := 18
	for k in blades:
		var a := TAU * k / blades
		var b := _box(Vector3(0.3, 1.15, 0.02), Vector3(sin(a), cos(a), 0) * 1.0, steel)
		b.basis = Basis(Vector3.BACK, -a) * Basis(Vector3.UP, 0.35)  # radial, pitched like a fan blade
		b.reparent(wheel, false)
		var r := _beam(Vector3(sin(a), cos(a), 0) * 1.55, Vector3(sin(a + TAU / blades), cos(a + TAU / blades), 0) * 1.55, 0.04, iron)
		r.reparent(wheel, false)  # outer rim
		_beam(Vector3.ZERO, Vector3(sin(a), cos(a), 0) * 1.55, 0.025, iron).reparent(wheel, false)  # spoke
	var hub := _cyl(0.18, 0.3, Vector3.ZERO, iron, 12)
	hub.rotation.x = PI * 0.5  # axis points forward
	hub.reparent(wheel, false)


func _tank() -> void:
	var c := Vector3(3.6, 0, 1.2)
	_cyl(2.2, 0.85, c + Vector3(0, 0.42, 0), steel, 32)
	# water sits just above the closed cylinder top so the tank reads as brim-full
	_cyl(2.1, 0.02, c + Vector3(0, 0.86, 0), water, 32)
	_beam(Vector3(0.2, 0.5, 0.1), c + Vector3(-1.9, 1.0, -0.6), 0.07, iron)  # outlet pipe
