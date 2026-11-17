## The big ranch entrance over the road: two log posts either side, a log beam across the top,
## a burned-wood name board hanging on chains, and an iron longhorn skull on the beam.
## Gate local x runs across the road; the road passes along local z between the posts.
class_name RanchGate
extends Building

const HALF := 4.3      # posts this far either side of the road center
const TOP := 6.8
const NAME := "رنچ دشت طلایی"

var log_mat: StandardMaterial3D


func posts() -> Array[Vector3]:
	return [to_global(Vector3(HALF, 0, 0)), to_global(Vector3(-HALF, 0, 0))]


func _ready() -> void:
	log_mat = _tex("trim_white_diff.jpg", "distressed_painted_planks", 1.4, true)
	log_mat.albedo_color = Color(0.5, 0.36, 0.24)
	for s in [-1.0, 1.0]:
		_cyl(0.34, TOP + 0.4, Vector3(HALF * s, (TOP + 0.4) * 0.5, 0), log_mat, 14, 0.3)
		_cyl(0.33, 0.06, Vector3(HALF * s, TOP + 0.42, 0), wood, 14)                 # sawn end
		_beam(Vector3(HALF * s, TOP - 1.5, 0), Vector3((HALF - 1.3) * s, TOP, 0), 0.2, log_mat)  # knee brace
		for k in 5:  # stones piled around the foot of each post
			var a: float = k * TAU / 5.0 + s
			_box(Vector3(0.5, 0.35, 0.45), Vector3(HALF * s + cos(a) * 0.55, 0.15, sin(a) * 0.55), stone, Vector3(0, a, 0.15))
	var beam := _cyl(0.3, HALF * 2 + 1.6, Vector3(0, TOP, 0), log_mat, 14, 0.28)
	beam.rotation.z = PI * 0.5
	# name board hanging on two chains
	var board_y := TOP - 1.45
	_box(Vector3(5.2, 1.35, 0.14), Vector3(0, board_y, 0), wood)
	for s in [-1.0, 1.0]:
		_box(Vector3(0.05, TOP - board_y - 0.5, 0.05), Vector3(2.1 * s, (TOP + board_y + 0.5) * 0.5 + 0.08, 0), iron)
		_box(Vector3(5.3, 0.1, 0.18), Vector3(0, board_y + 0.66 * s, 0), log_mat)    # top and bottom rails
	for z in [0.08, -0.08]:  # burned-in name on both faces
		var l := Label3D.new()
		l.text = NAME
		l.font = load("res://ui/fonts/Vazirmatn-Bold.ttf")
		l.font_size = 110
		l.pixel_size = 0.0068
		l.modulate = Color(0.16, 0.08, 0.03)
		l.outline_size = 0
		l.position = Vector3(0, board_y, z)
		l.rotation.y = 0.0 if z > 0 else PI
		l.shaded = true
		add_child(l)
	_skull(Vector3(0, TOP + 0.95, 0))
	MeshMerge.boxes(self)


## Flat iron longhorn steer skull, extruded from an outline.
func _skull(at: Vector3) -> void:
	var half := [Vector2(0, 0.55), Vector2(0.25, 0.55), Vector2(0.36, 0.45), Vector2(0.8, 0.42), Vector2(1.3, 0.52),
		Vector2(1.7, 0.8), Vector2(1.55, 0.56), Vector2(1.2, 0.34), Vector2(0.75, 0.28), Vector2(0.36, 0.26),
		Vector2(0.3, 0.0), Vector2(0.2, -0.38), Vector2(0.12, -0.62)]
	var outline := PackedVector2Array()
	for p in half:  # right half top to chin, the chin point, then the left half back up
		outline.append(p)
	outline.append(Vector2(0, -0.66))
	for i in range(half.size() - 1, 0, -1):
		outline.append(Vector2(-half[i].x, half[i].y))
	var tris := Geometry2D.triangulate_polygon(outline)
	var st := _st()
	var t := 0.05
	for side in [1.0, -1.0]:
		for i in range(0, tris.size(), 3):
			var idx := [tris[i], tris[i + 1], tris[i + 2]] if side > 0 else [tris[i], tris[i + 2], tris[i + 1]]
			for j in idx:
				st.add_vertex(at + Vector3(outline[j].x, outline[j].y, t * side))
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var q := [Vector3(a.x, a.y, t), Vector3(b.x, b.y, t), Vector3(b.x, b.y, -t), Vector3(a.x, a.y, -t)]
		for k in [0, 2, 1, 0, 3, 2]:
			st.add_vertex(at + q[k])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m: StandardMaterial3D = iron.duplicate()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED  # thin plate, seen from both sides; winding doesn't matter
	mi.material_override = m
	add_child(mi)
	# post the skull stands on
	_box(Vector3(0.1, 0.5, 0.1), at + Vector3(0, -0.75, 0), iron)
