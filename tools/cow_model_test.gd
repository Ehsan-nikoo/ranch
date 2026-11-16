## Looks at the imported Sketchfab cow: bounds, bones, and a render with a test pose.
## godot --path . res://tools/cow_model_test.tscn -- --pose=rest|walk|graze  -> renders/cow_model.png
extends Node3D

var skel: Skeleton3D
var anim: AnimationPlayer


func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var f := _find(c, cls)
		if f:
			return f
	return null


func _arg(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.get_slice("=", 1)
	return def


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.55, 0.42)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.85)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.86, 0.66)
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-35, -50, 0)
	add_child(sun)

	var cow: Node3D = load("res://models/farm_cow/scene.gltf").instantiate()
	add_child(cow)
	skel = _find(cow, "Skeleton3D")
	anim = _find(cow, "AnimationPlayer")
	print("anims ", anim.get_animation_list())
	var mi: MeshInstance3D = _find(cow, "MeshInstance3D")
	var aabb := mi.global_transform * mi.get_aabb()
	print("aabb ", aabb)
	print("bones ", skel.get_bone_count())
	for i in skel.get_bone_count():
		print(i, " ", skel.get_bone_name(i), " parent ", skel.get_bone_parent(i), " rest ", skel.get_bone_rest(i).basis.get_euler().snapped(Vector3.ONE * 0.01))
	print("has bake ", mi.has_method("bake_mesh_from_current_skeleton_pose"))

	var c := aabb.get_center()
	var cam := Camera3D.new()
	cam.fov = 35
	var size := aabb.size.length()
	cam.position = c + Vector3(size * 1.3, size * 0.25, size * 0.6)
	add_child(cam)
	cam.look_at(c)
	for k in 6:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://renders/cow_model.png"))
	get_tree().quit()
