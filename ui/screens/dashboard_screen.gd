## Dashboard: learning focus, account snapshot, market pulse, first-stage path
## and recent activity. Read-only; every action navigates to another screen.
class_name SmaDashboardScreen
extends SmaScreen

var _body: VBoxContainer


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
	SmaKit.clear_children(_body)
	if game == null or not game.started:
		return
	_render_header()
	if not game.last_close_recap.is_empty():
		_body.add_child(_render_close_recap())
	var mkt_evt_card := SmaKit.build_market_event_card(game, func(): refresh("market_event"))
	if mkt_evt_card != null:
		_body.add_child(mkt_evt_card)
	_body.add_child(_render_objective())
	_body.add_child(_render_rivals())
	if game.has_intro_task():
		_body.add_child(_render_intro())
	elif game.opening_gap_unlocked():
		_body.add_child(_render_opening_gap())
	if game.black_friday_unlocked():
		_body.add_child(_render_black_friday())
	var columns := SmaKit.hbox(12)
	var learning := _render_learning()
	learning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(learning)
	var portfolio := _render_portfolio()
	portfolio.custom_minimum_size.x = 360
	columns.add_child(portfolio)
	_body.add_child(columns)
	var pulse := SmaKit.hbox(12)
	var market := _render_market_pulse()
	market.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pulse.add_child(market)
	var path := _render_path()
	path.custom_minimum_size.x = 380
	pulse.add_child(path)
	_body.add_child(pulse)
	_render_activity()
	var bottom := SmaKit.hbox(12)
	var corporate := _render_corporate()
	corporate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(corporate)
	var review := _render_review()
	review.custom_minimum_size.x = 420
	bottom.add_child(review)
	_body.add_child(bottom)
	if not game.intro.is_empty() and not game.has_intro_task():
		_body.add_child(_render_intro())


func _render_header() -> void:
	var hour := int(Time.get_datetime_dict_from_system().get("hour", 9))
	var greeting_key := "dashboard.greetingMorning"
	if hour >= 18:
		greeting_key = "dashboard.greetingEvening"
	elif hour >= 12:
		greeting_key = "dashboard.greetingAfternoon"
	var header := SmaKit.hbox(10)
	var title_box := SmaKit.vbox(0)
	title_box.add_child(SmaKit.caption(I18n.t("dashboard.eyebrow")))
	title_box.add_child(SmaKit.label("%s · %s" % [
		I18n.t(greeting_key), game.display_player_name()], 22))
	title_box.add_child(SmaKit.muted(SmaCalendar.iso_date(game.get_day()), 12))
	header.add_child(title_box)
	header.add_child(SmaKit.hspacer())
	var bsum: Dictionary = game.quant_bots_summary()
	if int(bsum.get("count", 0)) > 0:
		var bpnl := float(bsum.get("totalPnl", 0.0))
		var bbtn := SmaKit.button(I18n.t("bots.dashboardChip", {
			"active": int(bsum.get("activeCount", 0)),
			"pnl": SmaFormat.signed_money(bpnl),
		}), func():
			var m := get_tree().get_first_node_in_group("main")
			if m != null and m.has_method("navigate"):
				m.navigate("quant"))
		header.add_child(bbtn)
	header.add_child(SmaKit.arcade_button(I18n.t("flash.quickBtn"), "amber", func():
		var m := get_tree().get_first_node_in_group("main")
		if m != null and m.has_method("navigate"):
			m.navigate("flash_trainer")))
	header.add_child(SmaKit.button(I18n.t("dashboard.openAcademy"),
		_go_academy, true))
	_body.add_child(header)


