## Challenge mode: goal-based runs with explicit deadlines and risk rules, plus
## the deterministic Daily Same-Seed 10-Day Sprint & risk-adjusted leaderboard.
class_name SmaChallengesScreen
extends SmaScreen

var _body: VBoxContainer
var _daily_code_edit: LineEdit
var _pending_daily_code := ""


func _build() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var root := SmaKit.vbox(10)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var scroll := SmaKit.scroll()
	root.add_child(scroll)
	_body = SmaKit.vbox(12)
	scroll.add_child(_body)


func refresh(_reason: String = "") -> void:
	if not built:
		return
	if _daily_code_edit != null and is_instance_valid(_daily_code_edit):
		_pending_daily_code = _daily_code_edit.text
	SmaKit.clear_children(_body)
	_daily_code_edit = null
	if game == null or not game.started:
		return
	_render_header()
	_render_daily_sprint()
	_render_active()
	_render_grid()
	_body.add_child(SmaKit.muted(I18n.t("challenges.note"), 10))


func _render_header() -> void:
	var header := SmaKit.hbox(10)
	var titles := SmaKit.vbox(2)
	titles.add_child(SmaKit.label(I18n.t("challenges.title"), 20))
	var subtitle := SmaKit.muted(I18n.t("challenges.subtitle"), 12)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(subtitle)
	header.add_child(titles)
	header.add_child(SmaKit.hspacer())
	header.add_child(SmaKit.label(I18n.t("challenges.badge", {
		"done": SmaChallenges.completed_count(game.challenges),
		"total": SmaChallenges.DEFS.size(),
	}), 12, SmaUiTheme.ACCENT))
	_body.add_child(header)


