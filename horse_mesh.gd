## The ranch horse: "Free to use - Low Poly Horse" by chi3dmodel (CC-BY 4.0), see models/horse/license.txt.
## The model has no skeleton, so the mesh is rebuilt once here with feet on y=0 and the nose toward +Z,
## and every vertex gets a leg weight in COLOR (see horse.gdshader) so the legs can swing in the shader.
class_name HorseMesh

const SRC := "res://models/horse/scene.gltf"
const LENGTH := 2.9         # nose-to-tail, meters
# COLOR: r = how much the vertex follows its leg's swing, g = 1 for the left-fore/right-hind pair,
# b = 1 for a fore leg, a = how much it also follows the knee bend

static var _mesh: ArrayMesh
static var _mat := {}
static var pivots := Vector4()      # hip height, fore pivot z, hind pivot z, knee height
static var saddle := Vector3()      # seat point on top of the saddle


static func mesh() -> ArrayMesh:
	if _mesh == null:
		_build()
	return _mesh


## A material for one surface, tinted for the coat (surface 0 is the body, 1 the mane, 2 the saddle);
## `pale` washes the coat out toward a dappled grey.
static func material(surface: int, tint: Color, pale := 0.0) -> ShaderMaterial:
	var key := "%d %s %.2f" % [surface, tint.to_html(), pale]
	if not _mat.has(key):
		mesh()
		var m := ShaderMaterial.new()
		m.shader = load("res://horse.gdshader")
		m.set_shader_parameter("tex", _mesh.surface_get_material(surface).albedo_texture)
		m.set_shader_parameter("tint", tint if surface != 2 else Color.WHITE)
		m.set_shader_parameter("pale", pale)
		m.set_shader_parameter("cutout", surface == 1)
		m.set_shader_parameter("pivots", pivots)
		_mat[key] = m
	return _mat[key]


static func _collect(n: Node, xf: Transform3D, out: Array) -> void:
	var t := xf * (n as Node3D).transform if n is Node3D else xf
	if n is MeshInstance3D:
		out.append([n, t])
	for c in n.get_children():
		_collect(c, t, out)


static func _build() -> void:
	var root: Node3D = load(SRC).instantiate()
	var parts := []
	_collect(root, Transform3D(), parts)
	# gather every surface in model space, then find the frame: nose along the long axis, toward the head
	var surfs := []
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for p in parts:
		var mi: MeshInstance3D = p[0]
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var nr: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var t: Transform3D = p[1]
			for i in v.size():
				v[i] = t * v[i]
				nr[i] = (t.basis * nr[i]).normalized()
				lo = lo.min(v[i])
				hi = hi.max(v[i])
			a[Mesh.ARRAY_VERTEX] = v
			a[Mesh.ARRAY_NORMAL] = nr
			surfs.append([a, mi.mesh.surface_get_material(s) if mi.get_surface_override_material(s) == null else mi.get_surface_override_material(s)])
	var along_x := hi.x - lo.x > hi.z - lo.z
	# the head is the highest point: the nose goes on that side
	var top := Vector3()
	for sd in surfs:
		for v in sd[0][Mesh.ARRAY_VERTEX]:
			if v.y > top.y:
				top = v
	var basis := Basis()
	if along_x:
		basis = Basis(Vector3.UP, -PI * 0.5 if top.x > (lo.x + hi.x) * 0.5 else PI * 0.5)  # +X turns to -Z under +90°
	elif top.z < (lo.z + hi.z) * 0.5:
		basis = Basis(Vector3.UP, PI)
	var length: float = maxf(hi.x - lo.x, hi.z - lo.z)
	var k := LENGTH / length
	var mid := (lo + hi) * 0.5
	var place := Transform3D(basis.scaled(Vector3.ONE * k), Vector3.ZERO) * Transform3D(Basis(), -Vector3(mid.x, lo.y, mid.z))
	for sd in surfs:
		var v: PackedVector3Array = sd[0][Mesh.ARRAY_VERTEX]
		var nr: PackedVector3Array = sd[0][Mesh.ARRAY_NORMAL]
		for i in v.size():
			v[i] = place * v[i]
			nr[i] = (place.basis * nr[i]).normalized()
		sd[0][Mesh.ARRAY_VERTEX] = v
		sd[0][Mesh.ARRAY_NORMAL] = nr
	_weights(surfs)
	_mesh = ArrayMesh.new()
	for sd in surfs:
		var a: Array = sd[0]
		a[Mesh.ARRAY_TANGENT] = null
		for c in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			a[c] = null   # the importer's extra UV data, unused
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		_mesh.surface_set_material(_mesh.get_surface_count() - 1, sd[1])
	root.free()


## Leg weights from the body's shape: below the belly, split into four by side and by fore/hind.
static func _weights(surfs: Array) -> void:
	var body: PackedVector3Array = surfs[0][0][Mesh.ARRAY_VERTEX]
	var zlo := INF
	var zhi := -INF
	for v in body:
		zlo = minf(zlo, v.z)
		zhi = maxf(zhi, v.z)
	var height := 0.0
	for v in body:
		height = maxf(height, v.y)
	# leg centres: average z of the hoof-high vertices in front of and behind the middle
	var fz := 0.0
	var fn := 0
	var hz := 0.0
	var hn := 0
	for v in body:
		if v.y < height * 0.15:
			if v.z > (zlo + zhi) * 0.5:
				fz += v.z
				fn += 1
			else:
				hz += v.z
				hn += 1
	fz /= maxi(fn, 1)
	hz /= maxi(hn, 1)
	var mid := (fz + hz) * 0.5
	# the belly: the underside of the barrel between the legs
	var belly := INF
	for v in body:
		if absf(v.z - mid) < (fz - hz) * 0.25:
			belly = minf(belly, v.y)
	var hip := belly + 0.1
	var knee := belly * 0.5
	pivots = Vector4(hip, fz, hz, knee)
	for sd in surfs:
		var a: Array = sd[0]
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var col := PackedColorArray()
		col.resize(v.size())
		for i in v.size():
			var p := v[i]
			var fore := p.z > mid
			var w := clampf((hip - p.y) / (hip - belly * 0.8), 0.0, 1.0)
			if sd != surfs[0] or absf(p.z - (fz if fore else hz)) > 0.4:
				w = 0.0   # mane, tail and saddle ride on the body; so does the barrel between the legs
			var diag := (p.x > 0.0) == fore   # left fore + right hind swing together
			var k := clampf((knee + 0.06 - p.y) / 0.12, 0.0, 1.0) * w
			col[i] = Color(w, 1.0 if diag else 0.0, 1.0 if fore else 0.0, k)
		a[Mesh.ARRAY_COLOR] = col
	# the seat sits straight above the stirrups (the lowest bits of the saddle), on its top
	var sv: PackedVector3Array = surfs[2][0][Mesh.ARRAY_VERTEX]
	var low := Vector3(0, INF, 0)
	for p in sv:
		if p.y < low.y:
			low = p
	var top := 0.0
	for p in sv:
		if absf(p.z - low.z) < 0.1 and absf(p.x) < 0.15:
			top = maxf(top, p.y)
	saddle = Vector3(0, top, low.z)
