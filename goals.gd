## Goals: a ladder of small targets ("have 25 cows", "deliver 3 contracts") with a cash and reputation
## prize each. Three are open at a time, shown on the ranch board; finishing one opens the next.
class_name Goals
extends Node

signal changed

# id, text, what's counted, target, prize in dollars, reputation
const LIST := [
	["herd10", "گله‌ت رو برسون به %s تا گاو", "herd", 10, 400, 5],
	["sell1", "اولین بار گاوهای آماده رو بفروش", "sales", 1, 300, 5],
	["hay", "انبار یونجه رو برسون به %s بسته", "hay", 60, 300, 5],
	["hand1", "یه کارگر بیار سر کار", "hands", 1, 300, 5],
	["pond", "یه آبگیر بساز", "pond", 1, 400, 5],
	["calf1", "صبر کن اولین گوساله‌ت به دنیا بیاد", "births", 1, 500, 10],
	["deal3", "%s تا قرارداد رو به موقع تحویل بده", "deals", 3, 1000, 15],
	["herd25", "گله‌ت رو برسون به %s تا گاو", "herd", 25, 1000, 10],
	["land1", "یه تیکه زمین تازه بخر", "land", 1, 1000, 10],
	["kennel", "سگدونی بساز", "kennel", 1, 500, 5],
	["stable", "اصطبل اسب بساز", "stable", 1, 800, 10],
	["tower", "برج دیده‌بانی بساز", "tower", 1, 800, 10],
	["feedlot", "آغل چاق‌کنی بساز", "feedlot", 1, 1200, 10],
	["sell10", "%s بار گاو بفروش", "sales", 10, 1500, 15],
	["hand3", "%s تا کارگر داشته باش", "hands", 3, 1000, 10],
	["herd50", "گله‌ت رو برسون به %s تا گاو", "herd", 50, 2500, 20],
	["deal10", "%s تا قرارداد رو به موقع تحویل بده", "deals", 10, 3000, 25],
	["calf20", "%s تا گوساله تو رنچت به دنیا بیاد", "births", 20, 2500, 20],
	["clinic", "دامپزشکی بساز", "clinic", 1, 1000, 10],
	["rodeo", "میدون گاوسواری بساز", "rodeo", 1, 2000, 20],
	["cafe", "کافه بساز", "cafe", 1, 1500, 15],
	["station", "ایستگاه قطار بساز", "station", 1, 3000, 25],
	["cash50", "%s دلار پول جمع کن", "money", 50000, 0, 50],
	["herd100", "گله‌ت رو برسون به %s تا گاو", "herd", 100, 6000, 40],
	["land4", "%s تیکه زمین تازه داشته باش", "land", 4, 5000, 30],
]
const OPEN := 3
var BUILT := {stable = HorseStable, rodeo = RodeoArena, pond = Pond, kennel = Kennel, tower = Watchtower,
	feedlot = Feedlot, clinic = VetClinic, cafe = Saloon, station = Station}  # "build one" goals

var herd: Herd
var market: Market
var workers: Workers
var builder: Builder
var progress: Progress
var land: Land
var notify: Callable
var done: Array = []          # ids
var count := {sales = 0, births = 0, deals = 0}
var _t := 0.0


func hook() -> void:
	market.sold.connect(func(_cash: int, contract: bool):
		count.sales += 1
		if contract:
			count.deals += 1)
	herd.born.connect(func(): count.births += 1)


## How far along a goal is, counted the way its kind says.
func value(kind: String) -> int:
	match kind:
		"herd":
			return herd.alive().size()
		"hay":
			return herd.hay
		"hands":
			return workers.hired.size()
		"land":
			return land.owned.count(1) - 4   # the middle four come with the ranch
		"money":
			return builder.money
	if BUILT.has(kind):
		return 1 if progress.has(BUILT[kind]) else 0
	return count.get(kind, 0)


## The goals being worked on now: the first OPEN not yet done, in order.
func open() -> Array:
	return LIST.filter(func(g): return not g[0] in done).slice(0, OPEN)


static func text(g: Array) -> String:
	return g[1] % UiTheme.fa(g[3]) if "%s" in g[1] else g[1]


static func prize(g: Array) -> String:
	var parts := []
	if g[4] > 0:
		parts.append("%s دلار" % UiTheme.fa(g[4]))
	parts.append("%s امتیاز شهرت" % UiTheme.fa(g[5]))
	return " و ".join(parts)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	for g in open():
		if value(g[2]) >= g[3]:
			done.append(g[0])
			if g[4] > 0:
				builder.add_money(g[4], "prize")
			progress.add(g[5])
			notify.call("هدف انجام شد: %s!  جایزه: %s" % [text(g), prize(g)])
			changed.emit()


func to_save() -> Dictionary:
	return {done = done, count = count}


func from_save(d: Dictionary) -> void:
	done = d.done
	for k in count:
		count[k] = int(d.count.get(k, 0))
