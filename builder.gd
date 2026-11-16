## Build mode: pick a building, pan the camera so its ghost sits where you want it, rotate, place.
## The ghost follows the screen center, so placing never fights the pan/zoom gestures.
class_name Builder
extends CanvasLayer

var CATALOG := [["Barn", Barn, 3000], ["House", RanchHouse, 2500], ["Silo", Silo, 1500], ["Windmill", Windmill, 800]]
const BOUNDS := Rect2(-62, -62, 124, 124)

var money := 6000
var rig: CameraRig
var world: Node3D
var occupied: Array[Rect2] = []
var on_placed: Callable  # (world footprint) -> void

var ghost: Building
var _cost := 0
var _valid := false
var _marker_mat := StandardMaterial3D.new()
var _money := Label.new()
var _build_btn := Button.new()
var _menu := HBoxContainer.new()
var _place_bar := HBoxContainer.new()
var _place_btn := Button.new()
var _items: Array[Button] = []


func _ready() -> void:
	_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_money.anchor_left = 1.0
	_money.anchor_right = 1.0
	_money.offset_left = -360
	_money.offset_right = -24
	_money.offset_top = 16
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_money.add_theme_font_size_override("font_size", 34)
	_money.add_theme_constant_override("outline_size", 8)
	_money.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_money.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	add_child(_money)

	for bar in [_menu, _place_bar]:
		bar.anchor_top = 1.0
		bar.anchor_bottom = 1.0
		bar.offset_left = 24
		bar.offset_top = -122
		bar.offset_bottom = -12
		bar.add_theme_constant_override("separation", 12)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)

	_menu.add_child(_button(_build_btn, "Build", _toggle_menu, "build"))
	for i in CATALOG.size():
		var n: String = CATALOG[i][0]
		var b := _button(Button.new(), "%s  $%d" % [n, CATALOG[i][2]], choose.bind(i), n.to_lower())
		b.visible = false
		_items.append(b)
		_menu.add_child(b)
	_place_bar.add_child(_button(Button.new(), "Rotate", rotate_ghost, "rotate"))
	_place_bar.add_child(_button(Button.new(), "Cancel", cancel, "cancel"))
	_place_bar.add_child(_button(_place_btn, "Place", place, "place"))
	_place_bar.visible = false
	_refresh()


func _button(b: Button, text: String, cb: Callable, icon: String) -> Button:
	b.text = text
	b.icon = load("res://ui/icons/%s.png" % icon)
	b.custom_minimum_size = Vector2(190, 104)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(cb)
	return b


func _toggle_menu() -> void:
	var open := not _items[0].visible
	for b in _items:
		b.visible = open
	_build_btn.text = "Close" if open else "Build"
	_refresh()


func _refresh() -> void:
	_money.text = "$ %d" % money
	for i in _items.size():
		_items[i].disabled = money < CATALOG[i][2]


func choose(i: int) -> void:
	_cost = CATALOG[i][2]
	ghost = CATALOG[i][1].new()
	ghost.position = _snapped(rig.target)
	world.add_child(ghost)
	# marker added after the building built itself, so MeshMerge can't swallow it
	var f := ghost._foot()
	var pm := PlaneMesh.new()
	pm.size = f.size
	var marker := MeshInstance3D.new()
	marker.name = "Marker"
	marker.mesh = pm
	marker.material_override = _marker_mat
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.position = Vector3(f.get_center().x, 0.06, f.get_center().y)
	ghost.add_child(marker)
	_menu.visible = false
	_place_bar.visible = true
	for b in _items:  # leave the menu collapsed for when placement ends
		b.visible = false
	_build_btn.text = "Build"


func rotate_ghost() -> void:
	ghost.rotation_degrees.y = fmod(ghost.rotation_degrees.y + 90.0, 360.0)


func cancel() -> void:
	ghost.queue_free()
	_end()


func place() -> void:
	if not _valid:
		return
	var r := ghost.world_footprint()
	money -= _cost
	occupied.append(r)
	ghost.get_node("Marker").queue_free()
	on_placed.call(r)
	_end()


func _end() -> void:
	ghost = null
	_place_bar.visible = false
	_menu.visible = true
	_refresh()


func _snapped(p: Vector3) -> Vector3:
	return Vector3(roundf(p.x), 0, roundf(p.z))


func _process(_delta: float) -> void:
	if ghost == null:
		return
	ghost.position = _snapped(rig.target)
	var r := ghost.world_footprint()
	_valid = money >= _cost and BOUNDS.encloses(r) and not occupied.any(func(o): return o.intersects(r))
	_marker_mat.albedo_color = Color(0.3, 0.95, 0.4, 0.38) if _valid else Color(1.0, 0.25, 0.2, 0.45)
	_place_btn.disabled = not _valid
