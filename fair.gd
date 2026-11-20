## The town fair, on the third day of every season: a horse race and a cattle show.
## The race: your best grown horse against four horses from other ranches. Hold «تند برو!» to gallop
## flat out, but a horse that runs out of breath can only trot for a while, so save some for the end.
## A horse's stars set its pace. The show: your best cow before the judges, who look at her weight,
## breed, health and how well she's fed; a wash and brush adds a few points. The first three of each
## win a prize and a cup or a ribbon, kept in the ranch house (see Collection). A festival (see
## Festivals) can hold either contest on its own day. Time on the ranch stops while the board is open.
class_name Fair
extends CanvasLayer

signal won(kind: String, place: int)   # kind: race, coach, show; place 1..5

const DAY_IN_SEASON := 2
const RACE_FEE := 60
const RACE_PRIZE := [600, 250, 100]
const RACE_REP := [15.0, 6.0, 2.0]
const SHOW_PRIZE := [400, 150, 60]
const SHOW_REP := [12.0, 5.0, 2.0]
const GROOM := 40          # wash and brush: a few points more with the judges
const GROOM_PTS := 5.0
const SHOW_KG := 300.0     # lighter calves don't go to the show
const TRACK := 100.0       # race length, in track units
const SPRINT := 1.3        # flat out, against a canter
const DRAIN := 0.32        # breath used per second flat out
const REGAIN := 0.12       # breath back per second at a canter
const TIRED := 2.2         # seconds a horse out of breath can only trot
const PLACES := ["اول", "دوم", "سوم", "چهارم", "پنجم"]
const RIDERS := ["پسرهای مک‌کین", "کلانتر شهر", "رنچ کارسون", "گاوچرون پیر", "رنچ تگزاسی", "خانواده‌ی میلر"]
const RIDER_HORSES := ["صاعقه", "کولاک", "شب‌تاب", "یاغی", "گردباد", "پرنده", "تیزپا", "ببر"]
const SHOW_COWS := ["خوشگله", "ملکه", "دُردونه", "پرنسس", "خانم‌بزرگ", "نقره", "شاهزاده", "مروارید"]
const CUPS := ["جام طلا", "جام نقره", "جام برنز"]
const RIBBONS := ["روبان آبی", "روبان قرمز", "روبان زرد"]
const SHIRTS := [Color(0.72, 0.16, 0.1), Color(0.2, 0.3, 0.55), Color(0.25, 0.45, 0.22), Color(0.5, 0.35, 0.6), Color(0.15, 0.13, 0.12)]
# what each coat looks like drawn flat (Cowboy.COATS on the bay texture)
const COAT_LOOK := [Color(0.45, 0.25, 0.12), Color(0.66, 0.3, 0.13), Color(0.13, 0.12, 0.12), Color(0.62, 0.61, 0.58),
	Color(0.82, 0.6, 0.3), Color(0.38, 0.42, 0.52), Color(0.9, 0.88, 0.84)]

var day: DayCycle
var herd: Herd
var horses: Horses
var builder: Builder
var progress: Progress
var rival: Rival
var notify: Callable
var others: Array = []     # boards that stop time; the fair waits for them
var autopilot := false     # test bot: rides and shows on its own
var trophies: Array = []   # {k = race|show, p = 1..3, y = year, s = season, who = name, fest = festival or ""}

var racers: Array = []     # {name, who, stars, coat, x, breath, tired, kick, save, form, me, fin, phase}
var t := 0.0               # race clock; below 0 the count before the start
var hold := false          # «تند برو!» held down
var _over := true
var _coach := false        # a stagecoach race (a festival's)
var _fest := ""            # the festival holding this contest, or "" for the season's fair
var _due := false
var _held := []            # contests already held at this fair
var _speed := 1.0
var _pick := 0
var _cow: Dictionary
var _groomed := false
var _entries: Array = []   # the show: [cow, owner, score, me], best first once judged
var _reveal := -1          # entries announced so far, from the last place up; -1 not judging
var _beat := 0.0
var _after := -1.0         # seconds the race goes on after you're past the post
var _bot_t := 1.0
var _panel: PanelContainer
var _dim: ColorRect
var _title := UiTheme.label("", 40)
var _text := UiTheme.label("", 25)
var _track := Track.new()
var _pads := HBoxContainer.new()
var _list := VBoxContainer.new()
var _row := HBoxContainer.new()
var _rng := RandomNumberGenerator.new()


