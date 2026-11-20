## Festivals on the real calendar (the Persian one, from the phone's date): eight a year, a few days
## each: Nowruz, the stagecoach race, Tirgan, the big state fair, Mehregan, the cowboys' campfire
## night, Yalda and Sadeh. Each has one job, and a prize only that festival gives: money, fame and a
## keepsake for the collection book. Miss it and it comes round again next year. The stagecoach race
## and the state fair's cattle show are entered from the festival's board, once a day. While one is
## on, a «جشن» button sits under «امروز», with a red mark until its job is done.
class_name Festivals
extends CanvasLayer

signal changed

# from and to: [month, day] of the Persian year; count: what the job counts (see _on_money and the hooks)
const LIST := [
	{id = "nowruz", name = "جشن نوروز", from = [1, 1], to = [1, 13], keep = "سبزه‌ی نوروز", money = 1500, rep = 15.0,
		about = "نوروز اومد! همه‌جا سبز شده و وقت زاد و ولده.", count = "born", n = 4, job = "%s تا گوساله یا کره‌اسب به دنیا بیاد"},
	{id = "coach", name = "مسابقه‌ی دلیجان", from = [2, 15], to = [2, 21], keep = "نعل نقره‌ای", money = 1200, rep = 12.0,
		about = "دلیجان‌ها از همه‌جا اومدن شهر برای مسابقه. اسبت رو ببند به دلیجان و بتازون!", count = "coach", n = 1, job = "تو مسابقه‌ی دلیجان اول یا دوم شو", play = "coach"},
	{id = "tirgan", name = "جشن تیرگان", from = [4, 10], to = [4, 16], keep = "کوزه‌ی تیرگان", money = 1200, rep = 10.0,
		about = "جشن آب و بارون. تابستونه و وقت جمع کردن یونجه برای زمستون.", count = "hay", n = 100, job = "%s بسته یونجه بخر یا بچین"},
	{id = "statefair", name = "نمایشگاه بزرگ ایالت", from = [5, 20], to = [5, 26], keep = "روبان طلایی ایالت", money = 1500, rep = 15.0,
		about = "بهترین گاوهای کل ایالت اومدن نمایشگاه. گاوت رو ببر جلوی داورها!", count = "show1", n = 1, job = "تو نمایشگاه گاو اول شو و روبان آبی بگیر", play = "show"},
	{id = "mehregan", name = "جشن مهرگان", from = [7, 10], to = [7, 16], keep = "سبد انار مهرگان", money = 1500, rep = 12.0,
		about = "جشن برداشت و مهربونی. بازار شلوغه و همه خریدارن.", count = "sale", n = 3000, job = "%s دلار گاو بفروش"},
	{id = "campfire", name = "شب آتیش گاوچرون‌ها", from = [8, 25], to = [9, 5], keep = "فانوس گاوچرون", money = 1200, rep = 10.0,
		about = "گاوچرون‌ها دور آتیش جمع می‌شن و قصه می‌گن. تاجرهای شهر هم دنبال گوشت خوبن.", count = "deal", n = 2, job = "%s تا قرارداد تحویل بده"},
	{id = "yalda", name = "شب یلدا", from = [9, 28], to = [10, 3], keep = "هندونه‌ی یلدا", money = 1500, rep = 15.0,
		about = "بلندترین شب سال. رنچ رو برای زمستون آماده کن.", count = "build", n = 2, job = "%s تا چیز بساز یا ارتقا بده"},
	{id = "sadeh", name = "جشن سده", from = [11, 7], to = [11, 13], keep = "مشعل سده", money = 1200, rep = 12.0,
		about = "آتیش بزرگ سده روشن شده و زمستون داره کم‌کم تموم می‌شه. وقت بزرگ کردن گله‌ست.", count = "cattle", n = 5, job = "%s تا گاو یا گوساله بخر"},
]
const MONTHS := ["فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور", "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند"]

