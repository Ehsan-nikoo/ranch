## Wild horses: now and then a band of mustangs turns up on the prairie past the ranch fence and runs
## there for the day. With a free stall you can ride after one with a lasso: hold «بتاز» to close in
## (your horse runs out of breath: ease off and let it get it back), and when you're close enough
## throw the rope while the loop over your head is swung wide open. Three throws, and the band is
## over the hills in TIME seconds. A caught horse costs nothing, is now and then a very good one or a
## rare colour, but it's wild: it takes a few mornings in the stable (half with a corral) to tame.
## Your best tame horse is the one you ride; the better it is, the faster it gallops.
class_name Wild
extends CanvasLayer

signal caught_one(h: Dictionary)

const CHANCE := 0.25       # each morning, once COOLDOWN days have passed since the last band
const COOLDOWN := 4
const TIME := 35.0         # seconds before the band is over the hills
const START := 20.0        # metres behind at the start
const LOST := 45.0         # this far behind and they're gone
const RANGE := 9.0         # how far the rope reaches
const GOOD := 0.72         # the loop is swung open wide enough
const MISS_GAP := 7.0      # a missed throw spooks the horse this far ahead
const THROWS := 3
const TROT := 12.3         # m/s without galloping
const TIRED_V := 9.0       # out of breath
const DRAIN := 0.2         # breath a second at the gallop
const REGAIN := 0.2
const SWING := 2.6         # how fast the loop goes round
const TAME := 4            # mornings to tame; a corral does it in half
const STARS_W := [20, 35, 30, 12, 3]   # how often the chased horse has 1..5 stars
const PX := 17.0           # pixels a metre on the board

var day: DayCycle
var horses: Horses
var builder: Builder
var world: Node3D
var notify: Callable
var others: Array = []     # boards that stop time; the band waits for them
var autopilot := false     # test bot

var last := -10            # day the last band came
var band_day := -1         # the band is about today; gone next morning
var tried := false         # already rode after it today
var target := {}           # the one you go after: {female, stars, coat}
var t := 0.0
var gap := START
var breath := 1.0
var tired := 0.0
var hold := false
var throws := THROWS
var open := 0.0
var travelled := 0.0
var my_phase := 0.0
var its_phase := 0.0
var caught := false
var _over := true
var _due := false
var _ws := 12.5
var _spurt := 0.0
var _spurt_v := 0.0
var _next_spurt := 2.0
var _flash := 0.0          # a miss: the rope flies out and falls short
var _my_stars := 1
var _speed := 1.0
var _bot_gallop := true
var _panel: PanelContainer
var _dim: ColorRect
var _title := UiTheme.label("", 40)
var _text := UiTheme.label("", 25)
var _view := View.new()
var _pads := HBoxContainer.new()
var _gallop: Button
var _throw: Button
var _row := HBoxContainer.new()
var _band: Array[MeshInstance3D] = []
var _band_a := 0.0
var _rng := RandomNumberGenerator.new()


