## Market overview: every listed company with live simulated quotes. Clicking a
## row selects it and moves to the trading desk.
class_name SmaMarketScreen
extends SmaScreen

var _rows: Dictionary = {}
var _search: LineEdit
var _sector_filter: OptionButton
var _sector_values: Array[String] = [""]
var _list: VBoxContainer
var _count_label: Label
var _index_label: Label
var _index_change: Label


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
	filters.add_child(SmaKit.hspacer())
	_count_label = SmaKit.muted("")
	filters.add_child(_count_label)
	root.add_child(filters)

	var table_card := SmaKit.card(0)
	table_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var table := SmaKit.vbox(0)
	table_card.add_child(table)
	var header := SmaKit.header_row(
		["market.ticker", "market.company", "market.sector", "market.last",
			"market.change", "market.bid", "market.ask", "market.volume"],
		[0.7, 2.1, 1.0, 0.9, 0.9, 0.8, 0.8, 1.0],
		[HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_LEFT,
			HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT,
			HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT])
	var header_texts: Array = header.get_children()
	for index in header_texts.size():
		var label: Label = header_texts[index]
		label.text = I18n.t(label.text)
	header.custom_minimum_size.y = 30
	table.add_child(header)

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
	var cells := {
		"ticker": SmaKit.cell(ticker, 0.7),
		"name": SmaKit.cell(String(company.get("name", ticker)), 2.1),
		"sector": SmaKit.cell(SmaKit.sector_label(String(company.get("sector", ""))), 1.0, HORIZONTAL_ALIGNMENT_LEFT, SmaUiTheme.MUTED),
		"last": SmaKit.cell("—", 0.9, HORIZONTAL_ALIGNMENT_RIGHT),
		"change": SmaKit.cell("—", 0.9, HORIZONTAL_ALIGNMENT_RIGHT),
		"bid": SmaKit.cell("—", 0.8, HORIZONTAL_ALIGNMENT_RIGHT),
		"ask": SmaKit.cell("—", 0.8, HORIZONTAL_ALIGNMENT_RIGHT),
		"volume": SmaKit.cell("—", 1.0, HORIZONTAL_ALIGNMENT_RIGHT, SmaUiTheme.MUTED),
	}
	for key in ["ticker", "name", "sector", "last", "change", "bid", "ask", "volume"]:
		row.add_child(cells[key])
	_list.add_child(panel)
	_rows[ticker] = {"panel": panel, "cells": cells, "sector": sector,
		"is_etf": is_etf, "locked": false}


func refresh(_reason: String = "") -> void:
	_update_rows()
	_apply_filter()


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
	var visible_count := 0
	var locked_count := 0
	for ticker in _rows.keys():
		var entry: Dictionary = _rows[ticker]
		var panel: PanelContainer = entry["panel"]
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
		if locked:
			cells["last"].text = "—"
			cells["change"].text = I18n.t("market.locked")
			cells["change"].add_theme_color_override("font_color", SmaUiTheme.DIM)
			cells["bid"].text = "—"
			cells["ask"].text = "—"
			cells["volume"].text = "—"
			continue
		cells["last"].text = SmaFormat.num(last, 2)
		cells["change"].text = SmaFormat.pct(change, 2)
		cells["change"].add_theme_color_override("font_color", SmaKit.value_color(change))
		var bid: Variant = quote.get("bid", null)
		var ask: Variant = quote.get("ask", null)
		cells["bid"].text = SmaFormat.num(float(bid), 2) if bid != null else "—"
		cells["ask"].text = SmaFormat.num(float(ask), 2) if ask != null else "—"
		cells["volume"].text = SmaFormat.compact(float(quote.get("volume", 0)))
	if _count_label != null:
		_count_label.text = "%d / %d · %s %d" % [visible_count, _rows.size(),
			I18n.t("market.lockedCount"), locked_count]


func _apply_filter() -> void:
	var query := _search.text.strip_edges().to_lower() if _search != null else ""
	var sector := ""
	var selected := _sector_filter.selected if _sector_filter != null else 0
	if selected > 0 and selected < _sector_values.size():
		sector = _sector_values[selected]
	var companies := SmaCompanyCatalog.load_companies()
	var etfs := SmaEtfs.instruments()
	for ticker in _rows.keys():
		var symbol := String(ticker)
		var company: Dictionary = companies.get(symbol, etfs.get(symbol, {}))
		var matches_query: bool = query == "" or symbol.to_lower().contains(query) \
			or String(company.get("name", "")).to_lower().contains(query)
		var matches_sector: bool = sector == "" or String(company.get("sector", "")) == sector
		_rows[symbol]["panel"].visible = matches_query and matches_sector
	_update_rows()


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
