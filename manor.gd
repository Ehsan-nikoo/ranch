## The owner's own house, there from the first day of every ranch. Five levels, each a different house:
## a log cabin, a bigger cabin with a porch and a lean-to, a two-storey farmhouse, the farmhouse with a
## wing and a balcony, and a mansion with wings, a round tower and columns at the door. Front faces +Z.
## Tapping it opens the owner's board (see BuildingUI): the strongbox, the ledger, the family wall, buying dollars.
class_name Manor
extends Building

const NAMES := ["کلبه‌ی چوبی", "خونه‌ی چوبی", "خونه‌ی دوطبقه", "خونه‌ی بزرگ", "عمارت"]
const WORTH := 6000             # what the build time of an upgrade is reckoned on (it's never bought)
const SPOT := Vector3(-24, 0, 20)  # where a ranch's manor stands at first
const BOX := [40, 70, 110, 160, 230]  # dollars that go into the strongbox each morning, by level
const BOX_DAYS := 7             # the strongbox holds this many mornings; then it's full

static var _log_mat: StandardMaterial3D
static var _slate_mat: StandardMaterial3D

## Dollars waiting in the strongbox (kept in the save with the other ranch numbers).
static var box := 0


func upgrades() -> Array:
	return [4000, 9000, 18000, 35000]


func upgrade_text() -> String:
	return ["یه خونه‌ی چوبی بزرگ‌تر با ایوون: صندوق پرتر می‌شه",
		"خونه‌ی دوطبقه: صندوق پرتر و هر روز صبح یه کم شهرت",
		"خونه‌ی بزرگ با بالکن: مزد کارگرها ۱۰ درصد کمتر",
		"عمارت با برج: گاوها ۵ درصد گرون‌تر فروش می‌رن"][mini(level - 1, 3)]


## The good things the house gives at level `lv`, one per line.
static func perks(lv: int) -> Array:
	var p := ["هر روز صبح %s دلار میاد تو صندوق" % UiTheme.fa(BOX[lv - 1])]
	if lv >= 3:
		p.append("هر روز صبح یه کم شهرت")
	if lv >= 4:
		p.append("مزد کارگرها ۱۰ درصد کمتر")
	if lv >= 5:
		p.append("گاوها ۵ درصد گرون‌تر فروش می‌رن")
	return p


## Reputation the house brings each morning: a bit from the two-storey house on.
static func daily_rep(world: Node) -> float:
	var lv := level_in(world)
	return 0.0 if lv < 3 else (0.5 if lv < 5 else 1.0)


## Level of the ranch's manor (1 when, somehow, there's none).
static func level_in(world: Node) -> int:
	return maxi(1, Building.best_level(world, Manor))


func _foot() -> Rect2:
	match level:
		1: return Rect2(-3.6, -2.9, 7.6, 6.7)
		2: return Rect2(-6.6, -3.1, 11.0, 8.0)
		3: return Rect2(-4.2, -3.3, 8.4, 8.9)
		4: return Rect2(-4.2, -3.3, 11.9, 8.9)
	return Rect2(-8.0, -3.3, 16.0, 9.4)


func _ready() -> void:
	if _log_mat == null:
		_log_mat = wood.duplicate()
		_log_mat.albedo_color = Color(0.45, 0.31, 0.2)
		_slate_mat = roof.duplicate()
		_slate_mat.albedo_color = Color(0.2, 0.24, 0.31)
	if level >= 4:  # the big houses get a dark slate-blue roof
		roof = _slate_mat
	match level:
		1: _cabin(3.0, 2.4, 2.5, 4.0, false)
		2: _cabin(3.4, 2.6, 2.6, 4.3, true)
		3: _farmhouse(false)
		4: _farmhouse(true)
		_: _mansion()
	MeshMerge.boxes(self)


# ---------- levels 1 and 2: log cabins ----------

