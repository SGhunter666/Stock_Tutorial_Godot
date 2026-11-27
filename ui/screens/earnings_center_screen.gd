## Earnings center: 400-filings/year formal coverage overview, K-line reaction
## research chart, upcoming reporting calendar, recent results with multi-factor
## pricing attribution ("Why good earnings can still drop"), and 8-quarter
## per-company financial history.
class_name SmaEarningsCenterScreen
extends SmaScreen

var _body: VBoxContainer
var _selected_ticker := ""
var _ticker_option: OptionButton
var _research_chart: SmaCandleChart
var _research_quote: Label


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
	_research_chart = null
	if game == null or not game.started:
		return
	_ensure_ticker()
	_render_header()
	_render_coverage_banner()
	_render_research()
	_render_recent()
	_render_upcoming()
	_render_history()


func _ensure_ticker() -> void:
	var companies := SmaCompanyCatalog.load_companies()
	var preferred := String(game.selected_ticker)
	if companies.has(preferred):
		_selected_ticker = preferred
		return
	if companies.has(_selected_ticker):
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


func _render_coverage_banner() -> void:
	var cov := SmaFundamentals.filing_coverage(game.get_day())
	var card := SmaKit.card(12)
	var box := SmaKit.vbox(4)
	card.add_child(box)
	box.add_child(SmaKit.label(I18n.t("earnings.coverageTitle"), 14, SmaUiTheme.ACCENT))
	var stats_lbl := SmaKit.label(I18n.t("earnings.coverageStats", {
		"companies": int(cov.get("companies", 100)),
		"perYear": int(cov.get("perYear", 400)),
		"released": int(cov.get("releasedFilings", 700)),
		"total": int(cov.get("totalModeledFilings", 4900)),
	}), 12, SmaUiTheme.GOLD)
	stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(stats_lbl)
	var note_lbl := SmaKit.muted(I18n.t("earnings.coverageNote"), 11)
	note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note_lbl)
	_body.add_child(card)


func _latest_earnings_for(ticker: String) -> Dictionary:
	if game.exchange == null or ticker.is_empty():
		return {}
	var cs: Dictionary = game.exchange.state.get("companies", {}).get(ticker, {})
	var live: Variant = cs.get("lastEarnings", null)
	if live is Dictionary and not (live as Dictionary).is_empty():
		return live
	var seed_str := String(game.exchange.state.get("seed", "sim-exchange-v1"))
	var latest_q := SmaFundamentals.latest_quarter(game.get_day(), ticker)
	return SmaEarnings.historical_event(ticker, latest_q, seed_str)


func _reason_color(item: Dictionary) -> Color:
	var reason := String(item.get("reactionReason", "inlineDigest"))
	var surprise := float(item.get("surprisePct", 0.0))
	var impact := float(item.get("pct", 0.0))
	if (surprise >= 2.0 and impact < 0.0) or (surprise <= -2.0 and impact > 0.0):
		return SmaUiTheme.GOLD
	if reason in ["beatAndRaise", "solidBeat", "badNewsPricedIn"]:
		return SmaKit.value_color(1.0)
	if reason in ["inlineDigest"]:
		return SmaUiTheme.MUTED
	return SmaKit.value_color(-1.0)


func _render_research() -> void:
	var card := SmaKit.card(12)
	var box := SmaKit.vbox(8)
	card.add_child(box)
	var controls := SmaKit.flow(8)
	controls.add_child(SmaKit.label(I18n.t("earnings.research"), 15))
	var companies := SmaCompanyCatalog.load_companies()
	var tickers := companies.keys()
	tickers.sort()
	_ticker_option = OptionButton.new()
	_ticker_option.custom_minimum_size.x = 200
	for index in tickers.size():
		var ticker := String(tickers[index])
		_ticker_option.add_item("%s · %s" % [ticker, String(companies[ticker].get("name", ticker))])
		_ticker_option.set_item_metadata(index, ticker)
		if ticker == _selected_ticker:
			_ticker_option.select(index)
	_ticker_option.item_selected.connect(_on_ticker_changed)
	controls.add_child(_ticker_option)
	var timeframe_picker := OptionButton.new()
	for timeframe: String in SmaMinuteSeries.CHART_TIMEFRAMES:
		timeframe_picker.add_item(timeframe)
	timeframe_picker.select(SmaMinuteSeries.CHART_TIMEFRAMES.find(game.chart_timeframe()))
	timeframe_picker.item_selected.connect(func(index):
		game.set_chart_timeframe(SmaMinuteSeries.CHART_TIMEFRAMES[index]))
	controls.add_child(timeframe_picker)
	controls.add_child(SmaKit.button(I18n.t("earnings.tradeSelected"), _go_trade, true))
	box.add_child(controls)
	_research_quote = SmaKit.muted("")
	box.add_child(_research_quote)
	var latest_ev := _latest_earnings_for(_selected_ticker)
	if not latest_ev.is_empty():
		var reason := String(latest_ev.get("reactionReason", "inlineDigest"))
		var driver_lbl := SmaKit.label(I18n.t("earnings.researchDriver", {
			"period": String(latest_ev.get("periodLabel", "")),
			"eps": SmaFormat.num(float(latest_ev.get("eps", 0.0)), 2),
			"expected": SmaFormat.num(float(latest_ev.get("expectedEps", 0.0)), 2),
			"surprise": SmaFormat.pct(float(latest_ev.get("surprisePct", 0.0)), 1),
			"runup": SmaFormat.pct(float(latest_ev.get("preRunupPct", 0.0)), 1),
			"guidance": I18n.t("earnings.guidance.%s" % String(
				latest_ev.get("guidance", "maintain"))),
			"pct": SmaFormat.pct(float(latest_ev.get("pct", 0.0)), 1),
			"reasonDesc": I18n.t("earnings.reasonDesc.%s" % reason),
		}), 11, _reason_color(latest_ev))
		driver_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(driver_lbl)
	_research_chart = SmaCandleChart.new()
	_research_chart.custom_minimum_size.y = 195
	box.add_child(_research_chart)
	_body.add_child(card)
	on_tick()


