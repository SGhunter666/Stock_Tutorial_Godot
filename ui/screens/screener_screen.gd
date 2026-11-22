## Stock screener: filter the simulated universe by sector, liquidity,
## valuation, dividend yield, market cap and today's move. Filters persist in
## the save file so the desk opens with the same screen next time.
class_name SmaScreenerScreen
extends SmaScreen

const DEFAULT_FILTERS := {
	"sector": "", "liquidity": "", "peMax": 0.0, "yieldMin": 0.0,
	"capMinB": 0.0, "changeMin": -100.0, "sort": "marketCap", "query": "",
}

var _body: VBoxContainer
var _sector_option: OptionButton
var _liquidity_option: OptionButton
var _pe_spin: SpinBox
var _yield_spin: SpinBox
var _cap_spin: SpinBox
var _change_spin: SpinBox
var _sort_option: OptionButton
var _search: LineEdit
var _results_box: VBoxContainer
var _count_label: Label
var _rows: Dictionary = {}
var _filters: Dictionary = DEFAULT_FILTERS.duplicate(true)


func _build() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var root := SmaKit.vbox(10)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var scroll := SmaKit.scroll()
	root.add_child(scroll)
	_body = SmaKit.vbox(12)
	scroll.add_child(_body)
	_filters = _stored_filters()
	_render_header()
	_render_filters()
	_render_results()


func refresh(_reason: String = "") -> void:
	if not built:
		return
	_filters = _stored_filters()
	_populate_results()


func on_tick() -> void:
	if game == null or game.exchange == null:
		return
	for ticker in _rows.keys():
		var labels: Dictionary = _rows[ticker]
		var quote: Dictionary = game.exchange.quote(String(ticker))
		var change := float(quote.get("changePct", 0.0))
		labels["last"].text = SmaFormat.money(float(quote.get("last", 0.0)))
		labels["change"].text = SmaFormat.pct(change, 2)
		labels["change"].add_theme_color_override("font_color",
			SmaKit.value_color(change))


func _render_header() -> void:
	var header := SmaKit.hbox(10)
	var title_box := SmaKit.vbox(2)
	title_box.add_child(SmaKit.label(I18n.t("screener.title"), 22))
	title_box.add_child(SmaKit.muted(I18n.t("screener.subtitle"), 12))
	header.add_child(title_box)
	header.add_child(SmaKit.hspacer())
	header.add_child(SmaKit.button(I18n.t("screener.reset"), _reset))
	header.add_child(SmaKit.button(I18n.t("screener.apply"), _apply, true))
	_body.add_child(header)


func _render_filters() -> void:
	var card := SmaKit.card(12)
	var box := SmaKit.vbox(8)
	card.add_child(box)
	box.add_child(SmaKit.label(I18n.t("screener.filtersTitle"), 14))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	_sector_option = OptionButton.new()
	_sector_option.add_item(I18n.t("screener.allSectors"))
	_sector_option.set_item_metadata(0, "")
	var sectors: Array = SmaCompanyCatalog.sectors()
	sectors.sort()
	for sector in sectors:
		_sector_option.add_item(SmaKit.sector_label(String(sector)))
		_sector_option.set_item_metadata(_sector_option.item_count - 1, String(sector))
	grid.add_child(_filter_cell("screener.sector", _sector_option))
	_liquidity_option = OptionButton.new()
	var liquidities := [["", "screener.allLiquidity"], ["deep", "screener.deep"],
		["normal", "screener.normal"], ["thin", "screener.thin"]]
	for entry in liquidities:
		_liquidity_option.add_item(I18n.t(String(entry[1])))
		_liquidity_option.set_item_metadata(_liquidity_option.item_count - 1,
			String(entry[0]))
	grid.add_child(_filter_cell("screener.liquidity", _liquidity_option))
	_pe_spin = _spin(0.0, 500.0, 1.0)
	grid.add_child(_filter_cell("screener.peMax", _pe_spin))
	_yield_spin = _spin(0.0, 50.0, 0.1)
	grid.add_child(_filter_cell("screener.yieldMin", _yield_spin))
	_cap_spin = _spin(0.0, 5000.0, 1.0)
	grid.add_child(_filter_cell("screener.capMin", _cap_spin))
	_change_spin = _spin(-100.0, 100.0, 0.1)
	grid.add_child(_filter_cell("screener.changeMin", _change_spin))
	_sort_option = OptionButton.new()
	var sorts := [["marketCap", "screener.sortCap"], ["change", "screener.sortChange"],
		["yield", "screener.sortYield"], ["pe", "screener.sortPe"],
		["ticker", "screener.sortTicker"]]
	for entry in sorts:
		_sort_option.add_item(I18n.t(String(entry[1])))
		_sort_option.set_item_metadata(_sort_option.item_count - 1, String(entry[0]))
	grid.add_child(_filter_cell("screener.sort", _sort_option))
	_search = LineEdit.new()
	_search.placeholder_text = I18n.t("screener.search")
	_search.text_changed.connect(func(_text): _populate_results())
	grid.add_child(_filter_cell("screener.searchLabel", _search))
	_load_controls()
	_body.add_child(card)


