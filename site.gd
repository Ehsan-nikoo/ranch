## A building going up, or being made bigger: the ground dug out and staked, a pile of timber and a
## pile of stone that shrink as the work goes on, and timber scaffolding that climbs with the walls.
## A new building rises out of the ground course by course (its meshes are cut off above a height that
## climbs, see build_clip.gdshader); an upgrade keeps the old building standing inside the scaffolding.
## Building owns it as a child; Builder calls show_at() with the share of the work done.
class_name Site
extends Node3D

const LIFT := 2.0          # height between scaffold decks
const BAY := 2.4           # spacing of the scaffold poles
const OUT := 1.15          # outer pole line, out from the wall
const IN := 0.35           # inner pole line
const LOW := 3.0           # under this height a building gets no scaffolding (pens, ponds, fences)

static var _twins := {}    # building material -> its cut-off twin, shared by every site
static var _clip_shader: Shader
static var _pole_mat: StandardMaterial3D
static var _plank_mat: StandardMaterial3D
static var _string_mat: StandardMaterial3D

var b: Building
var upgrade := false
var rect := Rect2()        # where the work is, x/z around the building's origin, in metres (not scaled)
var core := AABB()         # the finished building's own shape, in metres
var top := 5.0
var _meshes := []          # [MeshInstance3D, its own material or null (then it hides till done)]
var _stage := -1
var _scaffold := Node3D.new()
var _piles := Node3D.new()


## `new_rect`: the building's footprint once the work is done, in its own (unscaled) x/z.
func setup(building: Building, up: bool, new_rect: Rect2, new_scale: Vector3) -> void:
	b = building
	upgrade = up
	name = "Site"
	scale = Vector3.ONE / b.scale  # this node works in metres, whatever the building's level
	rect = Rect2(new_rect.position * Vector2(new_scale.x, new_scale.z), new_rect.size * Vector2(new_scale.x, new_scale.z))
	var shape := _shape()  # building space -> metres: times the scale of the level being built
	core = AABB(shape.position * new_scale, shape.size * new_scale)
	if upgrade:  # the scaffold goes round the whole new footprint, wings and all
		var r := rect.grow(-0.4)
		core = AABB(Vector3(r.position.x, 0, r.position.y), Vector3(r.size.x, core.end.y, r.size.y))
	top = core.end.y
	add_child(_scaffold)
	add_child(_piles)
	_pad()
	if not upgrade:
		_hide_building()


## The bounding box of the building's own meshes, in its local space.
func _shape() -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in b.find_children("*", "MeshInstance3D", true, false):
		if is_ancestor_of(mi) or mi.name == "Marker":
			continue
		var a: AABB = b.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		box = a if first else box.merge(a)
		first = false
	return box


## Dug and levelled ground under the whole site.
func _pad() -> void:
	var pad := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(rect.size.x + 1.0, 0.05, rect.size.y + 1.0)
	pad.mesh = bm
	pad.material_override = b._mud()
	pad.position = Vector3(rect.get_center().x, 0.02, rect.get_center().y)
	pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pad)


## Swaps every mesh of the building for its cut-off twin; meshes with their own (imported) materials
## just wait out of sight until the end.
func _hide_building() -> void:
	for mi: MeshInstance3D in b.find_children("*", "MeshInstance3D", true, false):
		if is_ancestor_of(mi):
			continue
		var m := mi.material_override
		if m is StandardMaterial3D:
			_meshes.append([mi, m])
			mi.material_override = twin(m)
		else:
			_meshes.append([mi, null])
			mi.visible = false
	_cut(0.0)


## Cuts the building off `h` metres above the ground.
func _cut(h: float) -> void:
	for e in _meshes:
		if e[1] != null:
			(e[0] as MeshInstance3D).set_instance_shader_parameter("clip_y", b.global_position.y + h)


## Puts every mesh back as it was.
func finish() -> void:
	for e in _meshes:
		var mi: MeshInstance3D = e[0]
		if not is_instance_valid(mi):
			continue
		if e[1] != null:
			mi.material_override = e[1]
		else:
			mi.visible = true
	_meshes.clear()
	var dust := CPUParticles3D.new()  # a puff of dust as the last scaffold boards come down
	dust.one_shot = true
	dust.amount = 36
	dust.lifetime = 1.6
	dust.explosiveness = 0.9
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(rect.size.x * 0.5, 0.5, rect.size.y * 0.5)
	dust.direction = Vector3.UP
	dust.spread = 70.0
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 2.6
	dust.gravity = Vector3(0, -1.2, 0)
	dust.scale_amount_min = 0.8
	dust.scale_amount_max = 1.8
	var q := QuadMesh.new()
	q.size = Vector2(1.2, 1.2)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.vertex_color_use_as_albedo = true
	q.material = dm
	dust.mesh = q
	var fade := Gradient.new()
	fade.set_color(0, Color(0.78, 0.68, 0.52, 0.55))
	fade.set_color(1, Color(0.78, 0.68, 0.52, 0.0))
	dust.color_ramp = fade
	dust.position = Vector3(rect.get_center().x, 0.6, rect.get_center().y)
	b.get_parent().add_child(dust)
	dust.global_transform = global_transform.translated_local(dust.position)
	dust.emitting = true
	dust.get_tree().create_timer(2.5).timeout.connect(dust.queue_free)


