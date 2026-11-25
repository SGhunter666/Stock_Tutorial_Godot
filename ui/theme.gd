## Central visual language. Every screen pulls colors, spacing, pixel fonts and
## 9-slice tactile pixel styles from here so the UI switches cleanly between the
## signature A+B Retro Pixel Hybrid ("pixel"), modern dark ("dark"), and light ("light").
class_name SmaUiTheme
extends RefCounted

const CARD_RADIUS := 10
const GAP := 10

static var BG := Color("#070c17")
static var BG_DEEP := Color("#04070f")
static var PANEL := Color("#111b2e")
static var PANEL_ALT := Color("#1a2945")
static var PANEL_HOVER := Color("#283e66")
static var BORDER := Color("#567da8")
static var TEXT := Color("#f4f8fc")
static var MUTED := Color("#b3cae0")
static var DIM := Color("#85a3bf")
static var ACCENT := Color("#5eead4")
static var ACCENT_DARK := Color("#0f766e")
static var GOLD := Color("#fbbf24")
static var POSITIVE := Color("#4ade80")
static var NEGATIVE := Color("#f87171")
static var WARNING := Color("#fbbf24")
static var INFO := Color("#60a5fa")
static var mode := "pixel"
static var color_scheme := "intl"

## Layout density: 1.0 for the beginner layout, a compact factor for advanced.
static var density := 1.0

static var _pixel_font_10: Font
static var _pixel_font_12: Font


static func is_pixel() -> bool:
	return mode == "pixel"


static func card_radius() -> int:
	return 0 if is_pixel() else CARD_RADIUS


static func set_density(value: float) -> void:
	density = clampf(value, 0.82, 1.0)


static func set_theme_mode(value: String) -> void:
	mode = value if ["pixel", "dark", "light"].has(value) else "dark"
	if mode == "light":
		BG = Color("#f2f6fa")
		BG_DEEP = Color("#ffffff")
		PANEL = Color("#ffffff")
		PANEL_ALT = Color("#eef3f8")
		PANEL_HOVER = Color("#e2eaf2")
		BORDER = Color("#cfdae5")
		TEXT = Color("#16202c")
		MUTED = Color("#4d6073")
		DIM = Color("#5b7085")
		ACCENT = Color("#0d9488")
		ACCENT_DARK = Color("#0f766e")
		GOLD = Color("#b45309")
		WARNING = Color("#b45309")
		INFO = Color("#1d4ed8")
	elif mode == "pixel":
		BG = Color("#070c17")
		BG_DEEP = Color("#04070f")
		PANEL = Color("#111b2e")
		PANEL_ALT = Color("#1a2945")
		PANEL_HOVER = Color("#283e66")
		BORDER = Color("#567da8")
		TEXT = Color("#f4f8fc")
		MUTED = Color("#b3cae0")
		DIM = Color("#85a3bf")
		ACCENT = Color("#5eead4")
		ACCENT_DARK = Color("#0f766e")
		GOLD = Color("#fbbf24")
		WARNING = Color("#fbbf24")
		INFO = Color("#60a5fa")
	else:
		BG = Color("#0a1220")
		BG_DEEP = Color("#070d18")
		PANEL = Color("#111d2e")
		PANEL_ALT = Color("#16263a")
		PANEL_HOVER = Color("#1b3049")
		BORDER = Color("#22384f")
		TEXT = Color("#e7f1f8")
		MUTED = Color("#9bb3c9")
		DIM = Color("#8aa3b8")
		ACCENT = Color("#5eead4")
		ACCENT_DARK = Color("#0f766e")
		GOLD = Color("#fbbf24")
		WARNING = Color("#fbbf24")
		INFO = Color("#60a5fa")
	_apply_semantic_colors()


static func set_color_scheme(value: String) -> void:
	color_scheme = value if ["intl", "cn", "colorblind"].has(value) else "intl"
	_apply_semantic_colors()


static func _apply_semantic_colors() -> void:
	var light := mode == "light"
	match color_scheme:
		"cn":
			POSITIVE = Color("#dc2626") if light else Color("#f87171")
			NEGATIVE = Color("#15803d") if light else Color("#4ade80")
		"colorblind":
			POSITIVE = Color("#1d4ed8") if light else Color("#60a5fa")
			NEGATIVE = Color("#c2410c") if light else Color("#fb923c")
		_:
			POSITIVE = Color("#15803d") if light else Color("#4ade80")
			NEGATIVE = Color("#dc2626") if light else Color("#f87171")


