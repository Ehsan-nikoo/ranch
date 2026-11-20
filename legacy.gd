## Generations: every GENERATION years the ranch passes to the next generation of the family. The
## handover board sums up how the last one did, names the heir, and the family picks one of three
## heirlooms: a knack the family keeps for good (they add up over the generations: greener grass,
## sharper selling, fewer sick cows...) or the old folks' savings. The family wall (from the ranch
## house) lists every generation and what it left. It never ends; the first handovers also bring a
## new era (Progress.ERAS: the railroad, then the cities). The game never stops.
class_name Legacy
extends CanvasLayer

const GENERATION := 70        # years each generation runs the ranch
const HANDOVER := [
	"",
	"پدربزرگ دیگه پیر شده و رنچ رو سپرد دست بچه‌هاش. حالا نسل دوم کار رو ادامه می‌ده.",
	"بچه‌ها هم موهاشون سفید شد؛ حالا نوه‌ها رنچ رو می‌چرخونن.",
]
const HEIRS := ["آرش", "مریم", "کاوه", "نیلوفر", "بهرام", "شیرین", "سیاوش", "پریسا", "داریوش", "مهتاب", "بردیا", "ترانه", "کیان", "آیدا"]
# id: name, what it does (each pick of the same one adds up)
const TRAITS := {
	green = ["دست سبز", "علف رنچ ۱۵ درصد زودتر دوباره درمیاد"],
	trader = ["تاجر زیرک", "گاوها ۵ درصد گرون‌تر فروش می‌رن"],
	healthy = ["دامدار کاربلد", "گاوها ۱۵ درصد کمتر مریض می‌شن"],
	rider = ["سوارکار ماهر", "اسبت تو مسابقه و تعقیب اسب وحشی تندتر می‌دوه"],
	name = ["اسم و رسم", "هر روز صبح یه امتیاز شهرت بیشتر"],
	thrifty = ["قناعت", "حقوق کارگرها ۱۰ درصد کمتر"],
	builder = ["بنّای خونوادگی", "ساختن و ارتقا ۲۰ درصد زودتر تموم می‌شه"],
	savings = ["پس‌انداز پدربزرگ", "۵۰۰۰ دلار همین الان (فقط یه بار)"],
}
const SAVINGS := 5000

## The family's knacks so far: id -> how many times picked. Static so any system can read them.
static var traits := {}

var day: DayCycle
var herd: Herd
var market: Market
var builder: Builder
var progress: Progress
var goals: Goals
var notify: Callable
var seen: Array = []           # generations whose handover was announced
var start := {money = 12000, herd = 0, rep = 0.0}   # where this generation began (a fresh ranch: taken in _ready)
var family: Array = []         # one {g, name, from, to, money, herd, rep, picked} per generation that has handed over
var head := ""                 # who runs the ranch now ("" = you, the founder)
var _picks: Array = []         # the three heirlooms on offer
var _heir := ""
var _panel: PanelContainer
var _dim: ColorRect
var _title := UiTheme.label("", 42)
var _text := UiTheme.label("", 24)
var _row := HBoxContainer.new()
var _wall: PanelContainer
var _wall_dim: ColorRect
var _wall_list := VBoxContainer.new()
var _rng := RandomNumberGenerator.new()
var _loaded := false


func _init() -> void:
	traits = {}  # a fresh ranch (the save, if any, fills them in)


## How many times the family picked knack `id`.
static func level(id: String) -> int:
	return int(traits.get(id, 0))


func _ready() -> void:
	_rng.randomize()
	layer = 5
	if not _loaded:  # a new ranch: the founder starts from what's here now
		_snapshot()
	_dim = UiTheme.dim(func(): pass)
	_panel = UiTheme.board()
	add_child(_dim)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	_panel.add_child(col)
	col.add_child(_title)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(1080, 0)
	col.add_child(_text)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 16)
	col.add_child(_row)
	_wall_dim = UiTheme.dim(toggle_wall)
	_wall = UiTheme.board()
	add_child(_wall_dim)
	add_child(_wall)
	var wc := VBoxContainer.new()
	wc.add_theme_constant_override("separation", 12)
	_wall.add_child(wc)
	wc.add_child(UiTheme.header("دیوار خونواده", builder._button(Button.new(), "بستن", toggle_wall, "cancel")))
	_wall_list.add_theme_constant_override("separation", 10)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(1120, 520)
	sc.add_child(_wall_list)
	_wall_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wc.add_child(sc)
	if not family.is_empty() and family[-1].picked == "":  # closed before an heirloom was picked
		if _heir == "":
			_heir = HEIRS[_rng.randi() % HEIRS.size()]
		_offer.call_deferred("نسل تازه اومده و هنوز ارثیه‌ش رو انتخاب نکردی.")


func is_open() -> bool:
	return _panel.visible or _wall.visible


func _year_days() -> int:
	return DayCycle.DAYS_PER_SEASON * 4


func _gained() -> Dictionary:
	return {money = builder.money - int(start.money), herd = herd.alive().size(), rep = maxi(0, int(progress.rep - float(start.rep)))}


func _summary() -> String:
	var g := _gained()
	return "تو این نسل:  پول %s%s دلار،  گله از %s به %s تا گاو،  شهرت %s امتیاز بیشتر شد" % [
		"+" if g.money >= 0 else "-", UiTheme.fa(absi(g.money)), UiTheme.fa(int(start.herd)), UiTheme.fa(g.herd), UiTheme.fa(g.rep)]


