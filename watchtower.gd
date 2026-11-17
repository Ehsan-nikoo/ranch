## Lookout tower: four tall timber legs braced with X's, a railed platform under a little pyramid
## roof, a ladder and a lantern that glows at night. Rustlers are seen coming. Ladder faces +Z.
class_name Watchtower
extends Building

const H := 7.5      # platform height
const LOW := 1.6    # half width at the ground
const TOP := 1.15   # half width at the platform


func _foot() -> Rect2:
	return Rect2(-LOW - 0.4, -LOW - 0.4, (LOW + 0.4) * 2, (LOW + 0.4) * 2 + 0.8)


func _corner(i: int, y: float) -> Vector3:
	var h := lerpf(LOW, TOP, y / H)
	return Vector3(h if i == 0 or i == 3 else -h, y, h if i < 2 else -h)


func _ready() -> void:
	for i in 4:
		_beam(_corner(i, 0.0), _corner(i, H), 0.24, wood)
		_box(Vector3(0.5, 0.3, 0.5), _corner(i, 0.1), stone)
	for k in 3:  # X braces on every face, three bays up
		var y0 := k * H / 3.0
		var y1 := (k + 1) * H / 3.0
		for i in 4:
			var j := (i + 1) % 4
			_beam(_corner(i, y0 + 0.2), _corner(j, y1 - 0.2), 0.09, wood)
			_beam(_corner(j, y0 + 0.2), _corner(i, y1 - 0.2), 0.09, wood)
			_beam(_corner(i, y1), _corner(j, y1), 0.12, wood)
	var w := TOP + 0.35
	_box(Vector3(w * 2, 0.16, w * 2), Vector3(0, H, 0), wood)  # platform
	for i in 4:  # railing with corner posts that carry the roof
		var c := Vector3(w if i == 0 or i == 3 else -w, H, w if i < 2 else -w) * Vector3(0.95, 1, 0.95)
		_box(Vector3(0.12, 2.3, 0.12), c + Vector3(0, 1.15, 0), wood)
	for s in [-1.0, 1.0]:
		_box(Vector3(w * 2, 0.1, 0.08), Vector3(0, H + 1.0, w * 0.95 * s), wood)
		_box(Vector3(0.08, 0.1, w * 2), Vector3(w * 0.95 * s, H + 1.0, 0), wood)
		_box(Vector3(w * 2, 0.5, 0.05), Vector3(0, H + 0.4, -w * 0.95 * s), red if s > 0 else wood)  # half walls
	_cyl(w * 1.65, 1.2, Vector3(0, H + 2.9, 0), roof, 4, 0.05).rotation.y = PI / 4.0
	_box(Vector3(0.22, 0.32, 0.22), Vector3(0.6, H + 1.95, w * 0.85), window_mat)  # lantern
	_box(Vector3(0.28, 0.06, 0.28), Vector3(0.6, H + 2.14, w * 0.85), iron)
	for x in [-0.28, 0.28]:  # ladder up the front
		_beam(Vector3(x, 0, LOW + 0.7), Vector3(x, H + 0.1, TOP + 0.38), 0.07, wood)
	for k in int(H / 0.4):
		var t := (k + 0.5) / (H / 0.4)
		_box(Vector3(0.56, 0.05, 0.05), Vector3(0, t * H, lerpf(LOW + 0.7, TOP + 0.38, t)), wood)
	MeshMerge.boxes(self)
