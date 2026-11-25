## 16-bit pixel single-candle teaching illustration for Academy K-line demo:
## recessed CRT bezel, pixel-dashed OHLC lanes, outlined 3D pixel candlestick,
## and crisp 12px Fusion Pixel readout tags.
class_name SmaCandleIllustration
extends Control

var open_price := 0.0
var high_price := 0.0
var low_price := 0.0
var close_price := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(420, 230)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_data(open_value: float, high_value: float, low_value: float, close_value: float) -> void:
	open_price = open_value
	high_price = high_value
	low_price = low_value
	close_price = close_value
	queue_redraw()


func _draw() -> void:
	var ink := Color("#04070e")
	draw_rect(Rect2(Vector2.ZERO, size), ink)
	draw_rect(Rect2(2, 2, maxf(0.0, size.x - 4.0), maxf(0.0, size.y - 4.0)), Color("#2b456b"))
	draw_rect(Rect2(4, 4, maxf(0.0, size.x - 8.0), maxf(0.0, size.y - 8.0)), SmaUiTheme.CRT_BG)
	var left := 38.0
	var right := size.x - 132.0
	var top := 22.0
	var bottom := size.y - 24.0
	if right <= left or bottom <= top:
		return
	var low := minf(low_price, open_price)
	low = minf(low, close_price)
	var high := maxf(high_price, open_price)
	high = maxf(high, close_price)
	if high - low < 0.01:
		high += 0.5
		low -= 0.5
	var center_x := roundf(((left + right) * 0.5) / 2.0) * 2.0
	var pos_col := Color("#4ade80") if SmaUiTheme.color_scheme != "cn" else Color("#f87171")
	var neg_col := Color("#f87171") if SmaUiTheme.color_scheme != "cn" else Color("#4ade80")
	if SmaUiTheme.color_scheme == "colorblind":
		pos_col = Color("#60a5fa")
		neg_col = Color("#fb923c")
	var color := pos_col if close_price >= open_price else neg_col
	var y_high := roundf(_y(high_price, low, high, top, bottom) / 2.0) * 2.0
	var y_low := roundf(_y(low_price, low, high, top, bottom) / 2.0) * 2.0
	var y_open := roundf(_y(open_price, low, high, top, bottom) / 2.0) * 2.0
	var y_close := roundf(_y(close_price, low, high, top, bottom) / 2.0) * 2.0

	var font := SmaUiTheme.pixel_font_12()
	var labels := [
		["O", open_price, y_open, Color("#cbd5e1")],
		["H", high_price, y_high, pos_col],
		["L", low_price, y_low, neg_col],
		["C", close_price, y_close, Color("#fef08a")],
	]
	labels.sort_custom(func(a, b): return float(a[2]) < float(b[2]))
	var last_label_y := -100.0
	for entry in labels:
		var lane_y: float = entry[2]
		var lane_color: Color = entry[3]
		var lx := left
		while lx < right:
			draw_rect(Rect2(lx, lane_y, minf(4.0, right - lx), 2.0),
				Color(lane_color.r, lane_color.g, lane_color.b, 0.42))
			lx += 8.0
		var label_y := maxf(lane_y, last_label_y + 20.0)
		label_y = minf(label_y, size.y - 10.0)
		last_label_y = label_y
		var text := "%s %s" % [entry[0], SmaFormat.money(float(entry[1]))]
		draw_rect(Rect2(right + 6.0, label_y - 10.0, 114.0, 18.0), Color("#0d1a2d"))
		draw_rect(Rect2(right + 6.0, label_y - 10.0, 114.0, 18.0), lane_color, false, 2.0)
		draw_string(font, Vector2(right + 12.0, label_y + 4.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, lane_color)

	# Outlined chunky 16-bit candlestick wick & body
	draw_rect(Rect2(center_x - 4.0, y_high - 2.0, 8.0, maxf(4.0, y_low - y_high + 4.0)), ink)
	draw_rect(Rect2(center_x - 2.0, y_high, 4.0, maxf(2.0, y_low - y_high)), color)
	var body_width := 48.0
	var body_top := minf(y_open, y_close)
	var body_height := maxf(6.0, roundf(absf(y_open - y_close) / 2.0) * 2.0)
	var bx := center_x - body_width * 0.5
	draw_rect(Rect2(bx - 2.0, body_top - 2.0, body_width + 4.0, body_height + 4.0), ink)
	draw_rect(Rect2(bx, body_top, body_width, body_height), color)
	draw_rect(Rect2(bx + 2.0, body_top + 2.0, body_width - 4.0, 2.0), color.lightened(0.35))
	draw_rect(Rect2(bx + 2.0, body_top + 2.0, 2.0, maxf(2.0, body_height - 4.0)), color.lightened(0.28))


func _y(price: float, low: float, high: float, top: float, bottom: float) -> float:
	return lerpf(bottom, top, (price - low) / maxf(0.0001, high - low))