var builder: Builder
var market: Market
var herd: Herd
var horses: Horses
var fair: Fair
var progress: Progress
var notify: Callable
var can_pop := func(): return true
var force := ""            # test: this festival is on whatever the date
var done := {}             # id -> Persian year its prize was won
var got := {}              # "id:year" -> amount counted so far
var played := {}           # id -> phone day it was last played (the race and the show: once a day)
var announced := {}        # id -> Persian year its board popped up
var _button: Button
var _mark: Label
var _panel: PanelContainer
var _dim: ColorRect
var _title := UiTheme.label("", 44)
var _about := UiTheme.label("", 25)
var _when := UiTheme.label("", 23, Color(0.32, 0.18, 0.08))
var _job := UiTheme.label("", 27)
var _prize := UiTheme.label("", 24, Color(0.32, 0.18, 0.08))
var _row := HBoxContainer.new()
var _t := 0.0


## Gregorian to Persian (solar hijri): [year, month, day].
static func jalali(gy: int, gm: int, gd: int) -> Array:
	var before := [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
	var gy2 := gy + 1 if gm > 2 else gy
	var days: int = 355666 + 365 * gy + (gy2 + 3) / 4 - (gy2 + 99) / 100 + (gy2 + 399) / 400 + gd + before[gm - 1]
	var jy := -1595 + 33 * (days / 12053)
	days %= 12053
	jy += 4 * (days / 1461)
	days %= 1461
	if days > 365:
		jy += (days - 1) / 365
		days = (days - 1) % 365
	if days < 186:
		return [jy, 1 + days / 31, 1 + days % 31]
	return [jy, 7 + (days - 186) / 30, 1 + (days - 186) % 30]


static func doy(m: int, d: int) -> int:
	return (m - 1) * 31 + d if m <= 6 else 186 + (m - 7) * 30 + d


## Today's Persian date from the phone's calendar.
static func today() -> Array:
	var t := Time.get_date_dict_from_system()
	return jalali(t.year, t.month, t.day)


## The festival on today, or {}.
func current() -> Dictionary:
	for f in LIST:
		if f.id == force:
			return f
	if force != "":
		return {}
	var j := today()
	var n := doy(j[1], j[2])
	for f in LIST:
		if n >= doy(f.from[0], f.from[1]) and n <= doy(f.to[0], f.to[1]):
			return f
	return {}


## Days left of it, today included.
func days_left(f: Dictionary) -> int:
	if f.id == force:
		return 3
	var j := today()
	return doy(f.to[0], f.to[1]) - doy(j[1], j[2]) + 1


## Days until it next starts (0 while it's on).
func days_until(f: Dictionary) -> int:
	if f == current():
		return 0
	var j := today()
	var d := doy(f.from[0], f.from[1]) - doy(j[1], j[2])
	return d if d > 0 else d + 365


static func dates(f: Dictionary) -> String:
	return "%s %s تا %s %s" % [UiTheme.fa(f.from[1]), MONTHS[f.from[0] - 1], UiTheme.fa(f.to[1]), MONTHS[f.to[0] - 1]]


func won(f: Dictionary) -> bool:
	return done.get(f.id, -1) == today()[0]


func _key(f: Dictionary) -> String:
	return "%s:%d" % [f.id, today()[0]]


func amount(f: Dictionary) -> int:
	return got.get(_key(f), 0)


static func job_text(f: Dictionary) -> String:
	return f.job % UiTheme.fa(f.n) if "%s" in f.job else f.job


func _ready() -> void:
	layer = 0  # under every board, like «امروز»
	_button = Button.new()
	_button.text = "جشن"
	_button.icon = load("res://ui/icons/party.png")
	_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_button.custom_minimum_size = Vector2(240, 104)
	_button.add_theme_font_size_override("font_size", 26)
	_button.position = Vector2(12, 232)  # under «امروز»
	_button.pressed.connect(toggle)
	add_child(_button)
	_mark = UiTheme.label("!", 30, Color.WHITE)
	var dot := StyleBoxFlat.new()
	dot.bg_color = Color(0.8, 0.12, 0.08)
	dot.set_corner_radius_all(18)
	dot.content_margin_left = 12
	dot.content_margin_right = 12
	_mark.add_theme_stylebox_override("normal", dot)
	_mark.position = Vector2(4, -4)
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.add_child(_mark)

	var over := CanvasLayer.new()
	over.layer = 3
	add_child(over)
	_dim = UiTheme.dim(toggle)
	_panel = UiTheme.board()
	over.add_child(_dim)
	over.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	_panel.add_child(col)
	var head := HBoxContainer.new()
	head.add_child(builder._button(Button.new(), "بستن", toggle, "cancel"))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	head.add_child(_title)
	UiTheme.center_head(head)
	col.add_child(head)
	for l: Label in [_about, _when, _job, _prize]:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(900, 0)
		col.add_child(l)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 16)
	col.add_child(_row)

	builder.money_moved.connect(_on_money)
	market.sold.connect(func(_cash: int, contract: bool):
		if contract:
			_count("deal", 1))
	herd.born.connect(func(): _count("born", 1))
	horses.foaled.connect(func(_h): _count("born", 1))
	fair.won.connect(func(kind: String, place: int):
		if kind == "coach" and place <= 2:
			_count("coach", 1)
		if kind == "show" and place == 1:
			_count("show1", 1))
	_refresh()


