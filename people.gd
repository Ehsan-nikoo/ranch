## Townspeople and the story. Six people from town come by the ranch, talk, ask for help and become
## friends: the sheriff, the cattle buyer, the vet, the schoolteacher, the old horse catcher and the
## blacksmith. A story in chapters runs through them (the ranch's first years, a sickness on the
## prairie, the school roof, the neighbour Blackwood after the river land, the town's thanks): each
## chapter one of them comes with a few lines and a job; once it's done, the next one comes. After the
## last chapter they still ask for something now and then. Friendship (hearts, 0 to 5) grows with each
## job done and a chat a day, and at 3 and 5 hearts each of them helps the ranch in their own way.
class_name People
extends CanvasLayer

const ORDER := ["bill", "henry", "rose", "elsie", "sam", "tom"]
# looks: skin, hair, hat (0 none, 1 cowboy, 2 bonnet, 3 fur cap, 4 bowler), hat colour, shirt, and extras
const CAST := {
	bill = {name = "کلانتر بیل", role = "کلانتر شهر", perk = ["کلانتر دزدها رو راحت‌تر می‌گیره", "کلانتر شب‌ها دور رنچت گشت می‌زنه و دزدها اصلاً نمیان"],
		look = {skin = Color(0.86, 0.66, 0.5), hair = Color(0.35, 0.3, 0.26), hat = 1, hat_col = Color(0.3, 0.22, 0.14), shirt = Color(0.55, 0.42, 0.26), stache = true, star = true},
		chat = ["این روزا دشت آرومه. خدا کنه همین‌طوری بمونه.", "پدربزرگت یه بار یه گاو فراری رو سه روز دنبال کرد. آدم سمجی بود!", "اگه دزدی دیدی، اول به من خبر بده، بعد تفنگ بردار.", "قهوه‌ی کافه‌ی شهر از هر چیزی تلخ‌تره، ولی من بازم می‌خورم.", "بلک‌وود آدم بدی نیست، فقط زیادی عجوله.", "یه کلانتر خوب بیشتر گوش می‌ده تا حرف بزنه."]},
	henry = {name = "آقای هنری", role = "خریدار گاو و صاحب مغازه", perk = ["گاوهات رو ۴ درصد گرون‌تر می‌خره", "گاوهات رو ۸ درصد گرون‌تر می‌خره"],
		look = {skin = Color(0.9, 0.72, 0.58), hair = Color(0.75, 0.75, 0.72), hat = 4, hat_col = Color(0.15, 0.14, 0.13), shirt = Color(0.25, 0.28, 0.35), stache = true, glasses = true, tie = true},
		chat = ["قیمت گوشت امسال بد نیست. البته برای من که خریدارم، زیادی خوبه!", "یه گاو چاق و سالم، بهترین تبلیغ رنچ توئه.", "مغازه‌م از نمک تا نعل اسب همه چی داره. جز صبر!", "تو این شغل یاد گرفتم آدم‌ها رو از رو دستشون بشناسم.", "اگه قطار بیاد، کار همه‌مون رونق می‌گیره."]},
	rose = {name = "دکتر رُز", role = "دامپزشک", perk = ["دامپزشک و واکسن ۱۰ درصد ارزون‌تر", "دامپزشک و واکسن ۲۰ درصد ارزون‌تر"],
		look = {skin = Color(0.82, 0.6, 0.45), hair = Color(0.45, 0.2, 0.1), hat = 0, hat_col = Color(0, 0, 0), shirt = Color(0.85, 0.85, 0.82), female = true, bag = true},
		chat = ["گاوی که آب تمیز داره، نصف مریضی‌ها رو نمی‌گیره.", "دیشب تا صبح بالای سر یه کره‌اسب بودم. الان سرحاله!", "واکسن یادت نره. پیشگیری همیشه ارزون‌تره.", "حیوون‌ها حرف نمی‌زنن، ولی همه چی رو نشون می‌دن. فقط باید نگاه کنی.", "گاوهات خوش‌اخلاق‌ان. این از صاحبشون میاد."]},
	elsie = {name = "خانم اِلسی", role = "معلم مدرسه", perk = ["هر روز صبح یه امتیاز شهرت بیشتر", "هر روز صبح دو امتیاز شهرت بیشتر"],
		look = {skin = Color(0.92, 0.76, 0.64), hair = Color(0.62, 0.42, 0.18), hat = 2, hat_col = Color(0.55, 0.3, 0.4), shirt = Color(0.42, 0.5, 0.62), female = true, brooch = true},
		chat = ["بچه‌ها امروز یه انشا نوشتن درباره‌ی گاوهای رنچ تو!", "مدرسه فقط یه کلاس داره، ولی بچه‌هاش دنیا رو می‌خوان بشناسن.", "یه روز بچه‌ها رو میارم رنچت ببینن. قول می‌دی گاوها نترسوننشون؟", "کتاب‌های مدرسه از شهر میان، با قطار. اگه قطار بیاد!", "تو شهر همه از رنچت تعریف می‌کنن."]},
	sam = {name = "سم پیر", role = "کمندانداز و اسب‌گیر", perk = ["اسب‌های وحشی بیشتر نزدیک رنچت میان", "اسب‌های وحشی دوبرابر بیشتر نزدیک رنچت میان"],
		look = {skin = Color(0.7, 0.5, 0.36), hair = Color(0.85, 0.85, 0.82), hat = 3, hat_col = Color(0.42, 0.3, 0.18), shirt = Color(0.4, 0.3, 0.2), beard = true},
		chat = ["کمند رو با مچ بنداز، نه با بازو. بازو زود خسته می‌شه.", "یه اسب وحشی رو با زور رام نمی‌کنی، با صبر رام می‌کنی.", "تو تپه‌های شمالی یه نریون سفید دیدم. هنوز کسی نتونسته بگیرتش.", "چهل سال تو این دشت اسب گرفتم. هنوزم هر بار دلم می‌لرزه.", "اسب خوب صاحبش رو انتخاب می‌کنه، نه برعکس."]},
	tom = {name = "تام آهنگر", role = "آهنگر شهر", perk = ["تعمیر آسیاب بادی نصف قیمت", "تعمیر آسیاب بادی مجانی"],
		look = {skin = Color(0.78, 0.56, 0.42), hair = Color(0.12, 0.1, 0.09), hat = 0, hat_col = Color(0, 0, 0), shirt = Color(0.6, 0.55, 0.48), beard = true, apron = true},
		chat = ["آهن رو باید وقتی داغه کوبید. کار رنچ هم همینه.", "نعل خوب، اسب رو سالم نگه می‌داره. نعل بد، صاحبش رو بیچاره می‌کنه.", "آسیاب‌هات رو هر از گاهی روغن‌کاری کن. خودشون ازت تشکر می‌کنن.", "دیروز یه پتک شکستم. اولین بار تو بیست سال!", "یه روز یه زنگ بزرگ برای مدرسه می‌سازم."]},
}
# the story: who comes, what they say, the job, and the prize
const STORY := [
	{who = "bill", lines = ["خوش اومدی! سال‌ها بود کسی این زمین‌ها رو آباد نکرده بود.", "پدربزرگت مرد خوبی بود. شهر خوشحاله که یکی از خونواده‌ش برگشته.", "ولی رنچ بی‌طویله و بی‌آب نمی‌چرخه."],
		job = "دو تا ساختمون بساز", kind = "buildings", n = 2, money = 400, rep = 5.0},
	{who = "henry", lines = ["سلام! من هنری‌ام، گاو رنچ‌ها رو می‌خرم و مغازه‌ی شهر هم مال منه.", "رنچ بلک‌وود همیشه گرون می‌فروشه. شهر یه فروشنده‌ی تازه لازم داره."],
		job = "اولین بار گاو بفروش", kind = "sales", n = 1, money = 500, rep = 5.0},
	{who = "rose", lines = ["من رُزم، دامپزشک شهر. خبر خوبی ندارم.", "یه مریضی داره تو دشت می‌چرخه. گاوهای بی‌واکسن زودتر می‌گیرنش."],
		job = "پنج تا گاو واکسن‌زده داشته باش", kind = "vacc", n = 5, money = 400, rep = 5.0},
	{who = "elsie", lines = ["سلام! من اِلسی‌ام، معلم مدرسه‌ی شهر.", "سقف مدرسه چکه می‌کنه و بچه‌ها زیر بارون درس می‌خونن.", "شهر داره پول جمع می‌کنه. تو هم کمک می‌کنی؟"],
		job = "۳۰۰ دلار برای سقف مدرسه بده", kind = "money", n = 300, money = 0, rep = 15.0},
	{who = "sam", lines = ["هِی! من سم‌ام. چهل ساله تو این تپه‌ها اسب وحشی می‌گیرم.", "یه رنچ بی‌اسب مثل خونه‌ی بی‌سقفه. یه اسب داشته باش، بقیه‌ش رو بهت یاد می‌دم."],
		job = "یه اسب داشته باش", kind = "horses", n = 1, money = 600, rep = 5.0},
	{who = "tom", lines = ["من تام‌ام، آهنگر. زمستون نزدیکه و زمستون اینجا شوخی نداره.", "پارسال دو تا رنچ از بی‌یونجگی گاوهاشون رو از دست دادن."],
		job = "انبار رو برسون به ۶۰ بسته یونجه", kind = "hay", n = 60, money = 500, rep = 5.0},
	{who = "bill", lines = ["چندتا دزد گاو این طرفا دیده شدن.", "یه رنچ تنها طعمه‌ی خوبیه. چندتا کارگر بیار که شب‌ها تنها نباشی."],
		job = "دو تا کارگر داشته باش", kind = "hands", n = 2, money = 600, rep = 8.0},
	{who = "henry", lines = ["شهر داره برای جشن آماده می‌شه و گوشت خوب می‌خواد.", "قول دادم گوشت خوب برسونم. کمکم کن روسفید بشم!"],
		job = "دو تا قرارداد رو به موقع تحویل بده", kind = "deals", n = 2, money = 900, rep = 10.0},
	{who = "elsie", lines = ["سقف مدرسه درست شد! بچه‌ها یه نقاشی از رنچت کشیدن.", "حالا همه‌شون می‌خوان یه گوساله‌ی تازه به دنیا اومده ببینن."],
		job = "سه تا گوساله یا کره‌اسب به دنیا بیاد", kind = "births", n = 3, money = 700, rep = 10.0},
	{who = "sam", lines = ["یه گله اسب وحشی تو تپه‌ها می‌چرخه. وقتشه خودت امتحان کنی.", "بتاز، ولی نذار نفس اسبت بره. حلقه که باز شد، بنداز!"],
		job = "یه اسب وحشی با کمند بگیر", kind = "wild", n = 1, money = 800, rep = 10.0},
	{who = "rose", lines = ["مریضی تموم شد و گله‌ی تو سالم موند. کارت حرف نداشت.", "حالا وقتشه گله‌ت رو بزرگ کنی. شهر به گوشت بیشتری احتیاج داره."],
		job = "گله‌ت رو برسون به ۲۵ تا گاو", kind = "herd", n = 25, money = 1200, rep = 10.0},
	{who = "tom", lines = ["تو شهر می‌گن رنچت خوشگل شده. می‌خوام با چشم خودم ببینم.", "یه کم دیگه تزئینش کن، شهر می‌خواد یه روز بیاد رنچت رو تماشا کنه."],
		job = "زیبایی رنچ رو برسون به ۳۰", kind = "beauty", n = 30, money = 800, rep = 10.0},
	{who = "bill", lines = ["خبر بدی دارم: بلک‌وود می‌گه زمین‌های کنار رودخونه مال اونه.", "قانون می‌گه هرکی زودتر بخره، مال اونه. عجله کن!"],
		job = "یه تیکه زمین تازه بخر", kind = "land", n = 1, money = 1500, rep = 15.0},
	{who = "henry", lines = ["بلک‌وود از زمین کوتاه اومد، ولی گفته تو جشنواره‌ی شهر شکستت می‌ده.", "نشونش بده رنچ کی بهتره!"],
		job = "تو جشنواره‌ی شهر یه جام یا روبان ببر", kind = "fair", n = 1, money = 1500, rep = 15.0},
	{who = "elsie", lines = ["همه‌ی شهر درباره‌ی تو حرف می‌زنن. بچه‌ها می‌خوان مثل تو رنچ‌دار بشن.", "شهر می‌خواد یه جشن به افتخار رنچت بگیره. فقط یه کم دیگه معروف‌تر شو!"],
		job = "رنچت «رنچ سرشناس» بشه", kind = "level", n = 3, money = 3000, rep = 20.0},
]
const THE_END := "شهر به افتخار رنچت یه جشن بزرگ گرفت! همه اومدن، تام یه زنگ برای مدرسه ساخت و اسمت رو روش نوشت."
# after the story: what each one asks for now and then [job, kind, n, prize]
const ASKS := {
	bill = [["دو تا قرارداد تحویل بده، شهر گوشت لازم داره", "deals", 2, 700], ["۴۰۰ دلار برای تعمیر زندون شهر بده", "money", 400, 0], ["یه کارگر دیگه بیار", "hands_more", 1, 500]],
	henry = [["سه بار گاو بفروش", "sales", 3, 800], ["دو تا قرارداد تحویل بده", "deals", 2, 800], ["۳۰ بسته یونجه برای اسب‌های گاری مغازه بده", "give_hay", 30, 600]],
	rose = [["دو تا گوساله یا کره‌اسب به دنیا بیاد", "births", 2, 600], ["۳۰۰ دلار برای داروهای تازه بده", "money", 300, 0], ["ده تا گاو واکسن‌زده داشته باش", "vacc", 10, 500]],
	elsie = [["۲۵۰ دلار برای کتاب‌های مدرسه بده", "money", 250, 0], ["یه چیز قشنگ تو رنچ بذار، بچه‌ها میان ببینن", "decor", 1, 400], ["یه گوساله به دنیا بیاد", "births", 1, 400]],
	sam = [["یه اسب وحشی بگیر", "wild", 1, 900], ["یه کره‌اسب به دنیا بیاد", "foals", 1, 700], ["۲۰ بسته یونجه برای اسب‌هام بده", "give_hay", 20, 500]],
	tom = [["یه چیز بساز یا ارتقا بده", "build", 1, 600], ["۳۰۰ دلار برای آهن تازه بده", "money", 300, 0], ["دو تا چیز قشنگ تو رنچ بذار", "decor", 2, 500]],
}
const ASK_GAP := 2         # days between one of their jobs and the next, after the story
const CHAT := 0.25         # hearts for a chat (once a day each)
const JOB := 1.0           # hearts for a job done
const GIFT_REP := 6.0      # fame for a side job

