## Ranch feel-test scene: barn on a prairie with a day-night cycle, wind and touch camera.
## Test args: `-- --shot=wide|close --hour=17.5`
extends Node3D

const TEX := "res://textures/"
const MASK_SPAN := 240.0
const GRASS_CHUNK := 20.0
const GRASS_COUNT := 50000  # ~1.3 per m2 over the bigger ranch; only nearby chunks draw

var day := DayCycle.new()
var rig := CameraRig.new()
var grass_chunks: Array[MultiMesh] = []
var grass_nodes: Array[Node3D] = []
var grass_mat := ShaderMaterial.new()
var ground_mat := ShaderMaterial.new()
var herd_ui := HerdUI.new()
var market := Market.new()
var market_ui := MarketUI.new()
var breed_ui := BreedUI.new()
var workers := Workers.new()
var workers_ui := WorkersUI.new()
var events := Events.new()
var auction := Auction.new()
var drive := Drive.new()
var rodeo := RodeoGame.new()
var fair := Fair.new()
var festivals := Festivals.new()
var surprises := Surprises.new()
var collection := Collection.new()
var building_ui := BuildingUI.new()
var horses := Horses.new()
var horse_ui := HorseUI.new()
var weather := Weather.new()
var cow_ui := CowUI.new()
var rival := Rival.new()
var ledger := Ledger.new()
var bank := Bank.new()
var warnings := Warnings.new()
var daily := Daily.new()
var away := Away.new()
var progress := Progress.new()
var progress_ui := ProgressUI.new()
var goals := Goals.new()
var legacy := Legacy.new()
var tutorial: Tutorial
var delivery := Delivery.new()
var land := Land.new()
var fence_mat := _fence_mat()


static func _fence_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX + "trim_white_diff.jpg")
	m.albedo_color = Color(0.55, 0.45, 0.35)
	m.uv1_triplanar = true
	m.roughness = 0.95
	return m
# per season (spring, summer, autumn, winter): grass blade tint, ground grass tint, ground lush tint, snow
const LOOK := [
	[Color(0.66, 0.86, 0.5), Color(0.52, 0.64, 0.4), Color(0.42, 0.6, 0.32), 0.0],
	[Color(1.0, 1.0, 1.0), Color(0.7, 0.68, 0.5), Color(0.52, 0.62, 0.36), 0.0],
	[Color(1.0, 0.8, 0.58), Color(0.68, 0.57, 0.42), Color(0.6, 0.5, 0.36), 0.0],
	[Color(0.78, 0.76, 0.72), Color(0.58, 0.54, 0.46), Color(0.52, 0.5, 0.42), 0.7],
]
const SEASON_NEWS := [
	"بهار شد: علف دوباره سبز می‌شه و تند رشد می‌کنه",
	"تابستون شد: وقت چیدن یونجه و پر کردن انباره",
	"پاییز شد: علف دیگه کند درمیاد؛ برای زمستون یونجه جمع کن",
	"زمستون شد: علف درنمیاد و گاوها از انبار یونجه می‌خورن",
]
var crickets: AudioStreamPlayer
var prairie: AudioStreamPlayer
var sfx := Sfx.new()
var mask_img: Image
var builder := Builder.new()
var herd := Herd.new()
# starting ranch: building, position, yaw in degrees
# A new ranch starts as bare land: the player builds and places everything. `starter` is the old
# ready-made yard, for tests (--starter=1, and the bot).
var layout := []
var starter := [
	[Barn, Vector3(0, 0, 0), 0.0],
	[RanchHouse, Vector3(-13, 0, 26), 90.0],
	[Windmill, Vector3(17, 0, -5), -30.0],
	[Silo, Vector3(-2, 0, -11), 0.0],
	[Corral, Vector3(-16.5, 0, 3), 90.0],
]


