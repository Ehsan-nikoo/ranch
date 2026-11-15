## Procedural gambrel-roof red barn with a lean-to shed. Origin = ground center, front faces +Z.
class_name Barn
extends Node3D

const TEX := "res://textures/"
const W := 5.0        # half width (x)
const L := 7.0        # half length (z)
const EAVE := 5.0
const KNEE := Vector2(3.4, 7.3)
const RIDGE := 8.6
const OVER := 0.5     # roof overhang
const THICK := 0.08
# wall rows: vertex colors only vary per vertex, so walls get rows where dirt/eave shading changes
const ROWS := [0.0, 0.35, 0.8, 1.4, 3.9, 4.5, 5.0]

var red: StandardMaterial3D
var roof: StandardMaterial3D
var white: StandardMaterial3D
var wood: StandardMaterial3D
var iron := _plain(Color(0.12, 0.11, 0.1), 0.6, 0.7)
var glass := _plain(Color(0.06, 0.07, 0.08), 0.25)
var stone := _plain(Color(0.38, 0.35, 0.31), 1.0)
var vane := Node3D.new()
## Shared by all window panes so DayCycle can light them at night in one place.
static var window_mat := _window_mat()


static func _window_mat() -> StandardMaterial3D:
	var m := _plain(Color(0.06, 0.07, 0.08), 0.25)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.62, 0.3)
	m.emission_energy_multiplier = 0.0
	return m


func _process(delta: float) -> void:
	# weathervane drifts with the wind
	vane.rotation.y = 0.6 + sin(Time.get_ticks_msec() * 0.0004) * 0.5 + sin(Time.get_ticks_msec() * 0.0011) * 0.15


func _ready() -> void:
	red = _tex("barn_red_diff.jpg", "distressed_painted_planks", 2.6)
	white = _tex("trim_white_diff.jpg", "distressed_painted_planks", 2.6, true)
	wood = _tex("trim_white_diff.jpg", "distressed_painted_planks", 2.6, true)
	wood.albedo_color = Color(0.62, 0.5, 0.38)
	roof = _tex("roof_rusty_diff.jpg", "corrugated_iron", 2.0)
	roof.metallic = 0.2
	_walls()
	_roof()
	_trim()
	_front()
	_sides()
	_cupola()
	_lean_to()
	MeshMerge.boxes(self)


# ---------- materials ----------

func _tex(diff: String, src: String, tile: float, triplanar := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX + diff)
	m.normal_enabled = true
	m.normal_texture = load(TEX + src + "_nor_gl.jpg")
	var arm: Texture2D = load(TEX + src + "_arm.jpg")
	m.roughness_texture = arm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.metallic_texture = arm
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	m.metallic = 0.0
	m.ao_enabled = true
	m.ao_texture = arm
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	if triplanar:
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE / tile
	else:
		m.vertex_color_use_as_albedo = true
	m.set_meta("tile", tile)
	return m