static func _load_pixel_font(res_path: String, sys_fallback: Font) -> Font:
	var file: FontFile = null
	if ResourceLoader.exists(res_path):
		var loaded := load(res_path) as FontFile
		if loaded != null:
			file = loaded.duplicate() as FontFile
	if file == null:
		var raw := FontFile.new()
		if raw.load_dynamic_font(ProjectSettings.globalize_path(res_path)) == OK:
			file = raw
	if file == null:
		return sys_fallback
	file.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	file.hinting = TextServer.HINTING_NONE
	file.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	file.multichannel_signed_distance_field = false
	file.oversampling = 1.0
	file.allow_system_fallback = true
	if sys_fallback != null:
		file.fallbacks = [sys_fallback]
	return file


static func _ensure_pixel_fonts() -> void:
	if _pixel_font_12 != null and _pixel_font_10 != null:
		return
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Microsoft YaHei",
		"Noto Sans CJK SC", "Apple Symbols", "sans-serif",
	])
	sys.allow_system_fallback = true
	sys.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	_pixel_font_10 = _load_pixel_font(
		"res://assets/fonts/fusion-pixel-10px-proportional-zh_hans.ttf", sys)
	_pixel_font_12 = _load_pixel_font(
		"res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf", sys)


static func pixel_font_10() -> Font:
	_ensure_pixel_fonts()
	return _pixel_font_10


static func pixel_font_12() -> Font:
	_ensure_pixel_fonts()
	return _pixel_font_12


## Maps any UI font size to an exact integer multiple (1x, 2x, 3x) of our 10px
## and 12px bitmap pixel fonts so strokes never suffer fractional distortion.
static func pixel_snap_font(raw_size: int) -> Dictionary:
	_ensure_pixel_fonts()
	if raw_size <= 10:
		return {"font": _pixel_font_10, "size": 10}
	if raw_size <= 17:
		return {"font": _pixel_font_12, "size": 12}
	if raw_size <= 30:
		return {"font": _pixel_font_12, "size": 24}
	return {"font": _pixel_font_12, "size": 36}


static func _box(color: Color, border_color: Color = Color(0, 0, 0, 0),
		radius: int = CARD_RADIUS, margin: int = 10) -> StyleBoxFlat:
	if border_color.a <= 0.0:
		border_color = BORDER
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	if is_pixel():
		style.anti_aliasing = false
		style.set_border_width_all(2)
		style.set_corner_radius_all(0)
		style.shadow_color = Color(0.01, 0.02, 0.05, 0.85)
		style.shadow_size = 0
		style.shadow_offset = Vector2(3, 3)
	else:
		style.set_border_width_all(1)
		style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


static func panel_style(bg: Color = Color(0, 0, 0, 0), border_hi: Color = Color(0, 0, 0, 0),
		margin: int = 10, rivets: bool = true) -> StyleBox:
	var fill := PANEL if bg.a <= 0.0 else bg
	var hi := BORDER if border_hi.a <= 0.0 else border_hi
	if is_pixel():
		return SmaPixelArt.card_box(fill, hi, fill.darkened(0.45), margin, rivets)
	return _box(fill, hi, CARD_RADIUS, margin)


static func readout_style(margin_h: int = 10, margin_v: int = 5,
		rim: Color = Color(0, 0, 0, 0)) -> StyleBox:
	var r := BORDER if rim.a <= 0.0 else rim
	if is_pixel():
		return SmaPixelArt.readout_box(BG_DEEP, r, margin_h, margin_v)
	var flat := _box(BG_DEEP, r, 8, margin_v)
	flat.content_margin_left = margin_h
	flat.content_margin_right = margin_h
	return flat


static func beveled_button_box(bg: Color, border: Color, margin: int = 9,
		depressed: bool = false) -> StyleBoxFlat:
	if not is_pixel():
		return _box(bg, border, 8, margin)
	var style := StyleBoxFlat.new()
	style.anti_aliasing = false
	style.bg_color = bg
	style.border_color = border
	style.border_blend = false
	style.set_corner_radius_all(0)
	if depressed:
		style.border_width_top = 3
		style.border_width_left = 3
		style.border_width_bottom = 1
		style.border_width_right = 1
		style.content_margin_left = margin + 1
		style.content_margin_top = margin + 1
		style.content_margin_right = maxi(2, margin - 1)
		style.content_margin_bottom = maxi(2, margin - 1)
	else:
		style.border_width_top = 2
		style.border_width_left = 2
		style.border_width_bottom = 3
		style.border_width_right = 3
		style.set_content_margin_all(margin)
		style.shadow_color = Color(0.01, 0.02, 0.05, 0.9)
		style.shadow_size = 0
		style.shadow_offset = Vector2(2, 2)
	return style


