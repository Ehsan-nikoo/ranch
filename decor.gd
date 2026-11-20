## Ranch decoration: small things put round the ranch just because they look nice (flowers, a tree, a
## lantern, an old covered wagon, a well, a pool with a fountain...), a sign with the ranch's own name,
## and the keepsakes won at the festivals. Each piece adds to the ranch's beauty, which brings a little
## fame every morning and more guests to the café. The same kind again counts for less, so a ranch
## full of different things is the prettiest. Pieces go down at once, with no building work.
class_name Decor
extends Building

# id: name, price, beauty, what it is, half size of the footprint
const KINDS := {
	cactus = ["کاکتوس", 50, 2.0, "کاکتوس بزرگ بیابونی. آب نمی‌خواد و همیشه سبزه.", Vector2(0.8, 0.8)],
	barrels = ["بشکه‌ها", 60, 2.0, "چند تا بشکه‌ی چوبی کنار هم.", Vector2(1.0, 0.8)],
	bales = ["کپه‌ی کاه", 60, 2.0, "چند تا بسته کاه روی هم، با یه کدو تنبل.", Vector2(1.3, 0.7)],
	mailbox = ["صندوق نامه", 70, 3.0, "صندوق نامه‌ی دم در رنچ؛ نامه‌رسون هر هفته سر می‌زنه.", Vector2(0.5, 0.5)],
	wheel = ["چرخ گاری", 70, 3.0, "یه چرخ گاری قدیمی که به یه تیکه نرده تکیه داده.", Vector2(1.4, 0.6)],
	flowers = ["باغچه‌ی گل", 80, 4.0, "یه باغچه‌ی چوبی پر از گل‌های رنگارنگ.", Vector2(1.3, 0.7)],
	bench = ["نیمکت", 120, 4.0, "یه نیمکت چوبی برای خستگی در کردن.", Vector2(1.2, 0.6)],
	scarecrow = ["مترسک", 110, 5.0, "مترسک با کلاه حصیری که کلاغ‌ها رو می‌ترسونه.", Vector2(0.9, 0.5)],
	lantern = ["فانوس", 130, 5.0, "تیرک چوبی با یه فانوس. شب‌ها روشن می‌شه.", Vector2(0.6, 0.5)],
	tree = ["درخت سایه‌دار", 180, 6.0, "یه درخت بزرگ و سرسبز.", Vector2(1.2, 1.2)],
	campfire = ["آتیش‌گاه", 160, 6.0, "آتیش وسط سنگ‌چین، با کنده‌هایی برای نشستن دورش.", Vector2(1.8, 1.8)],
	wagon = ["گاری سرپوشیده", 400, 8.0, "یه گاری قدیمی با سقف برزنتی، یادگار اولین کسایی که اومدن این دشت.", Vector2(2.6, 1.2)],
	well = ["چاه آب", 450, 9.0, "چاه سنگی با سقف چوبی و سطل.", Vector2(1.3, 1.3)],
	fountain = ["حوض و فواره", 700, 12.0, "حوض سنگی با کاشی فیروزه‌ای و یه فواره وسطش.", Vector2(2.2, 2.2)],
	sign = ["تابلوی اسم رنچ", 250, 10.0, "یه تابلوی بزرگ با اسم رنچت. فقط یکی می‌شه گذاشت.", Vector2(2.2, 0.5)],
}
const ORDER := ["flowers", "tree", "bench", "lantern", "sign", "fountain", "well", "wagon", "campfire", "scarecrow", "wheel", "mailbox", "bales", "barrels", "cactus"]
const ONLY_ONE := ["sign"]
# the festivals' keepsakes, kind "k_" + the festival's id (Festivals.LIST: keep): free, one of each, once
# that festival's prize has been won
const KEEP_BEAUTY := 12.0
const KEEP_HALF := {nowruz = Vector2(0.8, 0.8), coach = Vector2(1.0, 0.5), tirgan = Vector2(1.0, 0.8), statefair = Vector2(0.6, 0.5),
	mehregan = Vector2(0.9, 0.9), campfire = Vector2(1.0, 0.5), yalda = Vector2(0.9, 0.6), sadeh = Vector2(1.0, 1.0)}
const MAX_BEAUTY := 100.0      # beauty past this brings nothing more
const REP_PER := 25.0          # a point of fame each morning for every this much beauty

static var ranch_name := ""    # the player's name for the ranch (on the sign); "" = not named yet
static var _dm := {}

var kind := "flowers"


