## Three generations: when a new era begins (Progress.ERAS) the ranch passes to the children and a
## notice sums up how the last generation did; after the third a notice gives the family's final score
## and title. Only notices: the game never stops, the player just keeps going.
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
var notify: Callable
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
		notify.call("%s\n%s\n%s\n%s" % [Progress.ERAS[e][1], HANDOVER[e], Progress.ERAS[e][3], _summary()])
		_snapshot()


func _ending() -> void:
	var s := score()
	notify.call("سه نسل گذشت! %s\nامتیاز خانواده‌ت: %s  -  لقبتون: «%s»\nرنچ مال خودته، هر چقدر خواستی ادامه بده" % [
		_summary(), UiTheme.fa(s), title(s)])


func to_save() -> Dictionary:
	return {seen = seen, start = start}


func from_save(d: Dictionary) -> void:
	seen = d.seen.map(func(x): return int(x) if x is float else x)
	start = d.start
