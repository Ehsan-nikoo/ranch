## Buying dollars: a board of four bundles, each with its price in toman. Paying isn't hooked up to a
## store yet: `pay` is where a store's purchase call goes (it calls back with true once paid). Until
## then a bundle's button says so; with the hidden test buttons on (Hud dev), the dollars just come.
class_name Shop
extends CanvasLayer

## dollars, gift dollars on top, price in toman, a word on the card
const PACKS := [
	[5000, 0, 29000, ""],
	[10000, 2000, 59000, "محبوب"],
	[20000, 8000, 119000, ""],
	[40000, 25000, 239000, "بهترین قیمت"],
]

var builder: Builder
var save: Callable
var pay: Callable          # (pack index, done: Callable(bool)) -> void; empty = no store yet
var test_pay: Callable     # () -> bool: hidden test buttons are on, so a tap just gives the dollars
var _panel: PanelContainer
var _dim: ColorRect
var _say := UiTheme.label("", 24, Color(0.42, 0.12, 0.05))


func _ready() -> void:
	layer = 3
	_dim = UiTheme.dim(toggle)
	_panel = UiTheme.board()
	add_child(_dim)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	_panel.add_child(col)
	col.add_child(UiTheme.header("خرید دلار", builder._button(Button.new(), "بستن", toggle, "cancel")))
	col.add_child(UiTheme.label("پول کم آوردی؟ یه بسته دلار بخر و رنچت رو زودتر بزرگ کن.", 24))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	col.add_child(row)
	var box := StyleBoxFlat.new()  # a slightly sunken patch of the board, like the build cards
	box.bg_color = Color(0.25, 0.13, 0.05, 0.16)
	box.set_corner_radius_all(14)
	box.set_content_margin_all(14)
	for i in range(PACKS.size() - 1, -1, -1):  # the smallest on the right, where the eye starts
		var p: Array = PACKS[i]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", box)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		v.custom_minimum_size = Vector2(230, 0)
		card.add_child(v)
		v.add_child(UiTheme.label(p[3] if p[3] != "" else " ", 22, Color(0.15, 0.4, 0.1)))
		var pic := TextureRect.new()
		pic.texture = load("res://ui/icons/coins.png")
		pic.custom_minimum_size = Vector2(0, 70 + 12 * i)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		v.add_child(pic)
		v.add_child(UiTheme.label("%s دلار" % group(p[0] + p[1]), 30))
		v.add_child(UiTheme.label("با %s دلار هدیه" % group(p[1]) if p[1] > 0 else " ", 20, Color(0.15, 0.4, 0.1)))
		var b := builder._button(Button.new(), "%s تومن" % group(p[2]), _buy.bind(i), "")
		b.custom_minimum_size = Vector2(220, 90)
		b.add_theme_font_size_override("font_size", 24)
		v.add_child(b)
		row.add_child(card)
	_say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_say.custom_minimum_size.x = 900
	col.add_child(_say)


func is_open() -> bool:
	return _panel.visible


func toggle() -> void:
	_panel.visible = not _panel.visible
	_dim.visible = _panel.visible
	_say.text = ""


func _buy(i: int) -> void:
	if test_pay.is_valid() and test_pay.call():
		_paid(true, i)
		return
	if not pay.is_valid():
		_say.text = "خرید با پول واقعی هنوز راه نیفتاده. به‌زودی وصل می‌شه!"
		return
	_say.text = "داریم می‌ریم صفحه‌ی پرداخت..."
	pay.call(i, _paid.bind(i))


func _paid(ok: bool, i: int) -> void:
	if not ok:
		_say.text = "پرداخت انجام نشد و پولی کم نشد."
		return
	var p: Array = PACKS[i]
	builder.add_money(p[0] + p[1], "shop")
	_say.text = "%s دلار اومد تو حسابت. مبارکه!" % group(p[0] + p[1])
	if save.is_valid():
		save.call()


## A whole number with Persian digits and a thousands mark: ۱۲٬۰۰۰
static func group(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "٬" + s.right(3) + out
		s = s.left(s.length() - 3)
	return UiTheme.fa(s + out)
