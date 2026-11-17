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
var progress := Progress.new()
var progress_ui := ProgressUI.new()
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
var mask_img: Image
var builder := Builder.new()
var herd := Herd.new()
const CORRAL := Rect2(-24.5, -6.5, 16, 19)
# starting ranch: building, position, yaw in degrees
var layout := [
	[Barn, Vector3(0, 0, 0), 0.0],
	[RanchHouse, Vector3(-13, 0, 26), 90.0],
	[Windmill, Vector3(17, 0, -5), -30.0],
	[Silo, Vector3(-2, 0, -11), 0.0],
]


func _ready() -> void:
	UiTheme.apply()
	var saved := SaveGame.read()
	day.hour = float(_arg("hour", "17.2"))
	day.day = int(_arg("day", "0"))
	if not saved.is_empty():
		day.day = saved.day
		day.hour = saved.hour
		builder.money = saved.money
		if saved.has("land"):
			land.from_save(saved.land)
		layout = saved.buildings.map(func(b): return [load(b[0]), Vector3(b[1], 0, b[2]), b[3]])
	add_child(day)
	mask_img = (load(TEX + "ground_mask.png") as Texture2D).get_image()
	if mask_img.is_compressed():
		mask_img.decompress()
	herd.init_grass(mask_img)
	add_child(land)
	_ground()
	builder.occupied.append(CORRAL)
	for b in layout:
		var node: Building = b[0].new()
		node.position = b[1]
		node.rotation_degrees.y = b[2]
		add_child(node)
		builder.occupied.append(node.world_footprint())
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
	herd.extra_blocked = [CORRAL]
	herd.extra_blocked.append_array(delivery.blocked_rects())
	builder.occupied.append_array(delivery.blocked_rects())
	add_child(herd)
	delivery.herd = herd
	delivery.day = day
	herd._rescan()
	if saved.is_empty():
		for i in int(_arg("cows", "8")):
			herd.add_cow(herd.free_spot(Vector3(22, 0, 18), 9.0), randf_range(260.0, 520.0))
		for i in int(_arg("calves", "0")):  # test: fresh calves at purchase weight
			herd.add_cow(herd.free_spot(Vector3(22, 0, 18), 9.0), HerdUI.CALF_KG)
		for i in int(_arg("breeders", "0")):  # test: breeding cows and bulls
			herd.add_cow(herd.free_spot(Vector3(22, 0, 18), 9.0), 480.0, Herd.BREEDER)
		for i in int(_arg("bulls", "0")):
			herd.add_cow(herd.free_spot(Vector3(22, 0, 18), 9.0), HerdUI.BULL_KG, Herd.BULL)
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
	add_child(hud)
	builder.rig = rig
	builder.world = self
	builder.on_placed = func(r: Rect2):
		_clear_grass(r)
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
	progress_ui.progress = progress
	progress_ui.builder = builder
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
	if _arg("event", "") != "":  # test: `--event=wolves` shows that event's board
		events.call("_" + _arg("event", ""))
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
	progress.notify = breed_ui.notify
	while true:
		await get_tree().create_timer(4.0).timeout
		var st := [0, 0, 0, 0, 0, 0, 0]
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
				btns[0 if _arg("risky", "") == "" else -1].pressed.emit()
			while workers.capacity() < herd.alive().size() + 5 and workers.hired.size() < workers.slots() and not workers.candidates.is_empty():
				workers.hire(workers.candidates[0])
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
					builder.add_money(-land.price())
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
		print("   hands %d (wages %d, capacity %d)  effects %s" % [workers.hired.size(), workers.wages(), workers.capacity(), events.effects.keys().filter(func(k): return events.active(k))])
		print("   breeders %d (in calf %d)  bulls %d  sick %d  unvaccinated %d" % [herd.of_kind(Herd.BREEDER).size(), preg, herd.of_kind(Herd.BULL).size(), herd.sick_count(), herd.unvaccinated().size()])
		print("d%d %02dh %s  price %.2f  active %d  cows %d  hunger %.2f kg %d  hay %d/%d  shelter %d  money %d  wander/graze/water/drink/idle/tofeed/feed %s" % [
			day.day, int(day.hour), DayCycle.SEASON_NAMES[day.season()], market.price, market.active.size(), cows.size(), h / n, w / n, herd.hay, herd.hay_cap, herd.shelter, builder.money, st])


## Test hook for renders: `--ghost=<catalog index>@x,z` opens placement there, `--place` confirms.
func _test_build() -> void:
	if _arg("menu", "") != "":
		builder._toggle_menu()
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
	rig.snap()


func _on_hour(_h: float) -> void:
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


func _on_day(d: int) -> void:
	if d % DayCycle.DAYS_PER_SEASON == 0:
		herd_ui.notify(SEASON_NEWS[day.season()])
	market.new_day(d)
	workers.new_day(d)
	progress.new_day(d)
	events.new_day(d)
	_save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()  # phone apps get killed in the background without warning


func _save() -> void:
	if not is_node_ready():
		return
	var buildings := []
	for n in get_children():
		if n is Building and not n.has_node("Marker"):
			buildings.append([n.get_script().resource_path, n.position.x, n.position.z, n.rotation_degrees.y])
	SaveGame.write({money = builder.money, day = day.day, hour = day.hour, buildings = buildings, herd = herd.to_save(), market = market.to_save(), workers = workers.to_save(), progress = progress.to_save(), events = events.to_save(), delivery = delivery.to_save(), land = land.to_save()})


# ---------- ground & grass ----------

func _ground() -> void:
	var sm := ground_mat
	sm.shader = load("res://ground.gdshader")
	for p in [["grass_alb", "grass_ground_diff.jpg"], ["grass_nrm", "grass_ground_nor_gl.jpg"],
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
	var hay := StandardMaterial3D.new()
	hay.albedo_color = Color(0.86, 0.68, 0.33)
	hay.roughness = 1.0
	hay.normal_enabled = true
	hay.normal_texture = load(TEX + "grass_ground_nor_gl.jpg")
	hay.uv1_triplanar = true
	hay.albedo_texture = load(TEX + "grass_ground_diff.jpg")
	hay.uv1_scale = Vector3(3, 3, 3)
	# hay bale stack under the lean-to
	var spots := [Vector3(7.2, 0.3, -1.0), Vector3(8.4, 0.3, -1.0), Vector3(7.2, 0.3, 0.0), Vector3(8.4, 0.3, 0.0), Vector3(7.8, 0.9, -0.5)]
	for p in spots:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.15, 0.6, 0.85)
		mi.mesh = bm
		mi.material_override = hay
		mi.position = p
		mi.rotation.y = randf_range(-0.08, 0.08)
		add_child(mi)
	# corral fence on the left
	var wood := fence_mat
	var corners := [Vector2(-9, -6), Vector2(-24, -6), Vector2(-24, 12), Vector2(-9, 12)]
	for i in 3:
		_fence(corners[i], corners[i + 1], wood)
	_fence(Vector2(-9, -6), Vector2(-9, 4), wood)
	# water trough
	var trough := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.9, 0.6, 3.0)
	trough.mesh = tm
	trough.material_override = wood
	trough.position = Vector3(-11.5, 0.3, 2)
	add_child(trough)
	var water := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(0.75, 0.02, 2.85)
	water.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.15, 0.22, 0.25)
	wmat.roughness = 0.05
	water.material_override = wmat
	water.position = Vector3(-11.5, 0.58, 2)
	add_child(water)


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
