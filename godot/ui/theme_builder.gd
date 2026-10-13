class_name SgsTheme
extends RefCounted
## Builds the game's Theme in code: parchment panels, Kenney 9-slice buttons,
## DejaVu fonts. Applied to the root Control of each scene.

const BODY_FONT := "res://ui/fonts/DejaVuSans.ttf"
const TITLE_FONT := "res://ui/fonts/DejaVuSerif-Bold.ttf"

const GOLD := Color(0.93, 0.78, 0.38)
const PARCHMENT := Color(0.96, 0.92, 0.82)
const INK := Color(0.12, 0.09, 0.06)
const PANEL := Color(0.09, 0.06, 0.05, 0.88)

static var _theme: Theme = null


static func get_theme() -> Theme:
	if _theme == null:
		_theme = build()
	return _theme


static func nine(path: String, margin: int = 12) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	return sb


static func flat(bg: Color, border: Color = Color.TRANSPARENT, width: int = 0, radius: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func build() -> Theme:
	var t := Theme.new()
	var body: Font = load(BODY_FONT)
	var title: Font = load(TITLE_FONT)
	t.default_font = body
	t.default_font_size = 22

	# Buttons: Kenney grey by default; "primary" (blue) and "danger" (red) variations.
	for variation in [["Button", "grey"], ["PrimaryButton", "blue"], ["DangerButton", "red"]]:
		var type: String = variation[0]
		var color: String = variation[1]
		if type != "Button":
			t.set_type_variation(type, "Button")
		var normal := nine("res://ui/assets/kenney/button_%s.png" % color)
		var pressed := nine("res://ui/assets/kenney/button_%s_flat.png" % color)
		var hover := nine("res://ui/assets/kenney/button_%s.png" % color)
		hover.modulate_color = Color(1.08, 1.08, 1.0)
		var disabled := nine("res://ui/assets/kenney/button_grey_flat.png")
		disabled.modulate_color = Color(0.6, 0.6, 0.6, 0.8)
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		t.set_color("font_color", type, Color(0.1, 0.08, 0.06) if color == "grey" else Color.WHITE)
		t.set_color("font_hover_color", type, Color(0.1, 0.08, 0.06) if color == "grey" else Color.WHITE)
		t.set_color("font_pressed_color", type, Color(0.1, 0.08, 0.06) if color == "grey" else Color.WHITE)
		t.set_color("font_disabled_color", type, Color(0.35, 0.33, 0.3))
		t.set_font("font", type, title)
		t.set_font_size("font_size", type, 21)

	# Panels
	t.set_stylebox("panel", "PanelContainer", flat(PANEL, GOLD, 2, 12))
	t.set_type_variation("ParchmentPanel", "PanelContainer")
	t.set_stylebox("panel", "ParchmentPanel", flat(PARCHMENT, Color(0.55, 0.42, 0.2), 3, 10))
	t.set_type_variation("SeatPanel", "PanelContainer")
	t.set_stylebox("panel", "SeatPanel", flat(Color(0.13, 0.09, 0.07, 0.92), Color(0.35, 0.28, 0.2), 2, 12))

	# Labels
	t.set_color("font_color", "Label", Color(0.95, 0.93, 0.88))
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", title)
	t.set_font_size("font_size", "TitleLabel", 28)
	t.set_color("font_color", "TitleLabel", GOLD)
	t.set_type_variation("HelpLabel", "Label")
	t.set_font_size("font_size", "HelpLabel", 19)
	t.set_color("font_color", "HelpLabel", Color(0.85, 0.82, 0.72))
	t.set_type_variation("InkLabel", "Label")
	t.set_color("font_color", "InkLabel", INK)
	t.set_type_variation("SmallLabel", "Label")
	t.set_font_size("font_size", "SmallLabel", 17)

	# Inputs
	t.set_stylebox("normal", "LineEdit", flat(Color(0.05, 0.04, 0.03, 0.9), Color(0.4, 0.33, 0.22), 2, 8))
	t.set_stylebox("focus", "LineEdit", flat(Color(0.05, 0.04, 0.03, 0.9), GOLD, 2, 8))
	t.set_color("font_color", "LineEdit", Color(0.95, 0.93, 0.88))
	t.set_stylebox("normal", "RichTextLabel", flat(Color(0, 0, 0, 0.25), Color.TRANSPARENT, 0, 8))
	t.set_font_size("normal_font_size", "RichTextLabel", 18)
	t.set_font_size("bold_font_size", "RichTextLabel", 18)
	t.set_font("bold_font", "RichTextLabel", title)
	t.set_color("default_color", "RichTextLabel", Color(0.9, 0.88, 0.82))
	return t


## Full-screen table background: warm dark lacquer with wood grain.
static func make_background() -> Control:
	var root := Control.new()
	root.name = "Background"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var base := ColorRect.new()
	base.color = Color(0.20, 0.08, 0.06)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(base)
	var noise := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = 0.012
	fn.fractal_octaves = 4
	noise.noise = fn
	noise.width = 512
	noise.height = 512
	noise.seamless = true
	var grain := TextureRect.new()
	grain.texture = noise
	grain.stretch_mode = TextureRect.STRETCH_TILE
	grain.modulate = Color(1, 0.85, 0.6, 0.16)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(grain)
	var vignette := TextureRect.new()
	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0.55))
	grad.gradient = g
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5)
	grad.fill_to = Vector2(1.0, 0.5)
	grad.width = 256
	grad.height = 256
	vignette.texture = grad
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(vignette)
	return root
