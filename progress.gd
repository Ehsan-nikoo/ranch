## The long game: the ranch's reputation and the era it lives in.
## Reputation grows with every sale and delivered contract and drops with missed contracts and dead
## cattle. Each level unlocks a building: horse stable, blacksmith, rodeo arena.
## Eras follow the calendar, one generation of the family each: open range, then the railroad comes
## and lifts cattle prices, then the cities grow and lift them again.
class_name Progress
extends Node

signal changed

const LEVELS := [0, 100, 300, 650, 1300]    # reputation needed for each level
const NAMES := ["رنچ تازه‌کار", "رنچ آشنا", "رنچ سرشناس", "رنچ مشهور", "افسانه‌ی دشت"]
const UNLOCKS := ["", "اصطبل اسب، برج دیده‌بانی، آغل چاق‌کنی و دامپزشکی", "آهنگری و کافه", "میدون گاوسواری", "قراردادهای پرسودتر"]
# first year (counted from 0), name, cattle price multiplier, news
const ERAS := [
	[0, "نسل اول: دشت باز", 1.0, ""],
	[2, "نسل دوم: راه‌آهن اومد", 1.2, "راه‌آهن رسید به شهر! حالا گاوها رو با قطار می‌برن شهرهای بزرگ و قیمت‌ها رفت بالا. از «ساخت» می‌تونی ایستگاه قطار خودت رو بسازی"],
	[5, "نسل سوم: شهرها بزرگ شدن", 1.35, "شهرها بزرگ شدن و گوشت گرون‌تر شد؛ حالا نوه‌ها رنچ رو می‌چرخونن"],
]
const RODEO_PURSE := 500   # gate takings at the seasonal rodeo, plus 150 per reputation level
const CAFE_TAKE := 250     # the café's takings each season, plus 100 per reputation level
const STATION_BONUS := 1.1 # cattle sent by train fetch this much more
const FEEDLOT := [1.3, 1.2]  # the fattening pen: sale cattle gain this much faster and eat this much more

var day: DayCycle
var market: Market
var builder: Builder
var notify: Callable
var world: Node3D
var herd: Herd
var rep := 0.0


func level() -> int:
	var l := 1
	for i in LEVELS.size():
		if rep >= LEVELS[i]:
			l = i + 1
	return l


func next_level_at() -> int:
	return LEVELS[level()] if level() < LEVELS.size() else -1


func year() -> int:
	return day.day / (DayCycle.DAYS_PER_SEASON * 4)


func era() -> int:
	var e := 0
	for i in ERAS.size():
		if year() >= ERAS[i][0]:
			e = i
	return e


func add(points: float) -> void:
	var before := level()
	rep = maxf(0.0, rep + points)
	if level() > before:
		notify.call("رنچت معروف‌تر شد: «%s»! حالا %s رو داری" % [NAMES[level() - 1], UNLOCKS[level() - 1]])
	_apply()
	changed.emit()


## Era prices and the level's perks, passed on to the market.
func _apply() -> void:
	var train := has(Station)
	market.era_mul = ERAS[era()][2]
	market.max_offers = 2 + (1 if level() >= 3 else 0) + (1 if level() >= 5 else 0) + (1 if train else 0)
	market.premium = 1.1 if level() >= 5 else 1.0
	market.upkeep_cut = 3 if has(Blacksmith) else 0
	market.sale_bonus = STATION_BONUS if train else 1.0
	if herd:
		var pen := has(Feedlot)
		herd.gain_mul = FEEDLOT[0] if pen else 1.0
		herd.appetite_mul = FEEDLOT[1] if pen else 1.0
	if builder.level != level() or builder.era != era():
		builder.level = level()
		builder.era = era()
		builder._refresh()


func has(kind: Script) -> bool:
	return Building.built(world, kind)


func hook(h: Herd) -> void:
	herd = h
	market.sold.connect(func(cash: int, contract: bool): add(cash / 100.0 + (25.0 if contract else 0.0)))
	market.missed.connect(func(): add(-30.0))
	herd.died.connect(func(_c): add(-3.0))
	_apply()


func new_day(d: int) -> void:
	if d % DayCycle.DAYS_PER_SEASON == 0 and has(RodeoArena):
		var purse := RODEO_PURSE + 150 * level()
		builder.add_money(purse)
		notify.call("مسابقه‌ی گاوسواری این فصل برگزار شد: %s+ دلار، و رنچت معروف‌تر شد" % UiTheme.fa(purse))
		add(20.0)
	if d % DayCycle.DAYS_PER_SEASON == 0 and has(Saloon):
		var take := CAFE_TAKE + 100 * level()
		builder.add_money(take)
		notify.call("کافه‌ی رنچ این فصل %s+ دلار درآمد داشت و همه جا از رنچت تعریف می‌کنن" % UiTheme.fa(take))
		add(8.0)
	_apply()


func to_save() -> Dictionary:
	return {rep = rep}


func from_save(d: Dictionary) -> void:
	rep = d.rep
