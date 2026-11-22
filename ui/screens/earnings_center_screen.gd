## Earnings center: upcoming reporting dates, recent simulated results with
## surprise and guidance, and a per-company quarterly statement history.
class_name SmaEarningsCenterScreen
extends SmaScreen

var _body: VBoxContainer
var _selected_ticker := ""
var _ticker_option: OptionButton


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


func refresh(_reason: String = "") -> void:
	if not built:
		return
	SmaKit.clear_children(_body)
	_ticker_option = null
	if game == null or not game.started:
		return
	_ensure_ticker()
	_render_header()
	_render_upcoming()
	_render_recent()
	_render_history()


func _ensure_ticker() -> void:
	var companies := SmaCompanyCatalog.load_companies()
	if companies.has(_selected_ticker):
		return
	var preferred := String(game.selected_ticker) if game.selected_ticker != null else ""
	if companies.has(preferred):
		_selected_ticker = preferred
		return
	var tickers := companies.keys()
	tickers.sort()
	_selected_ticker = String(tickers[0]) if not tickers.is_empty() else ""


func _render_header() -> void:
	var header := SmaKit.hbox(10)
	var title_box := SmaKit.vbox(2)
	title_box.add_child(SmaKit.label(I18n.t("earnings.title"), 22))
	title_box.add_child(SmaKit.muted(I18n.t("earnings.subtitle"), 12))
	header.add_child(title_box)
	header.add_child(SmaKit.hspacer())
	header.add_child(SmaKit.button(I18n.t("earnings.openNews"), _go_news))
	header.add_child(SmaKit.button(I18n.t("earnings.openStatements"), _go_statements))
	_body.add_child(header)


func _render_upcoming() -> void:
	var rows: Array = game.earnings_calendar(8)
	var card := SmaKit.card(12)
	var box := SmaKit.vbox(5)
	card.add_child(box)
	box.add_child(SmaKit.label(I18n.t("earnings.upcomingTitle"), 15))
	box.add_child(SmaKit.muted(I18n.t("earnings.upcomingHint"), 10))
	if rows.is_empty():
		box.add_child(SmaKit.muted(I18n.t("earnings.noUpcoming"), 12))
	else:
		for row in rows:
			var names: Array = []
			var tickers: Array = row.get("tickers", [])
			for ticker in tickers:
				var company := SmaCompanyCatalog.get_company(String(ticker))
				names.append("%s %s" % [String(ticker),
					String(company.get("name", ""))])
			var shown := names.slice(0, 5)
			var extra := names.size() - shown.size()
			var text := ", ".join(PackedStringArray(shown))
			if extra > 0:
				text += " " + I18n.t("earnings.moreTickers", {"count": extra})
			box.add_child(SmaKit.muted(I18n.t("earnings.upcomingRow", {
				"date": SmaCalendar.iso_date(int(row.get("day", 0))),
				"period": String(row.get("periodLabel", "")),
				"tickers": text,
			}), 11))
	_body.add_child(card)


func _render_recent() -> void:
	var results: Array = []
	for item in game.news_items():
		if String(item.get("kind", "")) == "earnings":
			results.append(item)
	if results.size() > 20:
		results = results.slice(results.size() - 20)
	var card := SmaKit.card(12)
	var box := SmaKit.vbox(5)
	card.add_child(box)
	box.add_child(SmaKit.label(I18n.t("earnings.recentTitle"), 15))
	box.add_child(SmaKit.muted(I18n.t("earnings.recentHint"), 10))
	if results.is_empty():
		box.add_child(SmaKit.muted(I18n.t("earnings.noRecent"), 12))
	else:
		box.add_child(SmaKit.header_row(
			["earnings.date", "watchlist.ticker", "earnings.period",
				"earnings.eps", "earnings.expected", "earnings.surprise",
				"earnings.guidance", "earnings.impact"],
			[0.8, 1.6, 1.0, 0.8, 0.8, 0.8, 0.9, 0.8],
			[HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_LEFT,
				HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_RIGHT,
				HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT,
				HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT]))
		for index in range(results.size() - 1, -1, -1):
			box.add_child(_recent_row(results[index]))
	_body.add_child(card)


