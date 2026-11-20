## The «تزئین رنچ» board, opened from the build board: a card for every piece of decoration (and the
## festivals' keepsakes once they're won), how pretty the ranch is and what that brings, the ranch's
## name for its sign, and the colour of its buildings.
class_name DecorUI
extends CanvasLayer

const PAINT_PRICE := 400

var builder: Builder
var festivals: Festivals
var world: Node3D
var save: Callable
var notify: Callable

var _panel: PanelContainer
var _dim: ColorRect
var _info := UiTheme.label("", 26)
var _row := HBoxContainer.new()
var _scroll := ScrollContainer.new()
var _cards := {}             # kind -> [card, its button, its beauty label]
var _name_panel: PanelContainer
var _name_dim: ColorRect
var _name_edit := LineEdit.new()
var _name_then := Callable()
var _paint_panel: PanelContainer
var _paint_dim: ColorRect
var _paint_btns: Array[Button] = []


func _ready() -> void:
	_dim = UiTheme.dim(toggle)
	_panel = UiTheme.board()
	add_child(_dim)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_panel.add_child(col)
	var head := UiTheme.header("تزئین رنچ", builder._button(Button.new(), "بستن", toggle, "cancel"))
	var back := builder._button(Button.new(), "ساختمون‌ها", func():
		toggle()
		builder._toggle_menu(), "build")
	back.custom_minimum_size = Vector2(250, 84)
	head.add_child(back)
	head.move_child(back, 1)
	col.add_child(head)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(1100, 0)
	col.add_child(_info)
	var tools := HBoxContainer.new()
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	tools.add_theme_constant_override("separation", 20)
	var paint := builder._button(Button.new(), "رنگ ساختمون‌ها", open_paint, "brush")
	var nm := builder._button(Button.new(), "اسم رنچ", ask_name, "sign")
	for b in [paint, nm]:
		b.custom_minimum_size = Vector2(300, 84)
		tools.add_child(b)
	col.add_child(tools)

	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(1240, 0)
	col.add_child(_scroll)
	_row.add_theme_constant_override("separation", 14)
	_scroll.add_child(_row)
	var card_box := StyleBoxFlat.new()
	card_box.bg_color = Color(0.3, 0.15, 0.04, 0.16)
	card_box.border_color = Color(0.3, 0.16, 0.05, 0.55)
	card_box.set_border_width_all(2)
	card_box.set_corner_radius_all(10)
	card_box.set_content_margin_all(10)
	var kinds: Array = Decor.ORDER.duplicate()
	for f in Festivals.LIST:
		kinds.append("k_" + f.id)
	kinds.reverse()  # first one on the right: Persian reads right to left
	for k in kinds:
		var inf := Decor.info(k)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", card_box)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		card.add_child(v)
		var pic := TextureRect.new()
		if ResourceLoader.exists("res://ui/thumbs/d_%s.png" % k):
			pic.texture = load("res://ui/thumbs/d_%s.png" % k)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(230, 150)
		v.add_child(pic)
		var title := UiTheme.label(inf.name, 27)
		title.custom_minimum_size = Vector2(230, 0)
		v.add_child(title)
		var plus := UiTheme.label("", 21, Color(0.15, 0.4, 0.1))
		v.add_child(plus)
		var b := builder._button(Button.new(), "", _pick.bind(k), "party" if inf.keep else "flower")
		b.custom_minimum_size = Vector2(230, 80)
		b.add_theme_font_size_override("font_size", 23)
		v.add_child(b)
		_row.add_child(card)
		_cards[k] = [card, b, plus]
	builder.money_moved.connect(func(_d, _w): if _panel.visible: _refresh())
	_build_name()
	_build_paint()


func is_open() -> bool:
	return _panel.visible or _name_panel.visible or _paint_panel.visible


func toggle() -> void:
	_panel.visible = not _panel.visible
	_dim.visible = _panel.visible
	builder._menu.visible = not _panel.visible
	if _panel.visible:
		_refresh()
		await get_tree().process_frame  # start at the right end
		_scroll.scroll_horizontal = int(_scroll.get_h_scroll_bar().max_value)


static func num(v: float) -> String:
	if absf(v - roundf(v)) < 0.05:
		return UiTheme.fa(int(roundf(v)))
	return UiTheme.fa("%.1f" % v).replace(".", "٫")


func _refresh() -> void:
	var b := Decor.beauty(world)
	_info.text = "زیبایی رنچت: %s از %s.  هر روز صبح %s امتیاز شهرت میاره و کافه %s درصد بیشتر درمیاره. چیزای جورواجور زیبایی بیشتری دارن تا چندتا از یه جور." % [
		num(minf(b, Decor.MAX_BEAUTY)), UiTheme.fa(int(Decor.MAX_BEAUTY)), num(Decor.daily_rep(b)), UiTheme.fa(int(roundf((Decor.cafe_mul(b) - 1.0) * 100.0)))]
	for k in _cards:
		var inf := Decor.info(k)
		var btn: Button = _cards[k][1]
		var card: Control = _cards[k][0]
		var plus: Label = _cards[k][2]
		var have := Decor.count(world, k)
		plus.text = "%s+ زیبایی" % num(Decor.adds(world, k))
		var off := false
		if inf.keep:
			var fest: Dictionary = Festivals.LIST.filter(func(f): return f.id == inf.fest)[0]
			if not festivals.done.has(inf.fest):
				btn.text = "از «%s»" % fest.name
				off = true
			elif have > 0:
				btn.text = "گذاشتیش"
				off = true
			else:
				btn.text = "بذارش (مال خودته)"
		elif k in Decor.ONLY_ONE and have > 0:
			btn.text = "گذاشتیش"
			off = true
		else:
			btn.text = "%s دلار" % UiTheme.fa(inf.price)
			off = builder.money < int(inf.price)
		btn.disabled = off
		card.modulate = Color(1, 1, 1, 0.55) if off else Color.WHITE


