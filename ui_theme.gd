## Wooden plank buttons with straw around the edges (art from tools/make_ui.py), set on the window
## so every Button in the game picks it up.
class_name UiTheme


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
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		sb.modulate_color = tint[state]
		sb.content_margin_left = 34.0
		sb.content_margin_right = 34.0
		sb.content_margin_top = 26.0 if state == "pressed" else 22.0  # text sinks a little when pressed
		sb.content_margin_bottom = 18.0 if state == "pressed" else 22.0
		t.set_stylebox(state, "Button", sb)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	var cream := Color(1.0, 0.94, 0.8)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", cream)
	t.set_color("font_disabled_color", "Button", Color(0.75, 0.7, 0.62))
	t.set_color("font_outline_color", "Button", Color(0.2, 0.11, 0.04))
	t.set_constant("outline_size", "Button", 7)
	t.set_constant("h_separation", "Button", 8)
	t.set_constant("icon_max_width", "Button", 44)
	return t
