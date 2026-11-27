## Canvas candle + volume chart with cached moving averages, optional Bollinger
## bands, horizontal history pan, price-alert / order lines, crosshair OHLC
## readout, volume MA, position cost lines and trade markers. Reads only the
## candles it is given; it never asks the engine for future data.
class_name SmaCandleChart
extends Control

signal visible_count_changed(count: int)
signal pan_changed(panned: bool)

const MA_PERIODS := [5, 10, 20, 60]
const VMA_PERIOD := 5
const BOLL_PERIOD := 20
const MIN_VISIBLE := 20
const MAX_VISIBLE := 250
const DEFAULT_VISIBLE := 60

var candles: Array = []
var title_text: String = ""
var timeframe: String = "1m"
var visible_count := DEFAULT_VISIBLE
var pan_offset := 0
var show_ma := true
var show_boll := false
var pixel_stepped := true
var trade_markers: Array = []
var price_lines: Array = []
var candle_notes: Dictionary = {}
var long_cost := 0.0
var short_cost := 0.0

var _font: Font
var _font_size := 10
var _hover_index := -1
var _hover_pos := Vector2(-1, -1)
var _dragging := false
var _drag_start_x := 0.0
var _drag_start_pan := 0
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

var _cache_key := ""
var _ma_cache: Dictionary = {}
var _vma_cache: Array = []
var _boll_upper: Array = []
var _boll_lower: Array = []


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
	var tf_changed := timeframe != next_timeframe
	candles = next_candles
	timeframe = next_timeframe
	title_text = next_title
	if tf_changed:
		_set_pan(0)
	else:
		_clamp_pan()
	_ensure_series_cache()
	queue_redraw()


func set_visible_count(count: int) -> void:
	var next_count := clampi(count, MIN_VISIBLE, MAX_VISIBLE)
	if next_count == visible_count:
		return
	visible_count = next_count
	_clamp_pan()
	visible_count_changed.emit(visible_count)
	queue_redraw()


func set_indicators(ma_enabled: bool, boll_enabled: bool) -> void:
	if show_ma == ma_enabled and show_boll == boll_enabled:
		return
	show_ma = ma_enabled
	show_boll = boll_enabled
	queue_redraw()


func set_pixel_stepped(enabled: bool) -> void:
	if pixel_stepped == enabled:
		return
	pixel_stepped = enabled
	queue_redraw()


func reset_pan() -> void:
	_set_pan(0)
	queue_redraw()


func is_panned() -> bool:
	return pan_offset > 0


func set_trade_markers(next_markers: Array) -> void:
	trade_markers = next_markers
	queue_redraw()


func set_candle_notes(next_notes: Dictionary) -> void:
	candle_notes = next_notes
	queue_redraw()


func set_price_lines(next_lines: Array) -> void:
	price_lines = next_lines
	queue_redraw()


func set_position_cost(next_long_cost: float, next_short_cost: float) -> void:
	long_cost = maxf(0.0, next_long_cost)
	short_cost = maxf(0.0, next_short_cost)
	queue_redraw()


func _max_pan() -> int:
	return maxi(0, candles.size() - mini(visible_count, candles.size()))


func _clamp_pan() -> void:
	_set_pan(clampi(pan_offset, 0, _max_pan()))


func _set_pan(next_pan: int) -> void:
	var clamped := clampi(next_pan, 0, _max_pan())
	if clamped == pan_offset:
		return
	var was_panned := pan_offset > 0
	pan_offset = clamped
	var now_panned := pan_offset > 0
	if was_panned != now_panned:
		pan_changed.emit(now_panned)


func _series_signature() -> String:
	if candles.is_empty():
		return "empty"
	var first: Dictionary = candles[0]
	var last: Dictionary = candles[-1]
	return "%s|%d|%s|%s|%.4f|%.4f|%.4f|%s" % [
		timeframe, candles.size(), String(first.get("d", "")), String(last.get("d", "")),
		float(last.get("c", 0.0)), float(last.get("h", 0.0)), float(last.get("l", 0.0)),
		str(last.get("v", 0)),
	]


