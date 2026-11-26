## Interactive 16-bit Pixel Diploma & Trader Battle Card modal + PNG exporter.
## Displays a gold-rimmed pixel certificate with Lin Lan's PC-98 portrait, wax
## seal, key metrics, and Bayer-dithered CRT equity curve, and exports a crisp
## standalone PNG to user://saves/ or the user's Desktop.
class_name SmaReportPoster
extends Control

signal closed

var game: Node
var report_data: Dictionary = {}
var daily_data: Dictionary = {}
var _poster_card: PanelContainer
var _status_label: Label
var _saved_user_path := ""


class SmaPixelWaxSeal extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(136, 38)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var ink := Color("#090d16")
		var red_hi := Color("#f87171")
		var red_body := Color("#b91c1c")
		var red_sh := Color("#7f1d1d")
		var gold := Color("#fef08a")
		# Ribbon tails
		draw_rect(Rect2(12, 10, 22, 18), ink)
		draw_rect(Rect2(14, 12, 18, 14), Color("#1d4ed8"))
		draw_rect(Rect2(size.x - 34, 10, 22, 18), ink)
		draw_rect(Rect2(size.x - 32, 12, 18, 14), Color("#1d4ed8"))
		# Central notched wax seal
		var sx := roundf(size.x * 0.5 - 42.0)
		draw_rect(Rect2(sx + 2, 2, 80, 34), ink)
		draw_rect(Rect2(sx, 4, 84, 30), ink)
		draw_rect(Rect2(sx + 2, 4, 80, 28), red_body)
		draw_rect(Rect2(sx + 4, 4, 76, 2), red_hi)
		draw_rect(Rect2(sx + 4, 30, 76, 2), red_sh)
		draw_rect(Rect2(sx + 6, 8, 72, 20), gold, false, 2.0)
		var font := SmaUiTheme.pixel_font_10()
		if font != null:
			draw_string(font, Vector2(sx + 8, 22), "★ SMA SEAL ★",
				HORIZONTAL_ALIGNMENT_CENTER, 68, 10, gold)


func setup(game_ref: Node, custom_daily: Dictionary = {}) -> void:
	game = game_ref
	daily_data = custom_daily
	report_data = game.graduation_report() if game != null else {}
	_build()
	_auto_export_initial.call_deferred()


static func write_headless_png(report: Dictionary, target_path: String) -> bool:
	var w := 920
	var h := 540
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color("#091224"))
	img.fill_rect(Rect2i(0, 0, w, 6), Color("#fbbf24"))
	img.fill_rect(Rect2i(0, h - 6, w, 6), Color("#b45309"))
	img.fill_rect(Rect2i(0, 0, 6, h), Color("#fbbf24"))
	img.fill_rect(Rect2i(w - 6, 0, 6, h), Color("#b45309"))
	img.fill_rect(Rect2i(24, 96, w - 48, h - 136), Color("#060d18"))
	var ret := float(report.get("netReturnPct", 0.0))
	var bar_col := Color("#4ade80") if ret >= 0.0 else Color("#f87171")
	for i in 24:
		var bh := 40 + ((i * 19 + int(absf(ret) * 10.0)) % 180)
		img.fill_rect(Rect2i(52 + i * 34, h - 64 - bh, 22, bh), bar_col)
	var abs_dir := ProjectSettings.globalize_path(target_path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(abs_dir)
	return img.save_png(ProjectSettings.globalize_path(target_path)) == OK


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 68

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.08, 0.86)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close())
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var outer := SmaKit.vbox(10)
	outer.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(outer)

	_poster_card = _build_poster_card()
	outer.add_child(_poster_card)

	var ctrl_bar := SmaKit.modal_card(10)
	var ctrl_row := SmaKit.hbox(10)
	ctrl_bar.add_child(ctrl_row)
	_status_label = SmaKit.label(I18n.t("poster.generating"), 12, SmaUiTheme.ACCENT)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.clip_text = true
	ctrl_row.add_child(_status_label)
	ctrl_row.add_child(SmaKit.arcade_button(I18n.t("poster.saveDesktop"), "buy", _save_to_desktop))
	ctrl_row.add_child(SmaKit.button(I18n.t("common.close"), _close))
	outer.add_child(ctrl_bar)


