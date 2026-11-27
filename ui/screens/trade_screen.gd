## Trading desk: quote header, candle chart, depth order book, quick-size
## ticket, position controls and working orders. All mutations go through Game.
class_name SmaTradeScreen
extends SmaScreen

const RANGE_OPTIONS := [60, 120, 250]

var _timeframe := "1m"
var _side := "buy"
var _order_type := "market"
var _side_group := ButtonGroup.new()
var _type_group := ButtonGroup.new()
var _timeframe_group := ButtonGroup.new()
var _timeframe_buttons: Dictionary = {}
var _range_group := ButtonGroup.new()
var _range_buttons: Dictionary = {}
var _side_buttons: Dictionary = {}
var _type_buttons: Dictionary = {}
var _limit_type_button: Button
var _limit_hint: Label
var _stop_row: HBoxContainer
var _stop_price: SpinBox
var _stop_ticker := ""
var _trail_row: HBoxContainer
var _trail_pct: SpinBox

var _name_label: Label
var _ticker_label: Label
var _ticker_badge: TextureRect
var _meta_label: Label
var _profile_label: Label
var _sensitivity_label: Label
var _reason_label: Label
var _watch_button: Button
var _indicators_card: PanelContainer
var _indicator_labels: Dictionary = {}
var _indicator_cache_key := ""
var _catalyst_cache_key := ""
var _last_label: Label
var _change_label: Label
var _stat_labels: Dictionary = {}
var _chart: SmaCandleChart
var _start_chart: Button
var _ma_toggle: Button
var _boll_toggle: Button
var _px_step_toggle: Button
var _reset_pan_button: Button
var _book_rows: Array = []
var _book_meta: Label
var _book_depth_hint: Label
var _qty: SpinBox
var _limit: SpinBox
var _ticket_ticker := ""
var _limit_row: HBoxContainer
var _estimate_label: Label
var _fee_label: Label
var _weight_label: Label
var _available_label: Label
var _short_info_label: Label
var _micro_warn_label: Label
var _feedback: Label
var _intro_review: Button
var _oco_card: PanelContainer
var _oco_qty: SpinBox
var _oco_tp: SpinBox
var _oco_stop: SpinBox
var _oco_submit: Button
var _oco_feedback: Label
var _lock_card: PanelContainer
var _lock_title: Label
var _lock_body: Label
var _submit_button: Button
var _oco_action := "closeLong"
var _oco_key := ""
var _position_box: VBoxContainer
var _position_key := ""
var _position_pnl_labels: Dictionary = {}
var _orders_box: VBoxContainer
var _orders_key := ""
var _order_buttons: Dictionary = {}
var _right_scroll: ScrollContainer


class SmaPixelDepthBar extends Control:
	var accent: Color
	func _init(accent_col: Color = Color.WHITE) -> void:
		accent = accent_col
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		if size.x <= 1.0 or size.y <= 1.0:
			return
		if not SmaUiTheme.is_pixel():
			draw_rect(Rect2(Vector2.ZERO, size), Color(accent.r, accent.g, accent.b, 0.24))
			return
		var seg_w := 6.0
		var gap := 2.0
		var body_col := Color(accent.r, accent.g, accent.b, 0.48)
		var hi_col := Color(accent.r, accent.g, accent.b, 0.92)
		var h := maxf(4.0, roundf(size.y / 2.0) * 2.0)
		var y := roundf((size.y - h) * 0.5)
		var x := 0.0
		var last_seg_x := 0.0
		var last_seg_w := 0.0
		while x < size.x - 0.5:
			var w := minf(seg_w, maxf(2.0, roundf(size.x - x)))
			draw_rect(Rect2(x, y, w, h), body_col)
			last_seg_x = x
			last_seg_w = w
			x += seg_w + gap
		if last_seg_w > 0.0:
			draw_rect(Rect2(last_seg_x, y, last_seg_w, h), hi_col)


