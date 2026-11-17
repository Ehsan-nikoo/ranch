## Trouble on the ranch: drought, blizzard, wolves, rustlers, sickness going round, a broken windmill.
## Some mornings one turns up and a board asks what to do: pay to be safe, or take the risk.
## Hands with the right skill (see Workers) deal with some of it on their own. Time stops while the
## board is open. Lasting effects reach the herd through its multipliers.
class_name Events
extends CanvasLayer

const CHANCE := 0.4        # chance of trouble on a morning, once COOLDOWN days have passed since the last
const COOLDOWN := 2
const DROUGHT_DAYS := 2

var day: DayCycle
var herd: Herd
var builder: Builder
var workers: Workers
var notify: Callable
var world: Node3D

var effects := {}          # name -> game hour (day * 24 + hour) it ends
var pending: Array = []    # {at, what}: night raids play out by morning
var last := -10            # day of the last event
var _panel: PanelContainer
var _dim: ColorRect
var _title := UiTheme.label("", 40)
var _text := UiTheme.label("", 25)
var _row := HBoxContainer.new()
var _speed := 1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	layer = 5  # over the other boards
	_dim = UiTheme.dim(func(): pass)  # a choice must be made: tapping outside does nothing
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
	_row.add_theme_constant_override("separation", 16)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_row)


func now() -> float:
	return day.day * 24.0 + day.hour


func active(name: String) -> bool:
	return effects.get(name, -1.0) > now()


func _process(_delta: float) -> void:
	herd.growth_mul = 0.15 if active("drought") else 1.0
	herd.thirst_mul = 1.6 if active("drought_dry") else 1.0
	herd.cold_mul = 3.0 if active("blizzard") else 1.0
	if effects.has("windmill") and not active("windmill"):
		effects.erase("windmill")
		_set_broken(false)
		notify.call("آسیاب بادی دوباره کار می‌کنه")
	for p in pending.duplicate():
		if now() >= p.at:
			pending.erase(p)
			call("_resolve_" + p.what)


## Called at each day change, after the market.
func new_day(d: int) -> void:
	if d - last < COOLDOWN or _panel.visible or _rng.randf() > CHANCE:
		return
	var s := day.season()
	var n := herd.alive().size()
	var pool := []  # [weight, event]
	if s in [DayCycle.SUMMER, DayCycle.AUTUMN] and not active("drought"):
		pool.append([3, _drought])
	if s == DayCycle.WINTER and not active("blizzard"):
		pool.append([4, _blizzard])
	if s != DayCycle.SUMMER and n > 0:
		pool.append([3, _wolves])
	if n >= 10:
		pool.append([2, _rustlers])
	if s in [DayCycle.SPRING, DayCycle.SUMMER] and n > 0:
		pool.append([2, _outbreak])
	var smith := world.get_children().any(func(b): return b is Blacksmith and not b.has_node("Marker"))
	if _windmills().size() > 0 and not effects.has("windmill") and not smith:  # the smith keeps them mended
		pool.append([2, _windmill])
	if pool.is_empty():
		return
	var total: int = pool.reduce(func(a, e): return a + e[0], 0)
	var r := _rng.randi_range(1, total)
	for e in pool:
		r -= e[0]
		if r <= 0:
			last = d
			e[1].call()
			return


# ---------- the board ----------

## options: [[label, cost, icon, Callable]]; a cost the player can't pay disables that choice.
func _ask(title: String, text: String, options: Array) -> void:
	_title.text = title
	_text.text = text
	for c in _row.get_children():
		c.queue_free()
	for o in options:
		var cost: int = o[1]
		var label: String = o[0] if cost == 0 else "%s  %s دلار" % [o[0], UiTheme.fa(cost)]
		var b := builder._button(Button.new(), label, func():
			if cost > 0:
				builder.add_money(-cost)
			_close()
			o[3].call(), o[2])
		b.disabled = builder.money < cost
		_row.add_child(b)
	_speed = day.speed if day.speed > 0.0 else _speed
	day.speed = 0.0  # the ranch waits for your answer
	_panel.visible = true
	_dim.visible = true


func _close() -> void:
	_panel.visible = false
	_dim.visible = false
	day.speed = _speed


# ---------- the events ----------

func _drought() -> void:
	var until := now() + DROUGHT_DAYS * 24.0
	effects.drought = until
	var hand := workers.best(Workers.HAND)
	if hand >= 2:
		notify.call("خشکسالی شد؛ کارگرت با تانکر آب میاره، ولی تا %s روز علف درست درنمیاد" % UiTheme.fa(DROUGHT_DAYS))
		return
	_ask("خشکسالی", "خیلی وقته بارون نیومده و دشت داره خشک می‌شه. تا %s روز علف درست درنمیاد و آب کم میاد، برای همین گاوها خیلی زود تشنه می‌شن." % UiTheme.fa(DROUGHT_DAYS), [
		["تانکر آب بیار", 300, "hay", func(): notify.call("تانکر آب اومد؛ گاوها تشنه نمی‌مونن")],
		["ریسک کن", 0, "cancel", func(): effects.drought_dry = until],
	])


