## The neighbouring ranch: a rival that grows its fame alongside yours. It snaps up buyers' offers
## you leave lying around, sometimes brings its own cattle to the season auction (more cows on sale,
## lower bids), and enters the town rodeo. Passing it in fame, or falling behind, makes the news.
class_name Rival
extends Node

const NAME := "رنچ بلک‌وود"
const SNATCH := 0.3        # chance a day that it takes an offer you haven't accepted

var day: DayCycle
var market: Market
var progress: Progress
var notify: Callable

var rep := 0.0
var ahead := true          # were you ahead of it at the last check (a new game starts level)
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## Called at each day change, before the market drops old offers.
func new_day(d: int) -> void:
	# grows steadily, a little faster as the years go by: you have to keep working to stay ahead
	rep += _rng.randf_range(8.0, 18.0) * (1.0 + d / 120.0)
	for o in market.offers.duplicate():
		if _rng.randf() < SNATCH:
			market.offers.erase(o)
			notify.call("%s قرارداد %s گاو رو زودتر از تو برداشت!" % [NAME, UiTheme.fa(o.count)])
	market.changed.emit()
	var now_ahead := progress.rep > rep
	if now_ahead != ahead:
		ahead = now_ahead
		notify.call("رنچت از %s معروف‌تر شد! همه جا اسمت سر زبوناست" % NAME if ahead else "%s ازت جلو زد؛ باید بیشتر تلاش کنی" % NAME)
		if ahead:
			progress.add(10.0)


## Does it bring cattle to this auction? Then there are more cows on sale and the buyers hold back.
func at_auction() -> bool:
	return _rng.randf() < 0.4


## Its rider's time at the town rodeo, in seconds (8 = stayed on).
func rodeo_time() -> float:
	return 8.0 if _rng.randf() < 0.45 else snappedf(_rng.randf_range(2.0, 7.5), 0.1)


func line() -> String:
	return "رقیبت، %s: %s امتیاز شهرت (%s)" % [NAME, UiTheme.fa(int(rep)), "تو جلویی" if progress.rep > rep else "اون جلوئه"]


func to_save() -> Dictionary:
	return {rep = rep, ahead = ahead}


func from_save(d: Dictionary) -> void:
	rep = d.rep
	ahead = d.ahead
