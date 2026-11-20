## The look of every board, button and plank, set on the default theme so every Control in the game
## picks it up. Four looks (art from tools/make_skins.py); the player picks one in the settings.
class_name UiTheme

## Each look: its name in the settings, button art and its 9-slice margins (left, top, right,
## bottom), the text inset on a button (sides, top/bottom), board art, its slice margin and text
## inset (sides, top, bottom), the ink on boards, the ink on buttons and planks, that ink's outline,
## and the ink of a picked choice in the settings.
const SKINS := {
	"saddle": {name = "چرم زین", button = "res://ui/skins/saddle/button.png", bslice = [34, 30, 34, 30], bpad = [44, 20],
		panel = "res://ui/skins/saddle/panel.png", pslice = 80, ppad = [72, 64, 66],
		ink = Color(0.2, 0.1, 0.04), text = Color(0.97, 0.89, 0.72), outline = Color(0.12, 0.05, 0.02, 0.7), on = Color(0.72, 1.0, 0.45)},
	"poster": {name = "اعلامیه", button = "res://ui/skins/poster/button.png", bslice = [32, 30, 32, 30], bpad = [44, 20],
		panel = "res://ui/skins/poster/panel.png", pslice = 90, ppad = [72, 64, 66],
		ink = Color(0.17, 0.1, 0.05), text = Color(0.96, 0.88, 0.7), outline = Color(0.1, 0.05, 0.02, 0.7), on = Color(0.72, 1.0, 0.45)},
	"barn": {name = "انبار کهنه", button = "res://ui/skins/barn/button.png", bslice = [34, 30, 34, 30], bpad = [42, 20],
		panel = "res://ui/skins/barn/panel.png", pslice = 112, ppad = [68, 60, 62],
		ink = Color(0.15, 0.09, 0.05), text = Color(0.15, 0.09, 0.05), outline = Color(1.0, 0.92, 0.8, 0.3), on = Color(0.08, 0.34, 0.04)},
	"rope": {name = "طناب", button = "res://ui/skins/rope/button.png", bslice = [32, 32, 32, 32], bpad = [44, 22],
		panel = "res://ui/skins/rope/panel.png", pslice = 84, ppad = [68, 60, 62],
		ink = Color(0.2, 0.1, 0.04), text = Color(0.2, 0.1, 0.04), outline = Color(1.0, 0.88, 0.7, 0.3), on = Color(0.08, 0.34, 0.04)},
}
const LOOK := "saddle"   # a new game's look
static var look := ""    # the look in use; kept while the scene reloads for a new one
static var skin: Dictionary = SKINS[LOOK]


## Installs the theme and Persian font on the default theme. CanvasLayers cut the window theme
## chain, so the default theme is the one place every Control falls back to.
static func apply() -> void:
	if look == "":
		look = LOOK
		if SaveGame.enabled():  # the player's pick, kept with the other settings
			var c := ConfigFile.new()
			if c.load(Hud.CFG) == OK:
				look = str(c.get_value("game", "look", LOOK))
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--skin="):  # test: start in this look
				look = a.get_slice("=", 1)
		if not SKINS.has(look):
			look = LOOK
	skin = SKINS[look]
	INK = skin.ink
	ON_PLANK = skin.text
	var base := ThemeDB.get_default_theme()
	base.merge_with(make())
	base.default_font = load("res://ui/fonts/Vazirmatn-Bold.ttf")
	var tree := Engine.get_main_loop() as SceneTree
	if not tree.node_added.is_connected(_added):
		tree.node_added.connect(_added)
	for b in tree.root.find_children("*", "Button", true, false):
		_added(b)


## Godot puts a button's icon at its edge, far from a short text. Here the icon sits right beside
## the text and the two are centred together: the button's own icon is drawn clear (it still
## keeps its room) and drawn again next to the text.
static func _added(n: Node) -> void:
	if n.get_class() != "Button" or n.has_meta("icon_by_text"):
		return
	var b := n as Button
	b.set_meta("icon_by_text", true)
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color", "icon_disabled_color"]:
		b.add_theme_color_override(c, Color.TRANSPARENT)
	b.draw.connect(_draw_icon.bind(b))
	b.pressed.connect(func(): Sfx.play("click"))


const _STATE := ["normal", "pressed", "hover", "disabled", "hover_pressed"]  # by Button.get_draw_mode()


