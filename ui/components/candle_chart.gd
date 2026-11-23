## Canvas candle + volume chart with moving averages, a crosshair OHLC readout,
## volume MA, position cost lines and trade markers. Reads only the candles it
## is given; it never asks the engine for future data.
class_name SmaCandleChart
extends Control

signal visible_count_changed(count: int)

const MA_PERIODS := [5, 10, 20, 60]
const VMA_PERIOD := 5
const MIN_VISIBLE := 20
const MAX_VISIBLE := 250
const DEFAULT_VISIBLE := 60

var candles: Array = []
var title_text: String = ""
var timeframe: String = "1m"
var visible_count := DEFAULT_VISIBLE
var trade_markers: Array = []
var long_cost := 0.0
var short_cost := 0.0

var _font: Font
var _font_size := 10
var _hover_index := -1
var _hover_pos := Vector2(-1, -1)
var _plot := Rect2()
var _left := 0.0
var _right := 0.0
var _top := 0.0
var _price_bottom := 0.0
var _volume_top := 0.0
var _volume_bottom := 0.0
var _slot := 0.0
var _visible: Array = []
var _low := 0.0
var _high := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(320, 300)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	focus_mode = Control.FOCUS_NONE
	mouse_exited.connect(_on_mouse_exited)


func set_candles(next_candles: Array, next_timeframe: String = "1m",
		next_title: String = "") -> void:
	candles = next_candles
	timeframe = next_timeframe
	title_text = next_title
	queue_redraw()


func set_visible_count(count: int) -> void:
	var next_count := clampi(count, MIN_VISIBLE, MAX_VISIBLE)
	if next_count == visible_count:
		return
	visible_count = next_count
	visible_count_changed.emit(visible_count)
	queue_redraw()


func set_trade_markers(next_markers: Array) -> void:
	trade_markers = next_markers
	queue_redraw()


func set_position_cost(next_long_cost: float, next_short_cost: float) -> void:
	long_cost = maxf(0.0, next_long_cost)
	short_cost = maxf(0.0, next_short_cost)
	queue_redraw()


