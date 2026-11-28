## Portfolio: account summary, equity curve, risk metrics, clickable long/short
## books, derivatives/multi-asset holdings and fill ledger.
class_name SmaPortfolioScreen
extends SmaScreen

const REFRESH_INTERVAL_MS := 350

var _stat_values: Dictionary = {}
var _risk_values: Dictionary = {}
var _risk_level_label: Label
var _diag_radar: SmaRadarChart
var _diag_archetype: Label
var _diag_metrics: Label
var _diag_biases_box: FlowContainer
var _diag_comment: Label
var _equity_chart: SmaLineChart
var _equity_meta: Label
var _long_box: VBoxContainer
var _short_box: VBoxContainer
var _other_box: VBoxContainer
var _fills_box: VBoxContainer
var _status_label: Label
var _last_rebuild := 0


func _build() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var root := SmaKit.vbox(0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var scroll := SmaKit.scroll()
	root.add_child(scroll)
	var content := SmaKit.vbox(12)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	var heading := SmaKit.vbox(2)
	heading.add_child(SmaKit.title(I18n.t("portfolio.title"), 22))
	heading.add_child(SmaKit.muted(I18n.t("portfolio.subtitle")))
	content.add_child(heading)

	var stats_card := SmaKit.card(12)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 12)
	stats_card.add_child(grid)
	for key in ["equity", "cash", "buying_power", "maintenance", "realized", "fees", "day_pnl", "margin_status"]:
		var box := SmaKit.vbox(1)
		box.add_child(SmaKit.caption(I18n.t("portfolio.%s" % key)))
		var value := SmaKit.label("—", 17)
		box.add_child(value)
		_stat_values[key] = value
		if key == "margin_status":
			_status_label = value
		grid.add_child(box)
	content.add_child(stats_card)

	var chart_card := SmaKit.card(12)
	var chart_box := SmaKit.vbox(6)
	chart_card.add_child(chart_box)
	var chart_head := SmaKit.hbox(8)
	chart_head.add_child(SmaKit.label(I18n.t("portfolio.equityCurve"), 13))
	chart_head.add_child(SmaKit.hspacer())
	_equity_meta = SmaKit.caption("")
	chart_head.add_child(_equity_meta)
	chart_box.add_child(chart_head)
	_equity_chart = SmaLineChart.new()
	_equity_chart.custom_minimum_size = Vector2(320, 140)
	chart_box.add_child(_equity_chart)
	content.add_child(chart_card)

	var risk_card := SmaKit.card(12)
	var risk_box := SmaKit.vbox(5)
	risk_card.add_child(risk_box)
	var risk_head := SmaKit.hbox(8)
	risk_head.add_child(SmaKit.label(I18n.t("portfolio.riskTitle"), 13))
	_risk_level_label = SmaKit.caption("")
	risk_head.add_child(SmaKit.hspacer())
	risk_head.add_child(_risk_level_label)
	risk_box.add_child(risk_head)
	var risk_grid := GridContainer.new()
	risk_grid.columns = 5
	risk_grid.add_theme_constant_override("h_separation", 18)
	risk_grid.add_theme_constant_override("v_separation", 8)
	for key in ["annualVol", "maxDrawdown", "exposure", "hhi", "largest"]:
		var box := SmaKit.vbox(1)
		box.add_child(SmaKit.caption(I18n.t("portfolio.%s" % key)))
		var value := SmaKit.label("—", 15)
		box.add_child(value)
		_risk_values[key] = value
		risk_grid.add_child(box)
	risk_box.add_child(risk_grid)
	var risk_note := SmaKit.muted(I18n.t("portfolio.riskNote"), 10)
	risk_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	risk_box.add_child(risk_note)
	content.add_child(risk_card)

	var diag_card := SmaKit.card(12)
	var diag_root := SmaKit.hbox(14)
	diag_card.add_child(diag_root)
	_diag_radar = SmaRadarChart.new()
	diag_root.add_child(_diag_radar)
	var diag_info := SmaKit.vbox(6)
	diag_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var diag_head := SmaKit.hbox(8)
	diag_head.add_child(SmaKit.label(I18n.t("diag.title"), 15, SmaUiTheme.GOLD))
	diag_head.add_child(SmaKit.hspacer())
	_diag_archetype = SmaKit.label("—", 13, SmaUiTheme.ACCENT)
	diag_head.add_child(_diag_archetype)
	diag_info.add_child(diag_head)
	_diag_metrics = SmaKit.caption("")
	_diag_metrics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diag_info.add_child(_diag_metrics)
	_diag_biases_box = SmaKit.flow(6)
	diag_info.add_child(_diag_biases_box)
	_diag_comment = SmaKit.muted("", 12)
	_diag_comment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diag_info.add_child(_diag_comment)
	diag_root.add_child(diag_info)
	content.add_child(diag_card)

	var long_section := _table_section("portfolio.positions", ["market.ticker", "market.company",
		"common.qty", "portfolio.avg_cost", "market.last", "portfolio.market_value",
		"portfolio.unrealized"], [0.7, 1.8, 0.8, 0.9, 0.9, 1.1, 1.1], true)
	content.add_child(long_section["card"])
	_long_box = long_section["body"]
	var short_section := _table_section("portfolio.shorts", ["market.ticker", "market.company",
		"common.qty", "portfolio.avg_price", "market.last", "portfolio.market_value",
		"portfolio.unrealized"], [0.7, 1.8, 0.8, 0.9, 0.9, 1.1, 1.1], false)
	content.add_child(short_section["card"])
	_short_box = short_section["body"]

	var other_card := SmaKit.card(10)
	var other_wrap := SmaKit.vbox(6)
	other_card.add_child(other_wrap)
	var other_head := SmaKit.hbox(8)
	other_head.add_child(SmaKit.label(I18n.t("portfolio.otherAssets"), 13))
	other_head.add_child(SmaKit.hspacer())
	other_head.add_child(SmaKit.caption(I18n.t("portfolio.otherAssetsHint")))
	other_wrap.add_child(other_head)
	_other_box = SmaKit.vbox(4)
	other_wrap.add_child(_other_box)
	content.add_child(other_card)

	var fills_section := _table_section("portfolio.trades", ["common.day", "market.ticker", "common.side",
		"common.qty", "common.price", "portfolio.realized"], [0.9, 0.8, 0.9, 0.9, 0.9, 1.2], true)
	content.add_child(fills_section["card"])
	_fills_box = fills_section["body"]


