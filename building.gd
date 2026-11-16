## Shared materials and mesh helpers for procedural ranch buildings. Origin = ground center.
class_name Building
extends Node3D

const TEX := "res://textures/"
const THICK := 0.08  # roof sheet thickness

## Shared by all window panes so DayCycle can light them at night in one place.
static var window_mat := _window_mat()
static var _mats := {}

## Wall height; drives the eave shadow baked into wall vertex colors.
var eave := 5.0
var red: StandardMaterial3D
var white: StandardMaterial3D
var wood: StandardMaterial3D
var roof: StandardMaterial3D
var iron: StandardMaterial3D
var glass: StandardMaterial3D
var stone: StandardMaterial3D
var siding: StandardMaterial3D
var concrete: StandardMaterial3D
var green: StandardMaterial3D
var steel: StandardMaterial3D
var water: StandardMaterial3D


func _init() -> void:
	if _mats.is_empty():  # one set of materials for every building
		_mats = {
			red = _tex("barn_red_diff.jpg", "distressed_painted_planks", 2.6),
			white = _tex("trim_white_diff.jpg", "distressed_painted_planks", 2.6, true),
			wood = _tex("trim_white_diff.jpg", "distressed_painted_planks", 2.6, true),
			roof = _tex("roof_rusty_diff.jpg", "corrugated_iron", 2.0),
			iron = _plain(Color(0.12, 0.11, 0.1), 0.6, 0.7),
			glass = _plain(Color(0.06, 0.07, 0.08), 0.25),
			stone = _plain(Color(0.38, 0.35, 0.31), 1.0),
			siding = _tex("trim_white_diff.jpg", "distressed_painted_planks", 2.6),
			concrete = _tex("trim_white_diff.jpg", "distressed_painted_planks", 2.0, true),
			green = _plain(Color(0.09, 0.18, 0.13), 0.8),
			steel = _plain(Color(0.42, 0.43, 0.42), 0.45, 0.6),
			water = _plain(Color(0.16, 0.26, 0.27), 0.05),
		}
		_mats.wood.albedo_color = Color(0.62, 0.5, 0.38)
		_mats.siding.albedo_color = Color(0.96, 0.93, 0.84)
		_mats.concrete.albedo_color = Color(0.74, 0.71, 0.66)
	red = _mats.red
	white = _mats.white
	wood = _mats.wood
	roof = _mats.roof
	iron = _mats.iron
	glass = _mats.glass
	stone = _mats.stone
	siding = _mats.siding
	concrete = _mats.concrete
	green = _mats.green
	steel = _mats.steel
	water = _mats.water


# ---------- materials ----------

static func _window_mat() -> StandardMaterial3D:
	var m := _plain(Color(0.06, 0.07, 0.08), 0.25)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.62, 0.3)
	m.emission_energy_multiplier = 0.0
	return m


static func _tex(diff: String, src: String, tile: float, triplanar := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX + diff)
	m.normal_enabled = true
	m.normal_texture = load(TEX + src + "_nor_gl.jpg")
	var arm: Texture2D = load(TEX + src + "_arm.jpg")
	m.roughness_texture = arm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
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
		c = c * lerpf(1.0, 0.62, smoothstep(eave - 1.1, eave, p.y))
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


## Vertical wall from bottom edge a->b up to `top`, split into rows so vertex shading has steps.
## `lap` turns the board texture sideways for horizontal clapboard.
func _wall(st: SurfaceTool, a: Vector3, b: Vector3, top: float, n: Vector3, tile: float, eave_ao: bool, lap := false) -> void:
	var along := (b - a).normalized()
	var rows := [0.0, 0.35, 0.8, 1.4, eave - 1.1, eave - 0.5, eave]
	for i in rows.size() - 1:
		var y0: float = rows[i]
		var y1: float = minf(rows[i + 1], top)
		if y0 >= top or y1 <= y0:
			continue
		var q := [a + Vector3.UP * y0, b + Vector3.UP * y0, b + Vector3.UP * y1, a + Vector3.UP * y1]
		if lap:
			_poly(st, q, n, Vector3.DOWN, along, tile, eave_ao)
		else:
			_poly(st, q, n, along, Vector3.DOWN, tile, eave_ao)


## Roof sheet from ridge edge `hi` down to eave edge `lo`, spanning +-`along`, with thickness.
func _slab(st: SurfaceTool, hi: Vector3, lo: Vector3, along: Vector3, tile: float, eave_edge := true) -> void:
	var down := (lo - hi).normalized()
	var n := down.cross(along).normalized()
	if n.y < 0.0:
		n = -n
	var off := n * THICK
	var u := along.normalized()
	var q := [hi - along, hi + along, lo + along, lo - along]
	_poly(st, q.map(func(p): return p + off), n, u, down, tile)
	_poly(st, q, -n, u, down, tile)
	if eave_edge:
		_poly(st, [q[2], q[3], q[3] + off, q[2] + off], down, u, Vector3.DOWN, tile)


func _commit(st: SurfaceTool, m: Material) -> MeshInstance3D:
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	add_child(mi)
	return mi


func _st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


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


## Square beam from a to b in any direction (tower legs, braces).
func _beam(a: Vector3, b: Vector3, w: float, m: Material) -> MeshInstance3D:
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var mi := _box(Vector3(w, a.distance_to(b), w), Vector3.ZERO, m)
	mi.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
	return mi


func _cyl(r: float, h: float, pos: Vector3, m: Material, segs := 24, top_r := -1.0) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.bottom_radius = r
	cm.top_radius = r if top_r < 0.0 else top_r
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	return mi


## White frame + X brace, the classic barn-door look.
func _x_panel(cx: float, cy: float, w: float, h: float, z: float) -> void:
	var hw := w * 0.5
	var hh := h * 0.5
	var b := 0.16
	_box(Vector3(w, b, 0.06), Vector3(cx, cy + hh - b * 0.5, z), white)
	_box(Vector3(w, b, 0.06), Vector3(cx, cy - hh + b * 0.5, z), white)
	_box(Vector3(b, h, 0.06), Vector3(cx - hw + b * 0.5, cy, z), white)
	_box(Vector3(b, h, 0.06), Vector3(cx + hw - b * 0.5, cy, z), white)
	_board(Vector3(cx - hw + b, cy - hh + b, z), Vector3(cx + hw - b, cy + hh - b, z), 0.14, 0.05, white)
	_board(Vector3(cx + hw - b, cy - hh + b, z), Vector3(cx - hw + b, cy + hh - b, z), 0.14, 0.05, white)


## Four-pane window with sill on a wall facing `n`; optional shutters in `shutter` material.
func _window(at: Vector3, n: Vector3, frame: Material = null, shutter: Material = null) -> void:
	var f := frame if frame else white
	var rot := Vector3(0, atan2(n.x, n.z), 0)
	var side := Vector3(n.z, 0, -n.x)
	_box(Vector3(1.0, 1.1, 0.06), at + n * 0.04, f, rot)
	_box(Vector3(0.78, 0.88, 0.06), at + n * 0.07, window_mat, rot)
	_box(Vector3(0.06, 0.88, 0.07), at + n * 0.08, f, rot)
	_box(Vector3(0.78, 0.06, 0.07), at + n * 0.08, f, rot)
	_box(Vector3(1.2, 0.08, 0.16), at + n * 0.1 + Vector3(0, -0.6, 0), f, rot)
	if shutter:
		for s in [-1.0, 1.0]:
			_box(Vector3(0.42, 1.15, 0.05), at + n * 0.06 + side * s * 0.74, shutter, rot)
