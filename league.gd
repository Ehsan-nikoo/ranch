## The county league table: your ranch against eight others (Blackwood among them) for the best season.
## A ranch's season score is what its cattle sold for that season plus 25 for every point of fame it
## gained. The others' scores grow through the season, each at its own pace, and how far they get
## is set from your own last seasons, so there's always someone just ahead to catch. When the season
## ends the top three get a prize, the table starts again, and your best results are kept as records.
class_name League
extends CanvasLayer

const RIVALS := [["رنچ بلک‌وود", 1.2], ["رنچ ستاره‌ی شمال", 1.1], ["رنچ دره‌ی سبز", 1.0], ["رنچ نعل طلا", 0.92],
	["رنچ رود سرخ", 0.85], ["رنچ کوهپایه", 0.78], ["رنچ سه برادر", 0.7], ["رنچ بید مجنون", 0.6]]
const REP_POINTS := 25          # score for each point of fame gained
const PRIZE := [[1500, 15.0], [800, 8.0], [400, 4.0]]   # first, second, third: dollars and fame
const FLOOR := 2000             # what the others aim for while your own seasons are still small

var day: DayCycle
var builder: Builder
var progress: Progress
var notify: Callable

var season := -1               # index of the season being played (day / DAYS_PER_SEASON)
var sales := 0                 # your cattle sales this season
var rep_start := 0.0           # your fame when the season began
var targets: Array = []        # each rival's final score this season
var paces: Array = []          # how its score grows through the season (frac ^ pace)
var past: Array = []           # your last few season scores
var best := {score = 0, rank = 0, wins = 0, podiums = 0, seasons = 0}
var last := {}                 # the last season's final table, for the board: {rank, score}
var _rng := RandomNumberGenerator.new()
var _panel: PanelContainer
var _dim: ColorRect
var _when := UiTheme.label("", 24, Color(0.32, 0.18, 0.08))
var _grid := GridContainer.new()
var _records := UiTheme.label("", 22, Color(0.32, 0.18, 0.08))


func _ready() -> void:
	_rng.randomize()
	builder.money_moved.connect(func(delta: int, why: String):
		if why == "sale" and delta > 0:
			sales += delta)
	builder.bar_button("جدول رتبه", toggle, "rank")
	_dim = UiTheme.dim(toggle)
	_panel = UiTheme.board()
	add_child(_dim)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	col.add_child(UiTheme.header("جدول رتبه‌ی ایالت", builder._button(Button.new(), "بستن", toggle, "cancel")))
	_when.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_when.custom_minimum_size = Vector2(1060, 0)
	col.add_child(_when)
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 60)
	_grid.add_theme_constant_override("v_separation", 2)
	var c := CenterContainer.new()
	c.add_child(_grid)
	col.add_child(c)
	_records.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_records.custom_minimum_size = Vector2(1060, 0)
	col.add_child(_records)
	if season < 0:
		_start(day.day / DayCycle.DAYS_PER_SEASON)


func is_open() -> bool:
	return _panel.visible


func toggle() -> void:
	_panel.visible = not _panel.visible
	_dim.visible = _panel.visible
	if _panel.visible:
		_refresh()


## Your score this season so far.
func my_score() -> int:
	return sales + int(maxf(0.0, progress.rep - rep_start) * REP_POINTS)


func _frac() -> float:
	return clampf((day.day % DayCycle.DAYS_PER_SEASON + day.hour / 24.0) / DayCycle.DAYS_PER_SEASON, 0.0, 1.0)


## Each ranch's score now: [name, score, is it yours], best first.
func table(frac := -1.0) -> Array:
	if frac < 0.0:
		frac = _frac()
	var rows := [[Decor.shown_name(), my_score(), true]]
	for i in RIVALS.size():
		rows.append([RIVALS[i][0], int(targets[i] * pow(frac, paces[i])), false])
	rows.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and a[2]))
	return rows


func _start(s: int) -> void:
	season = s
	sales = 0
	rep_start = progress.rep
	var base := FLOOR
	if not past.is_empty():
		base = maxi(FLOOR, int(past.reduce(func(a, b): return a + b, 0) / float(past.size())))
	targets = []
	paces = []
	for r in RIVALS:
		targets.append(int(base * r[1] * _rng.randf_range(0.85, 1.15) / 10.0) * 10)
		paces.append(_rng.randf_range(0.8, 1.25))


## Called each morning: when a season ends, the table is final, prizes go out and a new one starts.
func new_day(d: int) -> void:
	var s := d / DayCycle.DAYS_PER_SEASON
	if s == season:
		return
	if season >= 0 and not targets.is_empty():
		_finish()
	_start(s)