func _table_section(title_key: String, columns: Array, ratios: Array, expand: bool) -> Dictionary:
	var card := SmaKit.card(10)
	var box := SmaKit.vbox(4)
	card.add_child(box)
	var head := SmaKit.hbox(8)
	var title := SmaKit.label(I18n.t(title_key), 13)
	title.custom_minimum_size.x = 160
	head.add_child(title)
	head.add_child(SmaKit.hspacer())
	box.add_child(head)
	var header := SmaKit.header_row(columns, ratios)
	header.custom_minimum_size.y = 24
	box.add_child(header)
	var scroll := SmaKit.scroll(140 if expand else 110)
	var body := SmaKit.vbox(2)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	box.add_child(scroll)
	return {"card": card, "body": body}


func refresh(reason: String = "") -> void:
	if game == null or not game.started or game.exchange == null:
		return
	if reason == "" and Time.get_ticks_msec() - _last_rebuild < REFRESH_INTERVAL_MS:
		return
	_last_rebuild = Time.get_ticks_msec()
	_update_stats()
	_update_equity_curve()
	_update_risk()
	_update_diagnostics()
	_update_long()
	_update_short()
	_update_other_assets()
	_update_fills()


func on_tick() -> void:
	refresh()


func _update_stats() -> void:
	var exchange: SmaExchange = game.exchange
	var account: Dictionary = exchange.state["account"]
	var snapshot := SmaMargin.margin_snapshot(exchange.state)
	var equity := exchange.equity()
	var day_start := _day_start_equity()
	var day_pnl := equity - day_start
	_stat_values["equity"].text = SmaFormat.money(equity)
	_stat_values["cash"].text = SmaFormat.money(float(account["cash"]))
	_stat_values["buying_power"].text = SmaFormat.money(game.effective_buying_power())
	_stat_values["maintenance"].text = SmaFormat.money(float(snapshot["maintenanceExcess"]))
	_stat_values["realized"].text = SmaFormat.signed_money(float(account["realizedPnl"]))
	_stat_values["realized"].add_theme_color_override("font_color",
		SmaKit.value_color(float(account["realizedPnl"])))
	_stat_values["fees"].text = SmaFormat.money(float(account["fees"]))
	_stat_values["day_pnl"].text = SmaFormat.signed_money(day_pnl)
	_stat_values["day_pnl"].add_theme_color_override("font_color", SmaKit.value_color(day_pnl))
	var status := String(snapshot["status"])
	_status_label.text = I18n.t("portfolio.margin_%s" % status)
	if status == "ok":
		_status_label.add_theme_color_override("font_color", SmaUiTheme.POSITIVE)
	elif status == "call":
		_status_label.add_theme_color_override("font_color", SmaUiTheme.WARNING)
	else:
		_status_label.add_theme_color_override("font_color", SmaUiTheme.NEGATIVE)


