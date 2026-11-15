## Management-game camera. Touch: 1 finger pans, 2 fingers pinch-zoom and twist-rotate.
## Mouse (desktop testing): left-drag pans, right-drag rotates, wheel zooms.
class_name CameraRig
extends Node3D

const BOUNDS := 60.0
const MIN_DIST := 10.0
const MAX_DIST := 75.0
const SMOOTH := 10.0

var target := Vector3(-2, 0, 2)
var yaw := deg_to_rad(25.0)
var dist := 48.0
var cam := Camera3D.new()

var _yaw := yaw
var _dist := dist
var _touches := {}  # index -> position
var _pinch_len := 0.0
var _pinch_ang := 0.0


func _ready() -> void:
	cam.fov = 38.0
	cam.far = 400.0
	add_child(cam)
	position = target
	_apply()


## Jump straight to the current target/yaw/dist without easing.
func snap() -> void:
	position = target
	_yaw = yaw
	_dist = dist
	if is_inside_tree():
		_apply()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			_touches[e.index] = e.position
		else:
			_touches.erase(e.index)
		_reset_pinch()
	elif e is InputEventScreenDrag:
		if _touches.size() == 1:
			_pan(e.relative)
		_touches[e.index] = e.position
		if _touches.size() == 2:
			var p: Array = _touches.values()
			var v: Vector2 = p[1] - p[0]
			if _pinch_len > 0.0:
				dist = clampf(dist * _pinch_len / maxf(v.length(), 1.0), MIN_DIST, MAX_DIST)
				yaw += angle_difference(_pinch_ang, v.angle())
			_pinch_len = v.length()
			_pinch_ang = v.angle()
	elif e is InputEventMouseMotion:
		if e.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_pan(e.relative)
		elif e.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			yaw -= e.relative.x * 0.006
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = maxf(dist * 0.9, MIN_DIST)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = minf(dist * 1.1, MAX_DIST)


func _reset_pinch() -> void:
	_pinch_len = 0.0


func _pan(rel: Vector2) -> void:
	# scale with zoom so the ground stays under the finger
	var k := _dist * 0.0016 * (1080.0 / get_viewport().get_visible_rect().size.y)
	var right := Vector3(cos(_yaw), 0, -sin(_yaw))
	var fwd := Vector3(sin(_yaw), 0, cos(_yaw))
	target -= (right * rel.x + fwd * rel.y) * k
	target.x = clampf(target.x, -BOUNDS, BOUNDS)
	target.z = clampf(target.z, -BOUNDS, BOUNDS)


func _process(delta: float) -> void:
	var t := 1.0 - exp(-SMOOTH * delta)
	position = position.lerp(target, t)
	_yaw = lerp_angle(_yaw, yaw, t)
	_dist = lerpf(_dist, dist, t)
	_apply()


func _apply() -> void:
	# zoomed in = lower, more cinematic angle; zoomed out = top-down overview
	var z := inverse_lerp(MIN_DIST, MAX_DIST, _dist)
	var pitch := deg_to_rad(lerpf(14.0, 52.0, z))
	var aim := Vector3(0, lerpf(2.5, 0.0, z), 0)
	cam.position = aim + Vector3(sin(_yaw) * cos(pitch), sin(pitch), cos(_yaw) * cos(pitch)) * _dist
	cam.look_at(global_position + aim)