## The race seen from the side: five lanes, the finish post on the left, the horses galloping
## right to left with their riders, each with its name above, and your horse's breath underneath.
class Track extends Control:
	var fair: Fair
	const X0 := 70.0
	const X1 := 900.0
	const LANE := 52.0

	func _draw() -> void:
		var w := size.x
		var n := fair.racers.size()
		draw_rect(Rect2(0, 8, w, LANE * n + 16), Color(0.62, 0.45, 0.27, 0.55))
		for i in n + 1:
			draw_line(Vector2(0, 16 + LANE * i), Vector2(w, 16 + LANE * i), Color(0.95, 0.9, 0.8, 0.5), 2.0)
		for k in int((LANE * n) / 12.0):  # chequered finish post
			draw_rect(Rect2(X0 - 12 + (k % 2) * 6, 16 + k * 12, 6, 12), Color.WHITE if k % 2 == 0 else Color(0.1, 0.1, 0.1))
		draw_line(Vector2(X1 + 30, 16), Vector2(X1 + 30, 16 + LANE * n), Color(0.95, 0.9, 0.8, 0.8), 3.0)
		var font := get_theme_default_font()
		for i in n:
			var r: Dictionary = fair.racers[i]
			var p := Vector2(X1 - r.x / Fair.TRACK * (X1 - X0), 16 + LANE * (i + 1) - 8)
			if fair._coach:
				_coach(p + Vector2(40, 0))
			_horse(p, r, i)
			var tag: String = ("تو: " if r.me else "") + r.name
			draw_string(font, p + Vector2(98 if fair._coach else 34, -12), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0.6, 0.1, 0.05) if r.me else UiTheme.INK)  # behind the horse
		_breath(16 + LANE * n + 22)

	## A horse facing left at `p` (its hooves' line), legs swinging with its gallop.
	func _horse(p: Vector2, r: Dictionary, lane: int) -> void:
		var c: Color = Fair.COAT_LOOK[r.coat]
		var dark := c.darkened(0.45) if r.coat != 2 else Color(0.05, 0.05, 0.05)
		var s := 0.62
		var ph: float = r.phase
		var bob := absf(sin(ph)) * 3.0
		var o := p + Vector2(0, -bob)
		for k in 4:  # legs: front pair at the left
			var lx := (-22.0 if k < 2 else 20.0) + (k % 2) * 6.0
			var sw := sin(ph + k * 1.6) * 0.7
			var hip := o + Vector2(lx, -26) * s
			draw_line(hip, hip + Vector2(sin(sw), cos(sw)) * 30.0 * s, c.darkened(0.15) if k % 2 else c, 6.0 * s)
		var body := PackedVector2Array()
		for k in 18:
			var a := TAU * k / 18.0
			body.append(o + Vector2(cos(a) * 34.0, -36.0 + sin(a) * 15.0) * s)
		draw_colored_polygon(body, c)
		draw_colored_polygon(PackedVector2Array([o + Vector2(-26, -44) * s, o + Vector2(-46, -70) * s, o + Vector2(-36, -76) * s, o + Vector2(-14, -50) * s]), c)  # neck
		draw_colored_polygon(PackedVector2Array([o + Vector2(-38, -78) * s, o + Vector2(-62, -66) * s, o + Vector2(-60, -60) * s, o + Vector2(-38, -64) * s]), c)  # head
		draw_line(o + Vector2(-34, -76) * s, o + Vector2(-16, -52) * s, dark, 5.0 * s)  # mane
		draw_line(o + Vector2(32, -42) * s, o + Vector2(48, -24 + sin(ph * 2.0) * 4.0) * s, dark, 6.0 * s)  # tail
		if fair._coach:
			return  # the driver sits on the coach
		_rider(o + Vector2(-2, -50) * s, Fair.SHIRTS[lane % Fair.SHIRTS.size()], s, 0.25)

	func _rider(seat: Vector2, shirt: Color, s: float, lean: float) -> void:
		var top := seat + Vector2(-sin(lean), -cos(lean)) * 30.0 * s
		draw_line(seat, top, shirt, 10.0 * s)
		draw_line(seat + Vector2(0, -20) * s, seat + Vector2(-22, -10) * s, shirt, 5.0 * s)  # arms to the reins
		draw_circle(top + Vector2(-2, -8) * s, 7.0 * s, Color(0.85, 0.66, 0.5))
		draw_rect(Rect2(top + Vector2(-14, -16) * s, Vector2(24, 4) * s), Color(0.4, 0.26, 0.13))
		draw_rect(Rect2(top + Vector2(-8, -24) * s, Vector2(12, 9) * s), Color(0.4, 0.26, 0.13))

	## The stagecoach behind a horse: a box on two wheels with the driver up front.
	func _coach(p: Vector2) -> void:
		var s := 0.62
		draw_line(p + Vector2(-56, -34) * s, p + Vector2(-8, -34) * s, Color(0.3, 0.18, 0.08), 3.0)  # shaft
		draw_rect(Rect2(p + Vector2(-8, -78) * s, Vector2(58, 44) * s), Color(0.55, 0.16, 0.1))
		draw_rect(Rect2(p + Vector2(-4, -72) * s, Vector2(20, 16) * s), Color(0.92, 0.86, 0.7))
		draw_rect(Rect2(p + Vector2(-8, -82) * s, Vector2(58, 6) * s), Color(0.3, 0.18, 0.08))
		for wx in [4.0, 40.0]:
			draw_circle(p + Vector2(wx, -18) * s, 14.0 * s, Color(0.3, 0.18, 0.08))
			draw_circle(p + Vector2(wx, -18) * s, 8.0 * s, Color(0.75, 0.6, 0.35))
		_rider(p + Vector2(-2, -82) * s, Color(0.72, 0.16, 0.1), s, 0.15)

	func _breath(y: float) -> void:
		var me: Dictionary = {}
		for r in fair.racers:
			if r.me:
				me = r
		if me.is_empty():
			return
		var bar := Rect2(size.x * 0.5 - 300, y, 600, 26)
		draw_rect(bar, Color(0.3, 0.15, 0.04, 0.25))
		var fill := bar
		fill.size.x *= me.breath
		fill.position.x = bar.end.x - fill.size.x  # fills from the right
		draw_rect(fill, Color(0.75, 0.2, 0.12) if me.tired > 0.0 else Color(0.35, 0.6, 0.25))
		draw_rect(bar, UiTheme.INK, false, 3.0)
		var font := get_theme_default_font()
		var tag := "اسبت نفسش برید! یه کم یواش" if me.tired > 0.0 else "نفس اسبت"
		var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(font, Vector2(size.x * 0.5 - tw * 0.5, y + 50), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiTheme.INK)


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
	_text.custom_minimum_size = Vector2(980, 0)
	col.add_child(_text)
	_track.fair = self
	_track.custom_minimum_size = Vector2(980, 352)
	col.add_child(_track)
	_list.add_theme_constant_override("separation", 4)
	col.add_child(_list)
	_pads.alignment = BoxContainer.ALIGNMENT_CENTER
	var go := Button.new()
	go.text = "تند برو!"
	go.custom_minimum_size = Vector2(420, 110)
	go.add_theme_font_size_override("font_size", 36)
	go.button_down.connect(func(): hold = true)
	go.button_up.connect(func(): hold = false)
	_pads.add_child(go)
	col.add_child(_pads)
	_row.add_theme_constant_override("separation", 16)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_row)