func _ensure_series_cache() -> void:
	var sig := _series_signature()
	if sig == _cache_key:
		return
	_cache_key = sig
	_ma_cache.clear()
	_vma_cache.clear()
	_boll_upper.clear()
	_boll_lower.clear()
	if candles.is_empty():
		return
	for period in MA_PERIODS:
		_ma_cache[period] = _moving_average(period, "c")
	_vma_cache = _moving_average(VMA_PERIOD, "v")
	_compute_bollinger()


func _compute_bollinger() -> void:
	var n := candles.size()
	_boll_upper.resize(n)
	_boll_lower.resize(n)
	var mid_series: Array = _ma_cache.get(BOLL_PERIOD, [])
	for index in n:
		if index < BOLL_PERIOD - 1 or mid_series.size() != n:
			_boll_upper[index] = NAN
			_boll_lower[index] = NAN
			continue
		var mean := float(mid_series[index])
		var sum_sq := 0.0
		for offset in range(index - BOLL_PERIOD + 1, index + 1):
			var diff := float(candles[offset].get("c", 0.0)) - mean
			sum_sq += diff * diff
		var std := sqrt(sum_sq / float(BOLL_PERIOD))
		_boll_upper[index] = mean + 2.0 * std
		_boll_lower[index] = mean - 2.0 * std