func _build() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var root := SmaKit.vbox(12)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var quote_card := SmaKit.card(12)
	var quote_head := SmaKit.flow(14)
	var identity := SmaKit.vbox(2)
	var id_head := SmaKit.hbox(8)
	if SmaUiTheme.is_pixel():
		_ticker_badge = TextureRect.new()
		_ticker_badge.custom_minimum_size = Vector2(28, 28)
		_ticker_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_ticker_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_ticker_badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_ticker_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		id_head.add_child(_ticker_badge)
	_ticker_label = SmaKit.label("—", 24, SmaUiTheme.GOLD if SmaUiTheme.is_pixel() else SmaUiTheme.ACCENT)
	id_head.add_child(_ticker_label)
	_name_label = SmaKit.label("—", 14, SmaUiTheme.MUTED)
	_meta_label = SmaKit.caption("")
	_profile_label = SmaKit.caption("")
	identity.add_child(id_head)
	identity.add_child(_name_label)
	identity.add_child(_meta_label)
	identity.add_child(_profile_label)
	_sensitivity_label = SmaKit.caption("")
	identity.add_child(_sensitivity_label)
	quote_head.add_child(identity)
	var quote_actions := SmaKit.hbox(8)
	_watch_button = SmaKit.button(I18n.t("trade.watchAdd"), _toggle_watch)
	_watch_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_watch_button.custom_minimum_size.x = 100
	quote_actions.add_child(_watch_button)
	var alert_button := SmaKit.button(I18n.t("trade.alertButton"), _open_alerts)
	alert_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	alert_button.custom_minimum_size.x = 100
	quote_actions.add_child(alert_button)
	var financials_button := SmaKit.button(I18n.t("financials.open"), _open_financials)
	financials_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	financials_button.custom_minimum_size.x = 100
	quote_actions.add_child(financials_button)
	var last_box := SmaKit.vbox(0)
	_last_label = SmaKit.label("—", 30)
	_change_label = SmaKit.label("—", 14)
	last_box.add_child(_last_label)
	last_box.add_child(_change_label)
	quote_head.add_child(last_box)
	for key in ["high", "low", "bid", "ask", "volume"]:
		var stat := SmaKit.vbox(1)
		var caption := SmaKit.caption(I18n.t("market.%s" % key))
		var value := SmaKit.label("—", 13)
		stat.add_child(caption)
		stat.add_child(value)
		_stat_labels[key] = value
		quote_head.add_child(stat)
	quote_head.add_child(quote_actions)
	var quote_vbox := SmaKit.vbox(5)
	quote_vbox.add_child(quote_head)
	_reason_label = SmaKit.label("", 11, SmaUiTheme.GOLD)
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote_vbox.add_child(_reason_label)
	quote_card.add_child(quote_vbox)
	root.add_child(quote_card)

	_lock_card = SmaKit.card(10)
	var lock_box := SmaKit.vbox(4)
	_lock_card.add_child(lock_box)
	_lock_title = SmaKit.label("", 14, SmaUiTheme.WARNING)
	_lock_body = SmaKit.muted("", 11)
	_lock_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lock_box.add_child(_lock_title)
	lock_box.add_child(_lock_body)
	var lock_actions := SmaKit.hbox(8)
	lock_actions.add_child(SmaKit.hspacer())
	lock_actions.add_child(SmaKit.button(I18n.t("trade.lockedGoAcademy"), _go_academy, true))
	lock_box.add_child(lock_actions)
	_lock_card.visible = false
	root.add_child(_lock_card)

	var body_scroll := SmaKit.scroll()
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body_scroll)
	var body := SmaKit.hbox(12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.add_child(body)

	var left := SmaKit.vbox(12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)

	var chart_card := SmaKit.card(10)
	var chart_box := SmaKit.vbox(8)
	chart_card.add_child(chart_box)
	var chart_head := SmaKit.hbox(6)
	chart_head.add_child(SmaKit.label(I18n.t("trade.chart"), 14))
	chart_head.add_child(SmaKit.hspacer())
	for timeframe in SmaMinuteSeries.CHART_TIMEFRAMES:
		var button := SmaKit.toggle(timeframe, _timeframe_group)
		button.custom_minimum_size.x = 40
		button.pressed.connect(_on_timeframe.bind(timeframe))
		_timeframe_buttons[timeframe] = button
		chart_head.add_child(button)
	chart_box.add_child(chart_head)
	_range_group.allow_unpress = true
	var range_row := SmaKit.flow(6)
	range_row.add_child(SmaKit.caption(I18n.t("chart.range")))
	for count in RANGE_OPTIONS:
		var range_button := SmaKit.toggle("%d" % int(count), _range_group)
		range_button.custom_minimum_size.x = 36
		SmaKit.set_small_font(range_button, 11)
		range_button.pressed.connect(_on_range.bind(int(count)))
		_range_buttons[int(count)] = range_button
		range_row.add_child(range_button)
	_ma_toggle = SmaKit.toggle("MA")
	_ma_toggle.button_pressed = true
	SmaKit.set_small_font(_ma_toggle, 11)
	_ma_toggle.toggled.connect(func(_v): _sync_chart_overlays())
	range_row.add_child(_ma_toggle)
	_boll_toggle = SmaKit.toggle("BOLL")
	_boll_toggle.button_pressed = false
	SmaKit.set_small_font(_boll_toggle, 11)
	_boll_toggle.toggled.connect(func(_v): _sync_chart_overlays())
	range_row.add_child(_boll_toggle)
	_px_step_toggle = SmaKit.toggle(I18n.t("chart.pixelStep"))
	_px_step_toggle.button_pressed = bool(game.settings.get("chartPixelStepped", true)) \
		if game != null else true
	_px_step_toggle.tooltip_text = I18n.t("chart.pixelStepHint")
	SmaKit.set_small_font(_px_step_toggle, 11)
	_px_step_toggle.visible = SmaUiTheme.is_pixel()
	_px_step_toggle.toggled.connect(func(on: bool):
		if game != null:
			game.settings["chartPixelStepped"] = on
		_sync_chart_overlays())
	range_row.add_child(_px_step_toggle)
	_reset_pan_button = SmaKit.button(I18n.t("chart.latest"), _reset_chart_pan)
	SmaKit.set_small_font(_reset_pan_button, 11)
	_reset_pan_button.visible = false
	range_row.add_child(_reset_pan_button)
	range_row.add_child(SmaKit.caption(I18n.t("chart.hint")))
	chart_box.add_child(range_row)
	_start_chart = SmaKit.button(I18n.t("header.play"), game.toggle_pause)
	_start_chart.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chart_box.add_child(_start_chart)
	_chart = SmaCandleChart.new()
	_chart.custom_minimum_size.y = 300
	_chart.visible_count_changed.connect(_on_chart_range_changed)
	_chart.pan_changed.connect(func(panned: bool):
		if _reset_pan_button != null:
			_reset_pan_button.visible = panned)
	chart_box.add_child(_chart)
	_sync_chart_overlays()
	left.add_child(chart_card)

	_indicators_card = SmaKit.card(10)
	var indicator_box := SmaKit.vbox(5)
	_indicators_card.add_child(indicator_box)
	indicator_box.add_child(SmaKit.label(I18n.t("trade.indicatorsTitle"), 13))
	indicator_box.add_child(SmaKit.muted(I18n.t("trade.indicatorsSubtitle"), 10))
	var indicator_grid := GridContainer.new()
	indicator_grid.columns = 4
	indicator_grid.add_theme_constant_override("h_separation", 12)
	indicator_grid.add_theme_constant_override("v_separation", 2)
	for spec in [["sma20", "trade.sma20"], ["sma50", "trade.sma50"],
			["rsi14", "trade.rsi14"], ["trend", "trade.trend"],
			["volatility", "trade.volatility"], ["drawdown", "trade.drawdown"]]:
		indicator_grid.add_child(SmaKit.caption(I18n.t(String(spec[1]))))
		var value := SmaKit.label("—", 11)
		_indicator_labels[String(spec[0])] = value
		indicator_grid.add_child(value)
	indicator_box.add_child(indicator_grid)
	indicator_box.add_child(SmaKit.muted(I18n.t("trade.indicatorsNote"), 9))
	_indicators_card.visible = false
	left.add_child(_indicators_card)

	var book_card := SmaKit.card(10)
	var book_box := SmaKit.vbox(4)
	book_card.add_child(book_box)
	var book_top := SmaKit.hbox(10)
	book_top.add_child(SmaKit.label(I18n.t("trade.book"), 13))
	_book_meta = SmaKit.caption("")
	book_top.add_child(_book_meta)
	book_top.add_child(SmaKit.hspacer())
	book_top.add_child(SmaKit.caption(I18n.t("trade.bookClickHint")))
	book_box.add_child(book_top)
	var book_header := SmaKit.hbox(8)
	book_header.add_child(SmaKit.cell(I18n.t("trade.depthBar"), 1.6,
		HORIZONTAL_ALIGNMENT_LEFT, SmaUiTheme.DIM, 10))
	book_header.add_child(_book_cell(I18n.t("trade.price"), SmaUiTheme.DIM))
	book_header.add_child(_book_cell(I18n.t("trade.volume"), SmaUiTheme.DIM))
	book_box.add_child(book_header)
	var ask_box := SmaKit.vbox(2)
	var bid_box := SmaKit.vbox(2)
	for index in 6:
		var ask_item := _create_book_row(SmaUiTheme.NEGATIVE)
		ask_box.add_child(ask_item["container"])
		var bid_item := _create_book_row(SmaUiTheme.POSITIVE)
		bid_box.add_child(bid_item["container"])
		_book_rows.append({"ask": ask_item, "bid": bid_item})
	book_box.add_child(ask_box)
	book_box.add_child(SmaKit.separator())
	book_box.add_child(bid_box)
	_book_depth_hint = SmaKit.caption("")
	_book_depth_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_book_depth_hint.visible = false
	book_box.add_child(_book_depth_hint)
	left.add_child(book_card)

	_right_scroll = SmaKit.scroll()
	_right_scroll.custom_minimum_size.x = 360
	_right_scroll.size_flags_horizontal = Control.SIZE_SHRINK_END
	body.add_child(_right_scroll)
	var right := SmaKit.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_scroll.add_child(right)

	var ticket_card := SmaKit.card(12)
	var ticket := SmaKit.vbox(8)
	ticket_card.add_child(ticket)
	ticket.add_child(SmaKit.label(I18n.t("trade.title"), 14))
	var side_row := SmaKit.hbox(4)
	for entry in [["buy", "trade.buy"], ["sell", "trade.sell"], ["short", "trade.short"], ["cover", "trade.cover"]]:
		var side_id := String(entry[0])
		var button := SmaKit.toggle(I18n.t(String(entry[1])), _side_group)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 34 if SmaUiTheme.is_pixel() else 30
		if SmaUiTheme.is_pixel():
			if side_id == "buy":
				SmaUiTheme.apply_arcade_button(button, "buy", 6)
			elif side_id == "sell":
				SmaUiTheme.apply_arcade_button(button, "sell", 6)
		button.pressed.connect(_on_side.bind(side_id))
		_side_buttons[side_id] = button
		side_row.add_child(button)
	ticket.add_child(side_row)
	var type_row := SmaKit.hbox(4)
	for entry in [["market", "trade.market"], ["limit", "trade.limit"],
			["stop", "trade.stop"], ["trailing", "trade.trailing"]]:
		var button := SmaKit.toggle(I18n.t(String(entry[1])), _type_group)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_type.bind(String(entry[0])))
		_type_buttons[String(entry[0])] = button
		if String(entry[0]) == "limit":
			_limit_type_button = button
		type_row.add_child(button)
	ticket.add_child(type_row)
	_limit_hint = SmaKit.caption("")
	_limit_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ticket.add_child(_limit_hint)
	var qty_row := SmaKit.hbox(8)
	qty_row.add_child(SmaKit.label(I18n.t("trade.qty"), 12, SmaUiTheme.MUTED))
	qty_row.add_child(SmaKit.hspacer())
	_qty = SpinBox.new()
	_qty.min_value = 1
	_qty.max_value = 1000000
	_qty.step = 1
	_qty.value = 10
	_qty.custom_minimum_size.x = 130
	_qty.value_changed.connect(func(_value): _update_estimate())
	qty_row.add_child(_qty)
	ticket.add_child(qty_row)

	var quick_row := SmaKit.hbox(4)
	for spec in [["25%", 0.25], ["50%", 0.5], ["Max", 1.0]]:
		var btn := SmaKit.button(String(spec[0]), _apply_quick_ratio.bind(float(spec[1])))
		SmaKit.set_small_font(btn, 11)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quick_row.add_child(btn)
	for amount in [1000.0, 5000.0]:
		var btn := SmaKit.button("$%dk" % int(amount / 1000.0), _apply_quick_amount.bind(amount))
		SmaKit.set_small_font(btn, 11)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quick_row.add_child(btn)
	ticket.add_child(quick_row)

	_limit_row = SmaKit.hbox(8)
	_limit_row.add_child(SmaKit.label(I18n.t("trade.limit_price"), 12, SmaUiTheme.MUTED))
	_limit_row.add_child(SmaKit.hspacer())
	_limit = SpinBox.new()
	_limit.min_value = 0.01
	_limit.max_value = 1000000
	_limit.step = 0.01
	_limit.value = 100.0
	_limit.custom_minimum_size.x = 130
	_limit.value_changed.connect(func(_value): _update_estimate())
	_limit_row.add_child(_limit)
	ticket.add_child(_limit_row)
	_stop_row = SmaKit.hbox(8)
	_stop_row.add_child(SmaKit.label(I18n.t("trade.stop_price"), 12, SmaUiTheme.MUTED))
	_stop_row.add_child(SmaKit.hspacer())
	_stop_price = SpinBox.new()
	_stop_price.min_value = 0.01
	_stop_price.max_value = 1000000
	_stop_price.step = 0.01
	_stop_price.value = 95.0
	_stop_price.custom_minimum_size.x = 130
	_stop_price.value_changed.connect(func(_value): _update_estimate())
	_stop_row.add_child(_stop_price)
	ticket.add_child(_stop_row)
	_trail_row = SmaKit.hbox(8)
	_trail_row.add_child(SmaKit.label(I18n.t("trade.trail_pct"), 12, SmaUiTheme.MUTED))
	_trail_row.add_child(SmaKit.hspacer())
	_trail_pct = SpinBox.new()
	_trail_pct.min_value = 0.5
	_trail_pct.max_value = 49.0
	_trail_pct.step = 0.5
	_trail_pct.value = 5.0
	_trail_pct.custom_minimum_size.x = 130
	_trail_pct.value_changed.connect(func(_value): _update_estimate())
	_trail_row.add_child(_trail_pct)
	ticket.add_child(_trail_row)
	ticket.add_child(SmaKit.separator())
	var estimate_row := SmaKit.hbox(8)
	estimate_row.add_child(SmaKit.label(I18n.t("trade.estimate"), 12, SmaUiTheme.MUTED))
	estimate_row.add_child(SmaKit.hspacer())
	_estimate_label = SmaKit.label("—", 13)
	estimate_row.add_child(_estimate_label)
	ticket.add_child(estimate_row)
	var fee_row := SmaKit.hbox(8)
	fee_row.add_child(SmaKit.label(I18n.t("trade.fee"), 12, SmaUiTheme.MUTED))
	fee_row.add_child(SmaKit.hspacer())
	_fee_label = SmaKit.muted("—")
	fee_row.add_child(_fee_label)
	ticket.add_child(fee_row)
	_weight_label = SmaKit.caption("")
	ticket.add_child(_weight_label)
	_available_label = SmaKit.caption("")
	_available_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ticket.add_child(_available_label)
	_short_info_label = SmaKit.label("", 10, SmaUiTheme.GOLD)
	_short_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_short_info_label.visible = false
	ticket.add_child(_short_info_label)
	_micro_warn_label = SmaKit.label("", 10, SmaUiTheme.WARNING)
	_micro_warn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_micro_warn_label.visible = false
	ticket.add_child(_micro_warn_label)
	_submit_button = SmaKit.arcade_button(I18n.t("trade.submit"), "buy", _submit, 20 if SmaUiTheme.is_pixel() else 13)
	_submit_button.custom_minimum_size.y = 44 if SmaUiTheme.is_pixel() else 38
	ticket.add_child(_submit_button)
	_feedback = SmaKit.muted("")
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ticket.add_child(_feedback)
	_intro_review = SmaKit.button(I18n.t("intro.openReview"), _open_intro_review)
	_intro_review.visible = false
	ticket.add_child(_intro_review)
	right.add_child(ticket_card)

	_oco_card = SmaKit.card(12)
	var oco_box := SmaKit.vbox(6)
	_oco_card.add_child(oco_box)
	oco_box.add_child(SmaKit.label(I18n.t("exchange.ocoTitle"), 13))
	var oco_note := SmaKit.muted(I18n.t("exchange.ocoNote"), 10)
	oco_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	oco_box.add_child(oco_note)
	_oco_qty = _oco_spin_row(oco_box, I18n.t("common.qty"), 1.0, 1)
	_oco_tp = _oco_spin_row(oco_box, I18n.t("exchange.ocoTakeProfit"), 0.01, 0.01)
	_oco_stop = _oco_spin_row(oco_box, I18n.t("exchange.ocoStop"), 0.01, 0.01)
	_oco_submit = SmaKit.button(I18n.t("exchange.ocoSubmit"), _submit_oco, true)
	oco_box.add_child(_oco_submit)
	_oco_feedback = SmaKit.muted("")
	_oco_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	oco_box.add_child(_oco_feedback)
	_oco_card.visible = false
	right.add_child(_oco_card)

	var position_card := SmaKit.card(10)
	var position_box := SmaKit.vbox(5)
	position_card.add_child(position_box)
	position_box.add_child(SmaKit.label(I18n.t("trade.position"), 13))
	position_box.add_child(SmaKit.header_row(["common.side", "common.qty",
		"portfolio.avg_cost", "portfolio.unrealized"], [0.9, 0.8, 0.9, 1.2],
		[HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_RIGHT,
			HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT]))
	_position_box = SmaKit.vbox(4)
	position_box.add_child(_position_box)
	right.add_child(position_card)

	var orders_card := SmaKit.card(10)
	var orders_box := SmaKit.vbox(5)
	orders_card.add_child(orders_box)
	orders_box.add_child(SmaKit.label(I18n.t("trade.open_orders"), 13))
	var order_scroll := SmaKit.scroll(140)
	_orders_box = SmaKit.vbox(3)
	order_scroll.add_child(_orders_box)
	orders_box.add_child(order_scroll)
	right.add_child(orders_card)

	_select_defaults()
	refresh()