static func _plain(c: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


# ---------- mesh helpers ----------

## Fake ground dirt + eave occlusion baked into vertex color (Mobile renderer has no SSAO).
func _shade(p: Vector3, eave_ao: bool) -> Color:
	var dirt := 1.0 - smoothstep(0.0, 1.4, p.y)
	var c := Color.WHITE.lerp(Color(0.5, 0.42, 0.34), dirt * 0.8)
	if eave_ao:
		c = c * lerpf(1.0, 0.62, smoothstep(3.9, 5.0, p.y))
	c.a = 1.0
	return c


## Adds a convex polygon facing `n`, triangulated as a fan with planar UVs.
func _poly(st: SurfaceTool, pts: Array, n: Vector3, uax: Vector3, vax: Vector3, tile: float, eave_ao := false) -> void:
	for i in range(1, pts.size() - 1):
		var tri := [pts[0], pts[i], pts[i + 1]]
		if (tri[1] - tri[0]).cross(tri[2] - tri[0]).dot(n) > 0.0:
			tri = [tri[0], tri[2], tri[1]]  # Godot front faces are clockwise
		for p: Vector3 in tri:
			st.set_normal(n)
			st.set_uv(Vector2(p.dot(uax), p.dot(vax)) / tile)
			st.set_color(_shade(p, eave_ao))
			st.add_vertex(p)


## Vertical wall rectangle from a to b (bottom edge), split into ROWS up to `top`.
func _wall(st: SurfaceTool, a: Vector3, b: Vector3, top: float, n: Vector3, tile: float, eave_ao: bool) -> void:
	var uax := (b - a).normalized()
	for i in ROWS.size() - 1:
		var y0: float = ROWS[i]
		var y1: float = minf(ROWS[i + 1], top)
		if y0 >= top:
			break
		_poly(st, [a + Vector3.UP * y0, b + Vector3.UP * y0, b + Vector3.UP * y1, a + Vector3.UP * y1], n, uax, Vector3.DOWN, tile, eave_ao)


func _commit(st: SurfaceTool, m: Material) -> MeshInstance3D:
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	add_child(mi)
	return mi


func _box(size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
	return mi


## Thin board from a to b lying in a plane facing +Z/-Z (gable faces, doors).
func _board(a: Vector3, b: Vector3, w: float, d: float, m: Material) -> void:
	var dlt := b - a
	_box(Vector3(w, dlt.length(), d), (a + b) * 0.5, m, Vector3(0, 0, -atan2(dlt.x, dlt.y)))


func _st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


# ---------- parts ----------

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
	# stone foundation
	_box(Vector3(W * 2 + 0.3, 0.45, L * 2 + 0.3), Vector3(0, 0.12, 0), stone)


func _roof() -> void:
	var st := _st()
	var t: float = roof.get_meta("tile")
	var zl := L + OVER
	for side in [-1.0, 1.0]:
		var prof := [Vector2(0, RIDGE), Vector2(KNEE.x * side, KNEE.y), Vector2(W * side, EAVE)]
		# extend past the eave along the lower slope
		prof[2] += (prof[2] - prof[1]).normalized() * OVER
		for i in 2:
			var hi: Vector2 = prof[i]
			var lo: Vector2 = prof[i + 1]
			var tg := (lo - hi).normalized()
			var n2 := Vector2(-tg.y, tg.x) if side > 0 else Vector2(tg.y, -tg.x)
			var n := Vector3(n2.x, n2.y, 0)
			var off := n * THICK
			var h3 := Vector3(hi.x, hi.y, 0)
			var l3 := Vector3(lo.x, lo.y, 0)
			var vax := Vector3(tg.x, tg.y, 0)
			var quad := [h3 + Vector3(0, 0, -zl), h3 + Vector3(0, 0, zl), l3 + Vector3(0, 0, zl), l3 + Vector3(0, 0, -zl)]
			_poly(st, quad.map(func(p): return p + off), n, Vector3.BACK, vax, t)
			_poly(st, quad, -n, Vector3.BACK, vax, t)
			if i == 1:  # eave edge
				_poly(st, [quad[2], quad[3], quad[3] + off, quad[2] + off], Vector3(tg.x, tg.y, 0), Vector3.BACK, Vector3.DOWN, t)
	_commit(st, roof)
	# ridge cap
	_box(Vector3(0.45, 0.12, zl * 2), Vector3(0, RIDGE + THICK + 0.02, 0), roof)


func _trim() -> void:
	var zf := L + OVER + 0.04
	var e := Vector3(W, EAVE, 0) + (Vector3(W, EAVE, 0) - Vector3(KNEE.x, KNEE.y, 0)).normalized() * OVER
	for s in [-1.0, 1.0]:
		var z: float = s * zf
		for x in [-1.0, 1.0]:
			# rake boards follow the gambrel profile on both gables
			_board(Vector3(e.x * x, e.y, z), Vector3(KNEE.x * x, KNEE.y + THICK, z), 0.22, 0.08, white)
			_board(Vector3(KNEE.x * x, KNEE.y + THICK, z), Vector3(0, RIDGE + THICK + 0.06, z), 0.22, 0.08, white)
			# corner boards
			_box(Vector3(0.22, EAVE - 0.3, 0.22), Vector3(W * x, EAVE * 0.5 + 0.15, L * s), white)
		# eave fascia
		_box(Vector3(0.06, 0.2, zf * 2), Vector3(s * (e.x + 0.03), e.y, 0), white)
	# horizontal band where gable meets wall
	for s in [-1.0, 1.0]:
		_box(Vector3(W * 2 + 0.1, 0.18, 0.08), Vector3(0, EAVE, L * s + 0.05 * s), white)


func _x_panel(cx: float, cy: float, w: float, h: float, z: float) -> void:
	# white frame + X brace, the classic barn-door look
	var hw := w * 0.5
	var hh := h * 0.5
	var b := 0.16
	_box(Vector3(w, b, 0.06), Vector3(cx, cy + hh - b * 0.5, z), white)
	_box(Vector3(w, b, 0.06), Vector3(cx, cy - hh + b * 0.5, z), white)
	_box(Vector3(b, h, 0.06), Vector3(cx - hw + b * 0.5, cy, z), white)
	_box(Vector3(b, h, 0.06), Vector3(cx + hw - b * 0.5, cy, z), white)
	_board(Vector3(cx - hw + b, cy - hh + b, z), Vector3(cx + hw - b, cy + hh - b, z), 0.14, 0.05, white)
	_board(Vector3(cx + hw - b, cy - hh + b, z), Vector3(cx - hw + b, cy + hh - b, z), 0.14, 0.05, white)


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
	# side windows on the front gable
	for x in [-3.6, 3.6]:
		_window(Vector3(x, 2.6, L), Vector3(0, 0, 1))
	# sign board over the doors
	_box(Vector3(2.6, 0.5, 0.06), Vector3(0, 4.85, L + 0.08), white)


func _window(at: Vector3, n: Vector3) -> void:
	var rot := Vector3(0, atan2(n.x, n.z), 0)
	var mi := _box(Vector3(1.0, 1.1, 0.06), at + n * 0.04, white, rot)
	_box(Vector3(0.78, 0.88, 0.06), at + n * 0.07, window_mat, rot)
	_box(Vector3(0.06, 0.88, 0.07), at + n * 0.08, white, rot)
	_box(Vector3(0.78, 0.06, 0.07), at + n * 0.08, white, rot)
	_box(Vector3(1.2, 0.08, 0.16), at + n * 0.1 + Vector3(0, -0.6, 0), white, rot)


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
	var cap := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 1.25
	cm.height = 0.9
	cm.radial_segments = 4
	cap.mesh = cm
	cap.material_override = roof
	cap.position = Vector3(0, y + 1.65, 0)
	cap.rotation.y = PI * 0.25
	add_child(cap)
	# weathervane
	_box(Vector3(0.04, 1.1, 0.04), Vector3(0, y + 2.6, 0), iron)
	vane.position = Vector3(0, y + 2.75, 0)
	add_child(vane)
	for part in [_box(Vector3(0.9, 0.05, 0.05), Vector3.ZERO, iron), _box(Vector3(0.25, 0.25, 0.02), Vector3(0.45, 0, 0), iron, Vector3(0, 0, PI * 0.25))]:
		part.reparent(vane, false)


func _lean_to() -> void:
	# open-sided shed on the +X side, rafters resting on the barn wall
	var x0 := W
	var x1 := W + 4.2
	var z0 := -6.0
	var z1 := 2.0
	var y0 := 4.4
	var y1 := 3.0
	var st := _st()
	var t: float = roof.get_meta("tile")
	var a := Vector3(x0, y0, z0 - 0.3)
	var b := Vector3(x0, y0, z1 + 0.3)
	var c := Vector3(x1 + 0.4, y1 - 0.13, z1 + 0.3)
	var d := Vector3(x1 + 0.4, y1 - 0.13, z0 - 0.3)
	var slope := (c - b).normalized()
	var n := slope.cross(Vector3.BACK).normalized()
	if n.y < 0:
		n = -n
	_poly(st, [a, b, c, d].map(func(p): return p + n * THICK), n, Vector3.BACK, slope, t)
	_poly(st, [a, b, c, d], -n, Vector3.BACK, slope, t)
	_commit(st, roof)
	for z in [z0, (z0 + z1) * 0.5, z1]:
		_box(Vector3(0.22, y1, 0.22), Vector3(x1, y1 * 0.5, z), wood)
	_box(Vector3(0.2, 0.25, z1 - z0 + 0.4), Vector3(x1, y1 - 0.05, (z0 + z1) * 0.5), wood)