func is_open() -> bool:
	return _panel.visible


## Called at each day change.
func new_day(d: int) -> void:
	if d % DayCycle.DAYS_PER_SEASON == DAY_IN_SEASON and (_racehorses().size() > 0 or _show_cows().size() > 0):
		_due = true


func _process(delta: float) -> void:
	if _due and not _panel.visible and not others.any(func(o): return o.is_open()):
		_due = false
		_held = []
		_fest = ""
		_invite()
	if not _panel.visible:
		return
	if not _over:
		_race_step(delta)
	elif _reveal >= 0 and _reveal < _entries.size():
		_beat -= delta
		if _beat <= 0.0:
			_beat = 0.9
			_announce()
	if autopilot:
		_bot()


# ---------- the fair board ----------

func _invite() -> void:
	_mode_view("")
	_title.text = "جشنواره‌ی شهر!"
	_text.text = "امروز تو شهر جشنواره‌ست. تو مسابقه‌ی اسب، اول %s دلار و جام طلا می‌بره؛ تو نمایشگاه گاو، بهترین گاو %s دلار و روبان آبی. هرچی ببری رنچت معروف‌تر می‌شه." % [UiTheme.fa(RACE_PRIZE[0]), UiTheme.fa(SHOW_PRIZE[0])]
	var opts := []
	var hs := _racehorses()
	opts.append(["مسابقه‌ی اسب" if not "race" in _held else "مسابقه‌ی اسب ✓", "horse", _race_setup, hs.is_empty() or "race" in _held])
	opts.append(["نمایشگاه گاو" if not "show" in _held else "نمایشگاه گاو ✓", "cow", _show_setup, _show_cows().is_empty() or "show" in _held])
	opts.append(["برگرد رنچ", "cancel", _close, false])
	if hs.is_empty():
		_text.text += "\nبرای مسابقه یه اسب بزرگ لازمه."
	_buttons(opts)
	_open()