## name, price, beauty, about, half, keep (a festival keepsake) for any kind of piece.
static func info(k: String) -> Dictionary:
	if KINDS.has(k):
		var e: Array = KINDS[k]
		return {name = e[0], price = e[1], beauty = e[2], about = e[3], half = e[4], keep = false}
	for f in Festivals.LIST:
		if "k_" + f.id == k:
			return {name = f.keep, price = 0, beauty = KEEP_BEAUTY, about = "یادگاری «%s». مال خودته و هر جا بخوای می‌ذاریش." % f.name,
				half = KEEP_HALF.get(f.id, Vector2(0.8, 0.8)), keep = true, fest = f.id}
	return {name = "تزئینی", price = 0, beauty = 0.0, about = "", half = Vector2(0.5, 0.5), keep = false}


## Name shown for the ranch: what the player called it, or a plain default.
static func shown_name() -> String:
	return ranch_name if ranch_name != "" else "رنچ ما"


static func pieces(world: Node) -> Array:
	return world.get_children().filter(func(n): return n is Decor and not n.has_node("Marker"))


static func count(world: Node, k: String) -> int:
	return pieces(world).filter(func(d): return d.kind == k).size()


## How pretty the ranch is: every piece's beauty, each more of the same kind worth less.
static func beauty(world: Node) -> float:
	var seen := {}
	var total := 0.0
	for d in pieces(world):
		var n: int = seen.get(d.kind, 0)
		total += float(info(d.kind).beauty) / (1.0 + 0.5 * n)
		seen[d.kind] = n + 1
	return total


## Beauty a piece of kind `k` adds now, the copies already standing counted.
static func adds(world: Node, k: String) -> float:
	return float(info(k).beauty) / (1.0 + 0.5 * count(world, k))


## Fame it brings each morning.
static func daily_rep(b: float) -> float:
	return minf(b, MAX_BEAUTY) / REP_PER


## The café's takings grow with it, up to half as much again.
static func cafe_mul(b: float) -> float:
	return 1.0 + minf(b, MAX_BEAUTY) / (MAX_BEAUTY * 2.0)


## Puts the new name on every sign on the ranch.
static func rename_signs(world: Node) -> void:
	for d in pieces(world):
		if d.kind == "sign":
			for l in d.find_children("*", "Label3D", false, false):
				_fit(l)


static func _fit(l: Label3D) -> void:
	l.text = shown_name()
	var w := l.font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_CENTER, -1, l.font_size).x
	l.pixel_size = minf(0.0075, 3.0 / maxf(w, 1.0))


func upgrades() -> Array:
	return []


func _foot() -> Rect2:
	var h: Vector2 = info(kind).half
	return Rect2(-h, h * 2.0)


func _ready() -> void:
	match kind:
		"cactus": _cactus()
		"barrels": _barrels()
		"bales": _bales()
		"mailbox": _mailbox()
		"wheel": _wheel_fence()
		"flowers": _flowers()
		"bench": _bench()
		"scarecrow": _scarecrow()
		"lantern": _lantern_post()
		"tree": _tree()
		"campfire": _campfire()
		"wagon": _wagon()
		"well": _well()
		"fountain": _fountain()
		"sign": _sign()
		"k_nowruz": _sabzeh()
		"k_coach": _horseshoe()
		"k_tirgan": _jars()
		"k_statefair": _rosette()
		"k_mehregan": _basket()
		"k_campfire": _lanterns()
		"k_yalda": _yalda()
		"k_sadeh": _torch()
	MeshMerge.boxes(self)


# ---------- materials and shapes ----------

static func _m(key: String, c: Color, rough := 0.85, glow := 0.0) -> StandardMaterial3D:
	if not _dm.has(key):
		var m := _plain(c, rough)
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = glow
		_dm[key] = m
	return _dm[key]


func _dark() -> StandardMaterial3D:
	return _m("dark", Color(0.27, 0.17, 0.1))


func _fire() -> StandardMaterial3D:
	return _m("fire", Color(1.0, 0.5, 0.12), 1.0, 2.6)


func _flame() -> StandardMaterial3D:
	return _m("flame", Color(1.0, 0.82, 0.3), 1.0, 3.0)


