## Bakes the Sketchfab cow into vertex-animation textures for the herd shader.
##   godot --path . res://tools/cow_bake.tscn
## The model ships only idle/attack/death clips, so walk and graze are posed here on its skeleton.
## Outputs (see CowMesh): models/cow_mesh.res, cow_vat_pos.res, cow_vat_nrm.res
extends Node3D

var skel: Skeleton3D
var anim: AnimationPlayer
var meshes: Array[MeshInstance3D] = []
var fwd := Vector3.FORWARD
var norm := Transform3D()
var arrays := []                     # rest arrays per mesh
var to_world: Array[Transform3D] = []  # skinned (skeleton) space -> world, per mesh  # model space -> herd space: feet on y=0, nose toward +Z, LENGTH long


func _find_all(n: Node, cls: String, out: Array) -> void:
	if n.is_class(cls):
		out.append(n)
	for c in n.get_children():
		_find_all(c, cls, out)


func _bone(name: String) -> int:
	var i := skel.find_bone(name)
	assert(i >= 0, "missing bone " + name)
	return i


func _bpos(name: String) -> Vector3:
	skel.force_update_all_bone_transforms()
	return skel.global_transform * skel.get_bone_global_pose(_bone(name)).origin


## Posed vertices of all meshes (body first, then eyes) in world space, skinned on the CPU
## (bake_mesh_from_current_skeleton_pose doesn't see bone changes made in the same frame).
func _snapshot() -> Array:
	skel.force_update_all_bone_transforms()
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	for k in meshes.size():
		var mi := meshes[k]
		var skin := mi.skin if mi.skin else mi.get_skin_reference().get_skin()
		var mats: Array[Transform3D] = []
		for j in skin.get_bind_count():
			var bone := skin.get_bind_bone(j)
			if bone < 0:
				bone = skel.find_bone(skin.get_bind_name(j))
			mats.append(skel.get_bone_global_pose(bone) * skin.get_bind_pose(j))
		var a: Array = arrays[k]
		var V: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var Nn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var B: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var W: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var per := B.size() / V.size()
		for i in V.size():
			var p := Vector3.ZERO
			var n := Vector3.ZERO
			for w in per:
				var wt := W[i * per + w]
				if wt <= 0.0:
					continue
				var m := mats[B[i * per + w]]
				p += (m * V[i]) * wt
				n += (m.basis * Nn[i]) * wt
			pos.append(to_world[k] * p)
			nrm.append((to_world[k].basis * n).normalized())
	return [pos, nrm]


func _pose_clip(clip: String, t: float) -> void:
	anim.play(clip)
	anim.seek(t, true)
	anim.pause()


func _rotate(bone: String, axis: Vector3, ang: float) -> void:
	var b := _bone(bone)
	skel.set_bone_pose_rotation(b, skel.get_bone_pose_rotation(b) * Quaternion(axis, ang))


## Local axis of `bone` whose positive rotation moves point `tip` most along `dir`.
func _best_axis(bone: String, tip: String, dir: Vector3) -> Vector3:
	var b := _bone(bone)
	var q := skel.get_bone_pose_rotation(b)
	var p0 := _bpos(tip)
	var best := Vector3.RIGHT
	var best_s := 0.0
	for ax in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		skel.set_bone_pose_rotation(b, q * Quaternion(ax, 0.2))
		var s := (_bpos(tip) - p0).dot(dir)
		skel.set_bone_pose_rotation(b, q)
		if absf(s) > absf(best_s):
			best_s = s
			best = ax
	return best * signf(best_s)