func _ready() -> void:
	UiTheme.apply()
	var saved := SaveGame.read()
	SaveGame.hold = false  # a ranch code just loaded (if any) is the ranch now
	day.hour = float(_arg("hour", "17.2"))
	day.day = int(_arg("day", "0"))
	if _arg("starter", "") != "" or _arg("bot", "") != "" or _arg("extras", "") != "":
		layout = starter.duplicate()
	if not saved.is_empty():
		day.day = saved.day
		day.hour = saved.hour
		builder.money = saved.money
		if saved.has("land"):
			land.from_save(saved.land)
		layout = saved.buildings.map(func(b): return [load(b[0]), Vector3(b[1], 0, b[2]), b[3], int(b[4]) if b.size() > 4 else 1, b.slice(5)])
		if not saved.has("yard"):  # a ranch from before the corral was a building: it keeps its corral
			layout.append([Corral, Vector3(-16.5, 0, 3), 90.0, 1])
	add_child(day)
	mask_img = (load(TEX + "ground_mask.png") as Texture2D).get_image()
	if mask_img.is_compressed():
		mask_img.decompress()
	herd.init_grass(mask_img)
	add_child(land)
	_ground()
	if _arg("extras", "") != "":  # test: the newer buildings already standing
		layout.append_array([[Pond, Vector3(38, 0, -16), 0.0], [HayShed, Vector3(-30, 0, -32), 0.0], [Kennel, Vector3(-40, 0, -10), 0.0],
			[Watchtower, Vector3(40, 0, 8), 0.0], [Feedlot, Vector3(34, 0, 36), 0.0], [VetClinic, Vector3(-38, 0, 10), 90.0],
			[Saloon, Vector3(-30, 0, 34), 0.0], [Station, Vector3(14, 0, -40), 180.0], [HorseStable, Vector3(18, 0, 18), 0.0]])
	for b in layout:
		var node: Building = b[0].new()
		node.position = b[1]
		node.rotation_degrees.y = b[2]
		node.level = b[3] if b.size() > 3 else 1
		add_child(node)
		builder.occupied.append(node.world_footprint())
		var work: Array = b[4] if b.size() > 4 else []
		if work.size() >= 3 and float(work[0]) > 0.0:  # a site that was still going up
			node.work_left = float(work[0])
			node.work_total = float(work[1])
			node.upgrading = bool(work[2])
			builder.resume_work(node)
	_grass()
	_props()
	MeshMerge.boxes(self)
	herd.day = day
	herd.world = self
	add_child(delivery)
	_ranch_fence(delivery.gate.position.x)
	MeshMerge.boxes(self)
	herd.land = land
	builder.land = land
	herd.extra_blocked = []
	herd.extra_blocked.append_array(delivery.blocked_rects())
	builder.occupied.append_array(delivery.blocked_rects())
	add_child(herd)
	delivery.herd = herd
	delivery.day = day
	herd._rescan()
	if saved.is_empty():
		for i in int(_arg("cows", "6" if not layout.is_empty() else "0")):  # a new ranch has no cattle: the player buys the first calves
			herd.add_cow(herd.free_spot(Vector3(22, 0, 18), 9.0), randf_range(200.0, 300.0) if _arg("kg", "") == "" else float(_arg("kg", "")))  # --kg: test herd at this weight
		for i in int(_arg("calves", "0")):  # test: fresh calves at purchase weight
			herd.add_cow(herd.free_spot(Vector3(22, 0, 18), 9.0), HerdUI.CALF_KG)
		for i in int(_arg("breeders", "0")):  # test: breeding cows and bulls
			herd.add_cow(herd.free_spot(Vector3(22, 0, 18), 9.0), 480.0, Herd.BREEDER)
		for i in int(_arg("bulls", "0")):
			herd.add_cow(herd.free_spot(Vector3(22, 0, 18), 9.0), HerdUI.BULL_KG, Herd.BULL)
		for i in int(_arg("white", "0")):  # test: cows of the rare white breed
			herd.add_cow(herd.free_spot(Vector3(22, 0, 18), 9.0), 480.0, Herd.BREEDER, 1, 3)
		for i in int(_arg("newborns", "0")):
			herd.add_cow(herd.free_spot(Vector3(22, 0, 18), 9.0), Herd.BIRTH_KG)
	else:
		herd.from_save(saved.herd)
	_audio()
	_shot(_arg("shot", "wide"))
	add_child(rig)
	var hud := Hud.new()
	hud.day = day
	hud.herd = herd
	hud.grass = grass_chunks
	hud.grass_nodes = grass_nodes
	hud.sfx = sfx
	add_child(hud)
	if _arg("settings", "") != "":  # test: the settings board open (--settings=export: after "copy the ranch code")
		if not hud._panel.visible:
			hud.toggle()
		if _arg("settings", "") == "look" and UiTheme.look != "poster":  # --settings=look: pick the second look a second in
			get_tree().create_timer(1.0).timeout.connect(func(): hud._look_btns[1].pressed.emit())
		if _arg("settings", "") == "export":
			hud.call_deferred("_export")
		if _arg("settings", "") == "import":  # --settings=import: this ranch's own code pasted back, waiting for the yes
			hud.snapshot = _state
			(func():
				hud._incoming = SaveGame.from_code(SaveGame.to_code(_state()))
				hud._say("رنچ تو این کد: %s دلار، سال %s. رنچ الانت پاک می‌شه و این جاش میاد. مطمئنی؟" % [UiTheme.fa(int(hud._incoming.money)), UiTheme.fa(1)], true)).call_deferred()
	builder.rig = rig
	builder.world = self
	builder.day = day
	builder.on_placed = func(r: Rect2):
		away.ask_once()  # a good moment to ask if the phone may say when it's done
		_clear_grass(r)
		progress._apply()
		_save()
	builder.on_finished = func(b: Building, up: bool):
		_clear_grass(b.world_footprint())
		herd._rescan()
		progress._apply()  # its perk (or the bigger one) starts now
		var nm: String = building_ui._entry(b)[0]
		herd_ui.notify("%s سطح %s شد" % [nm, UiTheme.fa(b.level)] if up else "ساخت %s تموم شد" % nm)
		_save()
	add_child(builder)
	market.day = day
	market.herd = herd
	market.builder = builder
	market.notify = herd_ui.notify
	if not saved.is_empty() and saved.has("market"):
		market.from_save(saved.market)
	add_child(market)
	herd_ui.herd = herd
	herd_ui.builder = builder
	herd_ui.market = market
	herd_ui.delivery = delivery
	herd_ui.workers = workers
	delivery.notify = herd_ui.notify
	if not saved.is_empty() and saved.has("delivery"):
		delivery.from_save(saved.delivery)
	add_child(herd_ui)
	market_ui.market = market
	market_ui.builder = builder
	add_child(market_ui)
	breed_ui.herd = herd
	breed_ui.builder = builder
	breed_ui.market = market
	breed_ui.delivery = delivery
	breed_ui.notify = herd_ui.notify
	add_child(breed_ui)
	workers.day = day
	workers.herd = herd
	workers.builder = builder
	workers.notify = herd_ui.notify
	workers.world = self
	if not saved.is_empty() and saved.has("workers"):
		workers.from_save(saved.workers)
	add_child(workers)
	var crew := Crew.new()
	crew.workers = workers
	crew.herd = herd
	crew.day = day
	crew.world = self
	add_child(crew)
	sfx.herd = herd
	sfx.crew = crew
	sfx.day = day
	add_child(sfx)
	if _arg("crew", "") != "":  # test: one hand of each skill
		for k in 4:
			workers.hired.append({name = Workers.NAMES[k], skill = k, level = 2, wage = 50})
	workers_ui.workers = workers
	workers_ui.builder = builder
	workers_ui.herd = herd
	add_child(workers_ui)
	events.day = day
	events.herd = herd
	events.builder = builder
	events.workers = workers
	events.notify = herd_ui.notify
	events.world = self
	if not saved.is_empty() and saved.has("events"):
		events.from_save(saved.events)
	add_child(events)
	ledger.builder = builder
	ledger.day = day
	if not saved.is_empty() and saved.has("ledger"):
		ledger.from_save(saved.ledger)
	add_child(ledger)
	bank.builder = builder
	bank.herd = herd
	bank.herd_ui = herd_ui
	bank.delivery = delivery
	bank.events = events
	bank.day = day
	bank.notify = herd_ui.notify
	if not saved.is_empty() and saved.has("bank"):
		bank.from_save(saved.bank)
	add_child(bank)
	warnings.herd = herd
	warnings.day = day
	warnings.delivery = delivery
	warnings.builder = builder
	warnings.notify = herd_ui.notify
	add_child(warnings)
	market_ui.ledger = ledger
	if _arg("ledger", "") != "":
		ledger.call_deferred("toggle")
	rival.day = day
	rival.market = market
	rival.progress = progress
	rival.notify = herd_ui.notify
	if not saved.is_empty() and saved.has("rival"):
		rival.from_save(saved.rival)
	add_child(rival)
	auction.rival = rival
	rodeo.rival = rival
	progress_ui.rival = rival
	weather.day = day
	weather.events = events
	weather.herd = herd
	weather.rig = rig
	if not saved.is_empty() and saved.has("weather"):
		weather.from_save(saved.weather)
	if _arg("weather", "") != "":  # test: --weather=1 rain, 2 storm, 3 snow
		weather.now = int(_arg("weather", ""))
		weather.until = 1e9
		weather._next_roll = 1e9  # --weather=0 stays clear
		day.overcast = 0.85 if weather.now == Weather.STORM else (0.5 if weather.now != Weather.CLEAR else 0.0)
	add_child(weather)
	hud.weather = weather
	weather.detail = Hud.QUALITY[hud._quality][3]
	auction.day = day
	auction.herd = herd
	auction.market = market
	auction.builder = builder
	auction.events = events
	auction.notify = herd_ui.notify
	add_child(auction)
	drive.day = day
	drive.herd = herd
	drive.market = market
	drive.builder = builder
	drive.workers = workers
	drive.events = events
	drive.auction = auction
	drive.notify = herd_ui.notify
	if not saved.is_empty() and saved.has("drive"):
		drive.from_save(saved.drive)
	add_child(drive)
	rodeo.day = day
	rodeo.builder = builder
	rodeo.progress = progress
	rodeo.events = events
	rodeo.world = self
	rodeo.notify = herd_ui.notify
	rodeo.others = [auction, drive]
	rodeo.autopilot = _arg("bot", "") != ""
	add_child(rodeo)
	fair.day = day
	fair.herd = herd
	fair.builder = builder
	fair.rival = rival
	fair.notify = herd_ui.notify
	fair.others = [events, auction, drive, rodeo]
	fair.autopilot = _arg("bot", "") != "" or _arg("fair", "") == "bot"
	if not saved.is_empty() and saved.has("fair"):
		fair.from_save(saved.fair)
	add_child(fair)
	rodeo.others.append(fair)
	drive.fair = fair
	building_ui.builder = builder
	building_ui.herd = herd
	building_ui.workers = workers
	building_ui.events = events
	building_ui.progress = progress
	building_ui.market = market
	building_ui.day = day
	building_ui.world = self
	building_ui.save = _save
	building_ui.hay_buy = herd_ui.buy_hay
	cow_ui.herd = herd
	cow_ui.builder = builder
	cow_ui.market = market
	cow_ui.notify = herd_ui.notify
	add_child(cow_ui)
	building_ui.cow_ui = cow_ui
	if _arg("cowboard", "") != "":  # test: the first cow's board
		cow_ui.call_deferred("open", herd.cows[0])
	horses.day = day
	horses.world = self
	horses.herd = herd
	horses.builder = builder
	horses.notify = herd_ui.notify
	if not saved.is_empty() and saved.has("horses"):
		horses.from_save(saved.horses)
	add_child(horses)
	horse_ui.horses = horses
	fair.horses = horses
	horse_ui.builder = builder
	add_child(horse_ui)
	building_ui.horses = horses
	building_ui.boards = {herd = herd_ui, breed = breed_ui, workers = workers_ui, market = market_ui, progress = progress_ui, horses = horse_ui}
	add_child(building_ui)
	if _arg("horses", "") != "":  # test: a stable's worth of horses, --horses=N (some foals, one in foal)
		for i in int(_arg("horses", "")):
			var h := horses._add(i % 3 != 0, 1 + i % 5, Horses.ADULT + 1.0 if i < 4 else 2.0 * i)
			if i == 1:
				h.foal = 30.0
				h.sire = 4
	if _arg("horseboard", "") != "":
		horse_ui.call_deferred("toggle")
	if _arg("board", "") != "":  # test: open the board of the first building of this kind, e.g. --board=Barn
		var bb: Array = get_children().filter(func(n): return n is Building and n.get_script().get_global_name() == _arg("board", ""))
		if not bb.is_empty():
			building_ui.call_deferred("open", bb[0])
	if _arg("manage", "") != "":  # test: the «مدیریت رنچ» board open
		builder.call_deferred("_toggle_manage")
	if _arg("ask", "") != "":  # test: the question before selling (--cowboard=1 --ask=1) or knocking down (--board=Barn --ask=1)
		get_tree().create_timer(0.3).timeout.connect(func():
			var row: Container = cow_ui._row if cow_ui._panel.visible else building_ui._row
			row.get_child(row.get_child_count() - 1 if row == building_ui._row else 1).pressed.emit())
	if _arg("toast", "") != "":  # test: a pile of long notices
		for t in ["خرج دیروز گله:  ۲۳۰- دلار", "یه خریدار می‌خواد ازت گاو بخره؛ برو تو «بازار» و ببین چی می‌خواد، شاید بیشتر از قیمت بازار بده", "حقوق دیروز کارگرها:  ۱۲۰- دلار", "تو رنچ‌های همسایه مریضی اومده؛ گاوهای تو واکسن زدن و چیزیشون نمی‌شه، ولی حواست به گوساله‌های تازه باشه"]:
			herd_ui.call_deferred("notify", t)
	rodeo._due = _arg("rodeo", "") != ""  # test: a rodeo right away (--rodeo=go: already riding)
	if _arg("rodeo", "") in ["go", "fall"]:
		rodeo._due = false
		rodeo.autopilot = _arg("rodeo", "") == "go"
		rodeo.call_deferred("_invite")
		rodeo.call_deferred("_start")
	drive._due = _arg("drive", "") != ""  # test: the trail buyer's word comes at once
	if _arg("auction", "") != "":  # test: an auction right away (--auction=go skips the invite)
		auction._due = true
		if _arg("auction", "") == "go":
			auction.call_deferred("_go_now")
	progress.day = day
	progress.market = market
	progress.builder = builder
	progress.notify = herd_ui.notify
	progress.world = self
	if not saved.is_empty() and saved.has("progress"):
		progress.from_save(saved.progress)
	if _arg("money", "") != "":  # test: start with this much money
		builder.money = int(_arg("money", ""))
	if _arg("rep", "") != "":  # test: start with this much reputation
		progress.rep = float(_arg("rep", ""))
	add_child(progress)
	progress.hook(herd)
	fair.progress = progress
	if _arg("fair", "") != "":  # test: the fair right away (--fair=race / show: straight to that contest, --fair=coach: a festival's stagecoach race)
		fair._due = true
		if _arg("fair", "") == "go":  # test: already racing with the best horse, the bot riding
			fair._due = false
			fair.autopilot = true
			fair._coach = _arg("coach", "") != ""  # --coach=1: the festival's stagecoach race
			(func():
				fair._open()
				fair._race_start(fair._racehorses()[0])).call_deferred()
		if _arg("fair", "") == "judge":  # test: the cattle show judged, every place called
			fair._due = false
			(func():
				fair._open()
				fair._show_setup()
				fair._judge()
				for i in fair._entries.size():
					fair._announce()).call_deferred()
		if _arg("fair", "") in ["race", "show", "coach"]:
			fair._due = false
			if _arg("fair", "") == "coach":
				fair.call_deferred("festival", "coach", "مسابقه‌ی دلیجان", "coach")
			else:
				fair.call_deferred("_open")
				fair.call_deferred("_race_setup" if _arg("fair", "") == "race" else "_show_setup")
	goals.herd = herd
	goals.market = market
	goals.workers = workers
	goals.builder = builder
	goals.progress = progress
	goals.land = land
	goals.notify = herd_ui.notify
	if not saved.is_empty() and saved.has("goals"):
		goals.from_save(saved.goals)
	add_child(goals)
	goals.hook()
	legacy.day = day
	legacy.herd = herd
	legacy.market = market
	legacy.builder = builder
	legacy.progress = progress
	legacy.goals = goals
	legacy.notify = herd_ui.notify
	if not saved.is_empty() and saved.has("legacy"):
		legacy.from_save(saved.legacy)
	add_child(legacy)
	progress_ui.progress = progress
	progress_ui.goals = goals
	progress_ui.builder = builder
	progress_ui.bank = bank
	add_child(progress_ui)
	progress_ui._refresh()
	var land_ui := LandUI.new()
	land_ui.land = land
	land_ui.builder = builder
	land_ui.on_bought = func():
		herd_ui.notify("زمین تازه مال تو شد: گاوها حالا اونجا هم می‌چرن")
		_save()
	add_child(land_ui)
	if _arg("land", "") != "":
		land_ui.toggle()
		if _arg("land", "") == "pick":  # test: the first plot for sale picked, waiting for the yes
			for i in Land.GRID * Land.GRID:
				if land.can_buy(i):
					land_ui.pick(i)
					break
	if _arg("unlock", "") != "":  # test: own plot N without paying
		land.unlock(int(_arg("unlock", "")))
	if _arg("market", "") != "":
		market_ui.toggle()
	day.speed = float(_arg("speed", "1"))
	if _arg("herd", "") != "":
		herd_ui.toggle()
	if _arg("breed", "") != "":
		breed_ui.toggle()
	if _arg("ranch", "") != "":
		progress_ui.toggle()
	if _arg("workers", "") != "":
		workers_ui.toggle()
	if _arg("legacy", "") != "":  # test: `--legacy=1` the handover to generation 2, `--legacy=3` to the fourth
		day.day = int(_arg("legacy", "")) * Legacy.GENERATION * DayCycle.DAYS_PER_SEASON * 4
		legacy.new_day(day.day)
	if _arg("event", "") != "":  # test: `--event=wolves` shows that event's board
		events.call("_" + _arg("event", ""))
	if saved.is_empty() or saved.get("tutorial", 99) < 99:
		tutorial = Tutorial.new()
		tutorial.herd_ui = herd_ui
		tutorial.market_ui = market_ui
		tutorial.builder = builder
		tutorial.workers_ui = workers_ui
		tutorial.progress_ui = progress_ui
		tutorial.step = int(saved.get("tutorial", 0))
		if _arg("tutorial", "1") == "0" or (not SaveGame.enabled() and _arg("tutorial", "") == ""):
			tutorial.step = 99  # test runs skip it unless asked with --tutorial=1
		if _arg("tstep", "") != "":  # test: start the tips at this step
			tutorial.step = int(_arg("tstep", ""))
		add_child(tutorial)
	daily.builder = builder
	daily.market = market
	daily.herd = herd
	daily.progress = progress
	daily.world = self
	daily.notify = herd_ui.notify
	daily.can_pop = func(): return (tutorial == null or not tutorial._box.visible) and (SaveGame.enabled() or _arg("daily", "") != "")
	if not saved.is_empty() and saved.has("daily"):
		daily.from_save(saved.daily)
	add_child(daily)
	if _arg("daily", "") == "claim":  # test: today's prize taken, a job half done, the board open
		daily.claim()
		daily._count("cattle", 1)
		daily.toggle()
	festivals.builder = builder
	festivals.market = market
	festivals.herd = herd
	festivals.horses = horses
	festivals.fair = fair
	festivals.progress = progress
	festivals.notify = herd_ui.notify
	festivals.force = _arg("fest", "")  # test: --fest=yalda puts that festival on, whatever the date
	festivals.can_pop = func(): return (tutorial == null or not tutorial._box.visible) and not daily._panel.visible and (SaveGame.enabled() or _arg("fest", "") != "")
	if not saved.is_empty() and saved.has("festivals"):
		festivals.from_save(saved.festivals)
	add_child(festivals)
	surprises.day = day
	surprises.herd = herd
	surprises.builder = builder
	surprises.market = market
	surprises.events = events
	surprises.progress = progress
	surprises.world = self
	surprises.notify = herd_ui.notify
	if not saved.is_empty() and saved.has("surprises"):
		surprises.from_save(saved.surprises)
	add_child(surprises)
	collection.herd = herd
	collection.horses = horses
	collection.fair = fair
	collection.festivals = festivals
	collection.builder = builder
	collection.progress = progress
	collection.notify = herd_ui.notify
	if not saved.is_empty() and saved.has("collection"):
		collection.from_save(saved.collection)
	add_child(collection)
	surprises.found.connect(func(k: String): collection.add("sur:" + k))
	building_ui.boards.book = collection
	if _arg("seen", "") != "":  # test: a well-filled book (one row full, prize waiting)
		for k in ["cow0:0", "cow0:1", "cow1", "cow2", "coat0", "coat1", "coat2", "coat3", "coat4", "race1", "race3", "show1", "show2", "fest:nowruz", "fest:yalda", "sur:gold", "sur:twins", "sur:trader", "sur:rain"]:
			collection.seen[k] = true
		fair.trophies = [{k = "race", p = 1, y = 0, s = 0, who = "باد", fest = ""}, {k = "race", p = 1, y = 1, s = 2, who = "باد", fest = ""}, {k = "race", p = 3, y = 0, s = 1, who = "برق", fest = ""}, {k = "show", p = 1, y = 0, s = 2, who = "گلی", fest = ""}, {k = "show", p = 2, y = 1, s = 0, who = "ابری", fest = ""}]
		festivals.done = {nowruz = 1405, yalda = 1405}
	if _arg("book", "") != "":
		collection.call_deferred("toggle")
	if _arg("surprise", "") != "":  # test: --surprise=trader (or any of Surprises.ORDER but twins) right away
		(func():
			surprises.call("_" + _arg("surprise", ""))
			surprises.found.emit(_arg("surprise", ""))).call_deferred()
	if _arg("coats", "") != "":  # test: one horse of each coat, the rare ones too
		for i in Cowboy.COATS.size():
			horses._add(i % 2 == 0, 3, Horses.ADULT + 1.0, i)
	away.builder = builder
	away.delivery = delivery
	away.notify = herd_ui.notify
	away.name_of = func(b): return building_ui._entry(b)[0]
	away.notify_on = func(): return hud.notify_on
	if not saved.is_empty() and saved.has("away"):
		away.from_save(saved.away)
	add_child(away)
	hud.snapshot = _state
	if _arg("codetest", "") != "":
		get_tree().create_timer(1.0).timeout.connect(func():
			var st := _state()
			var code := SaveGame.to_code(st)
			var back := SaveGame.from_code("  " + code.substr(0, 40) + "\n" + code.substr(40) + " ")
			print("CODE len ", code.length(), " json ", JSON.stringify(st).length(), " back ok ", not back.is_empty(), " money ", back.get("money"), " cows ", back.herd.cows.size() if back.has("herd") else -1, " bad ", SaveGame.from_code("RANCH1:abc").is_empty(), SaveGame.from_code("hello").is_empty()))
	if not saved.is_empty() and saved.has("saved_at"):  # the work went on while the game was closed
		away.catch_up(Away.now() - float(saved.saved_at))
	if _arg("away", "") != "":  # test: half a second in, as if the game had been closed this many seconds
		get_tree().create_timer(0.5).timeout.connect(func():
			print("AWAY before ", builder.sites.map(func(b): return snappedf(b.work_left, 0.01)), " trucks ", delivery.orders.map(func(o): return snappedf(o.t, 0.01)))
			print("AWAY coming ", away.coming())
			away.catch_up(float(_arg("away", "")))
			print("AWAY after ", builder.sites.map(func(b): return snappedf(b.work_left, 0.01)), " trucks ", delivery.orders.map(func(o): return snappedf(o.t, 0.01))))
	if SaveGame.recovered:
		herd_ui.notify("ذخیره‌ی آخر خراب شده بود؛ رنچت از پشتیبان برگشت")
	day.hour_changed.connect(_on_hour)
	day.day_changed.connect(_on_day)
	var autosave := Timer.new()  # also catches buys and sales between day changes
	autosave.wait_time = 60.0
	autosave.autostart = true
	autosave.timeout.connect(_save)
	add_child(autosave)
	_test_build()
	var o := _arg("order", "")  # test: `--order=calves,hay@seconds_already_waited`
	if o != "":
		var n := o.get_slice("@", 0).split(",")
		delivery.order(int(n[0]), int(n[1]))
		delivery.orders[0].t = float(o.get_slice("@", 1))
	if _arg("barsize", "") != "":  # test: widths of the bottom bar's buttons
		await get_tree().process_frame
		await get_tree().process_frame
		print("BAR ", builder._menu.size, " ", builder._menu.get_children().map(func(c): return [c.get("text"), c.size.x]), " sites ", builder.sites.map(func(b): return b.work_total))
	if _arg("debug", "") != "":
		_debug_herd()
		market.notify = func(t): print("   NOTE ", t)