func _blizzard() -> void:
	var until := now() + 24.0
	if workers.best(Workers.MECHANIC) >= 2:
		notify.call("کولاک اومد؛ تعمیرکارت از قبل طویله رو آماده کرده بود")
		return
	_ask("کولاک", "یه کولاک بد تو راهه و تا فردا همین موقع ول نمی‌کنه. گاوهایی که تو طویله جا ندارن، از سرما سه برابر بیشتر لاغر می‌شن.", [
		["دیوار جلوی باد بزن", 250, "barn", func(): notify.call("جلوی باد رو گرفتین؛ کولاک به گله آسیب نمی‌زنه")],
		["ریسک کن", 0, "cancel", func():
			effects.blizzard = until
			notify.call("کولاک شروع شد؛ گاوهای بیرون از طویله سرما می‌خورن")],
	])


func _wolves() -> void:
	if workers.best(Workers.RIDER) >= 1:
		notify.call("دیشب گرگ‌ها دور گله می‌چرخیدن؛ نگهبان شبت فراریشون داد")
		return
	_ask("گرگ‌ها", "صدای زوزه‌ی گرگ‌ها از تپه‌ها میاد و کنار حصار ردپاشون پیدا شده. امشب میان سراغ گله، اونم اول سراغ گوساله‌ها.", [
		["یه نگهبان برای امشب", 200, "worker", func(): notify.call("نگهبان تا صبح دور گله می‌چرخه")],
		["ریسک کن", 0, "cancel", func(): pending.append({at = _next_morning(), what = "wolves"})],
	])


func _resolve_wolves() -> void:
	if _rng.randf() < 0.65:
		var n := herd.take(_rng.randi_range(1, 2), true)
		notify.call("گرگ‌ها دیشب %s تا از گله رو بردن" % UiTheme.fa(n))
	else:
		notify.call("گرگ‌ها دیشب نزدیک نشدن؛ شانس آوردی")


func _rustlers() -> void:
	if workers.best(Workers.RIDER) >= 2:
		notify.call("دیشب دزدها اومدن، ولی نگهبان شبت بیرونشون کرد")
		return
	_ask("دزد گاو", "تو شهر می‌گن چندتا دزد گاو این طرفا پیداشون شده و دنبال گاوهای چاقن. شاید امشب بیان سراغ رنچ تو.", [
		["نگهبان تفنگ‌دار", 350, "place", func(): notify.call("نگهبان‌ها تا صبح بیدار می‌مونن")],
		["به کلانتر بگو", 50, "market", func(): pending.append({at = _next_morning(), what = "sheriff"})],
		["ریسک کن", 0, "cancel", func(): pending.append({at = _next_morning(), what = "rustlers"})],
	])


func _resolve_rustlers() -> void:
	if _rng.randf() < 0.7:
		var n := herd.take(_rng.randi_range(2, 4), false)
		notify.call("دزدها دیشب %s تا از گاوهای چاق رو بردن" % UiTheme.fa(n))
	else:
		notify.call("دزدها دیشب سراغ رنچ تو نیومدن")


func _resolve_sheriff() -> void:
	if _rng.randf() < 0.5:
		builder.add_money(150)
		notify.call("کلانتر دزدها رو گرفت و ۱۵۰ دلار جایزه گرفتی")
	else:
		_resolve_rustlers()


func _outbreak() -> void:
	var n := herd.unvaccinated().size()
	if n == 0:
		notify.call("تو رنچ‌های همسایه مریضی اومده؛ گاوهای تو واکسن زدن و چیزیشون نمی‌شه")
		return
	_ask("مریضی تو همسایه‌ها", "گاوهای رنچ‌های همسایه تب کردن و داره پخش می‌شه. %s تا از گاوهای تو واکسن نزدن و ممکنه بگیرن." % UiTheme.fa(n), [
		["همین الان واکسن بزن", BreedUI.VACCINE * n, "vaccine", func(): notify.call("%s تا گاو واکسن زدن" % UiTheme.fa(herd.vaccinate()))],
		["ریسک کن", 0, "cancel", func():
			var sick := herd.outbreak(0.35)
			notify.call("%s تا گاو مریض شدن؛ دامپزشک رو صدا کن" % UiTheme.fa(sick) if sick > 0 else "مریضی به گله‌ی تو نرسید")],
	])


func _windmill() -> void:
	if workers.best(Workers.MECHANIC) >= 1:
		notify.call("باد پره‌ی آسیاب رو شکست؛ تعمیرکارت همون موقع درستش کرد")
		return
	var until := now() + 24.0
	_ask("آسیاب بادی شکست", "باد دیشب پره‌های آسیاب بادی رو شکسته و دیگه آب نمیاره. تا درست نشه، گاوها از آب‌خوریش نمی‌تونن آب بخورن.", [
		["از شهر تعمیرکار بیار", 180, "windmill", func(): notify.call("آسیاب بادی تعمیر شد")],
		["خودت درستش کن (یه روز طول می‌کشه)", 0, "build", func():
			effects.windmill = until
			_set_broken(true)
			notify.call("تا فردا آسیاب بادی آب نمیاره")],
	])


func _windmills() -> Array:
	return world.get_children().filter(func(n): return n is Windmill and not n.has_node("Marker"))


## Breaks (or mends) the windmills; with more than one, the first keeps pumping so the herd isn't left dry.
func _set_broken(on: bool) -> void:
	var mills := _windmills()
	for i in mills.size():
		mills[i].broken = on and (i > 0 or mills.size() == 1)


func _next_morning() -> float:
	return (day.day + (1 if day.hour >= 6.0 else 0)) * 24.0 + 6.0


func to_save() -> Dictionary:
	return {effects = effects, pending = pending, last = last}


func from_save(d: Dictionary) -> void:
	effects = d.effects
	pending = d.pending
	last = int(d.last)
	if active("windmill"):
		_set_broken.call_deferred(true)