func _render_close_recap() -> Control:
	var r: Dictionary = game.last_close_recap
	var card := PanelContainer.new()
	var border_col := SmaUiTheme.GOLD if SmaUiTheme.is_pixel() else SmaUiTheme.ACCENT
	card.add_theme_stylebox_override("panel",
		SmaUiTheme.panel_style(SmaUiTheme.PANEL_ALT, border_col, 10, false))
	var row := SmaKit.hbox(12)
	card.add_child(row)
	var pnl := float(r.get("pnl", 0.0))
	var pct := float(r.get("pnlPct", 0.0))
	row.add_child(SmaKit.label(I18n.t("recap.title", {
		"date": String(r.get("date", "")),
	}), 13, SmaUiTheme.GOLD))
	row.add_child(SmaKit.label("%s (%s)" % [
		SmaFormat.signed_money(pnl), SmaFormat.pct(pct),
	], 13, SmaKit.value_color(pnl)))
	if bool(r.get("hasBook", false)):
		var b_tk := String(r.get("bestTicker", ""))
		var w_tk := String(r.get("worstTicker", ""))
		if b_tk != "":
			row.add_child(SmaKit.label(I18n.t("recap.best", {
				"ticker": b_tk, "pnl": SmaFormat.signed_money(float(r.get("bestPnl", 0.0))),
			}), 12, SmaKit.value_color(float(r.get("bestPnl", 0.0)))))
		if w_tk != "" and w_tk != b_tk:
			row.add_child(SmaKit.label(I18n.t("recap.worst", {
				"ticker": w_tk, "pnl": SmaFormat.signed_money(float(r.get("worstPnl", 0.0))),
			}), 12, SmaKit.value_color(float(r.get("worstPnl", 0.0)))))
	else:
		row.add_child(SmaKit.muted(I18n.t("recap.flatBook"), 11))
	var divs := float(r.get("dividends", 0.0))
	if divs > 0.0:
		row.add_child(SmaKit.label(I18n.t("recap.dividend", {
			"amount": SmaFormat.money(divs),
		}), 11, SmaUiTheme.POSITIVE))
	row.add_child(SmaKit.hspacer())
	var now_r := int(r.get("rank", 1))
	var prev_r := int(r.get("prevRank", now_r))
	var delta_txt := "▲" if now_r < prev_r else ("▼" if now_r > prev_r else "•")
	row.add_child(SmaKit.label(I18n.t("recap.rankBadge", {
		"rank": now_r, "delta": delta_txt,
	}), 12, SmaUiTheme.ACCENT))
	return card


func _render_objective() -> Control:
	var obj: Dictionary = game.current_objective()
	var card := SmaKit.card(12)
	var box := SmaKit.vbox(6)
	card.add_child(box)
	var head := SmaKit.hbox(8)
	head.add_child(SmaKit.label(I18n.t(String(obj.get("actKey", "objective.act1"))),
		11, SmaUiTheme.ACCENT))
	head.add_child(SmaKit.label(String(obj.get("title", "")), 15))
	head.add_child(SmaKit.hspacer())
	var target_screen := String(obj.get("target", "academy"))
	var jump := SmaKit.button(String(obj.get("button", I18n.t("objective.goAcademy"))), func():
		var main := get_tree().get_first_node_in_group("main") as SmaMain
		if main != null:
			main.navigate(target_screen), true)
	jump.disabled = (target_screen in ["opening_gap", "black_friday"]) \
		and (game.is_story_paused() or game.is_fast_forwarding())
	head.add_child(jump)
	box.add_child(head)
	_add_intro_text(box, String(obj.get("detail", "")))
	var path_hint := String(obj.get("pathHint", ""))
	if path_hint != "":
		var hint_lbl := SmaKit.caption(path_hint)
		hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(hint_lbl)
	var ch: Dictionary = obj.get("challenge", {})
	if bool(ch.get("active", false)):
		var def: Dictionary = ch.get("definition", {})
		box.add_child(SmaKit.label(I18n.t("objective.activeChallenge", {
			"name": I18n.t(String(def.get("titleKey", ""))),
			"days": int(ch.get("daysLeft", 0)),
		}), 12, SmaUiTheme.INFO))
	return card


func _seat_next_unlock_text(day: int) -> String:
	if day < 2:
		return I18n.t("rivals.nextUnlock.day2", {"left": 2 - day})
	if day < 4:
		return I18n.t("rivals.nextUnlock.day4", {"left": 4 - day})
	if day < 6:
		return I18n.t("rivals.nextUnlock.day6", {"left": 6 - day})
	if day < 8:
		return I18n.t("rivals.nextUnlock.day8", {"left": 8 - day})
	if day < 12:
		return I18n.t("rivals.nextUnlock.day12", {"left": 12 - day})
	return I18n.t("rivals.nextUnlock.allOpen")


