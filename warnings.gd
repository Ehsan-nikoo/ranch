## Warnings before cows die, while there's still time to do something: hay running low with winter
## near or here, cows going hungry or thirsty, no room in a barn for the cold, and a cow wasting away.
## Checked every game hour; each kind of warning at most once every few game hours. While cows are
## being hurt the herd button on the bottom bar blinks red.
class_name Warnings
extends Node

const EVERY := 6.0        # game hours between two warnings of one kind

var herd: Herd
var day: DayCycle
var delivery: Delivery
var builder: Builder
var notify: Callable
var danger := false       # something is hurting the cows right now
var _next := {}           # kind -> game hour it may be said again
var _blink := 0.0


func _ready() -> void:
	day.hour_changed.connect(func(_h): check())


func now() -> float:
	return day.day * 24.0 + day.hour


func _say(kind: String, text: String, every := EVERY) -> void:
	if now() < _next.get(kind, -1.0):
		return
	_next[kind] = now() + every
	notify.call(text)


## A cow this thin is close to dying of it (Herd kills her under min(180, peak * 0.75)).
static func wasting(c: Dictionary) -> bool:
	return c.weight < minf(180.0, c.peak * 0.75) * 1.12


func check() -> void:
	var cows := herd.alive()
	var n := cows.size()
	danger = false
	if n == 0:
		return
	var s := day.season()
	var winter := s == DayCycle.WINTER
	var near := s == DayCycle.AUTUMN and day.season_progress() > 0.6  # the last day of autumn
	var hay := herd.hay + delivery.pending_hay()
	# hungry with hay in store is only on her way to it: it's news once the hay is gone too
	# a thirsty cow can't settle to graze either: then it's the water that's missing, not the grass
	var hungry := cows.filter(func(c): return c.hunger > 0.9 and c.thirst < 0.6).size() if hay < maxf(1.0, n * 0.5) else 0
	var thirsty := cows.filter(func(c): return c.thirst > 0.92).size()  # a cow on her way to the tank is past 0.75 for a while
	var thin := cows.filter(func(c): return wasting(c) and c.sick < 0.0)  # a sick cow has its own warning
	var cold := winter and herd.shelter < n  # slows them down; only deadly on top of hunger
	var dying := cows.filter(func(c): return c.sick > Herd.SICK_DEATH * 0.5).size()
	danger = hungry > 0 or thirsty > 0 or not thin.is_empty() or dying > 0

	if not thin.is_empty():
		var c: Dictionary = thin[0]
		var why := "تشنگی" if c.thirst > 0.6 else ("گرسنگی" if c.hunger > 0.6 or not cold else "سرما")
		var fix: String = {"تشنگی": "زود آب براشون جور کن", "گرسنگی": "زود از «گله» یونجه بخر", "سرما": "زود طویله بساز"}[why]
		if thin.size() == 1:
			_say("thin", "«%s» از %s خیلی لاغر شده و داره می‌میره! %s" % [c.name, why, fix])
		else:
			_say("thin", "%s تا گاو از %s خیلی لاغر شدن و دارن می‌میرن! %s" % [UiTheme.fa(thin.size()), why, fix])
	if dying > 0:
		_say("sick", ("یه گاو مریض حالش خیلی بده و ممکنه بمیره!" if dying == 1 else "%s تا گاو مریض حالشون خیلی بده و ممکنه بمیرن!" % UiTheme.fa(dying)) + " از «دامداری» دامپزشک بیار")
	if winter or near:
		if herd.hay_cap == 0:
			_say("store", "زمستون علف نیست و جای یونجه نداری! یه طویله یا سیلو بساز و یونجه بخر", 8.0)
		elif hay < n * (1.0 if winter else 3.0):
			var head := "زمستون نزدیکه و یونجه کمه! " if not winter else ("یونجه تموم شده! " if hay < 1.0 else "یونجه داره تموم می‌شه! ")
			_say("hay", head + "از «گله» یونجه بخر، هر گاو روزی ۱ بسته می‌خوره", 8.0)
		if herd.shelter < n:
			var out := n - herd.shelter
			var who := "یه گاو تو طویله جا نداره" if out == 1 else "%s تا گاو تو طویله جا ندارن" % UiTheme.fa(out)
			_say("cold", "%s و %s! طویله بساز یا بزرگش کن" % [who, ("سرما لاغرش می‌کنه" if out == 1 else "سرما لاغرشون می‌کنه") if winter else "زمستون سرما می‌خوره"], 16.0)
	if hungry > 0:
		var fix := "یه طویله یا سیلو بساز و یونجه بخر" if herd.hay_cap == 0 else "از «گله» یونجه بخر"
		var who := "یه گاو خیلی گرسنه‌ست" if hungry == 1 else "%s تا گاو خیلی گرسنه‌ان" % UiTheme.fa(hungry)
		_say("hungry", "%s و %s! %s" % [who, "علف زیر برفه" if winter else "علف کم اومده", fix])
	if thirsty > 0 and not herd._tanks.is_empty():  # no water at all is warned by Main
		var who := "یه گاو خیلی تشنه‌ست" if thirsty == 1 else "%s تا گاو خیلی تشنه‌ان" % UiTheme.fa(thirsty)
		_say("thirsty", who + "! آب کمه یا آسیاب خرابه؛ یه آسیاب بادی یا آبگیر دیگه بساز")


func _process(delta: float) -> void:
	var b: Button = builder.bar.get("گله")
	if b == null:
		return
	if danger:
		_blink += delta * 4.0
		b.self_modulate = Color(1, 1, 1).lerp(Color(1.0, 0.35, 0.3), 0.5 + 0.5 * sin(_blink))
	elif b.self_modulate != Color.WHITE:
		b.self_modulate = Color.WHITE
