## Herd board: how the cattle are doing, buy calves, sell cattle that reached sale weight,
## and keep the hay store stocked for winter (cut it from the pasture, or buy it).
## Also shows short notices (a cow died, a sale went through) at the top of the screen.
class_name HerdUI
extends CanvasLayer

const CALF_KG := 220.0
const HEIFER_KG := 400.0
const BULL_KG := 650.0
const CALF_SPOT := Vector3(8, 0, 16)  # calves arrive in front of the barn
const HAY_LOT := 10                   # bales per harvest or purchase
const HARVEST_COST := 120             # farmhands' wages for cutting and baling a lot
const HAY_PRICE := [250, 250, 300, 420]  # per lot by season: dearer as winter nears

var herd: Herd
var builder: Builder
var market: Market
var delivery: Delivery
var workers: Workers
var _panel: PanelContainer
var _dim: ColorRect
var _stats := UiTheme.label("", 25)
var _buy: Button
var _sell: Button
var _cut: Button
var _buy_hay: Button
var _toast: Label
var _toast_box: PanelContainer
var _toast_t := 0.0
var _tick := 0.0
var _births := 0        # calves born since the last notice: a busy spring would bury other news
var _births_t := 0.0


func _ready() -> void:
	builder.bar_button("گله", toggle, "cow")
	_dim = UiTheme.dim(toggle)
	_panel = UiTheme.board()
	add_child(_dim)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	_panel.add_child(col)
	col.add_child(UiTheme.header("گله", builder._button(Button.new(), "بستن", toggle, "cancel")))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	_stats.custom_minimum_size = Vector2(560, 0)
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_stats)
	var pic := TextureRect.new()
	pic.texture = load("res://ui/thumbs/cow.png")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(360, 240)
	row.add_child(pic)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 16)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(btns)
	_sell = builder._button(Button.new(), "", sell, "place")
	_buy = builder._button(Button.new(), "", buy, "cow")
	btns.add_child(_sell)
	btns.add_child(_buy)
	var hay_btns := HBoxContainer.new()
	hay_btns.add_theme_constant_override("separation", 16)
	hay_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(hay_btns)
	_buy_hay = builder._button(Button.new(), "", buy_hay, "hay")
	_cut = builder._button(Button.new(), "", cut_hay, "hay")
	hay_btns.add_child(_buy_hay)
	hay_btns.add_child(_cut)
	# CC-BY 4.0 requires crediting the cow model's author

	_toast_box = UiTheme.plank(25, Control.PRESET_CENTER_TOP)  # below the top button row
	_toast_box.offset_top = 200
	_toast_box.modulate.a = 0.0
	_toast = _toast_box.get_child(0)
	add_child(_toast_box)
	herd.died.connect(func(cause): notify("یه گاو از %s مرد" % {thirst = "تشنگی", hunger = "گرسنگی", cold = "سرما", sickness = "بیماری"}[cause]))
	herd.born.connect(func():
		_births += 1
		_births_t = 2.0)
	herd.fell_sick.connect(func():
		if herd.sick_count() == 1:  # the first one is news; after that the vet board has the count
			notify("یه گاو مریض شده؛ از «دامداری» دامپزشک رو صدا کن"))


func toggle() -> void:
	_panel.visible = not _panel.visible
	_dim.visible = _panel.visible
	_refresh()


func buy() -> void:
	if builder.money < market.calf_price():
		return
	builder.add_money(-market.calf_price())
	delivery.order(1, 0)
	_refresh()


func sell() -> void:
	if herd.ready_count() == 0:
		return
	var r := market.sell_ready()
	var n: int = r[0]
	var cash: int = r[1]
	notify("%s تا گاو فروختی:  %s+ دلار" % [UiTheme.fa(n), UiTheme.fa(cash)])
	_refresh()


## Cuts hay from the fullest pasture (it grows back), costs wages; not under winter snow.
## A farmhand on the payroll cuts for free and bales more per lot.
func _harvest_cost() -> int:
	return 0 if workers.best(Workers.HAND) > 0 else HARVEST_COST


func _harvest_lot() -> int:
	return HAY_LOT + 5 * workers.best(Workers.HAND)


func cut_hay() -> void:
	if builder.money < _harvest_cost() or herd.day.season() == DayCycle.WINTER:
		return
	var got := herd.harvest(_harvest_lot())
	if got == 0:
		notify("علف برای چیدن کمه، یا انبار پره")
		return
	builder.add_money(-_harvest_cost())
	notify("%s بسته یونجه چیدی" % UiTheme.fa(got))
	_refresh()