func _render_rivals() -> Control:
	var card := SmaKit.card(12)
	var box := SmaKit.vbox(8)
	card.add_child(box)
	var head := SmaKit.hbox(8)
	head.add_child(SmaKit.label(I18n.t("rivals.title"), 15, SmaUiTheme.ACCENT))
	head.add_child(SmaKit.muted(I18n.t("rivals.subtitle"), 11))
	head.add_child(SmaKit.hspacer())
	head.add_child(SmaKit.label(_seat_next_unlock_text(game.get_day()), 11, SmaUiTheme.INFO))
	box.add_child(head)

	var board: Array = game.rival_leaderboard()
	var featured_quote := ""
	var featured_speaker := ""
	var featured_color := SmaUiTheme.MUTED
	for entry in board:
		var is_player := bool(entry.get("isPlayer", false))
		var rank := int(entry.get("rank", 1))
		var row_panel := PanelContainer.new()
		var border_col := SmaUiTheme.ACCENT if is_player else SmaUiTheme.BORDER
		row_panel.add_theme_stylebox_override("panel",
			SmaUiTheme.panel_style(SmaUiTheme.PANEL_ALT, border_col, 6, false))
		var row := SmaKit.hbox(10)
		row_panel.add_child(row)

		var rank_col := SmaUiTheme.WARNING if rank == 1 else (
			SmaUiTheme.ACCENT if is_player else SmaUiTheme.MUTED)
		var rank_lbl := SmaKit.label("#%d" % rank, 14, rank_col)
		rank_lbl.custom_minimum_size.x = 28
		row.add_child(rank_lbl)

		if not is_player:
			var portrait_path := String(entry.get("portrait", ""))
			if SmaUiTheme.is_pixel():
				var px := String(entry.get("pixelPortrait", ""))
				if px != "" and ResourceLoader.exists(px):
					portrait_path = px
			if portrait_path != "" and ResourceLoader.exists(portrait_path):
				var tex := load(portrait_path) as Texture2D
				if tex != null:
					var rect := TextureRect.new()
					rect.texture = tex
					rect.custom_minimum_size = Vector2(30, 40)
					rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST \
						if SmaUiTheme.is_pixel() else CanvasItem.TEXTURE_FILTER_LINEAR
					row.add_child(rect)
		else:
			var you_icon := SmaKit.label("★", 16, SmaUiTheme.WARNING)
			you_icon.custom_minimum_size = Vector2(30, 36)
			you_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			you_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(you_icon)

		var name_col := SmaUiTheme.ACCENT
		var hex := String(entry.get("color", ""))
		if hex != "" and Color.html_is_valid(hex):
			name_col = Color.html(hex)
		var trader_name: String = String(game.display_player_name()) if is_player \
			else I18n.t(String(entry.get("nameKey", "")))
		var meta_box := SmaKit.vbox(1)
		meta_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_row := SmaKit.hbox(6)
		name_row.add_child(SmaKit.label(trader_name, 13, name_col))
		name_row.add_child(SmaKit.muted("· %s" % I18n.t(String(entry.get("styleKey", ""))), 11))
		var status_key := String(entry.get("statusKey", ""))
		if status_key != "" and I18n.has_key(status_key):
			var st_col := SmaKit.value_color(-1.0) if bool(entry.get("marginCalled", false)) \
				else (SmaUiTheme.WARNING if rank == 1 else SmaUiTheme.MUTED)
			name_row.add_child(SmaKit.label("[%s]" % I18n.t(status_key), 10, st_col))
		meta_box.add_child(name_row)

		var holdings: Array = entry.get("holdings", [])
		var hold_text := I18n.t("rivals.cashOnly") if holdings.is_empty() \
			else I18n.t("rivals.holdingsPrefix", {"tickers": " · ".join(holdings)})
		meta_box.add_child(SmaKit.caption(hold_text))
		row.add_child(meta_box)

		if not is_player and not holdings.is_empty():
			var first_ticker := String(holdings[0]).trim_prefix("-")
			var peek_btn := SmaKit.button(first_ticker, func():
				var main := get_tree().get_first_node_in_group("main")
				if main != null and main.has_method("open_ticker"):
					main.open_ticker(first_ticker))
			SmaKit.set_small_font(peek_btn, 10)
			row.add_child(peek_btn)

		var ret_pct := float(entry.get("returnPct", 0.0))
		var today_pct := float(entry.get("todayPct", 0.0))
		var stats_box := SmaKit.vbox(1)
		stats_box.custom_minimum_size.x = 150
		var eq_lbl := SmaKit.label(SmaFormat.money(float(entry.get("equity", 0.0))), 13)
		eq_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stats_box.add_child(eq_lbl)
		var ret_lbl := SmaKit.label("%s (%s)" % [
			SmaFormat.pct(ret_pct),
			I18n.t("rivals.todayTag", {"pct": SmaFormat.pct(today_pct)}),
		], 11, SmaKit.value_color(ret_pct))
		ret_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stats_box.add_child(ret_lbl)
		row.add_child(stats_box)
		box.add_child(row_panel)

		if not is_player and (featured_quote == "" or String(entry.get("id", "")) == "gu_yan"):
			var qk := String(entry.get("quoteKey", ""))
			if qk != "" and I18n.has_key(qk):
				featured_speaker = trader_name
				featured_quote = I18n.t(qk)
				featured_color = name_col

	if featured_quote != "":
		var quote_row := SmaKit.hbox(6)
		quote_row.add_child(SmaKit.label("%s:" % featured_speaker, 11, featured_color))
		var q_lbl := SmaKit.muted(featured_quote, 11)
		q_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		q_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quote_row.add_child(q_lbl)
		box.add_child(quote_row)
	return card