func _cabin(w: float, d: float, e: float, r: float, big: bool) -> void:
	_gabled(w, d, e, r, 0.45, wood)
	_box(Vector3(w * 2 + 0.4, 0.35, d * 2 + 0.4), Vector3(0, 0.1, 0), stone)
	_logs(w, d, e)
	# door and windows
	_box(Vector3(1.0, 2.0, 0.08), Vector3(0, 1.15, d + 0.2), red)
	_box(Vector3(1.2, 0.14, 0.12), Vector3(0, 2.2, d + 0.2), _log_mat)
	for x in [-w * 0.6, w * 0.6]:
		_window(Vector3(x, 1.45, d + 0.16), Vector3(0, 0, 1), _log_mat, red if big else null)
	_window(Vector3(-w - 0.16, 1.45, 0), Vector3(-1, 0, 0), _log_mat)
	_window(Vector3(0, 1.45, -d - 0.16), Vector3(0, 0, -1), _log_mat)
	# stone chimney up the +x gable
	_box(Vector3(0.6, 0.9, 1.1), Vector3(w + 0.45, 0.45, 0), stone)
	_box(Vector3(0.75, r + 0.6, 0.75), Vector3(w + 0.45, (r + 0.6) * 0.5, 0), stone)
	_box(Vector3(0.9, 0.12, 0.9), Vector3(w + 0.45, r + 0.62, 0), iron)
	if not big:  # a little stoop and a bench
		_box(Vector3(1.8, 0.3, 1.0), Vector3(0, 0.15, d + 0.75), _log_mat)
		_box(Vector3(1.0, 0.08, 0.3), Vector3(-w * 0.6, 0.45, d + 0.55), wood)
		return
	# a lean-to room on the -x side
	var lean := Building.new()
	lean.position = Vector3(-w - 1.5, 0, -0.3)
	add_child(lean)
	lean.scale = Vector3.ONE
	lean._gabled(1.4, 1.9, 2.2, 3.1, 0.3, _log_mat)
	lean._window(Vector3(0, 1.3, 1.92), Vector3(0, 0, 1), wood, red)
	MeshMerge.boxes(lean)
	# a porch along the front with a shed roof on posts
	var z1 := d + 1.8
	_box(Vector3(w * 2, 0.3, 1.8), Vector3(0, 0.15, d + 0.9), wood)
	_box(Vector3(1.4, 0.15, 0.4), Vector3(0, 0.08, z1 + 0.2), wood)
	for x in [-w + 0.2, -0.9, 0.9, w - 0.2]:
		_box(Vector3(0.2, 2.2, 0.2), Vector3(x, 1.4, z1 - 0.15), _log_mat)
	var st := _st()
	_slab(st, Vector3(0, e - 0.1, d + 0.1), Vector3(0, 2.35, z1 + 0.25), Vector3(w + 0.2, 0, 0), roof.get_meta("tile"))
	_commit(st, roof)
	for span in [[-w + 0.2, -0.9], [0.9, w - 0.2]]:
		var cx: float = (span[0] + span[1]) * 0.5
		_box(Vector3(span[1] - span[0], 0.1, 0.1), Vector3(cx, 1.05, z1 - 0.15), _log_mat)
	_box(Vector3(0.5, 0.5, 0.5), Vector3(-w + 0.6, 0.55, d + 0.5), wood)  # a barrel-ish crate


## Round logs laid up the four walls, ends crossing past the corners.
func _logs(w: float, d: float, e: float) -> void:
	var n := int(e / 0.3)
	for i in n:
		var y := 0.3 + i * 0.3
		for s in [-1.0, 1.0]:
			_box(Vector3(w * 2 + 0.7, 0.27, 0.3), Vector3(0, y, d * s + 0.08 * s), _log_mat)
			_box(Vector3(0.3, 0.27, d * 2 + 0.7), Vector3(w * s + 0.08 * s, y + 0.15, 0), _log_mat)


# ---------- levels 3 and 4: the farmhouse ----------

const FW := 3.6
const FD := 2.8
const FE := 4.8
const FR := 6.6


