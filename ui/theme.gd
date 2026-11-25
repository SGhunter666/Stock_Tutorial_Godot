## Central 16-bit pixel visual language. Every mode in the game is 100% pixel art
## (Fusion Pixel bitmap fonts on exact integer multiples, nearest-neighbor 9-slice
## notched pixel frames with hard 4px drop shadows, pixel icons & arcade controls),
## offering three distinct pixel palettes:
##   - "pixel": Kairosoft Oak Desk × CRT Terminal Hybrid (Style A+B default)
##   - "light": Kairosoft Warm Parchment Studio (Style B warm cream)
##   - "dark":  PC-98 Midnight Neon Terminal (Style A cyber CRT)
class_name SmaUiTheme
extends RefCounted

const CARD_RADIUS := 0
const GAP := 10

static var BG := Color("#4a2d1b")
static var BG_DEEP := Color("#060c17")
static var CRT_BG := Color("#060d18")
static var PANEL := Color("#152238")
static var PANEL_ALT := Color("#1f3252")
static var PANEL_HOVER := Color("#2c4670")
static var BORDER := Color("#7db0e0")
static var TEXT := Color("#f4f8fc")
static var MUTED := Color("#bfd4ea")
static var DIM := Color("#8caac9")
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
	return true


static func card_radius() -> int:
	return 0


static func set_density(value: float) -> void:
	density = clampf(value, 0.82, 1.0)


static func set_theme_mode(value: String) -> void:
	mode = value if ["pixel", "dark", "light"].has(value) else "dark"
	CRT_BG = Color("#060d18")
	if mode == "light":
		# Style B: Kairosoft Warm Cream Parchment Pixel Palette
		BG = Color("#e8d3ab")
		BG_DEEP = Color("#fffaf0")
		PANEL = Color("#fcf4e1")
		PANEL_ALT = Color("#f2e2be")
		PANEL_HOVER = Color("#e6cfa0")
		BORDER = Color("#b58450")
		TEXT = Color("#21160e")
		MUTED = Color("#573e2c")
		DIM = Color("#785a43")
		ACCENT = Color("#0d9488")
		ACCENT_DARK = Color("#0f766e")
		GOLD = Color("#b45309")
		WARNING = Color("#b45309")
		INFO = Color("#1d4ed8")
	elif mode == "pixel":
		# Style A+B Hybrid: Warm Kairosoft Oak Desk + Crisp Steel-Indigo Pixel Windows
		BG = Color("#4a2d1b")
		BG_DEEP = Color("#060c17")
		PANEL = Color("#152238")
		PANEL_ALT = Color("#1f3252")
		PANEL_HOVER = Color("#2c4670")
		BORDER = Color("#7db0e0")
		TEXT = Color("#f4f8fc")
		MUTED = Color("#bfd4ea")
		DIM = Color("#8caac9")
		ACCENT = Color("#5eead4")
		ACCENT_DARK = Color("#0f766e")
		GOLD = Color("#fbbf24")
		WARNING = Color("#fbbf24")
		INFO = Color("#60a5fa")
	else:
		# Style A: PC-98 Midnight Cyber-Indigo Pixel Terminal
		BG = Color("#080d1a")
		BG_DEEP = Color("#050811")
		PANEL = Color("#10192e")
		PANEL_ALT = Color("#192847")
		PANEL_HOVER = Color("#253b66")
		BORDER = Color("#5c87bd")
		TEXT = Color("#f2f7fd")
		MUTED = Color("#b0c8e2")
		DIM = Color("#82a0bf")
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
## and 12px bitmap pixel fonts so strokes never suffer fractional distortion:
##   10px (1x of 10), 12px (1x of 12), 20px (2x of 10), 24px (2x of 12),
##   30px (3x of 10), 36px (3x of 12).
static func pixel_snap_font(raw_size: int) -> Dictionary:
	_ensure_pixel_fonts()
	if raw_size <= 10:
		return {"font": _pixel_font_10, "size": 10}
	if raw_size <= 14:
		return {"font": _pixel_font_12, "size": 12}
	if raw_size <= 17:
		return {"font": _pixel_font_10, "size": 20}
	if raw_size <= 27:
		return {"font": _pixel_font_12, "size": 24}
	if raw_size <= 32:
		return {"font": _pixel_font_10, "size": 30}
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
	var sh := fill.darkened(0.24 if mode == "light" else 0.45)
	if mode == "light" and border_hi.a <= 0.0:
		hi = Color("#fffdf7")
		sh = Color("#cfb484")
	return SmaPixelArt.card_box(fill, hi, sh, margin, rivets)


