## Cattle drive to the railhead in town: once a season, a cattle buyer at the railroad pays a lot more
## than the local market, if you walk the cows there yourself. The cows leave the ranch and are on the
## trail for half a day; on the way trouble turns up (a swollen river, a stampede, rustlers, a dry
## stretch) and each time a board asks what to do. What reaches the railhead sells at the higher price.
## A plank in the corner shows how far along the trail the herd is.
class_name Drive
extends CanvasLayer

const DAY_IN_SEASON := 2   # which day of each season the buyer sends word
const MIN_COWS := 4
const HOURS := 8.0         # game hours on the trail (10 real minutes at 1x)
const BONUS := 1.3         # railhead price over the local market
const WAGON := 100         # chuck wagon and cook, plus...
const PER_HEAD := 10       # ...trail hands' pay per cow
const AT := [0.3, 0.7]     # trail progress where trouble turns up

var day: DayCycle
var herd: Herd
var market: Market
var builder: Builder
var workers: Workers
var events: Events
var auction: Auction
var notify: Callable

var trail := {}            # {n, kg, start, next}: the herd on the trail; empty when there's none
var _due := false
var _n := 0
var _speed := 1.0
var _panel: PanelContainer
var _dim: ColorRect
var _title := UiTheme.label("", 40)
var _text := UiTheme.label("", 25)
var _count_row := HBoxContainer.new()
var _count := UiTheme.label("", 34)
var _row := HBoxContainer.new()
var _box: PanelContainer   # trail progress plank
var _box_label: Label
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	layer = 5
	_dim = UiTheme.dim(func(): pass)
	_panel = UiTheme.board()
	add_child(_dim)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	_panel.add_child(col)
	col.add_child(_title)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(980, 0)
	col.add_child(_text)
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
	_box = UiTheme.plank(24, Control.PRESET_TOP_LEFT)
	_box.offset_left = 16
	_box.offset_top = 230  # below the settings and «امروز» buttons
	_box.grow_horizontal = Control.GROW_DIRECTION_END
	_box_label = _box.get_child(0)
	_box_label.custom_minimum_size.x = 420  # fixed width: the plank doesn't twitch
	_box.visible = false
	add_child(_box)