func _farmhouse(big: bool) -> void:
	_gabled(FW, FD, FE, FR, 0.4, siding, true)
	_box(Vector3(FW * 2 + 0.3, 0.45, FD * 2 + 0.3), Vector3(0, 0.15, 0), stone)
	_corners(FW, FD, FE)
	_box(Vector3(FW * 2 + 0.1, 0.14, FD * 2 + 0.1), Vector3(0, 2.55, 0), white)  # band between the floors
	_front(FW, FD, false)
	for y in [1.6, 3.7]:
		_window(Vector3(-FW, y, 0), Vector3(-1, 0, 0), null, red)
		if not big:  # the wing covers that side
			_window(Vector3(FW, y, 0), Vector3(1, 0, 0), null, red)
		for x in [-1.8, 1.8]:
			_window(Vector3(x, y, -FD), Vector3(0, 0, -1), null, red)
	_chimney(Vector3(-1.6, 0, -1.0), FR + 0.8)
	_porch(-FW, FW, FD, 2.0, big)
	if big:
		var wg := _side(Vector3(FW + 1.9, 0, -0.4), 1.9, 2.3, 3.0, 4.4)
		wg._window(Vector3(0, 1.6, 2.3), Vector3(0, 0, 1), null, red)
		wg._window(Vector3(1.9, 1.6, 0), Vector3(1, 0, 0), null, red)
		wg._box(Vector3(0.7, 5.3, 0.7), Vector3(0.9, 2.65, -1.2), stone)
		MeshMerge.boxes(wg)


## Two-storey front: a door with a light over it and two rows of shuttered windows.
func _front(w: float, d: float, grand: bool) -> void:
	var z := d + 0.03
	_box(Vector3(1.4, 2.45, 0.06), Vector3(0, 1.45, z), white)
	_box(Vector3(1.1, 2.2, 0.08), Vector3(0, 1.35, z + 0.02), red)
	_box(Vector3(1.0, 0.32, 0.09), Vector3(0, 2.65, z), window_mat)
	for x in [-w * 0.6, w * 0.6]:
		_window(Vector3(x, 1.6, d), Vector3(0, 0, 1), null, red)
	for x in ([-w * 0.6, 0.0, w * 0.6] if not grand else [-w * 0.6, w * 0.6]):
		_window(Vector3(x, 3.7, d), Vector3(0, 0, 1), null, red)


func _corners(w: float, d: float, e: float) -> void:
	for x in [-w, w]:
		for z in [-d, d]:
			_box(Vector3(0.18, e - 0.3, 0.18), Vector3(x, e * 0.5 + 0.15, z), white)


func _chimney(at: Vector3, top: float) -> void:
	_box(Vector3(0.8, top, 0.8), at + Vector3(0, top * 0.5, 0), stone)
	_box(Vector3(0.95, 0.12, 0.95), at + Vector3(0, top + 0.05, 0), iron)


