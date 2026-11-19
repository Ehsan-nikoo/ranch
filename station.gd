## Railroad cattle station: an ochre depot with a deep platform roof, a stretch of track with a red
## stock car waiting, a water tower for the engines and a loading pen with a ramp. Cattle go to the
## city by train: better prices and more buyers. Platform faces +Z.
class_name Station
extends Building

const W := 4.5
const D := 2.5
const EAVE := 3.4
const RIDGE := 4.9
const TRACK := 7.0   # track centre line, +z from the depot centre (clear of the deep eaves)
const HALF := 12.5   # half length of the track

static var _paint: StandardMaterial3D


func upgrades() -> Array:
	return [6000, 12000]


func upgrade_text() -> String:
	return "قطار بیشتری میاد: هر فروش ۵ درصد دیگه گرون‌تر"


## Extra share on every sale with the station: 10%, then 15%, then 20%.
func bonus() -> float:
	return 0.1 + 0.05 * (level - 1)


func _foot() -> Rect2:
	return Rect2(-HALF, -D - 0.5, HALF * 2, D + 0.5 + TRACK + 1.8)


func _ready() -> void:
	if _paint == null:
		_paint = siding.duplicate()
		_paint.albedo_color = Color(0.86, 0.66, 0.36)
	_gabled(W, D, EAVE, RIDGE, 1.6, _paint, true)  # deep eaves shade the platform
	_box(Vector3(W * 2 + 0.3, 0.4, D * 2 + 0.3), Vector3(0, 0.15, 0), stone)
	for x in [-W, W]:
		for z in [-D, D]:
			_box(Vector3(0.16, EAVE, 0.16), Vector3(x, EAVE * 0.5, z), red)
	_box(Vector3(1.2, 2.2, 0.08), Vector3(-1.2, 1.1, D + 0.03), red)  # door
	for x in [1.0, 2.9]:
		_window(Vector3(x, 1.8, D), Vector3(0, 0, 1), red)
	_box(Vector3(3.0, 0.6, 0.08), Vector3(0, EAVE - 0.4, D + 0.08), white)  # name board
	# platform from the depot to the track
	_box(Vector3(HALF * 1.4, 0.55, TRACK - D - 0.9), Vector3(0, 0.27, (D + TRACK - 0.9) * 0.5), wood)
	# track: ties and two rails
	var tie := _plain(Color(0.25, 0.19, 0.14), 1.0)
	_box(Vector3(HALF * 2, 0.12, 2.6), Vector3(0, 0.06, TRACK), stone)  # ballast
	var tx := -HALF + 0.3
	while tx < HALF:
		_box(Vector3(0.24, 0.12, 2.3), Vector3(tx, 0.17, TRACK), tie)
		tx += 0.7
	for s in [-0.72, 0.72]:
		_box(Vector3(HALF * 2, 0.14, 0.08), Vector3(0, 0.3, TRACK + s), steel)
	_stock_car(Vector3(6.2, 0, TRACK))
	_water_tower(Vector3(-HALF + 2.2, 0, TRACK - 3.0))
	if level >= 2:  # a freight shed beside the depot
		var shed := _wing(Vector3(-W - 2.9, 0, 0.0), 2.4, 2.0, 2.9, 4.1, red)
		shed._x_panel(0, 1.2, 1.8, 2.2, 2.05)
		MeshMerge.boxes(shed)
	if level >= 3:  # a second stock car and a loading pen with a ramp at the far end
		_stock_car(Vector3(-3.6, 0, TRACK))
		var pc := Vector3(HALF - 2.0, 0, TRACK - 3.4)
		_box(Vector3(3.4, 0.05, 2.4), pc + Vector3(0, 0.025, 0), _mud())
		_pen(pc, 1.7, 1.2, white, 0.0, 1.4)
		_beam(pc + Vector3(0, 0.1, 1.2), pc + Vector3(0, 1.05, 2.5), 0.9, wood)  # ramp up to the car door
	MeshMerge.boxes(self)


## A slatted red cattle car on two bogies.
func _stock_car(at: Vector3) -> void:
	var cl := 8.0
	_box(Vector3(cl, 0.25, 2.5), at + Vector3(0, 1.05, 0), iron)  # frame
	for k in 9:  # slatted sides: boards with gaps
		_box(Vector3(cl, 0.16, 2.45), at + Vector3(0, 1.4 + k * 0.26, 0), red)
	for k in 7:
		var bx := lerpf(-cl * 0.5 + 0.1, cl * 0.5 - 0.1, k / 6.0)
		_box(Vector3(0.12, 2.4, 2.56), at + Vector3(bx, 2.3, 0), red)
	_box(Vector3(cl + 0.2, 0.15, 2.7), at + Vector3(0, 3.55, 0), roof)
	_box(Vector3(1.6, 2.0, 0.06), at + Vector3(0, 2.3, -1.3), iron)  # sliding door
	for bx in [-2.8, 2.8]:
		for dx in [-0.6, 0.6]:
			for s in [-0.72, 0.72]:
				_cyl(0.42, 0.12, at + Vector3(bx + dx, 0.62, s), iron, 12).rotation.x = PI * 0.5


## Wooden tank on four legs with a spout swung toward the track.
func _water_tower(at: Vector3) -> void:
	for p in [Vector2(-1.1, -1.1), Vector2(1.1, -1.1), Vector2(-1.1, 1.1), Vector2(1.1, 1.1)]:
		_beam(at + Vector3(p.x * 1.3, 0, p.y * 1.3), at + Vector3(p.x, 4.2, p.y), 0.2, wood)
	_box(Vector3(2.6, 0.2, 2.6), at + Vector3(0, 4.2, 0), wood)
	_cyl(1.5, 2.4, at + Vector3(0, 5.5, 0), wood, 16)
	for k in 3:
		_cyl(1.53, 0.07, at + Vector3(0, 4.6 + k * 0.8, 0), iron, 16)
	_cyl(1.7, 0.9, at + Vector3(0, 7.15, 0), roof, 16, 0.08)
	_beam(at + Vector3(0, 4.8, 1.5), at + Vector3(0, 4.0, 3.0), 0.2, iron)  # spout
