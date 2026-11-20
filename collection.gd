## The collection book: everything the ranch has had, ticked off. Cow breeds and colours, horse coats
## (three of them only come from foals), the fair's cups and ribbons, the festivals' keepsakes and the
## good surprises. Whatever is found goes in for good, even after it's sold. A full row pays a prize,
## once. Opened from «مدیریت رنچ» → «دفترچه», or from the ranch house, where the cups are kept.
class_name Collection
extends CanvasLayer

# row id, title, prize money, fame
const ROWS := [
	["cows", "گاوها", 800, 10.0],
	["horses", "رنگ اسب‌ها", 2000, 20.0],
	["cups", "جام‌ها و روبان‌ها", 1000, 15.0],
	["fests", "یادگاری جشن‌ها", 5000, 40.0],
	["sur", "اتفاق‌های خوب", 1000, 10.0],
]
const COWS := [["cow0:0", "معمولی سیاه‌وسفید", ""], ["cow0:1", "معمولی سرخ‌وسفید", ""], ["cow0:2", "معمولی کرم‌وسفید", ""],
	["cow1", "سیاه", ""], ["cow2", "شاخ‌بلند", ""], ["cow3", "سفید", "فقط تاجر دوره‌گرد میاره"]]
const CUPS := [["race1", "جام طلا", "اول مسابقه‌ی اسب"], ["race2", "جام نقره", "دوم مسابقه‌ی اسب"], ["race3", "جام برنز", "سوم مسابقه‌ی اسب"],
	["show1", "روبان آبی", "اول نمایشگاه گاو"], ["show2", "روبان قرمز", "دوم نمایشگاه گاو"], ["show3", "روبان زرد", "سوم نمایشگاه گاو"]]
const METAL := [Color(0.9, 0.7, 0.2), Color(0.75, 0.76, 0.78), Color(0.72, 0.45, 0.22)]
const RIBBON := [Color(0.15, 0.3, 0.75), Color(0.75, 0.15, 0.12), Color(0.9, 0.75, 0.15)]
const SUR_ICONS := {trader = "market", stray = "land", gold = "pond", chest = "barn", honey = "gift", traveller = "house",
	paper = "star", rain = "windmill", helpers = "build", twins = "cow"}

var herd: Herd
var horses: Horses
var fair: Fair
var festivals: Festivals
var builder: Builder
var progress: Progress
var notify: Callable
var seen := {}             # key -> true: found at least once
var claimed: Array = []    # rows whose prize was taken
var _mark: Label
var _panel: PanelContainer
var _dim: ColorRect
var _sum := UiTheme.label("", 25, Color(0.32, 0.18, 0.08))
var _rows := VBoxContainer.new()
var _scroll := ScrollContainer.new()
var _t := 0.0
var _quiet := true         # the first look after loading: no news for what's already there