## The chase, side on: the prairie running by, the wild horse ahead (to the left) and you behind it
## swinging the rope, how far the rope reaches, your horse's breath, the throws left and the time.
class View extends Control:
	var w: Wild
	const GROUND := 262.0

	func _draw() -> void:
		var wd := size.x
		var font := get_theme_default_font()
		# hills far off, sliding by slowly; the grass strip faster
		var hills := PackedVector2Array()
		for i in 41:
			var x := wd * i / 40.0
			var u := x + w.travelled * 2.0
			hills.append(Vector2(x, 150.0 - 34.0 * sin(u * 0.009) - 18.0 * sin(u * 0.023 + 1.0)))
		hills.append(Vector2(wd, GROUND))
		hills.append(Vector2(0, GROUND))
		draw_colored_polygon(hills, Color(0.55, 0.5, 0.32, 0.45))
		draw_rect(Rect2(0, GROUND, wd, 40), Color(0.6, 0.48, 0.28, 0.6))
		for k in 16:  # tufts flying past
			var x := fposmod(wd * k / 16.0 + w.travelled * PX, wd)
			draw_line(Vector2(x, GROUND + 14 + (k % 3) * 8), Vector2(x + 7, GROUND + 6 + (k % 3) * 8), Color(0.42, 0.36, 0.18, 0.8), 3.0)
		var me := Vector2(wd - 170, GROUND + 6)
		var it := Vector2(maxf(me.x - w.gap * PX, 70.0), GROUND + 6)
		# the rope's reach, marked on the ground
		var reach := me.x - RANGE * PX
		for k in 6:
			draw_line(Vector2(reach, GROUND - 4 + k * 8), Vector2(reach, GROUND + k * 8), Color(0.6, 0.1, 0.05, 0.7), 3.0)
		_horse(it, Fair.COAT_LOOK[w.target.get("coat", 0)], w.its_phase, false)
		_horse(me, Color(0.42, 0.26, 0.14), w.my_phase, true)
		var hand := me + Vector2(-4, -98) + Vector2(0, -absf(sin(w.my_phase)) * 3.0)
		var close := w.gap <= RANGE
		var ready := close and w.open >= GOOD
		var col := Color(0.15, 0.55, 0.15) if ready else (Color(0.85, 0.6, 0.15) if close else Color(0.35, 0.22, 0.1))
		var r := 10.0 + 30.0 * w.open
		draw_arc(hand + Vector2(0, -r * 0.4), r, 0, TAU, 28, col, 4.0)
		draw_line(hand, hand + Vector2(0, -r * 0.4 + r), col, 3.0)
		if w._flash > 0.0:  # the rope out, falling short of the horse
			var tip := me.lerp(it, 0.85) + Vector2(0, -60)
			draw_line(hand, tip, Color(0.6, 0.45, 0.2), 3.0)
			draw_arc(tip, 18.0, 0, TAU, 20, Color(0.6, 0.45, 0.2), 3.0)
		if w.caught:  # the rope round its neck
			draw_line(hand, it + Vector2(-34, -54), Color(0.6, 0.45, 0.2), 3.0)
			draw_arc(it + Vector2(-34, -54), 12.0, 0, TAU, 20, Color(0.6, 0.45, 0.2), 4.0)
		# top row: time on the right, throws left, how far
		var tb := Rect2(wd - 330, 8, 300, 18)
		draw_rect(tb, Color(0.3, 0.15, 0.04, 0.25))
		var left := clampf(1.0 - w.t / TIME, 0.0, 1.0)
		draw_rect(Rect2(tb.end.x - tb.size.x * left, tb.position.y, tb.size.x * left, tb.size.y), Color(0.85, 0.6, 0.15))
		draw_rect(tb, UiTheme.INK, false, 2.0)
		_say(font, "وقت", Vector2(tb.position.x - 50, 24), 20)
		for k in THROWS:
			var c := Vector2(60 + k * 46, 20)
			draw_arc(c, 14.0, 0, TAU, 20, UiTheme.INK if k < w.throws else Color(0.3, 0.15, 0.04, 0.25), 4.0)
		_say(font, "%s متر" % UiTheme.fa(int(ceilf(w.gap))), Vector2(wd * 0.5 - 40, 30), 26)
		# breath bar under the ground
		var bar := Rect2(wd * 0.5 - 300, GROUND + 52, 600, 24)
		draw_rect(bar, Color(0.3, 0.15, 0.04, 0.25))
		var fill := Rect2(bar.end.x - bar.size.x * w.breath, bar.position.y, bar.size.x * w.breath, bar.size.y)
		draw_rect(fill, Color(0.75, 0.2, 0.12) if w.tired > 0.0 else Color(0.35, 0.6, 0.25))
		draw_rect(bar, UiTheme.INK, false, 3.0)

	func _say(font: Font, s: String, at: Vector2, sz: int) -> void:
		draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, UiTheme.INK)

	## A horse galloping to the left with its hooves on `p`; `ridden`: with you on it.
	func _horse(p: Vector2, c: Color, ph: float, ridden: bool) -> void:
		var s := 1.0
		var dark := c.darkened(0.45) if c.get_luminance() > 0.12 else Color(0.03, 0.03, 0.03)
		var o := p + Vector2(0, -absf(sin(ph)) * 5.0)
		for k in 4:
			var lx := (-24.0 if k < 2 else 22.0) + (k % 2) * 7.0
			var sw := sin(ph + k * 1.6) * 0.8
			var hip := o + Vector2(lx, -30) * s
			draw_line(hip, hip + Vector2(sin(sw), cos(sw)) * 34.0 * s, c.darkened(0.15) if k % 2 else c, 8.0 * s)
		var body := PackedVector2Array()
		for k in 18:
			var a := TAU * k / 18.0
			body.append(o + Vector2(cos(a) * 38.0, -42.0 + sin(a) * 17.0) * s)
		draw_colored_polygon(body, c)
		draw_colored_polygon(PackedVector2Array([o + Vector2(-28, -50) * s, o + Vector2(-50, -80) * s, o + Vector2(-38, -86) * s, o + Vector2(-14, -56) * s]), c)
		draw_colored_polygon(PackedVector2Array([o + Vector2(-40, -88) * s, o + Vector2(-68, -74) * s, o + Vector2(-66, -66) * s, o + Vector2(-40, -72) * s]), c)
		draw_line(o + Vector2(-36, -86) * s, o + Vector2(-16, -58) * s, dark, 6.0 * s)
		draw_line(o + Vector2(36, -48) * s, o + Vector2(56, -30 + sin(ph * 2.0) * 6.0) * s, dark, 7.0 * s)
		if not ridden:
			return
		var seat := o + Vector2(-2, -58)
		var top := seat + Vector2(-0.3, -1.0).normalized() * 34.0
		var shirt := Color(0.62, 0.14, 0.1)
		draw_line(seat, top, shirt, 12.0)
		draw_line(seat + Vector2(0, -22), seat + Vector2(-24, -10), shirt, 6.0)
		draw_line(top + Vector2(0, 6), top + Vector2(0, -26), shirt, 6.0)  # the arm up, swinging the rope
		draw_circle(top + Vector2(-2, -9), 8.0, Color(0.85, 0.66, 0.5))
		draw_rect(Rect2(top + Vector2(-15, -18), Vector2(26, 5)), Color(0.4, 0.26, 0.13))
		draw_rect(Rect2(top + Vector2(-9, -27), Vector2(14, 10)), Color(0.4, 0.26, 0.13))


