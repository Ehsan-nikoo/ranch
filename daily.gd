## Every real day: a prize for coming back (bigger each day in a row, a week round), and three small
## jobs for the day with a prize each, plus a bonus for all three. Opened from the «امروز» button at
## the top left; the button wears a red mark while today's prize is waiting. Days follow the phone's
## own calendar, not the ranch's clock.
class_name Daily
extends CanvasLayer

const STREAK := [200, 300, 400, 500, 700, 900, 1500]   # the prize on day 1..7 in a row, then round again
const JOB_PRIZE := 250
const JOB_REP := 2
const BONUS := 500
const BONUS_REP := 5
# id, text, what's counted, target
const JOBS := [
	["sell", "%s دلار گاو بفروش", "sale", 1500],
	["calves", "%s تا گوساله یا گاو بخر", "cattle", 3],
	["hay", "%s بسته یونجه بخر یا بچین", "hay", 20],
	["deal", "یه قرارداد تحویل بده", "deal", 1],
	["build", "یه چیزی بساز، ارتقا بده یا زمین بخر", "build", 1],
	["vet", "یه بار دامپزشک بیار یا واکسن بزن", "vet", 1],
	["horse", "یه اسب بخر یا بفروش", "horses", 1],
]

var builder: Builder
var market: Market
var herd: Herd
var progress: Progress
var world: Node3D
var notify: Callable
var can_pop := func(): return true    # not while the first-game tips are still going
var last_claim := -1      # local day number of the last prize taken
var streak := 0           # days in a row up to last_claim
var jobs_day := -1
var jobs: Array = []      # ids of today's three jobs
var got := {}             # what's counted -> today's amount
var paid: Array = []      # job ids already paid today
var bonus_paid := false
var _button: Button
var _mark: Label
var _panel: PanelContainer
var _dim: ColorRect
var _days := HBoxContainer.new()
var _claim: Button
var _list := VBoxContainer.new()
var _bonus := UiTheme.label("", 23, Color(0.32, 0.18, 0.08))
var _t := 0.0
var _popped := false


## Today on the phone's calendar, as a day count.
static func today() -> int:
	var t: float = Time.get_unix_time_from_system() + Time.get_time_zone_from_system().get("bias", 0) * 60.0
	return int(floorf(t / 86400.0))


func _ready() -> void:
	_button = Button.new()
	_button.text = "امروز"
	_button.icon = load("res://ui/icons/gift.png")
	_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_button.custom_minimum_size = Vector2(170, 104)
	_button.add_theme_font_size_override("font_size", 26)
	_button.position = Vector2(204, 8)
	_button.pressed.connect(toggle)
	add_child(_button)
	_mark = UiTheme.label("!", 30, Color.WHITE)
	var dot := StyleBoxFlat.new()
	dot.bg_color = Color(0.8, 0.12, 0.08)
	dot.set_corner_radius_all(18)
	dot.content_margin_left = 12
	dot.content_margin_right = 12
	_mark.add_theme_stylebox_override("normal", dot)
	_mark.position = Vector2(4, -4)
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.add_child(_mark)

	var over := CanvasLayer.new()
	over.layer = 3
	add_child(over)
	_dim = UiTheme.dim(toggle)
	_panel = UiTheme.board()
	over.add_child(_dim)
	over.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_panel.add_child(col)
	var close := Button.new()
	close.text = "بستن"
	close.icon = load("res://ui/icons/cancel.png")
	close.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	close.custom_minimum_size = Vector2(190, 96)
	close.add_theme_font_size_override("font_size", 26)
	close.pressed.connect(toggle)
	col.add_child(UiTheme.header("کارهای امروز", close))
	col.add_child(UiTheme.label("جایزه‌ی هر روز: هر روز پشت هم که سر بزنی، بیشتر می‌شه", 25))
	_days.alignment = BoxContainer.ALIGNMENT_CENTER
	_days.add_theme_constant_override("separation", 8)
	col.add_child(_days)
	_claim = Button.new()
	_claim.icon = load("res://ui/icons/gift.png")
	_claim.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_claim.custom_minimum_size = Vector2(420, 96)
	_claim.add_theme_font_size_override("font_size", 26)
	_claim.pressed.connect(claim)
	var mid := CenterContainer.new()
	mid.add_child(_claim)
	col.add_child(mid)
	col.add_child(UiTheme.label("سه تا کار امروز (هر کدوم %s دلار):" % UiTheme.fa(JOB_PRIZE), 25))
	_list.add_theme_constant_override("separation", 4)
	col.add_child(_list)
	col.add_child(_bonus)

	builder.money_moved.connect(_on_money)
	market.sold.connect(func(_cash: int, contract: bool):
		if contract:
			_count("deal", 1))
	_new_day()
	_refresh()


## A fresh set of jobs when the phone's date has moved on.
func _new_day() -> void:
	var d := today()
	if jobs_day == d:
		return
	jobs_day = d
	got = {}
	paid = []
	bonus_paid = false
	var pool := JOBS.filter(func(j): return _fits(j[0]))
	var rng := RandomNumberGenerator.new()
	rng.seed = d  # the same three all day, even after a restart
	jobs = []
	while jobs.size() < 3 and not pool.is_empty():
		jobs.append(pool.pop_at(rng.randi_range(0, pool.size() - 1))[0])