## Applies chunky 3D arcade pixel button styling ("primary", "buy", "sell", "amber", "slate").
static func apply_arcade_button(node: Button, kind: String = "primary", margin: int = 8) -> void:
	if not is_pixel():
		var col := ACCENT_DARK
		var hi_col := ACCENT
		if kind == "buy":
			col = POSITIVE.darkened(0.28)
			hi_col = POSITIVE
		elif kind == "sell":
			col = NEGATIVE.darkened(0.28)
			hi_col = NEGATIVE
		elif kind == "amber":
			col = Color("#b45309")
			hi_col = WARNING
		node.add_theme_stylebox_override("normal", _box(col, hi_col, 8, margin))
		node.add_theme_stylebox_override("hover", _box(hi_col, Color.WHITE, 8, margin))
		node.add_theme_stylebox_override("pressed", _box(col.darkened(0.2), hi_col, 8, margin))
		node.add_theme_color_override("font_color", Color.WHITE)
		node.add_theme_color_override("font_hover_color",
			TEXT if mode == "light" else BG_DEEP)
		node.add_theme_color_override("font_pressed_color", Color.WHITE)
		return

	var face := Color("#14856e")
	var top_hi := Color("#6ee7b7")
	var ledge := Color("#064e3b")
	var hover_face := Color("#10b981")
	var text_col := Color("#ffffff")
	match kind:
		"buy":
			var pos_base := POSITIVE
			face = pos_base.darkened(0.18)
			hover_face = pos_base
			top_hi = pos_base.lightened(0.38)
			ledge = pos_base.darkened(0.56)
		"sell":
			var neg_base := NEGATIVE
			face = neg_base.darkened(0.14)
			hover_face = neg_base
			top_hi = neg_base.lightened(0.35)
			ledge = neg_base.darkened(0.55)
		"amber":
			face = Color("#d97706")
			hover_face = Color("#f59e0b")
			top_hi = Color("#fef08a")
			ledge = Color("#78350f")
		"slate":
			face = Color("#243756")
			hover_face = Color("#314b73")
			top_hi = Color("#749bc7")
			ledge = Color("#0c1526")
		_:
			face = Color("#12826c")
			hover_face = Color("#16a388")
			top_hi = Color("#6ee7b7")
			ledge = Color("#064238")

	node.add_theme_stylebox_override("normal", SmaPixelArt.button_box(face, top_hi, ledge, margin, false))
	node.add_theme_stylebox_override("hover", SmaPixelArt.button_box(hover_face, Color.WHITE, ledge, margin, false))
	node.add_theme_stylebox_override("pressed", SmaPixelArt.button_box(face.darkened(0.12), top_hi, ledge, margin, true))
	node.add_theme_color_override("font_color", text_col)
	node.add_theme_color_override("font_hover_color", Color.WHITE)
	node.add_theme_color_override("font_pressed_color", Color.WHITE)
	node.add_theme_color_override("font_outline_color", Color("#04070e"))
	node.add_theme_constant_override("outline_size", 4)


