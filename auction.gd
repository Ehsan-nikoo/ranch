## Season auction in town: once a season, if there are cows at sale weight, buyers gather and the
## player can take some of them to the ring. Each buyer has a hidden top price around the market's;
## bids climb live until nobody raises, then "one... two... three... sold!". The final bid can come
## out above the market or below it; the player can still refuse and take the cows home, but the
## trip money is gone. Time stops while the board is open.
class_name Auction
extends CanvasLayer

const DAY_IN_SEASON := 1   # which day of each season the auction is held (0, 1 or 2)
const TRIP := 20           # trucking, per head, paid when you go
const OPEN := 0.82         # opening bid, share of the market price
const BUYERS := ["قصاب شهر", "تاجر گوشت شیکاگو", "رنچ همسایه", "آقای کارسون", "بیوه‌ی مک‌کین", "کمپانی کنسرو"]
const BEAT := 0.75         # seconds between bids
const HAMMER := ["یک...", "دو...", "سه... فروخته شد!"]

var day: DayCycle
var herd: Herd
var market: Market
var builder: Builder
var events: Events
var notify: Callable

var _due := false
var _n := 0                # cows in the lot
var _kg := 0.0
var _bid := 0.0            # per kg
var _top := {}             # buyer -> hidden max per kg
var _lead := ""
var _beat := 0.0
var _hammer := -1          # -1 bidding; 0..2 counting down; 3 over
var _speed := 1.0
var _panel: PanelContainer
var _dim: ColorRect
var _title := UiTheme.label("", 40)
var _text := UiTheme.label("", 25)
var _big := UiTheme.label("", 62, Color(0.5, 0.08, 0.04))
var _who := UiTheme.label("", 28)
var _count_row := HBoxContainer.new()
var _count := UiTheme.label("", 34)
var _row := HBoxContainer.new()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	layer = 5
	_dim = UiTheme.dim(func(): pass)
	_panel = UiTheme.board()
	add_child(_dim)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	_panel.add_child(col)
	col.add_child(_title)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(980, 0)
	col.add_child(_text)
	col.add_child(_big)
	col.add_child(_who)
	_count_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_count_row.add_theme_constant_override("separation", 20)
	_count_row.add_child(_small("+", func(): _set_n(_n + 1)))
	_count.custom_minimum_size = Vector2(300, 0)
	_count_row.add_child(_count)
	_count_row.add_child(_small("-", func(): _set_n(_n - 1)))
	col.add_child(_count_row)
	_row.add_theme_constant_override("separation", 16)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_row)


