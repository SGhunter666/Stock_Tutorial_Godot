## Crisp 16-bit CRT 5-axis Behavioral Finance Radar Chart for the Portfolio
## Diagnostics Lab.
class_name SmaRadarChart
extends Control

var axes: Array = []
var overall_grade := "B"
var overall_score := 75.0


func _init() -> void:
	custom_minimum_size = Vector2(236, 196)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func set_data(next_axes: Array, grade: String, score: float) -> void:
	axes = next_axes
	overall_grade = grade
	overall_score = score
	queue_redraw()


func _draw() -> void:
	if size.x < 40.0 or size.y < 40.0:
		return
	var font := SmaUiTheme.pixel_font_10()
	draw_rect(Rect2(Vector2.ZERO, size), Color("#04070e"))
	draw_rect(Rect2(2, 2, size.x - 4.0, size.y - 4.0), SmaUiTheme.CRT_BG)
	draw_rect(Rect2(2, 2, size.x - 4.0, size.y - 4.0), Color("#3d608c"), false, 2.0)

	var count := axes.size()
	if count < 3:
		return
	var center := Vector2(size.x * 0.5, size.y * 0.52)
	var radius := minf(size.x * 0.30, size.y * 0.33)
	var ring_col := Color("#3d608c", 0.55)
	for ring in [0.33, 0.66, 1.0]:
		var pts := PackedVector2Array()
		for i in count:
			var ang := -PI * 0.5 + float(i) * TAU / float(count)
			pts.append(center + Vector2(cos(ang), sin(ang)) * (radius * float(ring)))
		pts.append(pts[0])
		draw_polyline(pts, ring_col, 1.0, false)

	for i in count:
		var ang := -PI * 0.5 + float(i) * TAU / float(count)
		var tip := center + Vector2(cos(ang), sin(ang)) * radius
		draw_line(center, tip, ring_col, 1.0)

	var data_pts := PackedVector2Array()
	for i in count:
		var entry: Dictionary = axes[i]
		var val := clampf(float(entry.get("value", 50.0)), 8.0, 100.0) / 100.0
		var ang := -PI * 0.5 + float(i) * TAU / float(count)
		data_pts.append(center + Vector2(cos(ang), sin(ang)) * (radius * val))

	var fill_col := Color(SmaUiTheme.POSITIVE.r, SmaUiTheme.POSITIVE.g, SmaUiTheme.POSITIVE.b, 0.28)
	var stroke_col := SmaUiTheme.GOLD if overall_score >= 82.0 else (
		SmaUiTheme.ACCENT if overall_score >= 65.0 else SmaUiTheme.NEGATIVE)
	if overall_score < 65.0:
		fill_col = Color(SmaUiTheme.NEGATIVE.r, SmaUiTheme.NEGATIVE.g, SmaUiTheme.NEGATIVE.b, 0.28)
	draw_colored_polygon(data_pts, fill_col)
	var closed := data_pts.duplicate()
	closed.append(data_pts[0])
	draw_polyline(closed, stroke_col, 2.0, false)
	for pt in data_pts:
		draw_rect(Rect2(roundf(pt.x - 2.0), roundf(pt.y - 2.0), 4.0, 4.0), stroke_col)

	for i in count:
		var entry: Dictionary = axes[i]
		var lbl := String(entry.get("label", ""))
		var ang := -PI * 0.5 + float(i) * TAU / float(count)
		var dir := Vector2(cos(ang), sin(ang))
		var pos := center + dir * (radius + 16.0)
		var tsize := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		var lx := clampf(pos.x - tsize.x * 0.5, 6.0, size.x - tsize.x - 6.0)
		var ly := clampf(pos.y + 4.0, 14.0, size.y - 6.0)
		draw_string(font, Vector2(roundf(lx), roundf(ly)), lbl,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#cfe2f7"))

	var grade_txt := "%s · %d" % [overall_grade, int(round(overall_score))]
	draw_string(font, Vector2(8.0, 15.0), grade_txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, stroke_col)