func _ready() -> void:
	_rng.randomize()
	layer = 5
	_dim = UiTheme.dim(func(): pass)
	_panel = UiTheme.board()
	add_child(_dim)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_panel.add_child(col)
	col.add_child(_title)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(1000, 0)
	col.add_child(_text)
	_view.w = self
	_view.custom_minimum_size = Vector2(1000, 350)
	col.add_child(_view)
	_pads.alignment = BoxContainer.ALIGNMENT_CENTER
	_pads.add_theme_constant_override("separation", 200)
	_throw = builder._button(Button.new(), "کمند بنداز", throw, "rodeo")
	_gallop = builder._button(Button.new(), "بتاز", func(): pass, "horse")
	_gallop.button_down.connect(func(): hold = true)
	_gallop.button_up.connect(func(): hold = false)
	for b in [_throw, _gallop]:  # gallop on the right, under the thumb
		b.custom_minimum_size = Vector2(300, 120)
		b.add_theme_font_size_override("font_size", 34)
		_pads.add_child(b)
	col.add_child(_pads)
	_row.add_theme_constant_override("separation", 16)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_row)


func is_open() -> bool:
	return _panel.visible


## Called each morning: yesterday's band has gone; now and then a new one comes.
func new_day(d: int) -> void:
	if band_day >= 0 and d != band_day:
		band_day = -1
		_clear_band()
	if d - last < COOLDOWN or _rng.randf() > CHANCE * (1.0 + 0.5 * People.perk("sam")):
		return
	come(d)


## A band turns up today.
func come(d: int) -> void:
	last = d
	band_day = d
	tried = false
	_show_band()
	if horses.room() <= 0:
		notify.call("یه گله اسب وحشی اون طرف نرده‌های رنچ می‌دوه! برای گرفتنشون اصطبل اسب لازمه")
		return
	_due = true


