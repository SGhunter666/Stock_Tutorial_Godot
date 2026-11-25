## Deterministic simulated news feed with category/held filters, ticker jump
## buttons, earnings calendar and corporate actions / rights offerings.
class_name SmaNewsScreen
extends SmaScreen

var _body: VBoxContainer
var _filter := "all"


func _build() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var root := SmaKit.vbox(10)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var scroll := SmaKit.scroll()
	root.add_child(scroll)
	_body = SmaKit.vbox(10)
	scroll.add_child(_body)


func refresh(_reason: String = "") -> void:
	if not built:
		return
	SmaKit.clear_children(_body)
	if game == null or not game.started:
		return
	_render_header()
	_render_filters()
	_render_corporate()
	_render_earnings_calendar()
	var items := _filtered_items(game.news_items())
	if items.is_empty():
		_render_empty()
		return
	var start := maxi(0, items.size() - 40)
	for index in range(items.size() - 1, start - 1, -1):
		_body.add_child(_news_card(items[index]))
	_body.add_child(SmaKit.muted(I18n.t("news.disclaimer"), 10))


func _filtered_items(items: Array) -> Array:
	if _filter == "all":
		return items
	var account: Dictionary = game.exchange.state["account"] if game.exchange != null else {}
	var held_positions: Dictionary = account.get("positions", {})
	var held_shorts: Dictionary = account.get("shorts", {})
	var out: Array = []
	for item in items:
		var kind := String(item.get("kind", "company"))
		var ticker := String(item.get("ticker", ""))
		if _filter == "mine":
			var relevant: bool = ticker != "" and (
				game.is_watched(ticker)
				or int(held_positions.get(ticker, {}).get("qty", 0)) > 0
				or int(held_shorts.get(ticker, {}).get("qty", 0)) > 0)
			if relevant:
				out.append(item)
		elif kind == _filter:
			out.append(item)
	return out


func _render_header() -> void:
	var header := SmaKit.hbox(10)
	var title_box := SmaKit.vbox(0)
	title_box.add_child(SmaKit.label(I18n.t("news.title"), 20))
	title_box.add_child(SmaKit.muted(I18n.t("news.subtitle"), 12))
	header.add_child(title_box)
	header.add_child(SmaKit.hspacer())
	var market_button := SmaKit.button(I18n.t("nav.market"), _go_market)
	header.add_child(market_button)
	_body.add_child(header)


func _render_filters() -> void:
	var row := SmaKit.flow(6)
	for spec in [
		["all", "news.filter.all"],
		["mine", "news.filter.mine"],
		["earnings", "news.kind.earnings"],
		["macro", "news.kind.macro"],
		["company", "news.kind.company"],
	]:
		var id := String(spec[0])
		var btn := SmaKit.toggle(I18n.t(String(spec[1])))
		btn.button_pressed = _filter == id
		btn.pressed.connect(func():
			_filter = id
			refresh())
		row.add_child(btn)
	_body.add_child(row)


func _render_corporate() -> void:
	var offerings: Array = game.rights_offerings()
	var actions_rows: Array = game.corporate_actions(6)
	if offerings.is_empty() and actions_rows.is_empty():
		return
	var card := SmaKit.card(12)
	var box := SmaKit.vbox(5)
	card.add_child(box)
	box.add_child(SmaKit.label(I18n.t("dashboard.corporateTitle"), 13))
	for offering in offerings:
		var line := SmaKit.vbox(3)
		var text := SmaKit.muted(I18n.t("dashboard.rightsTerms", {
			"ticker": String(offering["ticker"]),
			"ratio": SmaFormat.num(float(offering["ratio"]) * 100.0, 0),
			"price": SmaFormat.money(float(offering["price"])),
			"deadline": SmaCalendar.iso_date(int(offering["deadlineDay"])),
		}), 11)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(text)
		var actions := SmaKit.hbox(6)
		actions.add_child(SmaKit.button(I18n.t("dashboard.subscribe"), func():
			game.subscribe_rights(String(offering["id"]))
			refresh(), true))
		actions.add_child(SmaKit.button(I18n.t("dashboard.decline"), func():
			game.decline_rights(String(offering["id"]))
			refresh()))
		line.add_child(actions)
		box.add_child(line)
	for action in actions_rows:
		var kind := String(action.get("type", ""))
		var line := SmaKit.hbox(6)
		line.add_child(SmaKit.label(I18n.t("corporate.type.%s" % kind), 11, SmaUiTheme.ACCENT))
		line.add_child(SmaKit.label(String(action.get("ticker", "")), 11))
		line.add_child(SmaKit.hspacer())
		if action.has("ratio"):
			line.add_child(SmaKit.muted("×" + SmaFormat.num(float(action["ratio"]), 2), 10))
		if action.has("dps"):
			line.add_child(SmaKit.muted(SmaFormat.money(float(action["dps"])), 10))
		line.add_child(SmaKit.caption(SmaCalendar.iso_date(int(action.get("day", 0)))))
		box.add_child(line)
	_body.add_child(card)


