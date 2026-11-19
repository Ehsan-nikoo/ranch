## Land board: a map of the ranch's plots. Owned plots are marked, locked ones next to your land show
## their price; a tap picks one and a second button confirms the purchase, the rest wait until you own a neighbour. North (-z) is at the top,
## the same way round as the default camera view.
class_name LandUI
extends CanvasLayer

var land: Land
var builder: Builder
var on_bought: Callable    # () -> void, e.g. save the game
var _panel: PanelContainer
var _dim: ColorRect
var _grid := GridContainer.new()
var _info := UiTheme.label("", 22, Color(0.32, 0.18, 0.08))
var _pick := -1            # plot waiting for the yes
var _ask := HBoxContainer.new()
var _ask_text := UiTheme.label("", 24)


func _ready() -> void:
	builder.bar_button("زمین", toggle, "land")
	_dim = UiTheme.dim(toggle)
	_panel = UiTheme.board()
	add_child(_dim)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_panel.add_child(col)
	col.add_child(UiTheme.header("زمین‌های رنچ", builder._button(Button.new(), "بستن", toggle, "cancel")))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(900, 0)
	col.add_child(_info)
	_grid.columns = Land.GRID
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	var center := CenterContainer.new()
	center.add_child(_grid)
	col.add_child(center)
	_ask.alignment = BoxContainer.ALIGNMENT_CENTER
	_ask.add_theme_constant_override("separation", 16)
	_ask.add_child(builder._button(Button.new(), "نه", func():
		_pick = -1
		_refresh(), "cancel"))
	_ask.add_child(builder._button(Button.new(), "آره، بخر", func(): buy(_pick), "land"))
	_ask.add_child(_ask_text)
	col.add_child(_ask)
	land.changed.connect(_refresh)


func toggle() -> void:
	_panel.visible = not _panel.visible
	_dim.visible = _panel.visible
	_pick = -1
	_refresh()


## First tap on a plot: ask before spending the money.
func pick(i: int) -> void:
	_pick = i
	_refresh()


func buy(i: int) -> void:
	var p := land.price()
	if builder.money < p or not land.can_buy(i):
		return
	_pick = -1
	builder.add_money(-p, "build")
	land.unlock(i)
	on_bought.call()
	_refresh()


func _tile(text: String, color: Color) -> PanelContainer:
	var t := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = Color(0.3, 0.16, 0.05, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	t.add_theme_stylebox_override("panel", sb)
	t.custom_minimum_size = Vector2(200, 92)
	var l := UiTheme.label(text, 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.add_child(l)
	return t


func _refresh() -> void:
	if not _panel.visible:
		return
	_info.text = "هر تیکه زمین %s در %s متره. با زمین بیشتر، گاوها جای بیشتری برای چریدن دارن و می‌تونی ساختمون‌های بیشتری بسازی. فقط تیکه‌ای رو می‌تونی بخری که بغل زمین خودت باشه. قیمت تیکه‌ی بعدی: %s دلار" % [
		UiTheme.fa(int(Land.PLOT)), UiTheme.fa(int(Land.PLOT)), UiTheme.fa(land.price())]
	_ask.visible = _pick >= 0
	_ask_text.text = "این تیکه زمین رو %s دلار می‌خری؟" % UiTheme.fa(land.price())
	for c in _grid.get_children():
		c.queue_free()
	for i in Land.GRID * Land.GRID:
		if land.owned[i] == 1:
			_grid.add_child(_tile("زمین خودت", Color(0.42, 0.55, 0.25, 0.55)))
		elif land.can_buy(i):
			var b := builder._button(Button.new(), ("همینو می‌خوام" if i == _pick else "خرید") + "\n%s دلار" % UiTheme.fa(land.price()), pick.bind(i), "land")
			if i == _pick:
				b.modulate = Color(1.0, 0.85, 0.5)  # the plot waiting for the yes
			b.custom_minimum_size = Vector2(200, 92)
			b.add_theme_font_size_override("font_size", 20)
			b.disabled = builder.money < land.price()
			_grid.add_child(b)
		else:
			_grid.add_child(_tile("قفل", Color(0.2, 0.12, 0.05, 0.3)))
