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


func _foot() -> Rect2:
	return Rect2(-R - 0.4, -R - 0.4, R * 2 + 0.8, R * 2 + 0.8)


func _ready() -> void:
	_cyl(R + 0.3, 0.5, Vector3(0, 0.25, 0), stone, 32)  # footing
	_cyl(R, H, Vector3(0, 0.5 + H * 0.5, 0), concrete, 32)
	for k in 13:  # tension hoops
		_cyl(R + 0.03, 0.06, Vector3(0, 1.2 + k * 0.8, 0), iron, 32)
	var dome := SphereMesh.new()
	dome.radius = R + 0.1
	dome.height = R + 0.1
	dome.is_hemisphere = true
	dome.radial_segments = 32
	dome.rings = 8
	var mi := MeshInstance3D.new()
	mi.mesh = dome
	mi.material_override = steel
	mi.position.y = 0.5 + H
	add_child(mi)
	_cyl(0.35, 0.5, Vector3(0, 0.5 + H + R + 0.2, 0), steel, 12, 0.15)  # vent cap
	# ladder up the front with a safety cage hint
	for x in [-0.25, 0.25]:
		_box(Vector3(0.05, H + 1.0, 0.05), Vector3(x, 0.5 + (H + 1.0) * 0.5, R + 0.2), iron)
	for k in int(H / 0.4):
		_box(Vector3(0.5, 0.04, 0.04), Vector3(0, 1.0 + k * 0.4, R + 0.2), iron)
	_box(Vector3(0.9, 1.4, 0.06), Vector3(0, H - 0.4, R + 0.02), wood)  # loading door
	MeshMerge.boxes(self)