func _draw() -> void:
	var use_12 := SmaUiTheme.font_scale >= 1.15
	_font = SmaUiTheme.pixel_font_12() if use_12 else SmaUiTheme.pixel_font_10()
	var title_f := SmaUiTheme.resolve_font(12, false)
	var title_font: Font = title_f["font"]
	var title_px := int(title_f["size"])
	_font_size = 12 if use_12 else 10
	draw_rect(Rect2(Vector2.ZERO, size), Color("#04070e"))
	draw_rect(Rect2(2, 2, maxf(0.0, size.x - 4.0), maxf(0.0, size.y - 4.0)), SmaUiTheme.CRT_BG)
	if title_text != "":
		draw_string(title_font, Vector2(12, 20), title_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, title_px, Color("#b8d0eb"))
	if candles.is_empty():
		draw_string(title_font, Vector2(12, size.y * 0.5), I18n.t("chart.no_data"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, title_px, Color("#88a8cc"))
		return
	_ensure_series_cache()
	var count := mini(visible_count, candles.size())
	if count <= 0:
		return
	var max_start := maxi(0, candles.size() - count)
	var start := clampi(max_start - pan_offset, 0, max_start)
	_visible = candles.slice(start, start + count)
	_left = 12.0
	_right = size.x - (82.0 if use_12 else 74.0)
	_top = 62.0
	_price_bottom = size.y - 76.0
	_volume_top = _price_bottom + 12.0
	_volume_bottom = size.y - 22.0
	if _right <= _left or _price_bottom <= _top:
		return
	_low = INF
	_high = -INF
	var max_volume := 1.0
	for index in _visible.size():
		var bar: Dictionary = _visible[index]
		_low = minf(_low, float(bar["l"]))
		_high = maxf(_high, float(bar["h"]))
		max_volume = maxf(max_volume, float(bar.get("v", 0)))
		if show_boll and start + index < _boll_upper.size():
			var u := float(_boll_upper[start + index])
			var l := float(_boll_lower[start + index])
			if not is_nan(u):
				_high = maxf(_high, u)
			if not is_nan(l):
				_low = minf(_low, l)
	if timeframe == "1m":
		# Hold the initial scale steady while the first few quotes move the body.
		var opening_price := float(_visible[0]["o"])
		var half_range := maxf(0.06, opening_price * 0.003)
		_low = minf(_low, maxf(0.0, opening_price - half_range))
		_high = maxf(_high, opening_price + half_range)
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

	for index in _visible.size():
		if start + index < _vma_cache.size():
			var vval := float(_vma_cache[start + index])
			if not is_nan(vval):
				max_volume = maxf(max_volume, vval)
	var body_width := maxf(1.5, _slot * 0.62)
	if timeframe == "1m":
		body_width = minf(body_width, 24.0)
	_draw_grid()
	_draw_volume(max_volume, body_width)
	if show_boll:
		_draw_bollinger(start)
	_draw_candles(body_width)
	if show_ma:
		_draw_ma_lines(start)
	_draw_vma(start, max_volume)
	_draw_cost_lines()
	_draw_price_lines()
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
	var pixel := SmaUiTheme.is_pixel()
	var crt_border := Color("#3d608c")
	var crt_dim := Color("#88a8cc")
	var h_col := Color(crt_border.r, crt_border.g, crt_border.b, 0.58)
	var v_col := Color(crt_border.r, crt_border.g, crt_border.b, 0.38)
	for step in 5:
		var ratio := float(step) / 4.0
		var y := roundf(lerpf(_top, _price_bottom, ratio)) if pixel else lerpf(_top, _price_bottom, ratio)
		if pixel:
			var x_cur := _left
			while x_cur < _right:
				draw_rect(Rect2(x_cur, y, 2.0, 1.0), h_col)
				x_cur += 5.0
		else:
			draw_line(Vector2(_left, y), Vector2(_right, y), h_col, 1.0)
		var price := lerpf(_high, _low, ratio)
		draw_string(_font, Vector2(_right + 6, y + 3), SmaFormat.num(price, 2),
			HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, crt_dim)
	for step in 4:
		var ratio := float(step) / 3.0
		var x := roundf(lerpf(_left, _right, ratio)) if pixel else lerpf(_left, _right, ratio)
		if pixel:
			var y_cur := _top
			while y_cur < _volume_bottom:
				draw_rect(Rect2(x, y_cur, 1.0, 2.0), v_col)
				y_cur += 5.0
		else:
			draw_line(Vector2(x, _top), Vector2(x, _volume_bottom), v_col, 1.0)
	if pixel:
		draw_rect(Rect2(_left - 2.0, _top - 2.0, (_right - _left) + 4.0,
			(_volume_bottom - _top) + 4.0), crt_border, false, 2.0)


func _draw_volume(max_volume: float, body_width: float) -> void:
	var pixel := SmaUiTheme.is_pixel()
	for index in _visible.size():
		var bar: Dictionary = _visible[index]
		var color := SmaUiTheme.POSITIVE if float(bar["c"]) >= float(bar["o"]) \
			else SmaUiTheme.NEGATIVE
		var volume := float(bar.get("v", 0))
		var height := (volume / max_volume) * maxf(2.0, _volume_bottom - _volume_top)
		var x := _left + _slot * (float(index) + 0.5)
		if pixel:
			var w := maxf(2.0, roundf(body_width))
			var h := maxf(2.0, roundf(height / 2.0) * 2.0) if volume > 0.0 else 0.0
			if h > 0.0:
				draw_rect(Rect2(roundf(x - w * 0.5), roundf(_volume_bottom) - h, w, h),
					Color(color.r, color.g, color.b, 0.46))
		else:
			draw_rect(Rect2(x - body_width * 0.5, _volume_bottom - height,
				body_width, height), Color(color.r, color.g, color.b, 0.38))
	var sep_col := Color(SmaUiTheme.BORDER.r, SmaUiTheme.BORDER.g, SmaUiTheme.BORDER.b, 0.45)
	if pixel:
		draw_rect(Rect2(_left, roundf(_volume_top), _right - _left, 1.0), sep_col)
	else:
		draw_line(Vector2(_left, _volume_top), Vector2(_right, _volume_top), sep_col, 1.0)


func _draw_candles(body_width: float) -> void:
	var pixel := SmaUiTheme.is_pixel()
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
		if pixel:
			x = roundf(x)
			y_open = roundf(y_open)
			y_close = roundf(y_close)
			y_high = roundf(y_high)
			y_low = roundf(y_low)
			var w := maxf(2.0, roundf(body_width))
			draw_rect(Rect2(x - 1.0, y_high, 2.0, maxf(1.0, y_low - y_high)), color)
			var body_top := minf(y_open, y_close)
			var body_height := maxf(2.0, absf(y_close - y_open))
			var rect := Rect2(roundf(x - w * 0.5), body_top, w, body_height)
			draw_rect(rect, color)
			if w >= 5.0 and body_height >= 4.0:
				draw_rect(rect, Color(0, 0, 0, 0.35), false, 1.0)
		else:
			draw_line(Vector2(x, y_high), Vector2(x, y_low), color, 1.0)
			var body_top := minf(y_open, y_close)
			var body_height := maxf(1.0, absf(y_close - y_open))
			draw_rect(Rect2(x - body_width * 0.5, body_top, body_width, body_height), color)


func _draw_series(points: PackedVector2Array, col: Color, width: float = 1.2) -> void:
	if points.size() < 2:
		return
	if not (SmaUiTheme.is_pixel() and pixel_stepped):
		draw_polyline(points, col, width, true)
		return
	for i in range(points.size() - 1):
		var x0 := roundf(points[i].x / 2.0) * 2.0
		var y0 := roundf(points[i].y / 2.0) * 2.0
		var x1 := roundf(points[i + 1].x / 2.0) * 2.0
		var y1 := roundf(points[i + 1].y / 2.0) * 2.0
		var mid_x := roundf(((x0 + x1) * 0.5) / 2.0) * 2.0
		if mid_x > x0:
			draw_rect(Rect2(x0, y0 - 1.0, mid_x - x0, 2.0), col)
		draw_rect(Rect2(mid_x, minf(y0, y1) - 1.0, 2.0, absf(y1 - y0) + 2.0), col)
		if x1 > mid_x + 2.0:
			draw_rect(Rect2(mid_x + 2.0, y1 - 1.0, x1 - (mid_x + 2.0), 2.0), col)


func _draw_bollinger(start: int) -> void:
	var band_color := Color(SmaUiTheme.INFO.r, SmaUiTheme.INFO.g, SmaUiTheme.INFO.b, 0.65)
	for series in [_boll_upper, _boll_lower]:
		var points := PackedVector2Array()
		for index in _visible.size():
			if start + index >= series.size():
				continue
			var value := float(series[start + index])
			if is_nan(value):
				if points.size() > 1:
					_draw_series(points, band_color, 1.0)
				points = PackedVector2Array()
				continue
			points.append(Vector2(_left + _slot * (float(index) + 0.5), _price_y(value)))
		if points.size() > 1:
			_draw_series(points, band_color, 1.0)


func _draw_ma_lines(start: int) -> void:
	var colors := [SmaUiTheme.ACCENT, SmaUiTheme.WARNING, SmaUiTheme.INFO, Color("#a78bfa")]
	for period_index in MA_PERIODS.size():
		var period: int = MA_PERIODS[period_index]
		var series: Array = _ma_cache.get(period, [])
		if series.is_empty():
			continue
		var points := PackedVector2Array()
		for index in _visible.size():
			var value := float(series[start + index])
			if is_nan(value):
				if points.size() > 1:
					_draw_series(points, colors[period_index], 1.2)
				points = PackedVector2Array()
				continue
			points.append(Vector2(_left + _slot * (float(index) + 0.5), _price_y(value)))
		if points.size() > 1:
			_draw_series(points, colors[period_index], 1.2)


func _draw_vma(start: int, max_volume: float) -> void:
	if _vma_cache.is_empty():
		return
	var vma_col := Color(SmaUiTheme.INFO.r, SmaUiTheme.INFO.g, SmaUiTheme.INFO.b, 0.9)
	var points := PackedVector2Array()
	for index in _visible.size():
		var value := float(_vma_cache[start + index])
		if is_nan(value):
			if points.size() > 1:
				_draw_series(points, vma_col, 1.1)
			points = PackedVector2Array()
			continue
		var ratio := clampf(value / max_volume, 0.0, 1.0)
		points.append(Vector2(_left + _slot * (float(index) + 0.5),
			lerpf(_volume_bottom, _volume_top, ratio)))
	if points.size() > 1:
		_draw_series(points, vma_col, 1.1)


func _draw_cost_lines() -> void:
	_draw_dashed_line(long_cost, SmaUiTheme.WARNING, I18n.t("chart.costLong"), true)
	_draw_dashed_line(short_cost, SmaUiTheme.NEGATIVE, I18n.t("chart.costShort"), true)


func _draw_price_lines() -> void:
	for entry in price_lines:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var price := float(entry.get("price", 0.0))
		var label := String(entry.get("label", ""))
		var color: Color = entry.get("color", SmaUiTheme.INFO)
		_draw_dashed_line(price, color, label, false)


func _draw_dashed_line(price: float, color: Color, label: String, left_label: bool) -> void:
	if price <= 0.0:
		return
	var y := _price_y(price)
	if y < _top or y > _price_bottom:
		return
	var pixel := SmaUiTheme.is_pixel()
	if pixel:
		y = roundf(y)
	var x := _left
	while x < _right:
		if pixel:
			draw_rect(Rect2(roundf(x), y, minf(6.0, _right - x), 2.0), color)
		else:
			draw_line(Vector2(x, y), Vector2(minf(x + 6.0, _right), y), color, 1.0)
		x += 10.0
	var f_px := 10 if pixel else 9
	var text := "%s %s" % [label, SmaFormat.num(price, 2)]
	if left_label:
		draw_string(_font, Vector2(_left + 6, y - 4), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, f_px, color)
	else:
		var text_w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, f_px).x
		draw_string(_font, Vector2(maxf(_left + 6.0, _right - text_w - 6.0), y - 4), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, f_px, color)


