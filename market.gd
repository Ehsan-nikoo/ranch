## Cattle market: the price per kg moves every day (a seasonal base times a slow random drift),
## and buyers offer contracts: deliver N cows above a weight by a deadline at a premium price.
## A contract you accept and miss costs a cancellation fine.
class_name Market
extends Node

signal changed

# per-kg base by season: spring, summer, autumn (everyone sells before winter: cheap), winter (scarce: dear)
const BASE := [1.75, 1.65, 1.3, 1.85]
const HISTORY := 12        # days of price kept for the chart
const CALF_BASE := 450     # calf price when cattle sell at 1.6 $/kg
const UPKEEP := 15         # per cow per day: salt, vet, fence repair; paid at each day change
# Rough per-calf ledger at average prices: buy 450, two days upkeep 30, sell 500 kg x 1.6 = 800 -> about 320 profit
# per season-sized cycle. Wintering a cow costs ~3 bales (135-225) + upkeep, and pays off when winter prices are high.
const MAX_OFFERS := 2
const FINE := 0.15         # share of a missed contract's value

var day: DayCycle
var herd: Herd
var builder: Builder
var notify: Callable       # (text) -> void

var drift := 1.0
var price := 1.6
var history: Array = []    # per-kg price, oldest first
var offers: Array = []     # {count, min_kg, per_kg, due, until}
var active: Array = []     # accepted offers
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if history.is_empty():  # new game: some past days for the chart and a first offer to look at
		for i in HISTORY:
			_reprice()
		_offer()


func calf_price() -> int:
	return int(roundf(CALF_BASE * price / 1.6 / 10.0) * 10.0)


## -1 falling, 0 flat, 1 rising, over the last three days.
func trend() -> int:
	if history.size() < 3:
		return 0
	var d: float = history[-1] - history[-3]
	return 0 if absf(d) < 0.03 else signi(d)


func _reprice() -> void:
	# random walk that keeps getting pulled back toward 1, so prices wander but don't run away
	drift = clampf(drift + _rng.randf_range(-0.07, 0.07) + (1.0 - drift) * 0.2, 0.8, 1.22)
	price = snappedf(BASE[day.season()] * drift, 0.01)
	history.append(price)
	while history.size() > HISTORY:
		history.pop_front()


func new_day(d: int) -> void:
	_reprice()
	var n := herd.alive().size()
	if n > 0:
		builder.add_money(-UPKEEP * n)
		notify.call("هزینه‌ی نگهداری دیروز گله:  %s- دلار" % UiTheme.fa(UPKEEP * n))
	for c in active.duplicate():
		if d > c.due:
			var fine := int(c.count * c.min_kg * c.per_kg * FINE)
			builder.add_money(-fine)
			active.erase(c)
			notify.call("قرارداد %s گاو به موقع تحویل نشد: %s دلار جریمه" % [UiTheme.fa(c.count), UiTheme.fa(fine)])
	offers = offers.filter(func(o): return d <= o.until)
	if d % DayCycle.DAYS_PER_SEASON == 0 or _rng.randf() < 0.2:
		if _offer():
			notify.call("یه خریدار پیشنهاد قرارداد داده؛ برو به «بازار»")
	changed.emit()


func _offer() -> bool:
	if offers.size() >= MAX_OFFERS:
		return false
	var dps := DayCycle.DAYS_PER_SEASON
	offers.append({
		count = _rng.randi_range(3, 8),
		min_kg = [500, 525, 550][_rng.randi_range(0, 2)],  # past 550 growth tapers hard (Herd.MAX_KG)
		# premium over the year-round average, so a contract made in cheap autumn is still worth it in winter
		per_kg = snappedf(1.64 * drift * _rng.randf_range(1.12, 1.3), 0.01),
		due = (day.day / dps + 2) * dps - 1,  # last day of next season
		until = day.day + 2,                  # the offer itself stands for two days
	})
	return true


func eligible(c: Dictionary) -> int:
	return herd.alive().filter(func(cow): return cow.weight >= c.min_kg).size()


func accept(o: Dictionary) -> void:
	offers.erase(o)
	active.append(o)
	changed.emit()


func decline(o: Dictionary) -> void:
	offers.erase(o)
	changed.emit()


func deliver(c: Dictionary) -> void:
	if eligible(c) < c.count:
		return
	var cash := int(herd.sell(c.count, c.min_kg) * c.per_kg)
	builder.add_money(cash)
	active.erase(c)
	notify.call("قرارداد تحویل شد:  %s+ دلار" % UiTheme.fa(cash))
	changed.emit()


## Sell every cow at sale weight at today's price; returns [count, cash].
func sell_ready() -> Array:
	var n := herd.ready_count()
	var cash := int(herd.sell(n, Herd.READY_KG) * price)
	builder.add_money(cash)
	return [n, cash]


func to_save() -> Dictionary:
	return {drift = drift, price = price, history = history, offers = offers, active = active}


func from_save(d: Dictionary) -> void:
	drift = d.drift
	price = d.price
	history = d.history
	# JSON brings every number back as a float; counts and days must be whole again
	var fix := func(o):
		for k in ["count", "min_kg", "due", "until"]:
			o[k] = int(o[k])
		return o
	offers = d.offers.map(fix)
	active = d.active.map(fix)