## Friendship with each, 0 to 5 hearts; static so the perks can be read from anywhere.
static var hearts := {}

var day: DayCycle
var builder: Builder
var herd: Herd
var market: Market
var horses: Horses
var workers: Workers
var progress: Progress
var land: Land
var fair: Fair
var wild: Wild
var world: Node3D
var notify: Callable
var can_pop := func(): return true

var chapter := 0           # the story's chapter being worked on; STORY.size() = the story's told
var told := -1             # last chapter whose visit has been shown
var story_base := 0        # the counter when this chapter's job began
var asks := {}             # id -> {job, kind, n, money, base}: their own job, after the story
var next_ask := {}         # id -> day their next job comes
var chatted := {}          # id -> day of the last chat
var count := {sales = 0, deals = 0, births = 0, foals = 0, wild = 0, fair = 0, build = 0, decor = 0}
var _button: Button
var _mark: Label
var _panel: PanelContainer
var _dim: ColorRect
var _story := UiTheme.label("", 24, Color(0.32, 0.18, 0.08))
var _row := HBoxContainer.new()
var _scroll := ScrollContainer.new()
var _visit: PanelContainer
var _visit_dim: ColorRect
var _vface := Face.new()
var _vname := UiTheme.label("", 32)
var _vtext := UiTheme.label("", 27)
var _vnext: Button
var _vlines: Array = []
var _vat := 0
var _t := 0.0
var _rng := RandomNumberGenerator.new()