func _render_daily_sprint() -> void:
	if _pending_daily_code.strip_edges() == "":
		_pending_daily_code = SmaDailyChallenge.today_code()

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel",
		SmaPixelArt.card_box(SmaUiTheme.PANEL_ALT, SmaUiTheme.GOLD, Color("#040811"), 12, false))
	var box := SmaKit.vbox(8)
	card.add_child(box)

	var head := SmaKit.hbox(8)
	head.add_child(SmaKit.icon_rect("challenges", Vector2(20, 20)))
	head.add_child(SmaKit.label(I18n.t("daily.title"), 16, SmaUiTheme.GOLD))
	head.add_child(SmaKit.hspacer())
	if game.daily_sprint_active:
		head.add_child(SmaKit.badge(
			I18n.t("daily.activeBadge", {"code": game.daily_sprint_code}),
			Color("#063322"), SmaUiTheme.POSITIVE))
	else:
		head.add_child(SmaKit.badge(
			I18n.t("daily.seedBadge", {"seed": SmaDailyChallenge.seed_for_code(_pending_daily_code)}),
			SmaUiTheme.PANEL, SmaUiTheme.ACCENT))
	box.add_child(head)

	var sub := SmaKit.muted(I18n.t("daily.subtitle"), 11)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(sub)

	if game.daily_sprint_active:
		var st: Dictionary = game.daily_sprint_status()
		var days_done := int(st.get("days", 0))
		var stats := SmaKit.hbox(22)
		stats.add_child(_metric_custom(I18n.t("daily.colProgress"),
			"%d / %d" % [days_done, SmaDailyChallenge.SPRINT_DAYS], SmaUiTheme.ACCENT))
		stats.add_child(_metric_custom(I18n.t("daily.colScore"),
			"%d · %s" % [int(st.get("score", 1000)), String(st.get("grade", "B"))], SmaUiTheme.GOLD))
		var ret := float(st.get("returnPct", 0.0))
		stats.add_child(_metric("challenges.metric.return", SmaFormat.pct(ret, 2), ret))
		var dd := float(st.get("maxDrawdownPct", 0.0))
		stats.add_child(_metric("challenges.metric.drawdownMax", SmaFormat.pct_plain(dd, 2), -dd))
		stats.add_child(_metric("challenges.metric.trades", str(int(st.get("trades", 0))), 0.0))
		box.add_child(stats)

		var bar := ProgressBar.new()
		bar.max_value = float(SmaDailyChallenge.SPRINT_DAYS)
		bar.value = float(mini(days_done, SmaDailyChallenge.SPRINT_DAYS))
		bar.show_percentage = false
		bar.custom_minimum_size.y = 8
		box.add_child(bar)

		var actions := SmaKit.hbox(8)
		actions.add_child(SmaKit.arcade_button(I18n.t("daily.goTrade"), "buy", _go_trade))
		var step_btn := SmaKit.button(I18n.t("daily.stepDay"), func():
			game.step_day()
			refresh())
		step_btn.disabled = days_done >= SmaDailyChallenge.SPRINT_DAYS
		actions.add_child(step_btn)
		actions.add_child(SmaKit.arcade_button(I18n.t("daily.settlePoster"), "amber", _settle_and_open_poster))
		actions.add_child(SmaKit.hspacer())
		actions.add_child(SmaKit.button(I18n.t("daily.exitBtn"), _exit_daily_sprint))
		box.add_child(actions)
	else:
		var controls := SmaKit.hbox(8)
		controls.add_child(SmaKit.label(I18n.t("daily.codeLabel"), 12, SmaUiTheme.MUTED))
		_daily_code_edit = LineEdit.new()
		_daily_code_edit.text = _pending_daily_code
		_daily_code_edit.custom_minimum_size.x = 160
		controls.add_child(_daily_code_edit)
		controls.add_child(SmaKit.button(I18n.t("daily.todayBtn"), func():
			_pending_daily_code = SmaDailyChallenge.today_code()
			if _daily_code_edit != null:
				_daily_code_edit.text = _pending_daily_code
			refresh()))
		controls.add_child(SmaKit.arcade_button(I18n.t("daily.startBtn"), "buy", _start_daily_sprint))
		controls.add_child(SmaKit.hspacer())
		controls.add_child(SmaKit.arcade_button(I18n.t("poster.openShort"), "amber", func():
			var m := get_tree().get_first_node_in_group("main")
			if m != null and m.has_method("open_poster"):
				m.open_poster()))
		box.add_child(controls)

	if not game.daily_records.is_empty():
		box.add_child(SmaKit.separator())
		box.add_child(SmaKit.label(I18n.t("daily.boardTitle"), 12, SmaUiTheme.GOLD))
		box.add_child(SmaKit.header_row(
			["daily.colCode", "daily.colGrade", "daily.colScore",
				"challenges.metric.return", "challenges.metric.drawdownMax",
				"challenges.metric.trades"],
			[1.2, 0.5, 0.8, 0.9, 0.9, 0.7],
			[HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT,
				HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT]
		))
		var top_list: Array = game.daily_records.slice(0, 5)
		for rec in top_list:
			var r_ret := float(rec.get("returnPct", 0.0))
			box.add_child(SmaKit.data_row(
				[String(rec.get("code", "")), String(rec.get("grade", "B")),
					str(int(rec.get("score", 0))), SmaFormat.pct(r_ret, 2),
					SmaFormat.pct_plain(float(rec.get("maxDrawdownPct", 0.0)), 2),
					str(int(rec.get("trades", 0)))],
				[1.2, 0.5, 0.8, 0.9, 0.9, 0.7],
				[SmaUiTheme.TEXT, SmaUiTheme.GOLD, SmaUiTheme.ACCENT,
					SmaKit.value_color(r_ret), SmaUiTheme.WARNING, SmaUiTheme.MUTED],
				[HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT,
					HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT]
			))
	_body.add_child(card)


func _start_daily_sprint() -> void:
	var code := _daily_code_edit.text if _daily_code_edit != null else _pending_daily_code
	_pending_daily_code = SmaDailyChallenge.sanitize_code(code)
	var res: Dictionary = game.start_daily_sprint(_pending_daily_code)
	if not bool(res.get("ok", false)):
		return
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("navigate"):
		main.navigate("challenges")
	else:
		refresh()