## A festival's own contest: the stagecoach race or the big cattle show, straight to it.
func festival(kind: String, fest_name: String, fest_id: String) -> void:
	_fest = fest_id
	_held = ["race", "show"]
	_open()
	if kind == "coach":
		_coach = true
		_race_setup()
		_title.text = fest_name
	else:
		_show_setup()
		_title.text = fest_name


func _open() -> void:
	if not _panel.visible:
		_speed = day.speed if day.speed > 0.0 else _speed
		day.speed = 0.0
	_panel.visible = true
	_dim.visible = true


func _close() -> void:
	_over = true
	_reveal = -1
	_coach = false
	hold = false
	racers = []
	_panel.visible = false
	_dim.visible = false
	day.speed = _speed


func _back() -> void:
	if _fest != "":
		_close()
	else:
		_coach = false
		_invite()


func _mode_view(mode: String) -> void:
	_track.visible = mode == "race"
	_pads.visible = false
	_list.visible = mode == "show"


# ---------- the race ----------

## Grown horses, best first.
## A race is being run (for the gallop sound).
func racing() -> bool:
	return _panel.visible and not _over and t >= 0.0 and not racers.is_empty()


func _racehorses() -> Array:
	var hs := horses.list.filter(func(h): return horses.grown(h) and not Horses.wild(h))
	hs.sort_custom(func(a, b): return a.stars > b.stars)
	return hs


func _race_setup() -> void:
	_mode_view("")
	var hs := _racehorses()
	_pick = clampi(_pick, 0, maxi(hs.size() - 1, 0))
	_title.text = "مسابقه‌ی دلیجان" if _coach else "مسابقه‌ی اسب"
	var h: Dictionary = hs[_pick] if not hs.is_empty() else {}
	if h.is_empty():
		_text.text = "اسب بزرگی نداری؛ یه اسب کرایه‌ای %s می‌کشه." % Horses.stars_text(2)
	else:
		_text.text = "با «%s» (%s، %s) می‌ری؟ ستاره‌ی بیشتر یعنی تندتر. دکمه‌ی «تند برو!» رو نگه داری تاخت می‌ره، ولی نفسش که تموم شه یه مدت فقط یورتمه می‌ره؛ نفسش رو برای آخر نگه دار." % [h.name, Horses.COAT_NAMES[h.coat], Horses.stars_text(h.stars)]
	var opts := [["برو مسابقه  %s دلار" % UiTheme.fa(RACE_FEE), "horse", _race_start.bind(h), builder.money < RACE_FEE]]
	if hs.size() > 1:
		opts.append(["یه اسب دیگه", "rotate", func():
			_pick = (_pick + 1) % hs.size()
			_race_setup(), false])
	opts.append(["بی‌خیال", "cancel", _back, false])
	_buttons(opts)


