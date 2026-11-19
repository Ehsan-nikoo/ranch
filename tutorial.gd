## First-game tips: a plank above the bottom bar walks a new player through the boards one at a time.
## Each tip moves on by itself once the player does what it says (opens that board), or with "باشه";
## "دیگه نشون نده" ends it. Only for a new ranch; the step is saved.
## A bouncing arrow points at the button to press next (on the bar, or on the board once it's open),
## and doing what a tip says pays a small prize. The plank sits under the boards, so an open board
## hides it and only the arrow shows.
class_name Tutorial
extends CanvasLayer

const PRIZE := 300        # for the first real jobs: water, calves, a barn
const PRIZE_BOARD := 100  # for opening a board it points at

var herd_ui: HerdUI
var market_ui: MarketUI
var builder: Builder
var workers_ui: WorkersUI
var progress_ui: ProgressUI
var step := 0
var _box: PanelContainer
var _text: Label
var _arrow := TextureRect.new()
var _bob := 0.0
var _list: Array             # the steps, made once
var _t := 0.0


## [text, done when, what the arrow points at, prize] — the check is polled; null means only "باشه" moves on.
func _steps() -> Array:
	return [
		["به رنچت خوش اومدی! اینجا گوساله می‌خری، چاقشون می‌کنی و می‌فروشی. با یه انگشت دوربین رو بکش، با دو انگشت زوم کن", null, null, 0],
		["زمینت خالیه و همه‌چی رو خودت می‌سازی. اول از «ساخت» یه آسیاب بادی بساز تا گاوها آب داشته باشن", func(): return Building.placed(builder.world, Windmill) or Building.placed(builder.world, Pond), _build_target.bind(Windmill), PRIZE],
		["ساختمون یهو ساخته نمی‌شه: اول داربست می‌زنن و کم‌کم بالا میاد. سه تا ساختمون اولت زودتر تموم می‌شن. روش بزنی می‌بینی چقدر مونده", null, null, 0],
		["تا ساخته بشه، از «گله» چندتا گوساله بخر؛ با کامیون میان دم در رنچ", func(): return not herd_ui.herd.alive().is_empty() or not herd_ui.delivery.orders.is_empty(), func(): return herd_ui._buy if herd_ui._panel.visible else builder.bar.get("گله"), PRIZE],
		["یه طویله هم بساز: شب‌ها گاوها توش می‌خوابن و یونجه رو هم نگه می‌داره. سیلو هم جای یونجه‌ی بیشتره", func(): return Building.placed(builder.world, Barn), _build_target.bind(Barn), PRIZE],
		["دکمه‌ی «گله» رو بزن: می‌بینی گاوهات چندتان، چقدر وزن دارن و کدوما آماده‌ی فروشن", func(): return herd_ui._panel.visible, func(): return builder.bar.get("گله"), PRIZE_BOARD],
		["گاوها خودشون علف می‌خورن و از آسیاب بادی آب می‌خورن. وقتی وزنشون از ۵۰۰ کیلو رد شد، از «گله» بفروششون", null, null, 0],
		["زمستون علف درنمیاد: از «گله» یونجه بخر یا تابستون بچین، که گاوها گرسنه نمونن. اگه گاوها تو خطر باشن، دکمه‌ی «گله» قرمز چشمک می‌زنه", null, null, 0],
		["توی «بازار» قیمت امروز رو ببین و قرارداد بگیر؛ قرارداد پول و شهرت بیشتری میاره", func(): return market_ui._panel.visible, func(): return builder.bar.get("بازار"), PRIZE_BOARD],
		["با «ساخت» خونه‌ی کارگرها بساز. روی هر ساختمون بزنی منوش باز می‌شه و می‌تونی ارتقاش بدی: بزرگ‌تر و بهتر می‌شه", null, null, 0],
		["هر کارگر حواسش به ۲۰ تا گاو هست. از «کارگرها» یکی بیار سر کار", func(): return workers_ui._panel.visible, func(): return builder.bar.get("کارگرها"), PRIZE_BOARD],
		["توی «رنچ» هدف‌هات رو ببین؛ هر هدف جایزه داره. رنچت نسل به نسل تو خانواده‌ت می‌مونه. موفق باشی!", func(): return progress_ui._panel.visible, func(): return builder.bar.get("رنچ"), PRIZE_BOARD],
	]


## Where to tap to put up a building of `kind`: «ساخت», then its card's price, then «بساز».
func _build_target(kind: Script) -> Control:
	if builder.ghost != null:
		return builder._place_btn if builder.ghost.get_script() == kind else null
	if builder._panel.visible:
		for i in builder.CATALOG.size():
			if builder.CATALOG[i][1] == kind:
				return builder._items[i]
		return null
	return builder.bar.get("ساخت")


func _ready() -> void:
	layer = 0  # under the boards: an open board covers the tip, the arrow shows over it
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
	var over := CanvasLayer.new()
	over.layer = 4  # the arrow, over the boards
	add_child(over)
	_arrow.texture = load("res://ui/icons/arrow.png")
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.size = Vector2(96, 96)
	_arrow.visible = false
	over.add_child(_arrow)
	_list = _steps()
	_show()


func _show() -> void:
	var s := _list
	_box.visible = step < s.size()
	if _box.visible:
		_text.text = s[step][0]
		_box.call_deferred("reset_size")


func _next() -> void:
	step += 1
	_show()


func _skip() -> void:
	step = _list.size()
	_show()


func _process(delta: float) -> void:
	_point(delta)
	_t -= delta
	if _t > 0.0 or not _box.visible:
		return
	_t = 0.4
	var s: Array = _list[step]
	if s[1] != null and s[1].call():
		if s[3] > 0:
			builder.add_money(s[3], "prize")
			herd_ui.notify("آفرین! %s دلار جایزه گرفتی" % UiTheme.fa(s[3]))
		_next()


## The arrow bobs just above the button the tip wants pressed, while that button is on screen.
func _point(delta: float) -> void:
	var target: Control = null
	if step < _list.size() and _list[step][2] != null:
		target = _list[step][2].call()
	_arrow.visible = target != null and target.is_visible_in_tree() and _on_screen(target)
	if not _arrow.visible:
		return
	_bob += delta * 6.0
	var r := target.get_global_rect()
	_arrow.position = Vector2(r.get_center().x - 48.0, r.position.y - 84.0 - 14.0 * absf(sin(_bob)))


## A card button scrolled out of the build board's view doesn't count.
func _on_screen(c: Control) -> bool:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			return (p as Control).get_global_rect().grow(-20).has_point(c.get_global_rect().get_center())
		p = p.get_parent()
	return true
