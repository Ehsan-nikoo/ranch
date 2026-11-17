## Big open-sided hay barn: a red back wall, posts and a tin gable roof over stacks of square bales,
## with a few round bales out front. Stores far more hay than a silo. Front faces +Z.
class_name HayShed
extends Building

const W := 6.5
const D := 4.0
const EAVE := 4.4
const RIDGE := 6.2


func hay_room() -> int:
	return 150


func _foot() -> Rect2:
	return Rect2(-W - 0.6, -D - 0.6, W * 2 + 1.2, D * 2 + 2.4)


func _ready() -> void:
	eave = EAVE
	var st := _st()
	var t: float = red.get_meta("tile")
	_wall(st, Vector3(W, 0, -D), Vector3(-W, 0, -D), EAVE, Vector3(0, 0, -1), t, true)  # back wall
	for s in [-1.0, 1.0]:  # gable boards high up on the ends, open below
		var x: float = W * s
		_poly(st, [Vector3(x, EAVE, -D), Vector3(x, EAVE, D), Vector3(x, RIDGE, 0)], Vector3(s, 0, 0), Vector3.DOWN, Vector3.BACK, t)
	_commit(st, red)
	_roof_over(W, D, EAVE, RIDGE, 0.5)
	for k in 5:
		var x := lerpf(-W, W, k / 4.0)
		for z in [-D, D]:
			_box(Vector3(0.3, EAVE, 0.3), Vector3(x, EAVE * 0.5, z), wood)
		_box(Vector3(0.18, 0.24, D * 2), Vector3(x, EAVE - 0.1, 0), wood)  # tie beam
	_box(Vector3(W * 2 + 0.3, 0.14, 0.24), Vector3(0, EAVE - 0.05, D), white)  # front plate
	_box(Vector3(W * 2, 0.1, D * 2), Vector3(0, 0.05, 0), concrete)  # slab
	# stacks of square bales: tallest at the back, stepping down toward the open front
	var hay := _straw()
	var dark := _plain(Color(0.66, 0.53, 0.27), 1.0)  # every other bale a shade darker, so the stack reads
	for row in 4:
		var z := -D + 0.7 + row * 1.25
		var layers := 4 - row
		for l in layers:
			for k in 8:
				var x := -W + 0.9 + k * 1.45 + (0.35 if l % 2 == 1 else 0.0)
				if x > W - 0.7:
					continue
				_box(Vector3(1.3, 0.52, 1.1), Vector3(x, 0.38 + l * 0.58, z), hay if (k + l + row) % 2 == 0 else dark)
	for p in [Vector3(-3.5, 0, D + 1.3), Vector3(-1.9, 0, D + 1.5), Vector3(4.4, 0, D + 1.3)]:
		_cyl(0.75, 1.2, p + Vector3(0, 0.75, 0), hay, 14).rotation.z = PI * 0.5  # round bales on their side
	MeshMerge.boxes(self)
