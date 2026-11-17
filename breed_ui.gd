## Breeding and health board: the breeding herd (cows in calf, bulls), buying heifers and bulls,
## keeping a home-bred heifer for breeding, and the vet: treat the sick, vaccinate the herd.
class_name BreedUI
extends CanvasLayer

const VET_CALL := 100      # the vet's visit
const VET_PER_COW := 40    # treatment per sick cow
const VACCINE := 20        # per cow, lasts Herd.VACCINE_DAYS

var herd: Herd
var builder: Builder
var market: Market
var delivery: Delivery
var notify: Callable       # (text) -> void
var _panel: PanelContainer
var _dim: ColorRect
var _stats := UiTheme.label("", 25)
var _info := UiTheme.label("", 20, Color(0.32, 0.18, 0.08))
var _bull: Button
var _heifer: Button
var _keep: Button
var _vet: Button
var _vaccine: Button
var _tick := 0.0


func _ready() -> void:
	builder.bar_button("دامداری", toggle, "vet")
	_dim = UiTheme.dim(toggle)
	_panel = UiTheme.board()
	add_child(_dim)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	_panel.add_child(col)
	col.add_child(UiTheme.header("گاو مادر، گوساله و دامپزشک", builder._button(Button.new(), "بستن", toggle, "cancel")))
	_stats.custom_minimum_size = Vector2(900, 0)
	col.add_child(_stats)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(900, 0)
	_info.text = "یه گاو نر برای %s تا گاو مادر بسه. گاو مادری که سیر و سالم باشه و بالای %s کیلو وزن داشته باشه حامله می‌شه (زمستون نه) و %s روز بعد گوساله میاره. گوساله‌ها بزرگ می‌شن که بفروشیشون؛ اگه گوساله‌ی ماده‌ت به %s کیلو رسید، می‌تونی نگهش داری که خودش مادر بشه." % [
		UiTheme.fa(Herd.COWS_PER_BULL), UiTheme.fa(int(Herd.BREED_KG)), UiTheme.fa(int(Herd.GESTATION / 24.0)), UiTheme.fa(int(Herd.KEEP_KG))]
	col.add_child(_info)
	_bull = builder._button(Button.new(), "", buy_bull, "cow")
	_heifer = builder._button(Button.new(), "", buy_heifer, "cow")
	_keep = builder._button(Button.new(), "یه گوساله‌ی ماده رو مادر کن", keep_heifer, "place")
	_vet = builder._button(Button.new(), "", call_vet, "vet")
	_vaccine = builder._button(Button.new(), "", vaccinate, "vaccine")
	for buttons in [[_keep, _heifer, _bull], [_vaccine, _vet]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(row)
		for b in buttons:
			row.add_child(b)


func toggle() -> void:
	_panel.visible = not _panel.visible
	_dim.visible = _panel.visible
	_refresh()


func _room() -> bool:
	return herd.alive().size() + delivery.pending_animals() < Herd.MAX_COWS


func buy_bull() -> void:
	var p := market.bull_price()
	if builder.money < p or not _room():
		return
	builder.add_money(-p)
	delivery.order(0, 0, 0, 1)
	_refresh()


func buy_heifer() -> void:
	var p := market.heifer_price()
	if builder.money < p or not _room():
		return
	builder.add_money(-p)
	delivery.order(0, 0, 1, 0)
	_refresh()


func keep_heifer() -> void:
	if herd.keep_heifer():
		notify.call("یه گوساله‌ی ماده رو نگه داشتی که مادر بشه")
	_refresh()


func _vet_cost() -> int:
	return VET_CALL + VET_PER_COW * herd.sick_count()


func call_vet() -> void:
	var cost := _vet_cost()
	if herd.sick_count() == 0 or builder.money < cost:
		return
	builder.add_money(-cost)
	notify.call("دامپزشک %s گاو مریض رو خوب کرد:  %s- دلار" % [UiTheme.fa(herd.cure()), UiTheme.fa(cost)])
	_refresh()


func vaccinate() -> void:
	var cost := VACCINE * herd.unvaccinated().size()
	if cost == 0 or builder.money < cost:
		return
	builder.add_money(-cost)
	notify.call("%s تا گاو واکسن زدن؛ تا یه سال خیلی کمتر مریض می‌شن" % UiTheme.fa(herd.vaccinate()))
	_refresh()


func _refresh() -> void:
	if not _panel.visible:
		return
	var cows := herd.of_kind(Herd.BREEDER)
	var in_calf := cows.filter(func(c): return c.preg > 0.0)
	var next := INF
	for c in in_calf:
		next = minf(next, c.preg)
	var bulls := herd.of_kind(Herd.BULL)
	var n := herd.alive().size()
	var sick := herd.sick_count()
	var unvacc := herd.unvaccinated().size()
	var keepable := herd.feeders().filter(func(c): return c.female and c.weight >= Herd.KEEP_KG and c.sick < 0.0).size()
	var lines := [
		"گاو مادر:  %s      حامله:  %s" % [UiTheme.fa(cows.size()), UiTheme.fa(in_calf.size())],
		"گاو نر:  %s%s" % [UiTheme.fa(bulls.size()), "   (بدون گاو نر، گوساله‌ای به دنیا نمیاد)" if bulls.is_empty() else ""],
		"گوساله‌ی بعدی:  %s" % ("فعلاً نه" if in_calf.is_empty() else "%s ساعت دیگه" % UiTheme.fa(ceili(next))),
		"گوساله‌ی ماده که می‌شه مادرش کرد:  %s" % UiTheme.fa(keepable),
		"مریض:  %s      واکسن‌دار:  %s از %s" % [UiTheme.fa(sick), UiTheme.fa(n - unvacc), UiTheme.fa(n)],
	]
	_stats.text = "\n".join(lines)
	var room := _room()
	_bull.text = "خرید گاو نر  %s دلار" % UiTheme.fa(market.bull_price())
	_bull.disabled = builder.money < market.bull_price() or not room
	_heifer.text = "خرید گاو مادر  %s دلار" % UiTheme.fa(market.heifer_price())
	_heifer.disabled = builder.money < market.heifer_price() or not room
	_keep.disabled = keepable == 0
	_vet.text = "دامپزشک  %s دلار" % UiTheme.fa(_vet_cost()) if sick > 0 else "دامپزشک (کسی مریض نیست)"
	_vet.disabled = sick == 0 or builder.money < _vet_cost()
	_vaccine.text = "واکسن %s گاو  %s دلار" % [UiTheme.fa(unvacc), UiTheme.fa(VACCINE * unvacc)] if unvacc > 0 else "همه واکسن زدن"
	_vaccine.disabled = unvacc == 0 or builder.money < VACCINE * unvacc


func _process(delta: float) -> void:
	_tick -= delta
	if _panel.visible and _tick <= 0.0:
		_tick = 0.5
		_refresh()
