## Small UI factory used by every screen. These helpers exist to keep screens
## focused on layout and state, not on repeating Control boilerplate.
class_name SmaKit
extends RefCounted


static func label(text: String, size: int = 13,
		color: Color = Color(0, 0, 0, 0)) -> Label:
	var node := Label.new()
	node.text = text
	if SmaUiTheme.is_pixel():
		var snapped := SmaUiTheme.resolve_font(size, true)
		node.add_theme_font_override("font", snapped["font"])
		node.add_theme_font_size_override("font_size", int(snapped["size"]))
	else:
		var scaled := maxi(9, int(round(float(size) * SmaUiTheme.density)))
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
		var snapped := SmaUiTheme.resolve_font(px, false)
		node.add_theme_font_override("font", snapped["font"])
		node.add_theme_font_size_override("font_size", int(snapped["size"]))
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
		var snapped := SmaUiTheme.resolve_font(12, true)
		node.add_theme_font_override("font", snapped["font"])
		node.add_theme_font_size_override("font_size", int(snapped["size"]))
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
		var snapped := SmaUiTheme.resolve_font(font_px, true)
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


static func badge(text: String, bg: Color, fg: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", SmaPixelArt.readout_box(bg, fg, 8, 4))
	pill.add_child(label(text, 11, fg))
	return pill


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


## Formats `SmaAttribution.explain_today` into localized human-readable prose so
## no stock drop or surge ever appears unexplained.
static func format_attribution(state: Dictionary, ticker: String) -> String:
	var info := SmaAttribution.explain_today(state, ticker)
	var key := String(info.get("key", "attr.flatConsolidation"))
	var params: Dictionary = info.get("params", {}).duplicate()
	if key == "attr.earningsToday":
		var r := String(params.get("reason", "inlineDigest"))
		params["short"] = I18n.t("earnings.reasonShort.%s" % r)
		params["desc"] = I18n.t("earnings.reasonDesc.%s" % r)
	elif key == "attr.companyNews":
		var tmpl := String(params.get("template", "downgrade"))
		var comp_name := String(SmaCompanyCatalog.get_company(ticker).get("name", ticker))
		var chg := absf(float(info.get("changePct", 0.0)))
		params["headline"] = I18n.t("news.template.%s" % tmpl, {
			"company": comp_name,
			"pct": SmaFormat.num(chg, 1) + "%",
		})
	elif params.has("sector"):
		params["sector"] = sector_label(String(params["sector"]))
	var body := I18n.t(key, params) if I18n.has_key(key) else I18n.t("attr.orderFlowSell")
	return I18n.t("attr.prefix") + body


## Formats `SmaAttribution.candle_catalyst_map` into date -> localized short tag
## for `SmaCandleChart` crosshair hover tooltips.
static func format_candle_catalysts(state: Dictionary, ticker: String) -> Dictionary:
	var raw := SmaAttribution.candle_catalyst_map(state, ticker)
	var out := {}
	for date_key in raw.keys():
		var item: Dictionary = raw[date_key]
		var k := String(item.get("kind", ""))
		if k == "earnings":
			var r := String(item.get("reason", "inlineDigest"))
			out[date_key] = I18n.t("attr.candle.earnings", {
				"period": String(item.get("period", "")),
				"short": I18n.t("earnings.reasonShort.%s" % r),
			})
		elif k == "corporate":
			var act := String(item.get("type", ""))
			var act_key := "corporate.type.%s" % act
			out[date_key] = I18n.t("attr.candle.corp", {
				"action": I18n.t(act_key) if I18n.has_key(act_key) else act,
			})
		elif k == "news":
			out[date_key] = I18n.t("attr.candle.news")
		elif k == "macro":
			out[date_key] = I18n.t("attr.candle.macro")
	return out


## Builds the interactive High-Stakes Market Event Decision Card (IPO,
## Earnings Call Q&A, FOMC Rate Night) shared by Dashboard and News screens.
static func build_market_event_card(game_ref: Variant, on_resolved: Callable) -> Control:
	if game_ref == null or not game_ref.started:
		return null
	var evt: Dictionary = game_ref.active_market_event()
	if evt.is_empty():
		return null
	var kind := String(evt.get("kind", "ipo"))
	var resolved := bool(evt.get("resolved", false))
	var card := PanelContainer.new()
	var border_col := SmaUiTheme.POSITIVE if resolved else SmaUiTheme.GOLD
	card.add_theme_stylebox_override("panel",
		SmaUiTheme.panel_style(SmaUiTheme.PANEL_ALT, border_col, 12, false))
	var box := vbox(7)
	card.add_child(box)

	var head := hbox(8)
	head.add_child(label(I18n.t("events.kind.%s" % kind), 11, SmaUiTheme.GOLD))
	head.add_child(label(I18n.t(String(evt.get("titleKey", "")), {
		"ticker": String(evt.get("ticker", "")),
		"issuer": String(evt.get("issuer", "")),
	}), 15))
	head.add_child(hspacer())
	var status_txt := I18n.t("events.statusDone") if resolved else I18n.t("events.statusLive", {
		"days": maxi(1, int(evt.get("expiresDay", 0)) - int(evt.get("day", 0)) + 1),
	})
	head.add_child(label(status_txt, 11, SmaUiTheme.POSITIVE if resolved else SmaUiTheme.WARNING))
	box.add_child(head)

	var m: Dictionary = evt.get("metrics", {})
	var clue_txt := I18n.t(String(evt.get("clueKey", "")), {
		"issuer": String(evt.get("issuer", "")),
		"ticker": String(evt.get("ticker", "")),
		"revGrowth": SmaFormat.pct(float(m.get("revGrowth", 0.0)), 0),
		"netMargin": SmaFormat.pct(float(m.get("netMargin", 0.0)), 0),
		"ps": "%.1fx" % float(m.get("psMultiple", 0.0)),
		"oversub": "%.1fx" % float(m.get("oversub", 0.0)),
		"surprise": SmaFormat.pct(float(m.get("surprisePct", 0.0)), 1),
		"runup": SmaFormat.pct(float(m.get("runupPct", 0.0)), 1),
		"rate": "%.2f%%" % float(m.get("policyRate", 0.0)),
		"inflation": "%.2f%%" % float(m.get("inflation", 0.0)),
	})
	var clue := muted(clue_txt, 12)
	clue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(clue)

	if not resolved:
		var actions := flow(8)
		for choice in evt.get("choices", []):
			var cid := String(choice.get("id", ""))
			var stake := float(choice.get("stake", 0.0))
			var btn_lbl := I18n.t(String(choice.get("labelKey", "")), {
				"stake": SmaFormat.money(stake),
			})
			var primary := cid in ["light", "drop", "rally", "hedge"]
			var btn := button(btn_lbl, func():
				var res: Dictionary = game_ref.resolve_market_event(cid)
				if bool(res.get("ok", false)) and on_resolved.is_valid():
					on_resolved.call(), primary)
			actions.add_child(btn)
		box.add_child(actions)
	else:
		var res: Dictionary = evt.get("resolution", {})
		var delta := float(res.get("cashDelta", 0.0))
		var tone := String(res.get("tone", "neutral"))
		var tone_col := SmaUiTheme.POSITIVE if tone == "win" else (
			SmaUiTheme.NEGATIVE if tone == "loss" else SmaUiTheme.ACCENT)
		var metric_raw := String(res.get("metricText", ""))
		var metric_disp := I18n.t(metric_raw) if I18n.has_key(metric_raw) else metric_raw
		var verdict_line := label("%s · %s · %s (+%d XP)" % [
			I18n.t(String(res.get("verdictKey", "events.verdict.neutral"))),
			metric_disp,
			SmaFormat.signed_money(delta),
			int(res.get("xp", 0)),
		], 13, tone_col)
		verdict_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(verdict_line)
		var exp_lbl := muted(I18n.t(String(res.get("explainKey", ""))), 11)
		exp_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(exp_lbl)
	return card


## UI sounds are optional: the autoload is absent in headless logic tests, so
## every helper fails quietly instead of requiring a running audio server.
static func _play_click() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var audio := tree.root.get_node_or_null("Sfx")
	if audio != null and audio.has_method("play_click"):
		audio.play_click()