func _prim(mesh: PrimitiveMesh, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
	return mi


func _ball(r: float, pos: Vector3, m: Material, squash := 1.0) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0 * squash
	sm.radial_segments = 12
	sm.rings = 6
	return _prim(sm, pos, m)


## A cylinder lying along x (axis "x") or z (axis "z").
func _log(r: float, length: float, pos: Vector3, m: Material, axis := "x", segs := 10) -> MeshInstance3D:
	var mi := _cyl(r, length, pos, m, segs)
	mi.rotation = Vector3(0, 0, PI * 0.5) if axis == "x" else Vector3(PI * 0.5, 0, 0)
	return mi


## A wooden spoked wheel with an iron tyre. `side`: the wheel faces ±z (like a wagon's), else it
## faces ±x; `tilt` leans it back about the x axis.
func _wheel(c: Vector3, r: float, side := true, tilt := 0.0) -> void:
	var tm := TorusMesh.new()
	tm.inner_radius = r - 0.07
	tm.outer_radius = r
	tm.rings = 20
	tm.ring_segments = 6
	var face := Vector3(PI * 0.5 + tilt, 0, 0) if side else Vector3(0, 0, PI * 0.5)
	_prim(tm, c, iron, face)
	var rim := TorusMesh.new()
	rim.inner_radius = r - 0.14
	rim.outer_radius = r - 0.06
	rim.rings = 20
	rim.ring_segments = 6
	_prim(rim, c, _dark(), face)
	for i in 8:
		var a := PI * i / 8.0
		_box(Vector3(0.05, (r - 0.08) * 2.0, 0.05), c, _dark(), Vector3(tilt, 0, a) if side else Vector3(a, 0, 0))
	var hub := CylinderMesh.new()
	hub.top_radius = 0.09
	hub.bottom_radius = 0.09
	hub.height = 0.2
	hub.radial_segments = 8
	_prim(hub, c, _dark(), face)


## A little lantern hanging with its top at `top`; the glass glows at night like the windows.
func _lantern(top: Vector3) -> void:
	_box(Vector3(0.02, 0.14, 0.02), top + Vector3(0, -0.07, 0), iron)
	_cyl(0.15, 0.1, top + Vector3(0, -0.18, 0), iron, 8, 0.04)
	_box(Vector3(0.2, 0.28, 0.2), top + Vector3(0, -0.38, 0), window_mat)
	for p in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_box(Vector3(0.03, 0.3, 0.03), top + Vector3(p.x * 0.1, -0.38, p.y * 0.1), iron)
	_box(Vector3(0.24, 0.04, 0.24), top + Vector3(0, -0.54, 0), iron)


# ---------- the pieces ----------

func _cactus() -> void:
	var g := _m("cactus", Color(0.2, 0.36, 0.17))
	_cyl(0.6, 0.06, Vector3(0, 0.03, 0), _m("sand", Color(0.74, 0.62, 0.42), 1.0), 12)
	_cyl(0.22, 2.2, Vector3(0, 1.1, 0), g, 10, 0.2)
	_ball(0.2, Vector3(0, 2.2, 0), g)
	_log(0.13, 0.42, Vector3(-0.3, 0.95, 0), g)
	_cyl(0.13, 0.7, Vector3(-0.5, 1.3, 0), g, 8)
	_ball(0.13, Vector3(-0.5, 1.65, 0), g)
	_log(0.12, 0.36, Vector3(0.28, 1.3, 0), g)
	_cyl(0.12, 0.6, Vector3(0.45, 1.6, 0), g, 8)
	_ball(0.12, Vector3(0.45, 1.9, 0), g)
	_ball(0.07, Vector3(0, 2.38, 0), _m("pink", Color(0.85, 0.35, 0.5)))
	_box(Vector3(0.35, 0.22, 0.3), Vector3(0.45, 0.1, 0.35), stone, Vector3(0, 0.5, 0.1))
	_box(Vector3(0.25, 0.16, 0.2), Vector3(-0.4, 0.07, -0.3), stone, Vector3(0, 1.2, 0))


func _barrel(c: Vector3, r := 0.36, h := 0.9) -> void:
	_cyl(r, h, c + Vector3(0, h * 0.5, 0), _m("barrel", Color(0.45, 0.28, 0.14)), 12)
	for y in [0.12, h - 0.12]:
		_cyl(r + 0.015, 0.06, c + Vector3(0, y, 0), iron, 12)
	_cyl(r - 0.03, 0.02, c + Vector3(0, h + 0.005, 0), _dark(), 12)


func _barrels() -> void:
	_barrel(Vector3(-0.45, 0, -0.2))
	_barrel(Vector3(0.38, 0, -0.25))
	_barrel(Vector3(0.05, 0, 0.4), 0.3, 0.75)
	_box(Vector3(0.5, 0.3, 0.4), Vector3(0.65, 0.15, 0.45), wood, Vector3(0, 0.3, 0))


func _bales() -> void:
	var s := _straw()
	_box(Vector3(1.1, 0.5, 0.6), Vector3(-0.58, 0.25, 0), s)
	_box(Vector3(1.1, 0.5, 0.6), Vector3(0.58, 0.25, 0), s, Vector3(0, 0.06, 0))
	_box(Vector3(1.1, 0.5, 0.6), Vector3(0.05, 0.75, -0.02), s, Vector3(0, -0.1, 0))
	for x in [-0.58, 0.58]:
		for dz in [-0.12, 0.12]:
			_box(Vector3(1.12, 0.04, 0.03), Vector3(x, 0.25, dz), _dark())
	_ball(0.26, Vector3(0.55, 0.69, 0.05), _m("pumpkin", Color(0.85, 0.42, 0.08)), 0.75)
	_box(Vector3(0.04, 0.12, 0.04), Vector3(0.55, 0.92, 0.05), _m("stem", Color(0.25, 0.3, 0.12)))


func _mailbox() -> void:
	_box(Vector3(0.12, 1.1, 0.12), Vector3(0, 0.55, 0), wood)
	_box(Vector3(0.3, 0.25, 0.55), Vector3(0, 1.22, 0), _m("mailbox", Color(0.2, 0.3, 0.38), 0.6))
	_log(0.15, 0.55, Vector3(0, 1.34, 0), _m("mailbox", Color(0.2, 0.3, 0.38), 0.6), "z")
	_box(Vector3(0.03, 0.3, 0.06), Vector3(0.17, 1.4, -0.1), _m("flag", Color(0.75, 0.12, 0.08)))
	_box(Vector3(0.03, 0.1, 0.14), Vector3(0.17, 1.5, -0.03), _m("flag", Color(0.75, 0.12, 0.08)))


func _wheel_fence() -> void:
	for x in [-1.2, 1.2]:
		_box(Vector3(0.14, 1.2, 0.14), Vector3(x, 0.6, -0.3), wood)
	for y in [0.45, 0.95]:
		_box(Vector3(2.6, 0.12, 0.05), Vector3(0, y, -0.25), wood)
	_wheel(Vector3(0.1, 0.6, 0.05), 0.62, true, -0.22)
	_box(Vector3(0.6, 0.4, 0.5), Vector3(-0.9, 0.2, 0.15), _straw(), Vector3(0, 0.3, 0))


func _flowers() -> void:
	_box(Vector3(2.4, 0.4, 1.2), Vector3(0, 0.2, 0), wood)
	_box(Vector3(2.2, 0.06, 1.0), Vector3(0, 0.39, 0), _m("soil", Color(0.22, 0.14, 0.08), 1.0))
	var cols := [Color(0.82, 0.12, 0.1), Color(0.95, 0.78, 0.15), Color(0.55, 0.22, 0.65), Color(0.95, 0.93, 0.88), Color(0.95, 0.45, 0.6)]
	var stem := _m("leaf", Color(0.2, 0.4, 0.14))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 7:
		for j in 3:
			var p := Vector3(-0.95 + i * 0.32 + rng.randf_range(-0.06, 0.06), 0, -0.32 + j * 0.32 + rng.randf_range(-0.06, 0.06))
			var h := rng.randf_range(0.25, 0.45)
			_box(Vector3(0.03, h, 0.03), p + Vector3(0, 0.42 + h * 0.5, 0), stem)
			_ball(0.06, p + Vector3(0.05, 0.5, 0), stem, 0.5)
			var c: Color = cols[(i * 3 + j * 2) % cols.size()]
			_ball(0.085, p + Vector3(0, 0.44 + h, 0), _m("petal%d" % ((i * 3 + j * 2) % cols.size()), c), 0.6)


func _bench() -> void:
	_box(Vector3(2.0, 0.08, 0.45), Vector3(0, 0.46, 0), wood)
	_box(Vector3(2.0, 0.3, 0.06), Vector3(0, 0.8, -0.22), wood, Vector3(-0.15, 0, 0))
	for x in [-0.85, 0.85]:
		_box(Vector3(0.08, 0.46, 0.4), Vector3(x, 0.23, 0), _dark())
		_box(Vector3(0.08, 0.5, 0.06), Vector3(x, 0.7, -0.2), _dark(), Vector3(-0.15, 0, 0))
		_box(Vector3(0.08, 0.06, 0.45), Vector3(x, 0.66, 0), _dark())


func _scarecrow() -> void:
	_box(Vector3(0.1, 2.2, 0.1), Vector3(0, 1.1, 0), wood)
	_box(Vector3(1.6, 0.08, 0.08), Vector3(0, 1.6, 0), wood)
	var shirt := _m("plaid", Color(0.62, 0.14, 0.1))
	_box(Vector3(0.55, 0.6, 0.26), Vector3(0, 1.4, 0), shirt)
	_box(Vector3(1.3, 0.2, 0.2), Vector3(0, 1.6, 0), shirt)
	for x in [-0.72, 0.72]:
		_box(Vector3(0.1, 0.18, 0.18), Vector3(x, 1.52, 0), _straw(), Vector3(0, 0, 0.4 * signf(x)))
	var jeans := _m("jeans", Color(0.2, 0.26, 0.42))
	for x in [-0.12, 0.12]:
		_box(Vector3(0.2, 0.6, 0.2), Vector3(x, 0.85, 0), jeans)
		_box(Vector3(0.14, 0.14, 0.14), Vector3(x, 0.5, 0), _straw())
	_ball(0.2, Vector3(0, 1.95, 0), _m("burlap", Color(0.72, 0.6, 0.42), 1.0))
	_cyl(0.38, 0.04, Vector3(0, 2.12, 0), _straw(), 14)
	_cyl(0.17, 0.2, Vector3(0, 2.24, 0), _straw(), 12, 0.15)
	_box(Vector3(0.05, 0.05, 0.02), Vector3(-0.07, 2.0, 0.19), _dark())
	_box(Vector3(0.05, 0.05, 0.02), Vector3(0.07, 2.0, 0.19), _dark())


func _lantern_post() -> void:
	_box(Vector3(0.16, 2.5, 0.16), Vector3(0, 1.25, 0), _dark())
	_box(Vector3(0.7, 0.1, 0.1), Vector3(0.28, 2.38, 0), _dark())
	_box(Vector3(0.06, 0.4, 0.06), Vector3(0.12, 2.18, 0), _dark(), Vector3(0, 0, 0.8))
	_lantern(Vector3(0.52, 2.33, 0))
	_box(Vector3(0.4, 0.12, 0.4), Vector3(0, 0.06, 0), stone)


func _tree() -> void:
	var bark := _m("bark", Color(0.3, 0.21, 0.14), 1.0)
	_cyl(0.36, 3.4, Vector3(0, 1.7, 0), bark, 10, 0.24)
	_box(Vector3(0.14, 1.3, 0.14), Vector3(0.5, 3.2, 0.15), bark, Vector3(0.2, 0, -0.7))
	_box(Vector3(0.14, 1.2, 0.14), Vector3(-0.45, 3.3, -0.15), bark, Vector3(-0.2, 0, 0.6))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var leaf := [_m("leaf1", Color(0.17, 0.33, 0.12)), _m("leaf2", Color(0.22, 0.4, 0.14)), _m("leaf3", Color(0.27, 0.45, 0.16))]
	for p in [Vector3(0, 4.9, 0), Vector3(1.3, 4.2, 0.4), Vector3(-1.3, 4.3, -0.3), Vector3(0.3, 4.2, 1.3), Vector3(-0.3, 4.3, -1.3), Vector3(0.1, 5.8, 0.1), Vector3(1.0, 5.2, -0.9), Vector3(-1.0, 5.1, 0.9)]:
		_ball(rng.randf_range(1.2, 1.65), p, leaf[rng.randi() % 3], 0.85)


func _campfire() -> void:
	for i in 10:
		var a := TAU * i / 10.0
		_box(Vector3(0.28, 0.2, 0.22), Vector3(cos(a) * 0.62, 0.1, sin(a) * 0.62), stone, Vector3(0, -a, 0))
	_cyl(0.5, 0.03, Vector3(0, 0.02, 0), _m("ash", Color(0.15, 0.13, 0.12), 1.0), 12)
	for a in [0.0, 1.05, 2.1]:
		_box(Vector3(0.9, 0.12, 0.12), Vector3(0, 0.12, 0), _dark(), Vector3(0, a, 0.25))
	_cyl(0.32, 0.08, Vector3(0, 0.1, 0), _fire(), 8)
	_cyl(0.26, 0.6, Vector3(0, 0.42, 0), _fire(), 7, 0.0)
	_cyl(0.14, 0.75, Vector3(0.08, 0.5, 0.04), _flame(), 6, 0.0)
	_cyl(0.12, 0.5, Vector3(-0.1, 0.35, -0.06), _flame(), 6, 0.0)
	for z in [-1.45, 1.45]:
		_log(0.2, 1.4, Vector3(0, 0.2, z), _m("bark", Color(0.3, 0.21, 0.14), 1.0))
	_log(0.2, 1.2, Vector3(-1.45, 0.2, 0), _m("bark", Color(0.3, 0.21, 0.14), 1.0), "z")


func _wagon() -> void:
	var bed := _m("wagon", Color(0.4, 0.26, 0.14))
	_box(Vector3(3.4, 0.56, 1.4), Vector3(0, 0.92, 0), bed)
	_box(Vector3(3.5, 0.06, 1.46), Vector3(0, 1.2, 0), _dark())
	_log(0.72, 3.0, Vector3(0.1, 1.38, 0), _m("canvas", Color(0.88, 0.84, 0.74), 1.0), "x", 14)
	for x in [-1.3, -0.4, 0.5, 1.4]:
		var tm := TorusMesh.new()
		tm.inner_radius = 0.7
		tm.outer_radius = 0.76
		tm.rings = 14
		tm.ring_segments = 4
		_prim(tm, Vector3(x + 0.1, 1.38, 0), _dark(), Vector3(0, 0, PI * 0.5))
	for x in [-1.15, 1.15]:
		for z in [-0.82, 0.82]:
			_wheel(Vector3(x, 0.6 if x < 0 else 0.66, z), 0.6 if x < 0 else 0.66)
	for x in [-1.15, 1.15]:
		_box(Vector3(0.1, 0.1, 1.7), Vector3(x, 0.62, 0), _dark())
	_box(Vector3(1.8, 0.08, 0.08), Vector3(-2.4, 0.62, 0), _dark(), Vector3(0, 0, -0.12))
	_box(Vector3(0.5, 0.08, 1.2), Vector3(-1.55, 1.45, 0), bed)


func _well() -> void:
	_cyl(0.95, 0.8, Vector3(0, 0.4, 0), stone, 14)
	_cyl(0.98, 0.1, Vector3(0, 0.78, 0), _m("capstone", Color(0.5, 0.47, 0.42), 1.0), 14)
	_cyl(0.72, 0.02, Vector3(0, 0.76, 0), _m("deep", Color(0.04, 0.05, 0.05)), 14)
	for x in [-0.85, 0.85]:
		_box(Vector3(0.14, 1.9, 0.14), Vector3(x, 1.65, 0), wood)
	for s in [-1.0, 1.0]:
		_box(Vector3(2.2, 0.06, 0.9), Vector3(0, 2.68, 0.32 * s), roof, Vector3(0.62 * s, 0, 0))
	_box(Vector3(2.2, 0.1, 0.1), Vector3(0, 2.98, 0), _dark())
	_log(0.06, 1.75, Vector3(0, 1.8, 0), _dark())
	_cyl(0.13, 0.22, Vector3(0, 1.8, 0), _m("rope", Color(0.62, 0.5, 0.3), 1.0), 10)
	_box(Vector3(0.025, 0.55, 0.025), Vector3(0, 1.46, 0), _m("rope", Color(0.62, 0.5, 0.3), 1.0))
	_cyl(0.15, 0.24, Vector3(0, 1.08, 0), _m("barrel", Color(0.45, 0.28, 0.14)), 10, 0.17)
	_box(Vector3(0.06, 0.06, 0.5), Vector3(1.05, 1.8, 0.2), _dark())


func _fountain() -> void:
	_cyl(2.0, 0.25, Vector3(0, 0.125, 0), stone, 16)
	for i in 20:  # the rim, with a band of turquoise tiles
		var a := TAU * i / 20.0
		_box(Vector3(0.66, 0.5, 0.26), Vector3(cos(a) * 1.92, 0.25, sin(a) * 1.92), stone, Vector3(0, -a + PI * 0.5, 0))
		_box(Vector3(0.67, 0.12, 0.27), Vector3(cos(a) * 1.93, 0.36, sin(a) * 1.93), _m("tile", Color(0.1, 0.52, 0.58), 0.4), Vector3(0, -a + PI * 0.5, 0))
	_cyl(1.82, 0.04, Vector3(0, 0.4, 0), water, 16)
	_cyl(0.28, 1.1, Vector3(0, 0.55, 0), stone, 10)
	_cyl(0.75, 0.25, Vector3(0, 1.15, 0), stone, 12, 0.75)
	_cyl(0.35, 0.25, Vector3(0, 1.0, 0), stone, 12, 0.75)
	_cyl(0.65, 0.03, Vector3(0, 1.28, 0), water, 12)
	_cyl(0.1, 0.3, Vector3(0, 1.4, 0), _m("tile", Color(0.1, 0.52, 0.58), 0.4), 8)
	var spray := _m("spray", Color(0.72, 0.85, 0.92), 0.1)
	_cyl(0.05, 0.5, Vector3(0, 1.75, 0), spray, 6, 0.02)
	_ball(0.12, Vector3(0, 2.0, 0), spray, 0.6)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		_box(Vector3(0.05, 0.05, 0.6), Vector3(cos(a) * 0.45, 1.6, sin(a) * 0.45), spray, Vector3(0.9, -a + PI * 0.5, 0))


func _sign() -> void:
	var post := _m("bark", Color(0.3, 0.21, 0.14), 1.0)
	for x in [-1.9, 1.9]:
		_cyl(0.15, 3.4, Vector3(x, 1.7, 0), post, 10)
	_log(0.13, 4.5, Vector3(0, 3.25, 0), post)
	for x in [-1.3, 1.3]:
		_box(Vector3(0.03, 0.5, 0.03), Vector3(x, 2.95, 0), iron)
	_box(Vector3(3.5, 0.8, 0.1), Vector3(0, 2.32, 0), wood)
	_box(Vector3(3.6, 0.08, 0.12), Vector3(0, 2.74, 0), _dark())
	_box(Vector3(3.6, 0.08, 0.12), Vector3(0, 1.9, 0), _dark())
	for side in [1.0, -1.0]:
		var l := Label3D.new()
		l.font = load("res://ui/fonts/Vazirmatn-Bold.ttf")
		l.font_size = 72
		l.outline_size = 0
		l.modulate = Color(0.22, 0.11, 0.04)
		l.shaded = true
		l.position = Vector3(0, 2.32, 0.065 * side)
		l.rotation.y = 0.0 if side > 0.0 else PI
		add_child(l)
		_fit(l)


# ---------- the festivals' keepsakes ----------

func _table(top: float, w: float, d: float, cloth: Material) -> void:
	_box(Vector3(w, 0.06, d), Vector3(0, top, 0), cloth)
	for p in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_box(Vector3(0.07, top, 0.07), Vector3(p.x * (w * 0.5 - 0.08), top * 0.5, p.y * (d * 0.5 - 0.08)), _dark())


func _sabzeh() -> void:
	_cyl(0.6, 0.06, Vector3(0, 0.62, 0), _m("cloth_w", Color(0.92, 0.9, 0.84), 1.0), 16)
	_cyl(0.07, 0.6, Vector3(0, 0.3, 0), _dark(), 8)
	_cyl(0.42, 0.18, Vector3(0, 0.03, 0), _dark(), 10)
	_cyl(0.32, 0.06, Vector3(0, 0.68, 0), _m("plate", Color(0.85, 0.85, 0.8), 0.3), 14)
	var g := _m("sabzeh", Color(0.35, 0.65, 0.16))
	_cyl(0.27, 0.32, Vector3(0, 0.86, 0), g, 14, 0.3)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.27
	tm.outer_radius = 0.31
	tm.rings = 16
	tm.ring_segments = 4
	_prim(tm, Vector3(0, 0.82, 0), _m("ribbon", Color(0.82, 0.08, 0.1)))
	_ball(0.12, Vector3(0.38, 0.77, 0.2), _m("bowl", Color(0.65, 0.82, 0.88), 0.1))
	_box(Vector3(0.06, 0.03, 0.03), Vector3(0.38, 0.77, 0.2), _m("goldfish", Color(1.0, 0.45, 0.05)))
	_ball(0.07, Vector3(-0.35, 0.72, 0.25), _m("ribbon", Color(0.82, 0.08, 0.1)))
	_ball(0.07, Vector3(-0.42, 0.72, 0.12), _m("ribbon", Color(0.82, 0.08, 0.1)))


func _horseshoe() -> void:
	_box(Vector3(1.4, 0.45, 0.6), Vector3(0, 0.22, 0), stone)
	var silver := _m("silver", Color(0.86, 0.88, 0.9), 0.3)
	silver.metallic = 0.35
	var c := Vector3(0, 1.4, 0)
	for i in 11:  # a U open at the top, for luck
		var a := deg_to_rad(-200.0 + i * 22.0)
		_box(Vector3(0.2, 0.32, 0.12), c + Vector3(cos(a), sin(a), 0) * 0.62, silver, Vector3(0, 0, a))
	for x in [-0.2, 0.2]:
		_box(Vector3(0.12, 0.6, 0.12), Vector3(x, 0.6, 0), _dark())


func _jars() -> void:
	_box(Vector3(1.9, 0.12, 1.4), Vector3(0, 0.06, 0), wood)
	var clay := _m("clay", Color(0.66, 0.34, 0.18), 0.9)
	for j in [[Vector3(-0.5, 0, -0.2), 0.36], [Vector3(0.35, 0, -0.25), 0.3], [Vector3(0.0, 0, 0.35), 0.24]]:
		var r: float = j[1]
		var p: Vector3 = j[0]
		_ball(r, p + Vector3(0, 0.12 + r * 1.1, 0), clay, 1.1)
		_cyl(r * 0.35, r * 0.6, p + Vector3(0, 0.12 + r * 2.25, 0), clay, 10)
		_cyl(r * 0.45, 0.05, p + Vector3(0, 0.12 + r * 2.55, 0), clay, 10)
		_cyl(r * 1.01, 0.05, p + Vector3(0, 0.12 + r * 1.2, 0), _m("tile", Color(0.1, 0.52, 0.58), 0.4), 12)
	_cyl(0.28, 0.1, Vector3(0.6, 0.17, 0.4), clay, 12, 0.32)
	_cyl(0.26, 0.02, Vector3(0.6, 0.22, 0.4), water, 12)


func _rosette() -> void:
	_box(Vector3(0.7, 0.3, 0.6), Vector3(0, 0.15, 0), _dark())
	_box(Vector3(0.1, 1.2, 0.1), Vector3(0, 0.9, -0.1), _dark())
	var gold := _m("gold", Color(0.9, 0.68, 0.18), 0.3)
	gold.metallic = 0.7
	_cyl(0.38, 0.04, Vector3(0, 1.45, -0.02), gold, 18).rotation.x = PI * 0.5
	_cyl(0.24, 0.05, Vector3(0, 1.45, 0.0), _m("cloth_w", Color(0.92, 0.9, 0.84), 1.0), 14).rotation.x = PI * 0.5
	_cyl(0.13, 0.06, Vector3(0, 1.45, 0.02), gold, 12).rotation.x = PI * 0.5
	for x in [-0.1, 0.1]:
		_box(Vector3(0.13, 0.55, 0.02), Vector3(x, 0.95, -0.03), gold, Vector3(0, 0, x * 1.5))


func _basket() -> void:
	_cyl(0.55, 0.45, Vector3(0, 0.23, 0), _straw(), 14, 0.65)
	for y in [0.1, 0.25, 0.4]:
		_cyl(0.56 + y * 0.22, 0.03, Vector3(0, y, 0), _m("rope", Color(0.62, 0.5, 0.3), 1.0), 14)
	var pom := _m("pom", Color(0.6, 0.06, 0.08), 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 9:
		var a := TAU * i / 9.0
		_ball(0.15, Vector3(cos(a) * 0.32, 0.5 + rng.randf() * 0.08, sin(a) * 0.32), pom)
	for i in 3:
		_ball(0.15, Vector3(rng.randf_range(-0.12, 0.12), 0.68, rng.randf_range(-0.12, 0.12)), pom)
	_ball(0.15, Vector3(0.75, 0.14, 0.3), pom)
	_ball(0.15, Vector3(-0.7, 0.14, 0.45), pom)


func _lanterns() -> void:
	_box(Vector3(0.2, 3.0, 0.2), Vector3(0, 1.5, 0), _dark())
	_box(Vector3(1.9, 0.12, 0.12), Vector3(0, 2.85, 0), _dark())
	for x in [-0.8, 0.8]:
		_lantern(Vector3(x, 2.79, 0))
	_box(Vector3(0.6, 0.1, 0.1), Vector3(0, 2.2, 0.15), _dark())
	_lantern(Vector3(0, 2.12, 0.3))
	_box(Vector3(0.6, 0.2, 0.6), Vector3(0, 0.1, 0), stone)


func _yalda() -> void:
	_table(0.45, 1.6, 1.0, _m("cloth_r", Color(0.6, 0.08, 0.08), 1.0))
	var rind := _m("rind", Color(0.12, 0.3, 0.1), 0.6)
	_ball(0.28, Vector3(-0.4, 0.73, -0.1), rind, 0.85)
	_box(Vector3(0.36, 0.2, 0.06), Vector3(0.05, 0.58, 0.28), _m("melon", Color(0.88, 0.16, 0.18)), Vector3(0, 0.3, 0))
	_box(Vector3(0.38, 0.03, 0.07), Vector3(0.05, 0.47, 0.28), rind, Vector3(0, 0.3, 0))
	var pom := _m("pom", Color(0.6, 0.06, 0.08), 0.5)
	_cyl(0.24, 0.08, Vector3(0.45, 0.52, -0.15), _m("plate", Color(0.85, 0.85, 0.8), 0.3), 12)
	for p in [Vector3(0.38, 0.64, -0.2), Vector3(0.52, 0.64, -0.1), Vector3(0.45, 0.74, -0.15)]:
		_ball(0.1, p, pom)
	_cyl(0.05, 0.25, Vector3(0.0, 0.6, -0.3), _m("cloth_w", Color(0.92, 0.9, 0.84), 1.0), 8)
	_cyl(0.03, 0.08, Vector3(0.0, 0.76, -0.3), _flame(), 6, 0.0)
	_box(Vector3(0.3, 0.03, 0.22), Vector3(-0.1, 0.49, -0.3), _m("book", Color(0.3, 0.12, 0.06)))


func _torch() -> void:
	for i in 8:
		var a := TAU * i / 8.0
		_box(Vector3(0.3, 0.2, 0.24), Vector3(cos(a) * 0.75, 0.1, sin(a) * 0.75), stone, Vector3(0, -a, 0))
	_box(Vector3(0.5, 1.3, 0.5), Vector3(0, 0.65, 0), stone)
	_box(Vector3(0.6, 0.1, 0.6), Vector3(0, 1.32, 0), _m("capstone", Color(0.5, 0.47, 0.42), 1.0))
	_cyl(0.3, 0.2, Vector3(0, 1.45, 0), iron, 10, 0.38)
	_cyl(0.3, 0.7, Vector3(0, 1.88, 0), _fire(), 7, 0.0)
	_cyl(0.16, 0.9, Vector3(0.05, 1.95, 0.03), _flame(), 6, 0.0)
