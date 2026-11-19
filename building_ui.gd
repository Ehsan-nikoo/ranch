## Tap a building on the ranch to open its board: what it's for, how it's doing right now, the
## things you can do there (buy hay at the silo, hire hands at the house, call the vet at the
## clinic...), and moving or knocking it down (half the price back).
class_name BuildingUI
extends CanvasLayer

const TAP := 14.0          # a press that moves further than this is a camera pan, not a tap

var builder: Builder
var herd: Herd
var workers: Workers
var events: Events
var progress: Progress
var market: Market
var day: DayCycle
var world: Node3D
var save: Callable
var boards := {}           # name -> board with toggle(): herd, breed, workers, market, progress
var hay_buy: Callable      # HerdUI.buy_hay
var cow_ui: CowUI          # a tap on a cow opens hers instead
var horses: Horses

var _b: Building
var _panel: PanelContainer
var _dim: ColorRect
var _title := UiTheme.label("", 40)
var _icon := TextureRect.new()
var _about := UiTheme.label("", 24)
var _state := UiTheme.label("", 26, Color(0.42, 0.12, 0.05))
var _row := HBoxContainer.new()
var _down := Vector2.INF
var _sure := false
var _busy := false
var _tick := 0.0


func _ready() -> void:
	_dim = UiTheme.dim(close)
	_panel = UiTheme.board()
	add_child(_dim)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	_panel.add_child(col)
	var head := HBoxContainer.new()
	head.add_child(builder._button(Button.new(), "بستن", close, "cancel"))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	head.add_child(_title)
	_icon.custom_minimum_size = Vector2(72, 72)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(_icon)
	col.add_child(head)
	for l: Label in [_about, _state]:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(980, 0)
		col.add_child(l)
	_row.add_theme_constant_override("separation", 14)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_row)


func is_open() -> bool:
	return _panel.visible


## A short tap on the ground (not a drag to pan the camera) on a building opens its board.
## Taps on buttons and open boards never get here: the GUI takes them first.
func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if e.pressed:
		_down = e.position
		return
	if _down == Vector2.INF or e.position.distance_to(_down) > TAP or builder.ghost != null:
		_down = Vector2.INF
		return
	_down = Vector2.INF
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var o := cam.project_ray_origin(e.position)
	var d := cam.project_ray_normal(e.position)
	if d.y >= -0.01:
		return
	var cow := cow_ui.pick(o, d) if cow_ui else {}
	if not cow.is_empty():
		cow_ui.open(cow)
		return
	var hit := o + d * (-o.y / d.y)  # where the tap meets the ground
	var q := Vector2(hit.x, hit.z)
	var best: Building = null
	for n in world.get_children():
		if n is Building and not n.has_node("Marker") and n.world_footprint().grow(0.5).has_point(q):
			if best == null or n.global_position.distance_to(hit) < best.global_position.distance_to(hit):
				best = n
	if best != null:
		open(best)


func _entry(b: Building) -> Array:
	for c in builder.CATALOG:
		if c[1] == b.get_script():
			return c
	return ["ساختمون", null, 0, "build", ""]


func open(b: Building) -> void:
	_b = b
	_sure = false
	var c := _entry(b)
	_title.text = c[0]
	_icon.texture = load("res://ui/icons/%s.png" % c[3])
	_about.text = c[4]
	_refresh()
	_panel.visible = true
	_dim.visible = true


func close() -> void:
	_panel.visible = false
	_dim.visible = false
	_b = null


func _process(delta: float) -> void:
	if not _panel.visible:
		return
	if not is_instance_valid(_b) or not _b.is_inside_tree():  # knocked down, or swapped for its upgrade
		close()
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		if _busy != (_b.work_left > 0.0):  # the work just finished: the full board now
			_refresh()
		_state.text = _status_all(_b)


## Level line plus the building's own status (or how the work on it is going).
func _status_all(b: Building) -> String:
	if b.work_left > 0.0:
		var pct := int(100.0 * (1.0 - b.work_left / b.work_total))
		var mins := Builder.minutes_left(b)
		var what := "داره سطح %s می‌شه" % UiTheme.fa(b.level + 1) if b.upgrading else "داره ساخته می‌شه"
		var w := "%s: %s درصد کار تموم شده، حدود %s دقیقه‌ی دیگه." % [what, UiTheme.fa(pct), UiTheme.fa(mins)]
		return w + ("\n" + _status(b) if b.upgrading else "")
	var s := _status(b)
	if not b.upgrades().is_empty():
		s = "سطح %s از %s.  %s" % [UiTheme.fa(b.level), UiTheme.fa(b.upgrades().size() + 1), s]
	return s


func _refresh() -> void:
	_busy = _b.work_left > 0.0
	_state.text = _status_all(_b)
	for c in _row.get_children():
		c.queue_free()
	if not _busy or _b.upgrading:  # a site still going up has nothing to offer yet
		for a in _actions(_b):
			_add(a[0], a[1], a[2], a[3] if a.size() > 3 else false)
	var ups: Array = _b.upgrades()
	if _b.level - 1 < ups.size() and not _busy:
		var cost: int = ups[_b.level - 1]
		var room := _room(_b)
		_add("ارتقا  %s دلار" % UiTheme.fa(cost) if room else "برای ارتقا جا نیست", "star", _upgrade.bind(cost), builder.money < cost or not room)
		_about.text = "%s\nارتقای بعدی: %s (بزرگ‌تر هم می‌شه)" % [_entry(_b)[4], _b.upgrade_text()]
	else:
		_about.text = _entry(_b)[4]
	if not _busy:
		_add("جابه‌جا کن", "rotate", _move)
	var back := _refund(_b)
	_add("مطمئنی؟ خرابش کن" if _sure else "خراب کن  %s+ دلار" % UiTheme.fa(back), "cancel", _knock_down)