static func _draw_icon(b: Button) -> void:
	var tex := b.icon
	if tex == null:
		return
	var st := b.get_theme_stylebox(_STATE[b.get_draw_mode()])
	var at := Vector2(st.get_margin(SIDE_LEFT), st.get_margin(SIDE_TOP))
	var room := b.size - at - Vector2(st.get_margin(SIDE_RIGHT), st.get_margin(SIDE_BOTTOM))
	var isz := tex.get_size()
	var most := b.get_theme_constant("icon_max_width")
	if most > 0 and isz.x > most:
		isz *= most / isz.x
	var mid := at.x + room.x * 0.5
	var x := mid - isz.x * 0.5
	if b.text != "":
		var sep := b.get_theme_constant("h_separation")
		var tw := b.get_theme_font("font").get_multiline_string_size(b.text, HORIZONTAL_ALIGNMENT_CENTER, -1, b.get_theme_font_size("font_size")).x
		var group := minf(tw, room.x - isz.x - sep) + sep + isz.x
		var right := (b.icon_alignment == HORIZONTAL_ALIGNMENT_RIGHT) != b.is_layout_rtl()
		x = mid + group * 0.5 - isz.x if right else mid - group * 0.5
	var y := at.y + (room.y - isz.y) * 0.5
	b.draw_texture_rect(tex, Rect2(Vector2(x, y), isz), false, Color(1, 1, 1, 0.4) if b.disabled else Color.WHITE)


## Price like 1.65 with Persian digits and decimal sign.
static func fa_price(p: float) -> String:
	return fa("%.2f" % p).replace(".", "٫")


## Number with Persian digits.
static func fa(n: Variant) -> String:
	var s := str(n)
	for d in 10:
		s = s.replace(str(d), "۰۱۲۳۴۵۶۷۸۹"[d])
	return s


static var INK := Color(0.24, 0.12, 0.05)
static var ON_PLANK := INK  # text on buttons and planks


## Centered Persian label in dark "burned into wood" ink.
static func label(text: String, size: int, color := Color.TRANSPARENT) -> Label:
	if color == Color.TRANSPARENT:
		color = INK
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Small wooden plank (the button art) that grows to fit a centered label: money, notices.
## `anchor` is a Control.LayoutPreset; the plank grows away from that screen edge so it stays on screen.
static func plank(size: int, anchor: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _plank_box())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label("", size, ON_PLANK)
	l.add_theme_color_override("font_outline_color", skin.outline)
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_constant_override("line_spacing", -int(size * 0.35))  # Vazirmatn's tall line gap looks loose on a plank
	p.add_child(l)
	p.set_anchors_preset(anchor)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN if anchor == Control.PRESET_TOP_RIGHT else Control.GROW_DIRECTION_BOTH
	return p


static func _plank_box() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(skin.button)
	_slice(sb, skin.bslice)
	# text stays well inside the plank's inner frame line, clear of the straw and the screws
	sb.content_margin_left = skin.bpad[0] + 16.0
	sb.content_margin_right = skin.bpad[0] + 16.0
	sb.content_margin_top = skin.bpad[1] + 4.0
	sb.content_margin_bottom = skin.bpad[1] + 4.0
	return sb


static func _board_box() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(skin.panel)
	sb.set_texture_margin_all(skin.pslice)
	sb.content_margin_left = skin.ppad[0]
	sb.content_margin_right = skin.ppad[0]
	sb.content_margin_top = skin.ppad[1]
	sb.content_margin_bottom = skin.ppad[2]
	return sb


## Dresses everything already on screen in another look, in place. (Reloading the whole ranch for
## it left some phones on a white screen.) Boards and planks get the new art; text that wore the
## old look's inks gets the new ones; drawn boards are redrawn.
static func restyle(name: String) -> void:
	if not SKINS.has(name) or name == look:
		return
	var was := skin
	look = name
	apply()
	var tree := Engine.get_main_loop() as SceneTree
	var plank_tex: Texture2D = load(was.button)
	var board_tex: Texture2D = load(was.panel)
	var on_keys := ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]
	var on_plank := {}  # labels on a plank: their ink is the buttons' ink, not the boards'
	for n in tree.root.find_children("*", "Control", true, false):
		var c := n as Control
		if c.has_theme_stylebox_override("panel"):
			var sb := c.get_theme_stylebox("panel") as StyleBoxTexture
			if sb and sb.texture == plank_tex:
				c.add_theme_stylebox_override("panel", _plank_box())
				for l in c.find_children("*", "Label", true, false):
					on_plank[l] = true
					_swap_color(l, "font_color", was.text, skin.text)
					_swap_color(l, "font_outline_color", was.outline, skin.outline)
			elif sb and sb.texture == board_tex:
				c.add_theme_stylebox_override("panel", _board_box())
		if c is Label and not on_plank.has(c):
			_swap_color(c, "font_color", was.ink, skin.ink)
		if c is Button:
			for k in on_keys:
				_swap_color(c, k, was.on, skin.on)
		c.queue_redraw()
	tree.root.propagate_notification(Control.NOTIFICATION_THEME_CHANGED)


static func _swap_color(c: Control, key: String, from: Color, to: Color) -> void:
	if c.has_theme_color_override(key) and c.get_theme_color(key).is_equal_approx(from):
		c.add_theme_color_override(key, to)