func _render_black_friday() -> Control:
	var card := SmaKit.card(14)
	var content := SmaKit.vbox(8)
	card.add_child(content)
	content.add_child(SmaKit.title(I18n.t("bf.title"), 19))
	_add_intro_text(content, I18n.t("bf.dashboardHint"))
	var state: Dictionary = game.black_friday
	var label := "bf.start"
	if not state.is_empty():
		var attempts: Array = state["attempts"]
		var last: Dictionary = attempts.back()
		label = "bf.resume"
		if int(last["stage"]) == SmaBlackFriday.Stage.REVIEWED or (attempts.size() == 2 \
				and int(last["stage"]) == SmaBlackFriday.Stage.CLOSED):
			label = "bf.viewResults"
	var actions := SmaKit.flow(8)
	var button := SmaKit.button(I18n.t(label), func():
		var main := get_tree().get_first_node_in_group("main") as SmaMain
		if main != null:
			main.navigate("black_friday"), true)
	button.name = "BlackFridayEntry"
	button.focus_mode = Control.FOCUS_ALL
	button.disabled = game.is_story_paused() or game.is_fast_forwarding()
	actions.add_child(button)
	content.add_child(actions)
	return card


func _render_opening_gap() -> Control:
	var card := SmaKit.card(14)
	var content := SmaKit.vbox(8)
	card.add_child(content)
	content.add_child(SmaKit.title(I18n.t("gap.title"), 19))
	_add_intro_text(content, I18n.t("gap.dashboardHint"))
	var state: Dictionary = game.opening_gap
	var label := "gap.start"
	if not state.is_empty():
		var attempts: Array = state["attempts"]
		var last: Dictionary = attempts.back()
		label = "gap.resume"
		if last["stage"] == SmaOpeningGap.Stage.REVIEWED or (attempts.size() == 2 \
				and last["stage"] == SmaOpeningGap.Stage.CLOSED):
			label = "gap.viewResults"
	var actions := SmaKit.flow(8)
	var button := SmaKit.button(I18n.t(label), func():
		var main := get_tree().get_first_node_in_group("main") as SmaMain
		if main != null:
			main.navigate("opening_gap"), true)
	button.name = "OpeningGapEntry"
	button.focus_mode = Control.FOCUS_ALL
	button.disabled = game.is_story_paused() or game.is_fast_forwarding()
	actions.add_child(button)
	content.add_child(actions)
	return card


