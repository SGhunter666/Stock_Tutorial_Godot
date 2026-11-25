## Compact 20-bar stepped pixel sparkline with recessed mini-CRT backing and
## 2px staircase blocks for Market & Watchlist tables (Style B Market Board).
class_name SmaSparkline
extends Control

var _values: Array[float] = []
var _positive := true


func _init() -> void:
	custom_minimum_size = Vector2(72, 22)
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
	var bg := Color("#081220") if SmaUiTheme.mode != "light" else Color("#dfd0b2")
	var rim := Color("#233b5c") if SmaUiTheme.mode != "light" else Color("#b89566")
	draw_rect(Rect2(Vector2.ZERO, size), rim)
	draw_rect(Rect2(1, 1, maxf(0.0, size.x - 2.0), maxf(0.0, size.y - 2.0)), bg)
	var lo := _values[0]
	var hi := _values[0]
	for v in _values:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	if is_equal_approx(lo, hi):
		hi = lo + 1.0
	var w := maxf(16.0, size.x - 6.0)
	var h := maxf(8.0, size.y - 6.0)
	var color := SmaUiTheme.POSITIVE if _positive else SmaUiTheme.NEGATIVE
	var fill := Color(color.r, color.g, color.b, 0.25)
	var count := _values.size()
	var step := w / float(count - 1)
	var prev := Vector2.ZERO
	for i in count:
		var x := roundf((3.0 + float(i) * step) / 2.0) * 2.0
		var y := roundf((3.0 + h - ((_values[i] - lo) / (hi - lo)) * h) / 2.0) * 2.0
		var cur := Vector2(x, y)
		draw_rect(Rect2(cur.x, cur.y, maxf(2.0, ceilf(step)), maxf(2.0, size.y - 2.0 - cur.y)), fill)
		if i > 0:
			draw_rect(Rect2(prev.x, prev.y, maxf(2.0, cur.x - prev.x + 2.0), 2.0), color)
			var top_y := minf(prev.y, cur.y)
			var seg_h := absf(cur.y - prev.y)
			if seg_h >= 2.0:
				draw_rect(Rect2(cur.x, top_y, 2.0, seg_h + 2.0), color)
		prev = cur
