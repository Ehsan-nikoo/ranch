## Hands board: who works on the ranch (fire), who's looking for work this season (hire),
## and whether there are enough hands for the herd.
class_name WorkersUI
extends CanvasLayer

var workers: Workers
var builder: Builder
var herd: Herd
var _panel: PanelContainer
var _dim: ColorRect
var _stats := UiTheme.label("", 25)
var _list := VBoxContainer.new()
var _scroll := ScrollContainer.new()   # many hands don't fit on a phone screen: the list scrolls
var _tick := 0.0
const MAX_LIST := 440.0


func _ready() -> void:
	builder.bar_button("کارگرها", toggle, "worker")
	_dim = UiTheme.dim(toggle)
	_panel = UiTheme.board()
	add_child(_dim)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_panel.add_child(col)
	col.add_child(UiTheme.header("کارگرهای رنچ", builder._button(Button.new(), "بستن", toggle, "cancel")))
	_stats.custom_minimum_size = Vector2(1000, 0)
	col.add_child(_stats)
	_list.add_theme_constant_override("separation", 10)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	col.add_child(_scroll)
	workers.changed.connect(_rebuild)


func toggle() -> void:
	_panel.visible = not _panel.visible
	_dim.visible = _panel.visible
	_rebuild()


## One row per person: name, skill, level and what the skill does; wage on the button.
func _row(w: Dictionary, label: String, cb: Callable, icon: String, enabled: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var b := builder._button(Button.new(), label, cb, icon)
	b.custom_minimum_size = Vector2(250, 84)
	b.add_theme_font_size_override("font_size", 22)
	b.disabled = not enabled
	row.add_child(b)
	var info: String = Workers.SKILL_INFO[w.skill]
	if w.skill == Workers.HERDER:
		info = info % UiTheme.fa(Workers.COWS_PER_HAND + 10 * w.level)
	var l := UiTheme.label("%s، %s %s:  %s" % [w.name, Workers.SKILLS[w.skill], Workers.LEVELS[w.level - 1], info], 21)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(740, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


func _rebuild() -> void:
	if not _panel.visible:
		return
	_refresh()
	for c in _list.get_children():
		c.queue_free()
	_list.add_child(UiTheme.label("کارگرهات (%s تا، جا برای %s تا)" % [UiTheme.fa(workers.hired.size()), UiTheme.fa(workers.slots())], 26))
	if workers.hired.is_empty():
		_list.add_child(UiTheme.label("هنوز کسی رو نیاوردی سر کار", 21, Color(0.32, 0.18, 0.08)))
	for w in workers.hired:
		_list.add_child(_row(w, "بیرونش کن  (روزی %s)" % UiTheme.fa(w.wage), workers.fire.bind(w), "cancel", true))
	_list.add_child(UiTheme.label("دنبال کار می‌گردن (هر فصل آدمای تازه میان)", 26))
	var full := workers.hired.size() >= workers.slots()
	for w in workers.candidates:
		_list.add_child(_row(w, "بیارش سر کار  روزی %s دلار" % UiTheme.fa(w.wage), func(): workers.hire(w), "worker", not full))
	_scroll.custom_minimum_size.y = minf(_list.get_combined_minimum_size().y, MAX_LIST)


func _refresh() -> void:
	var n := herd.alive().size()
	var cap := workers.capacity()
	var lines := ["گله:  %s گاو      از پس چندتا برمیاین:  %s (خودت %s تا، هر کارگر %s تا)" % [
		UiTheme.fa(n), UiTheme.fa(cap), UiTheme.fa(Workers.OWNER_COWS), UiTheme.fa(Workers.COWS_PER_HAND)]]
	if n > cap:
		lines.append("کارگر کم داری؛ به همه‌ی گاوها نمی‌رسین و بیشتر مریض می‌شن")
	lines.append("حقوق روزانه:  %s دلار" % UiTheme.fa(workers.wages()))
	_stats.text = "\n".join(lines)


func _process(delta: float) -> void:
	_tick -= delta
	if _panel.visible and _tick <= 0.0:
		_tick = 1.0
		_refresh()
