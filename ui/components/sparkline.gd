## Compact 20-bar stepped pixel sparkline for market tables (Style B Market Board).
class_name SmaSparkline
extends Control

var _values: Array[float] = []
var _positive := true


func _init() -> void:
	custom_minimum_size = Vector2(68, 20)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(points: Array, positive: bool) -> void:
	_values.clear()
	for v in points:
		_values.append(float(v))
	_positive = positive
	queue_redraw()


func _draw() -> void:
	if _values.size() < 2:
		return
	var lo := _values[0]
	var hi := _values[0]
	for v in _values:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	if is_equal_approx(lo, hi):
		hi = lo + 1.0
	var w := maxf(16.0, size.x - 4.0)
	var h := maxf(8.0, size.y - 4.0)
	var color := SmaUiTheme.POSITIVE if _positive else SmaUiTheme.NEGATIVE
	var fill := Color(color.r, color.g, color.b, 0.18)
	var count := _values.size()
	var step := w / float(count - 1)
	var pixel := SmaUiTheme.is_pixel()
	var prev := Vector2.ZERO
	for i in count:
		var x := 2.0 + float(i) * step
		var y := 2.0 + h - ((_values[i] - lo) / (hi - lo)) * h
		if pixel:
			x = roundf(x)
			y = roundf(y)
		var cur := Vector2(x, y)
		if pixel:
			draw_rect(Rect2(cur.x, cur.y, maxf(2.0, ceilf(step)), maxf(1.0, size.y - 2.0 - cur.y)), fill)
			if i > 0:
				draw_rect(Rect2(prev.x, prev.y, maxf(2.0, cur.x - prev.x + 1.0), 2.0), color)
				var top_y := minf(prev.y, cur.y)
				var seg_h := absf(cur.y - prev.y)
				if seg_h >= 1.0:
					draw_rect(Rect2(cur.x, top_y, 2.0, seg_h + 1.0), color)
		else:
			if i > 0:
				draw_line(prev, cur, color, 1.5, true)
		prev = cur