func _draw_trade_markers(start: int) -> void:
	if trade_markers.is_empty():
		return
	var pixel := SmaUiTheme.is_pixel()
	var ink := Color("#04070e")
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
		if pixel:
			var cx := roundf(x / 2.0) * 2.0
			if is_buy:
				var ty := roundf((_price_y(float(bar["l"])) + 3.0) / 2.0) * 2.0
				draw_rect(Rect2(cx - 2.0, ty - 2.0, 4.0, 2.0), ink)
				draw_rect(Rect2(cx - 4.0, ty, 8.0, 2.0), ink)
				draw_rect(Rect2(cx - 6.0, ty + 2.0, 12.0, 6.0), ink)
				draw_rect(Rect2(cx - 1.0, ty, 2.0, 2.0), color)
				draw_rect(Rect2(cx - 3.0, ty + 2.0, 6.0, 2.0), color)
				draw_rect(Rect2(cx - 5.0, ty + 4.0, 10.0, 2.0), color)
			else:
				var ty := roundf((_price_y(float(bar["h"])) - 3.0) / 2.0) * 2.0
				draw_rect(Rect2(cx - 6.0, ty - 8.0, 12.0, 6.0), ink)
				draw_rect(Rect2(cx - 4.0, ty - 2.0, 8.0, 2.0), ink)
				draw_rect(Rect2(cx - 2.0, ty, 4.0, 2.0), ink)
				draw_rect(Rect2(cx - 5.0, ty - 6.0, 10.0, 2.0), color)
				draw_rect(Rect2(cx - 3.0, ty - 4.0, 6.0, 2.0), color)
				draw_rect(Rect2(cx - 1.0, ty - 2.0, 2.0, 2.0), color)
		elif is_buy:
			var y := _price_y(float(bar["l"])) + 7.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, y - 7.0), Vector2(x - 4.0, y), Vector2(x + 4.0, y)]), color)
		else:
			var y := _price_y(float(bar["h"])) - 7.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, y + 7.0), Vector2(x - 4.0, y), Vector2(x + 4.0, y)]), color)


