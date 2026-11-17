## Renders the four ranch hands side by side into renders/cowboys.png, to check how they look.
## Run (needs a GPU, not --headless):  godot --path . res://tools/cowboy_shot.tscn
extends Node3D


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.74, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.66, 0.85)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.88, 0.7)
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-40, -35, 0)
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = load("res://textures/dirt_diff.jpg")
	gm.uv1_triplanar = true
	gm.uv1_scale = Vector3(0.3, 0.3, 0.3)
	ground.material_override = gm
	add_child(ground)
	var riders: Array[Cowboy] = []
	for k in 4:
		var c := Cowboy.new()
		c.skill = k
		c.coat = k
		c.position = Vector3((k - 1.5) * 2.4, 0, 0)
		c.rotation.y = 0.9
		add_child(c)
		riders.append(c)
	var cam := Camera3D.new()
	cam.fov = 35.0
	add_child(cam)
	cam.position = Vector3(1.0, 4.2, 10.5)
	cam.look_at(Vector3(0, 1.3, 0))
	for i in 20:
		for k in 4:
			riders[k].walk(0.05, 0.0 if k == 0 else 2.0)
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://renders/cowboys.png"))
	get_tree().quit()
