## The ranch's account book: every dollar in or out, sorted by what it was for, kept per day for the
## last week. Opened from the market board; shows each kind's total in and out, and the week's balance.
class_name Ledger
extends CanvasLayer

const DAYS := 7
const KINDS := {"sale": "فروش گاو", "prize": "جایزه، کافه و هدف‌ها", "cattle": "خرید گاو", "hay": "یونجه", "vet": "دامپزشک و واکسن",
	"upkeep": "خرج گله", "wages": "حقوق کارگرها", "build": "ساخت، ارتقا و زمین", "trips": "کرایه‌ی راه و سفر", "horses": "اسب‌ها", "trouble": "دردسرها و جریمه", "": "بقیه"}

var builder: Builder
var day: DayCycle
var book: Array = []       # one {kind: sum} per day, oldest first; the last is today
var _panel: PanelContainer
var _dim: ColorRect
var _grid := GridContainer.new()
var _total := UiTheme.label("", 30)


func _ready() -> void:
	if book.is_empty():
		book.append({})
	builder.money_moved.connect(func(delta: int, why: String):
		var today: Dictionary = book[-1]
		today[why] = today.get(why, 0) + delta)
	day.day_changed.connect(func(_d):
		book.append({})
		while book.size() > DAYS:
			book.pop_front())
	_dim = UiTheme.dim(toggle)
	_panel = UiTheme.board()
	add_child(_dim)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_panel.add_child(col)
	col.add_child(UiTheme.header("دفترچه‌ی حساب", builder._button(Button.new(), "بستن", toggle, "cancel")))
	col.add_child(UiTheme.label("پول‌هایی که این %s روز اومد و رفت" % UiTheme.fa(DAYS), 24, Color(0.32, 0.18, 0.08)))
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 60)
	_grid.add_theme_constant_override("v_separation", 6)
	var center := CenterContainer.new()
	center.add_child(_grid)
	col.add_child(center)
	col.add_child(_total)


func toggle() -> void:
	_panel.visible = not _panel.visible
	_dim.visible = _panel.visible
	if _panel.visible:
		_refresh()


func _refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var sums := {}
	for d in book:
		for k in d:
			sums[k] = sums.get(k, 0) + d[k]
	# columns right to left: what it was for, money in, money out
	for t in ["خرج", "درآمد", ""]:
		_grid.add_child(UiTheme.label(t, 24))
	var net := 0
	for k in KINDS:
		if not sums.has(k) or sums[k] == 0:
			continue
		var v: int = sums[k]
		net += v
		_grid.add_child(UiTheme.label(UiTheme.fa(-v) if v < 0 else "", 24, Color(0.55, 0.1, 0.05)))
		_grid.add_child(UiTheme.label(UiTheme.fa(v) if v > 0 else "", 24, Color(0.15, 0.4, 0.1)))
		_grid.add_child(UiTheme.label(KINDS[k], 24))
	_total.text = "حساب این هفته:  %s%s دلار" % [UiTheme.fa(absi(net)), "+" if net >= 0 else "-"]
	_total.add_theme_color_override("font_color", Color(0.15, 0.4, 0.1) if net >= 0 else Color(0.55, 0.1, 0.05))


func to_save() -> Array:
	return book


func from_save(b: Array) -> void:
	book = b.map(func(d): return d)
	for d in book:
		for k in d:
			d[k] = int(d[k])