func _create_book_row(accent: Color) -> Dictionary:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_content_margin_all(2)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var row := SmaKit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var bar_host := Control.new()
	bar_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_host.size_flags_stretch_ratio = 1.6
	bar_host.custom_minimum_size.y = 16
	bar_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := SmaPixelDepthBar.new(accent)
	bar.anchor_top = 0.1
	bar.anchor_bottom = 0.9
	bar.anchor_left = 0.0
	bar.anchor_right = 0.0
	bar_host.add_child(bar)
	row.add_child(bar_host)
	var price := _book_cell("—", accent)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var size_lbl := _book_cell("—", SmaUiTheme.MUTED)
	size_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(price)
	row.add_child(size_lbl)
	var item := {"container": panel, "bar": bar, "price": price, "size": size_lbl, "value": 0.0}
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if float(item["value"]) > 0.0:
				_pick_book_price(float(item["value"])))
	return item


func _pick_book_price(price: float) -> void:
	if _order_type == "stop":
		_stop_price.value = SmaFormat.round_to(price, 2)
		_update_estimate()
		return
	if game.academy_is_tool_unlocked("order.limit"):
		if _order_type != "limit":
			_type_buttons["limit"].set_pressed_no_signal(true)
			_on_type("limit")
		_limit.value = SmaFormat.round_to(price, 2)
		_update_estimate()


func _sync_chart_overlays() -> void:
	if _chart == null:
		return
	_chart.set_indicators(
		_ma_toggle.button_pressed if _ma_toggle != null else true,
		_boll_toggle.button_pressed if _boll_toggle != null else false)
	if _px_step_toggle != null:
		_chart.set_pixel_stepped(_px_step_toggle.button_pressed)


