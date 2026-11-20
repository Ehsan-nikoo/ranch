## Build mode: pick a building, pan the camera so its ghost sits where you want it, rotate, place.
## The ghost follows the screen center, so placing never fights the pan/zoom gestures.
class_name Builder
extends CanvasLayer

# label, building, cost, icon/picture name, what it does, reputation level needed (see Progress),
# era needed (1 = once the railroad has come)
var CATALOG := [
	["طویله", Barn, 3000, "barn", "جای گاوها تو شب‌های سرد زمستون. یونجه و ابزار رنچ هم اینجا نگه داشته می‌شه."],
	["خونه", RanchHouse, 2500, "house", "کارگرها اینجا زندگی می‌کنن. هر خونه جای ۳ تا کارگر داره."],
	["سیلو", Silo, 1500, "silo", "انبار یونجه برای زمستون، که گاوها تو سرما گرسنه نمونن. جای ۶۰ بسته."],
	["آسیاب بادی", Windmill, 800, "windmill", "با باد، آب رو از زیر زمین میاره بالا و آب‌خوری گاوها رو پر می‌کنه."],
	["آبگیر", Pond, 1200, "pond", "برکه‌ی بزرگ برای آب خوردن گاوها. هیچ‌وقت خراب نمی‌شه و تو خشکسالی به دادت می‌رسه."],
	["انبار یونجه", HayShed, 2200, "hay", "یه انبار بزرگ و سقف‌دار برای ۱۵۰ بسته یونجه. بهار ارزون بخر، زمستون راحت باش."],
	["آغل", Corral, 600, "corral", "یه محوطه‌ی بزرگ با نرده برای اسب‌ها: روزها توش می‌چرخن و کره‌اسب‌ها زودتر بزرگ می‌شن."],
	["سگدونی", Kennel, 1500, "kennel", "سگ‌های گله کمک می‌کنن: خودت ۱۰ تا و هر کارگر ۵ تا گاو بیشتر. گرگ‌ها هم فرار می‌کنن."],
	["برج دیده‌بانی", Watchtower, 2500, "tower", "از بالاش دزدها رو از دور می‌بینن. دزد کمتر گاو می‌بره و کلانتر راحت‌تر می‌گیرتشون.", 2],
	["اصطبل اسب", HorseStable, 4000, "stable", "کابوی‌ها سوار اسب می‌شن و ۱۰ گاو بیشتر رو می‌چرخونن. اینجا اسب هم پرورش می‌دی و می‌فروشی.", 2],
	["آغل چاق‌کنی", Feedlot, 4500, "feedlot", "گاوهای فروشی ۳۰ درصد زودتر چاق می‌شن، ولی ۲۰ درصد بیشتر علف و یونجه می‌خورن.", 2],
	["دامپزشکی", VetClinic, 3500, "vet", "دامپزشک تو رنچ می‌مونه: مریض‌ها زودتر خوب می‌شن و دامپزشک و واکسن نصف قیمته.", 2],
	["آهنگری", Blacksmith, 5000, "smithy", "آهنگر آسیاب‌ها رو سالم نگه می‌داره و خرج هر گاو روزی ۲ دلار کمتر می‌شه.", 3],
	["کافه", Saloon, 6000, "saloon", "همسایه‌ها و مسافرها میان اینجا. هر فصل پول میاره و رنچت رو معروف‌تر می‌کنه.", 3],
	["میدون گاوسواری", RodeoArena, 9000, "rodeo", "هر فصل مسابقه‌ی گاوسواری راه می‌ندازی: پول بلیت میاد و رنچت معروف‌تر می‌شه.", 4],
	["ایستگاه قطار", Station, 12000, "train", "گاوها با قطار می‌رن شهر: هر فروش ۱۰ درصد گرون‌تر و یه خریدار بیشتر.", 1, 1],
]