func _update_equity_curve() -> void:
	if _equity_chart == null:
		return
	var account: Dictionary = game.exchange.state["account"]
	var history: Array = account.get("equityHistory", [])
	var values: Array = []
	var start_day := 0
	for point in history:
		if values.is_empty():
			start_day = int(point.get("day", 0))
		values.append(float(point.get("equity", 0.0)))
	var current_equity: float = game.get_equity()
	if values.is_empty():
		values.append(float(account.get("initialCash", current_equity)))
	values.append(current_equity)
	var initial := float(account.get("initialCash", 100000.0))
	var total_ret := (current_equity / initial - 1.0) * 100.0 if initial > 0.0 else 0.0
	var line_color := SmaKit.value_color(total_ret) if absf(total_ret) > 0.001 else SmaUiTheme.ACCENT
	_equity_chart.set_series(values, line_color, "money",
		SmaCalendar.iso_date(start_day), SmaCalendar.iso_date(game.get_day()))
	_equity_meta.text = "%s %s · %s %s" % [
		I18n.t("dashboard.sinceStart"), SmaFormat.pct(total_ret, 2),
		I18n.t("market.index"), SmaFormat.pct(game.market_index_change(), 2),
	]


func _update_risk() -> void:
	var risk: Dictionary = game.portfolio_risk()
	if risk.is_empty():
		return
	_risk_values["annualVol"].text = SmaFormat.pct_plain(float(risk["annualVolPct"]), 1) \
		if bool(risk["hasVolatility"]) else "—"
	_risk_values["maxDrawdown"].text = SmaFormat.pct_plain(float(risk["maxDrawdownPct"]), 1)
	_risk_values["exposure"].text = SmaFormat.pct_plain(float(risk["exposurePct"]), 1)
	_risk_values["hhi"].text = SmaFormat.num(float(risk["hhi"]), 0)
	_risk_values["largest"].text = SmaFormat.pct_plain(float(risk["largestPct"]), 1)
	var level := String(risk["riskLevel"])
	_risk_level_label.text = I18n.t("portfolio.risk_%s" % level)
	if level == "high":
		_risk_level_label.add_theme_color_override("font_color", SmaUiTheme.NEGATIVE)
	elif level == "medium":
		_risk_level_label.add_theme_color_override("font_color", SmaUiTheme.WARNING)
	else:
		_risk_level_label.add_theme_color_override("font_color", SmaUiTheme.POSITIVE)


