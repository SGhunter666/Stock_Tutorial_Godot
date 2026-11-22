## Watchlist and alert center: one place to review every followed ticker and
## every price alert, with quick jumps into the trading desk.
class_name SmaWatchlistScreen
extends SmaScreen

var _body: VBoxContainer
var _watch_rows: Dictionary = {}
var _alerts_box: VBoxContainer


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
	_watch_rows.clear()
	_alerts_box = null
	if game == null or not game.started:
		return
	_render_header()
	_render_watchlist()
	_render_alerts()


func on_tick() -> void:
	if game == null or game.exchange == null:
		return
	for ticker in _watch_rows.keys():
		var labels: Dictionary = _watch_rows[ticker]
		var quote: Dictionary = game.exchange.quote(String(ticker))
		var change := float(quote.get("changePct", 0.0))
		labels["last"].text = SmaFormat.money(float(quote.get("last", 0.0)))
		labels["change"].text = SmaFormat.pct(change, 2)
		labels["change"].add_theme_color_override("font_color",
			SmaKit.value_color(change))


func _render_header() -> void:
	var header := SmaKit.hbox(10)
	var title_box := SmaKit.vbox(2)
	title_box.add_child(SmaKit.label(I18n.t("watchlist.title"), 22))
	title_box.add_child(SmaKit.muted(I18n.t("watchlist.subtitle"), 12))
	header.add_child(title_box)
	header.add_child(SmaKit.hspacer())
	header.add_child(SmaKit.button(I18n.t("watchlist.goMarket"), _go_market))
	_body.add_child(header)


func _render_watchlist() -> void:
	var tickers: Array = game.watchlist()
	var card := SmaKit.card(12)
	var box := SmaKit.vbox(6)
	card.add_child(box)
	var title_row := SmaKit.hbox(8)
	title_row.add_child(SmaKit.label(I18n.t("watchlist.watchTitle"), 15))
	title_row.add_child(SmaKit.muted(I18n.t("watchlist.watchCount", {
		"count": tickers.size()}), 11))
	title_row.add_child(SmaKit.hspacer())
	title_row.add_child(SmaKit.muted(I18n.t("watchlist.watchHint"), 10))
	box.add_child(title_row)
	if tickers.is_empty():
		box.add_child(SmaKit.muted(I18n.t("watchlist.watchEmpty"), 12))
		_body.add_child(card)
		return
	box.add_child(SmaKit.header_row(
		["watchlist.ticker", "watchlist.company", "watchlist.sector",
			"watchlist.last", "watchlist.change", "watchlist.alertCount",
			"watchlist.action", ""],
		[0.7, 2.0, 1.0, 0.9, 0.9, 0.7, 0.7, 0.5],
		[HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_LEFT,
			HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_RIGHT,
			HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_CENTER,
			HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_CENTER]))
	for ticker in tickers:
		box.add_child(_watch_row(String(ticker)))
	_body.add_child(card)


func _watch_row(ticker: String) -> Control:
	var companies := SmaCompanyCatalog.load_companies()
	var etfs := SmaEtfs.instruments()
	var info: Dictionary = companies.get(ticker, etfs.get(ticker, {}))
	var quote: Dictionary = game.exchange.quote(ticker)
	var change := float(quote.get("changePct", 0.0))
	var row := SmaKit.hbox(8)
	var ticker_cell := SmaKit.cell(ticker, 0.7)
	ticker_cell.add_theme_color_override("font_color", SmaUiTheme.ACCENT)
	row.add_child(ticker_cell)
	row.add_child(SmaKit.cell(String(info.get("name", ticker)), 2.0))
	var sector := String(info.get("sector", ""))
	if SmaEtfs.is_etf(ticker):
		sector = SmaEtfs.ETF_SECTOR
	row.add_child(SmaKit.cell(SmaKit.sector_label(sector), 1.0,
		HORIZONTAL_ALIGNMENT_LEFT, SmaUiTheme.MUTED))
	var last_cell := SmaKit.cell(SmaFormat.money(float(quote.get("last", 0.0))),
		0.9, HORIZONTAL_ALIGNMENT_RIGHT)
	var change_cell := SmaKit.cell(SmaFormat.pct(change, 2), 0.9,
		HORIZONTAL_ALIGNMENT_RIGHT, SmaKit.value_color(change))
	row.add_child(last_cell)
	row.add_child(change_cell)
	row.add_child(SmaKit.cell(str(_active_alerts(ticker)), 0.7,
		HORIZONTAL_ALIGNMENT_CENTER))
	var open_button := SmaKit.button(I18n.t("watchlist.trade"),
		_open_ticker.bind(ticker))
	open_button.custom_minimum_size.x = 64
	row.add_child(open_button)
	var remove_button := SmaKit.button("★", _remove_watch.bind(ticker))
	remove_button.custom_minimum_size.x = 36
	remove_button.tooltip_text = I18n.t("watchlist.removeWatch", {"ticker": ticker})
	row.add_child(remove_button)
	_watch_rows[ticker] = {"last": last_cell, "change": change_cell}
	return row


func _active_alerts(ticker: String) -> int:
	var count := 0
	for alert in game.price_alerts():
		if String(alert.get("ticker", "")) == ticker \
				and bool(alert.get("active", false)):
			count += 1
	return count


