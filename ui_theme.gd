## Wooden plank buttons with straw around the edges (art from tools/make_ui.py), set on the window
## so every Button in the game picks it up.
class_name UiTheme


## Installs the theme and Persian font on the default theme. CanvasLayers cut the window theme
## chain, so the default theme is the one place every Control falls back to.
static func apply() -> void:
	var base := ThemeDB.get_default_theme()
	base.merge_with(make())
	base.default_font = load("res://ui/fonts/Vazirmatn-Bold.ttf")


## Price like 1.65 with Persian digits and decimal sign.
static func fa_price(p: float) -> String:
	return fa("%.2f" % p).replace(".", "٫")


## Number with Persian digits.
static func fa(n: Variant) -> String:
	var s := str(n)
	for d in 10:
		s = s.replace(str(d), "۰۱۲۳۴۵۶۷۸۹"[d])
	return s


const INK := Color(0.24, 0.12, 0.05)


## Centered Persian label in dark "burned into wood" ink.
static func label(text: String, size: int, color := INK) -> Label:
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
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://ui/wood_button.png")
	sb.set_texture_margin_all(38.0)
	# text stays well inside the plank's inner frame line, clear of the straw and the screws
	sb.content_margin_left = 60.0
	sb.content_margin_right = 60.0
	sb.content_margin_top = 26.0
	sb.content_margin_bottom = 26.0
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label("", size)
	l.add_theme_constant_override("line_spacing", -int(size * 0.35))  # Vazirmatn's tall line gap looks loose on a plank
	p.add_child(l)
	p.set_anchors_preset(anchor)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN if anchor == Control.PRESET_TOP_RIGHT else Control.GROW_DIRECTION_BOTH
	return p


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
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://ui/wood_panel.png")
	sb.set_texture_margin_all(72.0)
	sb.content_margin_left = 64.0
	sb.content_margin_right = 64.0
	sb.content_margin_top = 52.0
	sb.content_margin_bottom = 56.0
	p.add_theme_stylebox_override("panel", sb)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.visible = false
	return p


## Full-screen dimmer behind a board; tapping it calls `on_tap` (usually close).
static func dim(on_tap: Callable) -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(0.05, 0.03, 0.01, 0.55)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.visible = false
	d.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed or e is InputEventScreenTouch and e.pressed: on_tap.call())
	return d


## Board header: close button on the left, title on the right.
static func header(title: String, close: Button) -> HBoxContainer:
	var head := HBoxContainer.new()
	head.add_child(close)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	head.add_child(label(title, 44))
	return head


static func make() -> Theme:
	var t := Theme.new()
	var tex: Texture2D = load("res://ui/wood_button.png")
	var tint := {
		normal = Color.WHITE,
		hover = Color(1.08, 1.05, 1.0),
		pressed = Color(0.78, 0.72, 0.66),
		disabled = Color(0.6, 0.57, 0.55, 0.8),
	}
	for state in tint:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.set_texture_margin_all(38.0)  # straw border + plank corner and nails stay unstretched
		# stretch, not tile: tiling the middle would repeat the inner frame line in a visible pattern
		sb.modulate_color = tint[state]
		sb.content_margin_left = 44.0  # button text and icon clear of the plank's frame line
		sb.content_margin_right = 44.0
		sb.content_margin_top = 26.0 if state == "pressed" else 22.0  # text sinks a little when pressed
		sb.content_margin_bottom = 18.0 if state == "pressed" else 22.0
		t.set_stylebox(state, "Button", sb)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	# dark brown letters that look burned into the board, like the reference sign
	var ink := Color(0.24, 0.12, 0.05)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", ink)
	t.set_color("font_disabled_color", "Button", Color(0.35, 0.25, 0.17, 0.7))
	t.set_color("font_outline_color", "Button", Color(1.0, 0.85, 0.6, 0.35))  # faint light edge = engraved
	t.set_constant("outline_size", "Button", 3)
	t.set_constant("h_separation", "Button", 8)
	t.set_constant("icon_max_width", "Button", 62)  # icons carry padding for their drop shadow
	return t
