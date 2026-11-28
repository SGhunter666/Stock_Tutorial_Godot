## Flash Chart Trainer Screen (K-Line Blind Arcade Drill).
## Masks stock identity & dates on a 40-bar chart with VOL/MACD/RSI, lets the
## player decide Long / Short / Pass, animates the next 15 candles bar-by-bar,
## unmasks the real ticker & P&L, and awards Combo streaks + Academy XP.
class_name SmaFlashTrainerScreen
extends SmaScreen

var _stats_label: Label
var _combo_label: Label
var _round_title: Label
var _chart: SmaCandleChart
var _subpane_buttons: Dictionary = {}
var _action_box: HBoxContainer
var _reveal_box: VBoxContainer
var _verdict_label: Label
var _reveal_detail: Label
var _skip_btn: Button
var _next_btn: Button
var _jump_btn: Button

var _round: Dictionary = {}
var _phase := "decide" # "decide" | "animating" | "done"
var _reveal_idx := 0
var _anim_accum := 0.0
var _last_result: Dictionary = {}


func _build() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var root := SmaKit.vbox(10)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var head := SmaKit.hbox(10)
	var titles := SmaKit.vbox(2)
	titles.add_child(SmaKit.title(I18n.t("flash.title"), 22))
	titles.add_child(SmaKit.muted(I18n.t("flash.subtitle"), 12))
	head.add_child(titles)
	head.add_child(SmaKit.hspacer())
	var stats_box := SmaKit.vbox(2)
	_combo_label = SmaKit.label("", 15, SmaUiTheme.GOLD)
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stats_label = SmaKit.caption("")
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats_box.add_child(_combo_label)
	stats_box.add_child(_stats_label)
	head.add_child(stats_box)
	root.add_child(head)

	var chart_card := SmaKit.card(10)
	chart_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var chart_wrap := SmaKit.vbox(6)
	chart_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_card.add_child(chart_wrap)

	var bar := SmaKit.hbox(8)
	_round_title = SmaKit.label("MYSTERY #----", 14, SmaUiTheme.ACCENT)
	bar.add_child(_round_title)
	bar.add_child(SmaKit.hspacer())
	var sp_grp := ButtonGroup.new()
	for sp in [["volume", "VOL"], ["macd", "MACD"], ["rsi", "RSI"]]:
		var sid := String(sp[0])
		var btn := SmaKit.toggle(String(sp[1]), sp_grp)
		btn.button_pressed = sid == "macd"
		SmaKit.set_small_font(btn, 10)
		btn.pressed.connect(func():
			if _chart != null:
				_chart.set_subpane_mode(sid))
		_subpane_buttons[sid] = btn
		bar.add_child(btn)
	chart_wrap.add_child(bar)

	_chart = SmaCandleChart.new()
	_chart.custom_minimum_size = Vector2(560, 380)
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart.subpane_mode = "macd"
	_chart.show_ma = true
	chart_wrap.add_child(_chart)
	root.add_child(chart_card)

	var control_card := SmaKit.card(12)
	var ctrl_wrap := SmaKit.vbox(8)
	control_card.add_child(ctrl_wrap)

	_action_box = SmaKit.hbox(12)
	var long_btn := SmaKit.arcade_button(I18n.t("flash.btnLong"), "buy", _choose.bind("long"))
	long_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	long_btn.custom_minimum_size.y = 44
	var short_btn := SmaKit.arcade_button(I18n.t("flash.btnShort"), "sell", _choose.bind("short"))
	short_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	short_btn.custom_minimum_size.y = 44
	var pass_btn := SmaKit.arcade_button(I18n.t("flash.btnPass"), "amber", _choose.bind("pass"))
	pass_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pass_btn.custom_minimum_size.y = 44
	_action_box.add_child(long_btn)
	_action_box.add_child(short_btn)
	_action_box.add_child(pass_btn)
	ctrl_wrap.add_child(_action_box)

	_reveal_box = SmaKit.vbox(6)
	_reveal_box.visible = false
	_verdict_label = SmaKit.label("", 16, SmaUiTheme.GOLD)
	_verdict_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reveal_box.add_child(_verdict_label)
	_reveal_detail = SmaKit.muted("", 12)
	_reveal_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reveal_box.add_child(_reveal_detail)
	var nav_row := SmaKit.hbox(8)
	_skip_btn = SmaKit.button(I18n.t("flash.btnSkip"), _finish_reveal_now)
	_next_btn = SmaKit.arcade_button(I18n.t("flash.btnNext"), "buy", _start_new_round)
	_jump_btn = SmaKit.button(I18n.t("flash.btnInspect"), func():
		var tk := String(_round.get("ticker", ""))
		var m := get_tree().get_first_node_in_group("main")
		if tk != "" and m != null and m.has_method("open_ticker"):
			m.open_ticker(tk))
	nav_row.add_child(_skip_btn)
	nav_row.add_child(_next_btn)
	nav_row.add_child(_jump_btn)
	nav_row.add_child(SmaKit.hspacer())
	nav_row.add_child(SmaKit.caption(I18n.t("flash.keysHint")))
	_reveal_box.add_child(nav_row)
	ctrl_wrap.add_child(_reveal_box)
	root.add_child(control_card)


func refresh(_reason: String = "") -> void:
	if not built or game == null or not game.started:
		return
	_update_stats_header()
	if _round.is_empty():
		_start_new_round()