func _render_alerts() -> void:
	var alerts: Array = game.price_alerts()
	alerts.sort_custom(func(a, b):
		var a_active := bool(a.get("active", false))
		var b_active := bool(b.get("active", false))
		if a_active != b_active:
			return a_active
		return String(a.get("ticker", "")) < String(b.get("ticker", "")))
	var active_count := 0
	for alert in alerts:
		if bool(alert.get("active", false)):
			active_count += 1
	var card := SmaKit.card(12)
	var box := SmaKit.vbox(6)
	card.add_child(box)
	var title_row := SmaKit.hbox(8)
	title_row.add_child(SmaKit.label(I18n.t("watchlist.alertsTitle"), 15))
	title_row.add_child(SmaKit.muted(I18n.t("watchlist.alertsCount", {
		"active": active_count, "total": alerts.size()}), 11))
	title_row.add_child(SmaKit.hspacer())
	if alerts.size() > active_count:
		title_row.add_child(SmaKit.button(I18n.t("watchlist.clearTriggered"),
			_clear_triggered))
	box.add_child(title_row)
	if alerts.is_empty():
		box.add_child(SmaKit.muted(I18n.t("watchlist.alertsEmpty"), 12))
		_body.add_child(card)
		return
	box.add_child(SmaKit.header_row(
		["watchlist.ticker", "watchlist.direction", "watchlist.target",
			"watchlist.status", "watchlist.created", "watchlist.triggered",
			"watchlist.action", ""],
		[0.7, 0.8, 0.9, 0.8, 0.8, 1.2, 0.7, 0.5],
		[HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_LEFT,
			HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_CENTER,
			HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_LEFT,
			HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_CENTER]))
	var scroll := SmaKit.scroll(clampf(40.0 + float(alerts.size()) * 26.0, 80.0, 300.0))
	_alerts_box = SmaKit.vbox(3)
	scroll.add_child(_alerts_box)
	for alert in alerts:
		_alerts_box.add_child(_alert_row(alert))
	box.add_child(scroll)
	_body.add_child(card)


func _alert_row(alert: Dictionary) -> Control:
	var ticker := String(alert.get("ticker", ""))
	var active := bool(alert.get("active", false))
	var row := SmaKit.hbox(8)
	var ticker_cell := SmaKit.cell(ticker, 0.7)
	ticker_cell.add_theme_color_override("font_color", SmaUiTheme.ACCENT)
	row.add_child(ticker_cell)
	row.add_child(SmaKit.cell(I18n.t("alerts.%s" % String(alert.get("side", "above"))),
		0.8, HORIZONTAL_ALIGNMENT_LEFT))
	row.add_child(SmaKit.cell(SmaFormat.money(float(alert.get("price", 0.0))),
		0.9, HORIZONTAL_ALIGNMENT_RIGHT))
	row.add_child(SmaKit.cell(
		I18n.t("watchlist.statusActive" if active else "watchlist.statusTriggered"),
		0.8, HORIZONTAL_ALIGNMENT_CENTER,
		SmaUiTheme.POSITIVE if active else SmaUiTheme.DIM))
	row.add_child(SmaKit.cell(I18n.t("alerts.createdDay", {
		"day": int(alert.get("createdDay", 0))}), 0.8,
		HORIZONTAL_ALIGNMENT_CENTER, SmaUiTheme.MUTED))
	var triggered_text := "—"
	if not active:
		triggered_text = "%s · %s" % [
			SmaFormat.money(float(alert.get("triggeredPrice", 0.0))),
			I18n.t("alerts.createdDay", {
				"day": int(alert.get("triggeredDay", 0))})]
	row.add_child(SmaKit.cell(triggered_text, 1.2,
		HORIZONTAL_ALIGNMENT_LEFT, SmaUiTheme.MUTED))
	var open_button := SmaKit.button(I18n.t("watchlist.trade"),
		_open_ticker.bind(ticker))
	open_button.custom_minimum_size.x = 64
	row.add_child(open_button)
	var delete_button := SmaKit.button("×",
		_delete_alert.bind(String(alert.get("id", ""))))
	delete_button.custom_minimum_size.x = 32
	delete_button.tooltip_text = I18n.t("watchlist.deleteAlert")
	row.add_child(delete_button)
	return row


func _remove_watch(ticker: String) -> void:
	game.toggle_watch(ticker)
	refresh("watchlist")


func _delete_alert(alert_id: String) -> void:
	if alert_id == "":
		return
	game.remove_price_alert(alert_id)
	refresh("alerts")


func _clear_triggered() -> void:
	var removed: int = game.clear_triggered_alerts()
	if removed > 0:
		game.toast(I18n.t("watchlist.cleared", {"count": removed}))
	refresh("alerts")


func _open_ticker(ticker: String) -> void:
	if game == null or ticker == "":
		return
	game.select_ticker(ticker)
	var main := get_tree().get_first_node_in_group("main")
	if main == null or not main.has_method("navigate"):
		return
	if SmaEtfs.is_etf(ticker):
		main.navigate("etf")
		if main._screens.has("etf"):
			main._screens["etf"]._selected = ticker
			main._screens["etf"].refresh()
	else:
		main.navigate("trade")


func _go_market() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("navigate"):
		main.navigate("market")
