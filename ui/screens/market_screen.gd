## Market overview: every listed company with live simulated quotes. Clicking a
## row selects it and moves to the trading desk.
class_name SmaMarketScreen
extends SmaScreen

var _rows: Dictionary = {}
var _search: LineEdit
var _sector_filter: OptionButton
var _sector_values: Array[String] = [""]
var _watch_only: Button
var _list: VBoxContainer
var _count_label: Label
var _index_label: Label
var _index_change: Label
var _heat_tiles: Dictionary = {}
var _heat_buckets: Dictionary = {}
var _sort_key := "ticker"
var _sort_desc := false
var _sort_buttons: Dictionary = {}


func _build() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS

	var root := SmaKit.vbox(12)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var heading := SmaKit.vbox(2)
	heading.add_child(SmaKit.title(I18n.t("market.title"), 22))
	heading.add_child(SmaKit.muted(I18n.t("market.subtitle")))
	root.add_child(heading)

	var index_row := SmaKit.hbox(10)
	index_row.add_child(SmaKit.caption(I18n.t("market.index")))
	_index_label = SmaKit.label("—", 18)
	_index_change = SmaKit.label("—", 12)
	index_row.add_child(_index_label)
	index_row.add_child(_index_change)
	index_row.add_child(SmaKit.hspacer())
	root.add_child(index_row)

	var filters := SmaKit.hbox(10)
	_search = LineEdit.new()
	_search.placeholder_text = I18n.t("market.search")
	_search.custom_minimum_size.x = 320
	_search.text_changed.connect(func(_text): _apply_filter())
	filters.add_child(_search)
	_sector_filter = OptionButton.new()
	_sector_filter.custom_minimum_size.x = 180
	_sector_filter.add_item(I18n.t("market.all_sectors"))
	_sector_values = [""]
	var sectors: Array = SmaCompanyCatalog.sectors()
	sectors.append(SmaEtfs.ETF_SECTOR)
	sectors.sort()
	for sector in sectors:
		_sector_filter.add_item(SmaKit.sector_label(String(sector)))
		_sector_values.append(String(sector))
	_sector_filter.item_selected.connect(func(_index): _apply_filter())
	filters.add_child(_sector_filter)
	_watch_only = SmaKit.toggle(I18n.t("market.watchOnly"))
	_watch_only.toggled.connect(func(_pressed): _apply_filter())
	filters.add_child(_watch_only)
	filters.add_child(SmaKit.hspacer())
	_count_label = SmaKit.muted("")
	filters.add_child(_count_label)
	root.add_child(filters)
	root.add_child(_build_heatmap())

	var table_card := SmaKit.card(4 if SmaUiTheme.is_pixel() else 0)
	table_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var table := SmaKit.vbox(0)
	table_card.add_child(table)
	var header_wrap := PanelContainer.new()
	var h_style := StyleBoxFlat.new()
	h_style.bg_color = Color("#070e1c") if SmaUiTheme.is_pixel() else SmaUiTheme.BG_DEEP
	h_style.border_color = SmaUiTheme.BORDER
	h_style.border_width_bottom = 2 if SmaUiTheme.is_pixel() else 1
	h_style.set_content_margin_all(6)
	header_wrap.add_theme_stylebox_override("panel", h_style)
	var header := SmaKit.hbox(8)
	header.custom_minimum_size.y = 26
	header_wrap.add_child(header)
	_sort_buttons.clear()
	var col_specs := [
		["market.watch", 0.35, HORIZONTAL_ALIGNMENT_CENTER, ""],
		["market.ticker", 0.85, HORIZONTAL_ALIGNMENT_LEFT, "ticker"],
		["market.company", 2.0, HORIZONTAL_ALIGNMENT_LEFT, "name"],
		["market.sector", 1.0, HORIZONTAL_ALIGNMENT_LEFT, ""],
		["market.last", 0.9, HORIZONTAL_ALIGNMENT_RIGHT, "last"],
		["market.change", 0.95, HORIZONTAL_ALIGNMENT_RIGHT, "change"],
		["market.trend", 0.75, HORIZONTAL_ALIGNMENT_CENTER, ""],
		["market.bid", 0.8, HORIZONTAL_ALIGNMENT_RIGHT, ""],
		["market.ask", 0.8, HORIZONTAL_ALIGNMENT_RIGHT, ""],
		["market.volume", 1.0, HORIZONTAL_ALIGNMENT_RIGHT, "volume"],
	]
	var head_col := SmaUiTheme.GOLD if SmaUiTheme.is_pixel() else SmaUiTheme.DIM
	for spec in col_specs:
		var sort_id := String(spec[3])
		if sort_id == "":
			header.add_child(SmaKit.cell(I18n.t(String(spec[0])), float(spec[1]),
				spec[2], head_col, 11))
		else:
			var btn := Button.new()
			btn.flat = true
			btn.focus_mode = Control.FOCUS_NONE
			btn.alignment = spec[2]
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.size_flags_stretch_ratio = float(spec[1])
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			if SmaUiTheme.is_pixel():
				btn.add_theme_font_override("font", SmaUiTheme.pixel_font_12())
				btn.add_theme_font_size_override("font_size", 12)
			else:
				btn.add_theme_font_size_override("font_size", 11)
			btn.add_theme_color_override("font_color", head_col)
			btn.add_theme_color_override("font_hover_color", SmaUiTheme.ACCENT)
			btn.pressed.connect(_toggle_sort.bind(sort_id))
			_sort_buttons[sort_id] = {"button": btn, "labelKey": String(spec[0])}
			header.add_child(btn)
	_sync_sort_labels()
	table.add_child(header_wrap)

	var scroll := SmaKit.scroll()
	_list = SmaKit.vbox(0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	table.add_child(scroll)
	root.add_child(table_card)

	var companies := SmaCompanyCatalog.load_companies()
	for ticker in companies.keys():
		_create_row(String(ticker), companies[ticker], String(companies[ticker].get("sector", "")), false)
	var etfs := SmaEtfs.instruments()
	for ticker in etfs.keys():
		_create_row(String(ticker), etfs[ticker], SmaEtfs.ETF_SECTOR, true)


func _create_row(ticker: String, company: Dictionary, sector: String,
		is_etf: bool) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = SmaUiTheme.PANEL if _rows.size() % 2 == 0 else SmaUiTheme.PANEL_ALT
	style.set_content_margin_all(7)
	style.border_color = Color(0, 0, 0, 0)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.custom_minimum_size.y = 30
	panel.gui_input.connect(_on_row_input.bind(ticker))
	panel.mouse_entered.connect(func(): panel.self_modulate = Color(1.25, 1.25, 1.25))
	panel.mouse_exited.connect(func(): panel.self_modulate = Color.WHITE)
	var row := SmaKit.hbox(8)
	panel.add_child(row)
	var watch_cell := SmaKit.hbox(0)
	watch_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	watch_cell.size_flags_stretch_ratio = 0.35
	var watch_button := Button.new()
	watch_button.text = "☆"
	watch_button.flat = true
	watch_button.focus_mode = Control.FOCUS_NONE
	watch_button.custom_minimum_size = Vector2(26, 26)
	watch_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	watch_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	watch_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	watch_button.tooltip_text = I18n.t("market.watchAdd", {"ticker": ticker})
	watch_button.pressed.connect(_on_watch_pressed.bind(ticker))
	watch_cell.add_child(watch_button)
	row.add_child(watch_cell)
	var spark_wrap := SmaKit.hbox(0)
	spark_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spark_wrap.size_flags_stretch_ratio = 0.75
	var spark := SmaSparkline.new()
	spark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	spark_wrap.add_child(spark)
	var ticker_wrap := SmaKit.hbox(6)
	ticker_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ticker_wrap.size_flags_stretch_ratio = 0.85
	ticker_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_rect: TextureRect = null
	if SmaUiTheme.is_pixel():
		badge_rect = TextureRect.new()
		badge_rect.texture = SmaPixelArt.ticker_badge(ticker, sector, false)
		badge_rect.custom_minimum_size = Vector2(20, 20)
		badge_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		badge_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ticker_wrap.add_child(badge_rect)
	var ticker_lbl := SmaKit.cell(ticker, 1.0, HORIZONTAL_ALIGNMENT_LEFT,
		SmaUiTheme.ACCENT if SmaUiTheme.is_pixel() else SmaUiTheme.TEXT)
	ticker_wrap.add_child(ticker_lbl)
	var cells := {
		"ticker": ticker_lbl,
		"name": SmaKit.cell(String(company.get("name", ticker)), 2.0),
		"sector": SmaKit.cell(SmaKit.sector_label(String(company.get("sector", ""))), 1.0, HORIZONTAL_ALIGNMENT_LEFT, SmaUiTheme.MUTED),
		"last": SmaKit.cell("—", 0.9, HORIZONTAL_ALIGNMENT_RIGHT),
		"change": SmaKit.cell("—", 0.95, HORIZONTAL_ALIGNMENT_RIGHT),
		"bid": SmaKit.cell("—", 0.8, HORIZONTAL_ALIGNMENT_RIGHT),
		"ask": SmaKit.cell("—", 0.8, HORIZONTAL_ALIGNMENT_RIGHT),
		"volume": SmaKit.cell("—", 1.0, HORIZONTAL_ALIGNMENT_RIGHT, SmaUiTheme.MUTED),
	}
	row.add_child(ticker_wrap)
	for key in ["name", "sector", "last", "change"]:
		row.add_child(cells[key])
	row.add_child(spark_wrap)
	for key in ["bid", "ask", "volume"]:
		row.add_child(cells[key])
	_list.add_child(panel)
	_rows[ticker] = {"panel": panel, "cells": cells, "spark": spark, "badge": badge_rect,
		"sector": sector, "name": String(company.get("name", ticker)),
		"is_etf": is_etf, "locked": false, "watch": watch_button}


func _toggle_sort(key: String) -> void:
	if _sort_key == key:
		_sort_desc = not _sort_desc
	else:
		_sort_key = key
		_sort_desc = key in ["last", "change", "volume"]
	_sync_sort_labels()
	_apply_sort()


func _sync_sort_labels() -> void:
	for key in _sort_buttons.keys():
		var info: Dictionary = _sort_buttons[key]
		var btn: Button = info["button"]
		var base := I18n.t(String(info["labelKey"]))
		if key == _sort_key:
			btn.text = "%s %s" % [base, "▼" if _sort_desc else "▲"]
			btn.add_theme_color_override("font_color", SmaUiTheme.ACCENT)
		else:
			btn.text = base
			btn.add_theme_color_override("font_color", SmaUiTheme.DIM)


func _apply_sort() -> void:
	if _list == null or game == null or game.exchange == null:
		return
	var tickers: Array = _rows.keys()
	var quotes: Dictionary = {}
	for t in tickers:
		quotes[t] = game.exchange.quote(String(t))
	tickers.sort_custom(func(a, b):
		var a_locked := bool(_rows[a]["locked"])
		var b_locked := bool(_rows[b]["locked"])
		if a_locked != b_locked and _sort_key in ["last", "change", "volume"]:
			return not a_locked
		var qa: Dictionary = quotes[a]
		var qb: Dictionary = quotes[b]
		var cmp := 0
		match _sort_key:
			"name":
				var na := String(_rows[a]["name"]).to_lower()
				var nb := String(_rows[b]["name"]).to_lower()
				cmp = -1 if na < nb else (1 if na > nb else 0)
			"last":
				var la := float(qa.get("last", 0.0))
				var lb := float(qb.get("last", 0.0))
				cmp = -1 if la < lb else (1 if la > lb else 0)
			"change":
				var ca := float(qa.get("changePct", 0.0))
				var cb := float(qb.get("changePct", 0.0))
				cmp = -1 if ca < cb else (1 if ca > cb else 0)
			"volume":
				var va := float(qa.get("volume", 0.0))
				var vb := float(qb.get("volume", 0.0))
				cmp = -1 if va < vb else (1 if va > vb else 0)
			_:
				var sa := String(a)
				var sb := String(b)
				cmp = -1 if sa < sb else (1 if sa > sb else 0)
		if cmp == 0:
			return String(a) < String(b)
		return cmp > 0 if _sort_desc else cmp < 0)
	for index in tickers.size():
		var panel: PanelContainer = _rows[tickers[index]]["panel"]
		_list.move_child(panel, index)


func _build_heatmap() -> Control:
	var card := SmaKit.card(10)
	var box := SmaKit.vbox(6)
	card.add_child(box)
	var header := SmaKit.hbox(8)
	header.add_child(SmaKit.label(I18n.t("market.heatmapTitle"), 14))
	header.add_child(SmaKit.hspacer())
	header.add_child(SmaKit.muted(I18n.t("market.heatmapHint"), 10))
	box.add_child(header)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	var sectors: Array = SmaCompanyCatalog.sectors()
	sectors.append(SmaEtfs.ETF_SECTOR)
	sectors.sort()
	for sector in sectors:
		var button := Button.new()
		button.text = SmaKit.sector_label(String(sector))
		button.focus_mode = Control.FOCUS_NONE
		button.clip_text = true
		button.custom_minimum_size.y = 36
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 11)
		button.tooltip_text = I18n.t("market.heatmapTooltip", {
			"sector": SmaKit.sector_label(String(sector))})
		button.pressed.connect(_on_heatmap_sector.bind(String(sector)))
		grid.add_child(button)
		_heat_tiles[String(sector)] = button
		_heat_buckets[String(sector)] = -999
		_apply_heat_style(button, 0.0)
	return card


