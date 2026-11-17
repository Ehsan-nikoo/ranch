## Generations: every GENERATION years the ranch passes to the next generation of the family and a
## notice sums up how the last one did. It never ends; the first handovers also bring a new era
## (Progress.ERAS: the railroad, then the cities). Only notices: the game never stops.
class_name Legacy
extends Node

const GENERATION := 70        # years each generation runs the ranch
const HANDOVER := [
	"",
	"پدربزرگ دیگه پیر شده و رنچ رو سپرد دست بچه‌هاش. حالا نسل دوم کار رو ادامه می‌ده.",
	"بچه‌ها هم موهاشون سفید شد؛ حالا نوه‌ها رنچ رو می‌چرخونن.",
]

var day: DayCycle
var herd: Herd
var market: Market
var builder: Builder
var progress: Progress
var goals: Goals
var notify: Callable
var seen: Array = []           # generations whose handover was announced
var start := {money = 6000, herd = 8, rep = 0.0}   # where this generation began


func _year_days() -> int:
	return DayCycle.DAYS_PER_SEASON * 4


func _summary() -> String:
	var gained := builder.money - int(start.money)
	return "تو این نسل:  پول %s%s دلار،  گله از %s به %s تا گاو،  شهرت %s امتیاز بیشتر شد" % [
		"+" if gained >= 0 else "-", UiTheme.fa(absi(gained)), UiTheme.fa(int(start.herd)), UiTheme.fa(herd.alive().size()),
		UiTheme.fa(maxi(0, int(progress.rep - float(start.rep))))]


func _snapshot() -> void:
	start = {money = builder.money, herd = herd.alive().size(), rep = progress.rep}


## The handover text for generation `g` (1 = the children of the founder).
func _handover(g: int) -> String:
	var lines := []
	var e := progress.era()
	if e > 0 and g == e:  # this handover also starts a new era
		lines.append(Progress.ERAS[e][1])
	lines.append(HANDOVER[g] if g < HANDOVER.size() else "نسل %s خانواده‌ت حالا رنچ رو می‌چرخونه." % UiTheme.fa(g + 1))
	if e > 0 and g == e and Progress.ERAS[e][3] != "":
		lines.append(Progress.ERAS[e][3])
	lines.append(_summary())
	return "\n".join(lines)


func new_day(d: int) -> void:
	if d % _year_days() != 0:
		return
	var y := d / _year_days()
	if y == 0 or y % GENERATION != 0:
		return
	var g := y / GENERATION
	if g in seen:
		return
	seen.append(g)
	notify.call(_handover(g))
	_snapshot()


func to_save() -> Dictionary:
	return {seen = seen, start = start}


func from_save(d: Dictionary) -> void:
	seen = d.seen.filter(func(x): return x is float or x is int).map(func(x): return int(x))
	start = d.start
