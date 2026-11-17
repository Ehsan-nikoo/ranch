## Ranch land: a GRID x GRID map of PLOT-meter plots inside the ranch fence. The four middle plots
## come with the ranch; the rest are locked until bought, and each new plot must border one you own.
## Cows only graze, and buildings only go up, on owned land. Locked plots look darker and have a
## «for sale» sign; the ground and grass shaders read `texture` to shade them.
class_name Land
extends Node3D

signal changed

const GRID := 4
const PLOT := 48.0
const HALF := GRID * PLOT * 0.5   # fence runs at +-HALF
const PRICE := 2500               # first plot; each later one costs half that more

var owned := PackedByteArray()
var texture: ImageTexture
var _signs := {}                  # plot index -> sign node


func _init() -> void:
	owned.resize(GRID * GRID)
	for i in [5, 6, 9, 10]:       # the middle 2x2
		owned[i] = 1
	texture = ImageTexture.create_from_image(_image())


func _ready() -> void:
	_refresh()


func index_at(p: Vector3) -> int:
	var x := floori((p.x + HALF) / PLOT)
	var z := floori((p.z + HALF) / PLOT)
	if x < 0 or z < 0 or x >= GRID or z >= GRID:
		return -1
	return z * GRID + x


func is_open(p: Vector3) -> bool:
	var i := index_at(p)
	return i >= 0 and owned[i] == 1


## Whole world rect on owned land (rects are small next to plots, so the corners are enough).
func rect_open(r: Rect2) -> bool:
	for c in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y)]:
		if not is_open(Vector3(c.x, 0, c.y)):
			return false
	return true


func center(i: int) -> Vector3:
	return Vector3(-HALF + (i % GRID + 0.5) * PLOT, 0, -HALF + (i / GRID + 0.5) * PLOT)


func bought() -> int:
	return Array(owned).count(1) - 4


func price() -> int:
	return PRICE + PRICE / 2 * bought()


## A locked plot that shares a side with an owned one.
func can_buy(i: int) -> bool:
	if owned[i] == 1:
		return false
	var x := i % GRID
	var z := i / GRID
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + d.x
		var nz: int = z + d.y
		if nx >= 0 and nz >= 0 and nx < GRID and nz < GRID and owned[nz * GRID + nx] == 1:
			return true
	return false


func unlock(i: int) -> void:
	owned[i] = 1
	_refresh()
	changed.emit()


func _image() -> Image:
	var b := PackedByteArray()
	for v in owned:
		b.append(v * 255)
	return Image.create_from_data(GRID, GRID, false, Image.FORMAT_R8, b)


func _refresh() -> void:
	texture.update(_image())
	for i in GRID * GRID:
		if owned[i] == 0 and not _signs.has(i):
			var s := ForSaleSign.new()
			s.position = center(i)
			s.scale = Vector3.ONE * 1.8  # readable from the game camera's distance
			add_child(s)
			_signs[i] = s
		elif owned[i] == 1 and _signs.has(i):
			_signs[i].queue_free()
			_signs.erase(i)


func to_save() -> Array:
	return Array(owned)


func from_save(a: Array) -> void:
	if a.size() == GRID * GRID:
		for i in a.size():
			owned[i] = int(a[i])
		if is_inside_tree():
			_refresh()
		else:
			texture.update(_image())