func _settle_and_open_poster() -> void:
	var res: Dictionary = game.record_daily_sprint()
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("open_poster"):
		main.open_poster(res)
	refresh()


func _exit_daily_sprint() -> void:
	var st: Dictionary = game.daily_sprint_status()
	if int(st.get("trades", 0)) > 0 or int(st.get("days", 0)) > 0:
		game.record_daily_sprint()
	game.exit_sandbox()
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("navigate"):
		main.navigate("challenges")
	else:
		refresh()


func _go_trade() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("navigate"):
		main.navigate("trade")


func _render_active() -> void:
	var data: Dictionary = game.challenge_progress()
	if data.is_empty():
		var card := SmaKit.card(14)
		var box := SmaKit.vbox(4)
		card.add_child(box)
		box.add_child(SmaKit.label(I18n.t("challenges.noActiveTitle"), 15))
		box.add_child(SmaKit.muted(I18n.t("challenges.noActiveText"), 12))
		_body.add_child(card)
		return
	var definition: Dictionary = data["definition"]
	var values: Dictionary = data["values"]
	var card := SmaKit.card(14)
	var box := SmaKit.vbox(8)
	card.add_child(box)
	var head := SmaKit.hbox(10)
	head.add_child(SmaKit.label(I18n.t(String(definition["titleKey"])), 16))
	head.add_child(SmaKit.hspacer())
	head.add_child(SmaKit.label(I18n.t("challenges.daysLeft", {
		"days": int(data["remaining"]),
	}), 12, SmaUiTheme.WARNING))
	box.add_child(head)

	var stats := SmaKit.hbox(22)
	stats.add_child(_metric("challenges.metric.return",
		SmaFormat.pct(float(values["return"]), 2), float(values["return"])))
	stats.add_child(_metric("challenges.metric.drawdownMax",
		SmaFormat.pct_plain(float(values["drawdownMax"]), 2), -float(values["drawdownMax"])))
	stats.add_child(_metric("challenges.metric.trades",
		SmaFormat.num(float(values["trades"]), 0), 0.0))
	stats.add_child(_metric("challenges.equityLabel",
		SmaFormat.money(float(values["equity"])), 0.0))
	box.add_child(stats)

	for check in data["checks"]:
		var kind := String(check["kind"])
		var done := bool(check["done"])
		var line := SmaKit.hbox(8)
		line.add_child(SmaKit.label("✓" if done else "○", 12,
			SmaUiTheme.POSITIVE if done else SmaUiTheme.DIM))
		var text := I18n.t("challenges.metric.%s" % kind)
		if float(check.get("target", 0.0)) > 0.0:
			var target_text := _format_value(kind, float(check["target"]))
			var current_text := _format_value(kind, float(check["current"]))
			text += " · " + I18n.t("challenges.progressValue", {
				"current": current_text, "target": target_text,
			})
		line.add_child(SmaKit.label(text, 12, SmaUiTheme.TEXT if done else SmaUiTheme.MUTED))
		box.add_child(line)

	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.value = float(data["doneCount"]) / float(maxi(1, int(data["totalChecks"]))) * 100.0
	bar.show_percentage = false
	bar.custom_minimum_size.y = 6
	box.add_child(bar)

	var actions := SmaKit.hbox(8)
	actions.add_child(SmaKit.button(I18n.t("challenges.abandon"), _abandon))
	actions.add_child(SmaKit.button(I18n.t("challenges.openPortfolio"), _go_portfolio))
	box.add_child(actions)
	_body.add_child(card)


func _metric(label_key: String, value: String, tone: float) -> VBoxContainer:
	var box := SmaKit.vbox(0)
	box.add_child(SmaKit.caption(I18n.t(label_key)))
	box.add_child(SmaKit.label(value, 14, SmaKit.value_color(tone) if tone != 0.0 else SmaUiTheme.TEXT))
	return box


func _metric_custom(caption_text: String, value: String, color: Color) -> VBoxContainer:
	var box := SmaKit.vbox(0)
	box.add_child(SmaKit.caption(caption_text))
	box.add_child(SmaKit.label(value, 14, color))
	return box