## One square in the book: a picture of the thing, or a question mark while it's still missing.
class Swatch extends Control:
	var kind := ""         # cow, horse, cup, ribbon, fest, sur
	var what: Variant
	var have := false

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		if not have:
			draw_circle(c, r, Color(0.3, 0.15, 0.04, 0.15))
			draw_arc(c, r, 0, TAU, 32, Color(0.3, 0.16, 0.05, 0.5), 2.0)
			var font := get_theme_default_font()
			var q := "؟"
			var w := font.get_string_size(q, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
			draw_string(font, c + Vector2(-w * 0.5, 14), q, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.3, 0.16, 0.05, 0.6))
			return
		match kind:
			"cow":
				_cow(c, r, what)
			"horse":
				draw_circle(c, r, Fair.COAT_LOOK[what])
				var mane := (Fair.COAT_LOOK[what] as Color).darkened(0.5) if what != 6 else Color(0.8, 0.78, 0.74)
				draw_arc(c, r * 0.75, -2.4, -0.9, 12, mane, r * 0.3)
				draw_arc(c, r, 0, TAU, 32, UiTheme.INK, 2.0)
			"cup":
				_cup(c, r, Collection.METAL[what])
			"ribbon":
				_rosette(c, r, Collection.RIBBON[what])
			"fest":
				_fest(c, r, what)

	func _cow(c: Vector2, r: float, t: int) -> void:
		var base := Color(0.92, 0.9, 0.85)
		var patch: Color = [Color(0.08, 0.07, 0.07), Color(0.45, 0.16, 0.07), Color(0.55, 0.4, 0.24), Color(0.06, 0.05, 0.05), Color(0.88, 0.84, 0.74)][t]
		draw_circle(c, r, base if t < 3 else patch)
		if t < 3:
			for p in [Vector2(-0.35, -0.3), Vector2(0.35, 0.1), Vector2(-0.1, 0.45)]:
				draw_circle(c + p * r, r * 0.32, patch)
		draw_arc(c, r, 0, TAU, 32, UiTheme.INK, 2.0)

	func _cup(c: Vector2, r: float, m: Color) -> void:
		var s := r / 28.0
		var bowl := PackedVector2Array([Vector2(-18, -24), Vector2(18, -24), Vector2(16, -8), Vector2(8, 2), Vector2(-8, 2), Vector2(-16, -8)])
		for i in bowl.size():
			bowl[i] = c + bowl[i] * s
		draw_arc(c + Vector2(-18, -14) * s, 8 * s, PI * 0.5, PI * 1.5, 10, m.darkened(0.2), 4 * s)
		draw_arc(c + Vector2(18, -14) * s, 8 * s, -PI * 0.5, PI * 0.5, 10, m.darkened(0.2), 4 * s)
		draw_colored_polygon(bowl, m)
		draw_rect(Rect2(c + Vector2(-3, 2) * s, Vector2(6, 12) * s), m.darkened(0.15))
		draw_rect(Rect2(c + Vector2(-12, 14) * s, Vector2(24, 8) * s), m.darkened(0.3))
		draw_line(c + Vector2(-10, -20) * s, c + Vector2(-6, -6) * s, m.lightened(0.5), 3 * s)

	func _rosette(c: Vector2, r: float, col: Color) -> void:
		draw_colored_polygon(PackedVector2Array([c + Vector2(-0.4, 0.1) * r, c + Vector2(-0.6, 1.0) * r, c + Vector2(-0.3, 0.85) * r, c + Vector2(-0.05, 0.1) * r]), col.darkened(0.2))
		draw_colored_polygon(PackedVector2Array([c + Vector2(0.4, 0.1) * r, c + Vector2(0.6, 1.0) * r, c + Vector2(0.3, 0.85) * r, c + Vector2(0.05, 0.1) * r]), col.darkened(0.2))
		for k in 12:
			var a := TAU * k / 12.0
			draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.5 - Vector2(0, r * 0.15), r * 0.22, col)
		draw_circle(c - Vector2(0, r * 0.15), r * 0.38, col.lightened(0.25))
		draw_circle(c - Vector2(0, r * 0.15), r * 0.22, Color(0.95, 0.9, 0.75))

	## Each festival's keepsake, drawn plain.
	func _fest(c: Vector2, r: float, id: String) -> void:
		match id:
			"nowruz":  # sprouts in a dish
				for k in 9:
					var x := -0.5 + k / 8.0
					draw_line(c + Vector2(x * r * 0.9, 0.2 * r), c + Vector2(x * r * 1.1, -0.7 * r + absf(x) * 0.4 * r), Color(0.3, 0.6, 0.2), 4.0)
				draw_rect(Rect2(c + Vector2(-0.7, 0.15) * r, Vector2(1.4, 0.4) * r), Color(0.6, 0.35, 0.2))
				draw_rect(Rect2(c + Vector2(-0.7, 0.15) * r, Vector2(1.4, 0.12) * r), Color(0.75, 0.2, 0.15))
			"coach":  # a silver horseshoe
				draw_arc(c + Vector2(0, -0.1 * r), r * 0.6, PI * 0.15, PI * 1.85, 24, Color(0.78, 0.8, 0.84), r * 0.28)
				draw_arc(c + Vector2(0, -0.1 * r), r * 0.6, PI * 0.15, PI * 1.85, 24, Color(0.5, 0.52, 0.56), 2.0)
			"tirgan":  # a clay water jug
				draw_circle(c + Vector2(0, 0.15) * r, r * 0.55, Color(0.68, 0.38, 0.22))
				draw_rect(Rect2(c + Vector2(-0.18, -0.75) * r, Vector2(0.36, 0.5) * r), Color(0.68, 0.38, 0.22))
				draw_line(c + Vector2(-0.5, 0.1) * r, c + Vector2(0.5, 0.1) * r, Color(0.2, 0.45, 0.75), 4.0)
				draw_circle(c + Vector2(0.5, -0.75) * r, r * 0.12, Color(0.3, 0.6, 0.9))
			"statefair":  # a golden rosette
				_rosette(c, r, Color(0.88, 0.68, 0.18))
			"mehregan":  # a pomegranate
				draw_circle(c + Vector2(0, 0.1) * r, r * 0.6, Color(0.72, 0.12, 0.1))
				draw_colored_polygon(PackedVector2Array([c + Vector2(-0.2, -0.45) * r, c + Vector2(-0.1, -0.75) * r, c + Vector2(0, -0.5) * r, c + Vector2(0.1, -0.75) * r, c + Vector2(0.2, -0.45) * r]), Color(0.55, 0.1, 0.08))
				draw_circle(c + Vector2(-0.22, -0.1) * r, r * 0.12, Color(0.95, 0.6, 0.55))
			"campfire":  # a lantern
				draw_rect(Rect2(c + Vector2(-0.35, -0.45) * r, Vector2(0.7, 0.95) * r), Color(0.95, 0.75, 0.3))
				draw_rect(Rect2(c + Vector2(-0.35, -0.45) * r, Vector2(0.7, 0.95) * r), Color(0.2, 0.15, 0.1), false, 3.0)
				draw_circle(c + Vector2(0, 0.05) * r, r * 0.16, Color(1.0, 0.5, 0.1))
				draw_arc(c + Vector2(0, -0.55) * r, r * 0.25, PI, TAU, 10, Color(0.2, 0.15, 0.1), 3.0)
			"yalda":  # a slice of watermelon
				draw_arc(c + Vector2(0, -0.25) * r, r * 0.75, 0.0, PI, 20, Color(0.2, 0.5, 0.2), r * 0.18)
				var slice := PackedVector2Array([c + Vector2(-0.68, -0.25) * r])
				for k in 11:
					var a := PI * k / 10.0
					slice.append(c + Vector2(-0.25, 0) * 0 + Vector2(cos(a) * 0.68, sin(a) * 0.68 - 0.25) * r)
				draw_colored_polygon(slice, Color(0.88, 0.2, 0.2))
				for p in [Vector2(-0.3, 0.0), Vector2(0.0, 0.15), Vector2(0.3, 0.0)]:
					draw_circle(c + p * r, 3.0, Color(0.1, 0.08, 0.06))
			"sadeh":  # a torch
				draw_line(c + Vector2(0, 0.85) * r, c + Vector2(0, -0.2) * r, Color(0.45, 0.28, 0.12), 6.0)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-0.3, -0.2) * r, c + Vector2(0, -0.95) * r, c + Vector2(0.3, -0.2) * r]), Color(1.0, 0.5, 0.1))
				draw_colored_polygon(PackedVector2Array([c + Vector2(-0.15, -0.22) * r, c + Vector2(0, -0.65) * r, c + Vector2(0.15, -0.22) * r]), Color(1.0, 0.85, 0.3))