## Is there room on your land for the bigger building the next level makes?
func _room(b: Building) -> bool:
	var own := b.world_footprint()
	var r := b.footprint_at(b.level + 1)
	return builder.land.rect_open(r) and not builder.occupied.any(func(o: Rect2): return o != own and o.intersects(r))


func _add(text: String, icon: String, cb: Callable, off := false) -> void:
	var b := builder._button(Button.new(), text, cb, icon)
	b.disabled = off
	_row.add_child(b)


func _open_board(name: String) -> void:
	close()
	if boards.has(name):
		boards[name].toggle()


func _hay_line() -> String:
	return "یونجه‌ی رنچ: %s از %s بسته" % [UiTheme.fa(int(herd.hay)), UiTheme.fa(herd.hay_cap)]


## How it's doing right now, in a line or two.
func _status(b: Building) -> String:
	if b is Barn:
		var sleeping := herd.alive().filter(func(c): return c.get("inside", false) and herd._pens.size() > 0 and c.get("pen", -1) >= 0 and herd._pens[c.pen].distance_to(b.door()) < 0.5).size()
		return "جای %s گاو برای شب و زمستون؛ الان %s تا توش خوابیدن.\n%s" % [UiTheme.fa(b.shelter_room()), UiTheme.fa(sleeping), _hay_line()]
	if b is Silo or b is HayShed or b is Feedlot:
		return "این یکی جای %s بسته یونجه داره.\n%s" % [UiTheme.fa(b.hay_room()), _hay_line()]
	if b is RanchHouse:
		return "کارگرها: %s نفر، جای خواب: %s نفر.\nشب‌ها کارگرها می‌رن تو خونه می‌خوابن (جز نگهبان شب)." % [UiTheme.fa(workers.hired.size()), UiTheme.fa(workers.slots())]
	if b is Windmill:
		return "خرابه و آب نمیاره!" if b.broken else "سالمه و آب‌خوریش پره."
	if b is Pond:
		return "همیشه آب داره، حتی تو خشکسالی."
	if b is Kennel:
		return "دو تا سگ گله اینجان و گرگ‌ها ازشون می‌ترسن."
	if b is Watchtower:
		return "نگهبان از بالا مواظب دزدهاست."
	if b is VetClinic:
		return "گاوهای مریض الان: %s" % UiTheme.fa(herd.sick_count())
	if b is Saloon:
		return "هر فصل حدود %s دلار میاره." % UiTheme.fa(int((Progress.CAFE_TAKE + 100 * progress.level()) * (1.0 + 0.5 * (b.level - 1))))
	if b is Station:
		return "قیمت فروش امروز: %s دلار هر کیلو" % UiTheme.fa_price(market.sale_price())
	if b is RodeoArena:
		return "اول هر فصل اینجا رودئو برگزار می‌شه."
	if b is HorseStable:
		return "کارگرها سوار اسب‌ان و گاو بیشتری رو می‌چرخونن.\nاسب‌ها: %s تا، جا برای %s تا." % [UiTheme.fa(horses.list.size()), UiTheme.fa(horses.room())]
	if b is Corral:
		return "اسب‌ها روزها اینجا می‌چرخن. الان %s تا اسب داری." % UiTheme.fa(horses.list.size())
	if b is Blacksmith:
		return "آسیاب‌ها خراب نمی‌شن و خرج هر گاو کمتره."
	return ""


## [label, icon, Callable, disabled]: what you can do at this building.
func _actions(b: Building) -> Array:
	var price: int = HerdUI.HAY_PRICE[day.season()]
	if b is Silo or b is HayShed or b is Barn or b is Feedlot:
		return [["یونجه بخر  %s دلار" % UiTheme.fa(price), "hay", func():
			hay_buy.call()
			_state.text = _status(b), builder.money < price], ["گله", "cow", _open_board.bind("herd")]]
	if b is RanchHouse:
		return [["کارگرها", "worker", _open_board.bind("workers")]]
	if b is Windmill and b.broken:
		return [["تعمیرش کن  ۱۸۰ دلار", "windmill", func():
			builder.add_money(-180, "build")
			events.effects.windmill = 0.0  # ends now: Events mends it next frame
			close(), builder.money < 180]]
	if b is VetClinic:
		return [["دامداری", "vet", _open_board.bind("breed")]]
	if b is Station or b is Saloon:
		return [["بازار", "market", _open_board.bind("market")]]
	if b is HorseStable or b is Corral:
		return [["اسب‌ها", "horse", _open_board.bind("horses")]]
	if b is RodeoArena or b is Watchtower or b is Kennel:
		return [["رنچ", "star", _open_board.bind("progress")]]
	return []


func _refund(b: Building) -> int:
	return int(_entry(b)[2] * 0.5)


## Pays for the next level and puts the building into the builders' hands: scaffolding goes up round
## the bigger footprint, and when the work is done the bigger building stands in its place.
func _upgrade(cost: int) -> void:
	if builder.money < cost or not _room(_b):
		return
	builder.add_money(-cost, "build")
	builder.start_work(_b, true)
	save.call()
	_refresh()


func _move() -> void:
	var b := _b
	close()
	builder.move(b)


func _knock_down() -> void:
	if not _sure:  # one more tap to be sure
		_sure = true
		_refresh()
		return
	var b := _b
	close()
	builder.occupied.erase(b.work_rect if b.work_left > 0.0 and b.upgrading else b.world_footprint())
	builder.add_money(_refund(b), "build")
	world.remove_child(b)  # off the ranch right away, so the save and the herd don't see it
	b.queue_free()
	progress._apply()
	save.call()