func _debug_herd() -> void:
	herd.died.connect(func(cause):
		print("   DIED of %s" % cause))
	herd.born.connect(func(): print("   BORN"))
	herd.fell_sick.connect(func(): print("   SICK"))
	breed_ui.notify = func(t): print("   NOTE ", t)
	workers.notify = breed_ui.notify
	events.notify = breed_ui.notify
	auction.notify = breed_ui.notify
	drive.notify = breed_ui.notify
	rodeo.notify = breed_ui.notify
	progress.notify = breed_ui.notify
	bank.notify = breed_ui.notify
	warnings.notify = breed_ui.notify
	daily.notify = breed_ui.notify
	fair.notify = breed_ui.notify
	festivals.notify = breed_ui.notify
	surprises.notify = breed_ui.notify
	collection.notify = breed_ui.notify
	away.notify = breed_ui.notify
	print("DAILY jobs ", daily.jobs, " day ", Daily.today(), " next prize day ", daily.next_day())
	while true:
		await get_tree().create_timer(4.0).timeout
		if _arg("yes", "") != "" and events._panel.visible:  # test: --yes=1 takes the first choice on any board
			print("   ASK ", events._title.text, " | ", events._text.text.replace("\n", " "))
			events._row.get_child(0).pressed.emit()
		var st := [0, 0, 0, 0, 0, 0, 0, 0, 0]
		var h := 0.0
		var w := 0.0
		var cows := herd.alive()
		for c in cows:
			st[c.state] += 1
			h += c.hunger
			w += c.weight
		var n := maxf(cows.size(), 1)
		if _arg("bot", "") != "":  # test player: contracts, sell ready cows, keep ~15 head, stock hay before winter
			for o in market.offers.duplicate():
				market.accept(o)
			for c in market.active.duplicate():
				market.deliver(c)
			if events._panel.visible:  # the bot pays when it can, else takes the risk
				print("   EVENT ", events._title.text)
				var btns := events._row.get_children().filter(func(b): return not b.disabled and not b.is_queued_for_deletion())
				if not btns.is_empty():
					btns[0 if _arg("risky", "") == "" else -1].pressed.emit()
			if auction.is_open():  # the bot goes to every auction and sells at whatever the hammer says
				print("   AUCTION ", auction._title.text, " | ", auction._who.text.replace("\n", " "))
				var ab := auction._row.get_children().filter(func(b): return not b.disabled and not b.is_queued_for_deletion())
				if not ab.is_empty():
					ab[0].pressed.emit()
			if drive.is_open():
				print("   DRIVE ", drive._title.text, " | ", drive._text.text.left(60))
				var db := drive._row.get_children().filter(func(b): return not b.disabled and not b.is_queued_for_deletion())
				if not db.is_empty():
					db[randi() % db.size()].pressed.emit()
			if rodeo.is_open() and rodeo._over:  # the bot rides once a rodeo, and once more if thrown
				print("   RODEO ", rodeo._title.text, " | ", rodeo._text.text)
				var rb := rodeo._row.get_children().filter(func(b): return not b.disabled and not b.is_queued_for_deletion())
				if not rb.is_empty():
					rb[0 if rodeo._title.text != "افتادی!" or randf() < 0.5 else -1].pressed.emit()
			if not drive.trail.is_empty():
				print("   TRAIL %d cows %.0f kg  %.0f%%" % [drive.trail.n, drive.trail.kg, drive.progress() * 100.0])
			while workers.capacity() < herd.alive().size() + 5 and workers.hired.size() < workers.slots() and not workers.candidates.is_empty():
				workers.hire(workers.candidates[0])
			if _arg("hold", "") == "" or day.day % DayCycle.DAYS_PER_SEASON == 0:  # --hold=1 keeps ready cows for the auction and the drive
				herd_ui.sell()
			# breeding herd: a bull and up to 8 cows, home-bred heifers first; vet and vaccines as needed
			if herd.of_kind(Herd.BULL).size() + delivery.orders.reduce(func(a, o): return a + o.bulls, 0) == 0 and builder.money > market.bull_price() + 1500:
				breed_ui.buy_bull()
			if herd.of_kind(Herd.BREEDER).size() < 8:
				breed_ui.keep_heifer()
			if herd.sick_count() > 0:
				breed_ui.call_vet()
			breed_ui.vaccinate()
			while herd.alive().size() + delivery.pending_animals() < 15 and builder.money > market.calf_price() + 1500:
				herd_ui.buy()
			if day.season() == DayCycle.SUMMER:
				herd_ui.cut_hay()
			for i in Land.GRID * Land.GRID:  # buy a neighbouring plot when there's money to spare
				if land.can_buy(i) and builder.money > land.price() + 6000:
					builder.add_money(-land.price(), "build")
					land.unlock(i)
					print("   BOUGHT plot %d" % i)
					break
			if day.season() == DayCycle.AUTUMN:
				while herd_ui._hay_space() >= HerdUI.HAY_LOT and builder.money > 3000:
					herd_ui.buy_hay()
		var outside := cows.filter(func(c): return absf(c.pos.x) > 48.0 or absf(c.pos.z) > 48.0).size()
		var off_land := cows.filter(func(c): return not land.is_open(c.pos)).size()
		print("   cows grazing on bought land: %d, on locked land: %d" % [outside, off_land])
		var preg := herd.of_kind(Herd.BREEDER).filter(func(c): return c.preg > 0.0).size()
		print("   rep %d level %d era %d  price x%.2f" % [progress.rep, progress.level(), progress.era(), market.era_mul])
		var crew_n: Crew = sfx.crew
		print("   riders %s" % [crew_n._riders.values().map(func(r): return "%s%s(%.0f,%.0f)st%.1f" % ["H" if r.home else ("B" if r.get("bed", false) else ""), r.skill, r.node.position.x, r.node.position.z, r.stuck])])
		print("   hands %d (wages %d, capacity %d)  effects %s  goals %s  legacy %s" % [workers.hired.size(), workers.wages(), workers.capacity(), events.effects.keys().filter(func(k): return events.active(k)), goals.done, legacy.seen])
		print("   breeders %d (in calf %d)  bulls %d  sick %d  unvaccinated %d" % [herd.of_kind(Herd.BREEDER).size(), preg, herd.of_kind(Herd.BULL).size(), herd.sick_count(), herd.unvaccinated().size()])
		print("d%d %02dh %s  price %.2f  active %d  cows %d  hunger %.2f kg %d  hay %d/%d  shelter %d  money %d  debt %d  wander/graze/water/drink/idle/tofeed/feed/topen/sleep %s" % [
			day.day, int(day.hour), DayCycle.SEASON_NAMES[day.season()], market.price, market.active.size(), cows.size(), h / n, w / n, herd.hay, herd.hay_cap, herd.shelter, builder.money, bank.debt, st])


