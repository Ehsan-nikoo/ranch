## Procedural gambrel-roof red barn with a lean-to shed. Origin = ground center, front faces +Z.
class_name Barn
extends Building

const W := 5.0        # half width (x)
const L := 7.0        # half length (z)
const EAVE := 5.0
const KNEE := Vector2(3.4, 7.3)
const RIDGE := 8.6
const OVER := 0.5     # roof overhang

var vane := Node3D.new()


func hay_room() -> int:
	return 40 + 20 * (level - 1)


func shelter_room() -> int:
	return 15 + 10 * (level - 1)


func upgrades() -> Array:
	return [1500, 3000]


func upgrade_text() -> String:
	return "جای ۱۰ گاو و ۲۰ بسته یونجه‌ی بیشتر"


func _foot() -> Rect2:
	return Rect2(-5.6, -7.8, 15.4, 15.6)  # includes the lean-to on +x


func _process(_delta: float) -> void:
	# weathervane drifts with the wind
	vane.rotation.y = 0.6 + sin(Time.get_ticks_msec() * 0.0004) * 0.5 + sin(Time.get_ticks_msec() * 0.0011) * 0.15


func _ready() -> void:
	eave = EAVE
	_walls()
	_roof()
	_trim()
	_front()
	_sides()
	_cupola()
	_lean_to()
	MeshMerge.boxes(self)


func _gable_pts(z: float) -> Array:
	return [Vector3(-W, EAVE, z), Vector3(W, EAVE, z), Vector3(KNEE.x, KNEE.y, z),
		Vector3(0, RIDGE, z), Vector3(-KNEE.x, KNEE.y, z)]


func _walls() -> void:
	var st := _st()
	var t: float = red.get_meta("tile")
	for s in [-1.0, 1.0]:
		var z: float = L * s
		_wall(st, Vector3(-W * s, 0, z), Vector3(W * s, 0, z), EAVE, Vector3(0, 0, s), t, false)
		_poly(st, _gable_pts(z), Vector3(0, 0, s), Vector3(s, 0, 0), Vector3.DOWN, t)
		_wall(st, Vector3(W * s, 0, z), Vector3(W * s, 0, -z), EAVE, Vector3(s, 0, 0), t, true)
	_commit(st, red)
	_box(Vector3(W * 2 + 0.3, 0.45, L * 2 + 0.3), Vector3(0, 0.12, 0), stone)  # foundation


func _roof() -> void:
	var st := _st()
	var t: float = roof.get_meta("tile")
	var along := Vector3(0, 0, L + OVER)
	for side in [-1.0, 1.0]:
		var knee := Vector3(KNEE.x * side, KNEE.y, 0)
		var e := Vector3(W * side, EAVE, 0)
		e += (e - knee).normalized() * OVER  # overhang past the eave along the lower slope
		_slab(st, Vector3(0, RIDGE, 0), knee, along, t, false)
		_slab(st, knee, e, along, t)
	_commit(st, roof)
	_box(Vector3(0.45, 0.12, along.z * 2), Vector3(0, RIDGE + THICK + 0.02, 0), roof)  # ridge cap


func _trim() -> void:
	var zf := L + OVER + 0.04
	var e := Vector3(W, EAVE, 0) + (Vector3(W, EAVE, 0) - Vector3(KNEE.x, KNEE.y, 0)).normalized() * OVER
	for s in [-1.0, 1.0]:
		var z: float = s * zf
		for x in [-1.0, 1.0]:
			# rake boards follow the gambrel profile on both gables
			_board(Vector3(e.x * x, e.y, z), Vector3(KNEE.x * x, KNEE.y + THICK, z), 0.22, 0.08, white)
			_board(Vector3(KNEE.x * x, KNEE.y + THICK, z), Vector3(0, RIDGE + THICK + 0.06, z), 0.22, 0.08, white)
			_box(Vector3(0.22, EAVE - 0.3, 0.22), Vector3(W * x, EAVE * 0.5 + 0.15, L * s), white)  # corner boards
		_box(Vector3(0.06, 0.2, zf * 2), Vector3(s * (e.x + 0.03), e.y, 0), white)  # eave fascia
		_box(Vector3(W * 2 + 0.1, 0.18, 0.08), Vector3(0, EAVE, L * s + 0.05 * s), white)  # gable band


