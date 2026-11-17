## First-game tips: a plank above the bottom bar walks a new player through the boards one at a time.
## Each tip moves on by itself once the player does what it says (opens that board), or with "باشه";
## "دیگه نشون نده" ends it. Only for a new ranch; the step is saved.
class_name Tutorial
extends CanvasLayer

var herd_ui: HerdUI
var market_ui: MarketUI
var builder: Builder
var workers_ui: WorkersUI
var progress_ui: ProgressUI
var step := 0
var _box: PanelContainer
var _text: Label
var _t := 0.0


## [text, done when] — the check is polled; null means only "باشه" moves on.
func _steps() -> Array:
	return [
		["به رنچت خوش اومدی! اینجا گوساله می‌خری، چاقشون می‌کنی و می‌فروشی. با یه انگشت دوربین رو بکش، با دو انگشت زوم کن", null],
		["دکمه‌ی «گله» رو بزن: می‌بینی گاوهات چندتان، چقدر وزن دارن و کدوما آماده‌ی فروشن", func(): return herd_ui._panel.visible],
		["گاوها خودشون علف می‌خورن و از آسیاب بادی آب می‌خورن. وقتی وزنشون از ۵۰۰ کیلو رد شد، از «گله» بفروششون", null],
		["زمستون علف درنمیاد: از «گله» یونجه بخر یا تابستون بچین، که گاوها گرسنه نمونن", null],
		["توی «بازار» قیمت امروز رو ببین و قرارداد بگیر؛ قرارداد پول و شهرت بیشتری میاره", func(): return market_ui._panel.visible],
		["با «ساخت» آسیاب بادی، طویله و خونه بساز. هر خونه جا برای ۳ تا کارگر داره", func(): return builder._panel.visible],
		["هر کارگر حواسش به ۲۰ تا گاو هست. از «کارگرها» یکی بیار سر کار", func(): return workers_ui._panel.visible],
		["توی «رنچ» هدف‌هات رو ببین؛ هر هدف جایزه داره. رنچت سه نسل دووم میاره. موفق باشی!", func(): return progress_ui._panel.visible],
	]


func _ready() -> void:
	layer = 4
	_box = UiTheme.plank(24, Control.PRESET_CENTER_BOTTOM)
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_box.offset_top = -150
	_box.offset_bottom = -150
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_text = _box.get_child(0)
	_text.reparent(col)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(1000, 0)
	_box.add_child(col)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	for b in [["باشه", _next, "place"], ["دیگه نشون نده", _skip, "cancel"]]:
		var btn: Button = builder._button(Button.new(), b[0], b[1], b[2])
		btn.custom_minimum_size = Vector2(240, 70)
		btn.add_theme_font_size_override("font_size", 22)
		row.add_child(btn)
	col.add_child(row)
	add_child(_box)
	_show()


func _show() -> void:
	var s := _steps()
	_box.visible = step < s.size()
	if _box.visible:
		_text.text = s[step][0]
		_box.call_deferred("reset_size")


func _next() -> void:
	step += 1
	_show()


func _skip() -> void:
	step = _steps().size()
	_show()


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or not _box.visible:
		return
	_t = 0.4
	var check = _steps()[step][1]
	if check != null and check.call():
		_next()
