## The town bank: a way back when the money runs out. Once you're in debt, or have too little to buy
## even one calf with no cattle on the ranch, the bank offers a loan. After that a third of every
## dollar that comes in goes to pay it back, with a little extra, until it's paid off.
## A "no" is asked again a day later. Hands you can't pay walk off on their own (see Workers).
class_name Bank
extends Node

const LOAN := 4000
const EXTRA := 0.15      # paid back on top of the loan
const SHARE := 1.0 / 3.0 # of every dollar that comes in, until the debt is paid
const MAX_DEBT := 10000  # a second loan only while the first is mostly paid
const WAIT := 24.0       # game hours before asking again after a "no"

var builder: Builder
var herd: Herd
var herd_ui: HerdUI
var delivery: Delivery
var events: Events
var day: DayCycle
var notify: Callable
var debt := 0
var ask_after := 0.0      # game hour the bank may ask again
var _t := 0.0


func _ready() -> void:
	builder.money_moved.connect(_on_money)


func now() -> float:
	return day.day * 24.0 + day.hour


func _on_money(delta: int, why: String) -> void:
	if delta <= 0 or debt <= 0 or why == "loan":
		return
	var pay := mini(debt, ceili(delta * SHARE))
	debt -= pay
	builder.add_money(-pay, "loan")
	if debt == 0:
		notify.call("وام بانک رو تا آخرش پس دادی!")


## Broke: in debt, or no cattle, none coming and not enough for a calf.
func broke() -> bool:
	if builder.money < 0:
		return true
	return herd.alive().is_empty() and delivery.orders.is_empty() and builder.money < herd_ui.calf_price()


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 2.0
	if now() < ask_after or events._panel.visible or debt + owed() > MAX_DEBT or not broke():
		return
	ask_after = now() + WAIT
	var text := "پولت ته کشیده! بانک شهر حاضره %s دلار بهت قرض بده. بعدش از هر پولی که درمیاری یه سومش می‌ره برای قسط، تا وقتی %s دلار پس بدی" % [UiTheme.fa(LOAN), UiTheme.fa(owed())]
	if debt > 0:
		text += ".\nالان %s دلار به بانک بدهکاری" % UiTheme.fa(debt)
	events._ask("بانک شهر", text, [
		["قرض می‌گیرم", 0, "place", take],
		["نه، لازم ندارم", 0, "cancel", func(): pass],
	])


## What one loan costs to pay back.
func owed() -> int:
	return int(LOAN * (1.0 + EXTRA))


func take() -> void:
	debt += owed()
	builder.add_money(LOAN, "loan")
	notify.call("%s دلار وام گرفتی. قسطش خودش از درآمدت کم می‌شه" % UiTheme.fa(LOAN))


## One line for the ranch board, or "" with no debt.
func line() -> String:
	if debt <= 0:
		return ""
	return "بدهی بانک:  %s دلار (یه سوم هر درآمد می‌ره برای قسطش)" % UiTheme.fa(debt)


func to_save() -> Dictionary:
	return {debt = debt, ask_after = ask_after}


func from_save(d: Dictionary) -> void:
	debt = int(d.get("debt", 0))
	ask_after = float(d.get("ask_after", 0.0))