func _bar_index_for_trade(trade: Dictionary, _start: int) -> int:
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
	var last_price := float(candles[-1]["c"])
	var y := _price_y(last_price)
	if y >= _top and y <= _price_bottom:
		var line_col := Color(SmaUiTheme.ACCENT.r, SmaUiTheme.ACCENT.g, SmaUiTheme.ACCENT.b, 0.65)
		if SmaUiTheme.is_pixel():
			var py := roundf(y)
			var x := _left
			while x < _right:
				draw_rect(Rect2(roundf(x), py, minf(4.0, _right - x), 1.0), line_col)
				x += 7.0
			_draw_axis_tag(Vector2(_right + 2, py), SmaFormat.num(last_price, 2), SmaUiTheme.ACCENT)
		else:
			draw_line(Vector2(_left, y), Vector2(_right, y), line_col, 1.0)
			_draw_axis_tag(Vector2(_right + 2, y), SmaFormat.num(last_price, 2), SmaUiTheme.ACCENT)


func _draw_legend(start: int) -> void:
	var active_vis := _hover_index if _hover_index >= 0 and _hover_index < _visible.size() \
		else _visible.size() - 1
	var bar: Dictionary = _visible[active_vis]
	var abs_index := start + active_vis
	var x := _left
	var y := 34.0
	var crt_text := Color("#f4f8fc")
	var crt_muted := Color("#b8d0eb")
	x = _draw_metric(x, y, "O ", SmaFormat.num(float(bar["o"]), 2), crt_text)
	x = _draw_metric(x, y, "H ", SmaFormat.num(float(bar["h"]), 2), crt_text)
	x = _draw_metric(x, y, "L ", SmaFormat.num(float(bar["l"]), 2), crt_text)
	x = _draw_metric(x, y, "C ", SmaFormat.num(float(bar["c"]), 2), crt_text)
	x = _draw_metric(x, y, "V ", SmaFormat.compact(float(bar.get("v", 0))), crt_muted)
	var open_price := float(bar["o"])
	var change := (float(bar["c"]) / open_price - 1.0) * 100.0 if open_price > 0.0 else 0.0
	x = _draw_metric(x, y, "", SmaFormat.pct(change, 2), SmaKit.value_color(change))
	_draw_ma_legend(abs_index, 48.0)
	if abs_index < _vma_cache.size():
		var vma_value := float(_vma_cache[abs_index])
		if not is_nan(vma_value):
			draw_string(_font, Vector2(_left, _volume_top - 4),
				"%s · VMA%d %s" % [I18n.t("trade.volume"), VMA_PERIOD,
					SmaFormat.compact(vma_value)], HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				SmaUiTheme.INFO)