func _render_intro() -> Control:
	var card := SmaKit.card(14)
	var box := SmaKit.vbox(8)
	card.add_child(box)
	var receipt: Dictionary = game.intro["receipt"]
	var plan: Dictionary = game.intro["plan"]
	var review: Dictionary = game.intro["review"]
	var complete := bool(game.intro["complete"])
	var title := "intro.firstOrder" if receipt.is_empty() else (
		"intro.firstFill" if review.is_empty() else (
			"intro.completed" if complete else "intro.closeReview"))
	box.add_child(SmaKit.label(I18n.t(title), 19))
	if receipt.is_empty():
		_add_intro_text(box, I18n.t("intro.firstOrderHint"))
	else:
		_add_intro_text(box, I18n.t("intro.receipt", {
			"ticker": receipt["ticker"], "side": I18n.t("trade.%s" % receipt["side"]),
			"qty": SmaFormat.quantity(float(receipt["qty"])),
			"price": SmaFormat.money(float(receipt["price"])),
			"fee": SmaFormat.money(float(receipt["fee"])),
			"weight": SmaFormat.pct_plain(float(receipt["weight"]), 1),
		}))
	if not plan.is_empty():
		_add_intro_text(box, I18n.t("intro.planSummary", {
			"reason": plan["reason"], "exit": plan["exitRule"],
			"loss": SmaFormat.money(float(plan["maxLoss"])),
		}))
	if not review.is_empty():
		_add_intro_text(box, I18n.t("intro.closeStats", {
			"date": SmaCalendar.iso_date(int(review["day"])),
			"equity": SmaFormat.money(float(review["equity"])),
			"cash": SmaFormat.pct_plain(float(review["cashPct"]), 1),
			"fees": SmaFormat.money(float(review["fees"])),
		}))
		_add_intro_text(box, I18n.t("intro.cashMet" if bool(review["cashTargetMet"])
			else "intro.cashBelow"))
		if review.has("firstTradePnl"):
			var pnl := float(review["firstTradePnl"])
			_add_intro_text(box, I18n.t("intro.closePnl", {"pnl": SmaFormat.signed_money(pnl)}))
			if not plan.is_empty():
				var budget := float(plan["maxLoss"])
				_add_intro_text(box, I18n.t("intro.riskBudgetMet" if pnl >= -budget \
					else "intro.riskBudgetExceeded", {"budget": SmaFormat.money(budget)}))
		var feedback := "intro.noPlan" if plan.is_empty() else (
			"intro.beforeFill" if bool(plan["beforeFill"]) else "intro.afterFill")
		_add_intro_text(box, I18n.t(feedback))
		if not plan.is_empty():
			var exit_row := SmaKit.flow(8)
			exit_row.add_child(SmaKit.muted(I18n.t("intro.exitCheck")))
			var outcomes := ["unrecorded", "triggered", "notTriggered"]
			var labels := ["intro.exitUnrecorded", "intro.exitTriggered", "intro.exitNotTriggered"]
			var selected := maxi(0, outcomes.find(String(review.get("exitOutcome", "unrecorded"))))
			if complete:
				exit_row.add_child(SmaKit.label(I18n.t(labels[selected])))
			else:
				var picker := OptionButton.new()
				for label in labels:
					picker.add_item(I18n.t(label))
				picker.select(selected)
				picker.item_selected.connect(func(index): game.set_intro_exit_outcome(outcomes[index]))
				exit_row.add_child(picker)
			box.add_child(exit_row)
	var actions := SmaKit.hbox(8)
	if receipt.is_empty():
		actions.add_child(SmaKit.button(I18n.t("intro.openTrade"), _open_intro_trade, true))
	elif review.is_empty():
		actions.add_child(SmaKit.button(I18n.t("intro.advanceClose"), game.step_day, true))
	elif not complete:
		actions.add_child(SmaKit.button(I18n.t("intro.finishReview"), game.finish_intro_review, true))
	if review.is_empty() and (receipt.is_empty() or not bool(plan.get("beforeFill", false))):
		actions.add_child(SmaKit.button(I18n.t("intro.openPlan"), _edit_intro_plan))
	if actions.get_child_count() > 0:
		box.add_child(actions)
	else:
		actions.free()
	return card


func _add_intro_text(box: VBoxContainer, text: String) -> void:
	var label := SmaKit.muted(text, 13)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)


func _open_intro_trade() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("open_ticker"):
		main.open_ticker(game.INTRO_TICKER)


func _edit_intro_plan() -> void:
	var plan: Dictionary = game.intro["plan"]
	var dialog := ConfirmationDialog.new()
	dialog.title = I18n.t("intro.planTitle")
	dialog.ok_button_text = I18n.t("intro.savePlan")
	dialog.get_cancel_button().text = I18n.t("start.cancel")
	var form := SmaKit.vbox(8)
	form.custom_minimum_size.x = 470
	dialog.add_child(form)
	var reason := LineEdit.new()
	reason.max_length = 180
	reason.text = String(plan.get("reason", ""))
	form.add_child(SmaKit.label(I18n.t("intro.reason")))
	form.add_child(reason)
	var exit_rule := LineEdit.new()
	exit_rule.max_length = 180
	exit_rule.text = String(plan.get("exitRule", ""))
	form.add_child(SmaKit.label(I18n.t("intro.exitRule")))
	form.add_child(exit_rule)
	var max_loss := SpinBox.new()
	max_loss.max_value = 10000000.0
	max_loss.step = 0.01
	max_loss.prefix = "$"
	max_loss.value = float(plan.get("maxLoss", 0.0))
	form.add_child(SmaKit.label(I18n.t("intro.maxLoss")))
	form.add_child(max_loss)
	var update_button := func():
		dialog.get_ok_button().disabled = reason.text.strip_edges().is_empty() \
			or exit_rule.text.strip_edges().is_empty() or max_loss.value <= 0.0
	reason.text_changed.connect(func(_value): update_button.call())
	exit_rule.text_changed.connect(func(_value): update_button.call())
	max_loss.value_changed.connect(func(_value): update_button.call())
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(func():
		game.set_intro_plan(reason.text, exit_rule.text, max_loss.value)
		dialog.queue_free())
	add_child(dialog)
	update_button.call()
	dialog.popup_centered()
	reason.grab_focus()