func buy_hay() -> void:
	var price: int = HAY_PRICE[herd.day.season()]
	if builder.money < price or _hay_space() < HAY_LOT:
		return
	builder.add_money(-price)
	delivery.order(0, HAY_LOT)
	_refresh()


## Free storage once everything already on its way has arrived.
func _hay_space() -> float:
	return herd.hay_cap - herd.hay - delivery.pending_hay()


func notify(text: String) -> void:
	# several things can happen at a day change: stack them instead of the last one hiding the rest
	_toast_box.call_deferred("reset_size")
	_toast.text = text if _toast_t < 1.0 else _toast.text + "\n" + text
	_toast_t = 4.0 + 1.5 * _toast.text.count("\n")
	UiTheme.fit(_toast_box)


func _refresh() -> void:
	var cows := herd.feeders()
	var n := herd.alive().size()
	var avg := 0.0
	var ready_kg := 0.0
	var hungry := 0
	var thirsty := 0
	for c in cows:
		avg += c.weight / maxf(cows.size(), 1)
		if c.weight >= Herd.READY_KG:
			ready_kg += c.weight
	for c in herd.alive():
		if c.hunger > 0.7:
			hungry += 1
		if c.thirst > 0.7:
			thirsty += 1
	var ready := herd.ready_count()
	_stats.text = "\n".join([
		"تعداد گاو:  %s  (فروشی %s، مادر %s، نر %s)" % [UiTheme.fa(n), UiTheme.fa(cows.size()),
			UiTheme.fa(herd.of_kind(Herd.BREEDER).size()), UiTheme.fa(herd.of_kind(Herd.BULL).size())],
		"وزن متوسط گاوهای فروشی:  %s کیلو" % UiTheme.fa(int(avg)),
		"آماده‌ی فروش (بالای %s کیلو):  %s" % [UiTheme.fa(int(Herd.READY_KG)), UiTheme.fa(ready)],
		"گرسنه:  %s      تشنه:  %s" % [UiTheme.fa(hungry), UiTheme.fa(thirsty)],
		"قیمت امروز:  هر کیلو %s دلار" % UiTheme.fa_price(market.price),
		"یونجه تو انبار:  %s از %s بسته (زمستون هر گاو روزی ۱ بسته می‌خوره)" % [UiTheme.fa(int(herd.hay)), UiTheme.fa(herd.hay_cap)],
		"خرج گله:  روزی %s دلار" % UiTheme.fa(market.upkeep() * n),
		"جا تو طویله برای زمستون:  %s تا، برای %s گاو" % [UiTheme.fa(herd.shelter), UiTheme.fa(n)],
	])
	var winter := herd.day.season() == DayCycle.WINTER
	var price: int = HAY_PRICE[herd.day.season()]
	_cut.disabled = winter or builder.money < _harvest_cost() or herd.hay_cap - herd.hay < 1.0
	_cut.text = "چیدن %s بسته یونجه  %s" % [UiTheme.fa(_harvest_lot()), "%s دلار" % UiTheme.fa(_harvest_cost()) if _harvest_cost() > 0 else "(کارگر مزرعه)"]
	_buy_hay.text = "خرید %s بسته یونجه  %s دلار" % [UiTheme.fa(HAY_LOT), UiTheme.fa(price)]
	_buy_hay.disabled = builder.money < price or _hay_space() < HAY_LOT
	_sell.text = "فروش گاوهای آماده  %s دلار" % UiTheme.fa(int(ready_kg * market.sale_price()))
	_buy.text = "خرید گوساله  %s دلار" % UiTheme.fa(market.calf_price())
	_sell.disabled = ready == 0
	_buy.disabled = builder.money < market.calf_price() or n + delivery.pending_animals() >= Herd.MAX_COWS


func _process(delta: float) -> void:
	_births_t -= delta
	if _births > 0 and _births_t <= 0.0:
		notify("یه گوساله به دنیا اومد" if _births == 1 else "%s تا گوساله به دنیا اومدن" % UiTheme.fa(_births))
		_births = 0
	_toast_t -= delta
	_toast_box.modulate.a = clampf(_toast_t, 0.0, 1.0)
	if _toast_t < 0.0 and _toast.text != "":
		_toast.text = ""
		UiTheme.fit(_toast_box)
	_tick -= delta
	if _panel.visible and _tick <= 0.0:
		_tick = 0.5
		_refresh()