## Shrinks a plank back to its text after the text changed, keeping its screen edge: reset_size()
## would keep the left edge and push a right-anchored plank off screen.
static func fit(p: Control) -> void:
	if p.grow_horizontal == Control.GROW_DIRECTION_BEGIN:
		p.offset_left = p.offset_right
	else:
		var c := (p.offset_left + p.offset_right) * 0.5
		p.offset_left = c
		p.offset_right = c
	p.offset_bottom = p.offset_top


## Big wooden board centered on screen, hidden until shown.
static func board() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _board_box())
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.visible = false
	return p


## Asks before something that can't be taken back (selling, knocking down, letting a hand go): a small
## board over everything with «نه» and the yes. The yes wakes up a moment late, so a double tap on the
## button that asked can't answer for the player; a tap beside the board is a no.
static func confirm(text: String, yes: String, icon: String, on_yes: Callable) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var layer := CanvasLayer.new()
	layer.layer = 6  # over every board, the tips' arrow too
	var d := dim(layer.queue_free)
	d.visible = true
	layer.add_child(d)
	var p := board()
	p.visible = true
	layer.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)
	p.add_child(col)
	var l := label(text, 28)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 660
	col.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 48)
	col.add_child(row)
	var ok := Button.new()
	var no := Button.new()
	for b in [[ok, yes, icon], [no, "نه", "cancel"]]:
		var btn: Button = b[0]
		btn.text = b[1]
		btn.icon = load("res://ui/icons/%s.png" % b[2])
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		btn.custom_minimum_size = Vector2(250, 96)
		btn.add_theme_font_size_override("font_size", 26)
		row.add_child(btn)  # the yes on the left, «نه» on the right where the eye starts
	ok.disabled = true
	ok.pressed.connect(func():
		layer.queue_free()
		on_yes.call())
	no.pressed.connect(layer.queue_free)
	tree.root.add_child(layer)
	tree.create_timer(0.45).timeout.connect(func(): if is_instance_valid(ok): ok.disabled = false)


## Full-screen dimmer behind a board; tapping it calls `on_tap` (usually close).
static func dim(on_tap: Callable) -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(0.05, 0.03, 0.01, 0.55)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.visible = false
	d.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed or e is InputEventScreenTouch and e.pressed: on_tap.call())
	return d


## Board header: close button on the left, title in the middle.
static func header(title: String, close: Button) -> HBoxContainer:
	var head := HBoxContainer.new()
	head.add_child(close)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	head.add_child(label(title, 44))
	center_head(head)
	return head


## Puts what follows the first stretching gap of a header row in the middle of the row: a matching
## gap after it, then a blank as wide as the buttons before the first gap.
static func center_head(head: HBoxContainer) -> void:
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	var pad := Control.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(pad)
	head.sort_children.connect(func():
		var w := 0.0
		for c: Control in head.get_children():
			if c.size_flags_horizontal & Control.SIZE_EXPAND:
				break
			w += c.size.x + head.get_theme_constant("separation")
		w = maxf(0.0, w - head.get_theme_constant("separation"))
		if absf(pad.custom_minimum_size.x - w) > 0.5:
			pad.custom_minimum_size.x = w)


static func make() -> Theme:
	var t := Theme.new()
	var tex: Texture2D = load(skin.button)
	var tint := {
		normal = Color.WHITE,
		hover = Color(1.08, 1.05, 1.0),
		pressed = Color(0.78, 0.72, 0.66),
		disabled = Color(0.6, 0.57, 0.55, 0.8),
	}
	for state in tint:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		_slice(sb, skin.bslice)  # straw border + plank corner and nails stay unstretched
		# stretch, not tile: tiling the middle would repeat the inner frame line in a visible pattern
		sb.modulate_color = tint[state]
		sb.content_margin_left = skin.bpad[0]  # button text and icon clear of the plank's frame line
		sb.content_margin_right = skin.bpad[0]
		sb.content_margin_top = skin.bpad[1] + (4.0 if state == "pressed" else 0.0)  # text sinks a little when pressed
		sb.content_margin_bottom = skin.bpad[1] - (4.0 if state == "pressed" else 0.0)
		t.set_stylebox(state, "Button", sb)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	# dark brown letters that look burned into the board, like the reference sign
	var ink: Color = skin.text
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", ink)
	t.set_color("font_disabled_color", "Button", Color(ink, 0.55))
	t.set_color("font_outline_color", "Button", skin.outline)  # faint light edge = engraved
	t.set_constant("outline_size", "Button", 3)
	t.set_constant("h_separation", "Button", 8)
	t.set_constant("icon_max_width", "Button", 62)  # icons carry padding for their drop shadow
	return t


static func _slice(sb: StyleBoxTexture, m: Array) -> void:
	sb.texture_margin_left = m[0]
	sb.texture_margin_top = m[1]
	sb.texture_margin_right = m[2]
	sb.texture_margin_bottom = m[3]
