## Small good surprises: some mornings something nice turns up. A travelling trader with the rare
## white breed (it's never sold in town), a stray calf, gold in the pond, an old chest in the barn,
## wild honey, a tired traveller who leaves a gift, the town paper writing about the ranch, a good
## rain, the neighbours lending a hand on the building site, and twin calves now and then. Never on a
## morning trouble came (see Events). Each kind, the first time, goes in the collection book.
class_name Surprises
extends Node

signal found(kind: String)

const CHANCE := 0.3        # chance of a surprise on a morning, once COOLDOWN days have passed since the last
const COOLDOWN := 2
const NAMES := {
	trader = "تاجر دوره‌گرد", stray = "گوساله‌ی گمشده", gold = "طلا تو آبگیر", chest = "صندوق قدیمی", honey = "عسل وحشی",
	traveller = "مسافر خسته", paper = "روزنامه‌ی شهر", rain = "بارون خوب", helpers = "کمک همسایه‌ها", twins = "گوساله‌ی دوقلو",
}
const ORDER := ["twins", "trader", "stray", "gold", "chest", "honey", "traveller", "paper", "rain", "helpers"]
const WHITE := 3           # Herd.BREEDS: the white breed

var day: DayCycle
var herd: Herd
var builder: Builder
var market: Market
var events: Events
var progress: Progress
var world: Node3D
var notify: Callable
var last := -10            # day of the last surprise
var guest := false         # the traveller slept in the barn: his thanks come in the morning
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	herd.twins.connect(func(mother: String):
		notify.call("«%s» دوقلو زایید! دو تا گوساله با هم" % mother)
		found.emit("twins"))


## Called at each day change, after the trouble.
func new_day(d: int) -> void:
	if guest:
		guest = false
		var cash := _rng.randi_range(10, 30) * 10
		builder.add_money(cash, "prize")
		progress.add(3.0)
		notify.call("مسافر دیشبی صبح زود رفت و یه کیسه پول با یه یادداشت تشکر جا گذاشت:  %s+ دلار" % UiTheme.fa(cash))
	if d - last < COOLDOWN or events.last == d or events.is_open() or _rng.randf() > CHANCE:
		return
	var pool := []  # [weight, kind]
	var n := herd.alive().size()
	if n > 0 and n < Herd.MAX_COWS - 2:
		pool.append([3, "trader"])
		pool.append([2, "stray"])
	if Building.built(world, Pond):
		pool.append([2, "gold"])
	if Building.built(world, Barn) or Building.built(world, HayShed):
		pool.append([2, "chest"])
	if day.season() in [DayCycle.SPRING, DayCycle.SUMMER]:
		pool.append([2, "honey"])
	pool.append([2, "traveller"])
	if progress.level() >= 2 or n >= 10:
		pool.append([2, "paper"])
	if day.season() != DayCycle.WINTER and _grass_left() < 0.6:
		pool.append([3, "rain"])
	if not builder.sites.is_empty():
		pool.append([3, "helpers"])
	var total: int = pool.reduce(func(a, e): return a + e[0], 0)
	var r := _rng.randi_range(1, total)
	for e in pool:
		r -= e[0]
		if r <= 0:
			last = d
			call("_" + e[1])
			found.emit(e[1])
			return


## Share of the grass still standing on the ranch's grassland.
func _grass_left() -> float:
	var have := 0.0
	var cap := 0.0
	for i in herd.grass.size():
		have += herd.grass[i]
		cap += herd.grass_cap[i]
	return have / maxf(cap, 0.001)


func _spot() -> Vector3:
	return herd.free_spot(Vector3(22, 0, 18), 9.0)