func _reset_chart_pan() -> void:
	if _chart != null:
		_chart.reset_pan()


func _apply_quick_ratio(ratio: float) -> void:
	if game == null or not game.started or game.exchange == null:
		return
	var ticker: String = game.selected_ticker
	var qty := 0
	if _side == "sell":
		var held: int = game.exchange.available_shares(ticker)
		qty = maxi(1, int(floor(float(held) * ratio))) if held > 0 else 1
	elif _side == "cover":
		var short_held: int = game.exchange.available_short_shares(ticker)
		qty = maxi(1, int(floor(float(short_held) * ratio))) if short_held > 0 else 1
	else:
		var price := _current_price()
		if price <= 0.0:
			return
		var bp: float = game.effective_buying_power()
		var unit_cost := price * (1.0 + float(game.exchange.fee_bps) / 10000.0)
		qty = maxi(1, int(floor((bp * ratio) / maxf(0.01, unit_cost))))
	_qty.value = clampi(qty, 1, int(_qty.max_value))
	_update_estimate()


func _apply_quick_amount(amount: float) -> void:
	if game == null or not game.started:
		return
	var price := _current_price()
	if price <= 0.0:
		return
	var qty := maxi(1, int(floor(amount / price)))
	_qty.value = clampi(qty, 1, int(_qty.max_value))
	_update_estimate()


func _quick_close(side: String, qty: int) -> void:
	if game == null or not game.started or qty <= 0:
		return
	var result: Dictionary = game.submit_order({
		"ticker": game.selected_ticker,
		"side": side,
		"type": "market",
		"qty": qty,
	})
	if bool(result.get("ok", false)):
		_feedback.text = I18n.t("trade.order_filled")
		_feedback.add_theme_color_override("font_color", SmaUiTheme.POSITIVE)
		_orders_key = ""
		_position_key = ""
	else:
		var error_key := String(result.get("error", "order.invalid"))
		_feedback.text = I18n.t("error.%s" % error_key)
		_feedback.add_theme_color_override("font_color", SmaUiTheme.NEGATIVE)
	refresh()


func _go_academy() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("navigate"):
		main.navigate("academy")


func _open_financials() -> void:
	if game == null or not game.started or game.selected_ticker == "":
		return
	var main := get_tree().get_first_node_in_group("main")
	if main == null:
		return
	var dialog := SmaFinancialsDialog.new()
	main.add_child(dialog)
	dialog.closed.connect(func(): refresh("financials"))
	dialog.setup(game, game.selected_ticker)


func _toggle_watch() -> void:
	if game == null or not game.started:
		return
	game.toggle_watch(game.selected_ticker)
	refresh("watch")


func _open_alerts() -> void:
	if game == null or not game.started or game.selected_ticker == "":
		return
	var main := get_tree().get_first_node_in_group("main")
	if main == null:
		return
	var dialog := SmaPriceAlertDialog.new()
	main.add_child(dialog)
	dialog.closed.connect(func(): refresh("alerts"))
	dialog.setup(game, game.selected_ticker)


func _book_cell(text: String, color: Color) -> Label:
	var node := SmaKit.label(text, 11, color)
	node.custom_minimum_size.x = 84
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	node.size_flags_horizontal = Control.SIZE_SHRINK_END
	return node


func _select_defaults() -> void:
	for button in _side_group.get_buttons():
		button.button_pressed = button.text == I18n.t("trade.buy")
	for button in _type_group.get_buttons():
		button.button_pressed = button.text == I18n.t("trade.market")
	for button in _timeframe_group.get_buttons():
		button.button_pressed = button.text == "1m"
	for button in _range_group.get_buttons():
		button.button_pressed = button.text == "60"
	if _limit_row != null:
		_limit_row.visible = false
	if _stop_row != null:
		_stop_row.visible = false
	if _trail_row != null:
		_trail_row.visible = false


func refresh(reason: String = "") -> void:
	if game == null or not game.started or game.exchange == null:
		_set_empty(true)
		return
	_set_empty(false)
	var ticker: String = game.selected_ticker
	var timeframe: String = game.chart_timeframe()
	if _timeframe != timeframe:
		_timeframe = timeframe
		_timeframe_buttons[_timeframe].set_pressed_no_signal(true)
	_intro_review.visible = game.has_intro_task() and not game.intro["receipt"].is_empty()
	var lock: Dictionary = game.market_lock_info(ticker)
	var locked := bool(lock.get("locked", false))
	if _lock_card != null:
		_lock_card.visible = locked
		_lock_title.text = I18n.t("trade.lockedTitle")
		var unlock_day := int(lock.get("unlockDay", 0))
		if unlock_day > 0:
			_lock_body.text = I18n.t("trade.lockedBodyDual", {
				"ticker": ticker,
				"unit": I18n.t(String(lock.get("unitTitleKey", ""))),
				"day": unlock_day + 1,
			})
		else:
			_lock_body.text = I18n.t("trade.lockedBody", {
				"ticker": ticker,
				"unit": I18n.t(String(lock.get("unitTitleKey", ""))),
			})
	var company: Dictionary = game.exchange.company(ticker)
	var quote: Dictionary = game.exchange.quote(ticker)
	var last := float(quote.get("last", 0.0))
	_ticker_label.text = ticker
	if _ticker_badge != null:
		_ticker_badge.texture = SmaPixelArt.ticker_badge(ticker, String(company.get("sector", "")), locked)
	_name_label.text = String(company.get("name", ticker))
	if _watch_button != null:
		var watched: bool = game.is_watched(ticker)
		var watch_label := I18n.t(
			"trade.watchRemove" if watched else "trade.watchAdd")
		if _watch_button.text != watch_label:
			_watch_button.text = watch_label
			_watch_button.add_theme_color_override("font_color",
				SmaUiTheme.ACCENT if watched else SmaUiTheme.TEXT)
	_meta_label.text = "%s · %s · %s" % [
		SmaKit.sector_label(String(company.get("sector", ""))),
		SmaKit.liquidity_label(String(company.get("liquidity", ""))),
		SmaKit.style_label(SmaAcademy.style_of(ticker)),
	]
	var split_factor := float(game.exchange.state.get("companies", {}).get(ticker, {})
		.get("splitFactor", 1.0))
	var live_fin := SmaFundamentals.live_valuation(ticker, last, game.get_day(), split_factor)
	if not live_fin.is_empty():
		var raw_pe: Variant = live_fin.get("pe", null)
		var pe_str := ("P/E " + SmaFormat.num(float(raw_pe), 1) + " · ") \
			if (raw_pe != null and float(raw_pe) > 0.0) else ""
		_profile_label.text = "%s%s %.2f%% · %s %s" % [
			pe_str,
			I18n.t("company.dividendYield"), float(live_fin.get("dividendYieldPct", 0.0)),
			I18n.t("company.marketCap"), SmaFormat.compact(float(live_fin.get("marketCap", 0.0))),
		]
	else:
		var financials: Dictionary = company.get("financials", {})
		var dividend_yield := float(financials.get("dividendPerShare", 0.0)) / maxf(0.01, last) * 100.0
		var live_cap := float(company.get("sharesOutstanding", company.get("shares", 0.0))) * last
		if live_cap <= 0.0:
			live_cap = float(company.get("marketCap", 0.0))
		_profile_label.text = "%s %.2f%% · %s %s" % [
			I18n.t("company.dividendYield"), dividend_yield,
			I18n.t("company.marketCap"), SmaFormat.compact(live_cap),
		]
	var sensitivity := SmaIndustry.sector_sensitivity(String(company.get("sector", "")))
	_sensitivity_label.text = "%s · %s / %s / %s" % [
		I18n.t("exchange.macroSensitivity"),
		_signed_num(float(sensitivity["growth"])),
		_signed_num(float(sensitivity["rates"])),
		_signed_num(float(sensitivity["energy"])),
	]
	_update_quote_numbers(quote)
	if _order_type == "limit" and _ticket_ticker != ticker:
		_limit.set_value_no_signal(maxf(0.01, SmaFormat.round_to(last, 2)))
	var ticker_changed := _ticket_ticker != ticker
	_ticket_ticker = ticker
	if _order_type == "stop" and _stop_ticker != ticker:
		_reset_stop_price()
	if ticker_changed:
		_position_key = ""
		_indicator_cache_key = ""
	_update_tool_gates()
	_update_book(ticker)
	_update_chart(ticker)
	_update_indicators(ticker, last)
	_update_position(ticker)
	_update_orders()
	_update_available()
	_update_estimate()
	_update_oco(ticker, last)