func _update_diagnostics() -> void:
	if _diag_radar == null or game == null:
		return
	var diag: Dictionary = game.behavioral_diagnostics()
	if diag.is_empty():
		return
	var sc: Dictionary = diag.get("scores", {})
	var m: Dictionary = diag.get("metrics", {})
	var grade := String(diag.get("grade", "B"))
	var overall := float(diag.get("overallScore", 75.0))
	_diag_radar.set_data([
		{"label": I18n.t("diag.axis.disposition"), "value": float(sc.get("disposition", 75.0))},
		{"label": I18n.t("diag.axis.chaseControl"), "value": float(sc.get("chaseControl", 75.0))},
		{"label": I18n.t("diag.axis.overtrading"), "value": float(sc.get("overtrading", 75.0))},
		{"label": I18n.t("diag.axis.sizing"), "value": float(sc.get("sizing", 75.0))},
		{"label": I18n.t("diag.axis.risk"), "value": float(sc.get("risk", 75.0))},
	], grade, overall)
	_diag_archetype.text = "%s · %s (%d)" % [
		I18n.t(String(diag.get("archetypeKey", "diag.archetype.calmObserver"))),
		grade, int(round(overall)),
	]
	_diag_metrics.text = I18n.t("diag.metricsLine", {
		"winDays": SmaFormat.num(float(m.get("avgWinHoldDays", 0.0)), 1),
		"lossDays": SmaFormat.num(float(m.get("avgLossHoldDays", 0.0)), 1),
		"payoff": SmaFormat.num(float(m.get("payoffRatio", 1.0)), 2),
		"feeDrag": SmaFormat.pct_plain(float(m.get("feeDragPct", 0.0)), 2),
		"tpd": SmaFormat.num(float(m.get("tradesPerDay", 0.0)), 1),
	})
	SmaKit.clear_children(_diag_biases_box)
	var biases: Array = diag.get("biases", [])
	if biases.is_empty():
		_diag_biases_box.add_child(SmaKit.badge(I18n.t("diag.noBiases"),
			Color("#063322"), SmaUiTheme.POSITIVE))
	else:
		for b in biases:
			var bid := String(b.get("id", ""))
			var high := String(b.get("severity", "medium")) == "high"
			_diag_biases_box.add_child(SmaKit.badge(
				I18n.t("diag.bias.%s" % bid),
				Color("#3b1219") if high else Color("#3b2c0c"),
				SmaUiTheme.NEGATIVE if high else SmaUiTheme.WARNING))
	_diag_comment.text = "%s：%s" % [
		I18n.t(String(diag.get("mentorSpeakerKey", "story.char.lin_lan.name"))),
		I18n.t(String(diag.get("mentorCommentKey", "diag.comment.calmObserver"))),
	]


func _day_start_equity() -> float:
	var exchange: SmaExchange = game.exchange
	var history: Array = exchange.state["account"]["equityHistory"]
	var day := int(exchange.state["dayIndex"])
	var value := float(exchange.state["account"]["initialCash"])
	for point in history:
		if int(point.get("day", 0)) < day:
			value = float(point.get("equity", value))
	return value


func _clickable_row(inner: Control, callback: Callable) -> PanelContainer:
	var panel := PanelContainer.new()
	var row_rim := Color("#c49a68") if SmaUiTheme.mode == "light" else Color("#090f1d")
	panel.add_theme_stylebox_override("panel", SmaPixelArt.row_box(SmaUiTheme.PANEL_ALT, row_rim, 6, 4))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.mouse_entered.connect(func(): panel.self_modulate = Color(1.16, 1.16, 1.16))
	panel.mouse_exited.connect(func(): panel.self_modulate = Color.WHITE)
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			callback.call())
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(inner)
	return panel


func _open_ticker(ticker: String) -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main == null or not main.has_method("navigate"):
		return
	if SmaEtfs.is_etf(ticker):
		game.select_ticker(ticker)
		main.navigate("etf")
		if main._screens.has("etf"):
			main._screens["etf"]._selected = ticker
			main._screens["etf"].refresh()
	else:
		main.open_ticker(ticker)


func _open_screen(screen_id: String) -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("navigate"):
		main.navigate(screen_id)