func _finish() -> void:
	var rows := table(1.0)
	var rank := 1 + rows.find(rows.filter(func(r): return r[2])[0])
	var score := my_score()
	past.append(score)
	while past.size() > 3:
		past.pop_front()
	best.seasons = int(best.seasons) + 1
	best.score = maxi(int(best.score), score)
	best.rank = rank if int(best.rank) == 0 else mini(int(best.rank), rank)
	last = {rank = rank, score = score}
	if rank <= PRIZE.size():
		best.podiums = int(best.podiums) + 1
		if rank == 1:
			best.wins = int(best.wins) + 1
		var p: Array = PRIZE[rank - 1]
		builder.add_money(p[0], "prize")
		progress.add(p[1])
		notify.call("فصل تموم شد و تو جدول رتبه‌ی ایالت نفر %s شدی! %s دلار جایزه" % [UiTheme.fa(rank), UiTheme.fa(p[0])])
	else:
		notify.call("فصل تموم شد: تو جدول رتبه‌ی ایالت نفر %s از %s شدی. فصل بعد!" % [UiTheme.fa(rank), UiTheme.fa(rows.size())])


func _refresh() -> void:
	var left := (1.0 - _frac()) * DayCycle.DAYS_PER_SEASON * 24.0
	var mins := maxi(1, ceili(left * DayCycle.SECONDS_PER_HOUR / 60.0))
	_when.text = "امتیاز این فصل: پول فروش گاو + %s برای هر امتیاز شهرت. تا آخر فصل حدود %s مونده. نفر اول تا سوم جایزه می‌گیرن: %s، %s و %s دلار." % [
		UiTheme.fa(REP_POINTS), ("%s دقیقه" % UiTheme.fa(mins)) if mins < 60 else ("%s ساعت%s" % [UiTheme.fa(roundi(mins / 30.0) / 2), " و نیم" if roundi(mins / 30.0) % 2 == 1 else ""]),
		UiTheme.fa(PRIZE[0][0]), UiTheme.fa(PRIZE[1][0]), UiTheme.fa(PRIZE[2][0])]
	for c in _grid.get_children():
		c.queue_free()
	var rows := table()
	for h in ["امتیاز", "رنچ", "رتبه"]:  # columns right to left: rank, ranch, score
		_grid.add_child(UiTheme.label(h, 24, Color(0.32, 0.18, 0.08)))
	for i in rows.size():
		var r: Array = rows[i]
		var col := Color(0.6, 0.1, 0.05) if r[2] else UiTheme.INK
		_grid.add_child(UiTheme.label(UiTheme.fa(r[1]), 25, col))
		_grid.add_child(UiTheme.label(("تو: " if r[2] else "") + r[0], 25, col))
		_grid.add_child(UiTheme.label(UiTheme.fa(i + 1), 25, col))
	var lines := []
	if not last.is_empty():
		lines.append("فصل قبل: نفر %s با %s امتیاز." % [UiTheme.fa(int(last.rank)), UiTheme.fa(int(last.score))])
	if int(best.seasons) > 0:
		lines.append("رکوردهات: بهترین رتبه %s، بهترین امتیاز %s، %s بار اول، %s بار تو سه نفر اول، از %s فصل." % [UiTheme.fa(int(best.rank)), UiTheme.fa(int(best.score)),
			UiTheme.fa(int(best.wins)), UiTheme.fa(int(best.podiums)), UiTheme.fa(int(best.seasons))])
	else:
		lines.append("هنوز هیچ فصلی تموم نشده. اولین فصلت رو خوب تموم کن!")
	_records.text = "\n".join(lines)


func _process(_delta: float) -> void:
	if _panel.visible and Engine.get_process_frames() % 30 == 0:
		_refresh()


func to_save() -> Dictionary:
	return {season = season, sales = sales, rep_start = rep_start, targets = targets, paces = paces, past = past, best = best, last = last}


func from_save(d: Dictionary) -> void:
	season = int(d.get("season", -1))
	sales = int(d.get("sales", 0))
	rep_start = float(d.get("rep_start", 0.0))
	targets = d.get("targets", []).map(func(x): return int(x))
	paces = d.get("paces", []).map(func(x): return float(x))
	past = d.get("past", []).map(func(x): return int(x))
	best = d.get("best", best)
	last = d.get("last", {})
	if targets.size() != RIVALS.size() or paces.size() != RIVALS.size():
		season = -1  # rebuilt in _ready