func _update_quote_numbers(quote: Dictionary) -> void:
	var last := float(quote.get("last", 0.0))
	var change := float(quote.get("changePct", 0.0))
	_last_label.text = SmaFormat.money(last)
	_change_label.text = SmaFormat.pct(change)
	_change_label.add_theme_color_override("font_color", SmaKit.value_color(change))
	_stat_labels["high"].text = SmaFormat.money(float(quote.get("high", 0.0)))
	_stat_labels["low"].text = SmaFormat.money(float(quote.get("low", 0.0)))
	_stat_labels["bid"].text = _price_text(quote.get("bid", null))
	_stat_labels["ask"].text = _price_text(quote.get("ask", null))
	_stat_labels["volume"].text = SmaFormat.compact(float(quote.get("volume", 0)))
	if _reason_label != null and game != null and game.exchange != null:
		var sym := String(quote.get("ticker", game.selected_ticker))
		_reason_label.text = SmaKit.format_attribution(game.exchange.state, sym)
		_reason_label.add_theme_color_override("font_color",
			SmaUiTheme.GOLD if absf(change) >= 0.25 else SmaUiTheme.MUTED)


func _update_tool_gates() -> void:
	if game == null:
		return
	var limit_ok: bool = game.academy_is_tool_unlocked("order.limit")
	var stop_ok: bool = game.academy_is_tool_unlocked("order.stop")
	var short_ok: bool = game.academy_is_tool_unlocked("trade.short")
	if _limit_type_button != null:
		_limit_type_button.disabled = not limit_ok
		_limit_type_button.tooltip_text = "" if limit_ok else I18n.t("unlock.limitOrder.title")
	for key in ["stop", "trailing"]:
		var btn: Button = _type_buttons.get(key)
		if btn != null:
			btn.disabled = not stop_ok
			btn.tooltip_text = "" if stop_ok else I18n.t("unlock.stop.desc")
	var short_btn: Button = _side_buttons.get("short")
	if short_btn != null:
		short_btn.disabled = not short_ok
		short_btn.tooltip_text = "" if short_ok else I18n.t("unlock.short.desc")
	if _limit_hint != null:
		var hints: Array[String] = []
		if not limit_ok:
			hints.append(I18n.t("academy.lockedByUnit", {"unit": I18n.t("curriculum.u4.title")}))
		elif not short_ok or not stop_ok:
			hints.append(I18n.t("trade.toolsProgressiveHint"))
		_limit_hint.visible = not hints.is_empty()
		_limit_hint.text = " · ".join(hints)
	if not limit_ok and _order_type == "limit":
		_order_type = "market"
		_limit_row.visible = false
	if not stop_ok and (_order_type == "stop" or _order_type == "trailing"):
		_order_type = "market"
		_stop_row.visible = false
		_trail_row.visible = false
	if not short_ok and _side == "short":
		_side = "buy"
		if _side_buttons.has("buy"):
			_side_buttons["buy"].set_pressed_no_signal(true)


func on_tick() -> void:
	if game == null or not game.started or game.exchange == null:
		return
	var ticker: String = game.selected_ticker
	if ticker != _ticket_ticker:
		refresh("selection")
		return
	var quote: Dictionary = game.exchange.quote(ticker)
	_update_quote_numbers(quote)
	_update_book(ticker)
	_update_chart(ticker)
	_update_position_pnl_live(ticker, float(quote.get("last", 0.0)))
	_update_orders()
	_update_available()
	_update_estimate()


func capture_draft() -> Dictionary:
	if not game.started or _ticket_ticker.is_empty():
		return {}
	var values: Array = []
	for field in _draft_fields(not _oco_key.is_empty()):
		values.append([field.value, field.get_line_edit().text])
	return {"ticker": _ticket_ticker, "side": _side, "type": _order_type,
		"ocoKey": _oco_key, "values": values}


func restore_draft(draft: Dictionary) -> void:
	if draft.get("ticker") != _ticket_ticker or not draft.has("values"):
		return
	var side: String = draft["side"]
	var order_type: String = draft["type"]
	if order_type == "limit" and _limit_type_button.disabled:
		order_type = "market"
	if order_type in ["stop", "trailing"] and _type_buttons.get("stop") != null \
			and _type_buttons["stop"].disabled:
		order_type = "market"
	if side == "short" and _side_buttons.get("short") != null and _side_buttons["short"].disabled:
		side = "buy"
	for button in _side_group.get_buttons():
		button.set_pressed_no_signal(button.text == I18n.t("trade.%s" % side))
	for button in _type_group.get_buttons():
		button.set_pressed_no_signal(button.text == I18n.t("trade.%s" % order_type))
	_on_side(side)
	_on_type(order_type)
	var fields := _draft_fields(not _oco_key.is_empty() and draft["ocoKey"] == _oco_key)
	var values: Array = draft["values"]
	for index in fields.size():
		var field := fields[index]
		field.set_value_no_signal(values[index][0])
		field.get_line_edit().text = values[index][1]
		field.apply()
	_update_estimate()


func _draft_fields(include_oco: bool) -> Array[SpinBox]:
	var fields: Array[SpinBox] = [_qty, _limit, _stop_price, _trail_pct]
	if include_oco:
		fields.append_array([_oco_qty, _oco_tp, _oco_stop])
	return fields


func _set_empty(empty: bool) -> void:
	var hint: Control = get_node_or_null("EmptyHint")
	for child in get_children():
		if child.name == "EmptyHint":
			continue
		child.visible = not empty
	if empty and hint == null:
		var label := SmaKit.muted(I18n.t("trade.no_selection"))
		label.name = "EmptyHint"
		label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		add_child(label)
	elif hint != null:
		hint.visible = empty


func _price_text(value: Variant) -> String:
	return SmaFormat.num(float(value), 2) if value != null else "—"


func _update_book(ticker: String) -> void:
	var depth_unlocked: bool = game.academy_is_tool_unlocked("market.depth")
	var levels := 6 if depth_unlocked else 1
	var book: Dictionary = game.exchange.get_book(ticker, levels)
	var asks: Array = book.get("asks", [])
	var bids: Array = book.get("bids", [])
	if not asks.is_empty() and not bids.is_empty():
		var best_ask := float(asks[0]["price"])
		var best_bid := float(bids[0]["price"])
		_book_meta.text = "%s %s · %s %s" % [
			I18n.t("trade.spread"), SmaFormat.num(best_ask - best_bid, 2),
			I18n.t("trade.mid"), SmaFormat.num((best_ask + best_bid) * 0.5, 2),
		]
	else:
		_book_meta.text = ""
	var max_size := 1.0
	for entry in asks:
		max_size = maxf(max_size, float(entry.get("size", 0.0)))
	for entry in bids:
		max_size = maxf(max_size, float(entry.get("size", 0.0)))
	for index in _book_rows.size():
		var pair: Dictionary = _book_rows[index]
		var ask_item: Dictionary = pair["ask"]
		var bid_item: Dictionary = pair["bid"]
		var show_ask := depth_unlocked or index == _book_rows.size() - 1
		var show_bid := depth_unlocked or index == 0
		ask_item["container"].visible = show_ask
		bid_item["container"].visible = show_bid
		var ask_index := asks.size() - 1 - index if depth_unlocked else 0
		if show_ask and ask_index >= 0 and ask_index < asks.size():
			var p := float(asks[ask_index]["price"])
			var sz := float(asks[ask_index]["size"])
			ask_item["value"] = p
			ask_item["price"].text = SmaFormat.num(p, 2)
			ask_item["size"].text = SmaFormat.quantity(sz)
			ask_item["bar"].anchor_right = clampf(sz / max_size, 0.04, 1.0)
		else:
			ask_item["value"] = 0.0
			ask_item["price"].text = "—"
			ask_item["size"].text = "—"
			ask_item["bar"].anchor_right = 0.0
		if show_bid and index < bids.size():
			var p := float(bids[index]["price"])
			var sz := float(bids[index]["size"])
			bid_item["value"] = p
			bid_item["price"].text = SmaFormat.num(p, 2)
			bid_item["size"].text = SmaFormat.quantity(sz)
			bid_item["bar"].anchor_right = clampf(sz / max_size, 0.04, 1.0)
		else:
			bid_item["value"] = 0.0
			bid_item["price"].text = "—"
			bid_item["size"].text = "—"
			bid_item["bar"].anchor_right = 0.0
	if _book_depth_hint != null:
		_book_depth_hint.visible = not depth_unlocked
		if not depth_unlocked:
			_book_depth_hint.text = I18n.t("unlock.depth.desc")


