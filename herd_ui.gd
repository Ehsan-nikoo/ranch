## Herd board: how the cattle are doing, buy calves, sell cattle that reached sale weight.
## Also shows short notices (a cow died, a sale went through) at the top of the screen.
class_name HerdUI
extends CanvasLayer

const CALF_PRICE := 400
const CALF_KG := 220.0
const PRICE_PER_KG := 1.6
const CALF_SPOT := Vector3(8, 0, 16)  # calves arrive in front of the barn

var herd: Herd
var builder: Builder
var _panel: PanelContainer
var _dim: ColorRect
var _stats := UiTheme.label("", 27)
var _buy: Button
var _sell: Button
var _toast := Label.new()
var _toast_t := 0.0
var _tick := 0.0


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
	btns.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(btns)
	_sell = builder._button(Button.new(), "", sell, "place")
	_buy = builder._button(Button.new(), "خرید گوساله  %s دلار" % UiTheme.fa(CALF_PRICE), buy, "cow")
	btns.add_child(_sell)
	btns.add_child(_buy)

	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = 70
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 30)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02, 0.9))
	_toast.add_theme_color_override("font_color", Color(1.0, 0.9, 0.65))
	_toast.modulate.a = 0.0
	add_child(_toast)
	herd.died.connect(func(cause): notify("یک گاو از %s تلف شد" % ("تشنگی" if cause == "thirst" else "گرسنگی")))


func toggle() -> void:
	_panel.visible = not _panel.visible
	_dim.visible = _panel.visible
	_refresh()


func buy() -> void:
	if builder.money < CALF_PRICE:
		return
	builder.add_money(-CALF_PRICE)
	herd.add_cow(herd.free_spot(CALF_SPOT, 5.0), CALF_KG)
	_refresh()


func sell() -> void:
	var n := herd.ready_count()
	if n == 0:
		return
	var cash := int(herd.sell_ready() * PRICE_PER_KG)
	builder.add_money(cash)
	notify("%s گاو فروخته شد:  %s+ دلار" % [UiTheme.fa(n), UiTheme.fa(cash)])
	_refresh()


func notify(text: String) -> void:
	_toast.text = text
	_toast_t = 4.0


func _refresh() -> void:
	var cows := herd.cows
	var n := cows.size()
	var avg := 0.0
	var ready_kg := 0.0
	var hungry := 0
	var thirsty := 0
	for c in cows:
		avg += c.weight / maxf(n, 1)
		if c.weight >= Herd.READY_KG:
			ready_kg += c.weight
		if c.hunger > 0.7:
			hungry += 1
		if c.thirst > 0.7:
			thirsty += 1
	var ready := herd.ready_count()
	_stats.text = "\n".join([
		"تعداد گاو:  %s" % UiTheme.fa(n),
		"میانگین وزن:  %s کیلو" % UiTheme.fa(int(avg)),
		"آماده‌ی فروش (%s کیلو به بالا):  %s" % [UiTheme.fa(int(Herd.READY_KG)), UiTheme.fa(ready)],
		"گرسنه:  %s      تشنه:  %s" % [UiTheme.fa(hungry), UiTheme.fa(thirsty)],
		"قیمت بازار:  هر کیلو %s دلار" % UiTheme.fa(PRICE_PER_KG).replace(".", "٫"),
	])
	_sell.text = "فروش آماده‌ها  %s دلار" % UiTheme.fa(int(ready_kg * PRICE_PER_KG))
	_sell.disabled = ready == 0
	_buy.disabled = builder.money < CALF_PRICE or n >= Herd.MAX_COWS


func _process(delta: float) -> void:
	_toast_t -= delta
	_toast.modulate.a = clampf(_toast_t, 0.0, 1.0)
	_tick -= delta
	if _panel.visible and _tick <= 0.0:
		_tick = 0.5
		_refresh()