static func build() -> Theme:
	var theme := Theme.new()
	if is_pixel():
		_ensure_pixel_fonts()
		theme.default_font = _pixel_font_12
		theme.default_font_size = 12
	else:
		var fallback := SystemFont.new()
		fallback.font_names = PackedStringArray([
			"PingFang SC", "Hiragino Sans GB", "Microsoft YaHei",
			"Noto Sans CJK SC", "Source Han Sans SC", "Arial Unicode MS", "sans-serif",
		])
		fallback.allow_system_fallback = true
		fallback.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		var font: Font = fallback
		if OS.get_name() == "macOS":
			for candidate in ["/System/Library/Fonts/STHeiti Medium.ttc",
					"/System/Library/Fonts/STHeiti Light.ttc",
					"/System/Library/Fonts/Supplemental/Songti.ttc"]:
				var file := FontFile.new()
				var err := file.load_dynamic_font(candidate)
				if err == OK and file.get_font_name() != "" and file.has_char(0x8FDC):
					file.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
					file.fallbacks.append(fallback)
					font = file
					break
		theme.default_font = font
		theme.default_font_size = 13

	theme.set_color("font_color", "Label", TEXT)
	if is_pixel():
		theme.set_color("font_shadow_color", "Label", Color(0.01, 0.02, 0.05, 0.92))
		theme.set_constant("shadow_offset_x", "Label", 1)
		theme.set_constant("shadow_offset_y", "Label", 1)
	else:
		theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))

	theme.set_stylebox("panel", "PanelContainer", panel_style(PANEL, BORDER, 10, true))
	theme.set_stylebox("panel", "Panel", panel_style(PANEL, BORDER, 10, true))

	if is_pixel():
		var btn_norm := SmaPixelArt.button_box(Color("#233654"), Color("#6d93be"), Color("#0c1526"), 7, false)
		var btn_hov := SmaPixelArt.button_box(Color("#304970"), Color("#93c5fd"), Color("#122038"), 7, false)
		var btn_press := SmaPixelArt.button_box(Color("#0f766e"), Color("#5eead4"), Color("#053330"), 7, true)
		var btn_dis := SmaPixelArt.button_box(Color("#131d2f"), Color("#2c3e58"), Color("#080e19"), 7, false)
		theme.set_stylebox("normal", "Button", btn_norm)
		theme.set_stylebox("hover", "Button", btn_hov)
		theme.set_stylebox("pressed", "Button", btn_press)
		theme.set_stylebox("hover_pressed", "Button", btn_press)
		theme.set_stylebox("disabled", "Button", btn_dis)
		theme.set_stylebox("normal", "OptionButton", btn_norm)
		theme.set_stylebox("hover", "OptionButton", btn_hov)
		theme.set_stylebox("pressed", "OptionButton", btn_press)
		theme.set_stylebox("normal", "MenuButton", btn_norm)
		theme.set_stylebox("hover", "MenuButton", btn_hov)
		theme.set_stylebox("pressed", "MenuButton", btn_press)
		theme.set_color("font_outline_color", "Button", Color("#04070e"))
		theme.set_constant("outline_size", "Button", 2)
		theme.set_font_size("font_size", "Button", 12)
		theme.set_font_size("font_size", "OptionButton", 12)
		theme.set_font_size("font_size", "LineEdit", 12)
		theme.set_font_size("font_size", "PopupMenu", 12)
		theme.set_font_size("font_size", "CheckBox", 12)
	else:
		theme.set_stylebox("normal", "Button", beveled_button_box(PANEL_ALT, BORDER, 8, false))
		theme.set_stylebox("hover", "Button", beveled_button_box(PANEL_HOVER, ACCENT, 8, false))
		theme.set_stylebox("pressed", "Button", beveled_button_box(ACCENT_DARK, ACCENT, 8, true))
		theme.set_stylebox("disabled", "Button", _box(PANEL, DIM, 8, 8))
		theme.set_stylebox("normal", "OptionButton", beveled_button_box(PANEL_ALT, BORDER, 8, false))
		theme.set_stylebox("hover", "OptionButton", beveled_button_box(PANEL_HOVER, ACCENT, 8, false))
		theme.set_stylebox("pressed", "OptionButton", beveled_button_box(ACCENT_DARK, ACCENT, 8, true))
		theme.set_font_size("font_size", "Button", 13)
		theme.set_font_size("font_size", "OptionButton", 13)
		theme.set_font_size("font_size", "LineEdit", 13)
		theme.set_font_size("font_size", "PopupMenu", 13)
		theme.set_font_size("font_size", "CheckBox", 13)

	var focus := _box(Color.TRANSPARENT, ACCENT, 8, 0)
	focus.draw_center = false
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_stylebox("focus", "OptionButton", focus)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", GOLD if is_pixel() else Color.WHITE)
	theme.set_color("font_hover_pressed_color", "Button", GOLD if is_pixel() else Color.WHITE)
	theme.set_color("font_disabled_color", "Button", DIM)

	theme.set_stylebox("normal", "LineEdit", readout_style(8, 6, BORDER))
	theme.set_stylebox("focus", "LineEdit", readout_style(8, 6, ACCENT))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", DIM)

	theme.set_color("font_color", "OptionButton", TEXT)

	theme.set_stylebox("panel", "PopupMenu", panel_style(PANEL_ALT, ACCENT if is_pixel() else BORDER, 6, false))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", GOLD if is_pixel() else Color.WHITE)

	theme.set_stylebox("scroll", "VScrollBar", _box(BG_DEEP, BORDER, 6, 0))
	theme.set_stylebox("grabber", "VScrollBar", _box(PANEL_HOVER, BORDER, 6, 0))
	theme.set_stylebox("grabber_highlight", "VScrollBar", _box(ACCENT_DARK, ACCENT, 6, 0))
	theme.set_stylebox("grabber_pressed", "VScrollBar", _box(ACCENT, ACCENT, 6, 0))

	theme.set_stylebox("normal", "SpinBox", readout_style(6, 5, BORDER))
	theme.set_color("font_color", "SpinBox", TEXT)

	var pb_bg := _box(BG_DEEP, BORDER, 4, 0)
	var pb_fill := _box(POSITIVE if is_pixel() else ACCENT_DARK, ACCENT, 4, 0)
	theme.set_stylebox("background", "ProgressBar", pb_bg)
	theme.set_stylebox("fill", "ProgressBar", pb_fill)

	theme.set_color("font_color", "CheckBox", TEXT)
	theme.set_color("font_pressed_color", "CheckBox", ACCENT)

	return theme
