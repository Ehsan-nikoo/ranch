## Top of the screen: the date plank, and the settings button (top left) with its board:
## picture quality, grass, music and sounds, kept in user://settings.cfg between runs.
## The test overlay (FPS, frame cost, a time-speed button) is hidden from players: tap the settings
## board's title five times in a row to show or hide it (or start with `-- --dev=1`).
class_name Hud
extends CanvasLayer

const SPEEDS := [1.0, 10.0, 60.0]
# name, 3D render scale, shadows (0 off, 1 cheap, 2 full), share of grass drawn, glow, MSAA
const QUALITY := [
	["بالا", 0.9, 2, 1.0, true, Viewport.MSAA_2X],
	["متوسط", 0.75, 1, 0.55, false, Viewport.MSAA_DISABLED],
	["پایین", 0.6, 0, 0.3, false, Viewport.MSAA_DISABLED],
]
const CFG := "user://settings.cfg"

var day: DayCycle
var weather: Weather
var herd: Herd
var grass: Array[MultiMesh] = []
var grass_nodes: Array[Node3D] = []
var sfx: Sfx
var _label := Label.new()
var _date: Label
var _dev := Control.new()          # the test overlay
var _speed_btn := Button.new()
var _panel: PanelContainer
var _dim: ColorRect
var _quality_btns: Array[Button] = []
var _grass_btns: Array[Button] = []
var _music_btns: Array[Button] = []
var _sound_btns: Array[Button] = []
var _speed := 0
var _quality := 1
var _grass_on := true
var _music_on := true
var _sound_on := true
var _taps := 0                     # quick taps on the board's title, toward the test overlay
var _tap_t := 0.0
var _tick := 0.0


func _ready() -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var date_box := UiTheme.plank(24, Control.PRESET_CENTER_TOP)
	date_box.offset_top = 8
	_date = date_box.get_child(0)
	_date.custom_minimum_size.x = 440  # fixed width: the plank doesn't twitch as the clock ticks
	add_child(date_box)

	var gear := _button("تنظیمات", toggle, "gear")
	gear.position = Vector2(12, 8)
	add_child(gear)

	# test overlay: the speed button next to the settings button, frame numbers under them
	_dev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dev.visible = false
	add_child(_dev)
	_label.position = Vector2(16, 116)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_dev.add_child(_label)
	_speed_btn.custom_minimum_size = Vector2(190, 84)
	_speed_btn.add_theme_font_size_override("font_size", 24)
	_speed_btn.position = Vector2(206, 18)
	_speed_btn.pressed.connect(func(): _set_speed(_speed + 1))
	_dev.add_child(_speed_btn)

	_build_board()
	_load()
	_set_speed(0)
	_set_quality(_quality)
	_set_grass(_grass_on)
	_set_music(_music_on)
	if sfx and not sfx.is_node_ready():  # the tune starts playing in its _ready: stop it after that
		sfx.ready.connect(func(): _set_music(_music_on), CONNECT_ONE_SHOT)
	_set_sound(_sound_on)
	_set_dev(_dev.visible or OS.get_cmdline_user_args().has("--dev=1"))
	# sounds that start later (a cow's moo, the rain) go on the Sounds bus too
	get_tree().node_added.connect(_route)
	for n in get_tree().root.find_children("*", "AudioStreamPlayer", true, false) + get_tree().root.find_children("*", "AudioStreamPlayer3D", true, false):
		_route(n)


func _button(text: String, cb: Callable, icon: String) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = load("res://ui/icons/%s.png" % icon) if icon != "" else null
	b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.custom_minimum_size = Vector2(190, 104)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(cb)
	return b


## One line of the board: the setting's name on the right, its choices to the left of it.
## Choices are given right to left, the way they're read.
func _choice_row(col: VBoxContainer, title: String, names: Array, pick: Callable) -> Array[Button]:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var btns: Array[Button] = []
	for i in range(names.size() - 1, -1, -1):
		var b := Button.new()
		b.text = names[i]
		b.custom_minimum_size = Vector2(180, 90)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(pick.bind(i))
		row.add_child(b)
		btns.push_front(b)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.custom_minimum_size.x = 40
	row.add_child(gap)
	var l := UiTheme.label(title, 30)
	l.custom_minimum_size.x = 260
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(l)
	return btns


## The picked choice stands out: bright with a tick; the others fade back.
static func _mark(btns: Array[Button], picked: int) -> void:
	for i in btns.size():
		var b := btns[i]
		var on := i == picked
		b.text = ("✓ " if on else "") + b.text.trim_prefix("✓ ")
		b.modulate = Color.WHITE if on else Color(1, 1, 1, 0.5)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			if on:
				b.add_theme_color_override(c, Color(0.12, 0.36, 0.06))
			else:
				b.remove_theme_color_override(c)


func _build_board() -> void:
	var over := CanvasLayer.new()
	over.layer = 3  # the board opens over the bottom bar and the other boards
	add_child(over)
	_dim = UiTheme.dim(toggle)
	_panel = UiTheme.board()
	over.add_child(_dim)
	over.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_panel.add_child(col)
	var close := _button("بستن", toggle, "cancel")
	var head := UiTheme.header("تنظیمات", close)
	var title: Label = head.get_child(2)
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.gui_input.connect(_title_tap)
	col.add_child(head)
	_quality_btns = _choice_row(col, "کیفیت تصویر", ["بالا", "متوسط", "پایین"], _pick.bind(_set_quality, false))
	_grass_btns = _choice_row(col, "علف‌ها", ["روشن", "خاموش"], _pick.bind(_set_grass, true))
	_music_btns = _choice_row(col, "آهنگ", ["روشن", "خاموش"], _pick.bind(_set_music, true))
	_sound_btns = _choice_row(col, "صداها", ["روشن", "خاموش"], _pick.bind(_set_sound, true))
	var tip := UiTheme.label("اگه بازی رو گوشیت کند بود، کیفیت رو پایین بیار یا علف‌ها رو خاموش کن", 22, Color(0.32, 0.18, 0.08))
	col.add_child(tip)