## Test hook for renders: `--ghost=<catalog index>@x,z` opens placement there, `--place` confirms.
func _test_build() -> void:
	if _arg("menu", "") != "":
		builder._toggle_menu()
		var back := int(_arg("menu", ""))  # test: --menu=<pixels> scrolls the cards that far left of the start
		if back > 1:
			for i in 3:
				await get_tree().process_frame
			builder._scroll.scroll_horizontal = int(builder._scroll.get_h_scroll_bar().max_value) - back
	var g := _arg("ghost", "")
	if g == "":
		return
	var xz := g.get_slice("@", 1).split(",")
	rig.target = Vector3(float(xz[0]), 0, float(xz[1]))
	rig.snap()
	builder.choose(int(g.get_slice("@", 0)))
	if _arg("place", "") != "":
		for i in 2:  # let Builder._process validate the spot first
			await get_tree().process_frame
		builder.place()
		var w := _arg("work", "")  # test: --work=0.5 jumps the new site halfway (--work=up@0.5: an upgrade)
		if w != "" and not builder.sites.is_empty():
			var b: Building = builder.sites[-1]
			if w.begins_with("up@"):
				b.work_left = 0.0
				b.site.finish()
				b.site.free()
				builder.sites.clear()
				b.work_left = 0.0
				builder.start_work(b, true)
				w = w.get_slice("@", 1)
			b.work_left = b.work_total * (1.0 - float(w))
			if _arg("freeze", "") != "":
				day.speed = 0.0
			b.site.show_at(float(w))
			if _arg("siteboard", "") != "":  # test: the board of the site
				building_ui.open(b)