func _ready() -> void:
	var cow: Node3D = load("res://models/farm_cow/scene.gltf").instantiate()
	add_child(cow)
	var found := []
	_find_all(cow, "Skeleton3D", found)
	skel = found[0]
	found = []
	_find_all(cow, "AnimationPlayer", found)
	anim = found[0]
	found = []
	_find_all(cow, "MeshInstance3D", found)
	found.sort_custom(func(a, b): return a.mesh.surface_get_array_len(0) > b.mesh.surface_get_array_len(0))
	meshes.assign(found)  # body (biggest) first, then eyes
	# which space the skin output lives in: pick the transform that matches Godot's own bake at load time
	for mi in meshes:
		arrays.append(mi.mesh.surface_get_arrays(0))
		to_world.append(skel.global_transform)
	var ref: PackedVector3Array = meshes[0].bake_mesh_from_current_skeleton_pose().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var mine: PackedVector3Array = _snapshot()[0]
	var e_skel := 0.0
	var e_mesh := 0.0
	var inv := skel.global_transform.affine_inverse()
	for i in range(0, ref.size(), 50):
		var local := inv * mine[i]
		e_skel += local.distance_to(skel.global_transform.affine_inverse() * (meshes[0].global_transform * ref[i]))
		e_mesh += local.distance_to(ref[i])
	print("skin space check: skeleton %.4f  mesh-local %.4f" % [e_skel, e_mesh])

	# --- normalize: nose to +Z, feet on the ground, fixed length ---
	_pose_clip("Armature|idle1", 0.0)
	fwd = (_bpos("head_012") - _bpos("tail0_025"))
	fwd.y = 0.0
	fwd = fwd.normalized()
	var rest: PackedVector3Array = _snapshot()[0]
	var yaw := Basis(Vector3.UP, atan2(fwd.x, fwd.z)).inverse()
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for v in rest:
		var r := yaw * v
		lo = lo.min(r)
		hi = hi.max(r)
	var s := CowMesh.LENGTH / (hi.z - lo.z)
	norm = Transform3D(yaw.scaled(Vector3.ONE * s), Vector3.ZERO)
	norm.origin = -Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5) * s
	print("model length %.2f -> scale %.3f, height %.2f m" % [hi.z - lo.z, s, (hi.y - lo.y) * s])

	var frames := []  # [positions, normals] per frame, in clip order
	# idle: the model's own idle clip
	var idle_len := anim.get_animation("Armature|idle1").length
	for f in CowMesh.CLIPS.idle[1]:
		_pose_clip("Armature|idle1", idle_len * f / CowMesh.CLIPS.idle[1])
		frames.append(_snapshot())
	# walk: four-beat walk built on the leg bones (back-left, front-left, back-right, front-right)
	var legs := [  # upper bone, joint that folds to lift the hoof, hoof tip, phase offset, swing amount
		["lbl1_02", "twb.L_04", "feetb.L_end_040", 0.0, 0.3],
		["lfl1_017", "twf.L_019", "feetf.L_end_045", 0.25, 0.34],
		["lbr1_031", "twb.R_033", "feetb.R_end_048", 0.5, 0.3],
		["lfr1_021", "twf.R_023", "feetf.R_end_046", 0.75, 0.34],
	]
	_pose_clip("Armature|idle1", 0.0)
	for L in legs:
		L.append(_best_axis(L[0], L[2], fwd))          # swing axis: + moves hoof forward
		L.append(_best_axis(L[1], L[2], Vector3.UP))   # fold axis: + lifts hoof
	var neck_axis := _best_axis("neck2_010", "head_012", Vector3.DOWN)
	var n_walk: int = CowMesh.CLIPS.walk[1]
	for f in n_walk:
		_pose_clip("Armature|idle1", 0.0)
		var cyc := float(f) / n_walk
		for L in legs:
			var p := fmod(cyc + L[3], 1.0)
			var swing: float
			var lift := 0.0
			if p < 0.62:  # stance: hoof planted, leg sweeps back
				swing = lerpf(1.0, -1.0, p / 0.62)
			else:         # swing: leg comes forward with the hoof folded up
				var u := (p - 0.62) / 0.38
				swing = lerpf(-1.0, 1.0, smoothstep(0.0, 1.0, u))
				lift = sin(u * PI)
			_rotate(L[0], L[5], swing * L[4])
			_rotate(L[1], L[6], lift * 0.95)
		_rotate("neck2_010", neck_axis, 0.04 * sin(cyc * TAU * 2.0))  # head nods with each stride
		frames.append(_snapshot())
	# graze: neck and head lowered until the muzzle touches the grass, swinging gently side to side
	_pose_clip("Armature|idle1", 0.0)
	var neck_bones := ["spine6_09", "neck2_010", "neck_011", "head_012"]
	var bend := [0.3, 0.55, 0.4, -0.15]  # share of the bend per bone; head tips back a little to keep the muzzle forward
	var axes := neck_bones.map(func(b): return _best_axis(b, "head_012" if b != "head_012" else "horn.R_end_041", Vector3.DOWN))
	var side_axis := _best_axis("neck2_010", "head_012", fwd.cross(Vector3.UP))
	var lo_m := 0.0
	var best_low := INF
	for it in 13:  # pick the bend with the lowest muzzle while the head still points forward (past that it curls under)
		var m := it * 0.1
		_pose_clip("Armature|idle1", 0.0)
		for k in 4:
			_rotate(neck_bones[k], axes[k], m * bend[k])
		var low := INF
		var nose := -INF
		for v in _snapshot()[0]:
			var r: Vector3 = norm * v
			nose = maxf(nose, r.z)
			if r.z > 0.7:
				low = minf(low, r.y)
		if nose > 1.0 and low < best_low:
			best_low = low
			lo_m = m
	print("graze bend %.2f, muzzle %.2f m above the hooves" % [lo_m, best_low])
	var n_graze: int = CowMesh.CLIPS.graze[1]
	for f in n_graze:
		_pose_clip("Armature|idle1", 0.0)
		for k in 4:
			_rotate(neck_bones[k], axes[k], lo_m * bend[k])
		_rotate("neck2_010", side_axis, 0.12 * sin(float(f) / n_graze * TAU))
		frames.append(_snapshot())
	# death: the model's own clip, plays once
	var death_len := anim.get_animation("Armature|Death").length
	var n_death: int = CowMesh.CLIPS.death[1]
	for f in n_death:
		_pose_clip("Armature|Death", death_len * f / (n_death - 1))
		frames.append(_snapshot())
	assert(frames.size() == CowMesh.FRAMES)

	_save(frames)
	get_tree().quit()