func _update_chart(ticker: String) -> void:
	var candles: Array = game.exchange.get_candles(ticker, _timeframe)
	_start_chart.visible = candles.is_empty() and game.paused
	_start_chart.disabled = game.is_story_paused() or game.is_fast_forwarding()
	var title := "%s · %s" % [ticker, _timeframe]
	if _timeframe == "1m":
		var second := int(game.exchange.state["second"]) % 60
		title += " · " + I18n.t("chart.referenceQuote")
		title += " · " + I18n.t("chart.nextMinute", {"seconds": 60 - second})
	_chart.set_candles(candles, _timeframe, title)
	var cat_key := "%s|%d|%d|%d" % [
		ticker,
		int(game.exchange.state.get("dayIndex", 0)),
		int(game.exchange.state.get("newsSeq", 0)),
		int(game.exchange.state.get("corporateActions", []).size()),
	]
	if cat_key != _catalyst_cache_key:
		_catalyst_cache_key = cat_key
		_chart.set_candle_notes(SmaKit.format_candle_catalysts(game.exchange.state, ticker))
	var account: Dictionary = game.exchange.state["account"]
	var markers: Array = []
	for trade in account.get("trades", []):
		if String(trade.get("ticker", "")) == ticker:
			markers.append(trade)
	_chart.set_trade_markers(markers)
	var long_cost := 0.0
	var short_cost := 0.0
	var position: Dictionary = account.get("positions", {}).get(ticker, {})
	if int(position.get("qty", 0)) > 0:
		long_cost = float(position.get("avgCost", 0.0))
	var short_position: Dictionary = account.get("shorts", {}).get(ticker, {})
	if int(short_position.get("qty", 0)) > 0:
		short_cost = float(short_position.get("avgPrice", 0.0))
	_chart.set_position_cost(long_cost, short_cost)
	_chart.set_price_lines(_collect_price_lines(ticker))


func _collect_price_lines(ticker: String) -> Array:
	var lines: Array = []
	for alert in game.price_alerts():
		if bool(alert.get("active", false)) and String(alert.get("ticker", "")) == ticker:
			var side := String(alert.get("side", "above"))
			var tag := I18n.t("alerts.above" if side == "above" else "alerts.below")
			lines.append({
				"price": float(alert.get("price", 0.0)),
				"label": "⚑ %s" % tag,
				"color": SmaUiTheme.INFO,
			})
	for order in game.exchange.open_order_rows("player"):
		if String(order.get("ticker", "")) != ticker:
			continue
		var order_type := String(order.get("type", ""))
		var price := 0.0
		if order_type == "limit" and order.get("limitPrice") != null:
			price = float(order["limitPrice"])
		elif order.get("stopPrice") != null:
			price = float(order["stopPrice"])
		if price <= 0.0:
			continue
		var is_buy := String(order.get("side", "")) in ["buy", "cover"]
		lines.append({
			"price": price,
			"label": "%s %s" % [I18n.t("trade.%s" % String(order.get("side", "buy"))),
				I18n.t("trade.%s" % order_type) if I18n.has_key("trade.%s" % order_type) else order_type],
			"color": SmaUiTheme.POSITIVE if is_buy else SmaUiTheme.NEGATIVE,
		})
	return lines


func _on_range(count: int) -> void:
	if _chart == null:
		return
	_chart.set_visible_count(count)
	for value in _range_buttons.keys():
		_range_buttons[value].button_pressed = int(value) == int(count)


func _on_chart_range_changed(count: int) -> void:
	for value in _range_buttons.keys():
		_range_buttons[value].button_pressed = int(value) == int(count)


func _update_indicators(ticker: String, last: float) -> void:
	if _indicators_card == null:
		return
	_indicators_card.visible = String(game.settings.get("layout", "beginner")) == "advanced"
	if not _indicators_card.visible:
		return
	var daily: Array = game.exchange.get_candles(ticker, "1D")
	var cache_key := "%s|%d|%d|%.2f" % [ticker, game.get_day(), daily.size(), last]
	if cache_key == _indicator_cache_key:
		return
	_indicator_cache_key = cache_key
	var snapshot := SmaIndicators.snapshot(daily, last)
	if snapshot.is_empty():
		for key in _indicator_labels.keys():
			_indicator_labels[key].text = "—"
		return
	var sma20 := float(snapshot["sma20"])
	var sma50 := float(snapshot["sma50"])
	var rsi14 := float(snapshot["rsi14"])
	var volatility := float(snapshot["volatility"])
	var drawdown := float(snapshot["drawdown"])
	_indicator_labels["sma20"].text = "—" if is_nan(sma20) else SmaFormat.money(sma20)
	_indicator_labels["sma50"].text = "—" if is_nan(sma50) else SmaFormat.money(sma50)
	_indicator_labels["rsi14"].text = "—" if is_nan(rsi14) else SmaFormat.num(rsi14, 1)
	var trend := String(snapshot["trend"])
	var trend_key := "trade.trendUnknown"
	var trend_color := SmaUiTheme.MUTED
	if trend == "up":
		trend_key = "trade.trendUp"
		trend_color = SmaUiTheme.POSITIVE
	elif trend == "down":
		trend_key = "trade.trendDown"
		trend_color = SmaUiTheme.NEGATIVE
	elif trend == "flat":
		trend_key = "trade.trendFlat"
	_indicator_labels["trend"].text = I18n.t(trend_key)
	_indicator_labels["trend"].add_theme_color_override("font_color", trend_color)
	_indicator_labels["volatility"].text = "—" if is_nan(volatility) \
		else SmaFormat.pct_plain(volatility, 1)
	_indicator_labels["drawdown"].text = "—" if is_nan(drawdown) \
		else SmaFormat.pct_plain(drawdown, 1)
	_indicator_labels["drawdown"].add_theme_color_override("font_color", SmaUiTheme.NEGATIVE)


func _signed_num(value: float) -> String:
	return ("+" if value > 0.0 else "") + SmaFormat.num(value, 2)


