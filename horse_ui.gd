## Horses board (from the stable or the corral): buy a mare or a stallion, see every horse with its
## stars, age and whether she's in foal, and sell. Explains how breeding works in a line.
class_name HorseUI
extends CanvasLayer

var horses: Horses
var builder: Builder
var _panel: PanelContainer
var _dim: ColorRect
var _stats := UiTheme.label("", 24)
var _buy := HBoxContainer.new()
var _list := VBoxContainer.new()
var _scroll := ScrollContainer.new()
var _tick := 0.0
var _seen := -1
const MAX_LIST := 310.0


func _ready() -> void:
	_dim = UiTheme.dim(toggle)
	_panel = UiTheme.board()
	add_child(_dim)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_panel.add_child(col)
	col.add_child(UiTheme.header("اسب‌های رنچ", builder._button(Button.new(), "بستن", toggle, "cancel")))
	_stats.custom_minimum_size = Vector2(1000, 0)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_stats)
	_buy.alignment = BoxContainer.ALIGNMENT_CENTER
	_buy.add_theme_constant_override("separation", 16)
	col.add_child(_buy)
	_list.add_theme_constant_override("separation", 8)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	col.add_child(_scroll)


func is_open() -> bool:
	return _panel.visible


func toggle() -> void:
	_panel.visible = not _panel.visible
	_dim.visible = _panel.visible
	_rebuild()


func _rebuild() -> void:
	if not _panel.visible:
		return
	_refresh()
	_seen = horses.version
	for c in _buy.get_children():
		c.queue_free()
	for f in [true, false]:
		var b := builder._button(Button.new(), "%s بخر  %s دلار" % ["مادیان" if f else "نریون", UiTheme.fa(Horses.MARE if f else Horses.STALLION)], func():
			horses.buy(f)
			_rebuild(), "horse")
		b.disabled = not horses.can_buy(f)
		_buy.add_child(b)
	for c in _list.get_children():
		c.queue_free()
	if horses.list.is_empty():
		_list.add_child(UiTheme.label("هنوز اسبی نداری. یه مادیان و یه نریون بخر تا کره‌اسب بیارن", 22, Color(0.32, 0.18, 0.08)))
	for h in horses.list:
		_list.add_child(_row(h))
	_scroll.custom_minimum_size.y = minf(_list.get_combined_minimum_size().y, MAX_LIST)


func _row(h: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var b := builder._button(Button.new(), "بفروش  %s دلار" % UiTheme.fa(horses.value(h)), func():
		UiTheme.confirm("«%s» رو بفروشی؟ %s دلار" % [h.name, UiTheme.fa(horses.value(h))], "آره، بفروش", "market", func():
			horses.sell(h)
			_rebuild()), "market")
	b.custom_minimum_size = Vector2(250, 80)
	b.add_theme_font_size_override("font_size", 22)
	row.add_child(b)
	var what := ("مادیان" if h.female else "نریون") if horses.grown(h) else ("کره‌اسب ماده" if h.female else "کره‌اسب نر")
	var age := "" if horses.grown(h) else "، %s روز دیگه بزرگ می‌شه" % UiTheme.fa(ceili(Horses.ADULT - h.age))
	var foal := "، حامله‌ست (%s روز دیگه می‌زاد)" % UiTheme.fa(ceili(h.foal / 24.0)) if h.foal > 0.0 else ""
	var l := UiTheme.label("%s، %s %s  %s%s%s" % [h.name, what, Horses.COAT_NAMES[h.coat], Horses.stars_text(h.stars), age, foal], 22)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(740, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


func _refresh() -> void:
	var lines := ["اسب‌ها:  %s تا      جا تو اصطبل:  %s تا      خرج روزانه:  %s دلار" % [
		UiTheme.fa(horses.list.size()), UiTheme.fa(horses.room()), UiTheme.fa(Horses.UPKEEP * horses.list.size())]]
	if horses.room() == 0:
		lines.append("اول یه اصطبل اسب بساز، بعد اسب بخر")
	else:
		lines.append("مادیان و نریون با هم کره‌اسب میارن. ستاره‌ی کره‌اسب نزدیک پدر و مادرشه، گاهی بهتر؛ اسب بهتر خیلی گرون‌تر فروش می‌ره و تو مسابقه‌ی شهر تندتر می‌دوه. رنگ‌های طلایی، دودی و سفید رو نمی‌شه خرید و فقط از کره‌اسب‌ها درمیان")
	_stats.text = "\n".join(lines)


func _process(delta: float) -> void:
	_tick -= delta
	if _panel.visible and _tick <= 0.0:
		_tick = 1.0
		if _seen != horses.version:
			_rebuild()
		else:
			_refresh()