## Hides grass tufts inside a newly placed building's footprint.
func _clear_grass(r: Rect2) -> void:
	var gone := Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)
	for mm in grass_chunks:
		var a := mm.get_aabb()
		if not r.intersects(Rect2(a.position.x, a.position.z, a.size.x, a.size.z)):
			continue
		for i in mm.instance_count:
			var o := mm.get_instance_transform(i).origin
			if r.has_point(Vector2(o.x, o.z)):
				mm.set_instance_transform(i, gone)


func _arg(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.get_slice("=", 1)
	return def


func _shot(shot: String) -> void:
	match shot:  # target, dist, yaw
		"close":
			rig.target = Vector3(2, 0, 6)
			rig.dist = 15.0
			rig.yaw = 0.45
		"house":
			rig.target = Vector3(-11, 0, 26)
			rig.dist = 16.0
			rig.yaw = 1.1
		"herd":
			rig.target = Vector3(20, 0, 16)
			rig.dist = 20.0
			rig.yaw = 0.5
		"apron":
			rig.target = Vector3(1, 0, 13)
			rig.dist = 13.0
			rig.yaw = 0.9
		"overview":  # whole ranch from high up (past the zoom limit, for screenshots)
			rig.target = Vector3(0, 0, 10)
			rig.dist = 190.0
			rig.yaw = 0.3
		"edge":
			rig.target = Vector3(70, 0, 70)
			rig.dist = 22.0
			rig.yaw = 0.7
		"crew":  # the hands waiting by the ranch house
			rig.target = Vector3(-8, 1, 32)
			rig.dist = 9.0
			rig.yaw = 0.6
		"gate":
			rig.target = Vector3(9, 3, 94)
			rig.dist = 26.0
			rig.yaw = 0.35
		"mill":
			rig.target = Vector3(18, 2, -3)
			rig.dist = 17.0
			rig.yaw = 0.3
	var gal := _arg("gallery", "")  # test: --gallery=Barn puts levels 1, 2 and 3 of it side by side
	if gal != "":
		var kind: Script = null
		for c in builder.CATALOG:
			if c[1].get_global_name() == gal:
				kind = c[1]
		var x := 0.0
		var nodes: Array[Building] = []
		for lv in [1, 2, 3]:
			var node: Building = kind.new()
			node.level = lv
			var f := node.local_foot_at(lv)
			var sz := Building.size_of(lv)
			x += -f.position.x * sz.x
			node.position = Vector3(x, 0, 0)
			add_child(node)
			nodes.append(node)
			x += f.end.x * sz.x + 4.0
		var mid := x * 0.5 - 2.0
		for n in nodes:
			n.position.x -= mid
		rig.target = Vector3(0, 2, 0)
		rig.dist = x * 1.02
		rig.yaw = 0.0
	var look := _arg("look", "")  # test: --look=x,z,dist,yaw
	if look != "":
		var v := look.split(",")
		rig.target = Vector3(float(v[0]), 0, float(v[1]))
		rig.dist = float(v[2])
		rig.yaw = float(v[3])
	rig.snap()


func _on_hour(_h: float) -> void:
	_water_check()
	var night := Building.window_mat.emission_energy_multiplier / 2.5
	crickets.volume_db = linear_to_db(maxf(night, 0.001)) - 8.0
	grass_mat.set_shader_parameter("to_sun", day.light.global_basis.z)
	# the new season's look fades in over the first quarter of it
	var s := day.season()
	var k := smoothstep(0.0, 0.25, day.season_progress())
	var a: Array = LOOK[(s + 3) % 4]
	var b: Array = LOOK[s]
	grass_mat.set_shader_parameter("tint", a[0].lerp(b[0], k))
	ground_mat.set_shader_parameter("grass_tint", a[1].lerp(b[1], k))
	ground_mat.set_shader_parameter("lush_tint", a[2].lerp(b[2], k))
	var snow := lerpf(a[3], b[3], k)
	ground_mat.set_shader_parameter("snow", snow)
	grass_mat.set_shader_parameter("snow", snow)
	crickets.stream_paused = s == DayCycle.WINTER  # no crickets in the snow
	# birds by day, fewer in winter
	prairie.volume_db = linear_to_db(maxf(1.0 - night, 0.001)) - (16.0 if s == DayCycle.WINTER else 8.0)


## No windmill or pond yet and the cows getting thirsty: a reminder every few game hours.
var _dry_warn := 0.0
func _water_check() -> void:
	var t := day.day * 24.0 + day.hour
	if t < _dry_warn or not herd._tanks.is_empty():
		return
	if herd.alive().any(func(c): return c.thirst > 0.45):
		_dry_warn = t + 3.0
		herd_ui.notify("گاوها تشنه‌ان و آب ندارن! از «ساخت» یه آسیاب بادی یا آبگیر بساز")


func _on_day(d: int) -> void:
	if d % DayCycle.DAYS_PER_SEASON == 0:
		herd_ui.notify(SEASON_NEWS[day.season()])
	rival.new_day(d)
	market.new_day(d)
	workers.new_day(d)
	progress.new_day(d)
	events.new_day(d)
	surprises.new_day(d)
	auction.new_day(d)
	drive.new_day(d)
	rodeo.new_day(d)
	fair.new_day(d)
	horses.new_day(d)
	legacy.new_day(d)
	_save()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST]:
		_save()  # phone apps get killed in the background without warning


