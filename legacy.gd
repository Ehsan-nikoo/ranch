## Three generations: when a new era begins (Progress.ERAS) the ranch passes to the children, with a
## board that sums up how the last generation did; after the third the story ends with a final score
## and a title for the family. You can keep playing past the end or start a new ranch.
class_name Legacy
extends Node

const END_YEAR := 8           # the third generation hands over at the start of year 9
const TITLES := [[0, "یه رنچ کوچیک خانوادگی"], [25000, "یه رنچ آبرومند"], [70000, "رنچ بزرگ دشت"], [160000, "افسانه‌ی سه نسل"]]
const HANDOVER := [
	"",
	"پدربزرگ دیگه پیر شده و رنچ رو سپرد دست بچه‌هاش. حالا نسل دوم کار رو ادامه می‌ده.",
	"بچه‌ها هم موهاشون سفید شد؛ حالا نوه‌ها رنچ رو می‌چرخونن. این آخرین نسل داستانه.",
]

var day: DayCycle
var herd: Herd
var market: Market
var builder: Builder
var progress: Progress
var goals: Goals
var events: Events
var restart: Callable
var seen: Array = []           # era indices whose board was shown, and "end"
var start := {money = 6000, herd = 8, rep = 0.0}   # where this generation began


func _year_days() -> int:
	return DayCycle.DAYS_PER_SEASON * 4


## Cattle at today's prices: feeders by weight, breeding stock at what they'd cost to buy.
func herd_value() -> int:
	var v := 0.0
	for c in herd.alive():
		match c.kind:
			Herd.FEEDER:
				v += c.weight * market.price
			Herd.BREEDER:
				v += market.heifer_price()
			_:
				v += market.bull_price()
	return int(v)


func score() -> int:
	return builder.money + herd_value() + int(progress.rep) * 20 + goals.done.size() * 500


static func title(s: int) -> String:
	var t: String = TITLES[0][1]
	for x in TITLES:
		if s >= x[0]:
			t = x[1]
	return t


func _summary() -> String:
	var gained := builder.money - int(start.money)
	return "تو این نسل:  پول %s%s دلار،  گله از %s به %s تا گاو،  شهرت %s امتیاز بیشتر شد" % [
		"+" if gained >= 0 else "-", UiTheme.fa(absi(gained)), UiTheme.fa(int(start.herd)), UiTheme.fa(herd.alive().size()),
		UiTheme.fa(maxi(0, int(progress.rep - float(start.rep))))]


func _snapshot() -> void:
	start = {money = builder.money, herd = herd.alive().size(), rep = progress.rep}


func new_day(d: int) -> void:
	if d % _year_days() != 0:
		return
	var y := d / _year_days()
	if y >= END_YEAR and not "end" in seen:
		seen.append("end")
		_ending()
		return
	var e := progress.era()
	if e > 0 and y == Progress.ERAS[e][0] and not e in seen:
		seen.append(e)
		events._ask(Progress.ERAS[e][1], "%s\n%s\n\n%s" % [HANDOVER[e], Progress.ERAS[e][3], _summary()],
			[["بریم که داشته باشیم", 0, "star", func(): pass]])
		_snapshot()


func _ending() -> void:
	var s := score()
	var text := "سه نسل گذشت و داستان رنچ شما به آخرش رسید.\n%s\n\nپول: %s دلار    گله: %s تا گاو (ارزشش %s دلار)\nشهرت: %s    هدف‌های انجام‌شده: %s از %s\n\nامتیاز نهایی: %s\nلقب خانواده‌ت: «%s»" % [
		_summary(), UiTheme.fa(builder.money), UiTheme.fa(herd.alive().size()), UiTheme.fa(herd_value()),
		Progress.NAMES[progress.level() - 1], UiTheme.fa(goals.done.size()), UiTheme.fa(Goals.LIST.size()),
		UiTheme.fa(s), title(s)]
	events._ask("پایان سه نسل", text, [
		["ادامه بده", 0, "star", func(): pass],
		["یه رنچ تازه شروع کن", 0, "cancel", restart],
	])


func to_save() -> Dictionary:
	return {seen = seen, start = start}


func from_save(d: Dictionary) -> void:
	seen = d.seen.map(func(x): return int(x) if x is float else x)
	start = d.start