func _recent_row(item: Dictionary) -> Control:
	var ticker := String(item.get("ticker", ""))
	var company := SmaCompanyCatalog.get_company(ticker)
	var surprise := float(item.get("surprisePct", 0.0))
	var impact := float(item.get("pct", 0.0))
	var row := SmaKit.hbox(8)
	row.add_child(SmaKit.cell(SmaCalendar.iso_date(int(item.get("day", 0))),
		0.8, HORIZONTAL_ALIGNMENT_LEFT, SmaUiTheme.MUTED))
	var ticker_cell := SmaKit.cell("%s · %s" % [ticker,
		String(company.get("name", ticker))], 1.6)
	ticker_cell.add_theme_color_override("font_color", SmaUiTheme.ACCENT)
	row.add_child(ticker_cell)
	row.add_child(SmaKit.cell(String(item.get("periodLabel", "")), 1.0,
		HORIZONTAL_ALIGNMENT_LEFT, SmaUiTheme.MUTED))
	row.add_child(SmaKit.cell(SmaFormat.num(float(item.get("eps", 0.0)), 3),
		0.8, HORIZONTAL_ALIGNMENT_RIGHT))
	row.add_child(SmaKit.cell(SmaFormat.num(float(item.get("expectedEps", 0.0)), 3),
		0.8, HORIZONTAL_ALIGNMENT_RIGHT, SmaUiTheme.MUTED))
	row.add_child(SmaKit.cell(SmaFormat.pct(surprise, 1), 0.8,
		HORIZONTAL_ALIGNMENT_RIGHT, SmaKit.value_color(surprise)))
	row.add_child(SmaKit.cell(I18n.t("earnings.guidance.%s" % String(
		item.get("guidance", "maintain"))), 0.9, HORIZONTAL_ALIGNMENT_CENTER))
	row.add_child(SmaKit.cell(SmaFormat.pct(impact, 1), 0.8,
		HORIZONTAL_ALIGNMENT_RIGHT, SmaKit.value_color(impact)))
	return row


func _render_history() -> void:
	var card := SmaKit.card(12)
	var box := SmaKit.vbox(6)
	card.add_child(box)
	var header := SmaKit.hbox(8)
	header.add_child(SmaKit.label(I18n.t("earnings.historyTitle"), 15))
	header.add_child(SmaKit.hspacer())
	var companies := SmaCompanyCatalog.load_companies()
	var tickers := companies.keys()
	tickers.sort()
	_ticker_option = OptionButton.new()
	_ticker_option.custom_minimum_size.x = 220
	var selected_index := 0
	for index in tickers.size():
		var ticker := String(tickers[index])
		_ticker_option.add_item("%s · %s" % [ticker,
			String(companies[ticker].get("name", ticker))])
		_ticker_option.set_item_metadata(index, ticker)
		if ticker == _selected_ticker:
			selected_index = index
	_ticker_option.select(selected_index)
	_ticker_option.item_selected.connect(_on_ticker_changed)
	header.add_child(_ticker_option)
	box.add_child(header)
	var history: Array = SmaFundamentals.history(_selected_ticker, 8, game.get_day())
	if history.is_empty():
		box.add_child(SmaKit.muted(I18n.t("earnings.noHistory"), 12))
		_body.add_child(card)
		return
	box.add_child(SmaKit.header_row(
		["earnings.period", "earnings.reportDate", "earnings.revenue",
			"earnings.netIncome", "earnings.eps", "earnings.grossMargin",
			"earnings.roe", "earnings.freeCashFlow"],
		[1.0, 0.9, 1.0, 1.0, 0.7, 0.8, 0.7, 1.0],
		[HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_LEFT,
			HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT,
			HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT,
			HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT]))
	for report in history:
		box.add_child(_history_row(report))
	box.add_child(SmaKit.muted(I18n.t("earnings.disclaimer"), 10))
	_body.add_child(card)


func _history_row(report: Dictionary) -> Control:
	var income: Dictionary = report.get("income", {})
	var ratios: Dictionary = report.get("ratios", {})
	var cash_flow: Dictionary = report.get("cashFlow", {})
	var row := SmaKit.hbox(8)
	row.add_child(SmaKit.cell(String(report.get("periodLabel", "")), 1.0))
	row.add_child(SmaKit.cell(String(report.get("reportDate", "")), 0.9,
		HORIZONTAL_ALIGNMENT_LEFT, SmaUiTheme.MUTED))
	row.add_child(SmaKit.cell(SmaFormat.compact(float(income.get("revenue", 0.0))),
		1.0, HORIZONTAL_ALIGNMENT_RIGHT))
	row.add_child(SmaKit.cell(SmaFormat.compact(float(income.get("netIncome", 0.0))),
		1.0, HORIZONTAL_ALIGNMENT_RIGHT))
	row.add_child(SmaKit.cell(SmaFormat.num(float(income.get("eps", 0.0)), 3),
		0.7, HORIZONTAL_ALIGNMENT_RIGHT))
	row.add_child(SmaKit.cell(SmaFormat.pct(float(ratios.get("grossMargin", 0.0)) * 100.0,
		1), 0.8, HORIZONTAL_ALIGNMENT_RIGHT))
	row.add_child(SmaKit.cell(SmaFormat.pct(float(ratios.get("roe", 0.0)) * 100.0, 1),
		0.7, HORIZONTAL_ALIGNMENT_RIGHT))
	row.add_child(SmaKit.cell(SmaFormat.compact(float(cash_flow.get("freeCashFlow", 0.0))),
		1.0, HORIZONTAL_ALIGNMENT_RIGHT))
	return row


func _on_ticker_changed(index: int) -> void:
	if _ticker_option == null or index < 0:
		return
	_selected_ticker = String(_ticker_option.get_item_metadata(index))
	refresh("earnings")


func _go_news() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("navigate"):
		main.navigate("news")


func _go_statements() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("navigate"):
		main.navigate("statements")