func _filter_cell(label_key: String, control: Control) -> Control:
	var cell := SmaKit.vbox(2)
	cell.add_child(SmaKit.caption(I18n.t(label_key)))
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_child(control)
	return cell


func _spin(minimum: float, maximum: float, step: float) -> SpinBox:
	var node := SpinBox.new()
	node.min_value = minimum
	node.max_value = maximum
	node.step = step
	node.custom_minimum_size.x = 120
	return node


func _render_results() -> void:
	var card := SmaKit.card(12)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := SmaKit.vbox(5)
	card.add_child(box)
	var title_row := SmaKit.hbox(8)
	title_row.add_child(SmaKit.label(I18n.t("screener.resultsTitle"), 14))
	title_row.add_child(SmaKit.hspacer())
	_count_label = SmaKit.muted("", 11)
	title_row.add_child(_count_label)
	box.add_child(title_row)
	_results_box = SmaKit.vbox(3)
	box.add_child(_results_box)
	_body.add_child(card)
	_populate_results()


func _populate_results() -> void:
	if _results_box == null:
		return
	SmaKit.clear_children(_results_box)
	_rows.clear()
	if game == null or not game.started or game.exchange == null:
		return
	_filters = _current_filters()
	var rows: Array = _matching_rows(_filters)
	rows.sort_custom(_compare_rows.bind(String(_filters.get("sort", "marketCap"))))
	if _count_label != null:
		_count_label.text = I18n.t("screener.resultCount", {
			"shown": rows.size(), "total": SmaCompanyCatalog.load_companies().size()})
	if rows.is_empty():
		_results_box.add_child(SmaKit.muted(I18n.t("screener.empty"), 12))
		return
	_results_box.add_child(SmaKit.header_row(
		["watchlist.ticker", "watchlist.company", "watchlist.sector",
			"watchlist.last", "watchlist.change", "screener.pe",
			"screener.yield", "screener.marketCap", "", ""],
		[0.7, 1.8, 1.0, 0.9, 0.9, 0.6, 0.7, 0.9, 0.5, 0.6],
		[HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_LEFT,
			HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_RIGHT,
			HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT,
			HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT,
			HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_CENTER]))
	for entry in rows:
		_results_box.add_child(_result_row(entry))


func _matching_rows(filters: Dictionary) -> Array:
	var companies := SmaCompanyCatalog.load_companies()
	var result: Array = []
	var sector_filter := String(filters.get("sector", ""))
	var liquidity_filter := String(filters.get("liquidity", ""))
	var query := String(filters.get("query", "")).strip_edges().to_lower()
	var pe_max := float(filters.get("peMax", 0.0))
	var yield_min := float(filters.get("yieldMin", 0.0))
	var cap_min := float(filters.get("capMinB", 0.0))
	var change_min := float(filters.get("changeMin", -100.0))
	for ticker in companies.keys():
		var symbol := String(ticker)
		var company: Dictionary = companies[ticker]
		if sector_filter != "" and String(company.get("sector", "")) != sector_filter:
			continue
		if liquidity_filter != "" and String(company.get("liquidity", "")) != liquidity_filter:
			continue
		if query != "" and not symbol.to_lower().contains(query) \
				and not String(company.get("name", "")).to_lower().contains(query):
			continue
		var financials: Dictionary = company.get("financials", {})
		var pe := _number(financials.get("pe", 0.0))
		if pe_max > 0.0 and (pe <= 0.0 or pe > pe_max):
			continue
		var quote: Dictionary = game.exchange.quote(symbol)
		var last := float(quote.get("last", 0.0))
		var change := float(quote.get("changePct", 0.0))
		if change < change_min:
			continue
		var dividend := _number(financials.get("dividendPerShare", 0.0))
		var yield_pct := dividend / last * 100.0 if last > 0.0 else 0.0
		if yield_min > 0.0 and yield_pct < yield_min:
			continue
		var cap_b := _number(company.get("marketCap", 0.0)) / 1000000000.0
		if cap_min > 0.0 and cap_b < cap_min:
			continue
		result.append({
			"ticker": symbol, "name": String(company.get("name", symbol)),
			"sector": String(company.get("sector", "")), "last": last,
			"change": change, "pe": pe, "yield": yield_pct, "capB": cap_b,
		})
	return result


func _compare_rows(a: Dictionary, b: Dictionary, sort_key: String) -> bool:
	match sort_key:
		"change":
			return float(a["change"]) > float(b["change"])
		"yield":
			return float(a["yield"]) > float(b["yield"])
		"pe":
			var a_pe := float(a["pe"])
			var b_pe := float(b["pe"])
			if a_pe <= 0.0:
				return false
			if b_pe <= 0.0:
				return true
			return a_pe < b_pe
		"ticker":
			return String(a["ticker"]) < String(b["ticker"])
		_:
			if absf(float(a["capB"]) - float(b["capB"])) < 0.0001:
				return String(a["ticker"]) < String(b["ticker"])
			return float(a["capB"]) > float(b["capB"])