func _small(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(104, 90)
	b.add_theme_font_size_override("font_size", 40)
	b.pressed.connect(cb)
	return b


func is_open() -> bool:
	return _panel.visible


## Called at each day change.
func new_day(d: int) -> void:
	if d % DayCycle.DAYS_PER_SEASON == DAY_IN_SEASON and herd.ready_count() > 0:
		_due = true


func _process(delta: float) -> void:
	if _due and not _panel.visible and not events._panel.visible:
		_due = false
		if herd.ready_count() > 0:
			_invite()
	if not _panel.visible or _hammer < 0 and _top.is_empty() or _hammer >= HAMMER.size():
		return
	_beat -= delta
	if _beat > 0.0:
		return
	_beat = BEAT * _rng.randf_range(0.8, 1.3)
	var keen := _top.keys().filter(func(b): return b != _lead and _top[b] >= _bid + 0.02)
	if not keen.is_empty() and (_hammer < 0 or _hammer < HAMMER.size() - 1 and _rng.randf() < 0.45):  # a late bid can still break the count
		_lead = keen[_rng.randi() % keen.size()]
		_bid = minf(_bid + snappedf(_rng.randf_range(0.02, 0.06), 0.01), _top[_lead])
		_hammer = -1
		_show_bid("")
		return
	_hammer += 1
	if _hammer < HAMMER.size():
		_show_bid(HAMMER[_hammer])
	else:
		_done()


# ---------- the boards ----------

func _invite() -> void:
	_top.clear()
	_hammer = -1
	_title.text = "حراج فصل تو شهر!"
	_text.text = "خریدارها از همه‌جا اومدن شهر. گاوهای آماده‌ت رو ببری حراج، شاید از قیمت بازار (%s دلار هر کیلو) بیشتر بدن، شاید هم کمتر. کرایه‌ی راه هر گاو %s دلاره." % [UiTheme.fa_price(market.sale_price()), UiTheme.fa(TRIP)]
	_big.visible = false
	_who.visible = false
	_count_row.visible = true
	_set_n(herd.ready_count())
	_speed = day.speed if day.speed > 0.0 else _speed
	day.speed = 0.0
	_panel.visible = true
	_dim.visible = true


## Test hook: invite and go straight to the ring.
func _go_now() -> void:
	_due = false
	_invite()
	_go()


func _set_n(n: int) -> void:
	_n = clampi(n, 1, herd.ready_count())
	_count.text = "%s گاو" % UiTheme.fa(_n)
	_buttons([["ببر حراج  %s دلار" % UiTheme.fa(_n * TRIP), "market", _go, builder.money < _n * TRIP], ["این دفعه نه", "cancel", _close, false]])


func _go() -> void:
	builder.add_money(-_n * TRIP)
	_kg = _lot_kg(_n)
	var p := market.sale_price()
	var names := BUYERS.duplicate()
	names.shuffle()
	for b in names.slice(0, _rng.randi_range(3, 4)):
		_top[b] = snappedf(p * _rng.randf_range(0.85, 1.25), 0.01)
	_bid = snappedf(p * OPEN, 0.01)
	_lead = ""
	_beat = 1.2
	_hammer = -1
	_title.text = "حراج شروع شد!"
	_text.text = "%s گاو، روی هم %s کیلو. تو بازار %s دلار می‌خریدنش (%s دلار هر کیلو)." % [UiTheme.fa(_n), UiTheme.fa(int(_kg)), UiTheme.fa(int(_kg * p)), UiTheme.fa_price(p)]
	_count_row.visible = false
	_big.visible = true
	_who.visible = true
	_show_bid("کی بیشتر می‌ده؟")
	_buttons([])


## Heaviest first, the same cows Herd.sell would take.
func _lot_kg(n: int) -> float:
	var w: Array = herd.feeders().filter(func(c): return c.weight >= Herd.READY_KG).map(func(c): return c.weight)
	w.sort()
	w.reverse()
	return w.slice(0, n).reduce(func(a, x): return a + x, 0.0)


func _show_bid(status: String) -> void:
	_big.text = "%s دلار" % UiTheme.fa(int(_kg * _bid))
	var who := "پیشنهاد اول" if _lead == "" else _lead
	_who.text = "%s  (%s دلار هر کیلو)\n%s" % [who, UiTheme.fa_price(_bid), status if status != "" else "کسی بیشتر نمی‌ده؟"]


func _done() -> void:
	var p := market.sale_price()
	var cash := int(_kg * _bid)
	var diff := int(_kg * (_bid - p))
	if _lead == "":
		_title.text = "کسی نخرید!"
		_who.text = "امروز خریدارها دست‌ودلشون نمی‌رفت."
		_buttons([["برگردون خونه", "cancel", _close, false]])
		return
	_title.text = "فروخته شد!" if diff >= 0 else "قیمت پایین موند"
	if diff >= 0:
		_who.text = "%s خرید؛ %s دلار بیشتر از بازار!" % [_lead, UiTheme.fa(diff)]
	else:
		_who.text = "%s آخرین قیمت رو داد، ولی %s دلار کمتر از بازاره." % [_lead, UiTheme.fa(-diff)]
	_buttons([["بفروش", "market", _sell.bind(cash), false], ["نمی‌فروشم", "cancel", func():
		notify.call("گاوها رو برگردوندی رنچ")
		_close(), false]])


func _sell(cash: int) -> void:
	var before := herd.feeders().size()
	var kg := herd.sell(_n, Herd.READY_KG)
	_n = before - herd.feeders().size()
	cash = int(kg * _bid)
	builder.add_money(cash)
	market.sold.emit(cash, false)
	market.changed.emit()
	notify.call("تو حراج %s گاو فروختی:  %s+ دلار" % [UiTheme.fa(_n), UiTheme.fa(cash)])
	_close()


## options: [[label, icon, Callable, disabled]]
func _buttons(options: Array) -> void:
	for c in _row.get_children():
		c.queue_free()
	for o in options:
		var b := builder._button(Button.new(), o[0], o[2], o[1])
		b.disabled = o[3]
		_row.add_child(b)


func _close() -> void:
	_top.clear()
	_hammer = -1
	_panel.visible = false
	_dim.visible = false
	day.speed = _speed
