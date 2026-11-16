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
	mm.instance_count = 3
	# x, yaw, phase, head, coat, walk
	var cows := [[-3.2, 1.3, 0.0, 0.0, 0.2, 0.0], [0.0, 0.9, 1.2, 0.0, 0.5, 1.0], [3.2, 2.2, 0.0, 1.0, 0.85, 0.0]]
	for i in 3:
		var c: Array = cows[i]
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, c[1]), Vector3(c[0], 0, 0)))
		mm.set_instance_custom_data(i, Color(c[2], c[3], c[4], c[5]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = CowMesh.material()
	add_child(mmi)

	var cam := Camera3D.new()
	cam.fov = 32
	cam.position = Vector3(2.5, 3.2, 10.5)
	add_child(cam)
	cam.look_at(Vector3(0, 0.9, 0))
	for k in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://renders/cow_test.png"))
	get_tree().quit()
