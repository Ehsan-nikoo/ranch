## Procedural beef cow, ~2.2 m long, facing +Z, feet at y=0. One mesh shared by the whole herd.
## Vertex color encodes data for cow.gdshader: r = white-coat mask (Hereford face/belly),
## g = body part id / 8 (0 body, 1-4 legs FL FR BL BR, 5 head+neck, 6 tail), b = dark mask (muzzle, hooves).
class_name CowMesh

const HIP_Y := 0.95
const LEG_X := 0.24
const LEG_Z := 0.62

static var _mesh: ArrayMesh
static var _mat: ShaderMaterial


static func mesh() -> ArrayMesh:
	if _mesh == null:
		_mesh = _build()
	return _mesh


static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://cow.gdshader")
	return _mat


static func _c(white: float, part: int, dark: float) -> Color:
	return Color(white, part / 8.0, dark, 1.0)


## Ellipsoid around c with radii r, rotated by `rot`; col_fn(local unit dir) -> Color.
static func _ellipsoid(st: SurfaceTool, c: Vector3, r: Vector3, col_fn: Callable, rot := Basis(), seg := 16, rings := 10, deform := Callable()) -> void:
	var pos := []
	var cols := []
	for i in rings + 1:
		var th := PI * i / rings
		var prow := []
		var crow := []
		for j in seg + 1:
			var ph := TAU * j / seg
			var u := Vector3(sin(th) * sin(ph), cos(th), sin(th) * cos(ph))
			var p := u * r
			if deform.is_valid():
				p = deform.call(p, u)
			prow.append(c + rot * p)
			crow.append(col_fn.call(u))
		pos.append(prow)
		cols.append(crow)
	# normals from neighbouring points, so they stay right after any deform
	var grid := []
	for i in rings + 1:
		var row := []
		for j in seg + 1:
			var p: Vector3 = pos[i][j]
			var jl := (j - 1 + seg) % seg
			var jr := (j + 1) % seg
			var t1: Vector3 = pos[i][jr] - pos[i][jl]
			var t2: Vector3 = pos[mini(i + 1, rings)][j] - pos[maxi(i - 1, 0)][j]
			var n := t1.cross(t2)
			if n.length_squared() < 1e-10 or i == 0 or i == rings:
				n = p - c
			n = n.normalized()
			if n.dot(p - c) < 0.0:
				n = -n
			row.append([p, n, cols[i][j]])
		grid.append(row)
	for i in rings:
		for j in seg:
			var a: Array = grid[i][j]
			var b: Array = grid[i][j + 1]
			var cc: Array = grid[i + 1][j + 1]
			var d: Array = grid[i + 1][j]
			for v in [a, b, cc, a, cc, d]:
				st.set_normal(v[1])
				st.set_color(v[2])
				st.add_vertex(v[0])


## Tapered vertical cylinder from top (y0) down to y1, with a dark hoof band at the bottom.
static func _leg(st: SurfaceTool, x: float, z: float, part: int, white: float) -> void:
	var seg := 8
	var ys := [HIP_Y + 0.15, 0.62, 0.38, 0.1, 0.0]
	var rs := [0.13, 0.095, 0.07, 0.068, 0.075]
	for k in ys.size() - 1:
		for j in seg:
			var a0 := TAU * j / seg
			var a1 := TAU * (j + 1) / seg
			var quad := []
			for v in [[k, a0], [k, a1], [k + 1, a1], [k + 1, a0]]:
				var n := Vector3(sin(v[1]), 0, cos(v[1]))
				var y: float = ys[v[0]]
				var hoof := 1.0 if y <= 0.1 else 0.0
				var sock := white * (1.0 - smoothstep(0.25, 0.45, y))  # white socks on Herefords
				quad.append([Vector3(x, y, z) + n * rs[v[0]], n, _c(sock, part, hoof)])
			for q in [quad[0], quad[2], quad[1], quad[0], quad[3], quad[2]]:
				st.set_normal(q[1])
				st.set_color(q[2])
				st.add_vertex(q[0])