func _process(delta: float) -> void:
	_move_band(delta)
	if _due and not _panel.visible and not others.any(func(o): return o.is_open()):
		_due = false
		_invite()
	if _over:
		return
	t += delta
	_flash = maxf(0.0, _flash - delta)
	if t < 0.0:
		_text.text = "آماده..." if t < -0.6 else "برو!"
		_view.queue_redraw()
		return
	if autopilot:
		_bot()
		if _over:  # it threw and the chase is done
			return
	var g := hold or Input.is_key_pressed(KEY_SPACE)
	# the wild horse: a steady run with sudden spurts; better horses run faster
	_next_spurt -= delta
	if _next_spurt <= 0.0:
		_next_spurt = _rng.randf_range(1.5, 3.5)
		_spurt = 1.2
		_spurt_v = _rng.randf_range(2.0, 4.0)
	_spurt -= delta
	var ws := _ws + (_spurt_v if _spurt > 0.0 else 0.0) + sin(t * 0.7) * 0.8
	var me := TROT
	if tired > 0.0:
		tired -= delta
		me = TIRED_V
		breath = minf(1.0, breath + REGAIN * delta)
	elif g and breath > 0.0:
		me = gallop(_my_stars)
		breath -= DRAIN * delta
		if breath <= 0.0:
			breath = 0.0
			tired = 2.0
	else:
		breath = minf(1.0, breath + REGAIN * delta)
	gap = maxf(2.5, gap + (ws - me) * delta)
	travelled += me * delta
	my_phase = fmod(my_phase + delta * me * 0.95, TAU)
	its_phase = fmod(its_phase + delta * ws * 0.95, TAU)
	open = 0.5 + 0.5 * sin(t * SWING)
	_throw.disabled = gap > RANGE
	_text.text = "بتاز تا برسی بهش؛ نفس اسبت که برید یواش کن. وقتی حلقه‌ی کمند سبز شد بندازش!"
	_view.queue_redraw()
	if gap >= LOST:
		_end(false, "اسب‌های وحشی ازت دور شدن و پشت تپه‌ها گم شدن.")
	elif t >= TIME:
		_end(false, "گله رسید به تپه‌ها و رفت. دیر شد!")


## Gallop speed of a horse of `stars`, in m/s.
static func gallop(stars: int) -> float:
	return 15.0 + 0.6 * stars + 0.4 * Legacy.level("rider")


func throw() -> void:
	if _over or t < 0.0 or gap > RANGE:
		return
	if open >= GOOD:
		caught = true
		_win()
		return
	throws -= 1
	_flash = 0.6
	gap += MISS_GAP
	if throws <= 0:
		_end(false, "کمند سه بار خطا رفت و اسب‌ها رم کردن و رفتن.")
	else:
		notify.call("کمند خطا رفت! %s بار دیگه می‌تونی بندازی" % UiTheme.fa(throws))


## Test bot: gallops till the breath is nearly gone, eases off to get it back, throws on a wide loop.
func _bot() -> void:
	if _bot_gallop and breath < 0.1:
		_bot_gallop = false
	if not _bot_gallop and breath > 0.6:
		_bot_gallop = true
	hold = _bot_gallop
	if gap <= RANGE and open > 0.8:
		throw()


# ---------- the boards ----------

func _pick_target() -> void:
	var total: int = STARS_W.reduce(func(a, b): return a + b, 0)
	var r := _rng.randi_range(1, total)
	var stars := 1
	for i in STARS_W.size():
		r -= STARS_W[i]
		if r <= 0:
			stars = i + 1
			break
	var coat := _rng.randi() % Cowboy.COMMON
	var c := _rng.randf()
	if c < 0.03:
		coat = 6
	elif c < 0.1:
		coat = 5
	elif c < 0.2:
		coat = 4
	target = {female = _rng.randf() < 0.5, stars = stars, coat = coat}


func _rider() -> Dictionary:
	var best := {}
	for h in horses.list:
		if horses.grown(h) and h.get("wild", 0) <= 0 and (best.is_empty() or h.stars > best.stars):
			best = h
	return best


func _invite() -> void:
	_pick_target()
	caught = false
	_title.text = "اسب‌های وحشی!"
	var r := _rider()
	_my_stars = r.stars if not r.is_empty() else 1
	var ride := "سوار «%s» (%s) می‌شی." % [r.name, Horses.stars_text(r.stars)] if not r.is_empty() else "اسب خودت رو نداری و یه اسب پیر قرضی سوار می‌شی (%s)." % Horses.stars_text(1)
	_text.text = "یه گله اسب وحشی اون طرف نرده‌ها داره می‌دوه. یه %s %s %s جلوشونه%s. با کمند بگیرش! مجانیه، ولی چند روز طول می‌کشه تا رام بشه. %s" % [
		"مادیان" if target.female else "نریون", Horses.COAT_NAMES[target.coat], Horses.stars_text(target.stars),
		"؛ رنگش کمیابه" if target.coat in Horses.RARE else "", ride]
	_view.visible = false
	_pads.visible = false
	var room := horses.list.size() < horses.room()
	_buttons([["برو دنبالش" if room else "اصطبل جا نداره", "horse", _start, not room or tried], ["ولش کن", "cancel", _close, false]])
	_speed = day.speed if day.speed > 0.0 else _speed
	day.speed = 0.0
	_panel.visible = true
	_dim.visible = true