func _front() -> void:
	var z := L + 0.1
	# two sliding doors, one slid slightly open to show the dark interior
	_box(Vector3(4.6, 4.1, 0.05), Vector3(0, 2.05 + 0.2, L + 0.02), window_mat)
	for i in [-1, 1]:
		var cx: float = i * 1.15 + (0.55 if i > 0 else 0.0)
		_box(Vector3(2.3, 4.0, 0.12), Vector3(cx, 2.25, z), red)
		_x_panel(cx, 2.25, 2.3, 4.0, z + 0.08)
	_box(Vector3(7.4, 0.12, 0.14), Vector3(0.6, 4.4, z + 0.04), iron)  # door track
	# hayloft door + hood beam
	_box(Vector3(1.9, 1.9, 0.12), Vector3(0, 6.35, L + 0.05), red)
	_x_panel(0, 6.35, 1.9, 1.9, L + 0.13)
	_box(Vector3(0.22, 0.22, 1.6), Vector3(0, RIDGE - 0.35, L + 0.6), wood)
	_box(Vector3(0.05, 1.0, 0.05), Vector3(0, RIDGE - 0.95, L + 1.25), iron)  # pulley rope
	for x in [-3.6, 3.6]:
		_window(Vector3(x, 2.6, L), Vector3(0, 0, 1))
	_box(Vector3(2.6, 0.5, 0.06), Vector3(0, 4.85, L + 0.08), white)  # sign board


func _sides() -> void:
	for z in [-4.5, -1.5, 1.5, 4.5]:
		_window(Vector3(-W, 2.8, z), Vector3(-1, 0, 0))
	for z in [3.5, 5.5]:
		_window(Vector3(W, 2.8, z), Vector3(1, 0, 0))


func _cupola() -> void:
	var y := RIDGE + 0.1
	_box(Vector3(1.4, 1.2, 1.4), Vector3(0, y + 0.6, 0), white)
	for r in [0.0, PI * 0.5]:  # louvered vents, dark slats
		for k in 4:
			_box(Vector3(0.9, 0.06, 1.44), Vector3(0, y + 0.3 + k * 0.18, 0), glass, Vector3(0.0, r, 0.0))
	_cyl(1.25, 0.9, Vector3(0, y + 1.65, 0), roof, 4, 0.0).rotation.y = PI * 0.25
	# weathervane
	_box(Vector3(0.04, 1.1, 0.04), Vector3(0, y + 2.6, 0), iron)
	vane.position = Vector3(0, y + 2.75, 0)
	add_child(vane)
	for part in [_box(Vector3(0.9, 0.05, 0.05), Vector3.ZERO, iron), _box(Vector3(0.25, 0.25, 0.02), Vector3(0.45, 0, 0), iron, Vector3(0, 0, PI * 0.25))]:
		part.reparent(vane, false)


func _lean_to() -> void:
	# open-sided shed on the +X side, rafters resting on the barn wall
	var x1 := W + 4.2
	var z0 := -6.0
	var z1 := 2.0
	var y1 := 3.0
	var zm := (z0 + z1) * 0.5
	var st := _st()
	_slab(st, Vector3(W, 4.4, zm), Vector3(x1 + 0.4, y1 - 0.13, zm), Vector3(0, 0, (z1 - z0) * 0.5 + 0.3), roof.get_meta("tile"), false)
	_commit(st, roof)
	for z in [z0, zm, z1]:
		_box(Vector3(0.22, y1, 0.22), Vector3(x1, y1 * 0.5, z), wood)
	_box(Vector3(0.2, 0.25, z1 - z0 + 0.4), Vector3(x1, y1 - 0.05, zm), wood)
