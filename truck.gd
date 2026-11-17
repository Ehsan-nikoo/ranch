## Old ranch pickup that brings purchases: hay bales stacked in the bed, calves in a slatted
## stock trailer behind. Front faces +Z, wheels on the ground at y=0.
## Extends Building only for its materials and mesh helpers; Delivery keeps trucks out of the
## world's direct children, so herd, builder and save never treat a truck as a building.
class_name Truck
extends Building

const WHEEL_R := 0.42

var calves := 0
var hay_bales := 0
var paint := _plain(Color(0.19, 0.34, 0.37), 0.5, 0.2)  # faded teal
var rust := _plain(Color(0.33, 0.18, 0.1), 0.9)
var tire := _plain(Color(0.04, 0.04, 0.04), 0.95)
var wheels: Array[Node3D] = []


func _ready() -> void:
	_body()
	for p in [Vector3(0.85, 0, 1.55), Vector3(-0.85, 0, 1.55), Vector3(0.85, 0, -1.55), Vector3(-0.85, 0, -1.55)]:
		_wheel(p, self)
	if hay_bales > 0:
		_hay()
	if calves > 0:
		_trailer()
	MeshMerge.boxes(self)


## Turns the wheels for `dist` meters driven.
func roll(dist: float) -> void:
	for w in wheels:
		w.rotation.x += dist / WHEEL_R


func _body() -> void:
	_box(Vector3(1.5, 0.2, 4.9), Vector3(0, 0.55, -0.1), iron)             # frame
	_box(Vector3(1.5, 0.62, 1.45), Vector3(0, 1.08, 1.68), paint)          # hood
	_box(Vector3(1.05, 0.58, 0.08), Vector3(0, 1.02, 2.42), steel)         # grille
	for k in 5:
		_box(Vector3(0.95, 0.04, 0.1), Vector3(0, 0.8 + k * 0.11, 2.46), iron)
	_box(Vector3(1.95, 0.18, 0.16), Vector3(0, 0.6, 2.5), steel)           # bumpers
	_box(Vector3(1.95, 0.18, 0.16), Vector3(0, 0.6, -2.62), steel)
	for z in [1.55, -1.55]:                                                 # fenders over the wheels
		_box(Vector3(1.98, 0.22, 1.15), Vector3(0, 0.98, z), paint)
		for s in [-1.0, 1.0]:
			_box(Vector3(0.1, 0.3, 1.0), Vector3(0.94 * s, 0.82, z), paint)
	for s in [-1.0, 1.0]:
		var h := _cyl(0.13, 0.1, Vector3(0.62 * s, 1.12, 2.42), Building.window_mat, 12)  # headlights glow at night
		h.rotation.x = PI * 0.5
		_box(Vector3(0.08, 0.06, 1.0), Vector3(0.98 * s, 0.75, 0.35), steel)  # running board
	# cab with glass all round
	_box(Vector3(1.75, 1.2, 1.4), Vector3(0, 1.68, 0.35), paint)
	_box(Vector3(1.82, 0.08, 1.52), Vector3(0, 2.3, 0.35), paint)
	_box(Vector3(1.5, 0.55, 0.05), Vector3(0, 1.98, 1.06), glass)
	_box(Vector3(1.2, 0.4, 0.05), Vector3(0, 1.98, -0.36), glass)
	for s in [-1.0, 1.0]:
		_box(Vector3(0.05, 0.5, 0.95), Vector3(0.88 * s, 1.98, 0.4), glass)
		_box(Vector3(0.06, 0.08, 0.22), Vector3(0.95 * s, 1.95, 1.0), iron)  # mirrors
	_box(Vector3(0.4, 0.3, 0.06), Vector3(0.55, 1.15, 0.0), rust)         # a patch of rust on the door
	# bed with plank floor, low steel sides and tall wooden stake rails
	_box(Vector3(1.8, 0.1, 2.3), Vector3(0, 1.0, -1.45), wood)
	for s in [-1.0, 1.0]:
		_box(Vector3(0.08, 0.45, 2.3), Vector3(0.9 * s, 1.28, -1.45), paint)
		for z in [-0.45, -1.45, -2.5]:
			_box(Vector3(0.08, 0.7, 0.08), Vector3(0.9 * s, 1.75, z), wood)
		for y in [1.75, 2.05]:
			_box(Vector3(0.06, 0.1, 2.3), Vector3(0.9 * s, y, -1.45), wood)
	_box(Vector3(1.8, 0.45, 0.08), Vector3(0, 1.28, -2.6), paint)         # tailgate
	_box(Vector3(1.8, 0.95, 0.08), Vector3(0, 1.5, -0.32), wood)          # headboard