func on_tick() -> void:
	if _research_chart == null or _selected_ticker.is_empty():
		return
	var timeframe: String = game.chart_timeframe()
	var quote: Dictionary = game.exchange.quote(_selected_ticker)
	_research_quote.text = "%s · %s · %s" % [_selected_ticker, timeframe,
		SmaFormat.money(float(quote.get("last", 0.0)))]
	var title := "%s · %s" % [_selected_ticker, timeframe]
	if timeframe == "1m":
		title += " · " + I18n.t("chart.referenceQuote")
	_research_chart.set_candles(game.exchange.get_candles(_selected_ticker, timeframe), timeframe, title)


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
	var live_results: Array = []
	for item in game.news_items():
		if String(item.get("kind", "")) == "earnings":
			live_results.append(item)
	var results: Array = []
	if live_results.size() < 18 and game.exchange != null:
		var seed_str := String(game.exchange.state.get("seed", "sim-exchange-v1"))
		var hist := SmaEarnings.recent_historical(game.get_day(), seed_str, 18 - live_results.size())
		results.append_array(hist)
	results.append_array(live_results)
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
				"earnings.guidance", "earnings.impact", "earnings.reason"],
			[0.85, 1.45, 0.75, 0.7, 0.7, 0.75, 0.65, 0.75, 1.35],
			[HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_LEFT,
				HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_RIGHT,
				HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT,
				HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT,
				HORIZONTAL_ALIGNMENT_LEFT]))
		for index in range(results.size() - 1, -1, -1):
			box.add_child(_recent_row(results[index]))
	_body.add_child(card)


func _recent_row(item: Dictionary) -> Control:
	var ticker := String(item.get("ticker", ""))
	var company := SmaCompanyCatalog.get_company(ticker)
	var surprise := float(item.get("surprisePct", 0.0))
	var impact := float(item.get("pct", 0.0))
	var reason := String(item.get("reactionReason", "inlineDigest"))
	var row := SmaKit.hbox(6)
	row.add_child(SmaKit.cell(SmaCalendar.iso_date(int(item.get("day", 0))),
		0.85, HORIZONTAL_ALIGNMENT_LEFT, SmaUiTheme.MUTED))
	var ticker_btn := SmaKit.button("%s · %s" % [ticker,
		String(company.get("name", ticker))], func():
			game.set_chart_timeframe("1D")
			game.select_ticker(ticker))
	ticker_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ticker_btn.size_flags_stretch_ratio = 1.45
	SmaKit.set_small_font(ticker_btn, 11)
	row.add_child(ticker_btn)
	row.add_child(SmaKit.cell(String(item.get("periodLabel", "")), 0.75,
		HORIZONTAL_ALIGNMENT_LEFT, SmaUiTheme.MUTED))
	row.add_child(SmaKit.cell(SmaFormat.num(float(item.get("eps", 0.0)), 2),
		0.7, HORIZONTAL_ALIGNMENT_RIGHT))
	row.add_child(SmaKit.cell(SmaFormat.num(float(item.get("expectedEps", 0.0)), 2),
		0.7, HORIZONTAL_ALIGNMENT_RIGHT, SmaUiTheme.MUTED))
	row.add_child(SmaKit.cell(SmaFormat.pct(surprise, 1), 0.75,
		HORIZONTAL_ALIGNMENT_RIGHT, SmaKit.value_color(surprise)))
	row.add_child(SmaKit.cell(I18n.t("earnings.guidance.%s" % String(
		item.get("guidance", "maintain"))), 0.65, HORIZONTAL_ALIGNMENT_CENTER))
	row.add_child(SmaKit.cell(SmaFormat.pct(impact, 1), 0.75,
		HORIZONTAL_ALIGNMENT_RIGHT, SmaKit.value_color(impact)))
	var reason_cell := SmaKit.cell(I18n.t("earnings.reasonShort.%s" % reason),
		1.35, HORIZONTAL_ALIGNMENT_LEFT, _reason_color(item))
	reason_cell.tooltip_text = I18n.t("earnings.reasonDesc.%s" % reason)
	row.add_child(reason_cell)
	return row


func _render_history() -> void:
	var card := SmaKit.card(12)
	var box := SmaKit.vbox(6)
	card.add_child(box)
	var header := SmaKit.hbox(8)
	header.add_child(SmaKit.label(I18n.t("earnings.historyTitle"), 15))
	header.add_child(SmaKit.muted(_selected_ticker))
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
	game.select_ticker(String(_ticker_option.get_item_metadata(index)))


func _go_news() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("navigate"):
		main.navigate("news")


func _go_statements() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("open_ticker"):
		main.open_ticker(_selected_ticker, "statements")


func _go_trade() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("open_ticker"):
		main.open_ticker(_selected_ticker)
