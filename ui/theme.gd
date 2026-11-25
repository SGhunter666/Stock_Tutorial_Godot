## Central visual language. Every screen pulls colors, spacing and control styles
## from here so the UI can switch cleanly between the signature A+B Retro Pixel
## Terminal theme ("pixel"), modern dark ("dark"), and daytime light ("light").
class_name SmaUiTheme
extends RefCounted

const CARD_RADIUS := 10
const GAP := 10

static var BG := Color("#080d16")
static var BG_DEEP := Color("#05080f")
static var PANEL := Color("#0e1726")
static var PANEL_ALT := Color("#162338")
static var PANEL_HOVER := Color("#1f3350")
static var BORDER := Color("#3b5b7e")
static var TEXT := Color("#eef6fc")
static var MUTED := Color("#a8c2da")
static var DIM := Color("#7e9ab5")
static var ACCENT := Color("#5eead4")
static var ACCENT_DARK := Color("#0f766e")
static var POSITIVE := Color("#4ade80")
static var NEGATIVE := Color("#f87171")
static var WARNING := Color("#fbbf24")
static var INFO := Color("#60a5fa")
static var mode := "pixel"
static var color_scheme := "intl"

## Layout density: 1.0 for the beginner layout, a compact factor for advanced.
static var density := 1.0


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
		WARNING = Color("#b45309")
		INFO = Color("#1d4ed8")
	elif mode == "pixel":
		BG = Color("#080d16")
		BG_DEEP = Color("#05080f")
		PANEL = Color("#0e1726")
		PANEL_ALT = Color("#162338")
		PANEL_HOVER = Color("#213654")
		BORDER = Color("#3b5b7e")
		TEXT = Color("#eef6fc")
		MUTED = Color("#a8c2da")
		DIM = Color("#7e9ab5")
		ACCENT = Color("#5eead4")
		ACCENT_DARK = Color("#0f766e")
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


static func build() -> Theme:
	var theme := Theme.new()
	var fallback := SystemFont.new()
	fallback.font_names = PackedStringArray([
		"Menlo", "Monaco", "Consolas", "PingFang SC", "Hiragino Sans GB",
		"Microsoft YaHei", "Noto Sans CJK SC", "Source Han Sans SC", "sans-serif",
	] if is_pixel() else [
		"PingFang SC", "Hiragino Sans GB", "Microsoft YaHei",
		"Noto Sans CJK SC", "Source Han Sans SC", "Arial Unicode MS", "sans-serif",
	])
	fallback.allow_system_fallback = true
	fallback.antialiasing = TextServer.FONT_ANTIALIASING_NONE if is_pixel() \
		else TextServer.FONT_ANTIALIASING_GRAY
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
		theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.82))
		theme.set_constant("shadow_offset_x", "Label", 1)
		theme.set_constant("shadow_offset_y", "Label", 1)
	else:
		theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))

	theme.set_stylebox("panel", "PanelContainer", _box(PANEL))
	theme.set_stylebox("panel", "Panel", _box(PANEL))

	theme.set_stylebox("normal", "Button", beveled_button_box(PANEL_ALT, BORDER, 8, false))
	theme.set_stylebox("hover", "Button", beveled_button_box(PANEL_HOVER, ACCENT, 8, false))
	theme.set_stylebox("pressed", "Button", beveled_button_box(ACCENT_DARK, ACCENT, 8, true))
	theme.set_stylebox("disabled", "Button", _box(PANEL, DIM, 8, 8))
	var focus := _box(Color.TRANSPARENT, ACCENT, 8, 0)
	focus.draw_center = false
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", DIM)
	theme.set_font_size("font_size", "Button", 13)

	theme.set_stylebox("normal", "LineEdit", _box(BG_DEEP, BORDER, 8, 8))
	theme.set_stylebox("focus", "LineEdit", _box(BG_DEEP, ACCENT, 8, 8))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", DIM)
	theme.set_font_size("font_size", "LineEdit", 13)

	theme.set_stylebox("normal", "OptionButton", beveled_button_box(PANEL_ALT, BORDER, 8, false))
	theme.set_stylebox("hover", "OptionButton", beveled_button_box(PANEL_HOVER, ACCENT, 8, false))
	theme.set_stylebox("pressed", "OptionButton", beveled_button_box(ACCENT_DARK, ACCENT, 8, true))
	theme.set_stylebox("focus", "OptionButton", focus)
	theme.set_color("font_color", "OptionButton", TEXT)
	theme.set_font_size("font_size", "OptionButton", 13)

	theme.set_stylebox("panel", "PopupMenu", _box(PANEL_ALT, BORDER, 8, 6))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	theme.set_font_size("font_size", "PopupMenu", 13)

	theme.set_stylebox("scroll", "VScrollBar", _box(BG_DEEP, BORDER, 6, 0))
	theme.set_stylebox("grabber", "VScrollBar", _box(PANEL_HOVER, BORDER, 6, 0))
	theme.set_stylebox("grabber_highlight", "VScrollBar", _box(ACCENT_DARK, ACCENT, 6, 0))
	theme.set_stylebox("grabber_pressed", "VScrollBar", _box(ACCENT, ACCENT, 6, 0))

	theme.set_stylebox("normal", "SpinBox", _box(BG_DEEP, BORDER, 8, 6))
	theme.set_color("font_color", "SpinBox", TEXT)

	theme.set_color("font_color", "CheckBox", TEXT)
	theme.set_color("font_pressed_color", "CheckBox", ACCENT)
	theme.set_font_size("font_size", "CheckBox", 13)

	return theme