## A choice on the board: `on_off` rows pass "on" (the first choice) instead of the index.
func _pick(i: int, apply: Callable, on_off: bool) -> void:
	apply.call(i == 0 if on_off else i)
	_store()


func toggle() -> void:
	_panel.visible = not _panel.visible
	_dim.visible = _panel.visible
	_taps = 0


func _title_tap(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed or e is InputEventScreenTouch and e.pressed):
		return
	if e is InputEventMouseButton and e.button_index != MOUSE_BUTTON_LEFT:
		return
	_taps = _taps + 1 if _tap_t > 0.0 else 1
	_tap_t = 1.2
	if _taps >= 5:
		_taps = 0
		_set_dev(not _dev.visible)
		_store()


func _set_dev(on: bool) -> void:
	_dev.visible = on
	if not on:
		_set_speed(0)  # a player never stays stuck on fast time


func _set_speed(i: int) -> void:
	_speed = i % SPEEDS.size()
	day.speed = SPEEDS[_speed]
	_speed_btn.text = "زمان ×%s" % UiTheme.fa(int(SPEEDS[_speed]))


func _set_quality(i: int) -> void:
	_quality = clampi(i, 0, QUALITY.size() - 1)
	var q: Array = QUALITY[_quality]
	var vp := get_viewport()
	vp.scaling_3d_scale = q[1]
	vp.msaa_3d = q[5]
	day.light.shadow_enabled = q[2] > 0
	day.light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if q[2] == 2 else DirectionalLight3D.SHADOW_ORTHOGONAL
	# distance is measured from the camera, which sits ~50 m out, so it must reach past the ranch
	day.light.directional_shadow_max_distance = 90.0
	RenderingServer.directional_shadow_atlas_set_size(2048, q[2] == 2)
	day.env.glow_enabled = q[4]
	for mm in grass:
		mm.visible_instance_count = int(mm.instance_count * q[3])
	if weather:
		weather.detail = q[3]  # thinner rain and snow on a slow phone
	_mark(_quality_btns, _quality)


func _set_grass(on: bool) -> void:
	_grass_on = on
	for n in grass_nodes:
		n.visible = on
	_mark(_grass_btns, 0 if on else 1)


func _set_music(on: bool) -> void:
	_music_on = on
	if sfx and sfx.is_node_ready():  # stopped, not paused: a pause isn't kept by a player that hasn't started
		if not on:
			sfx.music.stop()
		elif not sfx.music.playing:
			sfx.music.play()
	_mark(_music_btns, 0 if on else 1)


## Every sound but the music goes through the "Sounds" bus, so the two can be turned off apart.
func _set_sound(on: bool) -> void:
	_sound_on = on
	AudioServer.set_bus_mute(_sound_bus(), not on)
	_mark(_sound_btns, 0 if on else 1)


func _sound_bus() -> int:
	var i := AudioServer.get_bus_index("Sounds")
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "Sounds")
		AudioServer.set_bus_send(i, "Master")
	return i


func _route(n: Node) -> void:
	if (n is AudioStreamPlayer or n is AudioStreamPlayer3D) and not (sfx and n == sfx.music):
		_sound_bus()
		n.bus = "Sounds"


## Settings stay on the phone between games (not in desktop test runs, like the save).
func _load() -> void:
	if not SaveGame.enabled():
		return
	var c := ConfigFile.new()
	if c.load(CFG) != OK:
		return
	_quality = int(c.get_value("game", "quality", 1))
	_grass_on = bool(c.get_value("game", "grass", true))
	_music_on = bool(c.get_value("game", "music", true))
	_sound_on = bool(c.get_value("game", "sounds", true))
	_dev.visible = bool(c.get_value("game", "dev", false))


func _store() -> void:
	if not SaveGame.enabled():
		return
	var c := ConfigFile.new()
	c.set_value("game", "quality", _quality)
	c.set_value("game", "grass", _grass_on)
	c.set_value("game", "music", _music_on)
	c.set_value("game", "sounds", _sound_on)
	c.set_value("game", "dev", _dev.visible)
	c.save(CFG)


func _process(delta: float) -> void:
	_tap_t -= delta
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25  # relabeling every frame costs text shaping on a slow CPU
	var sky: String = "" if weather == null or weather.now == Weather.CLEAR else "   " + Weather.NAMES[weather.now]
	_date.text = "%s   ساعت %s%s" % [day.date_text(), UiTheme.fa("%02d:%02d" % [int(day.hour), int(fmod(day.hour, 1.0) * 60)]), sky]
	UiTheme.fit(_date.get_parent())
	if not _dev.visible:
		return
	var rid := get_viewport().get_viewport_rid()
	# herd = the cattle simulation's own time per frame, which the render CPU number doesn't include
	_label.text = "%d FPS   herd %.1f ms   CPU %.1f ms   GPU %.1f ms   draws %d" % [
		Engine.get_frames_per_second(),
		herd.cost_ms,
		RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu(),
		RenderingServer.viewport_get_measured_render_time_gpu(rid),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