const QUICK := 3          # the first buildings of a new ranch take only the shortest build time
var money := 12000        # nothing is built and there are no cattle yet: water, a barn, a silo and calves
var day: DayCycle
var sites: Array[Building] = []   # buildings going up or being upgraded
var on_finished: Callable          # (building, upgraded) -> void: a site is done
var rig: CameraRig
var world: Node3D
var land: Land
var occupied: Array[Rect2] = []
var on_placed: Callable  # (world footprint) -> void
var on_decor: Callable   # opens the decoration board
var level := 1           # reputation level, set by Progress
var era := 0             # historical era, set by Progress

var ghost: Building
var _moving: Building      # a building being moved instead of a new one
var _from := Transform3D()
var _cost := 0
var _valid := false
var _marker_mat := StandardMaterial3D.new()
var _money: Label
var _build_btn := Button.new()
var _menu := HBoxContainer.new()
# the bottom bar holds just two buttons, right to left the way it's read: building, and the ranch
# board that opens every other board
const BAR := ["ساخت", "مدیریت رنچ"]
# the «مدیریت رنچ» board, three to a row, right to left
const MANAGE := ["گله", "دامداری", "کارگرها", "بازار", "زمین", "شهرت و هدف‌ها"]
var bar := {}            # name -> its button, on the bottom bar or the «مدیریت رنچ» board
var _manage: PanelContainer
var _manage_dim: ColorRect
var _grid := GridContainer.new()
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

	for row in [_menu, _place_bar]:  # centered along the bottom edge
		row.anchor_left = 0.0
		row.anchor_right = 1.0
		row.anchor_top = 1.0
		row.anchor_bottom = 1.0
		row.offset_left = 16
		row.offset_right = -16
		row.offset_top = -122
		row.offset_bottom = -12
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 24)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(row)

	bar["ساخت"] = _button(_build_btn, "ساخت", _toggle_menu, "build")
	bar["مدیریت رنچ"] = _button(Button.new(), "مدیریت رنچ", _toggle_manage, "house")
	for b in bar.values():
		b.custom_minimum_size = Vector2(250, 104)
	_build_manage()
	_arrange()
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
	var decor := _button(Button.new(), "تزئین رنچ", func():
		_toggle_menu()
		on_decor.call(), "flower")
	decor.custom_minimum_size = Vector2(260, 84)
	var head: Control = col.get_child(0)
	head.add_child(decor)
	head.move_child(decor, 1)

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
		desc.custom_minimum_size = Vector2(270, 134)  # room for four lines, so the price buttons line up
		desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		v.add_child(desc)
		var b := _button(Button.new(), "%s دلار" % UiTheme.fa(it[2]), choose.bind(i), it[3])
		b.custom_minimum_size = Vector2(270, 96)
		v.add_child(b)
		row.add_child(card)
		_items.push_front(b)
		_cards.push_front(card)


## Adds a board's button to the «مدیریت رنچ» board, in its place from MANAGE. Pressing it closes
## that board and opens its own.
func bar_button(text: String, cb: Callable, icon: String) -> Button:
	var b := _button(Button.new(), text, func():
		if _manage and _manage.visible:
			_toggle_manage()
		cb.call(), icon)
	b.custom_minimum_size = Vector2(320, 120)
	b.add_theme_font_size_override("font_size", 28)
	bar[text] = b
	_arrange()
	return b


## The button to tap on the way to a board, for the tips' arrow: on the «مدیریت رنچ» board while
## it's open, else «مدیریت رنچ» itself.
func bar_target(name: String) -> Control:
	if name in BAR or (_manage and _manage.visible):
		return bar.get(name)
	return bar.get("مدیریت رنچ")


## Lays out the bottom bar from BAR and the «مدیریت رنچ» board from MANAGE, both right to left;
## a board's button named in neither goes at the end of the board.
func _arrange() -> void:
	for c in _menu.get_children():
		_menu.remove_child(c)
	var low: Array = BAR.filter(func(n): return bar.has(n))
	low.reverse()  # a box lays its children out left to right
	for n in low:
		_menu.add_child(bar[n])
	for c in _grid.get_children():
		_grid.remove_child(c)
		if not c in bar.values():
			c.queue_free()
	var rest: Array = MANAGE.filter(func(n): return bar.has(n)) + bar.keys().filter(func(n): return not n in BAR and not n in MANAGE)
	for i in range(0, rest.size(), 3):
		var row: Array = rest.slice(i, i + 3).map(func(n): return bar[n])
		row.reverse()
		while row.size() < 3:  # a short last row starts on the right too
			var gap := Control.new()
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.push_front(gap)
		for c in row:
			_grid.add_child(c)


