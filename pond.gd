## Stock pond: a round pool dug out and filled by rain, a muddy rim, rocks and cattails.
## Cows drink here like at a windmill tank, it never breaks, and it eases a drought.
class_name Pond
extends Building

const R := 4.6   # water radius; cows stand round the rim to drink


func _foot() -> Rect2:
	return Rect2(-R - 1.2, -R - 1.2, (R + 1.2) * 2, (R + 1.2) * 2)


func _ready() -> void:
	_cyl(R + 1.0, 0.04, Vector3(0, 0.03, 0), _mud(), 36)
	_cyl(R, 0.04, Vector3(0, 0.07, 0), water, 36)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 9:  # rocks round the edge
		var a := rng.randf() * TAU
		var s := rng.randf_range(0.35, 0.7)
		_box(Vector3(s, s * 0.6, s * 0.8), Vector3(cos(a), 0, sin(a)) * (R + 0.6) + Vector3(0, s * 0.2, 0), stone, Vector3(0, rng.randf() * TAU, rng.randf_range(-0.3, 0.3)))
	var reed := _plain(Color(0.3, 0.42, 0.18), 0.9)
	var head := _plain(Color(0.33, 0.2, 0.1), 1.0)
	for clump in [-2.4, -1.8, 2.6]:  # cattails on the far side
		for k in 7:
			var a: float = clump + rng.randf_range(-0.25, 0.25)
			var p := Vector3(cos(a), 0, sin(a)) * (R - rng.randf_range(0.0, 0.6))
			var h := rng.randf_range(1.0, 1.7)
			var tilt := Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15))
			_box(Vector3(0.04, h, 0.04), p + Vector3(0, h * 0.5, 0), reed, tilt)
			_box(Vector3(0.09, 0.28, 0.09), p + Vector3(0, h - 0.1, 0), head, tilt)
	MeshMerge.boxes(self)