func _save(frames: Array) -> void:
	var vcount: int = frames[0][0].size()
	var rows := ceili(float(vcount) / CowMesh.WIDTH)
	var h := rows * CowMesh.FRAMES
	var pimg := Image.create(CowMesh.WIDTH, h, false, Image.FORMAT_RGBAH)
	var nimg := Image.create(CowMesh.WIDTH, h, false, Image.FORMAT_RGBA8)
	for f in frames.size():
		var P: PackedVector3Array = frames[f][0]
		var N: PackedVector3Array = frames[f][1]
		for i in vcount:
			var x := i % CowMesh.WIDTH
			var y := f * rows + i / CowMesh.WIDTH
			var p: Vector3 = norm * P[i]
			var n: Vector3 = (norm.basis.orthonormalized() * N[i]).normalized()
			pimg.set_pixel(x, y, Color(p.x, p.y, p.z, 1.0))
			nimg.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0))
	ResourceSaver.save(ImageTexture.create_from_image(pimg), CowMesh.DIR + "cow_vat_pos.res")
	ResourceSaver.save(ImageTexture.create_from_image(nimg), CowMesh.DIR + "cow_vat_nrm.res")

	# one surface for body + eyes so VERTEX_ID indexes the VAT; vertex color r flags the eyes
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for k in meshes.size():
		var a := meshes[k].mesh.surface_get_arrays(0)
		var base := verts.size()
		for i in a[Mesh.ARRAY_VERTEX].size():
			verts.append(norm * frames[0][0][base + i])  # rest = first idle frame (snapshots are world space)
			norms.append((norm.basis.orthonormalized() * frames[0][1][base + i]).normalized())
			cols.append(Color(1.0 if k == 1 else 0.0, 0, 0, 1))
		uvs.append_array(a[Mesh.ARRAY_TEX_UV])
		for j in a[Mesh.ARRAY_INDEX]:
			idx.append(base + j)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	ResourceSaver.save(am, CowMesh.DIR + "cow_mesh.res")
	print("baked %d verts x %d frames -> %dx%d" % [vcount, frames.size(), CowMesh.WIDTH, h])