## The «مدیریت رنچ» board: one big button for each board of the ranch.
func _build_manage() -> void:
	_manage = UiTheme.board()
	_manage_dim = UiTheme.dim(_toggle_manage)
	add_child(_manage_dim)
	add_child(_manage)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	_manage.add_child(col)
	col.add_child(UiTheme.header("مدیریت رنچ", _button(Button.new(), "بستن", _toggle_manage, "cancel")))
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 20)
	_grid.add_theme_constant_override("v_separation", 18)
	col.add_child(_grid)


func _toggle_manage() -> void:
	_manage.visible = not _manage.visible
	_manage_dim.visible = _manage.visible
	_menu.visible = not _manage.visible  # the board has its own close button


signal money_moved(delta: int, why: String)   # for the Ledger


## `why` sorts it in the ledger: sale, cattle, vet, hay, upkeep, wages, build, trouble, trips, prize.
func add_money(delta: int, why := "") -> void:
	money += delta
	money_moved.emit(delta, why)
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
	# in debt: the minus after the number, the way the notices write it, and in red
	_money.text = "%s دلار" % UiTheme.fa(money) if money >= 0 else "%s- دلار" % UiTheme.fa(-money)
	_money.add_theme_color_override("font_color", UiTheme.ON_PLANK if money >= 0 else Color(0.6, 0.08, 0.04))
	UiTheme.fit(_money.get_parent())  # plank fits the new number
	for i in _items.size():
		var need: int = CATALOG[i][5] if CATALOG[i].size() > 5 else 1
		var need_era: int = CATALOG[i][6] if CATALOG[i].size() > 6 else 0
		var short: bool = money < CATALOG[i][2] or level < need or era < need_era
		_items[i].disabled = short
		if era < need_era:
			_items[i].text = "وقتی راه‌آهن بیاد"
		elif level < need:
			_items[i].text = "وقتی «%s» بشی" % Progress.NAMES[need - 1]
		else:
			_items[i].text = "%s دلار" % UiTheme.fa(CATALOG[i][2])
		_cards[i].modulate = Color(1, 1, 1, 0.55) if short else Color.WHITE


func choose(i: int) -> void:
	_cost = CATALOG[i][2]
	ghost = CATALOG[i][1].new()
	ghost.position = _snapped(rig.target)
	world.add_child(ghost)
	_ghost_mode()


## A piece of decoration of kind `k` to put down (see Decor): no building work, it's there at once.
func choose_decor(k: String) -> void:
	_cost = int(Decor.info(k).price)
	var d := Decor.new()
	d.kind = k
	ghost = d
	ghost.position = _snapped(rig.target)
	world.add_child(ghost)
	_ghost_mode()


## Picks up a building that's already there and lets you put it down somewhere else, for free.
func move(b: Building) -> void:
	_cost = 0
	_moving = b
	_from = b.transform
	occupied.erase(b.world_footprint())
	ghost = b
	rig.target = b.position
	_ghost_mode()


func _ghost_mode() -> void:
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
	if _moving:  # back where it was
		ghost.transform = _from
		_drop_marker()
		occupied.append(ghost.world_footprint())
	else:
		ghost.queue_free()
	_end()


func _drop_marker() -> void:
	var marker := ghost.get_node("Marker")
	ghost.remove_child(marker)  # right away: on_placed saves the game and must see a real building
	marker.queue_free()