func _update_position(ticker: String) -> void:
	var long_position: Dictionary = game.exchange.state["account"]["positions"].get(ticker, {})
	var short_position: Dictionary = game.exchange.state["account"]["shorts"].get(ticker, {})
	var key := "%s|%d|%.4f|%d|%.4f" % [
		ticker,
		int(long_position.get("qty", 0)), float(long_position.get("avgCost", 0.0)),
		int(short_position.get("qty", 0)), float(short_position.get("avgPrice", 0.0)),
	]
	var quote: Dictionary = game.exchange.quote(ticker)
	var last := float(quote.get("last", 0.0))
	if key == _position_key:
		_update_position_pnl_live(ticker, last)
		return
	_position_key = key
	_position_pnl_labels.clear()
	SmaKit.clear_children(_position_box)
	if long_position.is_empty() and short_position.is_empty():
		_position_box.add_child(SmaKit.muted(I18n.t("trade.no_position")))
		return
	if not long_position.is_empty():
		var qty := int(long_position["qty"])
		var avg := float(long_position["avgCost"])
		var unrealized := (last - avg) * qty
		var row := SmaKit.data_row([
			I18n.t("trade.buy"), SmaFormat.quantity(qty), SmaFormat.num(avg, 2),
			SmaFormat.signed_money(unrealized),
		], [0.9, 0.8, 0.9, 1.2], [SmaUiTheme.POSITIVE, SmaUiTheme.TEXT, SmaUiTheme.MUTED,
			SmaKit.value_color(unrealized)], [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_RIGHT,
			HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT])
		_position_pnl_labels["long"] = row.get_child(3)
		_position_box.add_child(row)
		var actions := SmaKit.hbox(6)
		actions.add_child(SmaKit.hspacer())
		if qty >= 2:
			var half_btn := SmaKit.button(I18n.t("trade.closeHalf"),
				_quick_close.bind("sell", int(floor(qty / 2.0))))
			SmaKit.set_small_font(half_btn, 11)
			actions.add_child(half_btn)
		var close_btn := SmaKit.button(I18n.t("trade.closeAll"), _quick_close.bind("sell", qty))
		SmaKit.set_small_font(close_btn, 11)
		actions.add_child(close_btn)
		_position_box.add_child(actions)
	if not short_position.is_empty():
		var qty := int(short_position["qty"])
		var avg := float(short_position["avgPrice"])
		var unrealized := (avg - last) * qty
		var row := SmaKit.data_row([
			I18n.t("trade.short"), SmaFormat.quantity(qty), SmaFormat.num(avg, 2),
			SmaFormat.signed_money(unrealized),
		], [0.9, 0.8, 0.9, 1.2], [SmaUiTheme.NEGATIVE, SmaUiTheme.TEXT, SmaUiTheme.MUTED,
			SmaKit.value_color(unrealized)], [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_RIGHT,
			HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT])
		_position_pnl_labels["short"] = row.get_child(3)
		_position_box.add_child(row)
		var actions := SmaKit.hbox(6)
		actions.add_child(SmaKit.hspacer())
		if qty >= 2:
			var half_btn := SmaKit.button(I18n.t("trade.closeHalf"),
				_quick_close.bind("cover", int(floor(qty / 2.0))))
			SmaKit.set_small_font(half_btn, 11)
			actions.add_child(half_btn)
		var close_btn := SmaKit.button(I18n.t("trade.closeAll"), _quick_close.bind("cover", qty))
		SmaKit.set_small_font(close_btn, 11)
		actions.add_child(close_btn)
		_position_box.add_child(actions)


func _update_position_pnl_live(ticker: String, last: float) -> void:
	var long_position: Dictionary = game.exchange.state["account"]["positions"].get(ticker, {})
	if not long_position.is_empty() and _position_pnl_labels.has("long"):
		var lbl: Label = _position_pnl_labels["long"]
		if is_instance_valid(lbl):
			var unrealized := (last - float(long_position["avgCost"])) * int(long_position["qty"])
			lbl.text = SmaFormat.signed_money(unrealized)
			lbl.add_theme_color_override("font_color", SmaKit.value_color(unrealized))
	var short_position: Dictionary = game.exchange.state["account"]["shorts"].get(ticker, {})
	if not short_position.is_empty() and _position_pnl_labels.has("short"):
		var lbl: Label = _position_pnl_labels["short"]
		if is_instance_valid(lbl):
			var unrealized := (float(short_position["avgPrice"]) - last) * int(short_position["qty"])
			lbl.text = SmaFormat.signed_money(unrealized)
			lbl.add_theme_color_override("font_color", SmaKit.value_color(unrealized))


func _order_price_summary(order: Dictionary) -> String:
	var order_type := String(order.get("type", ""))
	if order_type == "limit" and order.get("limitPrice") != null:
		return "@%s" % SmaFormat.money(float(order["limitPrice"]))
	if order_type == "trailing":
		var pct := float(order.get("trailPct", 0.0)) * 100.0
		var stop_v: Variant = order.get("stopPrice")
		if stop_v != null:
			return "-%.1f%% (%s)" % [pct, SmaFormat.money(float(stop_v))]
		return "-%.1f%%" % pct
	if order.get("stopPrice") != null:
		return "@%s" % SmaFormat.money(float(order["stopPrice"]))
	return ""


func _update_orders() -> void:
	var orders: Array = game.exchange.open_order_rows("player")
	var key_parts: Array[String] = []
	for order in orders:
		key_parts.append("%s:%s:%s:%s" % [order.get("id", ""), order.get("status", ""),
			order.get("filledQty", 0), str(order.get("stopPrice", ""))])
	var key := "|".join(key_parts)
	if key == _orders_key:
		return
	_orders_key = key
	SmaKit.clear_children(_orders_box)
	_order_buttons.clear()
	if orders.is_empty():
		_orders_box.add_child(SmaKit.muted(I18n.t("trade.no_orders")))
		return
	for order in orders:
		var row := SmaKit.hbox(6)
		var side_key := "trade.%s" % String(order.get("side", "buy"))
		var side_label := I18n.t(side_key) if I18n.has_key(side_key) else String(order.get("side", ""))
		var type_key := "trade.%s" % String(order.get("type", "market"))
		var type_label := I18n.t(type_key) if I18n.has_key(type_key) else String(order.get("type", ""))
		var price_text := _order_price_summary(order)
		var label := "%s %s %s %s · %s/%s" % [
			String(order.get("ticker", "")),
			side_label,
			type_label,
			price_text,
			SmaFormat.quantity(float(order.get("filledQty", 0))),
			SmaFormat.quantity(float(order.get("qty", 0))),
		]
		row.add_child(SmaKit.cell(label.strip_edges(), 1.0, HORIZONTAL_ALIGNMENT_LEFT, SmaUiTheme.MUTED, 11))
		var cancel := SmaKit.button(I18n.t("trade.cancel"), _cancel.bind(String(order.get("id", ""))))
		SmaKit.set_small_font(cancel, 11)
		row.add_child(cancel)
		_orders_box.add_child(row)


func _update_available() -> void:
	var cash: float = float(game.exchange.available_cash())
	var bp: float = game.effective_buying_power()
	var suffix := "" if game.academy_is_tool_unlocked("trade.margin") \
		else " (%s)" % I18n.t("trade.cashAccount")
	_available_label.text = "%s %s · %s %s%s" % [
		I18n.t("trade.available_cash"), SmaFormat.money(cash),
		I18n.t("trade.buying_power"), SmaFormat.money(bp),
		suffix,
	]
	var ticker := String(game.selected_ticker)
	var company: Dictionary = game.exchange.company(ticker)
	var quote: Dictionary = game.exchange.quote(ticker)
	if _short_info_label != null:
		var has_short := int(game.exchange.state["account"]["shorts"].get(ticker, {}).get("qty", 0)) > 0
		if _side in ["short", "cover"] or has_short:
			var borrow_rate := SmaMargin.borrow_fee_rate(company) * 100.0
			var m_rate := SmaMargin.live_margin_rate(game.exchange.state) * 100.0
			var si_pct := SmaMargin.short_interest_pct(company, game.get_day(),
				String(game.exchange.state.get("seed", "sim-exchange-v1")))
			var tier_key := "trade.htbExtreme" if borrow_rate >= 25.0 \
				else ("trade.htbHard" if borrow_rate >= 10.0 else "trade.htbEasy")
			_short_info_label.text = I18n.t("trade.shortInfo", {
				"borrowRate": SmaFormat.pct_plain(borrow_rate, 1),
				"tier": I18n.t(tier_key),
				"shortInterest": SmaFormat.pct_plain(si_pct, 1),
				"marginRate": SmaFormat.pct_plain(m_rate, 1),
			})
			_short_info_label.add_theme_color_override("font_color",
				SmaKit.value_color(-1.0) if borrow_rate >= 25.0 else SmaUiTheme.GOLD)
			_short_info_label.visible = true
		else:
			_short_info_label.visible = false
	if _micro_warn_label != null:
		var s_mult := float(quote.get("spreadMult", 1.0))
		if s_mult >= 1.35:
			_micro_warn_label.text = I18n.t("trade.liquidityStressWarn", {
				"mult": SmaFormat.num(s_mult, 1),
			})
			_micro_warn_label.visible = true
		else:
			_micro_warn_label.visible = false


