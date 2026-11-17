## Market board: today's cattle price with a 12-day chart, contract offers to accept or turn down,
## and accepted contracts to deliver before their deadline.
class_name MarketUI
extends CanvasLayer

const SEASONS_OF := ["بهار", "تابستان", "پاییز", "زمستان"]

var market: Market
var builder: Builder
var _panel: PanelContainer
var _dim: ColorRect
var _price := UiTheme.label("", 34)
var _calf := UiTheme.label("", 22, Color(0.32, 0.18, 0.08))
var _chart := Chart.new()
var _list := VBoxContainer.new()


## Line chart of the price history, drawn in the board's ink.
class Chart extends Control:
	var data: Array = []

	func _draw() -> void:
		var r := Rect2(Vector2(8, 8), size - Vector2(16, 16))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.15, 0.04, 0.12))
		if data.size() < 2:
			return
		var lo: float = data.min() - 0.05
		var hi: float = data.max() + 0.05
		var pts := PackedVector2Array()
		for i in data.size():
			pts.append(r.position + Vector2(r.size.x * i / (data.size() - 1), r.size.y * (1.0 - (data[i] - lo) / (hi - lo))))
		draw_polyline(pts, UiTheme.INK, 3.0, true)
		for p in pts:
			draw_circle(p, 4.0, UiTheme.INK)
		draw_circle(pts[-1], 7.0, Color(0.55, 0.12, 0.05))  # today


func _ready() -> void:
	builder.bar_button("بازار", toggle, "market")
	_dim = UiTheme.dim(toggle)
	_panel = UiTheme.board()
	add_child(_dim)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_panel.add_child(col)
	col.add_child(UiTheme.header("بازار", builder._button(Button.new(), "بستن", toggle, "cancel")))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	col.add_child(row)
	# Persian reads right to left: contracts on the left, price on the right
	_list.custom_minimum_size = Vector2(700, 0)
	_list.add_theme_constant_override("separation", 10)
	row.add_child(_list)
	var price_col := VBoxContainer.new()
	price_col.add_theme_constant_override("separation", 8)
	row.add_child(price_col)
	price_col.add_child(_price)
	_chart.custom_minimum_size = Vector2(420, 190)
	price_col.add_child(_chart)
	price_col.add_child(UiTheme.label("قیمت هر کیلو تو %s روز گذشته" % UiTheme.fa(Market.HISTORY), 19, Color(0.32, 0.18, 0.08)))
	price_col.add_child(_calf)
	market.changed.connect(_refresh)


func toggle() -> void:
	_panel.visible = not _panel.visible
	_dim.visible = _panel.visible
	_refresh()


func _due_text(due: int) -> String:
	var dps := DayCycle.DAYS_PER_SEASON
	return "تا آخر %s سال %s" % [SEASONS_OF[(due / dps) % 4], UiTheme.fa(due / (dps * 4) + 1)]


func _small(b: Button) -> Button:
	b.custom_minimum_size = Vector2(150, 84)
	b.add_theme_font_size_override("font_size", 22)
	return b


func _card(text: String, buttons: Array) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()  # sunken darker patch of the board, like the build menu cards
	sb.bg_color = Color(0.3, 0.15, 0.04, 0.16)
	sb.border_color = Color(0.3, 0.16, 0.05, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	for b in buttons:
		h.add_child(b)
	var l := UiTheme.label(text, 21)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return card


func _refresh() -> void:
	if not _panel.visible:
		return
	var arrow: String = ["  ↓ داره ارزون می‌شه", "  ثابت", "  ↑ داره گرون می‌شه"][market.trend() + 1]
	_price.text = "هر کیلو %s دلار%s" % [UiTheme.fa_price(market.price), arrow]
	_calf.text = "قیمت گوساله امروز:  %s دلار" % UiTheme.fa(market.calf_price())
	if market.sale_bonus > 1.0:
		_calf.text += "\nبا قطار گاوهات %s درصد گرون‌تر فروش می‌رن" % UiTheme.fa(roundi(market.sale_bonus * 100.0 - 100.0))
	_chart.data = market.history
	_chart.queue_redraw()
	for c in _list.get_children():
		c.queue_free()
	_list.add_child(UiTheme.label("قراردادهام", 28))
	if market.active.is_empty():
		_list.add_child(UiTheme.label("فعلاً قراردادی نداری", 21, Color(0.32, 0.18, 0.08)))
	for c in market.active:
		var have := market.eligible(c)
		var b := _small(builder._button(Button.new(), "بده", market.deliver.bind(c), "place"))
		b.disabled = have < c.count
		_list.add_child(_card("%s تا گاو بالای %s کیلو، کیلویی %s دلار، %s\nآماده داری: %s از %s" % [
			UiTheme.fa(c.count), UiTheme.fa(c.min_kg), UiTheme.fa_price(c.per_kg), _due_text(c.due),
			UiTheme.fa(have), UiTheme.fa(c.count)], [b]))
	_list.add_child(UiTheme.label("خریدارها چی می‌خوان", 28))
	if market.offers.is_empty():
		_list.add_child(UiTheme.label("فعلاً کسی چیزی نخواسته", 21, Color(0.32, 0.18, 0.08)))
	for o in market.offers:
		var gain := int(o.per_kg / market.price * 100.0 - 100.0)
		_list.add_child(_card("%s تا گاو بالای %s کیلو، کیلویی %s دلار (%s٪ گرون‌تر از بازار)، %s\nاگه قبول کنی و به موقع ندی، %s٪ جریمه می‌شی" % [
			UiTheme.fa(o.count), UiTheme.fa(o.min_kg), UiTheme.fa_price(o.per_kg), UiTheme.fa(gain), _due_text(o.due),
			UiTheme.fa(int(Market.FINE * 100))], [
			_small(builder._button(Button.new(), "رد", market.decline.bind(o), "cancel")),
			_small(builder._button(Button.new(), "قبول", market.accept.bind(o), "place"))]))