func _update_heatmap() -> void:
	if _heat_tiles.is_empty() or game == null or game.exchange == null:
		return
	var totals: Dictionary = {}
	var counts: Dictionary = {}
	for ticker in _rows.keys():
		var sector := String(_rows[ticker]["sector"])
		var quote: Dictionary = game.exchange.quote(String(ticker))
		totals[sector] = float(totals.get(sector, 0.0)) \
			+ float(quote.get("changePct", 0.0))
		counts[sector] = int(counts.get(sector, 0)) + 1
	for sector in _heat_tiles.keys():
		var count := int(counts.get(sector, 0))
		var average := 0.0
		if count > 0:
			average = float(totals.get(sector, 0.0)) / float(count)
		var button: Button = _heat_tiles[sector]
		button.text = "%s  %s" % [SmaKit.sector_label(String(sector)),
			SmaFormat.pct(average, 2) if count > 0 else "—"]
		button.add_theme_color_override("font_color",
			SmaUiTheme.TEXT if count == 0 else SmaKit.value_color(average))
		var bucket := int(round(average * 2.0))
		if int(_heat_buckets.get(sector, -999)) != bucket:
			_heat_buckets[sector] = bucket
			_apply_heat_style(button, average)


func _apply_heat_style(button: Button, average: float) -> void:
	var tint := SmaUiTheme.PANEL_ALT
	if average > 0.01:
		tint = SmaUiTheme.PANEL.lerp(SmaUiTheme.POSITIVE,
			clampf(average / 4.0, 0.14, 0.48))
	elif average < -0.01:
		tint = SmaUiTheme.PANEL.lerp(SmaUiTheme.NEGATIVE,
			clampf(-average / 4.0, 0.14, 0.48))
	if SmaUiTheme.is_pixel():
		var hi := tint.lightened(0.28)
		var ledge := tint.darkened(0.45)
		button.add_theme_stylebox_override("normal", SmaPixelArt.button_box(tint, hi, ledge, 5, false))
		button.add_theme_stylebox_override("hover", SmaPixelArt.button_box(tint.lightened(0.1), Color.WHITE, ledge, 5, false))
		button.add_theme_stylebox_override("pressed", SmaPixelArt.button_box(tint, hi, ledge, 5, true))
		return
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.border_color = SmaUiTheme.BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(5)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = tint.lightened(0.08)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)


