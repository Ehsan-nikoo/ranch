## Ranch feel-test scene: barn on a prairie with a day-night cycle, wind and touch camera.
## Test args: `-- --shot=wide|close --hour=17.5`
extends Node3D

const TEX := "res://textures/"
const MASK_SPAN := 160.0
const GRASS_CHUNK := 20.0
const GRASS_COUNT := 20000

var day := DayCycle.new()
var rig := CameraRig.new()
var grass_chunks: Array[MultiMesh] = []
var grass_nodes: Array[Node3D] = []
var grass_mat := ShaderMaterial.new()
var crickets: AudioStreamPlayer
var mask_img: Image
var builder := Builder.new()
# starting ranch: building, position, yaw in degrees
var layout := [
	[Barn, Vector3(0, 0, 0), 0.0],
	[RanchHouse, Vector3(-13, 0, 26), 90.0],
	[Windmill, Vector3(17, 0, -5), -30.0],
	[Silo, Vector3(-2, 0, -11), 0.0],
]


func _ready() -> void:
	day.hour = float(_arg("hour", "17.2"))
	add_child(day)
	mask_img = (load(TEX + "ground_mask.png") as Texture2D).get_image()
	if mask_img.is_compressed():
		mask_img.decompress()
	_ground()
	builder.occupied.append(Rect2(-24.5, -6.5, 16, 19))  # corral
	for b in layout:
		var node: Building = b[0].new()
		node.position = b[1]
		node.rotation_degrees.y = b[2]
		add_child(node)
		builder.occupied.append(node.world_footprint())
	_grass()
	_props()
	MeshMerge.boxes(self)
	_audio()
	_shot(_arg("shot", "wide"))
	add_child(rig)
	var hud := Hud.new()
	hud.day = day
	hud.grass = grass_chunks
	hud.grass_nodes = grass_nodes
	add_child(hud)
	builder.rig = rig
	builder.world = self
	builder.on_placed = _clear_grass
	add_child(builder)
	day.hour_changed.connect(_on_hour)
	_test_build()


## Test hook for renders: `--ghost=<catalog index>@x,z` opens placement there, `--place` confirms.
func _test_build() -> void:
	var g := _arg("ghost", "")
	if g == "":
		return
	var xz := g.get_slice("@", 1).split(",")
	rig.target = Vector3(float(xz[0]), 0, float(xz[1]))
	rig.snap()
	builder.choose(int(g.get_slice("@", 0)))
	if _arg("place", "") != "":
		for i in 2:  # let Builder._process validate the spot first
			await get_tree().process_frame
		builder.place()


## Hides grass tufts inside a newly placed building's footprint.
func _clear_grass(r: Rect2) -> void:
	var gone := Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)
	for mm in grass_chunks:
		var a := mm.get_aabb()
		if not r.intersects(Rect2(a.position.x, a.position.z, a.size.x, a.size.z)):
			continue
		for i in mm.instance_count:
			var o := mm.get_instance_transform(i).origin
			if r.has_point(Vector2(o.x, o.z)):
				mm.set_instance_transform(i, gone)