func _pick(k: String) -> void:
	if _panel.visible:
		toggle()
	if k == "sign" and Decor.ranch_name == "":
		ask_name(builder.choose_decor.bind(k))
		return
	builder.choose_decor(k)


# ---------- the ranch's name ----------

func _build_name() -> void:
	_name_dim = UiTheme.dim(_name_cancel)
	_name_panel = UiTheme.board()
	add_child(_name_dim)
	add_child(_name_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	_name_panel.add_child(col)
	col.add_child(UiTheme.header("اسم رنچت چیه؟", builder._button(Button.new(), "بستن", _name_cancel, "cancel")))
	var about := UiTheme.label("این اسم رو تابلوی سر در رنچ نوشته می‌شه.", 25, Color(0.32, 0.18, 0.08))
	col.add_child(about)
	_name_edit.custom_minimum_size = Vector2(640, 90)
	_name_edit.add_theme_font_size_override("font_size", 36)
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.max_length = 22
	_name_edit.placeholder_text = "مثلاً رنچ ستاره"
	_name_edit.text_submitted.connect(func(_t): _name_ok())
	var c := CenterContainer.new()
	c.add_child(_name_edit)
	col.add_child(c)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	row.add_child(builder._button(Button.new(), "بی‌خیال", _name_cancel, "cancel"))
	row.add_child(builder._button(Button.new(), "همینه", _name_ok, "place"))
	col.add_child(row)


## Asks for the ranch's name; `then` runs once it has one.
func ask_name(then := Callable()) -> void:
	if _panel.visible:
		toggle()
	_name_then = then
	_name_edit.text = Decor.ranch_name
	_name_panel.visible = true
	_name_dim.visible = true
	builder._menu.visible = false
	_name_edit.grab_focus()


func _name_cancel() -> void:
	_name_panel.visible = false
	_name_dim.visible = false
	builder._menu.visible = true
	_name_edit.release_focus()
	_name_then = Callable()


func _name_ok() -> void:
	var t := _name_edit.text.strip_edges()
	var then := _name_then
	_name_cancel()
	if t == "":
		return
	var first := Decor.ranch_name == ""
	Decor.ranch_name = t
	Decor.rename_signs(world)
	if save.is_valid():
		save.call()
	if not then.is_valid() and notify.is_valid():
		notify.call("اسم رنچت شد «%s»" % t if first else "اسم رنچ عوض شد: «%s»" % t)
	if then.is_valid():
		then.call()


# ---------- the buildings' paint ----------

func _build_paint() -> void:
	_paint_dim = UiTheme.dim(_paint_close)
	_paint_panel = UiTheme.board()
	add_child(_paint_dim)
	add_child(_paint_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_paint_panel.add_child(col)
	col.add_child(UiTheme.header("رنگ ساختمون‌ها", builder._button(Button.new(), "بستن", _paint_close, "cancel")))
	var about := UiTheme.label("دیوارهای رنگی همه‌ی ساختمون‌ها (طویله، اصطبل، آغل و بقیه) این رنگی می‌شن. هر بار رنگ کردن %s دلار." % UiTheme.fa(PAINT_PRICE), 24, Color(0.32, 0.18, 0.08))
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size = Vector2(1000, 0)
	col.add_child(about)
	var grid := HBoxContainer.new()
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("separation", 12)
	col.add_child(grid)
	for i in range(Building.PAINTS.size() - 1, -1, -1):  # first on the right
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		var sw := TextureRect.new()
		sw.texture = load(Building.TEX + Building.PAINTS[i][1])
		sw.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sw.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		sw.custom_minimum_size = Vector2(150, 110)
		v.add_child(sw)
		var b := builder._button(Button.new(), Building.PAINTS[i][0], _repaint.bind(i), "")
		b.custom_minimum_size = Vector2(150, 76)
		b.add_theme_font_size_override("font_size", 24)
		v.add_child(b)
		grid.add_child(v)
		_paint_btns.push_front(b)


func open_paint() -> void:
	if _panel.visible:
		toggle()
	for i in _paint_btns.size():
		var b := _paint_btns[i]
		b.text = "الان همینه" if i == Building.wall_paint else Building.PAINTS[i][0]
		b.disabled = i == Building.wall_paint or builder.money < PAINT_PRICE
	_paint_panel.visible = true
	_paint_dim.visible = true
	builder._menu.visible = false


func _paint_close() -> void:
	_paint_panel.visible = false
	_paint_dim.visible = false
	builder._menu.visible = true


func _repaint(i: int) -> void:
	if builder.money < PAINT_PRICE:
		return
	builder.add_money(-PAINT_PRICE, "decor")
	Building.repaint(i)
	_paint_close()
	if save.is_valid():
		save.call()
	if notify.is_valid():
		notify.call("ساختمون‌های رنچ رو %s رنگ کردن" % Building.PAINTS[i][0])
