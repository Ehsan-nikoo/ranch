## Ranch hands: cowboys on a daily wage, each with one skill at a level from 1 to 3.
## Together they look after the herd: past what they (and you) can handle, cows get neglected and
## fall sick more often. Skills also take care of trouble by themselves (see Events):
## night riders keep off wolves and rustlers, mechanics fix the windmills, herders keep cows healthy,
## farmhands cut hay for free and haul water in a drought.
class_name Workers
extends Node

signal changed

enum { HERDER, RIDER, MECHANIC, HAND }
const SKILLS := ["گاوچرون", "نگهبان شب", "تعمیرکار", "کارگر مزرعه"]
const SKILL_INFO := [
	"گاوها کمتر مریض می‌شن و زودتر خوب می‌شن؛ حواسش به %s تا گاو هست",
	"شب‌ها دور گله می‌چرخه و گرگ‌ها رو فراری می‌ده (اگه کاربلد باشه دزدها رو هم)",
	"آسیاب بادی که خراب بشه خودش درستش می‌کنه (اگه کاربلد باشه، طویله رو هم برای کولاک آماده می‌کنه)",
	"یونجه رو مجانی می‌چینه و بیشتر هم می‌چینه (اگه کاربلد باشه، تو خشکسالی آب میاره)",
]
const LEVELS := ["تازه‌کار", "کاربلد", "استاد"]
const NAMES := ["جیک", "هنک", "بیل", "وایت", "کالب", "دیزی", "ملی", "تکس", "سم", "روزی", "جسی", "بو", "کلی", "ویل", "اَنی", "رِد"]
const OWNER_COWS := 10     # you look after this many yourself
const COWS_PER_HAND := 20  # each hand; a herder handles more
const BUNKS := 3           # hands per ranch house
const DOG_COWS := 10       # the kennel's dogs: this many more cows for you to look after...
const DOG_COWS_HAND := 5   # ...and this many more for each hand

var day: DayCycle
var herd: Herd
var builder: Builder
var notify: Callable
var hired: Array = []       # {name, skill, level, wage}
var candidates: Array = []
var world: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if candidates.is_empty():
		_new_candidates()


func _new_candidates() -> void:
	candidates.clear()
	var names := NAMES.filter(func(n): return not hired.any(func(w): return w.name == n))
	names.shuffle()
	for i in 3:
		var level := 1 if _rng.randf() < 0.55 else (2 if _rng.randf() < 0.75 else 3)
		candidates.append({name = names[i], skill = _rng.randi_range(0, 3), level = level,
			wage = [25, 40, 60][level - 1] + _rng.randi_range(-1, 1) * 5})
	changed.emit()


## Bunks in the ranch houses.
func slots() -> int:
	return maxi(BUNKS, BUNKS * world.get_children().filter(func(n): return n is RanchHouse and not n.has_node("Marker")).size())


## Hands on horseback from the stable cover more ground.
func mounted() -> bool:
	return world.get_children().any(func(n): return n is HorseStable and not n.has_node("Marker"))


## Best level among the hands with `skill`, 0 if none.
func best(skill: int) -> int:
	var b := 0
	for w in hired:
		if w.skill == skill:
			b = maxi(b, w.level)
	return b


## Cows the owner and the hands can look after.
func capacity() -> int:
	var dogs := Building.built(world, Kennel)
	var c := OWNER_COWS + (DOG_COWS if dogs else 0)
	for w in hired:
		c += COWS_PER_HAND + (10 * w.level if w.skill == HERDER else 0) + (10 if mounted() else 0) + (DOG_COWS_HAND if dogs else 0)
	return c


func wages() -> int:
	return hired.reduce(func(a, w): return a + w.wage, 0)


func hire(w: Dictionary) -> bool:
	if hired.size() >= slots():
		return false
	candidates.erase(w)
	hired.append(w)
	notify.call("%s (%s %s) اومد سر کار" % [w.name, SKILLS[w.skill], LEVELS[w.level - 1]])
	_apply()
	changed.emit()
	return true


func fire(w: Dictionary) -> void:
	hired.erase(w)
	_apply()
	changed.emit()


## Neglect past capacity and the herders' care, passed on to the herd.
func _apply() -> void:
	var n := herd.alive().size()
	var over := maxf(0.0, float(n) / capacity() - 1.0)
	var h := best(HERDER)
	herd.sick_mul = (1.0 + over * 2.0) * (1.0 - 0.2 * h)
	herd.cure_mul = 1.0 + h + (2.0 if Building.built(world, VetClinic) else 0.0)


func new_day(d: int) -> void:
	var pay := wages()
	if pay > 0:
		builder.add_money(-pay)
		notify.call("حقوق دیروز کارگرها:  %s- دلار" % UiTheme.fa(pay))
	if d % DayCycle.DAYS_PER_SEASON == 0:
		_new_candidates()  # new faces looking for work each season


var _t := 0.0


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = 1.0
		_apply()


func to_save() -> Dictionary:
	return {hired = hired, candidates = candidates}


func from_save(d: Dictionary) -> void:
	var fix := func(w):
		for k in ["skill", "level", "wage"]:
			w[k] = int(w[k])
		return w
	hired = d.hired.map(fix)
	candidates = d.candidates.map(fix)
