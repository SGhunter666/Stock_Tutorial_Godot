## Small UI factory used by every screen. These helpers exist to keep screens
## focused on layout and state, not on repeating Control boilerplate.
class_name SmaKit
extends RefCounted


static func label(text: String, size: int = 13,
		color: Color = Color(0, 0, 0, 0)) -> Label:
	var node := Label.new()
	node.text = text
	var scaled := maxi(9, int(round(float(size) * SmaUiTheme.density)))
	if SmaUiTheme.is_pixel():
		var snapped := SmaUiTheme.pixel_snap_font(scaled)
		node.add_theme_font_override("font", snapped["font"])
		node.add_theme_font_size_override("font_size", int(snapped["size"]))
	else:
		node.add_theme_font_size_override("font_size", scaled)
	node.add_theme_color_override("font_color",
		SmaUiTheme.TEXT if color.a <= 0.0 else color)
	return node


static func muted(text: String, size: int = 12) -> Label:
	return label(text, size, SmaUiTheme.MUTED)


static func title(text: String, size: int = 20) -> Label:
	var light_mode := SmaUiTheme.mode == "light"
	var col := Color("#7c2d12") if light_mode else Color("#fef3c7")
	var decorated := text
	if text != "" and not (text.begins_with("◆") or text.begins_with("★") or text.begins_with("▶")):
		decorated = "◆ " + text
	var node := label(decorated, size, col)
	node.add_theme_color_override("font_shadow_color",
		Color(1.0, 0.98, 0.92, 0.85) if light_mode else Color("#04070e"))
	node.add_theme_constant_override("shadow_offset_x", 1 if light_mode else 2)
	node.add_theme_constant_override("shadow_offset_y", 1 if light_mode else 2)
	return node


static func caption(text: String) -> Label:
	var node := label(text, 11, SmaUiTheme.DIM)
	return node


static func card(margin: int = 12) -> PanelContainer:
	var panel := PanelContainer.new()
	var pad := maxi(5, int(round(float(margin) * SmaUiTheme.density)))
	var style := SmaUiTheme.panel_style(SmaUiTheme.PANEL, SmaUiTheme.BORDER, pad, true)
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel


static func modal_card(margin: int = 20) -> PanelContainer:
	var panel := PanelContainer.new()
	var pad := maxi(8, int(round(float(margin) * SmaUiTheme.density)))
	var bg := Color("#fffaf0") if SmaUiTheme.mode == "light" else Color("#0f1b30")
	var hi := SmaUiTheme.GOLD
	panel.add_theme_stylebox_override("panel", SmaUiTheme.panel_style(bg, hi, pad, true))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel


static func set_small_font(node: Control, px: int = 10) -> void:
	if SmaUiTheme.is_pixel():
		if px <= 10:
			node.add_theme_font_override("font", SmaUiTheme.pixel_font_10())
			node.add_theme_font_size_override("font_size", 10)
		else:
			node.add_theme_font_override("font", SmaUiTheme.pixel_font_12())
			node.add_theme_font_size_override("font_size", 12)
	else:
		node.add_theme_font_size_override("font_size", px)


static func vbox(separation: int = SmaUiTheme.GAP) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",
		maxi(1, int(round(float(separation) * SmaUiTheme.density))))
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return box


static func hbox(separation: int = SmaUiTheme.GAP) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation",
		maxi(1, int(round(float(separation) * SmaUiTheme.density))))
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return box


