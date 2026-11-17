## Rodeo arena: a dirt ring inside a high plank fence, three bucking chutes at one end, wooden
## bleachers along one side and an announcer's stand with a flag. Hosts a rodeo every season
## that brings in money and reputation. Front (bleachers) faces +Z.
class_name RodeoArena
extends Building

const RX := 10.0   # ring half size
const RZ := 7.0
const SIDES := 18


func _foot() -> Rect2:
	return Rect2(-RX - 2.6, -RZ - 0.6, (RX + 2.6) * 2, RZ * 2 + 5.4)


func _ready() -> void:
	# ring of fence panels: posts and three planks between them
	var pts: Array[Vector3] = []
	for i in SIDES:
		var a := TAU * i / SIDES
		pts.append(Vector3(cos(a) * RX, 0, sin(a) * RZ))
	for i in SIDES:
		var a := pts[i]
		var b := pts[(i + 1) % SIDES]
		_box(Vector3(0.22, 2.0, 0.22), a + Vector3(0, 1.0, 0), wood)
		var mid := (a + b) * 0.5
		var yaw := atan2(b.x - a.x, b.z - a.z)
		for h in [0.5, 1.05, 1.6]:
			_box(Vector3(0.07, 0.24, a.distance_to(b) + 0.1), mid + Vector3(0, h, 0), white, Vector3(0, yaw, 0))
	# dirt floor of the ring
	var floor_mi := _cyl(1.0, 0.04, Vector3(0, 0.02, 0), _dirt(), SIDES)
	floor_mi.scale = Vector3(RX - 0.1, 1.0, RZ - 0.1)
	# bucking chutes at the -x end: three narrow pens with gates facing the ring
	for k in 3:
		var z := (k - 1) * 1.5
		for side in [-0.7, 0.7]:
			_box(Vector3(2.4, 2.1, 0.1), Vector3(-RX - 1.3, 1.05, z + side), wood)
		_box(Vector3(0.1, 1.9, 1.3), Vector3(-RX - 0.05, 0.95, z), red)  # gate
	_box(Vector3(2.6, 0.12, 4.6), Vector3(-RX - 1.3, 2.15, 0), wood)  # catwalk over the chutes
	# bleachers outside the +z side
	for row in 4:
		var y := 0.45 + row * 0.45
		var z := RZ + 1.0 + row * 0.75
		_box(Vector3(12.0, 0.1, 0.55), Vector3(0, y, z), wood)  # seat
		_box(Vector3(12.0, 0.45, 0.06), Vector3(0, y - 0.22, z - 0.3), wood)  # riser
	for x in [-6.0, -2.0, 2.0, 6.0]:
		_beam(Vector3(x, 0, RZ + 0.8), Vector3(x, 1.85, RZ + 3.5), 0.14, wood)
		_box(Vector3(0.14, 1.9, 0.14), Vector3(x, 0.95, RZ + 3.5), wood)
	# announcer's stand with a flag, at the +x end of the bleachers
	var ax := 7.6
	var az := RZ + 2.6
	for p in [Vector2(-0.9, -0.9), Vector2(0.9, -0.9), Vector2(-0.9, 0.9), Vector2(0.9, 0.9)]:
		_box(Vector3(0.16, 2.4, 0.16), Vector3(ax + p.x, 1.2, az + p.y), wood)
	_box(Vector3(2.1, 0.12, 2.1), Vector3(ax, 2.4, az), wood)
	_box(Vector3(2.1, 1.0, 0.08), Vector3(ax, 2.95, az + 1.0), red)
	_box(Vector3(2.1, 1.0, 0.08), Vector3(ax, 2.95, az - 1.0), red)
	_box(Vector3(2.4, 0.1, 2.4), Vector3(ax, 4.1, az), roof)
	for p in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0)]:
		_box(Vector3(0.1, 1.7, 0.1), Vector3(ax + p.x, 3.25, az + p.y), wood)
	_beam(Vector3(ax, 4.1, az), Vector3(ax, 7.0, az), 0.06, iron)  # flagpole
	_box(Vector3(1.3, 0.75, 0.03), Vector3(ax + 0.67, 6.6, az), white)  # ranch pennant: cream with a red hoist
	_box(Vector3(0.3, 0.75, 0.035), Vector3(ax + 0.17, 6.6, az), red)
	MeshMerge.boxes(self)


func _dirt() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX + "dirt_diff.jpg")
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.25, 0.25, 0.25)
	m.albedo_color = Color(0.85, 0.72, 0.55)
	m.roughness = 1.0
	return m
