## Debug overlay for the phone test: FPS, frame cost, game time, and speed/quality buttons.
class_name Hud
extends CanvasLayer

const SPEEDS := [1.0, 10.0, 60.0]
# name, 3D render scale, shadows, share of grass drawn
const QUALITY := [["High", 1.0, true, 1.0], ["Medium", 0.8, true, 0.7], ["Low", 0.65, false, 0.45]]

var day: DayCycle
var grass: Array[MultiMesh] = []
var _label := Label.new()
var _speed_btn := Button.new()
var _quality_btn := Button.new()
var _speed := 0
var _quality := 1


func _ready() -> void:
	_label.position = Vector2(24, 16)
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_child(_label)
	var row := HBoxContainer.new()
	row.position = Vector2(24, 120)
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	for b: Button in [_speed_btn, _quality_btn]:
		b.custom_minimum_size = Vector2(190, 64)
		b.add_theme_font_size_override("font_size", 24)
		row.add_child(b)
	_speed_btn.pressed.connect(func(): _set_speed(_speed + 1))
	_quality_btn.pressed.connect(func(): _set_quality(_quality + 1))
	_set_speed(0)
	_set_quality(1)


func _set_speed(i: int) -> void:
	_speed = i % SPEEDS.size()
	day.speed = SPEEDS[_speed]
	_speed_btn.text = "Time %dx" % SPEEDS[_speed]


func _set_quality(i: int) -> void:
	_quality = i % QUALITY.size()
	var q: Array = QUALITY[_quality]
	get_viewport().scaling_3d_scale = q[1]
	day.light.shadow_enabled = q[2]
	for mm in grass:
		mm.visible_instance_count = int(mm.instance_count * q[3])
	_quality_btn.text = "Quality: %s" % q[0]


func _process(_delta: float) -> void:
	var fps := Engine.get_frames_per_second()
	_label.text = "%d FPS  (%.1f ms)   draws %d   tris %dk\n%02d:%02d" % [
		fps, 1000.0 / maxf(fps, 1.0),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
		int(day.hour), int(fmod(day.hour, 1.0) * 60)]