static func _build() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# boxy barrel body (squared-off ellipsoid): flat back, deep chest, belly tucks up toward the flank
	_ellipsoid(st, Vector3(0, 1.1, -0.05), Vector3(0.4, 0.38, 1.0),
		func(u): return _c(clampf((-u.y - 0.6) * 3.0, 0, 1), 0, 0),
		Basis(), 22, 14,
		func(p, u):
			var e := Vector3(absf(u.x), absf(u.y), absf(u.z))
			p = Vector3(signf(u.x) * pow(e.x, 0.6), signf(u.y) * pow(e.y, 0.6), signf(u.z) * pow(e.z, 0.8)) * Vector3(0.4, 0.38, 1.0)
			p.y -= 0.07 * maxf(-u.y, 0.0) * (1.0 - absf(u.z))  # belly hangs a little
			p.y += 0.05 * maxf(u.z, 0.0) * maxf(u.y, 0.0)  # withers
			p.x *= 1.0 - 0.18 * maxf(u.z, 0.0) * maxf(-u.y, 0.0)  # narrower brisket
			return p)
	# neck and head (part 5) hang from a pivot at the shoulders, see cow.gdshader
	_ellipsoid(st, Vector3(0, 1.22, 0.98), Vector3(0.21, 0.3, 0.34),
		func(u): return _c(clampf((-u.y - 0.4) * 2.0, 0, 1), 5, 0), Basis(Vector3.RIGHT, 0.75), 14, 8)
	# long tapered head pointing down-forward, flat broad forehead
	# local +y of the head points up-back (forehead), -y down-forward (muzzle)
	var head_rot := Basis(Vector3.RIGHT, -0.7)
	_ellipsoid(st, Vector3(0, 1.2, 1.36), Vector3(0.16, 0.3, 0.16),
		func(u): return _c(clampf(u.z * 2.0 + 0.6, 0, 1), 5, 0), head_rot, 14, 10,
		func(p, u):
			p.x *= 1.0 - 0.35 * maxf(-u.y, 0.0)  # narrows toward the muzzle
			p.z *= 1.0 - 0.3 * maxf(-u.y, 0.0)
			return p)
	_ellipsoid(st, Vector3(0, 1.0, 1.55), Vector3(0.12, 0.1, 0.11),
		func(u): return _c(0.8, 5, clampf(u.z * 2.5 - 0.2, 0, 1)), head_rot, 12, 8)
	for s in [-1.0, 1.0]:
		# ears stick out sideways below the horns, horns are short and pale with dark tips
		_ellipsoid(st, Vector3(0.21 * s, 1.36, 1.24), Vector3(0.12, 0.045, 0.065),
			func(u): return _c(0.0, 5, 0.0), Basis(Vector3.FORWARD, 0.35 * s), 8, 6)
		_ellipsoid(st, Vector3(0.15 * s, 1.47, 1.2), Vector3(0.09, 0.03, 0.03),
			func(u): return _c(0.9, 5, clampf(u.x * s * 3.0 - 1.6, 0, 1)), Basis(Vector3.FORWARD, -0.5 * s), 8, 4)
	for leg in [[LEG_X, LEG_Z, 1], [-LEG_X, LEG_Z, 2], [LEG_X, -LEG_Z, 3], [-LEG_X, -LEG_Z, 4]]:
		_leg(st, leg[0], leg[1], leg[2], 1.0)
	# tail hangs from the rump to the hocks with a dark switch at the end
	_ellipsoid(st, Vector3(0, 0.95, -1.06), Vector3(0.035, 0.42, 0.035),
		func(u): return _c(0.0, 6, clampf(-u.y * 3.0 - 1.6, 0, 1)), Basis(Vector3.RIGHT, -0.12), 6, 8)
	return st.commit()