static func readout_style(margin_h: int = 10, margin_v: int = 5,
		rim: Color = Color(0, 0, 0, 0)) -> StyleBox:
	var r := BORDER if rim.a <= 0.0 else rim
	return SmaPixelArt.readout_box(BG_DEEP, r, margin_h, margin_v)


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
	_ensure_pixel_fonts()
	theme.default_font = _pixel_font_12
	theme.default_font_size = 12
	var light_mode := mode == "light"

	theme.set_color("font_color", "Label", TEXT)
	if light_mode:
		theme.set_color("font_shadow_color", "Label", Color(1.0, 0.99, 0.95, 0.75))
		theme.set_constant("shadow_offset_x", "Label", 1)
		theme.set_constant("shadow_offset_y", "Label", 1)
	else:
		theme.set_color("font_shadow_color", "Label", Color(0.01, 0.02, 0.05, 0.92))
		theme.set_constant("shadow_offset_x", "Label", 1)
		theme.set_constant("shadow_offset_y", "Label", 1)

	theme.set_stylebox("panel", "PanelContainer", panel_style(PANEL, BORDER, 10, true))
	theme.set_stylebox("panel", "Panel", panel_style(PANEL, BORDER, 10, true))

	var btn_norm: StyleBoxTexture
	var btn_hov: StyleBoxTexture
	var btn_press: StyleBoxTexture
	var btn_dis: StyleBoxTexture
	if light_mode:
		btn_norm = SmaPixelArt.button_box(Color("#ebd6af"), Color("#fffdf7"), Color("#9c6f44"), 7, false)
		btn_hov = SmaPixelArt.button_box(Color("#f7e7c6"), Color("#ffffff"), Color("#855a32"), 7, false)
		btn_press = SmaPixelArt.button_box(Color("#0f766e"), Color("#5eead4"), Color("#053330"), 7, true)
		btn_dis = SmaPixelArt.button_box(Color("#dfd0b4"), Color("#efe4cf"), Color("#b09a78"), 7, false)
	else:
		btn_norm = SmaPixelArt.button_box(Color("#243858"), Color("#7db0e0"), Color("#0c1526"), 7, false)
		btn_hov = SmaPixelArt.button_box(Color("#324d78"), Color("#bae6fd"), Color("#122038"), 7, false)
		btn_press = SmaPixelArt.button_box(Color("#0f766e"), Color("#5eead4"), Color("#053330"), 7, true)
		btn_dis = SmaPixelArt.button_box(Color("#131d2f"), Color("#2c3e58"), Color("#080e19"), 7, false)

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
	theme.set_icon("arrow", "OptionButton", SmaPixelArt.icon("opt_arrow"))
	theme.set_constant("arrow_margin", "OptionButton", 6)
	theme.set_icon("updown", "SpinBox", SmaPixelArt.icon("spin_updown"))

	if not light_mode:
		theme.set_color("font_outline_color", "Button", Color("#04070e"))
		theme.set_constant("outline_size", "Button", 2)
	theme.set_font_size("font_size", "Button", 12)
	theme.set_font_size("font_size", "OptionButton", 12)
	theme.set_font_size("font_size", "LineEdit", 12)
	theme.set_font_size("font_size", "PopupMenu", 12)
	theme.set_font_size("font_size", "CheckBox", 12)

	var focus := _box(Color.TRANSPARENT, ACCENT, 0, 0)
	focus.draw_center = false
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_stylebox("focus", "OptionButton", focus)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", TEXT if light_mode else Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color("#fef08a"))
	theme.set_color("font_hover_pressed_color", "Button", Color("#fef08a"))
	theme.set_color("font_disabled_color", "Button", DIM)

	theme.set_stylebox("normal", "LineEdit", readout_style(8, 6, BORDER))
	theme.set_stylebox("focus", "LineEdit", readout_style(8, 6, ACCENT))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", DIM)

	theme.set_color("font_color", "OptionButton", TEXT)
	theme.set_color("font_hover_color", "OptionButton", TEXT if light_mode else Color.WHITE)

	theme.set_stylebox("panel", "PopupMenu", panel_style(PANEL_ALT, ACCENT, 6, false))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", GOLD)

	var scr_track := SmaPixelArt.scroll_box(BG_DEEP, BORDER, true)
	var scr_grab := SmaPixelArt.scroll_box(PANEL_HOVER, BORDER, false)
	var scr_hi := SmaPixelArt.scroll_box(ACCENT_DARK, ACCENT, false)
	for bar_cls in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", bar_cls, scr_track)
		theme.set_stylebox("grabber", bar_cls, scr_grab)
		theme.set_stylebox("grabber_highlight", bar_cls, scr_hi)
		theme.set_stylebox("grabber_pressed", bar_cls, scr_hi)

	theme.set_stylebox("normal", "SpinBox", readout_style(6, 5, BORDER))
	theme.set_color("font_color", "SpinBox", TEXT)

	theme.set_stylebox("background", "ProgressBar", SmaPixelArt.progress_bg_box(BG_DEEP, BORDER))
	theme.set_stylebox("fill", "ProgressBar", SmaPixelArt.progress_fill_box(POSITIVE))

	theme.set_color("font_color", "CheckBox", TEXT)
	theme.set_color("font_pressed_color", "CheckBox", ACCENT)
	theme.set_icon("checked", "CheckBox", SmaPixelArt.icon("cb_checked"))
	theme.set_icon("unchecked", "CheckBox", SmaPixelArt.icon("cb_unchecked"))
	theme.set_icon("radio_checked", "CheckBox", SmaPixelArt.icon("radio_checked"))
	theme.set_icon("radio_unchecked", "CheckBox", SmaPixelArt.icon("radio_unchecked"))
	theme.set_icon("grabber", "HSlider", SmaPixelArt.icon("slider_grabber"))
	theme.set_icon("grabber_highlight", "HSlider", SmaPixelArt.icon("slider_grabber_hi"))
	theme.set_icon("grabber_disabled", "HSlider", SmaPixelArt.icon("cb_unchecked"))
	theme.set_stylebox("slider", "HSlider", SmaPixelArt.progress_bg_box(BG_DEEP, BORDER))
	theme.set_stylebox("grabber_area", "HSlider", SmaPixelArt.progress_fill_box(ACCENT))
	theme.set_stylebox("grabber_area_highlight", "HSlider", SmaPixelArt.progress_fill_box(POSITIVE))

	return theme