func _on_money(delta: int, why: String) -> void:
	match why:
		"sale":
			if delta > 0:
				_count("sale", delta)
		"cattle":
			if delta < 0:
				_count("cattle", 1)
		"hay":
			if delta <= 0:
				_count("hay", HerdUI.HAY_LOT)
		"build":
			if delta < 0:
				_count("build", 1)


func _count(kind: String, n: int) -> void:
	var f := current()
	if f.is_empty() or f.count != kind or won(f):
		return
	got[_key(f)] = amount(f) + n
	if amount(f) >= f.n:
		done[f.id] = today()[0]
		builder.add_money(f.money, "prize")
		progress.add(f.rep)
		notify.call("کار «%s» رو انجام دادی! %s دلار و «%s» برای دفترچه‌ی کلکسیون" % [f.name, UiTheme.fa(f.money), f.keep])
		changed.emit()
	_refresh()


func toggle() -> void:
	_panel.visible = not _panel.visible and not current().is_empty()
	_dim.visible = _panel.visible
	_refresh()


func _refresh() -> void:
	var f := current()
	_button.visible = not f.is_empty()
	if f.is_empty():
		return
	_mark.visible = not won(f)
	if not _panel.visible:
		return
	_title.text = f.name
	_about.text = f.about
	var left := days_left(f)
	_when.text = "%s؛ %s" % [dates(f), "امروز روز آخره!" if left <= 1 else "%s روز دیگه تموم می‌شه" % UiTheme.fa(left)]
	if won(f):
		_job.text = "✓  %s" % job_text(f)
		_prize.text = "جایزه‌ش رو گرفتی: «%s» تو دفترچه‌ی کلکسیونته. سال دیگه دوباره میاد." % f.keep
	else:
		_job.text = "کار این جشن: %s" % job_text(f) + ("  (%s از %s)" % [UiTheme.fa(mini(amount(f), f.n)), UiTheme.fa(f.n)] if f.n > 1 else "")
		_prize.text = "جایزه: %s دلار و «%s» برای دفترچه‌ی کلکسیون؛ «%s» فقط تو همین جشن درمیاد." % [UiTheme.fa(f.money), f.keep, f.keep]
	for c in _row.get_children():
		c.queue_free()
	if f.has("play") and not won(f):
		var today_n := Daily.today()
		var again: bool = played.get(f.id, -1) == today_n
		var label := "فردا دوباره بیا" if again else ("بریم مسابقه" if f.play == "coach" else "بریم نمایشگاه")
		var b := builder._button(Button.new(), label, func():
			played[f.id] = Daily.today()
			toggle()
			fair.festival(f.play, f.name, f.id), "horse" if f.play == "coach" else "cow")
		b.disabled = again or (f.play == "show" and fair._show_cows().is_empty())
		_row.add_child(b)
		if f.play == "show" and fair._show_cows().is_empty():
			_prize.text += "\nبرای نمایشگاه یه گاو دست‌کم %s کیلویی لازمه." % UiTheme.fa(int(Fair.SHOW_KG))


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 2.0
	_refresh()
	var f := current()
	if f.is_empty() or announced.get(f.id, -1) == today()[0] or not can_pop.call():
		return
	announced[f.id] = today()[0]  # a new festival: its board pops up once
	if not _panel.visible:
		toggle()


func to_save() -> Dictionary:
	return {done = done, got = got, played = played, announced = announced}


func from_save(d: Dictionary) -> void:
	for k in ["done", "got", "played", "announced"]:
		var src: Dictionary = d.get(k, {})
		var dst: Dictionary = get(k)
		for key in src:
			dst[key] = int(src[key])