func _draw() -> void:
	_font = get_theme_default_font()
	_font_size = 10
	draw_rect(Rect2(Vector2.ZERO, size), SmaUiTheme.BG_DEEP)
	if title_text != "":
		draw_string(_font, Vector2(12, 20), title_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SmaUiTheme.MUTED)
	if candles.is_empty():
		draw_string(_font, Vector2(12, size.y * 0.5), I18n.t("chart.no_data"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SmaUiTheme.DIM)
		return
	var count := mini(visible_count, candles.size())
	if count <= 0:
		return
	var start := candles.size() - count
	_visible = candles.slice(start)
	_left = 12.0
	_right = size.x - 74.0
	_top = 62.0
	_price_bottom = size.y - 76.0
	_volume_top = _price_bottom + 12.0
	_volume_bottom = size.y - 22.0
	if _right <= _left or _price_bottom <= _top:
		return
	_low = INF
	_high = -INF
	var max_volume := 1.0
	for bar in _visible:
		_low = minf(_low, float(bar["l"]))
		_high = maxf(_high, float(bar["h"]))
		max_volume = maxf(max_volume, float(bar.get("v", 0)))
	if _high - _low < 0.0001:
		_high += 0.5
		_low -= 0.5
	var padding := (_high - _low) * 0.08
	_high += padding
	_low -= padding
	_slot = (_right - _left) / float(count)
	_plot = Rect2(_left, _top, _right - _left, _volume_bottom - _top)
	# Keep the crosshair under the pointer while live candles append or the
	# redraw timer fires; only its bar index is recomputed.
	_hover_index = -1
	if _hover_pos.x >= 0.0 and _plot.has_point(_hover_pos):
		_hover_index = clampi(int(floor((_hover_pos.x - _left) / _slot)),
			0, _visible.size() - 1)

	var ma_series: Dictionary = {}
	for period in MA_PERIODS:
		ma_series[period] = _moving_average(period, "c")
	var vma := _moving_average(VMA_PERIOD, "v")
	for value in vma:
		if not is_nan(float(value)):
			max_volume = maxf(max_volume, float(value))
	var body_width := maxf(1.5, _slot * 0.62)
	if timeframe == "1m":
		body_width = minf(body_width, 24.0)
	_draw_grid()
	_draw_volume(max_volume, body_width)
	_draw_candles(body_width)
	_draw_ma_lines(ma_series, start)
	_draw_vma(vma, start, max_volume)
	_draw_cost_lines()
	_draw_trade_markers(start)
	_draw_last_price()
	_draw_legend(start)
	_draw_time_axis()
	if _hover_index >= 0 and _hover_index < _visible.size():
		_draw_crosshair()


func _moving_average(period: int, field: String) -> Array:
	var result: Array = []
	result.resize(candles.size())
	var total := 0.0
	for index in candles.size():
		total += float(candles[index].get(field, 0.0))
		if index >= period:
			total -= float(candles[index - period].get(field, 0.0))
		result[index] = total / float(period) if index >= period - 1 else NAN
	return result


func _draw_grid() -> void:
	for step in 5:
		var ratio := float(step) / 4.0
		var y := lerpf(_top, _price_bottom, ratio)
		draw_line(Vector2(_left, y), Vector2(_right, y),
			Color(SmaUiTheme.BORDER.r, SmaUiTheme.BORDER.g, SmaUiTheme.BORDER.b, 0.55), 1.0)
		var price := lerpf(_high, _low, ratio)
		draw_string(_font, Vector2(_right + 6, y + 3), SmaFormat.num(price, 2),
			HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, SmaUiTheme.DIM)
	for step in 4:
		var ratio := float(step) / 3.0
		var x := lerpf(_left, _right, ratio)
		draw_line(Vector2(x, _top), Vector2(x, _volume_bottom),
			Color(SmaUiTheme.BORDER.r, SmaUiTheme.BORDER.g, SmaUiTheme.BORDER.b, 0.32), 1.0)


func _draw_volume(max_volume: float, body_width: float) -> void:
	for index in _visible.size():
		var bar: Dictionary = _visible[index]
		var color := SmaUiTheme.POSITIVE if float(bar["c"]) >= float(bar["o"]) \
			else SmaUiTheme.NEGATIVE
		var volume := float(bar.get("v", 0))
		var height := (volume / max_volume) * maxf(2.0, _volume_bottom - _volume_top)
		var x := _left + _slot * (float(index) + 0.5)
		draw_rect(Rect2(x - body_width * 0.5, _volume_bottom - height,
			body_width, height), Color(color.r, color.g, color.b, 0.38))
	draw_line(Vector2(_left, _volume_top), Vector2(_right, _volume_top),
		Color(SmaUiTheme.BORDER.r, SmaUiTheme.BORDER.g, SmaUiTheme.BORDER.b, 0.45), 1.0)


func _draw_candles(body_width: float) -> void:
	for index in _visible.size():
		var bar: Dictionary = _visible[index]
		var open_price := float(bar["o"])
		var close_price := float(bar["c"])
		var high_price := float(bar["h"])
		var low_price := float(bar["l"])
		var x := _left + _slot * (float(index) + 0.5)
		var y_open := _price_y(open_price)
		var y_close := _price_y(close_price)
		var y_high := _price_y(high_price)
		var y_low := _price_y(low_price)
		var color := SmaUiTheme.POSITIVE if close_price >= open_price else SmaUiTheme.NEGATIVE
		draw_line(Vector2(x, y_high), Vector2(x, y_low), color, 1.0)
		var body_top := minf(y_open, y_close)
		var body_height := maxf(1.0, absf(y_close - y_open))
		draw_rect(Rect2(x - body_width * 0.5, body_top, body_width, body_height), color)


func _draw_ma_lines(ma_series: Dictionary, start: int) -> void:
	var colors := [SmaUiTheme.ACCENT, SmaUiTheme.WARNING, SmaUiTheme.INFO, Color("#a78bfa")]
	for period_index in MA_PERIODS.size():
		var period: int = MA_PERIODS[period_index]
		var series: Array = ma_series[period]
		var points := PackedVector2Array()
		for index in _visible.size():
			var value := float(series[start + index])
			if is_nan(value):
				if points.size() > 1:
					draw_polyline(points, colors[period_index], 1.2, true)
				points = PackedVector2Array()
				continue
			points.append(Vector2(_left + _slot * (float(index) + 0.5), _price_y(value)))
		if points.size() > 1:
			draw_polyline(points, colors[period_index], 1.2, true)


func _draw_vma(vma: Array, start: int, max_volume: float) -> void:
	var points := PackedVector2Array()
	for index in _visible.size():
		var value := float(vma[start + index])
		if is_nan(value):
			if points.size() > 1:
				draw_polyline(points, Color(SmaUiTheme.INFO.r, SmaUiTheme.INFO.g,
					SmaUiTheme.INFO.b, 0.9), 1.1, true)
			points = PackedVector2Array()
			continue
		var ratio := clampf(value / max_volume, 0.0, 1.0)
		points.append(Vector2(_left + _slot * (float(index) + 0.5),
			lerpf(_volume_bottom, _volume_top, ratio)))
	if points.size() > 1:
		draw_polyline(points, Color(SmaUiTheme.INFO.r, SmaUiTheme.INFO.g,
			SmaUiTheme.INFO.b, 0.9), 1.1, true)


func _draw_cost_lines() -> void:
	_draw_dashed_cost(long_cost, SmaUiTheme.WARNING, I18n.t("chart.costLong"))
	_draw_dashed_cost(short_cost, SmaUiTheme.NEGATIVE, I18n.t("chart.costShort"))


func _draw_dashed_cost(cost: float, color: Color, label: String) -> void:
	if cost <= 0.0:
		return
	var y := _price_y(cost)
	if y < _top or y > _price_bottom:
		return
	var x := _left
	while x < _right:
		draw_line(Vector2(x, y), Vector2(minf(x + 6.0, _right), y), color, 1.0)
		x += 10.0
	draw_string(_font, Vector2(_left + 6, y - 4), "%s %s" % [label, SmaFormat.num(cost, 2)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, color)


func _draw_trade_markers(start: int) -> void:
	if trade_markers.is_empty():
		return
	var limit := mini(trade_markers.size(), 80)
	var from := trade_markers.size() - limit
	for trade_index in range(from, trade_markers.size()):
		var trade: Dictionary = trade_markers[trade_index]
		var action := String(trade.get("action", ""))
		var side := String(trade.get("side", ""))
		var is_buy := action == "openLong" or action == "closeShort" or side == "buy"
		var is_sell := action == "openShort" or action == "closeLong" or side == "sell"
		if not is_buy and not is_sell:
			continue
		var index := _bar_index_for_trade(trade, start)
		if index < 0 or index >= _visible.size():
			continue
		var bar: Dictionary = _visible[index]
		var x := _left + _slot * (float(index) + 0.5)
		var color := SmaUiTheme.POSITIVE if is_buy else SmaUiTheme.NEGATIVE
		if is_buy:
			var y := _price_y(float(bar["l"])) + 7.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, y - 7.0), Vector2(x - 4.0, y), Vector2(x + 4.0, y)]), color)
		else:
			var y := _price_y(float(bar["h"])) - 7.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, y + 7.0), Vector2(x - 4.0, y), Vector2(x + 4.0, y)]), color)