func _result_row(entry: Dictionary) -> Control:
	var ticker := String(entry["ticker"])
	var row := SmaKit.hbox(8)
	var ticker_cell := SmaKit.cell(ticker, 0.7)
	ticker_cell.add_theme_color_override("font_color", SmaUiTheme.ACCENT)
	row.add_child(ticker_cell)
	row.add_child(SmaKit.cell(String(entry["name"]), 1.8))
	row.add_child(SmaKit.cell(SmaKit.sector_label(String(entry["sector"])), 1.0,
		HORIZONTAL_ALIGNMENT_LEFT, SmaUiTheme.MUTED))
	var last_cell := SmaKit.cell(SmaFormat.money(float(entry["last"])), 0.9,
		HORIZONTAL_ALIGNMENT_RIGHT)
	var change := float(entry["change"])
	var change_cell := SmaKit.cell(SmaFormat.pct(change, 2), 0.9,
		HORIZONTAL_ALIGNMENT_RIGHT, SmaKit.value_color(change))
	row.add_child(last_cell)
	row.add_child(change_cell)
	var pe := float(entry["pe"])
	row.add_child(SmaKit.cell(SmaFormat.num(pe, 1) if pe > 0.0 else "—", 0.6,
		HORIZONTAL_ALIGNMENT_RIGHT))
	row.add_child(SmaKit.cell(SmaFormat.pct(float(entry["yield"]), 2), 0.7,
		HORIZONTAL_ALIGNMENT_RIGHT))
	row.add_child(SmaKit.cell("%s B" % SmaFormat.num(float(entry["capB"]), 1), 0.9,
		HORIZONTAL_ALIGNMENT_RIGHT, SmaUiTheme.MUTED))
	var watch_button := SmaKit.button("★" if game.is_watched(ticker) else "☆",
		_toggle_watch.bind(ticker))
	watch_button.custom_minimum_size.x = 34
	row.add_child(watch_button)
	var trade_button := SmaKit.button(I18n.t("watchlist.trade"),
		_open_ticker.bind(ticker))
	trade_button.custom_minimum_size.x = 62
	row.add_child(trade_button)
	_rows[ticker] = {"last": last_cell, "change": change_cell}
	return row


func _stored_filters() -> Dictionary:
	var filters := DEFAULT_FILTERS.duplicate(true)
	if game == null:
		return filters
	var stored: Variant = game.settings.get("screener", {})
	if typeof(stored) != TYPE_DICTIONARY:
		return filters
	for key in filters.keys():
		if stored.has(key):
			filters[key] = stored[key]
	return filters


func _current_filters() -> Dictionary:
	return {
		"sector": _selected_metadata(_sector_option, ""),
		"liquidity": _selected_metadata(_liquidity_option, ""),
		"peMax": _pe_spin.value if _pe_spin != null else 0.0,
		"yieldMin": _yield_spin.value if _yield_spin != null else 0.0,
		"capMinB": _cap_spin.value if _cap_spin != null else 0.0,
		"changeMin": _change_spin.value if _change_spin != null else -100.0,
		"sort": _selected_metadata(_sort_option, "marketCap"),
		"query": _search.text if _search != null else "",
	}


func _load_controls() -> void:
	_select_metadata(_sector_option, String(_filters.get("sector", "")))
	_select_metadata(_liquidity_option, String(_filters.get("liquidity", "")))
	_select_metadata(_sort_option, String(_filters.get("sort", "marketCap")))
	_pe_spin.value = float(_filters.get("peMax", 0.0))
	_yield_spin.value = float(_filters.get("yieldMin", 0.0))
	_cap_spin.value = float(_filters.get("capMinB", 0.0))
	_change_spin.value = float(_filters.get("changeMin", -100.0))
	_search.text = String(_filters.get("query", ""))


func _apply() -> void:
	if game == null:
		return
	_filters = _current_filters()
	game.settings["screener"] = _filters.duplicate(true)
	game.save_game(false)
	_populate_results()
	game.toast(I18n.t("screener.applied"))


func _reset() -> void:
	_filters = DEFAULT_FILTERS.duplicate(true)
	_load_controls()
	if game != null:
		game.settings["screener"] = _filters.duplicate(true)
		game.save_game(false)
	_populate_results()


func _toggle_watch(ticker: String) -> void:
	if game == null:
		return
	game.toggle_watch(ticker)
	refresh("watchlist")


func _open_ticker(ticker: String) -> void:
	if game == null:
		return
	game.select_ticker(ticker)
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("navigate"):
		main.navigate("trade")


func _selected_metadata(option: OptionButton, fallback: String) -> String:
	if option == null or option.selected < 0:
		return fallback
	var value: Variant = option.get_item_metadata(option.selected)
	return String(value) if value != null else fallback


func _select_metadata(option: OptionButton, value: String) -> void:
	if option == null:
		return
	for index in option.item_count:
		if String(option.get_item_metadata(index)) == value:
			option.select(index)
			return
	option.select(0)


func _number(value: Variant) -> float:
	if value == null:
		return 0.0
	return float(value)
