## Deterministic simulated news feed. Events are generated at each day close by
## the exchange and shock simulated quotes; this screen only reads them.
class_name SmaNewsScreen
extends SmaScreen

var _body: VBoxContainer


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
	_render_earnings_calendar()
	var items: Array = game.news_items()
	if items.is_empty():
		_render_empty()
		return
	var start := maxi(0, items.size() - 40)
	for index in range(items.size() - 1, start - 1, -1):
		_body.add_child(_news_card(items[index]))
	_body.add_child(SmaKit.muted(I18n.t("news.disclaimer"), 10))


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
		box.add_child(SmaKit.muted("%s · %s" % [ticker, company_name], 10))
	return card