func _start() -> void:
	tried = true
	t = -1.2
	gap = START
	breath = 1.0
	tired = 0.0
	hold = false
	throws = THROWS
	travelled = 0.0
	caught = false
	_flash = 0.0
	_ws = 12.5 + 0.35 * (target.stars - 2)
	_spurt = 0.0
	_next_spurt = 1.5
	_over = false
	_bot_gallop = true
	_title.text = "دنبالش کن!"
	_view.visible = true
	_pads.visible = true
	_throw.disabled = true
	_buttons([])
	_view.queue_redraw()


func _win() -> void:
	_over = true
	hold = false
	_pads.visible = false
	var h := horses._add(target.female, target.stars, Horses.ADULT + _rng.randf_range(0.0, 4.0), target.coat)
	h.wild = TAME
	horses.version += 1
	caught_one.emit(h)
	_title.text = "گرفتیش!"
	_text.text = "«%s»، یه %s %s %s، حالا مال توئه%s. هنوز وحشیه: %s روز طول می‌کشه تا رام بشه (با آغل نصف این). تا رام نشده نه سوارش می‌شن و نه کره‌اسب میاره." % [
		h.name, "مادیان" if h.female else "نریون", Horses.COAT_NAMES[h.coat], Horses.stars_text(h.stars),
		"؛ رنگش کمیابه!" if h.coat in Horses.RARE else "", UiTheme.fa(TAME)]
	_buttons([["عالیه", "star", _close, false]])
	_view.queue_redraw()


func _end(_won: bool, why: String) -> void:
	_over = true
	hold = false
	_pads.visible = false
	_title.text = "از دستت در رفت"
	_text.text = why + " شاید دفعه‌ی بعد."
	_buttons([["باشه", "cancel", _close, false]])
	_view.queue_redraw()


## options: [[label, icon, Callable, disabled]]
func _buttons(options: Array) -> void:
	for c in _row.get_children():
		c.queue_free()
	for o in options:
		var b := builder._button(Button.new(), o[0], o[2], o[1])
		b.disabled = o[3]
		_row.add_child(b)


func _close() -> void:
	_over = true
	_panel.visible = false
	_dim.visible = false
	day.speed = _speed
	if caught:
		notify.call("یه اسب وحشی گرفتی! تو اصطبل داره رام می‌شه")


# ---------- the band on the prairie ----------

func _show_band() -> void:
	_clear_band()
	for i in 6:
		var mi := MeshInstance3D.new()
		mi.mesh = HorseMesh.mesh()
		var coat: Array = Cowboy.COATS[[0, 1, 3, 2, 0, 4][i]]
		for s in 2:
			mi.set_surface_override_material(s, HorseMesh.material(s, coat[0], coat[1] if s == 0 or coat[1] > 1.0 else 0.0))
		mi.set_surface_override_material(2, Horses._bare())
		mi.set_meta("lag", i * 0.022 + _rng.randf_range(0.0, 0.01))
		mi.set_meta("side", _rng.randf_range(-4.0, 4.0))
		mi.set_meta("phase", _rng.randf() * TAU)
		world.add_child(mi)
		_band.append(mi)
	_band_a = _rng.randf() * TAU
	_move_band(0.0)


func _clear_band() -> void:
	for mi in _band:
		if is_instance_valid(mi):
			mi.queue_free()
	_band.clear()


## The band runs round the ranch on the open prairie outside the fence, all day long.
func _move_band(delta: float) -> void:
	if _band.is_empty():
		return
	var rad := Land.HALF + 22.0
	_band_a += delta * minf(day.speed, 4.0) * 7.0 / rad
	for mi in _band:
		var a: float = _band_a - mi.get_meta("lag")
		var rr: float = rad + mi.get_meta("side")
		mi.position = Vector3(cos(a) * rr, 0, sin(a) * rr)
		mi.rotation.y = atan2(-sin(a), cos(a))  # along the circle, the way it's going
		var ph: float = fmod(mi.get_meta("phase") + delta * minf(day.speed, 4.0) * 6.0, TAU)
		mi.set_meta("phase", ph)
		mi.set_instance_shader_parameter("phase", ph)
		mi.set_instance_shader_parameter("amp", 0.67 if day.speed > 0.0 else 0.0)


func to_save() -> Dictionary:
	return {last = last}


func from_save(d: Dictionary) -> void:
	last = int(d.get("last", -10))