func _update_long() -> void:
	SmaKit.clear_children(_long_box)
	var rows: Array = game.exchange.position_rows()
	if rows.is_empty():
		_long_box.add_child(SmaKit.muted(I18n.t("portfolio.no_positions")))
		return
	for row in rows:
		var ticker := String(row["ticker"])
		var qty := int(row["qty"])
		var outer := SmaKit.hbox(6)
		var line := SmaKit.data_row([
			ticker, String(row["name"]), SmaFormat.quantity(float(qty)),
			SmaFormat.num(float(row["avgCost"]), 2), SmaFormat.num(float(row["last"]), 2),
			SmaFormat.money(float(row["marketValue"])), SmaFormat.signed_money(float(row["unrealized"])),
		], [0.7, 1.8, 0.8, 0.9, 0.9, 1.1, 1.1], [
			SmaUiTheme.ACCENT, SmaUiTheme.TEXT, SmaUiTheme.TEXT, SmaUiTheme.MUTED,
			SmaUiTheme.TEXT, SmaUiTheme.TEXT, SmaKit.value_color(float(row["unrealized"])),
		], [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_RIGHT,
			HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT,
			HORIZONTAL_ALIGNMENT_RIGHT])
		var row_btn := _clickable_row(line, _open_ticker.bind(ticker))
		row_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		outer.add_child(row_btn)
		if qty >= 2:
			var half_b := SmaKit.button(I18n.t("trade.closeHalf"),
				_quick_portfolio_close.bind(ticker, "sell", int(floor(qty / 2.0))))
			SmaKit.set_small_font(half_b, 10)
			outer.add_child(half_b)
		var all_b := SmaKit.button(I18n.t("trade.closeAll"),
			_quick_portfolio_close.bind(ticker, "sell", qty))
		SmaKit.set_small_font(all_b, 10)
		outer.add_child(all_b)
		_long_box.add_child(outer)


func _quick_portfolio_close(ticker: String, side: String, qty: int) -> void:
	if game == null or qty <= 0:
		return
	game.submit_order({"ticker": ticker, "side": side, "type": "market", "qty": qty})
	refresh("quick_close")


func _update_short() -> void:
	SmaKit.clear_children(_short_box)
	var rows: Array = game.exchange.short_rows()
	if rows.is_empty():
		_short_box.add_child(SmaKit.muted(I18n.t("portfolio.no_shorts")))
		return
	for row in rows:
		var ticker := String(row["ticker"])
		var qty := int(row["qty"])
		var outer := SmaKit.hbox(6)
		var line := SmaKit.data_row([
			ticker, String(row["name"]), SmaFormat.quantity(float(qty)),
			SmaFormat.num(float(row["avgPrice"]), 2), SmaFormat.num(float(row["last"]), 2),
			SmaFormat.money(float(row["marketValue"])), SmaFormat.signed_money(float(row["unrealized"])),
		], [0.7, 1.8, 0.8, 0.9, 0.9, 1.1, 1.1], [
			SmaUiTheme.NEGATIVE, SmaUiTheme.TEXT, SmaUiTheme.TEXT, SmaUiTheme.MUTED,
			SmaUiTheme.TEXT, SmaUiTheme.TEXT, SmaKit.value_color(float(row["unrealized"])),
		], [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_RIGHT,
			HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT,
			HORIZONTAL_ALIGNMENT_RIGHT])
		var row_btn := _clickable_row(line, _open_ticker.bind(ticker))
		row_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		outer.add_child(row_btn)
		if qty >= 2:
			var half_b := SmaKit.button(I18n.t("trade.closeHalf"),
				_quick_portfolio_close.bind(ticker, "cover", int(floor(qty / 2.0))))
			SmaKit.set_small_font(half_b, 10)
			outer.add_child(half_b)
		var all_b := SmaKit.button(I18n.t("trade.closeAll"),
			_quick_portfolio_close.bind(ticker, "cover", qty))
		SmaKit.set_small_font(all_b, 10)
		outer.add_child(all_b)
		_short_box.add_child(outer)


