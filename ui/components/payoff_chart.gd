## Pixel CRT payoff curve for option strategies: recessed phosphor bezel,
## pixel-dashed breakeven zero line, dithered profit/loss zones, and 2px stepped
## P&L staircase curve colored by profit (>=0) vs loss (<0).
class_name SmaPayoffChart
extends Control

var values: Array = []
var low_text := ""
var high_text := ""


func _init() -> void:
	custom_minimum_size = Vector2(320, 160)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(next_values: Array, next_low: String, next_high: String) -> void:
	values = next_values
	low_text = next_low
	high_text = next_high
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#04070e"))
	draw_rect(Rect2(2, 2, maxf(0.0, size.x - 4.0), maxf(0.0, size.y - 4.0)), Color("#2b456b"))
	draw_rect(Rect2(4, 4, maxf(0.0, size.x - 8.0), maxf(0.0, size.y - 8.0)), SmaUiTheme.CRT_BG)
	if values.size() < 2:
		return
	var font := SmaUiTheme.pixel_font_10()
	var axis_col := Color("#88a8cc")
	var pos_col := Color("#4ade80") if SmaUiTheme.color_scheme != "cn" else Color("#f87171")
	var neg_col := Color("#f87171") if SmaUiTheme.color_scheme != "cn" else Color("#4ade80")
	if SmaUiTheme.color_scheme == "colorblind":
		pos_col = Color("#60a5fa")
		neg_col = Color("#fb923c")
	var left := 66.0
	var right := size.x - 16.0
	var top := 14.0
	var bottom := size.y - 26.0
	if right <= left or bottom <= top:
		return
	var low := 0.0
	var high := 0.0
	for value in values:
		low = minf(low, float(value))
		high = maxf(high, float(value))
	if high - low < 0.01:
		high += 0.5
		low -= 0.5
	var padding := (high - low) * 0.08
	high += padding
	low -= padding
	var zero_y := roundf(_y_for(0.0, low, high, top, bottom) / 2.0) * 2.0
	var zx := left
	while zx < right:
		draw_rect(Rect2(zx, zero_y, minf(4.0, right - zx), 2.0), Color("#6486ad"))
		zx += 8.0
	draw_rect(Rect2(left - 2.0, top - 2.0, (right - left) + 4.0, (bottom - top) + 4.0),
		Color("#345480"), false, 2.0)

	var points := PackedVector2Array()
	for index in values.size():
		var x := lerpf(left, right, float(index) / float(values.size() - 1))
		points.append(Vector2(x, _y_for(float(values[index]), low, high, top, bottom)))

	for i in range(points.size() - 1):
		var x0 := roundf(points[i].x / 2.0) * 2.0
		var y0 := roundf(points[i].y / 2.0) * 2.0
		var x1 := roundf(points[i + 1].x / 2.0) * 2.0
		var y1 := roundf(points[i + 1].y / 2.0) * 2.0
		var mid_x := roundf(((x0 + x1) * 0.5) / 2.0) * 2.0
		var c0 := pos_col if float(values[i]) >= 0.0 else neg_col
		var c1 := pos_col if float(values[i + 1]) >= 0.0 else neg_col
		# Subtle pixel bar shading to zero axis
		var fill_c := Color(c0.r, c0.g, c0.b, 0.16)
		var bar_top := minf(y0, zero_y)
		var bar_h := absf(y0 - zero_y)
		if bar_h >= 2.0 and x1 > x0:
			draw_rect(Rect2(x0, bar_top, x1 - x0, bar_h), fill_c)
		if mid_x > x0:
			draw_rect(Rect2(x0, y0 - 1.0, mid_x - x0, 2.0), c0)
		draw_rect(Rect2(mid_x, minf(y0, y1) - 1.0, 2.0, absf(y1 - y0) + 2.0), c1)
		if x1 > mid_x + 2.0:
			draw_rect(Rect2(mid_x + 2.0, y1 - 1.0, x1 - (mid_x + 2.0), 2.0), c1)

	draw_string(font, Vector2(8, top + 6), SmaFormat.money(high),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, axis_col)
	draw_string(font, Vector2(8, bottom + 2), SmaFormat.money(low),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, axis_col)
	draw_string(font, Vector2(left, size.y - 8), low_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, axis_col)
	draw_string(font, Vector2(left, size.y - 8), high_text,
		HORIZONTAL_ALIGNMENT_RIGHT, right - left, 10, axis_col)


func _y_for(value: float, low: float, high: float, top: float, bottom: float) -> float:
	return bottom - (value - low) / (high - low) * (bottom - top)