## The field: other ranches' horses get better as the years go by and your ranch climbs.
func _race_start(h: Dictionary) -> void:
	builder.add_money(-RACE_FEE, "prize")
	var base := 1.7 + 0.12 * mini(progress.year(), 15) + 0.25 * (progress.level() - 1)
	var who := RIDERS.duplicate()
	who.shuffle()
	var names := RIDER_HORSES.duplicate()
	names.shuffle()
	racers = []
	for i in 4:
		var stars := clampi(roundi(base + _rng.randf_range(-1.0, 1.1)), 1, 5)
		var owner: String = who[i]
		if i == 0 and rival:  # the neighbours always bring a good one
			owner = Rival.NAME
			stars = clampi(roundi(base + 0.8), 2, 5)
		racers.append(_racer(names[i], owner, stars, _rng.randi() % Cowboy.COMMON, false))
	var me := _racer(h.get("name", "کرایه‌ای"), "تو", h.get("stars", 2), h.get("coat", 0), true)
	racers.insert(_rng.randi_range(1, 3), me)
	t = -1.6
	_after = -1.0
	_over = false
	hold = false
	_mode_view("race")
	_pads.visible = true
	_title.text = "مسابقه‌ی دلیجان!" if _coach else "مسابقه شروع شد!"
	_buttons([])
	_track.queue_redraw()


func _racer(nm: String, owner: String, stars: int, coat: int, me: bool) -> Dictionary:
	return {name = nm, who = owner, stars = stars, coat = coat, x = 0.0, breath = 1.0, tired = 0.0, me = me, fin = -1.0, phase = _rng.randf() * TAU,
		kick = _rng.randf_range(0.5, 0.78), save = _rng.randf_range(0.0, 0.18), form = _rng.randf_range(0.97, 1.03) if not me else 1.0}


static func pace(stars: int) -> float:
	return 5.2 + 0.5 * stars


func _race_step(delta: float) -> void:
	t += delta
	_track.queue_redraw()
	if t < 0.0:
		_text.text = "آماده..." if t < -0.6 else "برو!"
		return
	for r in racers:
		var flat := false
		if r.fin >= 0.0:
			flat = false
		elif r.me:
			flat = hold or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_UP)
			if autopilot:  # the bot gallops in bursts and keeps its breath for the end
				flat = r.breath > 0.6 or (r.x > TRACK * 0.72 and r.breath > 0.0)
		else:  # the others canter, then go flat out from their own point on, some keeping a little breath back
			flat = r.x > TRACK * r.kick and r.breath > r.save
		var v: float = (pace(r.stars) + (0.3 * Legacy.level("rider") if r.me else 0.0)) * r.form
		if r.tired > 0.0:
			r.tired -= delta
			v *= 0.62
			r.breath = minf(1.0, r.breath + REGAIN * 1.5 * delta)
		elif flat and r.breath > 0.0:
			v *= SPRINT
			r.breath -= DRAIN * delta
			if r.breath <= 0.0:
				r.breath = 0.0
				r.tired = TIRED
		else:
			r.breath = minf(1.0, r.breath + REGAIN * delta)
		if r.fin >= 0.0:
			v *= 0.4  # past the post: easing up
		r.x = minf(r.x + v * delta, TRACK + 6.0)
		r.phase += delta * v * 1.6
		if r.fin < 0.0 and r.x >= TRACK:
			r.fin = t
	var me := _me()
	var ahead := racers.filter(func(r): return not is_same(r, me) and (r.x > me.x or (r.fin >= 0.0 and r.fin < me.fin))).size()
	_text.text = "تو الان %sی" % PLACES[ahead] if me.fin < 0.0 else "از خط رد شدی: %s!" % PLACES[_place(me)]
	if me.fin >= 0.0:
		if _after < 0.0:
			_after = 0.0
			hold = false
			_pads.visible = false
		_after += delta
		if _after > 1.6:
			_race_end()


func _me() -> Dictionary:
	for r in racers:
		if r.me:
			return r
	return {}


## Place 0..4: anyone past the post sooner, or still running but ahead when you crossed, is in front.
func _place(me: Dictionary) -> int:
	return racers.filter(func(r): return not is_same(r, me) and r.fin >= 0.0 and r.fin < me.fin).size()


