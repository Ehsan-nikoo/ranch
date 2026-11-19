## Ranch board: reputation level and how far to the next, what each level unlocks, and the era.
class_name ProgressUI
extends CanvasLayer

var rival: Rival
var bank: Bank
var progress: Progress
var goals: Goals
var builder: Builder
var _panel: PanelContainer
var _dim: ColorRect
var _head := UiTheme.label("", 34)
var _bar := ProgressBar.new()
var _list := UiTheme.label("", 23)
var _era := UiTheme.label("", 23, Color(0.32, 0.18, 0.08))
var _goals := UiTheme.label("", 23)


func _ready() -> void:
	builder.bar_button("شهرت و هدف‌ها", toggle, "star")
	_dim = UiTheme.dim(toggle)
	_panel = UiTheme.board()
	add_child(_dim)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	col.add_child(UiTheme.header("رنچت چقدر معروفه؟", builder._button(Button.new(), "بستن", toggle, "cancel")))
	col.add_child(_head)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.55, 0.3, 0.08)
	fill.set_corner_radius_all(8)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.3, 0.15, 0.04, 0.2)
	bg.border_color = Color(0.3, 0.16, 0.05, 0.6)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(8)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.show_percentage = false
	_bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN  # fills from the right
	_bar.custom_minimum_size = Vector2(900, 30)
	col.add_child(_bar)
	col.add_child(_list)
	_era.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_era.custom_minimum_size = Vector2(900, 0)
	col.add_child(_era)
	_goals.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goals.custom_minimum_size = Vector2(900, 0)
	col.add_child(_goals)
	progress.changed.connect(_refresh)
	goals.changed.connect(_refresh)


func toggle() -> void:
	_panel.visible = not _panel.visible
	_dim.visible = _panel.visible
	_refresh()


func _refresh() -> void:
	builder.level = progress.level()
	builder.era = progress.era()
	builder._refresh()
	if not _panel.visible:
		return
	var l := progress.level()
	var nxt := progress.next_level_at()
	_head.text = "«%s»   امتیاز شهرت:  %s" % [Progress.NAMES[l - 1], UiTheme.fa(int(progress.rep))]
	var lo: int = Progress.LEVELS[l - 1]
	_bar.min_value = lo
	_bar.max_value = nxt if nxt > 0 else lo + 1
	_bar.value = progress.rep if nxt > 0 else _bar.max_value
	var lines := []
	for i in range(1, Progress.LEVELS.size()):
		lines.append("%s  %s (%s امتیاز):  %s باز می‌شه" % ["✓" if l > i else "○", Progress.NAMES[i], UiTheme.fa(Progress.LEVELS[i]), Progress.UNLOCKS[i]])
	_list.text = "\n".join(lines)
	var e := progress.era()
	var text := "%s (سال %s) - قیمت گاو %s برابر" % [Progress.ERAS[e][1], UiTheme.fa(progress.year() + 1), UiTheme.fa_price(Progress.ERAS[e][2])]
	if e + 1 < Progress.ERAS.size():
		text += "\nاز سال %s: %s" % [UiTheme.fa(Progress.ERAS[e + 1][0] + 1), Progress.ERAS[e + 1][1]]
	if e < 1:
		text += " (ایستگاه قطار باز می‌شه)"
	if rival:
		text += "\n" + rival.line()
	if bank and bank.line() != "":
		text += "\n" + bank.line()
	_era.text = text
	var g := ["هدف‌های الان (%s از %s تا انجام شده):" % [UiTheme.fa(goals.done.size()), UiTheme.fa(Goals.LIST.size())]]
	for o in goals.open():
		g.append("○  %s  (%s از %s)  جایزه: %s" % [Goals.text(o), UiTheme.fa(mini(goals.value(o[2]), o[3])), UiTheme.fa(o[3]), Goals.prize(o)])
	if goals.open().is_empty():
		g.append("همه‌ی هدف‌ها رو انجام دادی!")
	_goals.text = "\n".join(g)


var _tick := 0.0


func _process(delta: float) -> void:
	_tick -= delta
	if _panel.visible and _tick <= 0.0:
		_tick = 1.0
		_refresh()
