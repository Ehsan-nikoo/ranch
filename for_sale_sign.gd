## Little wooden «for sale» sign planted in the middle of a locked plot.
## Extends Building only for its materials and helpers; Land keeps it out of the world's direct
## children, so the herd, builder and save never count it as a building.
class_name ForSaleSign
extends Building


func _ready() -> void:
	_box(Vector3(0.14, 2.1, 0.14), Vector3(0, 1.05, 0), wood)
	_box(Vector3(2.0, 0.85, 0.08), Vector3(0, 1.75, 0.08), white)
	_box(Vector3(2.1, 0.08, 0.12), Vector3(0, 2.2, 0.08), wood)
	for z in [0.13, 0.03]:
		var l := Label3D.new()
		l.text = "زمین برای فروش"
		l.font = load("res://ui/fonts/Vazirmatn-Bold.ttf")
		l.font_size = 64
		l.pixel_size = 0.0055
		l.modulate = Color(0.55, 0.1, 0.05)
		l.outline_size = 0
		l.shaded = true
		l.position = Vector3(0, 1.75, z)
		l.rotation.y = 0.0 if z > 0.1 else PI
		add_child(l)
	MeshMerge.boxes(self)