func _render_earnings_calendar() -> void:
	var rows: Array = game.earnings_calendar(3)
	if rows.is_empty():
		return
	var card := SmaKit.card(12)
	var box := SmaKit.vbox(5)
	card.add_child(box)
	box.add_child(SmaKit.label(I18n.t("news.calendar.title"), 13))
	for row in rows:
		var names: Array = []
		for ticker in row.get("tickers", []):
			var company := SmaCompanyCatalog.get_company(String(ticker))
			names.append("%s %s" % [String(ticker),
				String(company.get("name", ""))])
		var shown := names.slice(0, 4)
		var extra := names.size() - shown.size()
		var tickers_text := ", ".join(PackedStringArray(shown))
		if extra > 0:
			tickers_text += " " + I18n.t("news.calendar.more", {"count": extra})
		box.add_child(SmaKit.muted(I18n.t("news.calendar.row", {
			"date": SmaCalendar.iso_date(int(row.get("day", 0))),
			"period": String(row.get("periodLabel", "")),
			"tickers": tickers_text,
		}), 10))
	_body.add_child(card)


func _go_market() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main != null:
		main.navigate("market")


func _open_trade(ticker: String) -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("open_ticker"):
		main.open_ticker(ticker)


func _open_financials(ticker: String) -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main == null:
		return
	var dialog := SmaFinancialsDialog.new()
	main.add_child(dialog)
	dialog.setup(game, ticker)


func _render_empty() -> void:
	var card := SmaKit.card(20)
	var box := SmaKit.vbox(6)
	card.add_child(box)
	box.add_child(SmaKit.label(I18n.t("news.emptyTitle"), 16))
	box.add_child(SmaKit.muted(I18n.t("news.emptyText"), 12))
	box.add_child(SmaKit.button(I18n.t("nav.market"), _go_market, true))
	_body.add_child(card)


func _news_card(item: Dictionary) -> PanelContainer:
	var card := SmaKit.card(10)
	var box := SmaKit.vbox(4)
	card.add_child(box)
	var meta := SmaKit.hbox(8)
	var kind := String(item.get("kind", "company"))
	var kind_color := SmaUiTheme.ACCENT if kind == "macro" \
		else (SmaUiTheme.INFO if kind == "earnings" else SmaUiTheme.WARNING)
	meta.add_child(SmaKit.label(I18n.t("news.kind.%s" % kind), 10, kind_color))
	meta.add_child(SmaKit.caption(SmaCalendar.iso_date(int(item.get("day", 0)))))
	meta.add_child(SmaKit.hspacer())
	var pct := float(item.get("pct", 0.0))
	meta.add_child(SmaKit.label(SmaFormat.pct(pct, 1), 11, SmaKit.value_color(pct)))
	box.add_child(meta)
	var ticker := String(item.get("ticker", ""))
	var company_name := ""
	if ticker != "":
		company_name = String(SmaCompanyCatalog.get_company(ticker).get("name", ticker))
	var template_key := "news.template.%s" % String(item.get("template", ""))
	var headline := I18n.t(template_key, {
		"company": company_name if company_name != "" else ticker,
		"pct": SmaFormat.num(absf(pct), 1) + "%",
		"period": String(item.get("periodLabel", "")),
		"eps": SmaFormat.num(float(item.get("eps", 0.0)), 2),
		"expected": SmaFormat.num(float(item.get("expectedEps", 0.0)), 2),
		"surprise": SmaFormat.pct(float(item.get("surprisePct", 0.0)), 1),
	})
	var headline_label := SmaKit.label(headline, 13)
	headline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(headline_label)
	if kind == "earnings":
		box.add_child(SmaKit.muted(I18n.t("news.earningsDetail", {
			"eps": SmaFormat.num(float(item.get("eps", 0.0)), 2),
			"expected": SmaFormat.num(float(item.get("expectedEps", 0.0)), 2),
			"surprise": SmaFormat.pct(float(item.get("surprisePct", 0.0)), 1),
			"guidance": I18n.t("news.guidance.%s" % String(item.get("guidance", "maintain"))),
		}), 10))
	if ticker != "":
		var footer := SmaKit.hbox(8)
		footer.add_child(SmaKit.muted("%s · %s" % [ticker, company_name], 10))
		footer.add_child(SmaKit.hspacer())
		var trade_btn := SmaKit.button(I18n.t("watchlist.trade"), _open_trade.bind(ticker))
		trade_btn.add_theme_font_size_override("font_size", 10)
		footer.add_child(trade_btn)
		var fin_btn := SmaKit.button(I18n.t("financials.open"), _open_financials.bind(ticker))
		fin_btn.add_theme_font_size_override("font_size", 10)
		footer.add_child(fin_btn)
		box.add_child(footer)
	return card