func _bar_index_for_trade(trade: Dictionary, start: int) -> int:
	var date := String(trade.get("date", ""))
	if date == "":
		var day_index := int(trade.get("day", -1))
		if day_index >= 0:
			date = SmaCalendar.iso_date(day_index)
	if date == "":
		return -1
	var trade_time := String(trade.get("time", ""))
	if timeframe in ["1D", "1W", "1M"]:
		var fallback := -1
		for index in _visible.size():
			var bar: Dictionary = _visible[index]
			var bar_start := String(bar.get("d", ""))
			var bar_end := String(bar.get("end", bar_start))
			if date >= bar_start and date <= bar_end:
				return index
			if bar_start <= date:
				fallback = index
		return fallback
	var last_same_day := -1
	var wanted := trade_time.substr(0, 5)
	for index in _visible.size():
		var bar: Dictionary = _visible[index]
		if String(bar.get("d", "")) != date:
			continue
		last_same_day = index
		if wanted != "" and String(bar.get("time", "")) == wanted:
			return index
		if wanted != "" and String(bar.get("time", "")) <= wanted:
			last_same_day = index
	return last_same_day


func _draw_last_price() -> void:
	var last_price := float(_visible[-1]["c"])
	var y := _price_y(last_price)
	draw_line(Vector2(_left, y), Vector2(_right, y),
		Color(SmaUiTheme.ACCENT.r, SmaUiTheme.ACCENT.g, SmaUiTheme.ACCENT.b, 0.6), 1.0)
	_draw_axis_tag(Vector2(_right + 2, y), SmaFormat.num(last_price, 2), SmaUiTheme.ACCENT)