func _on_heatmap_sector(sector: String) -> void:
	var index := _sector_values.find(sector)
	if index < 0:
		return
	_sector_filter.select(index)
	_apply_filter()


func refresh(_reason: String = "") -> void:
	_update_rows()
	_apply_filter()
	_apply_sort()


func on_tick() -> void:
	_update_rows()


func _update_rows() -> void:
	if game == null or not game.started or game.exchange == null:
		if _count_label != null:
			_count_label.text = I18n.t("start.no_save")
		if _index_label != null:
			_index_label.text = "—"
			_index_change.text = "—"
		return
	if _index_label != null:
		var index_change := float(game.market_index_change())
		_index_label.text = SmaFormat.num(float(game.market_index()), 2)
		_index_change.text = SmaFormat.pct(index_change, 2)
		_index_change.add_theme_color_override("font_color", SmaKit.value_color(index_change))
	_update_heatmap()
	var visible_count := 0
	var locked_count := 0
	for ticker in _rows.keys():
		var entry: Dictionary = _rows[ticker]
		var panel: PanelContainer = entry["panel"]
		var watch_button: Button = entry["watch"]
		var watched: bool = game.is_watched(String(ticker))
		var watch_text := "★" if watched else "☆"
		if watch_button.text != watch_text:
			watch_button.text = watch_text
			watch_button.add_theme_color_override("font_color",
				SmaUiTheme.ACCENT if watched else SmaUiTheme.MUTED)
			watch_button.tooltip_text = I18n.t(
				"market.watchRemove" if watched else "market.watchAdd",
				{"ticker": ticker})
		if not panel.visible:
			continue
		visible_count += 1
		var lock: Dictionary = game.market_lock_info(ticker)
		var locked := bool(lock.get("locked", false))
		entry["locked"] = locked
		if locked:
			locked_count += 1
		panel.modulate = Color(1, 1, 1, 0.55) if locked else Color.WHITE
		panel.tooltip_text = "" if not locked else I18n.t("market.lockedHint", {
			"unit": I18n.t(String(lock.get("unitTitleKey", ""))),
		})
		var quote: Dictionary = game.exchange.quote(ticker)
		var cells: Dictionary = entry["cells"]
		var change := float(quote.get("changePct", 0.0))
		var last := float(quote.get("last", 0.0))
		var spark: SmaSparkline = entry.get("spark", null)
		var badge_rect: TextureRect = entry.get("badge", null)
		if badge_rect != null:
			badge_rect.texture = SmaPixelArt.ticker_badge(String(ticker), String(entry["sector"]), locked)
		if locked:
			cells["ticker"].text = ticker if badge_rect != null else ("🔒 %s" % ticker)
			cells["last"].text = "—"
			cells["change"].text = I18n.t("market.locked")
			cells["change"].add_theme_color_override("font_color", SmaUiTheme.DIM)
			cells["bid"].text = "—"
			cells["ask"].text = "—"
			cells["volume"].text = "—"
			if spark != null:
				spark.visible = false
			continue
		if spark != null:
			spark.visible = true
			var bars: Array = game.exchange.get_candles(ticker, "1D")
			var closes: Array = []
			var start_idx := maxi(0, bars.size() - 20)
			for bi in range(start_idx, bars.size()):
				closes.append(float(bars[bi].get("c", last)))
			closes.append(last)
			spark.set_values(closes, change >= 0.0)
		cells["ticker"].text = ticker
		cells["last"].text = SmaFormat.num(last, 2)
		var arrow := ("▲ " if change > 0.0 else ("▼ " if change < 0.0 else "")) if SmaUiTheme.is_pixel() else ""
		cells["change"].text = arrow + SmaFormat.pct(change, 2)
		cells["change"].add_theme_color_override("font_color", SmaKit.value_color(change))
		var bid: Variant = quote.get("bid", null)
		var ask: Variant = quote.get("ask", null)
		cells["bid"].text = SmaFormat.num(float(bid), 2) if bid != null else "—"
		cells["ask"].text = SmaFormat.num(float(ask), 2) if ask != null else "—"
		cells["volume"].text = SmaFormat.compact(float(quote.get("volume", 0)))
	if _count_label != null:
		var count_text := "%d / %d · %s %d" % [visible_count, _rows.size(),
			I18n.t("market.lockedCount"), locked_count]
		if _watch_only != null and _watch_only.button_pressed and visible_count == 0:
			count_text = I18n.t("market.watchEmpty")
		_count_label.text = count_text


