## Dirt roads the player draws with a finger, free, from the build board. They live in a texture
## over the ranch (RES texels a meter) that the ground shader paints as packed dirt and the grass
## shader clears of tufts. Drawing mode: one finger draws (or rubs out), two fingers zoom and turn;
## holding the finger near the edge of the screen rolls the camera on.
class_name Roads
extends CanvasLayer

const RES := 2.0                            # texels a meter
const SIZE := int(Land.HALF * 2.0 * RES)    # texels a side; the texture covers the whole fenced ranch
const WIDTH := 3.4                          # meters across a road

var rig: CameraRig
var land: Land
var builder: Builder
var save: Callable
var img := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
var texture: ImageTexture
var erasing := false

var _bar := HBoxContainer.new()
var _hint: PanelContainer
var _mode_btn: Button
var _dirty := false
var _finger := Vector2.INF
var _last := Vector3.INF                    # ground under the finger at the last stroke


func _init() -> void:
	texture = ImageTexture.create_from_image(img)


func _ready() -> void:
	layer = 2
	_bar.anchor_left = 0.0
	_bar.anchor_right = 1.0
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_left = 16
	_bar.offset_right = -16
	_bar.offset_top = -122
	_bar.offset_bottom = -12
	_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_bar.add_theme_constant_override("separation", 24)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.visible = false
	add_child(_bar)
	_mode_btn = builder._button(Button.new(), "پاک کن", _toggle_erase, "cancel")
	_bar.add_child(_mode_btn)
	_bar.add_child(builder._button(Button.new(), "تموم", close, "place"))
	_hint = UiTheme.plank(24, Control.PRESET_CENTER_BOTTOM)
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_top = -136
	_hint.offset_bottom = -136
	_hint.visible = false
	add_child(_hint)
	_say()


func is_open() -> bool:
	return _bar.visible


## Drawing mode on: the build bar steps aside and one finger draws.
func open() -> void:
	builder.hide_bar(true)
	_bar.visible = true
	_hint.visible = true
	erasing = false
	_say()
	rig.grab = func(_p: Vector2) -> bool: return true
	rig.drag = _stroke


func close() -> void:
	_bar.visible = false
	_hint.visible = false
	rig.grab = Callable()
	rig.drag = Callable()
	_last = Vector3.INF
	_finger = Vector2.INF
	builder.hide_bar(false)
	if save.is_valid():
		save.call()


func _toggle_erase() -> void:
	erasing = not erasing
	_say()


func _say() -> void:
	(_hint.get_child(0) as Label).text = "با انگشت رو جاده بکش تا پاک بشه" if erasing else "با انگشت رو زمین بکش تا جاده‌ی خاکی درست بشه. مجانیه!"
	_mode_btn.text = "بکش" if erasing else "پاک کن"
	_mode_btn.icon = load("res://ui/icons/%s.png" % ("road" if erasing else "cancel"))


## The finger moved from `a` to `b`: a road (or a rubbed-out patch) along the ground between them.
func _stroke(a: Vector2, b: Vector2) -> void:
	var ga := rig.ground_at(a) if _last == Vector3.INF else _last
	var gb := rig.ground_at(b)
	_finger = b
	if ga == Vector3.INF or gb == Vector3.INF:
		return
	paint(ga, gb, not erasing)
	_last = gb


## Road on (or off) along the straight line from `a` to `b`, on owned land only.
func paint(a: Vector3, b: Vector3, on: bool) -> void:
	var r := WIDTH * 0.5
	var n := maxi(1, ceili(a.distance_to(b) / 0.4))
	for k in n + 1:
		var p := a.lerp(b, float(k) / n)
		if not land.is_open(p):
			continue
		var cx := (p.x + Land.HALF) * RES
		var cy := (p.z + Land.HALF) * RES
		var rr := (r + 0.6) * RES
		for y in range(maxi(0, floori(cy - rr)), mini(SIZE, ceili(cy + rr) + 1)):
			for x in range(maxi(0, floori(cx - rr)), mini(SIZE, ceili(cx + rr) + 1)):
				var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length() / RES
				var v := clampf((r + 0.6 - d) / 1.2, 0.0, 1.0)  # soft shoulder
				var old := img.get_pixel(x, y).r
				var nv := maxf(old, v) if on else minf(old, 1.0 - v)
				if nv != old:
					img.set_pixel(x, y, Color(nv, nv, nv))
					_dirty = true


## How much road there is at a world point, 0..1.
func at(p: Vector3) -> float:
	var x := int((p.x + Land.HALF) * RES)
	var y := int((p.z + Land.HALF) * RES)
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return 0.0
	return img.get_pixel(x, y).r


func _process(delta: float) -> void:
	if _bar.visible and not rig._grabbed:
		_last = Vector3.INF
		_finger = Vector2.INF
	if _bar.visible and rig._grabbed and _finger != Vector2.INF:
		_edge_roll(delta)
	if _dirty:
		_dirty = false
		texture.update(img)


## A finger held near the edge of the screen rolls the camera that way, still drawing under it.
func _edge_roll(delta: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	var edge := Vector2(vp.x * 0.12, vp.y * 0.16)
	var push := Vector2(
		-maxf(0.0, edge.x - _finger.x) / edge.x + maxf(0.0, _finger.x - (vp.x - edge.x)) / edge.x,
		-maxf(0.0, edge.y - _finger.y) / edge.y + maxf(0.0, _finger.y - (vp.y - edge.y)) / edge.y)
	if push == Vector2.ZERO:
		return
	var right := Vector3(cos(rig.yaw), 0, -sin(rig.yaw))
	var fwd := Vector3(sin(rig.yaw), 0, cos(rig.yaw))
	rig.target += (right * push.x + fwd * push.y) * rig.dist * 0.4 * delta
	rig.target.x = clampf(rig.target.x, -Land.HALF, Land.HALF)
	rig.target.z = clampf(rig.target.z, -Land.HALF, Land.HALF)
	_stroke(_finger, _finger)


func to_save() -> String:
	return Marshalls.raw_to_base64(img.get_data().compress(FileAccess.COMPRESSION_GZIP))


func from_save(s: String) -> void:
	if s == "":
		return
	var raw := Marshalls.base64_to_raw(s).decompress(SIZE * SIZE, FileAccess.COMPRESSION_GZIP)
	if raw.size() == SIZE * SIZE:
		img.set_data(SIZE, SIZE, false, Image.FORMAT_L8, raw)
		texture.update(img)
