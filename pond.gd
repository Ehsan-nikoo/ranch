## Stock pond: a round pool dug out and filled by rain, a muddy rim, rocks and cattails.
## Cows drink here like at a windmill tank, it never breaks, and it eases a drought.
class_name Pond
extends Building

const R := 4.6   # water radius; cows stand round the rim to drink


func upgrades() -> Array:
	return [800, 1600]


func upgrade_text() -> String:
	return "برکه بزرگ‌تر: جای بیشتر دورش و تو خشکسالی گاوها کمتر تشنه می‌شن"


func _foot() -> Rect2:
	var x0 := -R - 1.2 - (3.0 if level >= 3 else 0.0)  # the shade roof on -x at level 3
	return Rect2(x0, -R - 1.2, R + 1.2 - x0, (R + 1.2) * 2)


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
	if level >= 2:  # a plank dock out over the water, and more cattails
		for k in 7:
			_box(Vector3(1.3, 0.08, 0.3), Vector3(R * 0.55, 0.32, R - 0.9 + k * 0.34 - 1.0), wood)
		for p in [Vector2(-0.6, -1.0), Vector2(0.6, -1.0), Vector2(-0.6, 1.0), Vector2(0.6, 1.0)]:
			_box(Vector3(0.12, 0.6, 0.12), Vector3(R * 0.55 + p.x, 0.15, R - 0.95 + p.y * 1.0), wood)
		for k in 8:
			var a := 0.9 + rng.randf_range(-0.3, 0.3)
			var p := Vector3(cos(a), 0, sin(a)) * (R - rng.randf_range(0.0, 0.5))
			var h := rng.randf_range(1.0, 1.6)
			_box(Vector3(0.04, h, 0.04), p + Vector3(0, h * 0.5, 0), reed)
			_box(Vector3(0.09, 0.28, 0.09), p + Vector3(0, h - 0.1, 0), head)
	if level >= 3:  # a stone rim all round and a shade roof on -x for hot days
		for k in 26:
			var a := TAU * k / 26.0
			_box(Vector3(0.6, 0.35, 0.45), Vector3(cos(a), 0, sin(a)) * (R + 0.35) + Vector3(0, 0.12, 0), stone, Vector3(0, -a, 0))
		var c := Vector3(-R - 2.6, 0, 0)
		for p in [Vector2(-1.2, -1.8), Vector2(1.2, -1.8), Vector2(-1.2, 1.8), Vector2(1.2, 1.8)]:
			_box(Vector3(0.18, 2.6, 0.18), c + Vector3(p.x, 1.3, p.y), wood)
		var st := _st()
		_slab(st, c + Vector3(-1.5, 2.9, 0), c + Vector3(1.5, 2.5, 0), Vector3(0, 0, 2.2), roof.get_meta("tile"))
		_commit(st, roof)
	MeshMerge.boxes(self)