func _draw_legend(start: int) -> void:
	var bar: Dictionary = _visible[_hover_index] if _hover_index >= 0 \
		and _hover_index < _visible.size() else _visible[-1]
	var x := _left
	var y := 34.0
	x = _draw_metric(x, y, "O ", SmaFormat.num(float(bar["o"]), 2), SmaUiTheme.TEXT)
	x = _draw_metric(x, y, "H ", SmaFormat.num(float(bar["h"]), 2), SmaUiTheme.TEXT)
	x = _draw_metric(x, y, "L ", SmaFormat.num(float(bar["l"]), 2), SmaUiTheme.TEXT)
	x = _draw_metric(x, y, "C ", SmaFormat.num(float(bar["c"]), 2), SmaUiTheme.TEXT)
	x = _draw_metric(x, y, "V ", SmaFormat.compact(float(bar.get("v", 0))), SmaUiTheme.MUTED)
	var open_price := float(bar["o"])
	var change := (float(bar["c"]) / open_price - 1.0) * 100.0 if open_price > 0.0 else 0.0
	x = _draw_metric(x, y, "", SmaFormat.pct(change, 2), SmaKit.value_color(change))
	_draw_ma_legend(start, 48.0)
	var vma := _moving_average(VMA_PERIOD, "v")
	var vma_value := float(vma[start + _visible.size() - 1])
	if not is_nan(vma_value):
		draw_string(_font, Vector2(_left, _volume_top - 4),
			"%s · VMA%d %s" % [I18n.t("trade.volume"), VMA_PERIOD,
				SmaFormat.compact(vma_value)], HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			SmaUiTheme.INFO)


func _draw_ma_legend(start: int, y: float) -> void:
	var colors := [SmaUiTheme.ACCENT, SmaUiTheme.WARNING, SmaUiTheme.INFO, Color("#a78bfa")]
	var x := _left
	for index in MA_PERIODS.size():
		var period: int = MA_PERIODS[index]
		var series := _moving_average(period, "c")
		var value := float(series[start + _visible.size() - 1])
		if is_nan(value):
			continue
		x = _draw_metric(x, y, "MA%d " % period, SmaFormat.num(value, 2),
			colors[index], 10)