## The work is `p` (0..1) done.
func show_at(p: float) -> void:
	var h := 0.0
	if not upgrade:  # stakes and digging first, the walls from 8%, the last boards at 97%
		h = clampf((p - 0.08) / 0.89, 0.0, 1.0) * (top + 0.1)
		_cut(h)
	else:
		h = clampf(p / 0.9, 0.0, 1.0) * (top + 0.1)
	var stage := int(h / 1.0) * 10 + int(p * 8.0)  # rebuild the scaffold every metre and every eighth
	if stage != _stage:
		_stage = stage
		_build(p, h)


# ---------- the props ----------

func _build(p: float, h: float) -> void:
	for c in _scaffold.get_children():
		c.free()
	for c in _piles.get_children():
		c.free()
	var x0 := core.position.x
	var x1 := core.end.x
	var z0 := core.position.z
	var z1 := core.end.z
	if p < 0.35 and not upgrade:
		_stakes(rect)
	_piles_at(Vector3(rect.end.x - 1.2, 0, rect.end.y + 1.3), 1.0 - p)
	if top >= LOW:
		var climb := minf(h + 1.6, top + 0.9) if not upgrade else top + 0.9
		_scaffolding(x0, x1, z0, z1, climb, h if not upgrade else top)
	MeshMerge.boxes(_scaffold)
	MeshMerge.boxes(_piles)


func _box(parent: Node3D, size: Vector3, at: Vector3, m: Material, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)


## Corner stakes with string lines, marking out where the walls go.
func _stakes(r: Rect2) -> void:
	var c := [Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0, r.position.y), Vector3(r.end.x, 0, r.end.y), Vector3(r.position.x, 0, r.end.y)]
	for i in 4:
		var a: Vector3 = c[i]
		var d: Vector3 = c[(i + 1) % 4]
		_box(_scaffold, Vector3(0.08, 0.7, 0.08), a + Vector3(0, 0.35, 0), _poles())
		var mid := (a + d) * 0.5 + Vector3(0, 0.5, 0)
		_box(_scaffold, Vector3(0.02, 0.02, a.distance_to(d)), mid, _string(), Vector3(0, atan2(d.x - a.x, d.z - a.z), 0))


## A stack of sawn timber and a heap of stone by the front corner; `left` (0..1) of it still unused.
func _piles_at(at: Vector3, left: float) -> void:
	var boards := int(ceilf(left * 12.0))
	for k in boards:
		var layer := k / 4
		var x := (k % 4) * 0.3 - 0.45
		_box(_piles, Vector3(0.26, 0.12, 3.0), at + Vector3(x, 0.12 + layer * 0.14, 0), _planks())
	if boards > 0:
		for z in [-1.1, 0.0, 1.1]:  # bearers under the stack
			_box(_piles, Vector3(1.3, 0.08, 0.12), at + Vector3(0, 0.04, z), _poles())
	var stones := int(ceilf(left * 9.0))
	for k in stones:
		var a := k * 2.4
		var r := 0.25 + 0.2 * (k % 3)
		_box(_piles, Vector3(0.42, 0.3, 0.36), at + Vector3(-1.6 + cos(a) * r, 0.15 + (0.25 if k >= 6 else 0.0), sin(a) * r), b.stone, Vector3(0, a, 0))
	# a sawhorse
	var sx := at + Vector3(1.2, 0, -0.6)
	_box(_piles, Vector3(0.1, 0.1, 1.1), sx + Vector3(0, 0.75, 0), _poles())
	for s in [-0.45, 0.45]:
		for t in [-0.18, 0.18]:
			_box(_piles, Vector3(0.06, 0.8, 0.06), sx + Vector3(t, 0.38, s), _poles(), Vector3(0, 0, t * 1.2))