func _draw_ma_legend(abs_index: int, y: float) -> void:
	var colors := [SmaUiTheme.ACCENT, SmaUiTheme.WARNING, SmaUiTheme.INFO, Color("#a78bfa")]
	var x := _left
	if show_ma:
		for index in MA_PERIODS.size():
			var period: int = MA_PERIODS[index]
			var series: Array = _ma_cache.get(period, [])
			if abs_index >= series.size():
				continue
			var value := float(series[abs_index])
			if is_nan(value):
				continue
			x = _draw_metric(x, y, "MA%d " % period, SmaFormat.num(value, 2),
				colors[index], 10)
	if show_boll and abs_index < _boll_upper.size():
		var upper := float(_boll_upper[abs_index])
		var lower := float(_boll_lower[abs_index])
		if not is_nan(upper) and not is_nan(lower):
			x = _draw_metric(x, y, "BOLL ", "%s–%s" % [
				SmaFormat.num(lower, 2), SmaFormat.num(upper, 2)], SmaUiTheme.INFO, 10)


func _draw_metric(x: float, y: float, label: String, value: String, color: Color,
		font_px: int = 10) -> float:
	var px := 10 if SmaUiTheme.is_pixel() else font_px
	if label != "":
		draw_string(_font, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1,
			px, Color("#88a8cc"))
		x += _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(_font, Vector2(x, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1,
		px, color)
	x += _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	return x + 10.0


func _draw_time_axis() -> void:
	var labels := mini(4, _visible.size())
	var crt_dim := Color("#88a8cc")
	for step in labels:
		var ratio := float(step) / float(maxi(1, labels - 1))
		var index := int(round(ratio * float(_visible.size() - 1)))
		var bar: Dictionary = _visible[index]
		var label := _label_for(bar)
		var x := _left + _slot * (float(index) + 0.5)
		if step == 0:
			draw_string(_font, Vector2(_left, size.y - 6), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, crt_dim)
		elif step == labels - 1:
			draw_string(_font, Vector2(_left, size.y - 6), label,
				HORIZONTAL_ALIGNMENT_RIGHT, _right - _left, 10, crt_dim)
		else:
			draw_string(_font, Vector2(x - 32, size.y - 6), label,
				HORIZONTAL_ALIGNMENT_CENTER, 64, 10, crt_dim)


func _draw_crosshair() -> void:
	var bar: Dictionary = _visible[_hover_index]
	var x := _left + _slot * (float(_hover_index) + 0.5)
	var cross_col := Color(SmaUiTheme.ACCENT.r, SmaUiTheme.ACCENT.g, SmaUiTheme.ACCENT.b, 0.62)
	var pixel := SmaUiTheme.is_pixel()
	if pixel:
		var px := roundf(x)
		var y_cur := _top
		while y_cur < _volume_bottom:
			draw_rect(Rect2(px, roundf(y_cur), 1.0, minf(3.0, _volume_bottom - y_cur)), cross_col)
			y_cur += 6.0
	else:
		draw_line(Vector2(x, _top), Vector2(x, _volume_bottom), cross_col, 1.0)
	if _hover_pos.y >= _top and _hover_pos.y <= _price_bottom:
		if pixel:
			var py := roundf(_hover_pos.y)
			var x_cur := _left
			while x_cur < _right:
				draw_rect(Rect2(roundf(x_cur), py, minf(3.0, _right - x_cur), 1.0), cross_col)
				x_cur += 6.0
		else:
			draw_line(Vector2(_left, _hover_pos.y), Vector2(_right, _hover_pos.y), cross_col, 1.0)
		var price := _price_from_y(_hover_pos.y)
		_draw_axis_tag(Vector2(_right + 2, _hover_pos.y), SmaFormat.num(price, 2),
			SmaUiTheme.ACCENT)
	var label := _bar_title(bar)
	_draw_axis_tag(Vector2(x, size.y - 3), label, SmaUiTheme.ACCENT, true)
	_draw_tooltip(bar)


func _draw_axis_tag(position: Vector2, text: String, color: Color,
		centered: bool = false) -> void:
	var font_size := _font_size
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var box := Rect2(position.x, position.y - text_size.y + 2.0,
		text_size.x + 8.0, text_size.y + 2.0)
	if centered:
		box.position.x -= box.size.x * 0.5
	if box.position.x + box.size.x > size.x - 2.0:
		box.position.x = size.x - box.size.x - 2.0
	if box.position.x < 2.0:
		box.position.x = 2.0
	if SmaUiTheme.is_pixel():
		box.position = Vector2(roundf(box.position.x), roundf(box.position.y))
		box.size = Vector2(roundf(box.size.x), roundf(box.size.y))
	draw_rect(box, Color("#0d1a2d"))
	draw_rect(box, color, false, 2.0)
	draw_string(_font, Vector2(box.position.x + 4.0, box.position.y + text_size.y - 2.0),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _candle_driver_line(bar: Dictionary) -> String:
	var date_key := String(bar.get("d", bar.get("date", "")))
	if candle_notes.has(date_key):
		return String(candle_notes[date_key])
	if timeframe != "1D":
		return ""
	var o_val := maxf(0.01, float(bar.get("o", 1.0)))
	var h_val := float(bar.get("h", o_val))
	var l_val := float(bar.get("l", o_val))
	var c_val := float(bar.get("c", o_val))
	var prev_c := o_val
	if _hover_index > 0 and _hover_index < _visible.size():
		prev_c = maxf(0.01, float(_visible[_hover_index - 1].get("c", o_val)))
	var chg_pct := (c_val - prev_c) / prev_c * 100.0
	if absf(chg_pct) < 0.25:
		return ""
	var vol_val := float(bar.get("v", 0.0))
	var avg_v := vol_val
	if _hover_index >= 1 and _hover_index < _visible.size():
		var v_sum := 0.0
		var v_cnt := 0
		for back in range(maxi(0, _hover_index - 5), _hover_index):
			v_sum += float(_visible[back].get("v", 0.0))
			v_cnt += 1
		if v_cnt > 0:
			avg_v = maxf(1.0, v_sum / float(v_cnt))
	var body := maxf(0.01, absf(c_val - o_val))
	if chg_pct < 0.0:
		if vol_val >= avg_v * 1.38:
			return I18n.t("attr.candle.heavyDistribution")
		if _hover_index >= 5 and _hover_index < _visible.size():
			var base5 := maxf(0.01, float(_visible[_hover_index - 5].get("c", prev_c)))
			if (prev_c / base5 - 1.0) * 100.0 >= 3.5:
				return I18n.t("attr.candle.profitTaking")
		if (h_val - maxf(o_val, c_val)) > body * 1.35:
			return I18n.t("attr.candle.upperRejection")
		return I18n.t("attr.candle.normalPullback")
	if vol_val >= avg_v * 1.38:
		return I18n.t("attr.candle.volumeBreakout")
	if (minf(o_val, c_val) - l_val) > body * 1.35:
		return I18n.t("attr.candle.dipBuying")
	return I18n.t("attr.candle.trendAdvance")


func _draw_tooltip(bar: Dictionary) -> void:
	var prev_c := maxf(0.01, float(bar.get("o", 1.0)))
	if _hover_index > 0 and _hover_index < _visible.size():
		prev_c = maxf(0.01, float(_visible[_hover_index - 1].get("c", prev_c)))
	var chg_pct := (float(bar["c"]) - prev_c) / prev_c * 100.0
	var lines := [
		"%s  (%s)" % [_bar_title(bar), SmaFormat.pct(chg_pct, 2)],
		"O %s   H %s" % [SmaFormat.num(float(bar["o"]), 2),
			SmaFormat.num(float(bar["h"]), 2)],
		"L %s   C %s" % [SmaFormat.num(float(bar["l"]), 2),
			SmaFormat.num(float(bar["c"]), 2)],
		"V %s" % SmaFormat.compact(float(bar.get("v", 0))),
	]
	var driver := _candle_driver_line(bar)
	if driver != "":
		lines.append(driver)
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
	if SmaUiTheme.is_pixel():
		box.position = Vector2(roundf(box.position.x), roundf(box.position.y))
		box.size = Vector2(roundf(box.size.x), roundf(box.size.y))
	draw_rect(box, Color(0.05, 0.10, 0.18, 0.96))
	draw_rect(box, Color("#fbbf24"), false, 2.0)
	for index in lines.size():
		var is_driver := (driver != "" and index == lines.size() - 1)
		var color := Color("#fbbf24") if is_driver \
			else (Color("#9cb8d8") if index == 0 else Color("#f4f8fc"))
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
		if _dragging and _slot > 0.0:
			var delta_bars := int(round((event.position.x - _drag_start_x) / _slot))
			_set_pan(_drag_start_pan + delta_bars)
			_hover_pos = event.position
			queue_redraw()
		else:
			_update_hover(event.position)
		accept_event()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.double_click:
					reset_pan()
				else:
					_dragging = true
					_drag_start_x = event.position.x
					_drag_start_pan = pan_offset
			else:
				_dragging = false
			accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_visible_count(visible_count - 10)
			accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
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
	_dragging = false
	_hover_index = -1
	_hover_pos = Vector2(-1, -1)
	queue_redraw()
