## Interactive pixel modals launched from hotspots inside SmaPixelOfficeBanner:
##   "mentor": Live Mentor Portfolio & Risk Diagnostic Desk (with animated portrait)
##   "shop":   Kairosoft-style Pixel Office Renovation Workshop & Specialist Roster
##   "honors": Farview Pixel Trophy, Certificate & Achievement Case
class_name SmaOfficePopupDialog
extends Control

signal closed
signal navigate_requested(screen_id: String)

const PROP_ICONS := {
	"espresso_bar": "prop_espresso",
	"lucky_cat": "prop_cat",
	"research_board": "quant",
	"bloomberg_rig": "prop_bloomberg",
	"world_clocks": "prop_clocks",
	"server_rack": "prop_server",
	"vip_lounge": "fund",
	"bull_statue": "prop_bull",
}

var game: Node
var mode := "mentor"
var mentor_id := "lin_lan"
var _panel: PanelContainer


func setup(game_ref: Node, popup_mode: String = "mentor", target_mentor: String = "lin_lan") -> void:
	game = game_ref
	mode = popup_mode
	mentor_id = target_mentor
	_build_shell()
	_rebuild_panel()


func _build_shell() -> void:
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

	_panel = SmaKit.modal_card(18)
	_panel.custom_minimum_size = Vector2(800, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(_panel)


func _rebuild_panel() -> void:
	if _panel == null:
		return
	SmaKit.clear_children(_panel)
	var root := SmaKit.vbox(10)
	_panel.add_child(root)

	# Unified Kairosoft × PC-98 top tab bar
	var head := SmaKit.hbox(8)
	for tab in [
		["mentor", "logo", I18n.t("office.tabMentor")],
		["shop", "office", I18n.t("office.tabShop")],
		["honors", "challenges", I18n.t("office.tabHonors")],
	]:
		var tid := String(tab[0])
		var btn := SmaKit.button(String(tab[2]), func():
			mode = tid
			_play_sfx("pixel_click")
			_rebuild_panel(), mode == tid)
		btn.icon = SmaPixelArt.icon(String(tab[1]))
		head.add_child(btn)
	head.add_child(SmaKit.hspacer())
	head.add_child(SmaKit.arcade_button(I18n.t("poster.openShort"), "amber", func():
		var m := get_tree().get_first_node_in_group("main")
		_close()
		if m != null and m.has_method("open_poster"):
			m.open_poster()))
	head.add_child(SmaKit.button(I18n.t("common.close"), _close))
	root.add_child(head)
	root.add_child(SmaKit.separator())

	if mode == "shop":
		_build_shop(root)
	elif mode == "honors":
		_build_honors(root)
	else:
		_build_mentor_diag(root)


func _build_mentor_diag(root: VBoxContainer) -> void:
	var equity: float = float(game.get_equity()) if game != null else 100000.0
	var cash := float(game.exchange.state["account"]["cash"]) if (game != null and game.exchange != null) else 100000.0
	var cash_pct := (cash / maxf(1.0, equity)) * 100.0
	var rev: Dictionary = game.review_summary() if (game != null and game.exchange != null) else {}
	var conc_pct := float(rev.get("concentrationPct", 0.0))
	var win_pct := float(rev.get("winRatePct", 0.0))
	var real_pnl := float(rev.get("realizedPnl", 0.0))
	var is_warn := conc_pct > 25.0 or cash_pct < 20.0

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
		var tex := load(px_path) as Texture2D
		p_rect.texture = tex
		p_rect.custom_minimum_size = Vector2(144, 192)
		p_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var anim := SmaPortraitAnimator.new()
		anim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		p_rect.add_child(anim)
		anim.configure(mentor_id, tex, "crisis" if is_warn else "praise")
		p_frame.add_child(p_rect)
		left_col.add_child(p_frame)
		var m_name := I18n.t("story.char.%s.name" % mentor_id) if I18n.has_key("story.char.%s.name" % mentor_id) else mentor_id
		var m_lbl := SmaKit.label(m_name, 12, SmaUiTheme.ACCENT)
		m_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		left_col.add_child(m_lbl)
		body.add_child(left_col)

	var col := SmaKit.vbox(8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(col)
	col.add_child(SmaKit.title(I18n.t("pixelOffice.diagTitle"), 18))

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
		m_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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


func _build_shop(root: VBoxContainer) -> void:
	var avail_rp: int = int(game.office_available_rp()) if game != null else SmaOffice.STARTER_RP
	var rank_num: int = int(game.career.get("rank", 1)) if game != null else 1
	var office_state: Dictionary = game.office if game != null else SmaOffice.create_state()
	var owned_count := (office_state.get("owned", []) as Array).size()
	var staff_list: Array = game.fund.get("employees", []) if game != null else []

	var banner_row := SmaKit.hbox(10)
	banner_row.add_child(SmaKit.title(I18n.t("office.shopTitle"), 18))
	banner_row.add_child(SmaKit.hspacer())
	banner_row.add_child(SmaKit.badge(
		I18n.t("office.rpBadge", {"rp": avail_rp}),
		Color("#3b2306"), SmaUiTheme.GOLD))
	banner_row.add_child(SmaKit.badge(
		I18n.t("office.ownedBadge", {"done": owned_count, "total": SmaOffice.ITEMS.size()}),
		SmaUiTheme.PANEL_ALT, SmaUiTheme.ACCENT))
	banner_row.add_child(SmaKit.badge(
		I18n.t("office.staffBadge", {"count": staff_list.size()}),
		SmaUiTheme.PANEL_ALT, SmaUiTheme.POSITIVE))
	root.add_child(banner_row)

	var hint := SmaKit.muted(I18n.t("office.rpHint"), 11)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)

	var perks: Dictionary = SmaOffice.active_perks(office_state)
	var perk_bar := SmaKit.flow(6)
	perk_bar.add_child(SmaKit.badge(
		I18n.t("office.perkBarBots", {"slots": int(perks.get("botSlots", 1))}),
		SmaUiTheme.PANEL_ALT, SmaUiTheme.ACCENT))
	perk_bar.add_child(SmaKit.badge(
		I18n.t("office.perkBarXp", {"pct": int(perks.get("xpBonusPct", 0))}),
		SmaUiTheme.PANEL_ALT, SmaUiTheme.POSITIVE if int(perks.get("xpBonusPct", 0)) > 0 else SmaUiTheme.MUTED))
	if bool(perks.get("hasDeskSentiment", false)):
		perk_bar.add_child(SmaKit.badge(I18n.t("office.perkBarDesk"), SmaUiTheme.PANEL_ALT, SmaUiTheme.GOLD))
	if bool(perks.get("hasDailyCoffee", false)) and game != null:
		perk_bar.add_child(SmaKit.arcade_button(I18n.t("office.dailyCoffeeBtn"), "amber", func():
			var res: Dictionary = game.claim_office_interaction("coffee")
			if bool(res.get("ok", false)):
				_play_sfx("pixel_coffee")
				game.toast(I18n.t("office.coffeeClaimed", {"xp": int(res.get("xp", 20))}))
			else:
				game.toast(I18n.t("office.coffeeAlready"))
			_rebuild_panel()))
	root.add_child(perk_bar)

	var grid_scroll := SmaKit.scroll(410)
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	for item in SmaOffice.ITEMS:
		var iid := String(item["id"])
		var cost := int(item["cost"])
		var min_rank := int(item["minRank"])
		var owned := SmaOffice.is_owned(office_state, iid)
		var displayed := SmaOffice.is_displayed(office_state, iid)
		var card := SmaKit.card(10)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := SmaKit.vbox(6)
		card.add_child(box)

		var top := SmaKit.hbox(8)
		top.add_child(SmaKit.icon_rect(String(PROP_ICONS.get(iid, "office")), Vector2(24, 24)))
		var titles := SmaKit.vbox(1)
		titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		titles.add_child(SmaKit.label(I18n.t(String(item["titleKey"])), 13,
			SmaUiTheme.GOLD if owned else SmaUiTheme.TEXT))
		var desc := SmaKit.muted(I18n.t(String(item["descKey"])), 10)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		titles.add_child(desc)
		var perk_k := String(item.get("perkKey", ""))
		if perk_k != "" and I18n.has_key(perk_k):
			var perk_lbl := SmaKit.label(I18n.t(perk_k), 10, SmaUiTheme.POSITIVE if owned else SmaUiTheme.ACCENT)
			perk_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			titles.add_child(perk_lbl)
		top.add_child(titles)
		box.add_child(top)

		var foot := SmaKit.hbox(8)
		if min_rank > 1:
			foot.add_child(SmaKit.caption("Rank %d+" % min_rank))
		foot.add_child(SmaKit.hspacer())
		if owned:
			var toggle_label := I18n.t("office.displayed") if displayed else I18n.t("office.stored")
			var toggle_btn := SmaKit.button(toggle_label, func():
				if game != null:
					game.toggle_office_item(iid)
					_play_sfx("pixel_click")
					_rebuild_panel(), displayed)
			foot.add_child(toggle_btn)
		elif rank_num < min_rank:
			var lock_btn := SmaKit.button(I18n.t("office.needRank", {"rank": min_rank}))
			lock_btn.disabled = true
			foot.add_child(lock_btn)
		elif avail_rp < cost:
			var wait_btn := SmaKit.button("%d RP" % cost)
			wait_btn.disabled = true
			foot.add_child(wait_btn)
		else:
			foot.add_child(SmaKit.arcade_button(
				I18n.t("office.buyBtn", {"cost": cost}), "buy", func():
					_buy_item(iid)))
		box.add_child(foot)
		grid.add_child(card)
	grid_scroll.add_child(grid)
	root.add_child(grid_scroll)

	var staff_foot := SmaKit.hbox(8)
	var staff_note := I18n.t("office.staffHintNone") if staff_list.is_empty() else I18n.t(
		"office.staffHintActive", {"count": staff_list.size()})
	staff_foot.add_child(SmaKit.muted(staff_note, 11))
	staff_foot.add_child(SmaKit.hspacer())
	if game != null and game.is_fund_active():
		staff_foot.add_child(SmaKit.button(I18n.t("nav.fund"), func():
			_close()
			navigate_requested.emit("fund")))
	root.add_child(staff_foot)


func _buy_item(item_id: String) -> void:
	if game == null:
		return
	var res: Dictionary = game.purchase_office_item(item_id)
	if not bool(res.get("ok", false)):
		game.toast(I18n.t(String(res.get("error", "office.errorUnknown"))))
		return
	_play_sfx("achievement")
	var m := get_tree().get_first_node_in_group("main")
	if m != null and m.get("_pixel_fx") != null:
		m._pixel_fx.spawn_burst(size * 0.5, SmaUiTheme.GOLD, 14)
	var def: Dictionary = res.get("item", {})
	game.toast(I18n.t("office.boughtToast", {
		"item": I18n.t(String(def.get("titleKey", item_id))),
	}))
	_rebuild_panel()


func _build_honors(root: VBoxContainer) -> void:
	var rank_num := int(game.career.get("rank", 1)) if game != null else 1
	var rank_def: Dictionary = SmaCareer.rank_def(rank_num)
	var lvl: Dictionary = SmaAcademy.level_info(game.academy) if game != null else {"level": 1, "xp": 0}
	var unlocked_ach: Array = game.academy.get("achievements", []) if game != null else []
	var certs: Array = game.career.get("certificates", []) if game != null else []

	root.add_child(SmaKit.title(I18n.t("pixelOffice.honorsTitle"), 18))
	var summary := SmaKit.hbox(12)
	for pill in [
		[I18n.t("nav.career"), "Rank %d · %s" % [rank_num, I18n.t(String(rank_def.get("titleKey", "career.rank.retail.title")))], SmaUiTheme.GOLD],
		[I18n.t("academy.levelLabel"), "Lv.%d · %d XP" % [int(lvl["level"]), int(lvl["xp"])], SmaUiTheme.ACCENT],
		[I18n.t("academy.achievementsTitle"), "%d / %d" % [unlocked_ach.size(), SmaAcademy.ACHIEVEMENTS.size()], SmaUiTheme.POSITIVE],
	]:
		var c := SmaKit.card(8)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b := SmaKit.vbox(2)
		c.add_child(b)
		b.add_child(SmaKit.caption(String(pill[0])))
		b.add_child(SmaKit.label(String(pill[1]), 13, pill[2]))
		summary.add_child(c)
	root.add_child(summary)

	var scroll := SmaKit.scroll(280)
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
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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


func _play_sfx(sound: String) -> void:
	var audio := get_node_or_null("/root/Sfx")
	if audio != null and audio.has_method("play"):
		audio.play(sound)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	closed.emit()
	queue_free()