func _race_end() -> void:
	_over = true
	_track.queue_redraw()
	var me := _me()
	var p := _place(me)
	_held.append("race")
	won.emit("coach" if _coach else "race", p + 1)
	Sfx.play("cheer", 0.0 if p < 3 else -10.0)
	if p < 3:
		builder.add_money(RACE_PRIZE[p], "prize")
		progress.add(RACE_REP[p])
		_keep("race", p + 1, me.name)
		_title.text = "%s شدی!" % PLACES[p]
		_text.text = "«%s» %s شد. جایزه: %s دلار و یه %s که می‌ره تو خونه‌ی رنچ." % [me.name, PLACES[p], UiTheme.fa(RACE_PRIZE[p]), CUPS[p]]
		notify.call("تو مسابقه %s شدی: %s+ دلار" % [PLACES[p], UiTheme.fa(RACE_PRIZE[p])])
	else:
		_title.text = "%s شدی" % PLACES[p]
		_text.text = "این دفعه نشد. اسب بهتر (با ستاره‌ی بیشتر) تندتر می‌دوه؛ نفسش رو هم برای آخر نگه دار."
	var opts := []
	if _fest == "":
		opts.append(["برگرد جشنواره", "star", _back, false])
	else:
		opts.append(["عالیه", "star", _close, false])
	_buttons(opts)


# ---------- the cattle show ----------

## What the judges see: weight (most of it), breed, health and a good feed. Out of about 100.
static func score(c: Dictionary, today: int) -> float:
	var s := clampf(c.weight / 650.0, 0.0, 1.0) * 50.0
	s += Herd.SHOW[c.breed]
	s += 10.0 if c.sick < 0.0 else 0.0
	s += 5.0 if c.vacc >= today else 0.0
	s += 10.0 * (1.0 - maxf(c.hunger, c.thirst))
	return s


func _show_cows() -> Array:
	var cs := herd.alive().filter(func(c): return c.weight >= SHOW_KG)
	cs.sort_custom(func(a, b): return score(a, day.day) > score(b, day.day))
	return cs.slice(0, 6)


func _show_setup() -> void:
	_mode_view("")
	_reveal = -1
	var cs := _show_cows()
	if cs.is_empty():
		_title.text = "نمایشگاه گاو"
		_text.text = "گاوی نداری که به نمایشگاه ببری؛ گاوها باید دست‌کم %s کیلو باشن." % UiTheme.fa(int(SHOW_KG))
		_buttons([["باشه", "cancel", _back, false]])
		return
	_pick = clampi(_pick, 0, cs.size() - 1)
	if _cow.is_empty() or not _cow in cs:
		_cow = cs[_pick]
		_groomed = false
	_title.text = "نمایشگاه گاو"
	var s := score(_cow, day.day) + (GROOM_PTS if _groomed else 0.0)
	_text.text = "«%s» رو می‌بری؟ نژاد %s، %s کیلو. داورها به وزن، نژاد، سلامت و سیر بودنش نگاه می‌کنن؛ به نظر خودت %s از ۱۰۰ می‌گیره.%s" % [
		_cow.name, Herd.BREEDS[_cow.breed].name, UiTheme.fa(int(_cow.weight)), UiTheme.fa(int(s)), "\nحسابی تمیز و براقش کردی." if _groomed else ""]
	var opts := [["ببرش جلوی داورها", "cow", _judge, false]]
	if not _groomed:
		opts.append(["بشور و برسش بزن  %s دلار" % UiTheme.fa(GROOM), "vet", func():
			builder.add_money(-GROOM, "prize")
			_groomed = true
			_show_setup(), builder.money < GROOM])
	if cs.size() > 1:
		opts.append(["یه گاو دیگه", "rotate", func():
			_pick = (_pick + 1) % cs.size()
			_cow = cs[_pick]
			_groomed = false
			_show_setup(), false])
	opts.append(["بی‌خیال", "cancel", _back, false])
	_buttons(opts)


