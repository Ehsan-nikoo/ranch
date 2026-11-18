## Bull riding: every summer the town holds a rodeo (with a rodeo arena of your own, you host one
## every season, for a bigger prize and some fame). Pay the entry and climb on: the bull bucks the
## rider left and right, and holding the left/right buttons (or the arrow keys) leans back the other
## way. Stay on for RIDE seconds and the prize is yours; slip past the edge of the balance bar and
## you're in the dirt. Another go costs another entry. Time on the ranch stops meanwhile.
class_name RodeoGame
extends CanvasLayer

const RIDE := 8.0          # seconds to stay on
const FEE := 50
const PRIZE := 500         # town rodeo
const HOME_PRIZE := 800    # at your own arena
const HOME_REP := 20.0
const BUCK := [0.6, 1.1]   # kick strength range (balance units per second), grows over the ride
const LEAN := 4.0          # how hard holding a button pulls back
const TIPPY := 1.0         # off-centre, the rider tips further by itself
const DAMP := 0.97         # per 1/60 s

var day: DayCycle
var builder: Builder
var progress: Progress
var events: Events
var world: Node3D
var rival: Rival
var notify: Callable

var x := 0.0               # balance: -1 and 1 are the dirt
var v := 0.0
var t := -1.0              # seconds ridden; below 0 the gate count; -1 not riding
var hold := 0              # -1 left, 1 right (buttons or bot)
var won := false
var _rival_t := 0.0       # the neighbour's rider at the town rodeo
var autopilot := false    # test bot: leans back on its own, a bit late and sloppy
var others: Array = []     # other boards that stop time; the rodeo waits for them
var _due := false
var _home := false
var _next_buck := 0.0
var _speed := 1.0
var _over := true
var _panel: PanelContainer
var _dim: ColorRect
var _title := UiTheme.label("", 40)
var _text := UiTheme.label("", 25)
var _ring := Ring.new()
var _pads := HBoxContainer.new()
var _row := HBoxContainer.new()
var _rng := RandomNumberGenerator.new()


