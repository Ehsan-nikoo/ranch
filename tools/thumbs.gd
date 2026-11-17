## Renders a picture of each building for the build menu into res://ui/thumbs/<name>.png.
## Run (needs a real GPU, not --headless):
##   godot --path . res://tools/thumbs.tscn
extends Node

# file name, building, camera distance, aim height
var LIST := [["barn", Barn, 40.0, 3.5], ["house", RanchHouse, 26.0, 2.0], ["silo", Silo, 34.0, 6.5], ["windmill", Windmill, 29.0, 5.0], ["cow", null, 7.5, 0.8],
	["stable", HorseStable, 36.0, 2.2], ["smithy", Blacksmith, 28.0, 2.2], ["rodeo", RodeoArena, 44.0, 1.0]]


func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(480, 320)
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.85)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.86, 0.66)
	sun.light_energy = 2.1
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-38, -55, 0)
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	var dirt := StandardMaterial3D.new()
	dirt.albedo_texture = load("res://textures/dirt_diff.jpg")
	dirt.uv1_scale = Vector3(4, 4, 4)
	dirt.uv1_triplanar = true

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ui/thumbs"))
	for item in LIST:
		var b: Node3D
		var f := Rect2(-1.2, -1.2, 2.4, 2.4)
		if item[1] == null:  # the cow: same mesh and shader as the herd, standing still
			b = MeshInstance3D.new()
			b.mesh = CowMesh.mesh()
			b.material_override = CowMesh.material()
			b.rotation.y = -0.5
			vp.add_child(b)
		else:
			b = item[1].new()
			vp.add_child(b)
			f = b._foot()
		var c := Vector3(f.get_center().x, 0, f.get_center().y)
		# round patch of dirt so the building stands on something
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = maxf(f.size.x, f.size.y) * 0.62
		cm.bottom_radius = cm.top_radius
		cm.height = 0.1
		disc.mesh = cm
		disc.material_override = dirt
		disc.position = c + Vector3(0, -0.05, 0)
		vp.add_child(disc)
		var yaw := deg_to_rad(32.0)
		var pitch := deg_to_rad(24.0)
		var aim := c + Vector3(0, item[3], 0)
		cam.position = aim + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * item[2]
		cam.look_at(aim)
		for k in 4:
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://ui/thumbs/%s.png" % item[0]))
		b.free()
		disc.free()
	get_tree().quit()