func _arg(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.get_slice("=", 1)
	return def


func _shot(shot: String) -> void:
	match shot:  # target, dist, yaw
		"close":
			rig.target = Vector3(2, 0, 6)
			rig.dist = 15.0
			rig.yaw = 0.45
		"house":
			rig.target = Vector3(-11, 0, 26)
			rig.dist = 16.0
			rig.yaw = 1.1
		"mill":
			rig.target = Vector3(18, 2, -3)
			rig.dist = 17.0
			rig.yaw = 0.3
	rig.snap()


func _on_hour(_h: float) -> void:
	var night := Building.window_mat.emission_energy_multiplier / 2.5
	crickets.volume_db = linear_to_db(maxf(night, 0.001)) - 8.0
	grass_mat.set_shader_parameter("to_sun", day.light.global_basis.z)


# ---------- ground & grass ----------

func _ground() -> void:
	var sm := ShaderMaterial.new()
	sm.shader = load("res://ground.gdshader")
	for p in [["grass_alb", "grass_ground_diff.jpg"], ["grass_nrm", "grass_ground_nor_gl.jpg"],
			["dirt_alb", "dirt_diff.jpg"], ["dirt_nrm", "dirt_nor_gl.jpg"],
			["mask", "ground_mask.png"], ["macro", "macro_noise.png"]]:
		sm.set_shader_parameter(p[0], load(TEX + p[1]))
	sm.set_shader_parameter("span", MASK_SPAN)
	var pm := PlaneMesh.new()
	pm.size = Vector2(800, 800)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = sm
	add_child(mi)


func _mask(p: Vector2) -> Color:
	var u := p / MASK_SPAN + Vector2(0.5, 0.5)
	if u.x < 0.0 or u.x >= 1.0 or u.y < 0.0 or u.y >= 1.0:
		return Color.BLACK
	return mask_img.get_pixel(int(u.x * mask_img.get_width()), int(u.y * mask_img.get_height()))


func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for i in 7:
		var ang := r.randf() * TAU
		var h := r.randf_range(0.3, 0.75)
		var base := Vector3(r.randf_range(-0.1, 0.1), 0, r.randf_range(-0.1, 0.1))
		var side := Vector3(cos(ang), 0, sin(ang)) * 0.035
		var tip := base + Vector3(-sin(ang), 0, cos(ang)) * r.randf_range(0.08, 0.3) + Vector3.UP * h
		for v in [[base - side, Color(0.2, 0.19, 0.09)], [tip, Color(0.8, 0.62, 0.3)], [base + side, Color(0.2, 0.19, 0.09)]]:
			st.set_normal(Vector3.UP)
			st.set_color(v[1])
			st.add_vertex(v[0])
	return st.commit()


func _grass() -> void:
	var mat := grass_mat
	mat.shader = load("res://grass.gdshader")
	var mesh := _tuft_mesh()
	var r := RandomNumberGenerator.new()
	r.seed = 11
	# bucket instances into chunks so off-screen grass is frustum-culled
	var chunks := {}
	var placed := 0
	while placed < GRASS_COUNT:
		var p := Vector2(r.randf_range(-70, 70), r.randf_range(-70, 70))
		if builder.occupied.any(func(r): return r.has_point(p)):
			continue
		var m := _mask(p)
		if r.randf() < smoothstep(0.1, 0.4, m.r) or r.randf() > 1.0 - smoothstep(38.0, 68.0, p.length()):
			continue
		var s := r.randf_range(0.6, 1.4) * (1.0 + m.g * 0.4)
		var xf := Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s, s * r.randf_range(0.8, 1.3), s)), Vector3(p.x, 0, p.y))
		var c := Color(1, 1, 1).lerp(Color(0.62, 0.8, 0.45), maxf(r.randf() ** 2, m.g * 0.8)).darkened(r.randf() * 0.25)
		var key := Vector2i(floori(p.x / GRASS_CHUNK), floori(p.y / GRASS_CHUNK))
		if not chunks.has(key):
			chunks[key] = [[], []]
		chunks[key][0].append(xf)
		chunks[key][1].append(c)
		placed += 1
	for key in chunks:
		var xs: Array = chunks[key][0]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, xs[i])
			mm.set_instance_color(i, chunks[key][1][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 100.0
		add_child(mmi)
		grass_chunks.append(mm)
		grass_nodes.append(mmi)


# ---------- props ----------

func _props() -> void:
	var hay := StandardMaterial3D.new()
	hay.albedo_color = Color(0.86, 0.68, 0.33)
	hay.roughness = 1.0
	hay.normal_enabled = true
	hay.normal_texture = load(TEX + "grass_ground_nor_gl.jpg")
	hay.uv1_triplanar = true
	hay.albedo_texture = load(TEX + "grass_ground_diff.jpg")
	hay.uv1_scale = Vector3(3, 3, 3)
	# hay bale stack under the lean-to
	var spots := [Vector3(7.2, 0.3, -1.0), Vector3(8.4, 0.3, -1.0), Vector3(7.2, 0.3, 0.0), Vector3(8.4, 0.3, 0.0), Vector3(7.8, 0.9, -0.5)]
	for p in spots:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.15, 0.6, 0.85)
		mi.mesh = bm
		mi.material_override = hay
		mi.position = p
		mi.rotation.y = randf_range(-0.08, 0.08)
		add_child(mi)
	# corral fence on the left
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = load(TEX + "trim_white_diff.jpg")
	wood.albedo_color = Color(0.55, 0.45, 0.35)
	wood.uv1_triplanar = true
	wood.roughness = 0.95
	var corners := [Vector2(-9, -6), Vector2(-24, -6), Vector2(-24, 12), Vector2(-9, 12)]
	for i in 3:
		_fence(corners[i], corners[i + 1], wood)
	_fence(Vector2(-9, -6), Vector2(-9, 4), wood)
	# water trough
	var trough := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.9, 0.6, 3.0)
	trough.mesh = tm
	trough.material_override = wood
	trough.position = Vector3(-11.5, 0.3, 2)
	add_child(trough)
	var water := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(0.75, 0.02, 2.85)
	water.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.15, 0.22, 0.25)
	wmat.roughness = 0.05
	water.material_override = wmat
	water.position = Vector3(-11.5, 0.58, 2)
	add_child(water)


func _fence(a: Vector2, c: Vector2, m: Material) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(a.x * 31 + a.y * 7)
	var len := a.distance_to(c)
	var n := int(ceil(len / 2.5))
	var dir := (c - a).normalized()
	var yaw := atan2(dir.x, dir.y)
	for i in n + 1:
		var p := a.lerp(c, float(i) / n)
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.16, 1.5, 0.16)
		post.mesh = pm
		post.material_override = m
		post.position = Vector3(p.x, 0.75, p.y)
		post.rotation = Vector3(r.randf_range(-0.04, 0.04), r.randf(), r.randf_range(-0.04, 0.04))
		add_child(post)
	for h in [0.5, 0.95, 1.35]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.06, 0.14, len)
		rail.mesh = rm
		rail.material_override = m
		var mid := (a + c) * 0.5
		rail.position = Vector3(mid.x, h, mid.y) + Vector3(dir.y, 0, -dir.x) * 0.1
		rail.rotation.y = yaw
		add_child(rail)


# ---------- audio ----------

func _loop(path: String, db: float) -> AudioStreamPlayer:
	var s: AudioStreamWAV = load(path)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = int(s.get_length() * s.mix_rate)
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = db
	p.autoplay = true
	add_child(p)
	return p


func _audio() -> void:
	_loop("res://sounds/wind.wav", -10.0)
	crickets = _loop("res://sounds/crickets.wav", -60.0)
