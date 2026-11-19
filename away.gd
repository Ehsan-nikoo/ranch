## While you were away: building work and the delivery truck go on with the app closed or in the
## background, by the real time that passed (the ranch's clock and the herd wait for you).
## Also the phone notifications: on leaving, it asks the phone to say when a building will be done,
## when the truck is at the gate, and the next day that the daily prize is waiting; on coming back
## it takes them back. Notifications go through the RanchNotify Android plugin (addons/ranch_notify);
## without it (desktop, or a build without the plugin) they are simply skipped.
class_name Away
extends Node

const NOTE_AFTER := 20.0     # seconds away before "while you were away" is worth saying
const TRUCK_AT := Delivery.ARRIVE - Delivery.DRIVE_IN * 0.5  # a truck that came meanwhile is just rolling in
const REMIND_HOUR := 19      # the next-day nudge comes tomorrow evening, phone's time

var builder: Builder
var delivery: Delivery
var notify: Callable
var name_of: Callable        # building -> its name on the board
var notify_on := func(): return true   # the player's setting
var asked := false           # the phone's permission to notify was asked for already
var plugin: Object           # the Android side, or null
var _left := -1.0


func _ready() -> void:
	if Engine.has_singleton("RanchNotify"):
		plugin = Engine.get_singleton("RanchNotify")


static func now() -> float:
	return Time.get_unix_time_from_system()


## Moves the work on by `seconds` of real time; says so if it's been a while.
func catch_up(seconds: float) -> void:
	if seconds <= 1.0:
		return
	var hours := seconds / DayCycle.SECONDS_PER_HOUR  # the ranch runs at normal speed for players
	var moved := false
	for b in builder.sites:
		if is_instance_valid(b) and b.work_left > 0.0:
			b.work_left = maxf(0.0, b.work_left - hours)  # Builder finishes it on its next frame
			moved = true
	for o in delivery.orders:
		if not o.done and o.t < TRUCK_AT:
			o.t = minf(o.t + hours, TRUCK_AT)
			moved = true
	if moved and seconds >= NOTE_AFTER:
		notify.call("خوش برگشتی! وقتی نبودی کارها جلو رفت")


## The first time a building goes up, the phone asks if the game may send notifications.
func ask_once() -> void:
	if asked or plugin == null:
		return
	asked = true
	plugin.ask_permission()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_left = now()
		schedule()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		if plugin:
			plugin.cancel_all()
		if _left > 0.0:
			catch_up(now() - _left)
			_left = -1.0


## What's coming while the phone is in the pocket: [seconds from now, title, text], soonest first.
func coming() -> Array:
	var out := []
	var done := {}  # seconds -> names, so buildings finishing together make one notice
	for b in builder.sites:
		if not is_instance_valid(b) or b.work_left <= 0.0:
			continue
		var sec := int(ceilf(b.work_left * DayCycle.SECONDS_PER_HOUR / 30.0) * 30.0)  # to the half minute
		done[sec] = done.get(sec, []) + [name_of.call(b)]
	for sec in done:
		var names: Array = done[sec]
		var text := "ساخت %s تموم شد. بیا ببین!" % " و ".join(names) if names.size() <= 2 else "ساخت %s تا ساختمون تموم شد. بیا ببین!" % UiTheme.fa(names.size())
		out.append([sec, "رنچ", text])
	for o in delivery.orders:
		if not o.done:
			var sec := int(maxf(30.0, (TRUCK_AT - o.t) * DayCycle.SECONDS_PER_HOUR))
			out.append([sec, "رنچ", "کامیون دم در رنچه و %s رو آورده" % " و ".join(delivery._cargo(o))])
	out.append([int(remind_in()), "رنچ", "گاوها منتظرتن! جایزه‌ی امروزت هم آماده‌ست"])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out.slice(0, 6)


## Seconds to tomorrow evening: always a new day on the phone's calendar, so a new daily prize.
static func remind_in() -> float:
	var local: float = now() + Time.get_time_zone_from_system().get("bias", 0) * 60.0
	return (floorf(local / 86400.0) + 1.0) * 86400.0 + REMIND_HOUR * 3600.0 - local


func schedule() -> void:
	if plugin == null or not notify_on.call():
		return
	var list := coming()
	for i in list.size():
		plugin.schedule(i + 1, list[i][0], list[i][1], list[i][2])


func to_save() -> Dictionary:
	return {asked = asked}


func from_save(d: Dictionary) -> void:
	asked = bool(d.get("asked", false))