func _snapshot() -> void:
	start = {money = builder.money, herd = herd.alive().size(), rep = progress.rep}


## The handover text for generation `g` (1 = the children of the founder).
func _handover(g: int) -> String:
	var lines := []
	var e := progress.era()
	if e > 0 and g == e:  # this handover also starts a new era
		lines.append(Progress.ERAS[e][1])
	lines.append(HANDOVER[g] if g < HANDOVER.size() else "نسل %s خانواده‌ت حالا رنچ رو می‌چرخونه." % UiTheme.fa(g + 1))
	if e > 0 and g == e and Progress.ERAS[e][3] != "":
		lines.append(Progress.ERAS[e][3])
	lines.append(_summary())
	return "\n".join(lines)


func new_day(d: int) -> void:
	if d % _year_days() != 0:
		return
	var y := d / _year_days()
	if y == 0 or y % GENERATION != 0:
		return
	var g := y / GENERATION
	if g in seen:
		return
	seen.append(g)
	_hand_over(g, y)


func _hand_over(g: int, y: int) -> void:
	var used := family.map(func(f): return f.name)
	var free := HEIRS.filter(func(n): return not n in used)
	_heir = free[_rng.randi() % free.size()] if not free.is_empty() else HEIRS[_rng.randi() % HEIRS.size()]
	var gained := _gained()
	family.append({g = g, name = head, from = y - GENERATION + 1, to = y, money = gained.money, herd = gained.herd, rep = gained.rep, picked = ""})
	_offer(_handover(g))


## The handover board: the heir and three heirlooms to pick from (it waits for a pick, even across a restart).
func _offer(story: String) -> void:
	_title.text = "نسل تازه!"
	_text.text = story + "\nحالا «%s» رنچ رو می‌چرخونه. خونواده یه ارثیه براش گذاشته؛ یکی رو انتخاب کن:" % _heir
	var ids: Array = TRAITS.keys()
	ids.shuffle()
	_picks = ids.slice(0, 3)
	for c in _row.get_children():
		c.queue_free()
	for id in _picks:
		var t: Array = TRAITS[id]
		var b := builder._button(Button.new(), "%s\n%s" % [t[0], t[1]], _pick.bind(id), "")
		b.custom_minimum_size = Vector2(340, 150)
		b.add_theme_font_size_override("font_size", 23)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_row.add_child(b)
	_panel.visible = true
	_dim.visible = true
	Sfx.play("handbell")


func _pick(id: String) -> void:
	_panel.visible = false
	_dim.visible = false
	family[-1].picked = id
	if id == "savings":
		builder.add_money(SAVINGS, "prize")
	else:
		traits[id] = level(id) + 1
	head = _heir
	progress._apply()
	notify.call("«%s» حالا صاحب رنچه. ارثیه‌ی خونواده: %s" % [head, TRAITS[id][0]])
	_snapshot()


# ---------- the family wall ----------

func toggle_wall() -> void:
	_wall.visible = not _wall.visible
	_wall_dim.visible = _wall.visible
	if _wall.visible:
		_fill_wall()


func _fill_wall() -> void:
	for c in _wall_list.get_children():
		c.queue_free()
	var y := day.day / _year_days() + 1
	var gen := family.size() + 1
	var next := GENERATION * gen - (y - 1)
	_line("نسل %s: %s، از سال %s تا الان. تا نسل بعد %s سال مونده." % [UiTheme.fa(gen), "«%s»" % head if head != "" else "خودت (بنیان‌گذار رنچ)",
		UiTheme.fa(GENERATION * (gen - 1) + 1), UiTheme.fa(maxi(1, next))], 26, UiTheme.INK)
	var knacks := traits.keys().map(func(k): return "%s%s" % [TRAITS[k][0], " ×%s" % UiTheme.fa(traits[k]) if traits[k] > 1 else ""])
	_line("ارثیه‌های خونواده: " + ("، ".join(knacks) if not knacks.is_empty() else "هنوز هیچی؛ هر نسل که عوض بشه یکی اضافه می‌شه"), 23, Color(0.15, 0.4, 0.1))
	for i in range(family.size() - 1, -1, -1):
		var f: Dictionary = family[i]
		_line("نسل %s: %s، سال %s تا %s.  پول %s%s دلار، گله‌ی %s تایی، %s امتیاز شهرت.  ارثیه‌ای که گذاشت: %s" % [UiTheme.fa(int(f.g)),
			"«%s»" % f.name if f.name != "" else "بنیان‌گذار رنچ", UiTheme.fa(int(f.from)), UiTheme.fa(int(f.to)), "+" if f.money >= 0 else "-",
			UiTheme.fa(absi(int(f.money))), UiTheme.fa(int(f.herd)), UiTheme.fa(int(f.rep)), TRAITS[f.picked][0] if TRAITS.has(f.picked) else "-"], 22, Color(0.32, 0.18, 0.08))


func _line(text: String, size: int, col: Color) -> void:
	var l := UiTheme.label(text, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(1080, 0)
	_wall_list.add_child(l)


func to_save() -> Dictionary:
	return {seen = seen, start = start, family = family, head = head, heir = _heir, traits = traits}


func from_save(d: Dictionary) -> void:
	_loaded = true
	seen = d.seen.filter(func(x): return x is float or x is int).map(func(x): return int(x))
	start = d.start
	family = d.get("family", [])
	head = str(d.get("head", ""))
	_heir = str(d.get("heir", ""))
	for k in d.get("traits", {}):
		traits[k] = int(d.traits[k])