func _small(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(104, 90)
	b.add_theme_font_size_override("font_size", 40)
	b.pressed.connect(cb)
	return b


func now() -> float:
	return day.day * 24.0 + day.hour


func is_open() -> bool:
	return _panel.visible


func _busy() -> bool:
	return _panel.visible or events._panel.visible or auction.is_open()


## Called at each day change.
func new_day(d: int) -> void:
	if d % DayCycle.DAYS_PER_SEASON == DAY_IN_SEASON and trail.is_empty() and herd.ready_count() >= MIN_COWS:
		_due = true


func progress() -> float:
	return 0.0 if trail.is_empty() else clampf((now() - trail.start) / HOURS, 0.0, 1.0)


func _process(_delta: float) -> void:
	_box.visible = not trail.is_empty()
	if trail.is_empty():
		if _due and not _busy():
			_due = false
			if herd.ready_count() >= MIN_COWS:
				_invite()
		return
	var p := progress()
	var bar := ""
	for i in 10:
		bar += "■" if i < int(p * 10.0) else "□"
	_box_label.text = "کوچ گله: %s گاو  %s" % [UiTheme.fa(trail.n), bar]
	if _busy():
		return
	var k: int = trail.next
	if k < AT.size() and p >= AT[k]:
		trail.next = k + 1
		_trouble()
	elif p >= 1.0:
		_arrive()


# ---------- starting out ----------

func _invite() -> void:
	_title.text = "کوچ گله تا ایستگاه"
	_text.text = "یه خریدار از ایستگاه راه‌آهن شهر خبر داده: گاو چاق رو %s برابر قیمت بازار می‌خره، ولی باید خودت گله رو تا اونجا ببری. راهش چند ساعت طول می‌کشه و ممکنه تو راه گرفتاری پیش بیاد. واگن غذا %s دلار، هر گاو هم %s دلار مزد کابوی‌ها." % ["۱٫۳", UiTheme.fa(WAGON), UiTheme.fa(PER_HEAD)]
	_count_row.visible = true
	_set_n(herd.ready_count())
	_pause()


func _cost(n: int) -> int:
	return WAGON + PER_HEAD * n


func _set_n(n: int) -> void:
	_n = clampi(n, MIN_COWS, herd.ready_count())
	_count.text = "%s گاو" % UiTheme.fa(_n)
	_buttons([["راه بیفت  %s دلار" % UiTheme.fa(_cost(_n)), "cow", _go, builder.money < _cost(_n)], ["نه، بمونه", "cancel", _close, false]])


func _go() -> void:
	builder.add_money(-_cost(_n), "trips")
	var kg := herd.sell(_n, Herd.READY_KG)
	trail = {n = _n, kg = kg, start = now(), next = 0}
	notify.call("گله راه افتاد سمت ایستگاه")
	_close()


# ---------- on the trail ----------

## Takes `lost` cows off the trail herd (average weight each) and `thin` share of the weight.
func _hurt(lost: int, thin: float) -> void:
	var n: int = trail.n
	lost = mini(lost, n)
	var avg: float = trail.kg / maxf(n, 1)
	trail.n = n - lost
	trail.kg = (trail.kg - avg * lost) * (1.0 - thin)


func _trouble() -> void:
	var pool := [_river, _stampede, _rustlers, _dry]
	pool.shuffle()
	pool[0].call()


func _river() -> void:
	_ask("رودخونه طغیان کرده", "گله رسیده لب رودخونه، ولی آب بالا اومده و تند می‌ره. اگه الان رد بشین ممکنه آب چندتا گاو رو ببره. اگه صبر کنین تا آب بخوابه، گاوها گشنه می‌مونن و لاغر می‌شن.", [
		["همین الان رد شو", 0, "cow", func():
			var lost := _rng.randi_range(0, 2) if workers.best(Workers.RIDER) < 2 else 0
			_hurt(lost, 0.0)
			notify.call("از رودخونه رد شدین" if lost == 0 else "آب %s تا گاو رو با خودش برد" % UiTheme.fa(lost))],
		["صبر کن آب بخوابه", 0, "cancel", func():
			trail.start += 3.0  # three hours lost
			_hurt(0, 0.05)
			notify.call("آب خوابید و رد شدین؛ گاوها یه کم لاغر شدن")],
	])


func _stampede() -> void:
	_ask("رم کردن گله", "یه رعد و برق زد و گله رم کرد! گاوها دارن هر کدوم یه طرف می‌دوون.", [
		["بیفت جلوی گله", 0, "cow", func():
			var lost := 0 if _rng.randf() < 0.55 + 0.15 * workers.best(Workers.RIDER) else _rng.randi_range(1, 3)
			_hurt(lost, 0.02)
			notify.call("جلوی گله رو گرفتی؛ همه سالمن" if lost == 0 else "گله رو جمع کردی، ولی %s تا گاو گم شدن" % UiTheme.fa(lost))],
		["بذار خسته شن", 0, "cancel", func():
			_hurt(_rng.randi_range(0, 1), 0.08)
			notify.call("گله آروم شد، ولی کلی دویدن و لاغر شدن")],
	])


func _rustlers() -> void:
	var guard := 40 + 5 * int(trail.n)
	_ask("دزدهای گاو", "یه مشت دزد از دور دنبال گله‌ان. امشب حتماً میان سراغش.", [
		["تفنگدار بگیر", guard, "worker", func(): notify.call("تفنگدارها تا صبح بیدار موندن؛ دزدها جرئت نکردن")],
		["ریسک کن", 0, "cancel", func():
			var lost := 0 if _rng.randf() < 0.4 else _rng.randi_range(2, 4)
			_hurt(lost, 0.0)
			notify.call("دزدها نیومدن!" if lost == 0 else "دزدها %s تا گاو بردن" % UiTheme.fa(lost))],
	])


func _dry() -> void:
	_ask("راه خشک", "جلوتون یه تیکه راه بی‌آبه. یا از وسطش برین که کوتاهه ولی گاوها تشنه و لاغر می‌شن، یا از کنار رودخونه دور بزنین که طول می‌کشه.", [
		["از وسطش برو", 0, "cow", func():
			_hurt(0, 0.07)
			notify.call("از راه خشک رد شدین؛ گاوها لاغر شدن")],
		["دور بزن", 0, "cancel", func():
			trail.start += 3.0
			notify.call("دور زدین؛ دیرتر می‌رسین ولی گاوها سرحالن")],
	])


func _arrive() -> void:
	var t := trail
	trail = {}
	if t.n == 0:
		notify.call("هیچ گاوی به ایستگاه نرسید")
		return
	var cash := int(t.kg * market.sale_price() * BONUS)
	builder.add_money(cash, "sale")
	market.sold.emit(cash, false)
	market.changed.emit()
	_title.text = "رسیدین ایستگاه!"
	_text.text = "%s گاو سالم رسیدن و خریدار همه رو برداشت:  %s+ دلار" % [UiTheme.fa(t.n), UiTheme.fa(cash)]
	_count_row.visible = false
	_buttons([["عالیه", "market", _close, false]])
	_pause()


# ---------- the board ----------

## options: [[label, cost, icon, Callable]]
func _ask(title: String, text: String, options: Array) -> void:
	_title.text = title
	_text.text = text
	_count_row.visible = false
	var list := []
	for o in options:
		var cost: int = o[1]
		var label: String = o[0] if cost == 0 else "%s  %s دلار" % [o[0], UiTheme.fa(cost)]
		list.append([label, o[2], func():
			if cost > 0:
				builder.add_money(-cost, "trouble")
			_close()
			o[3].call(), cost > 0 and builder.money < cost])
	_buttons(list)
	_pause()


## options: [[label, icon, Callable, disabled]]
func _buttons(options: Array) -> void:
	for c in _row.get_children():
		c.queue_free()
	for o in options:
		var b := builder._button(Button.new(), o[0], o[2], o[1])
		b.disabled = o[3]
		_row.add_child(b)


func _pause() -> void:
	_speed = day.speed if day.speed > 0.0 else _speed
	day.speed = 0.0
	_panel.visible = true
	_dim.visible = true


func _close() -> void:
	_panel.visible = false
	_dim.visible = false
	day.speed = _speed


func to_save() -> Dictionary:
	return trail


func from_save(d: Dictionary) -> void:
	trail = d
	if not trail.is_empty():  # JSON brings numbers back as floats
		trail.n = int(trail.n)
		trail.next = int(trail.next)