func _format_value(kind: String, value: float) -> String:
	if kind == "return":
		return SmaFormat.pct(value, 1)
	if kind == "drawdownMax" or kind == "cashRatio":
		return SmaFormat.pct_plain(value, 1)
	if kind in ["trades", "optionTrades", "futuresTrades", "etfTrades",
			"shortTrades", "dividends", "openPositions"]:
		return SmaFormat.num(value, 0)
	return I18n.t("challenges.yes") if value > 0.0 else I18n.t("challenges.no")


func _render_grid() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for definition in SmaChallenges.DEFS:
		grid.add_child(_challenge_card(definition))
	_body.add_child(grid)


func _challenge_card(definition: Dictionary) -> PanelContainer:
	var challenge_id := String(definition["id"])
	var completed: bool = game.challenges["completed"].has(challenge_id)
	var failed: bool = game.challenges["failed"].has(challenge_id)
	var active_id := String(game.challenges["active"].get("id", ""))
	var active := active_id == challenge_id
	var cur_day: int = int(game.get_day())
	var unlocked := SmaChallenges.is_unlocked(game.academy, definition, cur_day)
	var card := SmaKit.card(12)
	var box := SmaKit.vbox(6)
	card.add_child(box)

	var head := SmaKit.hbox(8)
	var titles := SmaKit.vbox(1)
	titles.add_child(SmaKit.label(I18n.t(String(definition["titleKey"])), 14))
	var description := SmaKit.muted(I18n.t(String(definition["descKey"])), 11)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(description)
	head.add_child(titles)
	head.add_child(SmaKit.hspacer())
	head.add_child(SmaKit.label("+%d XP" % int(definition["xp"]), 11, SmaUiTheme.ACCENT))
	box.add_child(head)

	for check in definition["checks"]:
		var kind := String(check["kind"])
		var label := I18n.t("challenges.metric.%s" % kind)
		if check.has("target"):
			label += " · " + I18n.t("challenges.progressValue", {
				"current": _format_value(kind, 0.0),
				"target": _format_value(kind, float(check["target"])),
			})
		box.add_child(SmaKit.muted("• " + label, 11))

	var footer := SmaKit.hbox(8)
	if completed:
		footer.add_child(SmaKit.label(I18n.t("challenges.completed"), 11, SmaUiTheme.POSITIVE))
	elif active:
		footer.add_child(SmaKit.label(I18n.t("challenges.inProgress"), 11, SmaUiTheme.WARNING))
	elif failed:
		footer.add_child(SmaKit.label(I18n.t("challenges.failed"), 11, SmaUiTheme.NEGATIVE))
	else:
		footer.add_child(SmaKit.muted(I18n.t("challenges.days", {
			"days": int(definition["days"]),
		}), 11))
	footer.add_child(SmaKit.hspacer())
	if not unlocked:
		var auto_day := SmaChallenges.unlock_day_for(challenge_id)
		var lock_txt := I18n.t("challenges.lockedDual", {
			"unit": I18n.t(String(SmaAcademy.unit(String(definition["unlockUnit"])).get("titleKey", ""))),
			"day": auto_day + 1,
		}) if auto_day > 0 else I18n.t("challenges.lockedByUnit", {
			"unit": SmaAcademy.unit(String(definition["unlockUnit"])).get("titleKey", ""),
		})
		footer.add_child(SmaKit.muted(lock_txt, 10))
		footer.add_child(SmaKit.button(I18n.t("challenges.goUnlock"), _go_academy))
	elif not active:
		footer.add_child(SmaKit.button(
			I18n.t("challenges.retry") if completed or failed else I18n.t("challenges.start"),
			_start.bind(challenge_id), true))
	box.add_child(footer)
	return card


func _start(challenge_id: String) -> void:
	game.start_challenge(challenge_id)
	refresh()


func _abandon() -> void:
	game.abandon_challenge()
	refresh()


func _go_portfolio() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("navigate"):
		main.navigate("portfolio")


func _go_academy() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("navigate"):
		main.navigate("academy")