func _draw_metric(x: float, y: float, label: String, value: String, color: Color,
		size: int = 11) -> float:
	if label != "":
		draw_string(_font, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1,
			size, SmaUiTheme.DIM)
		x += _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(_font, Vector2(x, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1,
		size, color)
	x += _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return x + 10.0


func _draw_time_axis() -> void:
	var labels := mini(4, _visible.size())
	for step in labels:
		var ratio := float(step) / float(maxi(1, labels - 1))
		var index := int(round(ratio * float(_visible.size() - 1)))
		var bar: Dictionary = _visible[index]
		var label := _label_for(bar)
		var x := _left + _slot * (float(index) + 0.5)
		if step == 0:
			draw_string(_font, Vector2(_left, size.y - 6), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, SmaUiTheme.DIM)
		elif step == labels - 1:
			draw_string(_font, Vector2(_left, size.y - 6), label,
				HORIZONTAL_ALIGNMENT_RIGHT, _right - _left, 10, SmaUiTheme.DIM)
		else:
			draw_string(_font, Vector2(x - 32, size.y - 6), label,
				HORIZONTAL_ALIGNMENT_CENTER, 64, 10, SmaUiTheme.DIM)


func _draw_crosshair() -> void:
	var bar: Dictionary = _visible[_hover_index]
	var x := _left + _slot * (float(_hover_index) + 0.5)
	draw_line(Vector2(x, _top), Vector2(x, _volume_bottom),
		Color(SmaUiTheme.ACCENT.r, SmaUiTheme.ACCENT.g, SmaUiTheme.ACCENT.b, 0.55), 1.0)
	if _hover_pos.y >= _top and _hover_pos.y <= _price_bottom:
		draw_line(Vector2(_left, _hover_pos.y), Vector2(_right, _hover_pos.y),
			Color(SmaUiTheme.ACCENT.r, SmaUiTheme.ACCENT.g, SmaUiTheme.ACCENT.b, 0.55), 1.0)
		var price := _price_from_y(_hover_pos.y)
		_draw_axis_tag(Vector2(_right + 2, _hover_pos.y), SmaFormat.num(price, 2),
			SmaUiTheme.ACCENT)
	var label := _bar_title(bar)
	_draw_axis_tag(Vector2(x, size.y - 3), label, SmaUiTheme.ACCENT, true)
	_draw_tooltip(bar)


func _draw_axis_tag(position: Vector2, text: String, color: Color,
		centered: bool = false) -> void:
	var font_size := 10
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var box := Rect2(position.x, position.y - text_size.y + 2.0,
		text_size.x + 8.0, text_size.y + 2.0)
	if centered:
		box.position.x -= box.size.x * 0.5
	if box.position.x + box.size.x > size.x - 2.0:
		box.position.x = size.x - box.size.x - 2.0
	if box.position.x < 2.0:
		box.position.x = 2.0
	draw_rect(box, SmaUiTheme.PANEL_ALT)
	draw_rect(box, color, false, 1.0)
	draw_string(_font, Vector2(box.position.x + 4.0, box.position.y + text_size.y - 2.0),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_tooltip(bar: Dictionary) -> void:
	var lines := [
		_bar_title(bar),
		"O %s   H %s" % [SmaFormat.num(float(bar["o"]), 2),
			SmaFormat.num(float(bar["h"]), 2)],
		"L %s   C %s" % [SmaFormat.num(float(bar["l"]), 2),
			SmaFormat.num(float(bar["c"]), 2)],
		"V %s" % SmaFormat.compact(float(bar.get("v", 0))),
	]
	var width := 0.0
	for line in lines:
		width = maxf(width, _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x)
	width += 16.0
	var height := 16.0 + float(lines.size()) * 14.0
	var box := Rect2(_hover_pos.x + 14.0, _hover_pos.y + 14.0, width, height)
	if box.position.x + box.size.x > _right:
		box.position.x = _hover_pos.x - box.size.x - 14.0
	if box.position.y + box.size.y > _price_bottom:
		box.position.y = _hover_pos.y - box.size.y - 14.0
	box.position.x = clampf(box.position.x, _left + 2.0, _right - box.size.x - 2.0)
	box.position.y = clampf(box.position.y, _top + 2.0, _price_bottom - box.size.y - 2.0)
	draw_rect(box, Color(SmaUiTheme.PANEL.r, SmaUiTheme.PANEL.g, SmaUiTheme.PANEL.b, 0.96))
	draw_rect(box, SmaUiTheme.BORDER, false, 1.0)
	for index in lines.size():
		var color := SmaUiTheme.MUTED if index == 0 else SmaUiTheme.TEXT
		draw_string(_font, Vector2(box.position.x + 8.0,
			box.position.y + 14.0 + float(index) * 14.0), lines[index],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)


func _price_y(price: float) -> float:
	var ratio := (price - _low) / maxf(0.000001, _high - _low)
	return lerpf(_price_bottom, _top, ratio)


func _price_from_y(y: float) -> float:
	var ratio := (_price_bottom - y) / maxf(0.000001, _price_bottom - _top)
	return lerpf(_low, _high, ratio)


func _label_for(bar: Dictionary) -> String:
	if timeframe in ["1D", "1W", "1M", "1d", "1w", "1mo", "1y"]:
		var day_text := String(bar.get("d", ""))
		return day_text.substr(5) if day_text.length() >= 10 else day_text
	return String(bar.get("time", ""))


func _bar_title(bar: Dictionary) -> String:
	var day := String(bar.get("d", ""))
	var time := String(bar.get("time", ""))
	if day != "" and time != "":
		return "%s %s" % [day, time]
	if day != "":
		var end := String(bar.get("end", ""))
		if end != "" and end != day:
			return "%s → %s" % [day, end]
		return day
	return String(bar.get("time", ""))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_visible_count(visible_count - 10)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_visible_count(visible_count + 10)
			accept_event()


func _update_hover(position: Vector2) -> void:
	_hover_pos = position
	if _plot.size.x <= 0.0 or _slot <= 0.0 or not _plot.has_point(position):
		_hover_index = -1
		queue_redraw()
		return
	var index := int(floor((position.x - _left) / _slot))
	_hover_index = clampi(index, 0, maxi(0, _visible.size() - 1))
	queue_redraw()


func _on_mouse_exited() -> void:
	_hover_index = -1
	_hover_pos = Vector2(-1, -1)
	queue_redraw()