func _build_poster_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(900, 500)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel",
		SmaPixelArt.card_box(Color("#0d182c"), Color("#fbbf24"), Color("#78350f"), 18, true))

	var root := SmaKit.vbox(10)
	card.add_child(root)

	# 1. Crest Header (always bright-on-navy inside the gold certificate frame)
	var head := SmaKit.hbox(10)
	head.add_child(SmaKit.icon_rect("logo", Vector2(26, 26)))
	var brand := SmaKit.label("FARVIEW TRADING ACADEMY · 远望交易学院", 13, Color("#fbbf24"))
	head.add_child(brand)
	head.add_child(SmaKit.hspacer())
	var is_daily := not daily_data.is_empty()
	var seed_str := String(daily_data.get("seed", ""))
	if seed_str == "" and game != null and game.exchange != null:
		seed_str = String(game.exchange.state.get("seed", "academy-2026"))
	var seed_pill := SmaKit.label("SEED · %s" % seed_str, 11, Color("#5eead4"))
	head.add_child(seed_pill)
	root.add_child(head)

	var gold_line := ColorRect.new()
	gold_line.custom_minimum_size.y = 2
	gold_line.color = Color("#fbbf24")
	root.add_child(gold_line)

	# 2. Body: Left Portrait & Wax Seal + Right Stats & CRT Equity Curve
	var body := SmaKit.hbox(16)
	root.add_child(body)

	var left_col := SmaKit.vbox(8)
	left_col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var p_frame := PanelContainer.new()
	p_frame.add_theme_stylebox_override("panel",
		SmaPixelArt.card_box(Color("#07101d"), Color("#5eead4"), Color("#040811"), 4, false))
	var p_rect := TextureRect.new()
	var px_path := "res://assets/portraits/pixel/lin_lan.png"
	if ResourceLoader.exists(px_path):
		var tex := load(px_path) as Texture2D
		p_rect.texture = tex
		var anim := SmaPortraitAnimator.new()
		anim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		anim.configure("lin_lan", tex, "praise")
		p_rect.add_child(anim)
	p_rect.custom_minimum_size = Vector2(144, 192)
	p_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p_frame.add_child(p_rect)
	left_col.add_child(p_frame)
	left_col.add_child(SmaPixelWaxSeal.new())
	var mentor_cap := SmaKit.label(I18n.t("poster.mentorSign"), 11, Color("#cbd5e1"))
	mentor_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_col.add_child(mentor_cap)
	body.add_child(left_col)

	var right_col := SmaKit.vbox(8)
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right_col)

	var player_name := String(report_data.get("playerName", "Trader"))
	var banner_title := ""
	var sub_line := ""
	if is_daily:
		banner_title = I18n.t("poster.dailyTitle", {
			"code": String(daily_data.get("code", "")),
			"grade": String(daily_data.get("grade", "B")),
		})
		sub_line = "%s · %s" % [player_name, I18n.t("poster.dailySub", {
			"days": int(daily_data.get("days", 0)),
			"score": int(daily_data.get("score", 0)),
		})]
	else:
		var grad := bool(report_data.get("graduated", false))
		banner_title = I18n.t("poster.gradTitle" if grad else "poster.cardTitle", {"name": player_name})
		var r_key := String(report_data.get("careerRankKey", "career.rank.retail.title"))
		sub_line = "Rank %d · %s · Day %d (%s)" % [
			int(report_data.get("careerRank", 1)),
			I18n.t(r_key),
			int(report_data.get("day", 0)) + 1,
			String(report_data.get("date", "")),
		]

	right_col.add_child(SmaKit.label("★ " + banner_title, 22, Color("#fef08a")))
	right_col.add_child(SmaKit.label(sub_line, 12, Color("#93c5fd")))

	var eq_val := float(daily_data.get("equity", report_data.get("equity", 100000.0)))
	var ret_val := float(daily_data.get("returnPct", report_data.get("netReturnPct", 0.0)))
	var dd_val := float(daily_data.get("maxDrawdownPct", report_data.get("maxDrawdownPct", 0.0)))
	var tr_cnt := int(daily_data.get("trades", report_data.get("totalTrades", 0)))
	var fourth_title := I18n.t("poster.scoreLabel") if is_daily else I18n.t("story.report.honors")
	var fourth_val := "%d (%s)" % [int(daily_data.get("score", 0)), String(daily_data.get("grade", "B"))] \
		if is_daily else "%d/%d · %d★" % [
			int(report_data.get("unitsDone", 0)),
			int(report_data.get("unitsTotal", 32)),
			int(report_data.get("achievementsCount", 0)),
		]

	var pos_c := Color("#4ade80") if SmaUiTheme.color_scheme != "cn" else Color("#f87171")
	var neg_c := Color("#f87171") if SmaUiTheme.color_scheme != "cn" else Color("#4ade80")
	var ret_col := pos_c if ret_val >= 0.0 else neg_c

	var m_grid := GridContainer.new()
	m_grid.columns = 4
	m_grid.add_theme_constant_override("h_separation", 8)
	for m in [
		[I18n.t("story.report.equity"), "%s (%s)" % [SmaFormat.money(eq_val), SmaFormat.pct(ret_val, 2)], ret_col],
		[I18n.t("portfolio.maxDrawdown"), SmaFormat.pct_plain(dd_val, 2), Color("#fbbf24") if dd_val > 8.0 else pos_c],
		[I18n.t("dashboard.winRate"), "%s · %d" % [SmaFormat.pct_plain(float(report_data.get("winRatePct", 0.0)), 1), tr_cnt], Color("#5eead4")],
		[fourth_title, fourth_val, Color("#fef08a")],
	]:
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_stylebox_override("panel",
			SmaPixelArt.readout_box(Color("#070e1b"), Color("#3b5d8a"), 8, 6))
		var cb := SmaKit.vbox(2)
		cell.add_child(cb)
		cb.add_child(SmaKit.label(String(m[0]), 10, Color("#88a8cc")))
		cb.add_child(SmaKit.label(String(m[1]), 12, m[2]))
		m_grid.add_child(cell)
	right_col.add_child(m_grid)

	# Embedded Bayer-dithered CRT Equity Curve
	var chart := SmaLineChart.new()
	chart.custom_minimum_size = Vector2(560, 158)
	var pts: Array = []
	if game != null and game.exchange != null:
		for entry in game.exchange.state["account"].get("equityHistory", []):
			pts.append(float(entry.get("equity", 100000.0)))
		pts.append(float(game.get_equity()))
	if pts.size() < 2:
		pts = [100000.0, eq_val]
	chart.set_series(pts, ret_col, "money", "DAY 01", "NOW")
	right_col.add_child(chart)

	var foot := SmaKit.hbox(8)
	foot.add_child(SmaKit.label(I18n.t("poster.footerNote"), 10, Color("#88a8cc")))
	foot.add_child(SmaKit.hspacer())
	foot.add_child(SmaKit.label("Stock Market Academy · %s" % String(
		ProjectSettings.get_setting("application/config/version", "beta-12")), 10, Color("#fbbf24")))
	right_col.add_child(foot)

	return card