func _wheel(at: Vector3, parent: Node3D) -> void:
	var w := Node3D.new()
	w.position = at + Vector3(0, WHEEL_R, 0)
	parent.add_child(w)
	var t := _cyl(WHEEL_R, 0.3, Vector3.ZERO, tire, 16)
	t.rotation.z = PI * 0.5
	t.reparent(w, false)
	var hub := _cyl(0.2, 0.32, Vector3.ZERO, steel, 10)
	hub.rotation.z = PI * 0.5
	hub.reparent(w, false)
	wheels.append(w)


func _hay() -> void:
	var hay := StandardMaterial3D.new()
	hay.albedo_texture = load(TEX + "grass_ground_diff.jpg")
	hay.albedo_color = Color(0.95, 0.76, 0.4)
	hay.uv1_triplanar = true
	hay.uv1_scale = Vector3(3, 3, 3)
	hay.roughness = 1.0
	var spots := [Vector3(0.42, 1.31, -0.85), Vector3(-0.42, 1.31, -0.85), Vector3(0.42, 1.31, -2.0), Vector3(-0.42, 1.31, -2.0),
		Vector3(0.0, 1.83, -0.85), Vector3(0.0, 1.83, -2.0)]
	for i in mini(spots.size(), ceili(hay_bales / 2.0)):  # 2 bales of load per bale shown, so 10 fill the bed
		_box(Vector3(0.8, 0.52, 1.05), spots[i], hay, Vector3(0, randf_range(-0.06, 0.06), 0))


func _trailer() -> void:
	var t := Node3D.new()
	t.position = Vector3(0, 0, -5.4)
	add_child(t)
	_beam(Vector3(0, 0.62, -2.65), Vector3(0, 0.62, -3.8), 0.12, iron)  # hitch
	var parts := [
		_box(Vector3(2.0, 0.12, 3.2), Vector3(0, 0.75, 0), wood),       # floor
		_box(Vector3(2.0, 0.1, 3.2), Vector3(0, 2.15, 0), paint),       # roof frame
		_box(Vector3(2.0, 1.4, 0.08), Vector3(0, 1.45, 1.6), wood),     # front wall
	]
	for s in [-1.0, 1.0]:
		for y in [1.0, 1.35, 1.7, 2.0]:                                 # slatted sides: calves show through
			parts.append(_box(Vector3(0.06, 0.16, 3.2), Vector3(1.0 * s, y, 0), wood))
		for z in [-1.55, 0.0, 1.55]:
			parts.append(_box(Vector3(0.1, 1.45, 0.1), Vector3(1.0 * s, 1.45, z), paint))
	for y in [1.0, 1.4, 1.8]:                                           # rear gate
		parts.append(_box(Vector3(2.0, 0.14, 0.06), Vector3(0, y, -1.6), wood))
	for p in parts:
		p.reparent(t, false)
	for s in [-1.0, 1.0]:
		_wheel(Vector3(0.95 * s, 0, 0), t)
		_box(Vector3(0.2, 0.2, 1.0), Vector3(0.95 * s, 0.95, 0), paint).reparent(t, false)
	for i in mini(calves, 3):                                           # the calves themselves, idling
		var c := MeshInstance3D.new()
		c.mesh = CowMesh.mesh()
		c.material_override = CowMesh.material()
		c.scale = Vector3.ONE * 0.62
		c.position = Vector3([0.0, -0.45, 0.45][i], 0.8, [0.5, -0.7, -0.7][i])
		t.add_child(c)
	MeshMerge.boxes(t)
