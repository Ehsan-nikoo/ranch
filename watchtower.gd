## Lookout tower: four tall timber legs braced with X's, a railed platform under a little pyramid
## roof, a ladder and a lantern that glows at night. Rustlers are seen coming. Ladder faces +Z.
class_name Watchtower
extends Building

const H := 7.5      # platform height
const LOW := 1.6    # half width at the ground
const TOP := 1.15   # half width at the platform


func upgrades() -> Array:
	return [1500, 3000]


func upgrade_text() -> String:
	return "دزدها رو زودتر می‌بینن: کمتر گاو می‌برن و راحت‌تر گیر می‌افتن"


func _foot() -> Rect2:
	var x1 := LOW + 0.4 + (3.2 if level >= 3 else 0.0)  # the guard hut at level 3
	return Rect2(-LOW - 0.4, -LOW - 0.4, x1 + LOW + 0.4, (LOW + 0.4) * 2 + 0.8)


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
	if level >= 2:  # an alarm bell hung under the roof, its rope down to the platform
		_box(Vector3(0.1, 0.1, w * 1.9), Vector3(0, H + 2.25, 0), wood)
		_cyl(0.32, 0.5, Vector3(0, H + 1.95, 0), _plain(Color(0.62, 0.48, 0.22), 0.35, 0.8), 14, 0.18)
		_box(Vector3(0.02, 0.9, 0.02), Vector3(0.1, H + 1.3, 0), _straw())
	if level >= 3:  # a flag on the peak and a little guard hut at the foot
		_beam(Vector3(0, H + 3.4, 0), Vector3(0, H + 5.6, 0), 0.05, iron)
		_box(Vector3(1.1, 0.65, 0.03), Vector3(0.57, H + 5.25, 0), red)
		var hut := _wing(Vector3(LOW + 2.0, 0, 0), 1.2, 1.3, 2.3, 3.2, wood)
		hut._window(Vector3(0, 1.4, 1.3), Vector3(0, 0, 1), null, red)
		MeshMerge.boxes(hut)
	MeshMerge.boxes(self)