func _current_unit() -> Dictionary:
	for entry in SmaAcademy.units():
		if bool(entry.get("optional", false)):
			continue
		var unit_id := String(entry["id"])
		if not SmaAcademy.is_unit_unlocked(game.academy, unit_id):
			continue
		if SmaAcademy.is_unit_complete(game.academy, unit_id):
			continue
		return entry
	return {}


func _render_learning() -> PanelContainer:
	var card := SmaKit.card(14)
	var box := SmaKit.vbox(6)
	card.add_child(box)
	box.add_child(SmaKit.caption(I18n.t("dashboard.continueEyebrow")))
	var entry := _current_unit()
	if entry.is_empty():
		box.add_child(SmaKit.label(I18n.t("dashboard.stageCompleteTitle"), 20))
		var text := SmaKit.muted(I18n.t("dashboard.stageCompleteText"), 12)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(text)
		box.add_child(SmaKit.button(I18n.t("dashboard.reviewAcademy"), _go_academy, true))
		return card
	var progress := SmaAcademy.progress_rows(game.academy, entry)
	var unit_id := String(entry["id"])
	box.add_child(SmaKit.label(I18n.t("dashboard.unitPill", {
		"number": entry.get("number", 0)}), 11, SmaUiTheme.ACCENT))
	box.add_child(SmaKit.label(I18n.t(String(entry["titleKey"])), 20))
	var summary := SmaKit.muted(I18n.t(String(entry["summaryKey"])), 12)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(summary)
	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.value = float(progress["pct"])
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	box.add_child(bar)
	box.add_child(SmaKit.muted(I18n.t("dashboard.sectionsRead", {
		"read": progress["read"], "total": progress["total"]}), 11))
	var actions := SmaKit.hbox(6)
	actions.add_child(SmaKit.button(I18n.t("dashboard.resumeLesson"),
		_open_unit.bind(unit_id), true))
	actions.add_child(SmaKit.button(I18n.t("dashboard.openAcademy"), _go_academy))
	box.add_child(actions)
	return card


func _render_portfolio() -> PanelContainer:
	var card := SmaKit.card(14)
	var box := SmaKit.vbox(5)
	card.add_child(box)
	box.add_child(SmaKit.caption(I18n.t("dashboard.portfolioEyebrow")))
	box.add_child(SmaKit.label(SmaFormat.money(game.get_equity()), 26))
	var initial := 100000.0
	if game.exchange != null:
		initial = float(game.exchange.state["account"].get("initialCash", initial))
	var ret: float = (game.get_equity() / initial - 1.0) * 100.0 if initial > 0.0 else 0.0
	box.add_child(SmaKit.label("%s %s" % [SmaFormat.pct(ret, 2),
		I18n.t("dashboard.sinceStart")], 12, SmaKit.value_color(ret)))
	var cash := 0.0
	var positions := 0
	if game.exchange != null:
		cash = float(game.exchange.state["account"]["cash"])
		positions = game.exchange.state["account"]["positions"].size()
	box.add_child(SmaKit.muted(I18n.t("dashboard.cashLine", {
		"value": SmaFormat.money(cash)}), 11))
	box.add_child(SmaKit.muted(I18n.t("dashboard.positionsLine", {
		"value": positions}), 11))
	box.add_child(SmaKit.button(I18n.t("nav.portfolio"), _go_portfolio))
	return card


func _render_market_pulse() -> PanelContainer:
	var card := SmaKit.card(12)
	var box := SmaKit.vbox(5)
	card.add_child(box)
	box.add_child(SmaKit.label(I18n.t("dashboard.marketPulse"), 15))
	box.add_child(SmaKit.muted(I18n.t("dashboard.marketPulseSubtitle"), 11))
	var index_row := SmaKit.hbox(8)
	index_row.add_child(SmaKit.caption(I18n.t("dashboard.indexLabel")))
	index_row.add_child(SmaKit.hspacer())
	index_row.add_child(SmaKit.label(SmaFormat.num(game.market_index(), 2), 16))
	index_row.add_child(SmaKit.label(SmaFormat.pct(game.market_index_change(), 2), 12,
		SmaKit.value_color(game.market_index_change())))
	box.add_child(index_row)
	var movers: Array = []
	if game.exchange != null:
		for ticker in game.exchange.state["companies"].keys():
			var cs: Dictionary = game.exchange.state["companies"][ticker]
			var last := float(cs.get("last", 0.0))
			var previous := float(cs.get("prevClose", last))
			var change := (last / previous - 1.0) * 100.0 if previous > 0.0 else 0.0
			movers.append({"ticker": String(ticker), "last": last, "change": change,
				"name": String(cs.get("company", {}).get("name", ticker))})
	movers.sort_custom(func(a, b): return float(a["change"]) > float(b["change"]))
	box.add_child(SmaKit.caption(I18n.t("dashboard.gainers")))
	for row in movers.slice(0, 2):
		box.add_child(_mover_row(row))
	box.add_child(SmaKit.caption(I18n.t("dashboard.losers")))
	var losers: Array = movers.slice(maxi(0, movers.size() - 2), movers.size())
	losers.reverse()
	for row in losers:
		box.add_child(_mover_row(row))
	box.add_child(SmaKit.button(I18n.t("nav.market"), _go_market))
	return card