## A deck from x0 to x1 in front of the wall at z = d, `deep` deep, with posts, rails and a roof;
## `balcony` puts railings on the porch roof (made flat for it).
func _porch(x0: float, x1: float, d: float, deep: float, balcony: bool) -> void:
	var z1 := d + deep
	var cx := (x0 + x1) * 0.5
	var w := x1 - x0
	_box(Vector3(w, 0.45, deep), Vector3(cx, 0.22, d + deep * 0.5), wood)
	for k in 2:
		_box(Vector3(1.6, 0.15, 0.35), Vector3(0, 0.3 - k * 0.15, z1 + 0.17 + k * 0.33), wood)
	var posts := [x0 + 0.2, -0.9, 0.9, x1 - 0.2]
	for x in posts:
		_box(Vector3(0.18, 2.3, 0.18), Vector3(x, 1.6, z1 - 0.15), white)
	for span in [[x0 + 0.2, -0.9], [0.9, x1 - 0.2]]:
		var c: float = (span[0] + span[1]) * 0.5
		var sw: float = span[1] - span[0]
		_box(Vector3(sw, 0.08, 0.08), Vector3(c, 1.3, z1 - 0.15), white)
		for k in 6:
			_box(Vector3(0.05, 0.8, 0.05), Vector3(span[0] + sw * (k + 1) / 7.0, 0.88, z1 - 0.15), white)
	if balcony:  # flat roof with a railed balcony on it, reached from the upstairs door
		_box(Vector3(w + 0.3, 0.2, deep + 0.2), Vector3(cx, 2.85, d + deep * 0.5), white)
		_box(Vector3(w + 0.1, 0.05, deep), Vector3(cx, 2.97, d + deep * 0.5), wood)
		for x in [x0 + 0.1, x1 - 0.1]:
			_box(Vector3(0.08, 0.08, deep), Vector3(x, 3.65, d + deep * 0.5), white)
		_box(Vector3(w, 0.08, 0.08), Vector3(cx, 3.65, z1 - 0.05), white)
		for k in 15:
			_box(Vector3(0.05, 0.65, 0.05), Vector3(x0 + w * (k + 0.5) / 15.0, 3.3, z1 - 0.05), white)
		return
	var st := _st()
	_slab(st, Vector3(0, 2.95, d + 0.05), Vector3(0, 2.55, z1 + 0.35), Vector3(w * 0.5 + 0.3, 0, 0), roof.get_meta("tile"))
	_commit(st, roof)
	_box(Vector3(w + 0.6, 0.2, 0.16), Vector3(cx, 2.75, z1 - 0.15), white)


## A clapboard wing like Building._wing, but roofed like the house it's part of.
func _side(at: Vector3, w: float, d: float, eave_h: float, ridge: float) -> Building:
	var b := Building.new()
	b.position = at
	add_child(b)
	b.scale = Vector3.ONE
	b.roof = roof
	b._gabled(w, d, eave_h, ridge, 0.35, siding, true)
	b._box(Vector3(w * 2 + 0.25, 0.35, d * 2 + 0.25), Vector3(0, 0.1, 0), stone)
	for x in [-w, w]:
		for z in [-d, d]:
			b._box(Vector3(0.16, eave_h, 0.16), Vector3(x, eave_h * 0.5, z), white)
	return b


# ---------- level 5: the mansion ----------