func _ready() -> void:
	var b := builder.bar_button("دفترچه", toggle, "book")
	_mark = UiTheme.label("!", 30, Color.WHITE)
	var dot := StyleBoxFlat.new()
	dot.bg_color = Color(0.8, 0.12, 0.08)
	dot.set_corner_radius_all(18)
	dot.content_margin_left = 12
	dot.content_margin_right = 12
	_mark.add_theme_stylebox_override("normal", dot)
	_mark.position = Vector2(4, -4)
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.visible = false
	b.add_child(_mark)
	_dim = UiTheme.dim(toggle)
	_panel = UiTheme.board()
	add_child(_dim)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	col.add_child(UiTheme.header("دفترچه‌ی کلکسیون", builder._button(Button.new(), "بستن", toggle, "cancel")))
	col.add_child(_sum)
	_rows.add_theme_constant_override("separation", 14)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(1150, 470)
	_scroll.add_child(_rows)
	col.add_child(_scroll)
	festivals.changed.connect(_scan)


## Cells of a row: [key, name, hint, kind, what]
func cells(row: String) -> Array:
	match row:
		"cows":
			return COWS.map(func(c): return [c[0], c[1], c[2], "cow", int(c[0].substr(5)) if c[0].begins_with("cow0:") else [0, 3, 1, 4][int(c[0].substr(3))]])
		"horses":
			var out := []
			for i in Horses.COAT_NAMES.size():
				out.append(["coat%d" % i, Horses.COAT_NAMES[i], ("فقط از کره‌اسب‌های خیلی خوب" if i == 6 else "فقط از کره‌اسب") if i in Horses.RARE else "", "horse", i])
			return out
		"cups":
			return CUPS.map(func(c): return [c[0], c[1], c[2], "cup" if c[0].begins_with("race") else "ribbon", int(c[0].right(1)) - 1])
		"fests":
			return Festivals.LIST.map(func(f): return ["fest:" + f.id, f.keep, "%s (%s)" % [f.name, Festivals.dates(f)], "fest", f.id])
		"sur":
			return Surprises.ORDER.map(func(k): return ["sur:" + k, Surprises.NAMES[k], "", "sur", k])
	return []


func found(row: String) -> int:
	return cells(row).filter(func(c): return seen.has(c[0])).size()


func full(row: String) -> bool:
	return found(row) == cells(row).size()


