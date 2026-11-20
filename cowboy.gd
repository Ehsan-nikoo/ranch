## A ranch hand on horseback: the horse is HorseMesh (its legs swing in horse.gdshader) and the rider is
## "Western Cowboy (Rigged)" by stevedaman (Sketchfab, CC-BY 4.0, models/rider/), a Mixamo-rigged man
## posed sitting astride the saddle, his plaid shirt dyed the colour of his job (rider.gdshader).
## Crew moves it; walk() animates it.
class_name Cowboy
extends Node3D

const SHIRTS := [Color(0.6, 0.16, 0.12), Color(0.16, 0.24, 0.48), Color(0.62, 0.5, 0.3), Color(0.28, 0.44, 0.2)]  # by Workers skill
# [tint, pale]: bay, chestnut, black, grey, then the rare ones that only come from breeding (Horses.RARE):
# golden with a black mane, smoky blue, white
const COATS := [[Color(1, 1, 1), 0.0], [Color(1.45, 0.82, 0.5), 0.0], [Color(0.42, 0.4, 0.4), 0.0], [Color(1, 1, 1), 0.85],
	[Color(3.4, 2.8, 1.2), 0.0], [Color(0.5, 0.56, 0.72), 0.5], [Color(1, 1, 1), 1.75]]
const COMMON := 4  # the first four: what town sells and what the hands ride
const RIDER := "res://models/rider/scene.gltf"
const BONE := "mixamorig_%s"
const TALL := 1.78                 # meters

var skill := 0
var coat := 0
var _horse := MeshInstance3D.new()
var _rider: Node3D
var _seat_y := 0.0
var _phase := 0.0
var _speed := 0.0
static var _shirts := {}


func _ready() -> void:
	_horse.mesh = HorseMesh.mesh()
	for s in 3:
		_horse.set_surface_override_material(s, HorseMesh.material(s, COATS[coat][0], COATS[coat][1] if s == 0 else 0.0))
	add_child(_horse)
	_rider = load(RIDER).instantiate()
	add_child(_rider)
	var body: MeshInstance3D = _rider.find_children("*", "MeshInstance3D", true, false)[0]
	body.material_override = _shirt(body.mesh.surface_get_material(0))
	var sk: Skeleton3D = _rider.find_children("*", "Skeleton3D", true, false)[0]
	# the file comes in at several times life size: scale it to a man of TALL from his boots to his crown
	var top := sk.global_transform * sk.get_bone_global_pose(_bone(sk, "HeadTop_End")).origin
	var toe := sk.global_transform * sk.get_bone_global_pose(_bone(sk, "LeftToeBase")).origin
	_rider.scale = Vector3.ONE * TALL / (top.y - toe.y)
	_sit(sk)
	# hips just above the seat of the saddle
	var hips := sk.global_transform * sk.get_bone_global_pose(_bone(sk, "Hips")).origin
	_rider.position += HorseMesh.saddle + Vector3(0, 0.1, -0.15) - to_local(hips)
	_seat_y = _rider.position.y


## One shared material per job colour.
func _shirt(src: Material) -> ShaderMaterial:
	if not _shirts.has(skill):
		var m := ShaderMaterial.new()
		m.shader = load("res://rider.gdshader")
		m.set_shader_parameter("tex", (src as BaseMaterial3D).albedo_texture)
		m.set_shader_parameter("shirt", SHIRTS[skill])
		_shirts[skill] = m
	return _shirts[skill]


## Mixamo bone names carry a running number after them ("mixamorig_LeftLeg_048").
func _bone(sk: Skeleton3D, name: String) -> int:
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).begins_with(BONE % name + "_"):
			return i
	push_error("missing bone " + name)
	return -1


## Turns a bone so that it points along `dir` (in skeleton space), keeping its twist.
func _aim(sk: Skeleton3D, bone: String, dir: Vector3) -> void:
	var i := _bone(sk, bone)
	var g := sk.get_bone_global_pose(i)
	var q := Quaternion(g.basis.y.normalized(), dir.normalized())
	var want := Basis(q) * g.basis
	var p := sk.get_bone_parent(i)
	var parent := sk.get_bone_global_pose(p).basis if p >= 0 else Basis()
	sk.set_bone_pose_rotation(i, (parent.inverse() * want).get_rotation_quaternion())
	sk.force_update_all_bone_transforms()


## From the T-pose to sitting astride: thighs forward and out round the barrel, shins hanging to the
## stirrups, heels down, both hands forward low on the reins.
func _sit(sk: Skeleton3D) -> void:
	for side in [["Left", 1.0], ["Right", -1.0]]:
		var s: String = side[0]
		var x: float = side[1]
		_aim(sk, s + "UpLeg", Vector3(0.42 * x, -0.4, 0.8))
		_aim(sk, s + "Leg", Vector3(0.12 * x, -1.0, -0.1))
		_aim(sk, s + "Foot", Vector3(0.1 * x, -0.25, 0.95))
		_aim(sk, s + "Arm", Vector3(0.14 * x, -0.95, 0.25))
		_aim(sk, s + "ForeArm", Vector3(-0.18 * x, -0.5, 0.85))
		_aim(sk, s + "Hand", Vector3(-0.1 * x, -0.4, 0.9))


## Animates the stride for this frame: `speed` in m/s of ground covered (0 = standing).
func walk(delta: float, speed: float) -> void:
	_speed = lerpf(_speed, speed, minf(1.0, delta * 4.0))
	var k := clampf(_speed / 2.0, 0.0, 1.0)
	_phase = fmod(_phase + delta * clampf(_speed, 0.0, 6.0) * 2.2, TAU)
	_horse.set_instance_shader_parameter("phase", _phase)
	_horse.set_instance_shader_parameter("amp", 0.42 * k)
	_rider.position.y = _seat_y + absf(sin(_phase)) * 0.04 * k
