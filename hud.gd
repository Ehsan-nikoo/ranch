## Debug overlay for the phone test: FPS, CPU/GPU frame cost, game time, and speed/quality/grass buttons.
class_name Hud
extends CanvasLayer

const SPEEDS := [1.0, 10.0, 60.0]
# name, 3D render scale, shadows (0 off, 1 cheap, 2 full), share of grass drawn, glow, MSAA
const QUALITY := [
	["High", 0.9, 2, 1.0, true, Viewport.MSAA_2X],
	["Medium", 0.75, 1, 0.55, false, Viewport.MSAA_DISABLED],
	["Low", 0.6, 0, 0.3, false, Viewport.MSAA_DISABLED],
]

var day: DayCycle
var grass: Array[MultiMesh] = []
var grass_nodes: Array[Node3D] = []
var _label := Label.new()
var _speed_btn := Button.new()
var _quality_btn := Button.new()
var _grass_btn := Button.new()
var _speed := 0
var _quality := 1
var _tick := 0.0


func _ready() -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_label.position = Vector2(24, 16)
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_child(_label)
	var row := HBoxContainer.new()
	row.position = Vector2(24, 120)
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	for b: Button in [_speed_btn, _quality_btn, _grass_btn]:
		b.custom_minimum_size = Vector2(190, 64)
		b.add_theme_font_size_override("font_size", 24)
		row.add_child(b)
	_speed_btn.pressed.connect(func(): _set_speed(_speed + 1))
	_quality_btn.pressed.connect(func(): _set_quality(_quality + 1))
	_grass_btn.pressed.connect(_toggle_grass)
	_set_speed(0)
	_set_quality(1)
	_grass_btn.text = "Grass: on"


func _set_speed(i: int) -> void:
	_speed = i % SPEEDS.size()
	day.speed = SPEEDS[_speed]
	_speed_btn.text = "Time %dx" % SPEEDS[_speed]


func _set_quality(i: int) -> void:
	_quality = i % QUALITY.size()
	var q: Array = QUALITY[_quality]
	var vp := get_viewport()
	vp.scaling_3d_scale = q[1]
	vp.msaa_3d = q[5]
	day.light.shadow_enabled = q[2] > 0
	day.light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if q[2] == 2 else DirectionalLight3D.SHADOW_ORTHOGONAL
	# distance is measured from the camera, which sits ~50 m out, so it must reach past the ranch
	day.light.directional_shadow_max_distance = 90.0
	RenderingServer.directional_shadow_atlas_set_size(2048, q[2] == 2)
	day.env.glow_enabled = q[4]
	for mm in grass:
		mm.visible_instance_count = int(mm.instance_count * q[3])
	_quality_btn.text = "Quality: %s" % q[0]


func _toggle_grass() -> void:
	var on := not grass_nodes[0].visible
	for n in grass_nodes:
		n.visible = on
	_grass_btn.text = "Grass: %s" % ("on" if on else "off")


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25  # relabeling every frame costs text shaping on a slow CPU
	var rid := get_viewport().get_viewport_rid()
	_label.text = "%d FPS   CPU %.1f ms   GPU %.1f ms   draws %d\n%02d:%02d" % [
		Engine.get_frames_per_second(),
		RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu(),
		RenderingServer.viewport_get_measured_render_time_gpu(rid),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		int(day.hour), int(fmod(day.hour, 1.0) * 60)]