func _save() -> void:
	if not is_node_ready():
		return
	SaveGame.write(_state())


## Everything the save file (and a ranch code) holds.
func _state() -> Dictionary:
	var buildings := []
	for n in get_children():
		if n is Building and not n.has_node("Marker"):
			buildings.append([n.get_script().resource_path, n.position.x, n.position.z, n.rotation_degrees.y, n.level, n.work_left, n.work_total, n.upgrading])
	return {saved_at = Time.get_unix_time_from_system(), yard = 2, money = builder.money, day = day.day, hour = day.hour, buildings = buildings, herd = herd.to_save(), market = market.to_save(), workers = workers.to_save(), progress = progress.to_save(), events = events.to_save(), weather = weather.to_save(), rival = rival.to_save(), ledger = ledger.to_save(), drive = drive.to_save(), delivery = delivery.to_save(), land = land.to_save(), goals = goals.to_save(), legacy = legacy.to_save(), horses = horses.to_save(), fair = fair.to_save(), festivals = festivals.to_save(), surprises = surprises.to_save(), collection = collection.to_save(), bank = bank.to_save(), daily = daily.to_save(), away = away.to_save(), tutorial = tutorial.step if tutorial else 99}


# ---------- ground & grass ----------

func _ground() -> void:
	var sm := ground_mat
	sm.shader = load("res://ground.gdshader")
	var opt := _arg("ground", "")  # test: a different grass texture from textures/opts
	var alb := "grass_ground_diff.jpg" if opt == "" else "opts/%s_col.jpg" % opt
	var nrm := "grass_ground_nor_gl.jpg" if opt == "" else "opts/%s_nrm.jpg" % opt
	if opt != "":
		sm.set_shader_parameter("boost", 1.35)
	for p in [["grass_alb", alb], ["grass_nrm", nrm],
			["dirt_alb", "dirt_diff.jpg"], ["dirt_nrm", "dirt_nor_gl.jpg"],
			["mask", "ground_mask.png"], ["macro", "macro_noise.png"]]:
		sm.set_shader_parameter(p[0], load(TEX + p[1]))
	sm.set_shader_parameter("span", MASK_SPAN)
	sm.set_shader_parameter("grazed", herd.grass_tex)
	sm.set_shader_parameter("plots", land.texture)
	sm.set_shader_parameter("land_half", Land.HALF)
	var pm := PlaneMesh.new()
	pm.size = Vector2(800, 800)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = sm
	add_child(mi)