## The ride: the bull and rider tipping with the balance, a balance bar and the clock.
class Ring extends Control:
	var game: RodeoGame
	const BULL := Color(0.26, 0.15, 0.09)
	const SHIRT := Color(0.2, 0.28, 0.45)
	const HAT := Color(0.45, 0.3, 0.16)

	func _draw() -> void:
		var w := size.x
		# dirt
		draw_rect(Rect2(0, 272, w, 22), Color(0.55, 0.38, 0.22, 0.6))
		# the bull rears and kicks while the ride is on; the rider tips with the balance
		var riding := game.t > 0.0 and not game._over
		var buck := sin(maxf(game.t, 0.0) * 9.0) * 0.22 if riding else 0.0
		var lift := absf(sin(maxf(game.t, 0.0) * 9.0)) * 18.0 if riding else 0.0
		var bull := Transform2D(buck, Vector2(1.15, 1.15), 0.0, Vector2(w * 0.5, 186 - lift))
		draw_set_transform_matrix(bull)
		_bull(riding)
		var thrown := game._over and not game.won and game.t > 0.0
		var tip := game.x * 0.9 if not thrown else signf(game.x) * 1.5
		var seat := Vector2(-10, -44) if not thrown else Vector2(signf(game.x) * 150, 40)
		draw_set_transform_matrix(bull * Transform2D(tip, seat))
		_rider()
		draw_set_transform_matrix(Transform2D.IDENTITY)
		_bar()

	func _bull(kick: bool) -> void:
		var body := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			body.append(Vector2(cos(a) * 95.0, sin(a) * 42.0))
		draw_colored_polygon(body, BULL)
		draw_circle(Vector2(-25, -30), 30, BULL)  # hump
		draw_colored_polygon(PackedVector2Array([Vector2(78, -32), Vector2(128, -22), Vector2(140, 4), Vector2(118, 20), Vector2(84, 16)]), BULL)
		draw_polyline(PackedVector2Array([Vector2(112, -24), Vector2(132, -40), Vector2(140, -60)]), Color(0.9, 0.85, 0.7), 6.0)
		draw_polyline(PackedVector2Array([Vector2(96, -28), Vector2(84, -46), Vector2(88, -66)]), Color(0.9, 0.85, 0.7), 6.0)
		var back := 0.6 if kick else 0.0  # hind legs fly back on each kick
		for lx in [-72.0, -48.0]:
			draw_line(Vector2(lx, 20), Vector2(lx, 20) + Vector2(-sin(back), cos(back)) * 64.0, BULL, 16.0)
		for lx in [52.0, 76.0]:
			draw_line(Vector2(lx, 20), Vector2(lx, 84), BULL, 16.0)
		draw_polyline(PackedVector2Array([Vector2(-92, -10), Vector2(-118, -30), Vector2(-128, -56)]), BULL, 5.0)

	func _rider() -> void:
		draw_polyline(PackedVector2Array([Vector2(0, 0), Vector2(26, 28), Vector2(18, 52)]), Color(0.3, 0.25, 0.2), 11.0)  # leg
		draw_line(Vector2(0, 4), Vector2(0, -58), SHIRT, 18.0)                 # body
		draw_line(Vector2(0, -48), Vector2(-30, -96), SHIRT, 8.0)              # free arm up
		draw_line(Vector2(0, -44), Vector2(28, -8), SHIRT, 8.0)                # hand on the rope
		draw_circle(Vector2(0, -74), 13, Color(0.85, 0.66, 0.5))               # head
		draw_rect(Rect2(-25, -88, 50, 7), HAT)                                 # brim
		draw_rect(Rect2(-13, -105, 26, 18), HAT)                               # crown

	func _bar() -> void:
		var w := size.x
		# balance bar: green in the middle, red near the edges
		var bar := Rect2(w * 0.5 - 360, 314, 720, 34)
		draw_rect(bar, Color(0.75, 0.2, 0.12))
		draw_rect(bar.grow_individual(-140, 0, -140, 0), Color(0.85, 0.65, 0.2))
		draw_rect(bar.grow_individual(-260, 0, -260, 0), Color(0.35, 0.6, 0.25))
		draw_rect(bar, UiTheme.INK, false, 3.0)
		var mx := bar.position.x + bar.size.x * (0.5 + clampf(game.x, -1.0, 1.0) * 0.5)
		draw_rect(Rect2(mx - 7, bar.position.y - 12, 14, bar.size.y + 24), UiTheme.INK)


func _ready() -> void:
	_rng.randomize()
	layer = 5
	_dim = UiTheme.dim(func(): pass)
	_panel = UiTheme.board()
	add_child(_dim)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	_panel.add_child(col)
	col.add_child(_title)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(980, 0)
	col.add_child(_text)
	_ring.game = self
	_ring.custom_minimum_size = Vector2(980, 366)
	col.add_child(_ring)
	_pads.alignment = BoxContainer.ALIGNMENT_CENTER
	_pads.add_theme_constant_override("separation", 300)
	_pads.add_child(_pad("چپ", -1))
	_pads.add_child(_pad("راست", 1))
	col.add_child(_pads)
	_row.add_theme_constant_override("separation", 16)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_row)


## A hold-down button: leans that way while pressed.
func _pad(text: String, dir: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 120)
	b.add_theme_font_size_override("font_size", 36)
	b.button_down.connect(func(): hold = dir)
	b.button_up.connect(func(): if hold == dir: hold = 0)
	return b


func is_open() -> bool:
	return _panel.visible


func home() -> bool:
	return Building.built(world, RodeoArena)


## Called at each day change: the town rodeo on the first day of summer, or every season at home.
func new_day(d: int) -> void:
	if d % DayCycle.DAYS_PER_SEASON == 0 and (home() or day.season() == DayCycle.SUMMER):
		_due = true


