## Close-up check of the procedural cow: three coats, standing / walking / grazing.
## godot --path . res://tools/cow_test.tscn   -> renders/cow_test.png
extends Node3D


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.55, 0.42)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.85)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.86, 0.66)
	sun.light_energy = 2.1
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-35, -50, 0)
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = load("res://textures/dirt_diff.jpg")
	gm.uv1_scale = Vector3(6, 6, 1)
	ground.material_override = gm
	add_child(ground)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = CowMesh.mesh()
	# x, yaw, walk cycle, head, coat, walk; one of each coat: standing, walking, grazing, walking
	var cows := [[-4.8, 1.3, 0.0, 0.0, 0.05, 0.0], [-1.6, 0.9, 0.3, 0.0, 0.3, 1.0], [1.6, 2.2, 0.0, 1.0, 0.55, 0.0], [4.8, 1.6, 0.7, 0.0, 0.8, 1.0]]
	if OS.get_cmdline_user_args().has("--walk"):  # side view of the walk cycle at four moments
		cows = [[-4.8, PI / 2, 0.0, 0.0, 0.3, 1.0], [-1.6, PI / 2, 0.25, 0.0, 0.3, 1.0], [1.6, PI / 2, 0.5, 0.0, 0.3, 1.0], [4.8, PI / 2, 0.75, 0.0, 0.3, 1.0]]
	mm.instance_count = cows.size()
	for i in cows.size():
		var c: Array = cows[i]
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, c[1]), Vector3(c[0], 0, 0)))
		mm.set_instance_custom_data(i, Color(c[2], c[3], c[4], c[5]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = CowMesh.material()
	add_child(mmi)

	var cam := Camera3D.new()
	cam.fov = 32
	cam.position = Vector3(0, 1.0, 13.0) if OS.get_cmdline_user_args().has("--walk") else Vector3(2.5, 3.6, 13.5)
	add_child(cam)
	cam.look_at(Vector3(0, 0.9, 0))
	for k in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://renders/cow_test.png"))
	get_tree().quit()