func _mansion() -> void:
	var w := FW
	var d := FD
	_gabled(w, d, FE, FR + 0.3, 0.4, siding, true)
	_box(Vector3(w * 2 + 0.3, 0.5, d * 2 + 0.3), Vector3(0, 0.18, 0), stone)
	_corners(w, d, FE)
	_box(Vector3(w * 2 + 0.1, 0.14, d * 2 + 0.1), Vector3(0, 2.55, 0), white)
	_front(w, d, true)
	for y in [1.6, 3.7]:
		for x in [-1.8, 1.8]:
			_window(Vector3(x, y, -d), Vector3(0, 0, -1), null, red)
	_chimney(Vector3(-1.4, 0, -1.0), FR + 1.1)
	_chimney(Vector3(1.4, 0, -1.0), FR + 1.1)
	# two-storey wings both sides
	for s in [-1.0, 1.0]:
		var wg := _side(Vector3((w + 2.0) * s, 0, -0.3), 2.0, 2.4, 4.0, 5.6)
		for y in [1.5, 3.2]:
			wg._window(Vector3(-0.8, y, 2.4), Vector3(0, 0, 1), null, red)
			wg._window(Vector3(0.8, y, 2.4), Vector3(0, 0, 1), null, red)
			wg._window(Vector3(2.0 * s, y, 0), Vector3(s, 0, 0), null, red)
		wg._box(Vector3(4.1, 0.12, 4.9), Vector3(0, 2.2, 0), white)
		MeshMerge.boxes(wg)
	# round tower on the front corner, with a pointed roof and a flag
	var tw := Building.new()
	tw.position = Vector3(-w - 0.2, 0, d + 0.1)
	add_child(tw)
	tw.scale = Vector3.ONE
	tw.roof = roof
	tw._cyl(1.35, 0.5, Vector3(0, 0.2, 0), stone, 8)
	tw._cyl(1.25, 7.4, Vector3(0, 3.7, 0), siding, 8)
	tw._cyl(1.38, 0.16, Vector3(0, 2.6, 0), white, 8)
	tw._cyl(1.4, 0.2, Vector3(0, 7.45, 0), white, 8)
	tw._cyl(1.6, 3.0, Vector3(0, 9.05, 0), roof, 8, 0.04)
	tw._box(Vector3(0.05, 1.6, 0.05), Vector3(0, 11.3, 0), iron)
	for k in 4:
		var a := TAU * (k + 0.5) / 8.0 + PI * 0.25
		var n := Vector3(sin(a), 0, cos(a))
		tw._box(Vector3(0.6, 1.0, 0.06), n * 1.24 + Vector3(0, 4.0, 0), window_mat, Vector3(0, a, 0))
		tw._box(Vector3(0.6, 1.0, 0.06), n * 1.24 + Vector3(0, 6.1, 0), window_mat, Vector3(0, a, 0))
	MeshMerge.boxes(tw)
	_flag = Node3D.new()  # under its own node so the merge leaves it free to wave
	_flag.position = tw.position + Vector3(0, 11.75, 0)
	add_child(_flag)
	var cloth := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.9, 0.55, 0.03)
	cloth.mesh = fm
	cloth.material_override = red
	cloth.position = Vector3(0.47, 0, 0)
	_flag.add_child(cloth)
	# columns and a pediment over the door
	var z1 := d + 2.0
	_box(Vector3(4.2, 0.45, 2.0), Vector3(0.6, 0.22, d + 1.0), stone)
	for k in 3:
		_box(Vector3(2.2, 0.15, 0.35), Vector3(0.6, 0.3 - k * 0.1, z1 + 0.17 + k * 0.3), stone)
	for x in [-1.2, -0.1, 1.3, 2.4]:
		_cyl(0.18, 4.4, Vector3(x, 2.65, z1 - 0.25), white, 12)
		_box(Vector3(0.48, 0.2, 0.48), Vector3(x, 0.55, z1 - 0.25), white)
		_box(Vector3(0.5, 0.2, 0.5), Vector3(x, 4.85, z1 - 0.25), white)
	_box(Vector3(4.4, 0.4, 2.3), Vector3(0.6, 5.1, d + 1.05), white)
	var st := _st()
	var pz := z1 + 0.05
	_poly(st, [Vector3(-1.6, 5.3, pz), Vector3(2.8, 5.3, pz), Vector3(0.6, 6.5, pz)], Vector3(0, 0, 1), Vector3.RIGHT, Vector3.UP, siding.get_meta("tile"))
	_commit(st, white)
	for side in [-1.0, 1.0]:
		st = _st()
		_slab(st, Vector3(0.6, 6.5, d + 1.1), Vector3(0.6 + 2.35 * side, 5.3, d + 1.1), Vector3(0, 0, 1.15), roof.get_meta("tile"), false)
		_commit(st, roof)
	# low hedges and lamps along the front
	for x in [-6.6, 6.6]:
		_box(Vector3(2.4, 0.7, 0.7), Vector3(x, 0.35, 2.9), _hedge())
	for x in [-1.9, 3.1]:
		_box(Vector3(0.1, 1.6, 0.1), Vector3(x, 0.8, z1 + 1.1), iron)
		_box(Vector3(0.3, 0.35, 0.3), Vector3(x, 1.75, z1 + 1.1), window_mat)


static var _hedge_mat: StandardMaterial3D


func _hedge() -> StandardMaterial3D:
	if _hedge_mat == null:
		_hedge_mat = Building._plain(Color(0.16, 0.28, 0.12), 1.0)
	return _hedge_mat


var _flag: Node3D


## Waves the mansion's flag in the wind.
func _process(_delta: float) -> void:
	if _flag == null:
		set_process(false)
		return
	var t := Time.get_ticks_msec() * 0.001
	_flag.rotation = Vector3(0, sin(t * 3.0) * 0.25, sin(t * 4.7) * 0.05)