func _process(delta: float) -> void:
	if _due and not _panel.visible and not events._panel.visible and not _others_open():
		_due = false
		_invite()
	if _over:
		return
	t += delta
	if t < 0.0:
		_text.text = "آماده..." if t < -0.6 else "برو!"
		return
	var k := 0
	if Input.is_key_pressed(KEY_LEFT):
		k -= 1
	if Input.is_key_pressed(KEY_RIGHT):
		k += 1
	if autopilot and _rng.randf() < 0.12:  # checks only now and then, like someone slow to react
		var e := x + 0.35 * v
		hold = -1 if e > 0.06 else (1 if e < -0.06 else 0)
	var lean := k if k != 0 else hold
	_next_buck -= delta
	if _next_buck <= 0.0:
		_next_buck = _rng.randf_range(0.4, 0.85)
		v += (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(BUCK[0], BUCK[1]) * (1.0 + t / RIDE * 0.8)
	v += (x * TIPPY + lean * LEAN) * delta
	v *= pow(DAMP, delta * 60.0)
	x += v * delta
	_text.text = "%s ثانیه مونده" % UiTheme.fa(ceili(RIDE - t))
	_ring.queue_redraw()
	if absf(x) >= 1.0:
		_end(false)
	elif t >= RIDE:
		_end(true)


func _others_open() -> bool:
	return others.any(func(o): return o.is_open())


# ---------- the boards ----------

func _invite() -> void:
	_home = home()
	won = false
	_title.text = "رودئو تو میدون خودت!" if _home else "رودئوی شهر!"
	var prize := HOME_PRIZE if _home else PRIZE
	_rival_t = rival.rodeo_time() if rival and not _home else 0.0
	_text.text = "هرکی %s ثانیه رو گاو وحشی بمونه، %s دلار جایزه می‌بره%s. ورودی %s دلاره. با دکمه‌های چپ و راست خودت رو صاف نگه دار." % [UiTheme.fa(int(RIDE)), UiTheme.fa(prize), " و رنچت معروف‌تر می‌شه" if _home else "", UiTheme.fa(FEE)]
	if _rival_t > 0.0:
		_text.text += "\nسوارکار %s %s." % [Rival.NAME, "۸ ثانیه کامل موند! باید تو هم بمونی" if _rival_t >= RIDE else "%s ثانیه موند" % UiTheme.fa(_rival_t).replace(".", "٫")]
	_ring.visible = false
	_pads.visible = false
	_buttons([["سوار می‌شم  %s دلار" % UiTheme.fa(FEE), "rodeo", _start, builder.money < FEE], ["این دفعه نه", "cancel", _close, false]])
	_speed = day.speed if day.speed > 0.0 else _speed
	day.speed = 0.0
	_panel.visible = true
	_dim.visible = true


func _start() -> void:
	builder.add_money(-FEE, "prize")
	x = _rng.randf_range(-0.05, 0.05)
	v = 0.0
	hold = 0
	t = -1.2  # the gate count
	_over = false
	_next_buck = 0.3
	_title.text = "رو گاو بمون!"
	_ring.visible = true
	_pads.visible = true
	_buttons([])
	_ring.queue_redraw()


func _end(stayed: bool) -> void:
	_over = true
	hold = 0
	_pads.visible = false
	_ring.queue_redraw()
	if stayed:
		won = true
		var prize := HOME_PRIZE if _home else PRIZE
		var tie := _rival_t >= RIDE  # the neighbour stayed on too: the prize is shared
		if tie:
			prize /= 2
		builder.add_money(prize, "prize")
		if _home:
			progress.add(HOME_REP)
		_title.text = "موندی! برنده شدی!"
		_text.text = "جمعیت داره برات دست می‌زنه. جایزه: %s دلار%s%s" % [UiTheme.fa(prize), "، رنچت هم معروف‌تر شد" if _home else "", " (با %s مساوی شدی و جایزه نصف شد)" % Rival.NAME if tie else ""]
		_buttons([["عالیه", "star", _close, false]])
	else:
		_title.text = "افتادی!"
		_text.text = "%s ثانیه دووم آوردی. یه بار دیگه؟" % UiTheme.fa(snappedf(t, 0.1)).replace(".", "٫")
		_buttons([["دوباره  %s دلار" % UiTheme.fa(FEE), "rodeo", _start, builder.money < FEE], ["بسه دیگه", "cancel", _close, false]])


## options: [[label, icon, Callable, disabled]]
func _buttons(options: Array) -> void:
	for c in _row.get_children():
		c.queue_free()
	for o in options:
		var b := builder._button(Button.new(), o[0], o[2], o[1])
		b.disabled = o[3]
		_row.add_child(b)


func _close() -> void:
	t = -1.0
	_over = true
	_panel.visible = false
	_dim.visible = false
	day.speed = _speed
	if won:
		notify.call("تو رودئو برنده شدی!")