func add(key: String) -> void:
	if seen.has(key):
		return
	seen[key] = true
	if not _quiet:
		for r in ROWS:
			for c in cells(r[0]):
				if c[0] == key:
					notify.call("تو دفترچه‌ی کلکسیون ثبت شد: %s" % c[1] + ("؛ ردیف «%s» کامل شد و جایزه داره!" % r[1] if full(r[0]) else ""))
	_rebuild()


## Looks over the ranch for anything new.
func _scan() -> void:
	for c in herd.alive():
		add("cow0:%d" % clampi(int(floorf(c.coat * 4.0)), 0, 2) if c.breed == 0 else "cow%d" % c.breed)
	for h in horses.list:
		add("coat%d" % h.coat)
	for k in fair.counts():
		add(k)
	for f in Festivals.LIST:
		if festivals.done.has(f.id):
			add("fest:" + f.id)
	_quiet = false
	_mark.visible = ROWS.any(func(r): return full(r[0]) and not r[0] in claimed)


func claim(row: Array) -> void:
	if not full(row[0]) or row[0] in claimed:
		return
	claimed.append(row[0])
	builder.add_money(row[2], "prize")
	progress.add(row[3])
	notify.call("جایزه‌ی ردیف «%s»:  %s+ دلار" % [row[1], UiTheme.fa(row[2])])
	_mark.visible = ROWS.any(func(r): return full(r[0]) and not r[0] in claimed)
	_rebuild()


func is_open() -> bool:
	return _panel.visible


func toggle() -> void:
	_panel.visible = not _panel.visible
	_dim.visible = _panel.visible
	if _panel.visible:
		_scan()
	_rebuild()


func _rebuild() -> void:
	if not _panel.visible:
		return
	var have := 0
	var all := 0
	for r in ROWS:
		have += found(r[0])
		all += cells(r[0]).size()
	_sum.text = "%s تا از %s تا رو پیدا کردی. هر ردیف که کامل شه جایزه داره." % [UiTheme.fa(have), UiTheme.fa(all)]
	for c in _rows.get_children():
		c.queue_free()
	var counts := fair.counts()
	for r in ROWS:
		var head := HBoxContainer.new()
		var done: bool = r[0] in claimed
		var b := builder._button(Button.new(), "جایزه رو گرفتی ✓" if done else "جایزه: %s دلار" % UiTheme.fa(r[2]), claim.bind(r), "gift")
		b.disabled = done or not full(r[0])
		b.custom_minimum_size = Vector2(280, 76)
		b.add_theme_font_size_override("font_size", 22)
		head.add_child(b)
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(gap)
		head.add_child(UiTheme.label("%s  (%s از %s)" % [r[1], UiTheme.fa(found(r[0])), UiTheme.fa(cells(r[0]).size())], 30))
		_rows.add_child(head)
		var flow := HFlowContainer.new()
		flow.layout_direction = Control.LAYOUT_DIRECTION_RTL  # the first one on the right
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		for c in cells(r[0]):
			flow.add_child(_cell(c, counts.get(c[0], 0)))
		_rows.add_child(flow)


func _cell(c: Array, n: int) -> PanelContainer:
	var box := PanelContainer.new()
	var have := seen.has(c[0])
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.88, 0.7, 0.55) if have else Color(0.3, 0.15, 0.04, 0.12)
	sb.border_color = Color(0.3, 0.16, 0.05, 0.6 if have else 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(6)
	box.add_theme_stylebox_override("panel", sb)
	box.custom_minimum_size = Vector2(134, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	box.add_child(v)
	if c[3] == "sur" and have:
		var tr := TextureRect.new()
		tr.texture = load("res://ui/icons/%s.png" % SUR_ICONS[c[4]])
		tr.custom_minimum_size = Vector2(0, 56)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		v.add_child(tr)
	else:
		var s := Swatch.new()
		s.kind = c[3]
		s.what = c[4]
		s.have = have
		s.custom_minimum_size = Vector2(0, 56)
		v.add_child(s)
	var name: String = c[1] if have or c[3] == "fest" else "؟"
	if n > 1:
		name += " ×%s" % UiTheme.fa(n)
	if have or c[2] == "" or c[3] == "fest":  # a missing one with a hint shows just the hint
		var l := UiTheme.label(name, 18)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(122, 0)
		v.add_child(l)
	if not have and c[2] != "":
		var hint := UiTheme.label(c[2], 16, Color(0.32, 0.18, 0.08))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(122, 0)
		v.add_child(hint)
	return box


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 2.0
	_scan()


func to_save() -> Dictionary:
	return {seen = seen.keys(), claimed = claimed}


func from_save(d: Dictionary) -> void:
	for k in d.get("seen", []):
		seen[k] = true
	claimed = d.get("claimed", [])
