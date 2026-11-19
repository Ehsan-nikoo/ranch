## Concrete stave silo with steel hoops, dome cap and a ladder facing +Z.
class_name Silo
extends Building

const R := 2.2
const H := 11.0


func hay_room() -> int:
	return 60 + 45 * (level - 1)


func upgrades() -> Array:
	return [800, 1600]


func upgrade_text() -> String:
	return "جای ۴۵ بسته یونجه‌ی بیشتر"


const SIDE := 5.0   # the extra silos stand this far to the side


func _foot() -> Rect2:
	var x0 := -R - 0.4 - (SIDE if level >= 3 else 0.0)
	var x1 := R + 0.4 + (SIDE if level >= 2 else 0.0)
	return Rect2(x0, -R - 0.4, x1 - x0, R * 2 + 0.8)


func _ready() -> void:
	_silo(Vector3.ZERO, R, H)
	if level >= 2:
		_silo(Vector3(SIDE, 0, 0), R * 0.82, H * 0.8)
	if level >= 3:
		_silo(Vector3(-SIDE, 0, 0), R * 0.82, H * 0.8)
		# a catwalk from the big silo's top across to both small ones, with a rail
		var y := 0.5 + H * 0.8 + 0.2
		_box(Vector3(SIDE * 2, 0.1, 0.7), Vector3(0, y, 0), iron)
		_box(Vector3(SIDE * 2, 0.05, 0.05), Vector3(0, y + 0.9, 0.33), iron)
		for x in [-SIDE + R, -R, R, SIDE - R]:
			_box(Vector3(0.05, 0.9, 0.05), Vector3(x, y + 0.45, 0.33), iron)
	MeshMerge.boxes(self)


## One concrete stave silo standing at `c`.
func _silo(c: Vector3, r: float, h: float) -> void:
	_cyl(r + 0.3, 0.5, c + Vector3(0, 0.25, 0), stone, 32)  # footing
	_cyl(r, h, c + Vector3(0, 0.5 + h * 0.5, 0), concrete, 32)
	for k in int(h / 0.8) - 1:  # tension hoops
		_cyl(r + 0.03, 0.06, c + Vector3(0, 1.2 + k * 0.8, 0), iron, 32)
	var dome := SphereMesh.new()
	dome.radius = r + 0.1
	dome.height = r + 0.1
	dome.is_hemisphere = true
	dome.radial_segments = 32
	dome.rings = 8
	var mi := MeshInstance3D.new()
	mi.mesh = dome
	mi.material_override = steel
	mi.position = c + Vector3(0, 0.5 + h, 0)
	add_child(mi)
	_cyl(0.35, 0.5, c + Vector3(0, 0.5 + h + r + 0.2, 0), steel, 12, 0.15)  # vent cap
	# ladder up the front with a safety cage hint
	for x in [-0.25, 0.25]:
		_box(Vector3(0.05, h + 1.0, 0.05), c + Vector3(x, 0.5 + (h + 1.0) * 0.5, r + 0.2), iron)
	for k in int(h / 0.4):
		_box(Vector3(0.5, 0.04, 0.04), c + Vector3(0, 1.0 + k * 0.4, r + 0.2), iron)
	_box(Vector3(0.9, 1.4, 0.06), c + Vector3(0, h - 0.4, r + 0.02), wood)  # loading door
