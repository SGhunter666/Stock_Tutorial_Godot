## Interactive pixel modals launched from hotspots inside SmaPixelOfficeBanner:
##   "mentor": Live Mentor Portfolio & Risk Diagnostic Desk
##   "honors": Farview Pixel Trophy, Certificate & Achievement Case
class_name SmaOfficePopupDialog
extends Control

signal closed
signal navigate_requested(screen_id: String)

var game: Node
var mode := "mentor"
var mentor_id := "lin_lan"


func setup(game_ref: Node, popup_mode: String = "mentor", target_mentor: String = "lin_lan") -> void:
	game = game_ref
	mode = popup_mode
	mentor_id = target_mentor
	_build()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 62
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.08, 0.82)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close())
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := SmaKit.modal_card(20)
	panel.custom_minimum_size = Vector2(760, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	if mode == "honors":
		_build_honors(panel)
	else:
		_build_mentor_diag(panel)


func _build_mentor_diag(panel: PanelContainer) -> void:
	var root := SmaKit.vbox(12)
	panel.add_child(root)
	var head := SmaKit.hbox(10)
	head.add_child(SmaKit.icon_rect("logo", Vector2(22, 22)))
	head.add_child(SmaKit.title(I18n.t("pixelOffice.diagTitle"), 20))
	head.add_child(SmaKit.hspacer())
	head.add_child(SmaKit.button(I18n.t("common.close"), _close))
	root.add_child(head)
	root.add_child(SmaKit.separator())

	var body := SmaKit.hbox(18)
	root.add_child(body)

	var px_path := "res://assets/portraits/pixel/%s.png" % mentor_id
	if ResourceLoader.exists(px_path):
		var left_col := SmaKit.vbox(6)
		left_col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var p_frame := PanelContainer.new()
		p_frame.add_theme_stylebox_override("panel",
			SmaPixelArt.card_box(Color("#08111f"), SmaUiTheme.ACCENT, Color("#040811"), 4, false))
		var p_rect := TextureRect.new()
		p_rect.texture = load(px_path) as Texture2D
		p_rect.custom_minimum_size = Vector2(144, 192)
		p_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		p_frame.add_child(p_rect)
		left_col.add_child(p_frame)
		var m_name := I18n.t("story.char.%s.name" % mentor_id) if I18n.has_key("story.char.%s.name" % mentor_id) else mentor_id
		var m_lbl := SmaKit.label(m_name, 12, SmaUiTheme.ACCENT)
		m_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		left_col.add_child(m_lbl)
		body.add_child(left_col)

	var col := SmaKit.vbox(8)
	body.add_child(col)
	var equity: float = float(game.get_equity()) if game != null else 100000.0
	var cash := float(game.exchange.state["account"]["cash"]) if (game != null and game.exchange != null) else 100000.0
	var cash_pct := (cash / maxf(1.0, equity)) * 100.0
	var rev: Dictionary = game.review_summary() if (game != null and game.exchange != null) else {}
	var conc_pct := float(rev.get("concentrationPct", 0.0))
	var win_pct := float(rev.get("winRatePct", 0.0))
	var real_pnl := float(rev.get("realizedPnl", 0.0))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	for spec in [
		[I18n.t("pixelOffice.diagCashPct"), SmaFormat.pct_plain(cash_pct, 1),
			SmaUiTheme.POSITIVE if cash_pct >= 20.0 else SmaUiTheme.WARNING],
		[I18n.t("dashboard.concentration"), SmaFormat.pct_plain(conc_pct, 1),
			SmaUiTheme.WARNING if conc_pct > 25.0 else SmaUiTheme.POSITIVE],
		[I18n.t("dashboard.winRate"), SmaFormat.pct_plain(win_pct, 1), SmaUiTheme.ACCENT],
		[I18n.t("dashboard.realized"), SmaFormat.signed_money(real_pnl), SmaKit.value_color(real_pnl)],
	]:
		var m_card := SmaKit.card(8)
		var m_box := SmaKit.vbox(2)
		m_card.add_child(m_box)
		m_box.add_child(SmaKit.caption(String(spec[0])))
		m_box.add_child(SmaKit.label(String(spec[1]), 18, spec[2]))
		grid.add_child(m_card)
	col.add_child(grid)

	var advice_text := I18n.t("pixelOffice.diagHealthy")
	var advice_col := SmaUiTheme.POSITIVE
	if conc_pct > 25.0:
		advice_text = I18n.t("pixelOffice.diagHighConc", {"pct": SmaFormat.pct_plain(conc_pct, 1)})
		advice_col = SmaUiTheme.WARNING
	elif cash_pct < 20.0:
		advice_text = I18n.t("pixelOffice.diagLowCash", {"pct": SmaFormat.pct_plain(cash_pct, 1)})
		advice_col = SmaUiTheme.WARNING
	var advice_lbl := SmaKit.label(advice_text, 12, advice_col)
	advice_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(advice_lbl)

	if game != null and game.started:
		var obj: Dictionary = game.current_objective()
		var obj_card := SmaKit.card(10)
		var o_box := SmaKit.vbox(4)
		obj_card.add_child(o_box)
		o_box.add_child(SmaKit.label(String(obj.get("title", "")), 13, SmaUiTheme.GOLD))
		var det := SmaKit.muted(String(obj.get("detail", "")), 11)
		det.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		o_box.add_child(det)
		var target_scr := String(obj.get("target", "academy"))
		var btn_row := SmaKit.hbox(8)
		btn_row.add_child(SmaKit.hspacer())
		btn_row.add_child(SmaKit.arcade_button(
			String(obj.get("button", I18n.t("objective.goAcademy"))), "buy", func():
				var dest := target_scr
				_close()
				navigate_requested.emit(dest)))
		o_box.add_child(btn_row)
		col.add_child(obj_card)


func _build_honors(panel: PanelContainer) -> void:
	var root := SmaKit.vbox(10)
	panel.add_child(root)
	var head := SmaKit.hbox(10)
	head.add_child(SmaKit.icon_rect("challenges", Vector2(20, 20)))
	head.add_child(SmaKit.title(I18n.t("pixelOffice.honorsTitle"), 20))
	head.add_child(SmaKit.hspacer())
	head.add_child(SmaKit.button(I18n.t("common.close"), _close))
	root.add_child(head)
	root.add_child(SmaKit.separator())

	var rank_num := int(game.career.get("rank", 1)) if game != null else 1
	var rank_def: Dictionary = SmaCareer.rank_def(rank_num)
	var lvl: Dictionary = SmaAcademy.level_info(game.academy) if game != null else {"level": 1, "xp": 0}
	var unlocked_ach: Array = game.academy.get("achievements", []) if game != null else []
	var certs: Array = game.career.get("certificates", []) if game != null else []

	var summary := SmaKit.hbox(12)
	for pill in [
		[I18n.t("nav.career"), "Rank %d · %s" % [rank_num, I18n.t(String(rank_def.get("titleKey", "career.rank.retail.title")))], SmaUiTheme.GOLD],
		[I18n.t("academy.levelLabel"), "Lv.%d · %d XP" % [int(lvl["level"]), int(lvl["xp"])], SmaUiTheme.ACCENT],
		[I18n.t("academy.achievementsTitle"), "%d / %d" % [unlocked_ach.size(), SmaAcademy.ACHIEVEMENTS.size()], SmaUiTheme.POSITIVE],
	]:
		var c := SmaKit.card(8)
		var b := SmaKit.vbox(2)
		c.add_child(b)
		b.add_child(SmaKit.caption(String(pill[0])))
		b.add_child(SmaKit.label(String(pill[1]), 13, pill[2]))
		summary.add_child(c)
	root.add_child(summary)

	var scroll := SmaKit.scroll(320)
	var list := SmaKit.vbox(6)
	scroll.add_child(list)
	if not certs.is_empty():
		list.add_child(SmaKit.label(I18n.t("story.report.certs", {"count": certs.size()}), 12, SmaUiTheme.GOLD))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	for ach in SmaAcademy.ACHIEVEMENTS:
		var aid := String(ach["id"])
		var earned := unlocked_ach.has(aid)
		var cell := SmaKit.card(8)
		var row := SmaKit.hbox(8)
		cell.add_child(row)
		row.add_child(SmaKit.icon_rect("watchlist" if earned else "cb_unchecked", Vector2(16, 16)))
		var meta := SmaKit.vbox(1)
		meta.add_child(SmaKit.label(I18n.t("achievement.%s.title" % aid), 12,
			SmaUiTheme.POSITIVE if earned else SmaUiTheme.DIM))
		meta.add_child(SmaKit.caption(I18n.t("achievement.%s.desc" % aid)))
		row.add_child(meta)
		grid.add_child(cell)
	list.add_child(grid)
	root.add_child(scroll)

	var foot := SmaKit.hbox(8)
	foot.add_child(SmaKit.hspacer())
	foot.add_child(SmaKit.button(I18n.t("nav.career"), func():
		_close()
		navigate_requested.emit("career")))
	foot.add_child(SmaKit.arcade_button(I18n.t("nav.academy"), "primary", func():
		_close()
		navigate_requested.emit("academy")))
	root.add_child(foot)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	closed.emit()
	queue_free()