func _trader() -> void:
	var heifer := int(roundf(market.heifer_price() * 1.6 / 10.0) * 10.0)
	var calf := int(roundf(market.calf_price() * Herd.BREEDS[WHITE].calf / 10.0) * 10.0)
	events._ask("تاجر دوره‌گرد", "یه تاجر دوره‌گرد با گاری‌ش اومده دم در رنچ. گاو سفید داره؛ این نژاد تو شهر پیدا نمی‌شه، زود چاق می‌شه، گوشتش گرون‌تره و گوساله‌هاش هم سفید درمیان.", [
		["تلیسه‌ی سفید", heifer, "cow", func():
			var c := herd.add_cow(_spot(), 420.0, Herd.BREEDER, 1, WHITE)
			notify.call("«%s»، یه تلیسه‌ی سفید، اومد تو گله؛ گوساله‌هاش هم سفید می‌شن" % c.get("name", ""))],
		["گوساله‌ی سفید", calf, "cow", func():
			var c := herd.add_cow(_spot(), 160.0, Herd.FEEDER, -1, WHITE)
			notify.call("«%s»، یه گوساله‌ی سفید، اومد تو گله" % c.get("name", ""))],
		["نه، مرسی", 0, "cancel", func(): notify.call("تاجر سری تکون داد و رفت سمت شهر")],
	])


func _stray() -> void:
	events._ask("گوساله‌ی گمشده", "یه گوساله‌ی بی‌صاحب از دشت اومده قاطی گله‌ت. چند روزه کسی دنبالش نیومده.", [
		["نگهش دار", 0, "cow", func():
			var c := herd.add_cow(_spot(), 160.0, Herd.FEEDER, -1, _rng.randi() % Herd.BUY_BREEDS)
			notify.call("«%s» حالا مال توئه" % c.get("name", ""))],
		["ببرش پیش کلانتر", 0, "star", func():
			builder.add_money(80, "prize")
			progress.add(5.0)
			notify.call("کلانتر صاحبش رو پیدا کرد و ۸۰ دلار مژدگونی داد؛ همه می‌گن رنچت درستکاره")],
	])


func _gold() -> void:
	var cash := _rng.randi_range(15, 40) * 10
	builder.add_money(cash, "prize")
	notify.call("یکی از کارگرها تو گل‌ولای آبگیر یه تیکه طلا پیدا کرد! فروختیش:  %s+ دلار" % UiTheme.fa(cash))


func _chest() -> void:
	var cash := _rng.randi_range(20, 45) * 10
	builder.add_money(cash, "prize")
	notify.call("موقع تمیز کردن انبار یه صندوق قدیمی پیدا شد؛ توش چندتا سکه‌ی قدیمی بود:  %s+ دلار" % UiTheme.fa(cash))


func _honey() -> void:
	var cash := _rng.randi_range(10, 22) * 10
	builder.add_money(cash, "prize")
	notify.call("تو یه درخت کنار رنچ کندوی عسل وحشی پیدا شد؛ عسلش رو فروختی:  %s+ دلار" % UiTheme.fa(cash))


func _traveller() -> void:
	events._ask("مسافر خسته", "یه مسافر خسته در زده؛ می‌خواد یه شب تو انبار بخوابه و صبح زود بره.", [
		["آره، بیاد تو", 0, "house", func():
			guest = true
			notify.call("مسافر یه کاسه آش خورد و رفت تو انبار خوابید")],
		["نه", 0, "cancel", func(): notify.call("مسافر راهش رو کشید و رفت")],
	])


func _paper() -> void:
	progress.add(8.0)
	notify.call("روزنامه‌ی شهر درباره‌ی رنچت نوشته! همه دارن ازش حرف می‌زنن")


func _rain() -> void:
	for i in herd.grass.size():
		herd.grass[i] = herd.grass_cap[i]
	herd.grass_tex.update(herd._grass_image())
	notify.call("دیشب یه بارون خوب اومد و علف همه‌جا دوباره دراومد")


func _helpers() -> void:
	var b: Building = builder.sites[0]
	b.work_left *= 0.5
	b.site.show_at(1.0 - b.work_left / b.work_total)
	notify.call("همسایه‌ها اومدن کمک و کار ساختمون نصفش جلو افتاد")


func to_save() -> Dictionary:
	return {last = last, guest = guest}


func from_save(d: Dictionary) -> void:
	last = int(d.get("last", -10))
	guest = bool(d.get("guest", false))