func _mover_row(row: Dictionary) -> HBoxContainer:
	var line := SmaKit.hbox(6)
	line.add_child(SmaKit.label(String(row["ticker"]), 12))
	line.add_child(SmaKit.muted(String(row["name"]), 10))
	line.add_child(SmaKit.hspacer())
	line.add_child(SmaKit.label(SmaFormat.money(float(row["last"])), 11))
	line.add_child(SmaKit.label(SmaFormat.pct(float(row["change"]), 2), 11,
		SmaKit.value_color(float(row["change"]))))
	return line


func _render_path() -> PanelContainer:
	var card := SmaKit.card(12)
	var box := SmaKit.vbox(5)
	card.add_child(box)
	box.add_child(SmaKit.label(I18n.t("dashboard.pathTitle"), 15))
	box.add_child(SmaKit.muted(I18n.t("dashboard.pathSubtitle"), 11))
	for unit_id in ["u1", "u2", "u3", "u4"]:
		var entry := SmaAcademy.unit(unit_id)
		var progress := SmaAcademy.progress_rows(game.academy, entry)
		var line := SmaKit.hbox(6)
		line.add_child(SmaKit.caption("%02d" % int(entry.get("number", 0))))
		var title := SmaKit.label(I18n.t(String(entry["titleKey"])), 11,
			SmaUiTheme.TEXT if SmaAcademy.is_unit_complete(game.academy, unit_id) \
				else SmaUiTheme.MUTED)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(title)
		line.add_child(SmaKit.caption("%d / %d" % [
			int(progress["read"]), int(progress["total"])]))
		box.add_child(line)
	box.add_child(SmaKit.button(I18n.t("nav.academy"), _go_academy))
	return card


func _render_activity() -> void:
	var card := SmaKit.card(12)
	var box := SmaKit.vbox(5)
	card.add_child(box)
	box.add_child(SmaKit.label(I18n.t("dashboard.activityTitle"), 15))
	box.add_child(SmaKit.muted(I18n.t("dashboard.activitySubtitle"), 11))
	var trades: Array = []
	if game.exchange != null:
		trades = game.exchange.state["account"].get("trades", [])
	if trades.is_empty():
		box.add_child(SmaKit.muted(I18n.t("dashboard.noTradesTitle"), 12))
		_body.add_child(card)
		return
	for index in mini(4, trades.size()):
		var trade: Dictionary = trades[index]
		var line := SmaKit.hbox(8)
		line.add_child(SmaKit.caption(String(trade.get("side", "")).to_upper()))
		line.add_child(SmaKit.label(String(trade.get("ticker", "")), 12))
		line.add_child(SmaKit.muted(I18n.t("dashboard.tradeMeta", {
			"qty": SmaFormat.num(float(trade.get("qty", 0)), 0),
			"price": SmaFormat.money(float(trade.get("price", 0.0)))}), 11))
		box.add_child(line)
	_body.add_child(card)


func _go_academy() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main != null:
		main.navigate("academy")