## A drawn face for each of them: head and shoulders, hair, hat and a thing or two that's theirs.
class Face extends Control:
	var look := {}

	func _draw() -> void:
		if look.is_empty():
			return
		var c := size * 0.5
		var s := minf(size.x, size.y) / 200.0
		draw_circle(c, 96.0 * s, Color(0.95, 0.88, 0.72, 0.6))
		var skin: Color = look.skin
		var hair: Color = look.hair
		var head := c + Vector2(0, -12) * s
		var fem: bool = look.get("female", false)
		if fem:  # long hair behind the head
			draw_rect(Rect2(head + Vector2(-46, -20) * s, Vector2(92, 82) * s), hair)
		# shoulders and shirt
		var sh := PackedVector2Array([c + Vector2(-80, 96) * s, c + Vector2(-70, 50) * s, c + Vector2(-30, 34) * s, c + Vector2(30, 34) * s, c + Vector2(70, 50) * s, c + Vector2(80, 96) * s])
		draw_colored_polygon(sh, look.shirt)
		if look.get("apron", false):
			draw_colored_polygon(PackedVector2Array([c + Vector2(-34, 96) * s, c + Vector2(-30, 40) * s, c + Vector2(30, 40) * s, c + Vector2(34, 96) * s]), Color(0.3, 0.22, 0.16))
		draw_rect(Rect2(head + Vector2(-13, 30) * s, Vector2(26, 26) * s), skin.darkened(0.08))
		if look.get("tie", false):
			draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 36) * s, c + Vector2(12, 36) * s, c + Vector2(0, 46) * s]), Color(0.6, 0.12, 0.1))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 56) * s, c + Vector2(12, 56) * s, c + Vector2(0, 46) * s]), Color(0.6, 0.12, 0.1))
		if look.get("star", false):  # the sheriff's badge
			var pts := PackedVector2Array()
			for i in 10:
				var r := 14.0 if i % 2 == 0 else 6.0
				var a := -PI * 0.5 + i * PI / 5.0
				pts.append(c + (Vector2(-40, 66) + Vector2(cos(a), sin(a)) * r) * s)
			draw_colored_polygon(pts, Color(0.92, 0.75, 0.25))
		if look.get("brooch", false):
			draw_circle(c + Vector2(0, 46) * s, 7.0 * s, Color(0.85, 0.7, 0.3))
		if look.get("bag", false):  # a stethoscope round the neck
			draw_arc(c + Vector2(0, 38) * s, 26.0 * s, 0.2, PI - 0.2, 16, Color(0.2, 0.2, 0.22), 4.0 * s)
			draw_circle(c + Vector2(22, 70) * s, 7.0 * s, Color(0.6, 0.62, 0.65))
		# head
		draw_circle(head, 44.0 * s, skin)
		draw_circle(head + Vector2(-44, 4) * s, 8.0 * s, skin)
		draw_circle(head + Vector2(44, 4) * s, 8.0 * s, skin)
		if not fem and look.hat == 0:  # short hair on top
			draw_arc(head, 40.0 * s, PI + 0.25, TAU - 0.25, 20, hair, 14.0 * s)
		if fem:  # fringe
			draw_arc(head + Vector2(0, -4) * s, 40.0 * s, PI + 0.3, TAU - 0.3, 20, hair, 16.0 * s)
		# eyes, brows, nose, mouth
		for x in [-16.0, 16.0]:
			draw_circle(head + Vector2(x, -2) * s, 4.5 * s, Color(0.12, 0.08, 0.06))
			draw_line(head + Vector2(x - 9, -13) * s, head + Vector2(x + 8, -14) * s, hair.darkened(0.2), 3.5 * s)
		draw_line(head + Vector2(0, 2) * s, head + Vector2(-3, 14) * s, skin.darkened(0.3), 3.0 * s)
		draw_arc(head + Vector2(0, 14) * s, 12.0 * s, 0.4, PI - 0.4, 10, Color(0.5, 0.2, 0.15), 3.0 * s)
		if look.get("glasses", false):
			for x in [-16.0, 16.0]:
				draw_arc(head + Vector2(x, -2) * s, 10.0 * s, 0, TAU, 16, Color(0.2, 0.18, 0.15), 2.5 * s)
			draw_line(head + Vector2(-6, -2) * s, head + Vector2(6, -2) * s, Color(0.2, 0.18, 0.15), 2.5 * s)
		if look.get("beard", false):
			draw_colored_polygon(PackedVector2Array([head + Vector2(-40, 6) * s, head + Vector2(-30, 34) * s, head + Vector2(0, 48) * s, head + Vector2(30, 34) * s, head + Vector2(40, 6) * s, head + Vector2(26, 26) * s, head + Vector2(0, 30) * s, head + Vector2(-26, 26) * s]), hair)
		if look.get("stache", false) or look.get("beard", false):
			draw_colored_polygon(PackedVector2Array([head + Vector2(-22, 14) * s, head + Vector2(0, 8) * s, head + Vector2(22, 14) * s, head + Vector2(16, 18) * s, head + Vector2(0, 14) * s, head + Vector2(-16, 18) * s]), hair)
		# hat
		var hc: Color = look.hat_col
		match int(look.hat):
			1:  # cowboy hat
				draw_colored_polygon(_oval(head + Vector2(0, -30) * s, 76.0 * s, 13.0 * s), hc)
				draw_colored_polygon(PackedVector2Array([head + Vector2(-34, -32) * s, head + Vector2(-28, -72) * s, head + Vector2(0, -64) * s, head + Vector2(28, -72) * s, head + Vector2(34, -32) * s]), hc)
				draw_rect(Rect2(head + Vector2(-34, -42) * s, Vector2(68, 7) * s), hc.darkened(0.4))
			2:  # bonnet
				draw_arc(head + Vector2(0, -6) * s, 48.0 * s, PI + 0.1, TAU - 0.1, 24, hc, 20.0 * s)
				draw_line(head + Vector2(-40, 20) * s, head + Vector2(-20, 46) * s, hc, 4.0 * s)
			3:  # fur cap
				draw_colored_polygon(_oval(head + Vector2(0, -34) * s, 46.0 * s, 26.0 * s), hc)
				draw_rect(Rect2(head + Vector2(-46, -34) * s, Vector2(92, 12) * s), hc.lightened(0.25))
			4:  # bowler
				draw_colored_polygon(_oval(head + Vector2(0, -32) * s, 56.0 * s, 8.0 * s), hc)
				draw_colored_polygon(_oval(head + Vector2(0, -46) * s, 34.0 * s, 24.0 * s), hc)

	func _oval(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
		var p := PackedVector2Array()
		for i in 20:
			var a := TAU * i / 20.0
			p.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		return p


func _init() -> void:
	hearts = {}  # a fresh ranch (the save, if any, fills them in)


## How much a perk of `id` is on: 0 under 3 hearts, 1 from 3, 2 at 5.
static func perk(id: String) -> int:
	var h: float = hearts.get(id, 0.0)
	return 2 if h >= 5.0 else (1 if h >= 3.0 else 0)


static func hearts_text(h: float) -> String:
	var n := clampi(int(h), 0, 5)
	return "♥".repeat(n) + "♡".repeat(5 - n)


func _ready() -> void:
	_rng.randomize()
	for id in ORDER:
		if not hearts.has(id):
			hearts[id] = 0.0
	_button = builder.bar_button("آدم‌ها", toggle, "people")
	_mark = UiTheme.label("!", 30, Color.WHITE)
	var dot := StyleBoxFlat.new()
	dot.bg_color = Color(0.8, 0.12, 0.08)
	dot.set_corner_radius_all(18)
	dot.content_margin_left = 12
	dot.content_margin_right = 12
	_mark.add_theme_stylebox_override("normal", dot)
	_mark.position = Vector2(4, -4)
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.visible = false
	_button.add_child(_mark)
	_dim = UiTheme.dim(toggle)
	_panel = UiTheme.board()
	add_child(_dim)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_panel.add_child(col)
	col.add_child(UiTheme.header("آدم‌های شهر", builder._button(Button.new(), "بستن", toggle, "cancel")))
	_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story.custom_minimum_size = Vector2(1100, 0)
	col.add_child(_story)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(1240, 0)
	_row.add_theme_constant_override("separation", 14)
	_scroll.add_child(_row)
	col.add_child(_scroll)
	_build_visit()
	market.sold.connect(func(_cash: int, contract: bool):
		count.sales += 1
		if contract:
			count.deals += 1)
	herd.born.connect(func(): count.births += 1)
	horses.foaled.connect(func(_h):
		count.births += 1
		count.foals += 1)
	wild.caught_one.connect(func(_h): count.wild += 1)
	fair.won.connect(func(_k: String, place: int): if place <= 3: count.fair += 1)
	builder.money_moved.connect(func(delta: int, why: String):
		if delta < 0 and why in ["build", "decor"]:
			count[why] += 1)


func is_open() -> bool:
	return _panel.visible or _visit.visible


func toggle() -> void:
	_panel.visible = not _panel.visible
	_dim.visible = _panel.visible
	if _panel.visible:
		_rebuild()
		await get_tree().process_frame
		_scroll.scroll_horizontal = int(_scroll.get_h_scroll_bar().max_value)


# ---------- jobs ----------

## Where a job of `kind` stands now; counters count from `base`.
func value(kind: String, base := 0) -> int:
	match kind:
		"buildings":
			return world.get_children().filter(func(n): return n is Building and not n is Decor and n.works()).size()
		"vacc":
			return herd.alive().filter(func(c): return c.vacc >= day.day).size()
		"horses":
			return horses.list.size()
		"hay":
			return int(herd.hay)
		"hands":
			return workers.hired.size()
		"hands_more":
			return workers.hired.size() - base
		"herd":
			return herd.alive().size()
		"beauty":
			return int(Decor.beauty(world))
		"land":
			return land.owned.count(1) - 4
		"level":
			return progress.level() + 1
		"money", "give_hay":
			return 0  # given with the button
	return int(count.get(kind, 0)) - base


func _counter(kind: String) -> int:
	if kind == "hands_more":
		return workers.hired.size()
	return int(count.get(kind, 0))


## The job being worked on for `id` ({who, job, kind, n, money, rep, base}), or {}.
func job_of(id: String) -> Dictionary:
	if chapter < STORY.size():
		var st: Dictionary = STORY[chapter]
		if st.who == id and told >= chapter:
			return {who = id, job = st.job, kind = st.kind, n = st.n, money = st.money, rep = st.rep, base = story_base, story = true}
		return {}
	if asks.has(id):
		var a: Dictionary = asks[id]
		return {who = id, job = a.job, kind = a.kind, n = a.n, money = a.money, rep = GIFT_REP, base = a.base, story = false}
	return {}


func _done(j: Dictionary) -> bool:
	return not j.kind in ["money", "give_hay"] and value(j.kind, j.base) >= j.n


func can_give(j: Dictionary) -> bool:
	if j.kind == "money":
		return builder.money >= j.n
	if j.kind == "give_hay":
		return herd.hay >= j.n
	return false


## Pays what a giving job asks for, and that's the job done.
func give(id: String) -> void:
	var j := job_of(id)
	if j.is_empty() or not can_give(j):
		return
	if j.kind == "money":
		builder.add_money(-j.n, "prize")
	else:
		herd.hay -= j.n
	_complete(j)


func _complete(j: Dictionary) -> void:
	var p: Dictionary = CAST[j.who]
	var before := perk(j.who)
	hearts[j.who] = minf(5.0, hearts[j.who] + JOB)
	if j.money > 0:
		builder.add_money(j.money, "prize")
	progress.add(j.rep)
	var paid := "  %s+ دلار" % UiTheme.fa(j.money) if j.money > 0 else ""
	notify.call("%s: «دستت درد نکنه!» کار «%s» تموم شد.%s" % [p.name, j.job, paid])
	if perk(j.who) > before:
		notify.call("%s حالا دوست صمیمیته: %s" % [p.name, p.perk[perk(j.who) - 1]])
	if j.story:
		chapter += 1
		if chapter < STORY.size():
			story_base = _counter(STORY[chapter].kind)
		else:
			notify.call(THE_END)
			for id in ORDER:
				next_ask[id] = day.day + 1 + ORDER.find(id) % 3
	else:
		asks.erase(j.who)
		next_ask[j.who] = day.day + ASK_GAP
	if _panel.visible:
		_rebuild()


func chat(id: String) -> void:
	if int(chatted.get(id, -1)) == day.day:
		return
	chatted[id] = day.day
	var p: Dictionary = CAST[id]
	var before := perk(id)
	hearts[id] = minf(5.0, hearts[id] + CHAT)
	notify.call("%s: «%s»" % [p.name, p.chat[_rng.randi() % p.chat.size()]])
	if perk(id) > before:
		notify.call("%s حالا دوست صمیمیته: %s" % [p.name, p.perk[perk(id) - 1]])
		progress._apply()
	_rebuild()


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	for id in ORDER:
		var j := job_of(id)
		if not j.is_empty() and _done(j):
			_complete(j)
	if chapter >= STORY.size():  # after the story: a new job now and then
		for id in ORDER:
			if not asks.has(id) and day.day >= int(next_ask.get(id, 0)):
				var a: Array = ASKS[id][_rng.randi() % ASKS[id].size()]
				asks[id] = {job = a[0], kind = a[1], n = a[2], money = a[3], base = _counter(a[1])}
				notify.call("%s یه کار تازه ازت خواسته (تو «آدم‌ها»)" % CAST[id].name)
	elif told < chapter and not _visit.visible and can_pop.call():
		_show_visit()
	_mark.visible = (chapter < STORY.size() and told < chapter) or ORDER.any(func(id):
		var j := job_of(id)
		return not j.is_empty() and can_give(j)) or ORDER.any(func(id): return int(chatted.get(id, -1)) != day.day and hearts[id] < 5.0)


# ---------- the board ----------

func _rebuild() -> void:
	for c in _row.get_children():
		c.queue_free()
	if chapter < STORY.size():
		_story.text = "داستان رنچ: فصل %s از %s. هر کسی که کار داستان دستشه، یه کار ازت خواسته. هر روز با هر کدوم می‌تونی یه بار حرف بزنی و دوست‌تر بشی." % [UiTheme.fa(chapter + 1), UiTheme.fa(STORY.size())]
	else:
		_story.text = "داستان رنچ تموم شد؛ شهر هنوز دوستت داره. هر از گاهی هر کدوم یه کار ازت می‌خوان. با ۳ و ۵ قلب، هر کدوم یه جوری کمکت می‌کنن."
	var card_box := StyleBoxFlat.new()
	card_box.bg_color = Color(0.3, 0.15, 0.04, 0.16)
	card_box.border_color = Color(0.3, 0.16, 0.05, 0.55)
	card_box.set_border_width_all(2)
	card_box.set_corner_radius_all(10)
	card_box.set_content_margin_all(10)
	var ids := ORDER.duplicate()
	ids.reverse()  # first one on the right
	for id in ids:
		var p: Dictionary = CAST[id]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", card_box)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		card.add_child(v)
		var f := Face.new()
		f.look = p.look
		f.custom_minimum_size = Vector2(250, 128)
		v.add_child(f)
		v.add_child(UiTheme.label(p.name, 28))
		v.add_child(UiTheme.label(p.role, 20, Color(0.32, 0.18, 0.08)))
		v.add_child(UiTheme.label(hearts_text(hearts[id]), 28, Color(0.7, 0.12, 0.1)))
		var pk := perk(id)
		var perk_l := UiTheme.label(("کمکش: " + p.perk[pk - 1]) if pk > 0 else "با ۳ قلب: " + p.perk[0], 19, Color(0.15, 0.4, 0.1) if pk > 0 else Color(0.32, 0.18, 0.08))
		perk_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		perk_l.custom_minimum_size = Vector2(250, 48)
		v.add_child(perk_l)
		var j := job_of(id)
		var job := UiTheme.label("", 21)
		job.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		job.custom_minimum_size = Vector2(250, 66)
		if j.is_empty():
			job.text = "فعلاً کاری نداره" if chapter >= STORY.size() or told >= chapter else "داره میاد رنچت..."
		elif j.kind in ["money", "give_hay"]:
			job.text = "«%s»" % j.job
		else:
			job.text = "«%s»  (%s از %s)" % [j.job, UiTheme.fa(clampi(value(j.kind, j.base), 0, j.n)), UiTheme.fa(j.n)]
		v.add_child(job)
		var talk := builder._button(Button.new(), "حرف زدیم" if int(chatted.get(id, -1)) == day.day else "حرف بزن", chat.bind(id), "")
		talk.disabled = int(chatted.get(id, -1)) == day.day
		talk.custom_minimum_size = Vector2(250, 64)
		talk.add_theme_font_size_override("font_size", 22)
		v.add_child(talk)
		if not j.is_empty() and j.kind in ["money", "give_hay"]:
			var g := builder._button(Button.new(), "بده  %s %s" % [UiTheme.fa(j.n), "دلار" if j.kind == "money" else "بسته یونجه"], give.bind(id), "gift")
			g.disabled = not can_give(j)
			g.custom_minimum_size = Vector2(250, 64)
			g.add_theme_font_size_override("font_size", 22)
			v.add_child(g)
		_row.add_child(card)


# ---------- a visit: the next chapter of the story ----------

func _build_visit() -> void:
	_visit_dim = UiTheme.dim(func(): pass)
	_visit = UiTheme.board()
	var over := CanvasLayer.new()
	over.layer = 4
	add_child(over)
	over.add_child(_visit_dim)
	over.add_child(_visit)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_visit.add_child(row)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vtext.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vtext.custom_minimum_size = Vector2(760, 150)
	_vtext.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	col.add_child(_vname)
	col.add_child(_vtext)
	_vnext = builder._button(Button.new(), "بعدی", _visit_next, "place")
	var c := CenterContainer.new()
	c.add_child(_vnext)
	col.add_child(c)
	row.add_child(col)
	_vface.custom_minimum_size = Vector2(260, 260)
	row.add_child(_vface)  # the face on the right: Persian reads right to left


func _show_visit() -> void:
	var st: Dictionary = STORY[chapter]
	var p: Dictionary = CAST[st.who]
	_vface.look = p.look
	_vface.queue_redraw()
	_vname.text = "%s، %s" % [p.name, p.role]
	_vlines = st.lines.duplicate()
	_vlines.append("کار: %s.%s" % [st.job, "  جایزه: %s دلار" % UiTheme.fa(st.money) if st.money > 0 else ""])
	_vat = 0
	_vtext.text = _vlines[0]
	_vnext.text = "بعدی"
	_visit.visible = true
	_visit_dim.visible = true
	told = chapter
	story_base = _counter(st.kind)


func _visit_next() -> void:
	_vat += 1
	if _vat >= _vlines.size():
		_visit.visible = false
		_visit_dim.visible = false
		return
	_vtext.text = _vlines[_vat]
	if _vat == _vlines.size() - 1:
		_vnext.text = "باشه"


func to_save() -> Dictionary:
	return {hearts = hearts, chapter = chapter, told = told, base = story_base, asks = asks, next = next_ask, chatted = chatted, count = count}


func from_save(d: Dictionary) -> void:
	for id in ORDER:
		hearts[id] = float(d.get("hearts", {}).get(id, 0.0))
	chapter = int(d.get("chapter", 0))
	told = int(d.get("told", -1))
	story_base = int(d.get("base", 0))
	asks = d.get("asks", {})
	for id in asks:
		asks[id].n = int(asks[id].n)
		asks[id].money = int(asks[id].money)
		asks[id].base = int(asks[id].base)
	next_ask = d.get("next", {})
	chatted = d.get("chatted", {})
	for k in d.get("count", {}):
		count[k] = int(d.count[k])
