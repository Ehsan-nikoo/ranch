## Build mode: pick a building, pan the camera so its ghost sits where you want it, rotate, place.
## The ghost follows the screen center, so placing never fights the pan/zoom gestures.
class_name Builder
extends CanvasLayer

# label, building, cost, icon/picture name, what it does, reputation level needed (see Progress)
var CATALOG := [
	["طویله", Barn, 3000, "barn", "جای گاوها تو شب‌های سرد زمستون. یونجه و ابزار رنچ هم اینجا نگه داشته می‌شه."],
	["خونه", RanchHouse, 2500, "house", "کارگرها اینجا زندگی می‌کنن. هر خونه جای ۳ تا کارگر داره."],
	["سیلو", Silo, 1500, "silo", "انبار یونجه برای زمستون، که گاوها تو سرما گرسنه نمونن."],
	["آسیاب بادی", Windmill, 800, "windmill", "با باد، آب رو از زیر زمین میاره بالا و آب‌خوری گاوها رو پر می‌کنه."],
	["اصطبل اسب", HorseStable, 4000, "stable", "کابوی‌ها سوار اسب می‌شن و هر کدوم ۱۰ گاو بیشتر رو می‌چرخونن.", 2],
	["آهنگری", Blacksmith, 5000, "smithy", "آهنگر آسیاب‌ها رو سالم نگه می‌داره و خرج هر گاو روزی ۳ دلار کمتر می‌شه.", 3],
	["میدون گاوسواری", RodeoArena, 9000, "rodeo", "هر فصل مسابقه‌ی گاوسواری راه می‌ندازی: پول بلیت میاد و رنچت معروف‌تر می‌شه.", 4],
]

var money := 6000
var rig: CameraRig
var world: Node3D
var land: Land
var occupied: Array[Rect2] = []
var on_placed: Callable  # (world footprint) -> void
var level := 1           # reputation level, set by Progress

var ghost: Building
var _cost := 0
var _valid := false
var _marker_mat := StandardMaterial3D.new()
var _money: Label
var _build_btn := Button.new()
var _menu := HBoxContainer.new()
var _place_bar := HBoxContainer.new()
var _place_btn := Button.new()
var _items: Array[Button] = []
var _cards: Array[Control] = []
var _panel: PanelContainer
var _dim: ColorRect
var _scroll: ScrollContainer


func _ready() -> void:
	_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var money_box := UiTheme.plank(30, Control.PRESET_TOP_RIGHT)
	money_box.offset_right = -12
	money_box.offset_top = 8
	_money = money_box.get_child(0)
	add_child(money_box)

	for bar in [_menu, _place_bar]:
		bar.anchor_top = 1.0
		bar.anchor_bottom = 1.0
		bar.offset_left = 16
		bar.offset_top = -122
		bar.offset_bottom = -12
		bar.add_theme_constant_override("separation", 4)  # seven buttons have to fit across a phone
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)

	_menu.add_child(_button(_build_btn, "ساخت", _toggle_menu, "build"))
	_build_panel()
	_place_bar.add_child(_button(Button.new(), "چرخش", rotate_ghost, "rotate"))
	_place_bar.add_child(_button(Button.new(), "لغو", cancel, "cancel"))
	_place_bar.add_child(_button(_place_btn, "بساز", place, "place"))
	_place_bar.visible = false
	_refresh()


func _button(b: Button, text: String, cb: Callable, icon: String) -> Button:
	b.text = text
	b.icon = load("res://ui/icons/%s.png" % icon) if icon != "" else null
	b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT  # Persian reads right to left
	b.custom_minimum_size = Vector2(190, 104)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(cb)
	return b