func _oco_spin_row(box: VBoxContainer, label_text: String, minimum: float,
		step: float) -> SpinBox:
	var row := SmaKit.hbox(8)
	row.add_child(SmaKit.label(label_text, 12, SmaUiTheme.MUTED))
	row.add_child(SmaKit.hspacer())
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = 1000000
	spin.step = step
	spin.custom_minimum_size.x = 130
	row.add_child(spin)
	box.add_child(row)
	return spin


## OCO exits only make sense for an open long or short. Quotes can carry two
## legs that reserve the same shares, so the card hides once both are working.
func _update_oco(ticker: String, last: float) -> void:
	if _oco_card == null:
		return
	var account: Dictionary = game.exchange.state["account"]
	var long_qty := int(account["positions"].get(ticker, {}).get("qty", 0))
	var short_qty := int(account["shorts"].get(ticker, {}).get("qty", 0))
	var action := "closeLong" if long_qty > 0 else "closeShort"
	var available: int = game.exchange.available_shares(ticker) if long_qty > 0 \
		else game.exchange.available_short_shares(ticker)
	_oco_card.visible = available > 0
	if not _oco_card.visible:
		_oco_key = ""
		_oco_feedback.text = ""
		return
	var key := "%s|%s" % [ticker, action]
	if key != _oco_key:
		_oco_key = key
		_oco_action = action
		_oco_qty.max_value = float(available)
		_oco_qty.value = float(available)
		var take_profit := last * (1.1 if action == "closeLong" else 0.9)
		var stop := last * (0.9 if action == "closeLong" else 1.1)
		_oco_tp.value = maxf(0.01, SmaFormat.round_to(take_profit, 2))
		_oco_stop.value = maxf(0.01, SmaFormat.round_to(stop, 2))
		_oco_feedback.text = ""
	else:
		_oco_qty.max_value = float(available)
	var limit_ok: bool = game.academy_is_tool_unlocked("order.limit")
	var stop_ok: bool = game.academy_is_tool_unlocked("order.stop")
	var unlocked := limit_ok and stop_ok
	_oco_submit.disabled = not unlocked
	if not limit_ok:
		_oco_feedback.text = I18n.t("error.order.limitLocked")
		_oco_feedback.add_theme_color_override("font_color", SmaUiTheme.WARNING)
	elif not stop_ok:
		_oco_feedback.text = I18n.t("error.order.stopLocked")
		_oco_feedback.add_theme_color_override("font_color", SmaUiTheme.WARNING)
	elif _oco_feedback.text in [I18n.t("error.limitLocked"), I18n.t("error.order.stopLocked")]:
		_oco_feedback.text = ""


func _current_price() -> float:
	var ticker: String = game.selected_ticker
	var quote: Dictionary = game.exchange.quote(ticker)
	if _order_type == "limit":
		return _limit.value
	if _order_type == "stop":
		return _stop_price.value
	var buying := _side == "buy" or _side == "cover"
	var value: Variant = quote.get("ask") if buying else quote.get("bid")
	return float(value) if value != null else float(quote.get("last", 0.0))


func _update_estimate() -> void:
	if _estimate_label == null or game == null or not game.started:
		return
	var price := _current_price()
	var value := price * _qty.value
	var fee := SmaFormat.round_to(value * float(game.exchange.fee_bps) / 10000.0, 2)
	_estimate_label.text = SmaFormat.money(value)
	_fee_label.text = SmaFormat.money(fee)
	if _weight_label != null and game.exchange != null:
		var equity: float = game.get_equity()
		var ticker: String = game.selected_ticker
		var held := int(game.exchange.state["account"]["positions"].get(ticker, {}).get("qty", 0))
		var short_held := int(game.exchange.state["account"]["shorts"].get(ticker, {}).get("qty", 0))
		var post_qty := held
		if _side == "buy":
			post_qty = held + int(_qty.value)
		elif _side == "sell":
			post_qty = maxi(0, held - int(_qty.value))
		elif _side == "short":
			post_qty = short_held + int(_qty.value)
		elif _side == "cover":
			post_qty = maxi(0, short_held - int(_qty.value))
		var pct := (float(post_qty) * price / equity * 100.0) if equity > 0.0 else 0.0
		_weight_label.text = I18n.t("trade.postWeight", {"pct": SmaFormat.pct_plain(pct, 1)})
		_weight_label.add_theme_color_override("font_color",
			SmaUiTheme.WARNING if pct > 25.0 else SmaUiTheme.DIM)


func _on_side(side: String) -> void:
	if game != null and side in ["short", "cover"] and not game.academy_is_tool_unlocked("trade.short"):
		return
	_side = side
	if _submit_button != null:
		SmaUiTheme.apply_arcade_button(_submit_button,
			"buy" if _side in ["buy", "cover"] else "sell", 8)
	_feedback.text = ""
	if _order_type == "stop":
		_reset_stop_price()
	_update_available()
	_update_estimate()


func _on_type(order_type: String) -> void:
	if game != null:
		if order_type == "limit" and not game.academy_is_tool_unlocked("order.limit"):
			return
		if order_type in ["stop", "trailing"] and not game.academy_is_tool_unlocked("order.stop"):
			return
	_order_type = order_type
	_limit_row.visible = order_type == "limit"
	_stop_row.visible = order_type == "stop"
	_trail_row.visible = order_type == "trailing"
	if order_type == "limit":
		var quote: Dictionary = game.exchange.quote(game.selected_ticker)
		var reference := float(quote.get("last", _limit.value))
		_limit.value = maxf(0.01, SmaFormat.round_to(reference, 2))
	elif order_type == "stop":
		_reset_stop_price()
	_update_estimate()


func _reset_stop_price() -> void:
	if _stop_price == null or game == null or not game.started:
		return
	var quote: Dictionary = game.exchange.quote(game.selected_ticker)
	var reference := float(quote.get("last", _stop_price.value))
	var buying := _side == "buy" or _side == "cover"
	_stop_ticker = game.selected_ticker
	_stop_price.value = maxf(0.01,
		SmaFormat.round_to(reference * (1.05 if buying else 0.95), 2))


func _on_timeframe(timeframe: String) -> void:
	game.set_chart_timeframe(timeframe)


func _open_intro_review() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("navigate"):
		main.navigate("dashboard")


func _submit() -> void:
	if game == null or not game.started:
		return
	var params := {
		"ticker": game.selected_ticker,
		"side": _side,
		"type": _order_type,
		"qty": int(_qty.value),
	}
	if _order_type == "limit":
		params["limitPrice"] = _limit.value
	elif _order_type == "stop":
		params["stopPrice"] = _stop_price.value
	elif _order_type == "trailing":
		params["trailPct"] = _trail_pct.value / 100.0
	var result: Dictionary = game.submit_order(params)
	if bool(result.get("ok", false)):
		var order: Dictionary = result.get("order", {})
		var filled := int(order.get("filledQty", 0))
		_feedback.text = I18n.t("trade.order_filled") if filled > 0 else I18n.t("trade.order_submitted")
		_feedback.add_theme_color_override("font_color", SmaUiTheme.POSITIVE)
		_orders_key = ""
		_position_key = ""
	else:
		var error_key := String(result.get("error", "order.invalid"))
		_feedback.text = I18n.t("error.%s" % error_key)
		_feedback.add_theme_color_override("font_color", SmaUiTheme.NEGATIVE)
	refresh()


func _cancel(order_id: String) -> void:
	game.cancel_order(order_id)
	_orders_key = ""
	refresh()


func _submit_oco() -> void:
	if game == null or not game.started or _oco_card == null:
		return
	var quantity := int(_oco_qty.value)
	var result: Dictionary = game.submit_oco({
		"ticker": game.selected_ticker,
		"action": _oco_action,
		"qty": quantity,
		"takeProfitPrice": _oco_tp.value,
		"stopPrice": _oco_stop.value,
	})
	if bool(result.get("ok", false)):
		game.toast(I18n.t("exchange.ocoSubmitted", {"qty": quantity}))
		_orders_key = ""
		refresh()
		return
	var error_key := String(result.get("error", "order.oco"))
	_oco_feedback.text = I18n.t("error.%s" % error_key)
	_oco_feedback.add_theme_color_override("font_color", SmaUiTheme.NEGATIVE)
