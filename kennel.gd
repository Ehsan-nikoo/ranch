## Dog kennel: three little doghouses in a fenced run, with water bowls and two ranch dogs.
## The dogs help the hands move the herd and bark the wolves away. Front faces +Z.
class_name Kennel
extends Building

const HX := 4.2
const HZ := 2.8
const DOG := "res://models/dog/scene.gltf"
const MODEL_TALL := 4.46   # the file's height, nose to paws, as it comes in
const TALL := 0.72         # a real lab: about 0.57 m at the shoulder, head up a bit higher


func upgrades() -> Array:
	return [1000, 2000]


func upgrade_text() -> String:
	return "سگ‌های بیشتر: خودت ۵ و هر کارگر ۲ تا گاو بیشتر رو می‌چرخونه"


func _foot() -> Rect2:
	return Rect2(-HX - 0.4, -HZ - 0.4, HX * 2 + 0.8, HZ * 2 + 0.8)


func _ready() -> void:
	_box(Vector3(HX * 2, 0.06, HZ * 2), Vector3(0, 0.03, 0), _mud())
	_pen(Vector3.ZERO, HX, HZ, white, 1.4, 1.0)  # low, so the dogs show over it
	for x in [-2.7, 0.0, 2.7]:
		_doghouse(Vector3(x, 0, -HZ + 1.0))
	for x in [-3.3, 3.3]:
		_cyl(0.22, 0.12, Vector3(x, 0.06, 0.9), steel, 12)
		_cyl(0.18, 0.02, Vector3(x, 0.12, 0.9), water, 12)
	MeshMerge.boxes(self)  # before the dogs: their meshes must stay their own
	_dog(Vector3(-1.35, 0, -0.4), 0.5, Color.WHITE)
	_dog(Vector3(1.4, 0, -0.1), -2.4, Color(0.62, 0.44, 0.3))


func _doghouse(at: Vector3) -> void:
	_box(Vector3(1.3, 0.9, 1.1), at + Vector3(0, 0.45, 0), red)
	_box(Vector3(0.5, 0.6, 0.04), at + Vector3(0, 0.32, 0.56), glass)  # dark door hole
	for s in [-1.0, 1.0]:  # two roof boards meeting at the ridge
		_box(Vector3(0.95, 0.07, 1.3), at + Vector3(0.36 * s, 1.15, 0), roof, Vector3(0, 0, -0.62 * s))
	_box(Vector3(0.3, 0.06, 0.06), at + Vector3(0, 0.8, 0.57), white)  # name board


## A ranch dog from models/dog/ (a rigged labrador), standing at `at` and idling on its own loop.
## `coat` tints the yellow fur: white = as modelled, darker for a brown or black dog.
func _dog(at: Vector3, yaw: float, coat: Color) -> void:
	var dog: Node3D = load(DOG).instantiate()
	dog.position = at
	dog.rotation.y = yaw
	dog.scale = Vector3.ONE * TALL / MODEL_TALL
	add_child(dog)
	if coat != Color.WHITE:
		for mi: MeshInstance3D in dog.find_children("*", "MeshInstance3D", true, false):
			for i in mi.mesh.get_surface_count():
				var m: BaseMaterial3D = mi.mesh.surface_get_material(i).duplicate()
				m.albedo_color = coat
				mi.set_surface_override_material(i, m)
	var ap: AnimationPlayer = dog.find_children("*", "AnimationPlayer", true, false)[0]
	var anim := ap.get_animation(ap.get_animation_list()[0])
	anim.loop_mode = Animation.LOOP_LINEAR
	ap.play(anim.resource_name if anim.resource_name != "" else ap.get_animation_list()[0])
	ap.seek(randf() * anim.length)  # the dogs don't move in step