## Wooden board in the middle of the screen with one card per building: picture, name, use, price.
func _build_panel() -> void:
	_panel = UiTheme.board()
	_dim = UiTheme.dim(_toggle_menu)
	add_child(_dim)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_panel.add_child(col)
	col.add_child(UiTheme.header("چی بسازیم؟", _button(Button.new(), "بستن", _toggle_menu, "cancel")))

	# more buildings than fit across the screen: the row scrolls sideways (drag on a phone)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(1240, 0)
	col.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	scroll.add_child(row)
	_scroll = scroll
	var card_box := StyleBoxFlat.new()  # slightly sunken, darker patch of the board
	card_box.bg_color = Color(0.3, 0.15, 0.04, 0.16)
	card_box.border_color = Color(0.3, 0.16, 0.05, 0.55)
	card_box.set_border_width_all(2)
	card_box.set_corner_radius_all(10)
	card_box.set_content_margin_all(12)
	for i in range(CATALOG.size() - 1, -1, -1):  # first item on the right: Persian reads right to left
		var it: Array = CATALOG[i]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", card_box)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		card.add_child(v)
		var pic := TextureRect.new()
		pic.texture = load("res://ui/thumbs/%s.png" % it[3])
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(270, 180)
		v.add_child(pic)
		v.add_child(UiTheme.label(it[0], 32))
		var desc := UiTheme.label(it[4], 21, Color(0.32, 0.18, 0.08))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(270, 104)
		desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		v.add_child(desc)
		var b := _button(Button.new(), "%s دلار" % UiTheme.fa(it[2]), choose.bind(i), it[3])
		b.custom_minimum_size = Vector2(270, 96)
		v.add_child(b)
		row.add_child(card)
		_items.push_front(b)
		_cards.push_front(card)


## Adds a button to the bottom bar next to «ساخت» (hidden with it during placement).
func bar_button(text: String, cb: Callable, icon: String) -> Button:
	var b := _button(Button.new(), text, cb, icon)
	_menu.add_child(b)
	return b


func add_money(delta: int) -> void:
	money += delta
	_refresh()


func _toggle_menu() -> void:
	_panel.visible = not _panel.visible
	_dim.visible = _panel.visible
	_menu.visible = not _panel.visible  # the board has its own close button
	_refresh()
	if _panel.visible:  # start at the right end: Persian reads right to left
		await get_tree().process_frame
		_scroll.scroll_horizontal = int(_scroll.get_h_scroll_bar().max_value)


func _refresh() -> void:
	_money.text = "%s دلار" % UiTheme.fa(money)
	UiTheme.fit(_money.get_parent())  # plank fits the new number
	for i in _items.size():
		var need: int = CATALOG[i][5] if CATALOG[i].size() > 5 else 1
		var short: bool = money < CATALOG[i][2] or level < need
		_items[i].disabled = short
		_items[i].text = "%s دلار" % UiTheme.fa(CATALOG[i][2]) if level >= need else "وقتی «%s» بشی" % Progress.NAMES[need - 1]
		_cards[i].modulate = Color(1, 1, 1, 0.55) if short else Color.WHITE


func choose(i: int) -> void:
	_cost = CATALOG[i][2]
	ghost = CATALOG[i][1].new()
	ghost.position = _snapped(rig.target)
	world.add_child(ghost)
	# marker added after the building built itself, so MeshMerge can't swallow it
	var f := ghost._foot()
	var pm := PlaneMesh.new()
	pm.size = f.size
	var marker := MeshInstance3D.new()
	marker.name = "Marker"
	marker.mesh = pm
	marker.material_override = _marker_mat
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.position = Vector3(f.get_center().x, 0.06, f.get_center().y)
	ghost.add_child(marker)
	_menu.visible = false
	_place_bar.visible = true
	_panel.visible = false
	_dim.visible = false


func rotate_ghost() -> void:
	ghost.rotation_degrees.y = fmod(ghost.rotation_degrees.y + 90.0, 360.0)


func cancel() -> void:
	ghost.queue_free()
	_end()


func place() -> void:
	if not _valid:
		return
	var r := ghost.world_footprint()
	money -= _cost
	occupied.append(r)
	var marker := ghost.get_node("Marker")
	ghost.remove_child(marker)  # right away: on_placed saves the game and must see a real building
	marker.queue_free()
	on_placed.call(r)
	_end()


func _end() -> void:
	ghost = null
	_place_bar.visible = false
	_menu.visible = true
	_refresh()


func _snapped(p: Vector3) -> Vector3:
	return Vector3(roundf(p.x), 0, roundf(p.z))


func _process(_delta: float) -> void:
	if ghost == null:
		return
	ghost.position = _snapped(rig.target)
	var r := ghost.world_footprint()
	_valid = money >= _cost and land.rect_open(r) and not occupied.any(func(o): return o.intersects(r))
	_marker_mat.albedo_color = Color(0.3, 0.95, 0.4, 0.38) if _valid else Color(1.0, 0.25, 0.2, 0.45)
	_place_btn.disabled = not _valid