func _process(delta: float) -> void:
	if _phase != "animating" or not visible:
		return
	_anim_accum += delta
	if _anim_accum < 0.085:
		return
	_anim_accum = 0.0
	var fut: Array = _round.get("futureBars", [])
	_reveal_idx += 1
	if _reveal_idx >= fut.size():
		_finish_reveal_now()
	else:
		_render_chart_slice(_reveal_idx)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or game == null or not game.started:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.ctrl_pressed or key.meta_pressed:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if _phase == "decide":
		match key.keycode:
			KEY_L:
				_choose("long")
				get_viewport().set_input_as_handled()
			KEY_S:
				_choose("short")
				get_viewport().set_input_as_handled()
			KEY_P:
				_choose("pass")
				get_viewport().set_input_as_handled()
	elif _phase == "done" and key.keycode == KEY_ENTER:
		_start_new_round()
		get_viewport().set_input_as_handled()


func _update_stats_header() -> void:
	if game == null:
		return
	var st: Dictionary = game.flash_trainer_stats()
	var played := int(st.get("played", 0))
	var wins := int(st.get("wins", 0))
	var wr := (float(wins) / float(played) * 100.0) if played > 0 else 0.0
	_combo_label.text = I18n.t("flash.comboBanner", {
		"streak": int(st.get("streak", 0)),
		"score": int(st.get("score", 0)),
	})
	_stats_label.text = I18n.t("flash.statsLine", {
		"played": played,
		"winRate": SmaFormat.pct_plain(wr, 0),
		"bestStreak": int(st.get("bestStreak", 0)),
		"bestScore": int(st.get("bestScore", 0)),
	})


func _start_new_round() -> void:
	if game == null or not game.started:
		return
	_round = game.flash_trainer_next_round()
	_last_result = {}
	_phase = "decide"
	_reveal_idx = 0
	_anim_accum = 0.0
	if not bool(_round.get("ok", false)):
		return
	_round_title.text = I18n.t("flash.maskedTitle", {
		"code": String(_round["mysteryCode"]),
		"price": SmaFormat.money(float(_round["entryPrice"])),
	})
	_action_box.visible = true
	_reveal_box.visible = false
	_chart.set_rr_plan({})
	_chart.set_price_lines([{"price": float(_round["entryPrice"]), "label": "ENTRY", "color": SmaUiTheme.GOLD}])
	_render_chart_slice(0)
	_update_stats_header()


func _render_chart_slice(future_count: int) -> void:
	var vis: Array = _round.get("visibleBars", [])
	var fut: Array = _round.get("futureBars", [])
	var combined: Array = vis.duplicate()
	for i in mini(future_count, fut.size()):
		combined.append(fut[i])
	_chart.visible_count = maxi(44, combined.size())
	var label := String(_round.get("mysteryCode", "MYSTERY"))
	if _phase == "done":
		label = "%s · %s (%s → %s)" % [
			String(_round["ticker"]), String(_round["companyName"]),
			String(_round["decisionDate"]), String(_round["endDate"]),
		]
	_chart.set_candles(combined, "1D", label)


func _choose(choice: String) -> void:
	if _phase != "decide" or _round.is_empty():
		return
	_last_result = game.flash_trainer_submit(_round, choice)
	_phase = "animating"
	_reveal_idx = 1
	_anim_accum = 0.0
	_action_box.visible = false
	_reveal_box.visible = true
	_skip_btn.visible = true
	_next_btn.visible = false
	_jump_btn.visible = false
	_verdict_label.text = I18n.t("flash.revealing")
	_verdict_label.add_theme_color_override("font_color", SmaUiTheme.ACCENT)
	_reveal_detail.text = ""
	_render_chart_slice(1)
	if DisplayServer.get_name() == "headless":
		_finish_reveal_now()


func _finish_reveal_now() -> void:
	if _round.is_empty():
		return
	_phase = "done"
	var fut: Array = _round.get("futureBars", [])
	_reveal_idx = fut.size()
	_render_chart_slice(fut.size())
	_skip_btn.visible = false
	_next_btn.visible = true
	_jump_btn.visible = true
	var tone := String(_last_result.get("tone", "neutral"))
	var col := SmaUiTheme.POSITIVE if tone == "win" else (SmaUiTheme.NEGATIVE if tone == "loss" else SmaUiTheme.GOLD)
	_verdict_label.text = "%s · %s (%+d pts · +%d XP)" % [
		I18n.t(String(_last_result.get("verdictKey", "flash.verdict.passChop"))),
		SmaFormat.pct(float(_last_result.get("playerReturnPct", 0.0)), 2),
		int(_last_result.get("scoreDelta", 0)),
		int(_last_result.get("xp", 0)),
	]
	_verdict_label.add_theme_color_override("font_color", col)
	_reveal_detail.text = I18n.t("flash.revealMeta", {
		"ticker": String(_round["ticker"]),
		"name": String(_round["companyName"]),
		"date": String(_round["decisionDate"]),
		"rawRet": SmaFormat.pct(float(_round["rawReturnPct"]), 2),
		"maxUp": SmaFormat.pct(float(_round["maxUpPct"]), 1),
		"maxDn": SmaFormat.pct(float(_round["maxDownPct"]), 1),
	})
	_round_title.text = "%s · %s" % [String(_round["ticker"]), String(_round["companyName"])]
	_update_stats_header()
