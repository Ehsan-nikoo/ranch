## Tap a cow to see her board: her name, breed, weight, how she's doing (hungry, thirsty, sick, in
## calf), and buttons to make her a favourite (favourites are never sold with the rest, at the market,
## the auction or on a drive) or to sell just her. A ring on the ground shows which cow it is.
class_name CowUI
extends CanvasLayer

const KINDS := ["فروشی", "گاو مادر", "گاو نر"]

var herd: Herd
var builder: Builder
var market: Market
var notify: Callable

var _c: Dictionary = {}
var _panel: PanelContainer
var _dim: ColorRect
var _title: Label
var _text := UiTheme.label("", 25)
var _row := HBoxContainer.new()
var _ring := MeshInstance3D.new()
var _tick := 0.0


func _ready() -> void:
	_dim = UiTheme.dim(close)
	_dim.color.a = 0.25  # see-through: the cow stays in view
	_panel = UiTheme.board()
	_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)  # off to the side, so the cow can be seen
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.offset_right = -20
	add_child(_dim)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_panel.add_child(col)
	var head := UiTheme.header("", builder._button(Button.new(), "بستن", close, "cancel"))
	_title = head.get_child(2)
	col.add_child(head)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(560, 0)
	col.add_child(_text)
	_row.add_theme_constant_override("separation", 12)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_row)
	var t := TorusMesh.new()
	t.inner_radius = 1.25
	t.outer_radius = 1.45
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.3)
	t.material = m
	_ring.mesh = t
	_ring.visible = false
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	herd.add_child(_ring)


func is_open() -> bool:
	return _panel.visible


## The cow nearest a tap's ray (within reach of her body), or {}.
func pick(origin: Vector3, dir: Vector3) -> Dictionary:
	var best := {}
	var best_d := 1.4
	for c in herd.alive():
		if c.get("inside", false):
			continue
		var p: Vector3 = c.pos + Vector3(0, 0.8, 0)
		var d := (p - origin).cross(dir).length()  # distance from the ray
		if d < best_d:
			best_d = d
			best = c
	return best


func open(c: Dictionary) -> void:
	_c = c
	_panel.visible = true
	_dim.visible = true
	_ring.visible = true
	_refresh()


func close() -> void:
	_panel.visible = false
	_dim.visible = false
	_ring.visible = false
	_c = {}


func _process(delta: float) -> void:
	if not _panel.visible:
		return
	_ring.position = Vector3(_c.pos.x, 0.08, _c.pos.z)
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		if _c.has("dying") or not herd.cows.any(func(x): return is_same(x, _c)):  # sold, taken or dead meanwhile
			close()
			return
		_text.text = _about(_c)


func _price(c: Dictionary) -> int:
	return int(c.weight * Herd.BREEDS[c.breed].sale * market.sale_price())


func _about(c: Dictionary) -> String:
	var lines := [
		"%s، نژاد %s" % [KINDS[c.kind] if c.kind != Herd.FEEDER else ("گوساله‌ی فروشی" if c.weight < 300.0 else "گاو فروشی"), Herd.BREEDS[c.breed].name],
		"وزن: %s کیلو%s" % [UiTheme.fa(int(c.weight)), "  (آماده‌ی فروش)" if c.kind == Herd.FEEDER and c.weight >= Herd.READY_KG else ""],
	]
	var mood := []
	if c.hunger > 0.7:
		mood.append("گرسنه‌ست")
	if c.thirst > 0.7:
		mood.append("تشنه‌ست")
	if c.sick >= 0.0:
		mood.append("مریضه! دامپزشک لازم داره")
	if mood.is_empty():
		mood.append("سیر و سرحاله")
	lines.append("حالش: " + "، ".join(mood))
	if c.state == Herd.SLEEP:
		lines.append("الان خوابه")
	if c.preg > 0.0:
		lines.append("حامله‌ست؛ تا %s روز دیگه گوساله میاره" % UiTheme.fa(ceili(c.preg / 24.0)))
	lines.append("واکسن زده" if c.vacc >= herd.day.day else "واکسن نزده")
	if c.fav:
		lines.append("محبوبته: با بقیه فروخته نمی‌شه")
	return "\n".join(lines)


func _refresh() -> void:
	_title.text = ("★ " if _c.fav else "") + _c.name
	_text.text = _about(_c)
	for b in _row.get_children():
		b.queue_free()
	var fav := builder._button(Button.new(), "دیگه محبوب نیست" if _c.fav else "محبوبم باشه", func():
		_c.fav = not _c.fav
		_refresh(), "star")
	_row.add_child(fav)
	var price := _price(_c)
	var sell := builder._button(Button.new(), "بفروشش  %s دلار" % UiTheme.fa(price), func():
		var cash := herd.sell_one(_c, market.sale_price())
		builder.add_money(cash, "sale")
		market.sold.emit(cash, false)
		market.changed.emit()
		notify.call("%s رو فروختی:  %s+ دلار" % [_c.name, UiTheme.fa(cash)])
		close(), "market")
	sell.disabled = _c.fav  # a favourite has to be un-favourited first
	_row.add_child(sell)
