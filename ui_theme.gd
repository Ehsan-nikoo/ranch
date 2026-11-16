## Wooden plank buttons with straw around the edges (art from tools/make_ui.py), set on the window
## so every Button in the game picks it up.
class_name UiTheme


## Installs the theme and Persian font on the default theme. CanvasLayers cut the window theme
## chain, so the default theme is the one place every Control falls back to.
static func apply() -> void:
	var base := ThemeDB.get_default_theme()
	base.merge_with(make())
	base.default_font = load("res://ui/fonts/Vazirmatn-Bold.ttf")


## Number with Persian digits.
static func fa(n: Variant) -> String:
	var s := str(n)
	for d in 10:
		s = s.replace(str(d), "۰۱۲۳۴۵۶۷۸۹"[d])
	return s


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
		sb.content_margin_left = 34.0
		sb.content_margin_right = 34.0
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