func _mask(p: Vector2) -> Color:
	var u := p / MASK_SPAN + Vector2(0.5, 0.5)
	if u.x < 0.0 or u.x >= 1.0 or u.y < 0.0 or u.y >= 1.0:
		return Color.BLACK
	return mask_img.get_pixel(int(u.x * mask_img.get_width()), int(u.y * mask_img.get_height()))


func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for i in 7:
		var ang := r.randf() * TAU
		var h := r.randf_range(0.22, 0.55)  # knee height next to the cattle
		var base := Vector3(r.randf_range(-0.1, 0.1), 0, r.randf_range(-0.1, 0.1))
		var side := Vector3(cos(ang), 0, sin(ang)) * 0.035
		var tip := base + Vector3(-sin(ang), 0, cos(ang)) * r.randf_range(0.08, 0.3) + Vector3.UP * h
		for v in [[base - side, Color(0.2, 0.19, 0.09)], [tip, Color(0.8, 0.62, 0.3)], [base + side, Color(0.2, 0.19, 0.09)]]:
			st.set_normal(Vector3.UP)
			st.set_color(v[1])
			st.add_vertex(v[0])
	return st.commit()


func _grass() -> void:
	var mat := grass_mat
	mat.shader = load("res://grass.gdshader")
	mat.set_shader_parameter("grazed", herd.grass_tex)
	mat.set_shader_parameter("plots", land.texture)
	mat.set_shader_parameter("land_half", Land.HALF)
	mat.set_shader_parameter("span", MASK_SPAN)
	var mesh := _tuft_mesh()
	var r := RandomNumberGenerator.new()
	r.seed = 11
	# bucket instances into chunks so off-screen grass is frustum-culled
	var chunks := {}
	var placed := 0
	while placed < GRASS_COUNT:
		var p := Vector2(r.randf_range(-118, 118), r.randf_range(-118, 118))
		if builder.occupied.any(func(r): return r.has_point(p)):
			continue
		var m := _mask(p)
		if r.randf() < smoothstep(0.1, 0.4, m.r) or r.randf() > 1.0 - smoothstep(Land.HALF + 4.0, Land.HALF + 22.0, maxf(absf(p.x), absf(p.y))):
			continue
		var s := r.randf_range(0.6, 1.4) * (1.0 + m.g * 0.4)
		var xf := Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s, s * r.randf_range(0.8, 1.3), s)), Vector3(p.x, 0, p.y))
		var c := Color(1, 1, 1).lerp(Color(0.62, 0.8, 0.45), maxf(r.randf() ** 2, m.g * 0.8)).darkened(r.randf() * 0.25)
		var key := Vector2i(floori(p.x / GRASS_CHUNK), floori(p.y / GRASS_CHUNK))
		if not chunks.has(key):
			chunks[key] = [[], []]
		chunks[key][0].append(xf)
		chunks[key][1].append(c)
		placed += 1
	for key in chunks:
		var xs: Array = chunks[key][0]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, xs[i])
			mm.set_instance_color(i, chunks[key][1][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 90.0
		add_child(mmi)
		grass_chunks.append(mm)
		grass_nodes.append(mmi)


# ---------- props ----------

func _props() -> void:
	pass  # the old corral, its trough and hay stack are a building now (Corral)


## Rail fence all round the ranch, open where the road comes through the gate at x = gate_x.
func _ranch_fence(gate_x: float) -> void:
	var h := Land.HALF
	var gap := RanchGate.HALF - 0.3
	for seg in [[Vector2(-h, -h), Vector2(h, -h)], [Vector2(h, -h), Vector2(h, h)], [Vector2(-h, h), Vector2(-h, -h)],
			[Vector2(h, h), Vector2(gate_x + gap, h)], [Vector2(gate_x - gap, h), Vector2(-h, h)]]:
		_fence(seg[0], seg[1], fence_mat)


func _fence(a: Vector2, c: Vector2, m: Material) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(a.x * 31 + a.y * 7)
	var len := a.distance_to(c)
	var n := int(ceil(len / 2.5))
	var dir := (c - a).normalized()
	var yaw := atan2(dir.x, dir.y)
	for i in n + 1:
		var p := a.lerp(c, float(i) / n)
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.16, 1.5, 0.16)
		post.mesh = pm
		post.material_override = m
		post.position = Vector3(p.x, 0.75, p.y)
		post.rotation = Vector3(r.randf_range(-0.04, 0.04), r.randf(), r.randf_range(-0.04, 0.04))
		add_child(post)
	for h in [0.5, 0.95, 1.35]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.06, 0.14, len)
		rail.mesh = rm
		rail.material_override = m
		var mid := (a + c) * 0.5
		rail.position = Vector3(mid.x, h, mid.y) + Vector3(dir.y, 0, -dir.x) * 0.1
		rail.rotation.y = yaw
		add_child(rail)


# ---------- audio ----------

func _loop(path: String, db: float) -> AudioStreamPlayer:
	var s: AudioStreamWAV = load(path)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = int(s.get_length() * s.mix_rate)
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = db
	p.autoplay = true
	add_child(p)
	return p


func _audio() -> void:
	_loop("res://sounds/wind.wav", -10.0)
	crickets = _loop("res://sounds/crickets.wav", -60.0)
	var birds: AudioStreamOggVorbis = load("res://sounds/prairie.ogg")  # recorded prairie: birds and breeze
	birds.loop = true
	prairie = AudioStreamPlayer.new()
	prairie.stream = birds
	prairie.autoplay = true
	add_child(prairie)