static func flow(separation: int = SmaUiTheme.GAP) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", separation)
	row.add_theme_constant_override("v_separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return row


static func button(text: String, callback: Callable = Callable(), primary: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.pressed.connect(_play_click)
	if SmaUiTheme.is_pixel():
		node.add_theme_font_override("font", SmaUiTheme.pixel_font_12())
		node.add_theme_font_size_override("font_size", 12)
	else:
		node.add_theme_font_size_override("font_size",
			maxi(9, int(round(12.0 * SmaUiTheme.density))))
	if primary:
		SmaUiTheme.apply_arcade_button(node, "primary", 8)
	if callback.is_valid():
		node.pressed.connect(callback)
	return node


static func arcade_button(text: String, kind: String, callback: Callable = Callable(),
		font_px: int = 12) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.pressed.connect(_play_click)
	if SmaUiTheme.is_pixel():
		var snapped := SmaUiTheme.pixel_snap_font(font_px)
		node.add_theme_font_override("font", snapped["font"])
		node.add_theme_font_size_override("font_size", int(snapped["size"]))
	else:
		node.add_theme_font_size_override("font_size", font_px)
	SmaUiTheme.apply_arcade_button(node, kind, 8)
	if callback.is_valid():
		node.pressed.connect(callback)
	return node


static func toggle(text: String, group: ButtonGroup = null) -> Button:
	var node := button(text)
	node.toggle_mode = true
	node.button_group = group
	return node


static func icon_rect(kind: String, px_size: Vector2 = Vector2(16, 16)) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = SmaPixelArt.icon(kind)
	rect.custom_minimum_size = px_size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func cell(text: String, ratio: float = 1.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
		color: Color = Color(0, 0, 0, 0), size: int = 12) -> Label:
	var node := label(text, size, color)
	node.horizontal_alignment = align
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_stretch_ratio = ratio
	node.clip_text = true
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func header_row(columns: Array, ratios: Array, aligns: Array = []) -> HBoxContainer:
	var row := hbox(8)
	row.add_theme_constant_override("separation", 8)
	var col := SmaUiTheme.GOLD if SmaUiTheme.is_pixel() else SmaUiTheme.DIM
	for index in columns.size():
		var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
		if index < aligns.size():
			align = aligns[index]
		var text := I18n.t(String(columns[index]))
		row.add_child(cell(text, float(ratios[index]), align, col, 11))
	return row


static func data_row(values: Array, ratios: Array, colors: Array = [], aligns: Array = []) -> HBoxContainer:
	var row := hbox(8)
	for index in values.size():
		var color := SmaUiTheme.TEXT
		if index < colors.size():
			color = colors[index]
		var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
		if index < aligns.size():
			align = aligns[index]
		row.add_child(cell(String(values[index]), float(ratios[index]), align, color, 12))
	return row


static func separator() -> HSeparator:
	var line := HSeparator.new()
	var style := StyleBoxFlat.new()
	style.anti_aliasing = false
	style.bg_color = Color("#04070e") if SmaUiTheme.mode != "light" else Color("#b58450")
	style.border_color = SmaUiTheme.BORDER
	style.border_width_bottom = 2
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	line.add_theme_stylebox_override("separator", style)
	return line


static func spacer(height: float = 0.0, expand: bool = false) -> Control:
	var node := Control.new()
	if height > 0.0:
		node.custom_minimum_size.y = height
	if expand:
		node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Horizontal spring for HBox rows. Kept separate from spacer() so vertical and
## horizontal layouts cannot silently steal each other's expansion.
static func hspacer() -> Control:
	var node := Control.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


static func scroll(height: float = 0.0) -> ScrollContainer:
	var node := ScrollContainer.new()
	node.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if height > 0.0:
		node.custom_minimum_size.y = height
	return node


static func value_color(value: float) -> Color:
	if value > 0.0:
		return SmaUiTheme.POSITIVE
	if value < 0.0:
		return SmaUiTheme.NEGATIVE
	return SmaUiTheme.MUTED


static func sector_label(sector: String) -> String:
	var key := "sector.%s" % sector
	if I18n.has_key(key):
		return I18n.t(key)
	return sector.capitalize()


static func liquidity_label(liquidity: String) -> String:
	var key := "liquidity.%s" % liquidity
	if I18n.has_key(key):
		return I18n.t(key)
	return liquidity.capitalize()


static func style_label(style: String) -> String:
	var key := "style.%s" % style
	if I18n.has_key(key):
		return I18n.t(key)
	return style.capitalize()


## UI sounds are optional: the autoload is absent in headless logic tests, so
## every helper fails quietly instead of requiring a running audio server.
static func _play_click() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var audio := tree.root.get_node_or_null("Sfx")
	if audio != null and audio.has_method("play_click"):
		audio.play_click()