func _render_corporate() -> PanelContainer:
	var card := SmaKit.card(12)
	var box := SmaKit.vbox(5)
	card.add_child(box)
	box.add_child(SmaKit.label(I18n.t("dashboard.corporateTitle"), 15))
	box.add_child(SmaKit.muted(I18n.t("dashboard.corporateSubtitle"), 11))
	var offerings: Array = game.rights_offerings()
	for offering in offerings:
		var line := SmaKit.vbox(2)
		var text := SmaKit.muted(I18n.t("dashboard.rightsTerms", {
			"ticker": String(offering["ticker"]),
			"ratio": SmaFormat.num(float(offering["ratio"]) * 100.0, 0),
			"price": SmaFormat.money(float(offering["price"])),
			"deadline": SmaCalendar.iso_date(int(offering["deadlineDay"])),
		}), 11)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(text)
		var actions := SmaKit.hbox(6)
		actions.add_child(SmaKit.button(I18n.t("dashboard.subscribe"),
			_subscribe_rights.bind(String(offering["id"])), true))
		actions.add_child(SmaKit.button(I18n.t("dashboard.decline"),
			_decline_rights.bind(String(offering["id"]))))
		line.add_child(actions)
		box.add_child(line)
	var actions_rows: Array = game.corporate_actions(6)
	if actions_rows.is_empty():
		box.add_child(SmaKit.muted(I18n.t("dashboard.noCorporate"), 11))
	for action in actions_rows:
		var kind := String(action.get("type", ""))
		var line := SmaKit.hbox(6)
		line.add_child(SmaKit.label(I18n.t("corporate.type.%s" % kind), 11,
			SmaUiTheme.ACCENT))
		line.add_child(SmaKit.label(String(action.get("ticker", "")), 11))
		line.add_child(SmaKit.hspacer())
		if action.has("ratio"):
			line.add_child(SmaKit.muted("×" + SmaFormat.num(float(action["ratio"]), 2), 10))
		if action.has("dps"):
			line.add_child(SmaKit.muted(SmaFormat.money(float(action["dps"])), 10))
		line.add_child(SmaKit.caption(SmaCalendar.iso_date(int(action.get("day", 0)))))
		box.add_child(line)
	return card


func _subscribe_rights(offering_id: String) -> void:
	game.subscribe_rights(offering_id)
	refresh()


func _decline_rights(offering_id: String) -> void:
	game.decline_rights(offering_id)
	refresh()


func _render_review() -> PanelContainer:
	var summary: Dictionary = game.review_summary()
	var card := SmaKit.card(12)
	var box := SmaKit.vbox(5)
	card.add_child(box)
	box.add_child(SmaKit.label(I18n.t("dashboard.reviewTitle"), 15))
	box.add_child(SmaKit.muted(I18n.t("dashboard.reviewSubtitle"), 11))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 3)
	for spec in [
		["dashboard.winRate", SmaFormat.pct_plain(float(summary.get("winRatePct", 0.0)), 1)],
		["dashboard.profitFactor", SmaFormat.num(float(summary.get("profitFactor", 0.0)), 2)],
		["dashboard.realized", SmaFormat.signed_money(float(summary.get("realizedPnl", 0.0)))],
		["dashboard.dividends", SmaFormat.money(float(summary.get("dividends", 0.0)))],
		["dashboard.concentration", SmaFormat.pct_plain(float(
			summary.get("concentrationPct", 0.0)), 1)],
	]:
		var stat := SmaKit.vbox(0)
		stat.add_child(SmaKit.caption(I18n.t(String(spec[0]))))
		stat.add_child(SmaKit.label(String(spec[1]), 13))
		grid.add_child(stat)
	box.add_child(grid)
	box.add_child(SmaKit.separator())
	var timeline: Array = game.review_timeline(6)
	if timeline.is_empty():
		box.add_child(SmaKit.muted(I18n.t("dashboard.noTimeline"), 11))
	for row in timeline:
		var kind := String(row.get("kind", ""))
		var side := String(row.get("side", ""))
		var line := SmaKit.hbox(6)
		line.add_child(SmaKit.caption(SmaCalendar.iso_date(int(row.get("day", 0)))))
		line.add_child(SmaKit.label(I18n.t("review.kind.%s" % kind), 10,
			SmaUiTheme.MUTED))
		line.add_child(SmaKit.label(String(row.get("ticker", "")), 11))
		line.add_child(SmaKit.hspacer())
		line.add_child(SmaKit.muted(_side_text(kind, side), 10))
		line.add_child(SmaKit.label(SmaFormat.money(float(row.get("amount", 0.0))), 10))
		box.add_child(line)
	return card


func _side_text(kind: String, side: String) -> String:
	if kind == "dividend":
		return ""
	if kind == "futures":
		return I18n.t("futures.open" if side == "open" else "futures.close")
	if kind == "option":
		return I18n.t("trade.%s" % side) if I18n.has_key("trade.%s" % side) else side
	var key := "trade.%s" % side
	return I18n.t(key) if I18n.has_key(key) else side


func _open_unit(unit_id: String) -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main == null:
		return
	main.navigate("academy")
	if main._screens.has("academy"):
		main._screens["academy"]._select_unit(unit_id)


func _go_portfolio() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main != null:
		main.navigate("portfolio")


func _go_market() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main != null:
		main.navigate("market")