func place() -> void:
	if not _valid:
		return
	var r := ghost.world_footprint()
	money -= _cost
	money_moved.emit(-_cost, "decor" if ghost is Decor else "build")
	occupied.append(r)
	_drop_marker()
	if not _moving and not ghost is Decor:  # a new building: from here it goes up bit by bit
		start_work(ghost, false)
	on_placed.call(r)
	_end()


## Price of a building of this kind on the build board.
func price_of(b: Building) -> int:
	for c in CATALOG:
		if c[1] == b.get_script():
			return c[2]
	return 1000


## Begins the work on `b`: putting it up (level 1), or taking it to the next level when `up`.
## An upgrade takes the bigger footprint at once, so nothing else can be built there meanwhile.
func start_work(b: Building, up: bool) -> void:
	var lv := b.level + (1 if up else 0)
	b.upgrading = up
	b.work_total = Building.work_hours(price_of(b), lv)
	if not up and world.get_children().filter(func(n): return n is Building and not n is Decor and n != b).size() < QUICK:
		b.work_total = Building.work_hours(0, 1)  # a new ranch's first few go up in the shortest time
	b.work_left = b.work_total
	if up:
		occupied.erase(b.world_footprint())
		b.work_rect = b.footprint_at(lv)
		occupied.append(b.work_rect)
	else:
		b.work_rect = b.world_footprint()
	_site(b)


## Puts a saved site back up after a load (work_left and the rest come from the save).
func resume_work(b: Building) -> void:
	b.work_rect = b.footprint_at(b.level + 1) if b.upgrading else b.world_footprint()
	if b.upgrading:
		occupied.erase(b.world_footprint())
		occupied.append(b.work_rect)
	_site(b)


func _site(b: Building) -> void:
	var lv := b.level + (1 if b.upgrading else 0)
	b.site = Site.new()
	b.add_child(b.site)
	b.site.setup(b, b.upgrading, b.local_foot_at(lv), Building.size_of(lv))
	b.site.show_at(1.0 - b.work_left / b.work_total)
	sites.append(b)


## Minutes of real time (at normal speed) left on a site.
static func minutes_left(b: Building) -> int:
	return ceili(b.work_left * DayCycle.SECONDS_PER_HOUR / 60.0)


func _work(delta: float) -> void:
	var hours := minf(delta, DayCycle.MAX_STEP) * (day.speed if day else 1.0) / DayCycle.SECONDS_PER_HOUR
	for b in sites.duplicate():
		if not is_instance_valid(b) or not b.is_inside_tree():  # knocked down meanwhile
			sites.erase(b)
			continue
		if hours <= 0.0:
			continue
		b.work_left = maxf(0.0, b.work_left - hours)
		b.site.show_at(1.0 - b.work_left / b.work_total)
		if b.work_left <= 0.0:
			sites.erase(b)
			_finish(b)


func _finish(b: Building) -> void:
	b.site.finish()
	if not b.upgrading:
		b.site.queue_free()
		b.site = null
		on_finished.call(b, false)
		return
	# the upgrade is done: the bigger, fancier building takes the old one's place
	var n: Building = b.get_script().new()
	n.level = b.level + 1
	n.position = b.position
	n.rotation = b.rotation
	world.remove_child(b)
	b.queue_free()
	world.add_child(n)
	occupied.erase(b.work_rect)
	occupied.append(n.world_footprint())
	on_finished.call(n, true)


func _end() -> void:
	ghost = null
	_moving = null
	_place_bar.visible = false
	_menu.visible = true
	_refresh()


func _snapped(p: Vector3) -> Vector3:
	return Vector3(roundf(p.x), 0, roundf(p.z))


func _process(delta: float) -> void:
	_work(delta)
	if ghost == null:
		return
	ghost.position = _snapped(rig.target)
	var r := ghost.world_footprint()
	_valid = money >= _cost and land.rect_open(r) and not occupied.any(func(o): return o.intersects(r))
	_marker_mat.albedo_color = Color(0.3, 0.95, 0.4, 0.38) if _valid else Color(1.0, 0.25, 0.2, 0.45)
	_place_btn.disabled = not _valid