## Jobs that make sense on this ranch today.
func _fits(id: String) -> bool:
	match id:
		"vet":
			return herd.alive().size() >= 5
		"horse":
			return Building.built(world, HorseStable) or Building.built(world, Corral)
		"deal":
			return herd.alive().size() >= 5
	return true


func _on_money(delta: int, why: String) -> void:
	match why:
		"sale":
			if delta > 0:
				_count("sale", delta)
		"cattle":
			if delta < 0:
				_count("cattle", 1)
		"hay":
			if delta <= 0:
				_count("hay", HerdUI.HAY_LOT)
		"build", "vet", "horses":
			if delta != 0:
				_count(why, 1)


func _count(kind: String, n: int) -> void:
	_new_day()
	got[kind] = got.get(kind, 0) + n
	for j in JOBS:
		if j[0] in jobs and not j[0] in paid and j[2] == kind and got[kind] >= j[3]:
			paid.append(j[0])
			builder.add_money(JOB_PRIZE, "prize")
			progress.add(JOB_REP)
			notify.call("یکی از کارهای امروز تموم شد: «%s». %s دلار جایزه" % [text(j), UiTheme.fa(JOB_PRIZE)])
	if not bonus_paid and not jobs.is_empty() and jobs.all(func(id): return id in paid):
		bonus_paid = true
		builder.add_money(BONUS, "prize")
		progress.add(BONUS_REP)
		notify.call("هر سه تا کار امروز رو انجام دادی! %s دلار جایزه‌ی اضافه" % UiTheme.fa(BONUS))
	_refresh()


static func text(j: Array) -> String:
	return j[1] % UiTheme.fa(j[3]) if "%s" in j[1] else j[1]


func claimed() -> bool:
	return last_claim == today()


## The day in a row today's prize would be (1 to 7).
func next_day() -> int:
	var run := streak + 1 if last_claim == today() - 1 else 1
	return (run - 1) % STREAK.size() + 1


func claim() -> void:
	if claimed():
		return
	var n := next_day()
	streak = streak + 1 if last_claim == today() - 1 else 1
	last_claim = today()
	var prize: int = STREAK[n - 1]
	builder.add_money(prize, "prize")
	if n == STREAK.size():
		progress.add(10)  # a whole week in a row
	notify.call("جایزه‌ی روز %s رو گرفتی: %s دلار" % [UiTheme.fa(n), UiTheme.fa(prize)])
	_refresh()


func toggle() -> void:
	_panel.visible = not _panel.visible
	_dim.visible = _panel.visible
	_new_day()
	_refresh()


func _refresh() -> void:
	_mark.visible = not claimed()
	if not _panel.visible:
		return
	for c in _days.get_children():
		c.queue_free()
	var now := next_day() if not claimed() else (streak - 1) % STREAK.size() + 1
	for i in range(STREAK.size() - 1, -1, -1):  # day 1 on the right
		var box := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		var past := i + 1 < now or (i + 1 == now and claimed())
		sb.bg_color = Color(0.35, 0.55, 0.15, 0.35) if past else (Color(0.85, 0.55, 0.1, 0.45) if i + 1 == now else Color(0.3, 0.15, 0.04, 0.16))
		sb.border_color = Color(0.3, 0.16, 0.05, 0.6)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(8)
		box.add_theme_stylebox_override("panel", sb)
		box.custom_minimum_size = Vector2(130, 0)
		var l := UiTheme.label("روز %s\n%s%s" % [UiTheme.fa(i + 1), "✓ " if past else "", UiTheme.fa(STREAK[i])], 22)
		box.add_child(l)
		_days.add_child(box)
	_claim.disabled = claimed()
	_claim.text = "فردا دوباره سر بزن" if claimed() else "بگیر: %s دلار" % UiTheme.fa(STREAK[now - 1])
	for c in _list.get_children():
		c.queue_free()
	for j in JOBS:
		if not j[0] in jobs:
			continue
		var done: bool = j[0] in paid
		var line := "%s  %s" % ["✓" if done else "○", text(j)]
		if not done and j[3] > 1:
			line += "  (%s از %s)" % [UiTheme.fa(mini(got.get(j[2], 0), j[3])), UiTheme.fa(j[3])]
		_list.add_child(UiTheme.label(line, 24, Color(0.15, 0.4, 0.1) if done else UiTheme.INK))
	_bonus.text = "هر سه تا انجام شد!" if bonus_paid else "هر سه تا رو انجام بدی، %s دلار جایزه‌ی اضافه" % UiTheme.fa(BONUS)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 2.0
	if jobs_day != today():  # midnight passed with the game open
		_new_day()
		_refresh()
	# today's prize waiting: open the board once a session, when the first-game tips are done
	if not _popped and not claimed() and can_pop.call():
		_popped = true
		if not _panel.visible:
			toggle()


func to_save() -> Dictionary:
	return {last_claim = last_claim, streak = streak, jobs_day = jobs_day, jobs = jobs, got = got, paid = paid, bonus_paid = bonus_paid}


func from_save(d: Dictionary) -> void:
	last_claim = int(d.get("last_claim", -1))
	streak = int(d.get("streak", 0))
	jobs_day = int(d.get("jobs_day", -1))
	jobs = d.get("jobs", [])
	got = {}
	for k in d.get("got", {}):
		got[k] = int(d.got[k])
	paid = d.get("paid", [])
	bonus_paid = bool(d.get("bonus_paid", false))
