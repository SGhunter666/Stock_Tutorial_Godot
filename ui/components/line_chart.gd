## Pixel CRT line chart for NAV curves and backtest equity: recessed dark CRT
## phosphor screen, pixel-dotted grid, 4x4 Bayer ordered-dithered area fill,
## and 2px stepped-pixel staircase curve with glowing pixel endpoint cursor.
class_name SmaLineChart
extends Control

const BAYER4 := [
	[0, 8, 2, 10],
	[12, 4, 14, 6],
	[3, 11, 1, 9],
	[15, 7, 13, 5],
]

var values: Array = []
var color := SmaUiTheme.ACCENT
var format_mode := "money"
var start_label := ""
var end_label := ""


func _init() -> void:
	custom_minimum_size = Vector2(320, 180)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_series(next_values: Array, next_color: Color = Color(0, 0, 0, 0),
		next_format: String = "money", next_start: String = "",
		next_end: String = "") -> void:
	values = next_values
	color = Color("#5eead4") if next_color.a <= 0.0 else next_color
	format_mode = next_format
	start_label = next_start
	end_label = next_end
	queue_redraw()


func _format(value: float) -> String:
	if format_mode == "pct":
		return SmaFormat.pct(value, 1)
	if format_mode == "number":
		return SmaFormat.num(value, 2)
	return SmaFormat.compact(value)


func _format_axis(value: float, other: float) -> String:
	if format_mode != "money":
		return _format(value)
	for digits in range(1, 5):
		var text := _compact_digits(value, digits)
		if text != _compact_digits(other, digits):
			return text
	return _format(value)


func _compact_digits(value: float, digits: int) -> String:
	var absolute := absf(value)
	if absolute >= 1_000_000_000.0:
		return SmaFormat.num(value / 1_000_000_000.0, digits) + "B"
	if absolute >= 1_000_000.0:
		return SmaFormat.num(value / 1_000_000.0, digits) + "M"
	if absolute >= 1_000_000.0:
		return SmaFormat.num(value / 1_000_000.0, digits) + "M"
	if absolute >= 1_000.0:
		return SmaFormat.num(value / 1_000.0, digits) + "K"
	return SmaFormat.num(value, digits)


func _draw() -> void:
	# Recessed pixel CRT monitor bezel
	draw_rect(Rect2(Vector2.ZERO, size), Color("#04070e"))
	draw_rect(Rect2(2, 2, maxf(0.0, size.x - 4.0), maxf(0.0, size.y - 4.0)), Color("#2b456b"))
	draw_rect(Rect2(4, 4, maxf(0.0, size.x - 8.0), maxf(0.0, size.y - 8.0)), SmaUiTheme.CRT_BG)
	if values.size() < 2:
		return
	var font := SmaUiTheme.pixel_font_10()
	var axis_col := Color("#88a8cc")
	var grid_col := Color("#233b5c")
	var line_col := color.lightened(0.18) if SmaUiTheme.mode == "light" else color
	var left := 68.0
	var right := size.x - 16.0
	var top := 14.0
	var bottom := size.y - 26.0
	if right <= left or bottom <= top:
		return
	var low := INF
	var high := -INF
	for value in values:
		low = minf(low, float(value))
		high = maxf(high, float(value))
	if high - low < 0.001:
		var pad := maxf(0.01, absf(high) * 0.01)
		high += pad
		low = maxf(0.0, low - pad)
	var padding := (high - low) * 0.08
	high += padding
	low -= padding

	# Pixel-dotted CRT grid
	for step in 4:
		var ratio := float(step) / 3.0
		var y := roundf(lerpf(top, bottom, ratio) / 2.0) * 2.0
		var gx := left
		while gx < right:
			draw_rect(Rect2(gx, y, 2.0, 2.0), grid_col)
			gx += 6.0
	draw_rect(Rect2(left - 2.0, top - 2.0, (right - left) + 4.0, (bottom - top) + 4.0),
		Color("#345480"), false, 2.0)

	# 4x4 Bayer ordered-dithered pixel area fill under stepped curve
	var fill_col := Color(line_col.r, line_col.g, line_col.b, 0.34)
	var b_px := 4.0
	var cols := int(floor((right - left) / b_px))
	for ci in cols:
		var cx := left + float(ci) * b_px
		var t_idx := clampf((cx - left) / maxf(1.0, right - left), 0.0, 1.0) * float(values.size() - 1)
		var v := float(values[int(round(t_idx))])
		var cy := roundf((bottom - (v - low) / (high - low) * (bottom - top)) / 2.0) * 2.0
		var gy_cur := cy + 2.0
		var row_i := 0
		while gy_cur < bottom - 1.0:
			var depth := clampf(1.0 - (gy_cur - cy) / maxf(8.0, bottom - top), 0.15, 0.85)
			var thresh := int(depth * 16.0)
			if int(BAYER4[row_i % 4][ci % 4]) < thresh:
				draw_rect(Rect2(cx, gy_cur, 2.0, 2.0), fill_col)
			gy_cur += b_px
			row_i += 1

	# 2px stepped-pixel staircase curve
	var points := PackedVector2Array()
	for index in values.size():
		var x := lerpf(left, right, float(index) / float(values.size() - 1))
		var y := bottom - (float(values[index]) - low) / (high - low) * (bottom - top)
		points.append(Vector2(x, y))
	for i in range(points.size() - 1):
		var x0 := roundf(points[i].x / 2.0) * 2.0
		var y0 := roundf(points[i].y / 2.0) * 2.0
		var x1 := roundf(points[i + 1].x / 2.0) * 2.0
		var y1 := roundf(points[i + 1].y / 2.0) * 2.0
		var mid_x := roundf(((x0 + x1) * 0.5) / 2.0) * 2.0
		if mid_x > x0:
			draw_rect(Rect2(x0, y0 - 1.0, mid_x - x0, 2.0), line_col)
		draw_rect(Rect2(mid_x, minf(y0, y1) - 1.0, 2.0, absf(y1 - y0) + 2.0), line_col)
		if x1 > mid_x + 2.0:
			draw_rect(Rect2(mid_x + 2.0, y1 - 1.0, x1 - (mid_x + 2.0), 2.0), line_col)

	# Glowing 6x6 pixel endpoint block
	var last_pt := points[-1]
	var lx := roundf(last_pt.x / 2.0) * 2.0
	var ly := roundf(last_pt.y / 2.0) * 2.0
	draw_rect(Rect2(lx - 4.0, ly - 4.0, 8.0, 8.0), Color("#04070e"))
	draw_rect(Rect2(lx - 2.0, ly - 2.0, 4.0, 4.0), Color("#fef08a"))

	draw_string(font, Vector2(8, top + 6), _format_axis(high, low),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, axis_col)
	draw_string(font, Vector2(8, bottom + 2), _format_axis(low, high),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, axis_col)
	if start_label != "":
		draw_string(font, Vector2(left, size.y - 8), start_label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, axis_col)
	if end_label != "":
		draw_string(font, Vector2(left, size.y - 8), end_label,
			HORIZONTAL_ALIGNMENT_RIGHT, right - left, 10, axis_col)