func _auto_export_initial() -> void:
	var slot_num := int(game.active_slot) if game != null else 1
	var suffix := ("daily_%s" % String(daily_data.get("code", "run"))) \
		if not daily_data.is_empty() else ("slot_%d" % slot_num)
	_saved_user_path = "user://saves/farview_poster_%s.png" % suffix
	var ok := await capture_to_png(_saved_user_path)
	if _status_label != null and is_instance_valid(_status_label):
		_status_label.text = I18n.t("poster.savedPath", {"path": _saved_user_path}) if ok \
			else I18n.t("toast.saveFailed")


func capture_to_png(target_path: String) -> bool:
	if DisplayServer.get_name() == "headless":
		return write_headless_png(report_data, target_path)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if _poster_card == null or not is_instance_valid(_poster_card):
		return false
	var vp_img := get_viewport().get_texture().get_image()
	if vp_img == null or vp_img.is_empty():
		return write_headless_png(report_data, target_path)
	var vp_rect := get_viewport_rect().size
	var scale_x := float(vp_img.get_width()) / maxf(1.0, vp_rect.x)
	var scale_y := float(vp_img.get_height()) / maxf(1.0, vp_rect.y)
	var grect := _poster_card.get_global_rect()
	var rx := clampi(int(round(grect.position.x * scale_x)), 0, vp_img.get_width() - 2)
	var ry := clampi(int(round(grect.position.y * scale_y)), 0, vp_img.get_height() - 2)
	var rw := clampi(int(round(grect.size.x * scale_x)), 1, vp_img.get_width() - rx)
	var rh := clampi(int(round(grect.size.y * scale_y)), 1, vp_img.get_height() - ry)
	var cropped := vp_img.get_region(Rect2i(rx, ry, rw, rh))
	var global_target := ProjectSettings.globalize_path(target_path) \
		if target_path.begins_with("user://") or target_path.begins_with("res://") else target_path
	DirAccess.make_dir_recursive_absolute(global_target.get_base_dir())
	return cropped.save_png(global_target) == OK


func _save_to_desktop() -> void:
	var desktop := OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	if desktop == "":
		desktop = ProjectSettings.globalize_path("user://saves")
	var tag := String(daily_data.get("code", "Slot%d" % (int(game.active_slot) if game != null else 1)))
	var target := "%s/Farview_Poster_%s.png" % [desktop, tag]
	var ok := await capture_to_png(target)
	if _status_label != null and is_instance_valid(_status_label):
		_status_label.text = I18n.t("poster.savedDesktop", {"path": target}) if ok \
			else I18n.t("toast.saveFailed")
	if ok and game != null:
		game.toast(I18n.t("poster.savedToast"))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	closed.emit()
	queue_free()