## Two lines of poles round the walls, ledgers and plank decks at each lift up to `deck`, and X braces
## on the outside; the poles stand `climb` metres tall.
func _scaffolding(x0: float, x1: float, z0: float, z1: float, climb: float, deck: float) -> void:
	var lifts := []
	var y := LIFT
	while y <= deck + 0.3 and y < top:
		lifts.append(y)
		y += LIFT
	for line in [OUT, IN]:
		var r := Rect2(x0 - line, z0 - line, x1 - x0 + line * 2.0, z1 - z0 + line * 2.0)
		var c := [Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)]
		for i in 4:
			var a: Vector2 = c[i]
			var d: Vector2 = c[(i + 1) % 4]
			var n := maxi(1, int(ceilf(a.distance_to(d) / BAY)))
			for k in n:  # poles (the next side puts one on the far corner)
				var q := a.lerp(d, k / float(n))
				_box(_scaffold, Vector3(0.11, climb, 0.11), Vector3(q.x, climb * 0.5, q.y), _poles())
			var mid := (a + d) * 0.5
			var yaw := atan2(d.x - a.x, d.y - a.y)
			for ly in lifts:  # ledger along the side at each lift, a guard rail on the outer line
				_box(_scaffold, Vector3(0.07, 0.07, a.distance_to(d)), Vector3(mid.x, ly, mid.y), _poles(), Vector3(0, yaw, 0))
				if line == OUT:
					_box(_scaffold, Vector3(0.06, 0.06, a.distance_to(d)), Vector3(mid.x, ly + 0.95, mid.y), _poles(), Vector3(0, yaw, 0))
			if line == OUT and climb > 2.5:  # a long brace across every other bay
				for k in range(0, n, 2):
					var p0 := a.lerp(d, k / float(n))
					var p1 := a.lerp(d, (k + 1) / float(n))
					var lo := Vector3(p0.x, 0.2, p0.y)
					var hi := Vector3(p1.x, minf(climb - 0.2, LIFT * 2.0), p1.y)
					var along := hi - lo
					var mi := MeshInstance3D.new()
					var bm := BoxMesh.new()
					bm.size = Vector3(0.06, along.length(), 0.06)
					mi.mesh = bm
					mi.material_override = _poles()
					var up := along.normalized()
					var side := up.cross(Vector3.UP).normalized()
					mi.transform = Transform3D(Basis(side, up, side.cross(up)), (lo + hi) * 0.5)
					_scaffold.add_child(mi)
	# plank decks between the two lines, all round, at each lift
	var w := OUT - IN
	for ly in lifts:
		var mid := (OUT + IN) * 0.5
		_box(_scaffold, Vector3(x1 - x0 + mid * 2.0 + w, 0.06, w), Vector3((x0 + x1) * 0.5, ly + 0.05, z1 + mid), _planks())
		_box(_scaffold, Vector3(x1 - x0 + mid * 2.0 + w, 0.06, w), Vector3((x0 + x1) * 0.5, ly + 0.05, z0 - mid), _planks())
		_box(_scaffold, Vector3(w, 0.06, z1 - z0 + mid * 2.0 - w), Vector3(x1 + mid, ly + 0.05, (z0 + z1) * 0.5), _planks())
		_box(_scaffold, Vector3(w, 0.06, z1 - z0 + mid * 2.0 - w), Vector3(x0 - mid, ly + 0.05, (z0 + z1) * 0.5), _planks())


# ---------- materials ----------

static func _poles() -> StandardMaterial3D:
	if _pole_mat == null:
		_pole_mat = StandardMaterial3D.new()
		_pole_mat.albedo_color = Color(0.66, 0.52, 0.36)
		_pole_mat.roughness = 1.0
	return _pole_mat


static func _planks() -> StandardMaterial3D:
	if _plank_mat == null:
		_plank_mat = StandardMaterial3D.new()
		_plank_mat.albedo_color = Color(0.8, 0.66, 0.46)
		_plank_mat.roughness = 1.0
	return _plank_mat


static func _string() -> StandardMaterial3D:
	if _string_mat == null:
		_string_mat = StandardMaterial3D.new()
		_string_mat.albedo_color = Color(0.95, 0.9, 0.75)
		_string_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _string_mat


## The building material `m` drawn through build_clip.gdshader: the same colour and texture, cut off
## above each mesh's clip_y.
static func twin(m: StandardMaterial3D) -> ShaderMaterial:
	if _twins.has(m):
		return _twins[m]
	if _clip_shader == null:
		_clip_shader = load("res://build_clip.gdshader")
	var t := ShaderMaterial.new()
	t.shader = _clip_shader
	t.set_shader_parameter("albedo", m.albedo_color)
	t.set_shader_parameter("roughness", m.roughness)
	t.set_shader_parameter("metallic", m.metallic)
	if m.albedo_texture:
		t.set_shader_parameter("has_tex", true)
		t.set_shader_parameter("albedo_tex", m.albedo_texture)
		t.set_shader_parameter("triplanar", m.uv1_triplanar)
		t.set_shader_parameter("tri_scale", m.uv1_scale.x)
		if m.normal_enabled and m.normal_texture:
			t.set_shader_parameter("has_normal", true)
			t.set_shader_parameter("normal_tex", m.normal_texture)
		if m.roughness_texture:
			t.set_shader_parameter("has_arm", true)
			t.set_shader_parameter("arm_tex", m.roughness_texture)
	t.set_shader_parameter("use_vcol", m.vertex_color_use_as_albedo)
	_twins[m] = t
	return t