func _judge() -> void:
	var y := mini(progress.year(), 12)
	var names := SHOW_COWS.duplicate()
	names.shuffle()
	var who := RIDERS.duplicate()
	who.shuffle()
	_entries = [[_cow.name, "تو", score(_cow, day.day) + (GROOM_PTS if _groomed else 0.0), true]]
	for i in 4:
		var s := _rng.randf_range(50.0, 74.0) + y
		var owner: String = who[i]
		if i == 0 and rival:
			owner = Rival.NAME
			s = _rng.randf_range(62.0, 82.0) + y * 0.8
		_entries.append([names[i], owner, s, false])
	for e in _entries:  # the judges don't all see it the same
		e[2] = clampf(e[2] + _rng.randf_range(-3.0, 3.0), 0.0, 100.0)
	_entries.sort_custom(func(a, b): return a[2] > b[2])
	for c in _list.get_children():
		c.queue_free()
	_mode_view("show")
	_title.text = "داورها دارن نگاه می‌کنن..."
	_text.text = "پنج تا گاو اومدن جلوی داورها. از آخر اعلام می‌کنن:"
	_buttons([])
	_reveal = 0
	_beat = 1.2


## Calls the next entry, from the last place up.
func _announce() -> void:
	var i := _entries.size() - 1 - _reveal
	var e: Array = _entries[i]
	var line := "%s: «%s» از %s  (%s امتیاز)" % [PLACES[i], e[0], e[1], UiTheme.fa(int(e[2]))]
	if i < 3:
		line += "  " + RIBBONS[i]
	_list.add_child(UiTheme.label(line, 26 if i > 0 else 30, Color(0.6, 0.1, 0.05) if e[3] else UiTheme.INK))
	_list.move_child(_list.get_child(_list.get_child_count() - 1), 0)  # the best ends up on top
	_reveal += 1
	if _reveal >= _entries.size():
		_show_end()


func _show_end() -> void:
	var p := 0
	for i in _entries.size():
		if _entries[i][3]:
			p = i
	_held.append("show")
	won.emit("show", p + 1)
	if p < 3:
		builder.add_money(SHOW_PRIZE[p], "prize")
		progress.add(SHOW_REP[p])
		_keep("show", p + 1, _cow.name)
		_cow.ribbon = mini(int(_cow.get("ribbon", 9)), p + 1)
		_title.text = "%s گرفت!" % RIBBONS[p]
		_text.text = "«%s» %s شد: %s دلار جایزه و %s. روبانش رو گردنش می‌مونه." % [_cow.name, PLACES[p], UiTheme.fa(SHOW_PRIZE[p]), RIBBONS[p]]
		notify.call("«%s» تو نمایشگاه %s گرفت: %s+ دلار" % [_cow.name, RIBBONS[p], UiTheme.fa(SHOW_PRIZE[p])])
	else:
		_title.text = "این دفعه روبان نگرفت"
		_text.text = "«%s» %s شد. گاو سنگین‌تر، سیر و سالم و واکسن‌زده امتیاز بیشتری می‌گیره." % [_cow.name, PLACES[p]]
	_cow = {}
	_buttons([["برگرد جشنواره" if _fest == "" else "عالیه", "star", _back, false]])


func _keep(kind: String, place: int, who: String) -> void:
	trophies.append({k = kind, p = place, y = progress.year(), s = day.season(), who = who, fest = _fest})


## How many of each: "race1" -> 2 ...
func counts() -> Dictionary:
	var n := {}
	for tr in trophies:
		var key: String = "%s%d" % [tr.k, tr.p]
		n[key] = n.get(key, 0) + 1
	return n


# ---------- shared ----------

## options: [[label, icon, Callable, disabled]]
func _buttons(options: Array) -> void:
	for c in _row.get_children():
		c.queue_free()
	for o in options:
		var b := builder._button(Button.new(), o[0], o[2], o[1])
		b.disabled = o[3]
		_row.add_child(b)


## Test bot: enters what it can and takes whatever comes.
func _bot() -> void:
	if not _over or (_reveal >= 0 and _reveal < _entries.size()):
		return
	var btns := _row.get_children().filter(func(b): return not b.disabled and not b.is_queued_for_deletion())
	if btns.is_empty():
		return
	_bot_t = _bot_t - get_process_delta_time()
	if _bot_t > 0.0:
		return
	_bot_t = 1.0
	print("   FAIR ", _title.text, " | ", _text.text.left(70).replace("\n", " "))
	btns[0].pressed.emit()


func to_save() -> Dictionary:
	return {trophies = trophies}


func from_save(d: Dictionary) -> void:
	trophies = d.get("trophies", [])
	for tr in trophies:
		tr.p = int(tr.p)
		tr.y = int(tr.y)
		tr.s = int(tr.s)