func _update_other_assets() -> void:
	SmaKit.clear_children(_other_box)
	var entries: Array = []
	for opt in game.option_rows():
		var qty := int(opt.get("qty", 0))
		var label := "%s %s %s (D%d)" % [
			String(opt.get("ticker", "")),
			String(opt.get("type", "")).to_upper(),
			SmaFormat.num(float(opt.get("strike", 0.0)), 2),
			int(opt.get("expiryDay", 0)),
		]
		entries.append({"cat": I18n.t("nav.options"), "label": label, "qty": "%d" % qty,
			"value": float(opt.get("marketValue", 0.0)), "pnl": float(opt.get("unrealized", 0.0)),
			"screen": "options"})
	for fut in game.futures_rows():
		var label := "%s %s (D%d)" % [
			String(fut.get("ticker", "")),
			String(fut.get("side", "")).to_upper(),
			int(fut.get("expiryDay", 0)),
		]
		entries.append({"cat": I18n.t("nav.futures"), "label": label,
			"qty": SmaFormat.quantity(float(fut.get("qty", 0))),
			"value": float(fut.get("notional", fut.get("margin", 0.0))),
			"pnl": float(fut.get("unrealized", 0.0)), "screen": "futures"})
	for pair in [
		[game.bond_rows(), "multiasset.bondValue"],
		[game.fx_rows(), "multiasset.fxValue"],
		[game.commodity_rows(), "multiasset.commodityValue"],
		[game.crypto_rows(), "multiasset.cryptoValue"],
	]:
		var cat := I18n.t(String(pair[1]))
		for row in pair[0]:
			entries.append({"cat": cat,
				"label": String(row.get("name", row.get("id", row.get("pair", "")))),
				"qty": SmaFormat.num(float(row.get("qty", row.get("units", 0.0))), 2),
				"value": float(row.get("value", 0.0)),
				"pnl": float(row.get("pnl", 0.0)), "screen": "multiasset"})
	if entries.is_empty():
		_other_box.add_child(SmaKit.muted(I18n.t("portfolio.noOtherAssets"), 11))
		return
	_other_box.add_child(SmaKit.header_row(
		["portfolio.assetClass", "portfolio.instrument", "common.qty",
			"portfolio.market_value", "portfolio.unrealized"],
		[0.9, 1.8, 0.7, 1.0, 1.0],
		[HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_RIGHT,
			HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT]))
	for item in entries:
		var pnl := float(item["pnl"])
		var line := SmaKit.data_row([
			String(item["cat"]), String(item["label"]), String(item["qty"]),
			SmaFormat.money(float(item["value"])), SmaFormat.signed_money(pnl),
		], [0.9, 1.8, 0.7, 1.0, 1.0], [
			SmaUiTheme.ACCENT, SmaUiTheme.TEXT, SmaUiTheme.MUTED,
			SmaUiTheme.TEXT, SmaKit.value_color(pnl),
		], [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_RIGHT,
			HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT])
		_other_box.add_child(_clickable_row(line, _open_screen.bind(String(item["screen"]))))


func _update_fills() -> void:
	SmaKit.clear_children(_fills_box)
	var fills: Array = game.exchange.state["account"]["trades"]
	if fills.is_empty():
		_fills_box.add_child(SmaKit.muted(I18n.t("portfolio.no_trades")))
		return
	var start := maxi(0, fills.size() - 12)
	for index in range(fills.size() - 1, start - 1, -1):
		var fill: Dictionary = fills[index]
		var side := String(fill.get("action", fill.get("side", "")))
		var labels := {
			"openLong": I18n.t("trade.buy"), "closeLong": I18n.t("trade.sell"),
			"openShort": I18n.t("trade.short"), "closeShort": I18n.t("trade.cover"),
		}
		var side_text: String = String(labels.get(side, side))
		var side_color: Color = SmaUiTheme.POSITIVE if side == "openLong" or side == "closeShort" else SmaUiTheme.NEGATIVE
		_fills_box.add_child(SmaKit.data_row([
			"%s %s" % [String(fill.get("date", "")).substr(5), String(fill.get("time", "")).substr(0, 5)],
			String(fill.get("ticker", "")), side_text,
			SmaFormat.quantity(float(fill.get("qty", 0))),
			SmaFormat.num(float(fill.get("price", 0.0)), 2),
			SmaFormat.signed_money(float(fill.get("realized", 0.0))),
		], [0.9, 0.8, 0.9, 0.9, 0.9, 1.2], [
			SmaUiTheme.MUTED, SmaUiTheme.ACCENT, side_color, SmaUiTheme.TEXT,
			SmaUiTheme.TEXT, SmaKit.value_color(float(fill.get("realized", 0.0))),
		], [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_LEFT,
			HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT]))