func _apply_filter() -> void:
	var query := _search.text.strip_edges().to_lower() if _search != null else ""
	var sector := ""
	var selected := _sector_filter.selected if _sector_filter != null else 0
	if selected > 0 and selected < _sector_values.size():
		sector = _sector_values[selected]
	var watch_only := _watch_only != null and _watch_only.button_pressed
	var companies := SmaCompanyCatalog.load_companies()
	var etfs := SmaEtfs.instruments()
	for ticker in _rows.keys():
		var symbol := String(ticker)
		var company: Dictionary = companies.get(symbol, etfs.get(symbol, {}))
		var matches_query: bool = query == "" or symbol.to_lower().contains(query) \
			or String(company.get("name", "")).to_lower().contains(query)
		var matches_sector: bool = sector == "" or String(company.get("sector", "")) == sector
		var matches_watch: bool = not watch_only or game.is_watched(symbol)
		_rows[symbol]["panel"].visible = matches_query and matches_sector and matches_watch
	_update_rows()


func _on_watch_pressed(ticker: String) -> void:
	if game == null:
		return
	game.toggle_watch(ticker)
	_apply_filter()


func _on_row_input(event: InputEvent, ticker: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var lock: Dictionary = game.market_lock_info(ticker)
		if bool(lock.get("locked", false)):
			var account: Dictionary = game.exchange.state["account"]
			var held := int(account.get("positions", {}).get(ticker, {}).get("qty", 0)) \
				+ int(account.get("shorts", {}).get(ticker, {}).get("qty", 0))
			if held <= 0:
				game.toast(I18n.t("market.lockedToast", {
					"ticker": ticker,
					"unit": I18n.t(String(lock.get("unitTitleKey", ""))),
				}))
				return
		game.select_ticker(ticker)
		var main := get_tree().get_first_node_in_group("main")
		if main != null and main.has_method("navigate"):
			if SmaEtfs.is_etf(ticker):
				main.navigate("etf")
				if main._screens.has("etf"):
					main._screens["etf"]._selected = ticker
					main._screens["etf"].refresh()
			else:
				main.navigate("trade")
