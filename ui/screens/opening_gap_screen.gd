## A dedicated training screen. Only the current attempt's revealed quotes go
## into the chart, and the career account stays off this screen.
class_name SmaOpeningGapScreen
extends SmaScreen

const Stage := SmaOpeningGap.Stage
const STACK_WIDTH := 930.0
const EXIT_LABELS := {"unrecorded": "intro.exitUnrecorded", "triggered": "intro.exitTriggered",
	"notTriggered": "intro.exitNotTriggered"}

var _body: VBoxContainer
var _scroll: ScrollContainer
var _splits: Array[BoxContainer] = []
var _focus: Control
var _choice_group: ButtonGroup
var _reflection: LineEdit
var _exit_outcome: OptionButton
var _index := 0
var _stage := Stage.BRIEFING


func _build() -> void:
	_scroll = SmaKit.scroll()
	_scroll.follow_focus = true
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_scroll)
	_body = SmaKit.vbox(12)
	_scroll.add_child(_body)
	resized.connect(_update_columns)


func refresh(_reason: String = "") -> void:
	_render(capture_draft())


func capture_draft() -> Dictionary:
	if _choice_group != null:
		var chosen := _choice_group.get_pressed_button()
		if chosen != null:
			return {"index": _index, "stage": _stage, "action": chosen.get_meta("action")}
	if is_instance_valid(_reflection):
		return {"index": _index, "stage": _stage, "text": _reflection.text,
			"caret": _reflection.caret_column,
			"outcome": _exit_outcome.selected if is_instance_valid(_exit_outcome) else 0}
	return {}


func restore_draft(draft: Dictionary) -> void:
	_render(draft)


func _render(draft: Dictionary) -> void:
	if not built or not visible or not game.opening_gap_active:
		return
	_splits.clear()
	_focus = null
	_choice_group = null
	_reflection = null
	_exit_outcome = null
	SmaKit.clear_children(_body)
	var state: Dictionary = game.opening_gap
	var attempts: Array = state["attempts"]
	_index = attempts.size() - 1
	var attempt: Dictionary = attempts[_index]
	_stage = int(attempt["stage"])
	if draft.get("index") != _index or draft.get("stage") != _stage:
		draft = {}
	var account := SmaOpeningGap.snapshot(attempt)
	_add_header(account)
	var split := _columns(_body)
	_add_market(split, account)
	var card := _card(split)
	if _stage == Stage.OPEN:
		_add_decisions(card, state, attempt, account, draft.get("action", ""))
	elif _stage < Stage.CLOSED:
		_add_advance(card, state, account)
	elif _index == 0 and _stage == Stage.CLOSED:
		_add_review(card, state, draft)
	elif _index == 0:
		card.add_child(SmaKit.title(I18n.t("gap.compare"), 16))
		_add_text(card, I18n.t("gap.compareHint"))
		_focus = _action(card, "gap.startComparison", "compare")
	else:
		card.add_child(SmaKit.title(I18n.t("gap.comparisonTitle"), 16))
		var first := SmaOpeningGap.snapshot(attempts[0])
		_add_text(card, I18n.t("gap.comparison", {
			"pnl": _signed_money(account["pnl"] - first["pnl"]),
			"cash": _signed_money(account["trade"]["cash"] - first["trade"]["cash"]),
			"drawdown": SmaFormat.pct(account["drawdown"] - first["drawdown"]).trim_suffix("%"),
		}))
		_add_text(card, I18n.t("gap.comparisonHint"))
		_focus = _button(card, I18n.t("gap.back"), _back_to_dashboard, true)
	if _stage >= Stage.CLOSED or _index == 1:
		var comparing := _index == 1 and _stage == Stage.CLOSED
		var results: Control = _columns(_body) if comparing else _body
		_add_result(results, attempts[0], I18n.t("gap.firstAttempt"), state["exitRule"])
		if comparing:
			_add_result(results, attempt, I18n.t("gap.secondAttempt"), state["exitRule"])
	_focus_current.call_deferred()


func _focus_current() -> void:
	if is_visible_in_tree() and is_instance_valid(_focus) and _focus.is_visible_in_tree():
		_focus.grab_focus()


func _add_header(account: Dictionary) -> void:
	var header := SmaKit.flow(12)
	header.add_child(SmaKit.title(I18n.t("gap.title"), 24))
	_button(header, I18n.t("gap.back"), _back_to_dashboard)
	_button(header, "中 / EN", _toggle_language)
	_body.add_child(header)
	var brief := _card(_body)
	var points: Array = account["points"]
	var time := I18n.t("gap.premarket") if _stage == Stage.BRIEFING else String(points.back()["time"])
	_add_text(brief, I18n.t("gap.session", {"time": time, "attempt": _index + 1}), 12, SmaUiTheme.MUTED)
	_add_text(brief, I18n.t(account["headline"]), 17)
	_add_text(brief, I18n.t(account["briefing"]))
	var metrics := SmaKit.flow(12)
	for pair in [["header.equity", _money(account["equity"])],
			["header.cash", _money(account["trade"]["cash"])],
			["gap.drawdown", SmaFormat.pct_plain(account["drawdown"])],
			["gap.budget", SmaFormat.pct_plain(account["budget"], 0)]]:
		var column := SmaKit.vbox(2)
		column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		column.add_child(SmaKit.caption(I18n.t(pair[0])))
		column.add_child(SmaKit.label(pair[1], 16))
		metrics.add_child(column)
	brief.add_child(metrics)


func _add_market(parent: Control, account: Dictionary) -> void:
	var market := _card(parent)
	market.add_child(SmaKit.title(I18n.t("gap.quoteTitle", {"ticker": account["ticker"]}), 16))
	var points: Array = account["points"]
	var trade: Dictionary = account["trade"]
	var current: Dictionary = points.back()
	_add_text(market, I18n.t("gap.mark", {"price": _money(current["price_cents"]), "shares": trade["shares"]}))
	if _stage == Stage.OPEN:
		_add_text(market, I18n.t("gap.openQuotes", {"bid": _money(current["bid_cents"]),
			"ask": _money(current["ask_cents"]), "loss": _signed_money(account["overnight"])}))
	if points.size() > 1:
		var chart := SmaLineChart.new()
		chart.custom_minimum_size = Vector2(180, 150)
		var prices: Array = points.map(func(point): return float(point["price_cents"]) / 100.0)
		chart.set_series(prices, SmaUiTheme.ACCENT, "money", I18n.t("gap.previousClose"), current["time"])
		market.add_child(chart)
	for index in points.size():
		var point: Dictionary = points[index]
		_add_text(market, I18n.t("gap.markAt", {
			"time": I18n.t("gap.previousClose") if index == 0 else point["time"],
			"price": _money(point["price_cents"]), "equity": _money(account["equityPoints"][index]),
		}), 12, SmaUiTheme.MUTED)


func _add_advance(parent: VBoxContainer, state: Dictionary, account: Dictionary) -> void:
	if _stage == Stage.BRIEFING:
		parent.add_child(SmaKit.title(I18n.t("gap.beforeOpen"), 16))
		_add_text(parent, I18n.t("gap.trainingAccount"))
		_add_exit_rule(parent, state["exitRule"])
		_focus = _action(parent, "gap.open", "advance")
	else:
		parent.add_child(SmaKit.title(I18n.t("gap.receipt"), 16))
		var attempt: Dictionary = state["attempts"][_index]
		_add_execution(parent, account["trade"], attempt["action"])
		_focus = _action(parent, "gap.advanceIntraday" if _stage == Stage.DECIDED else "gap.advanceClose", "advance")


func _add_decisions(parent: VBoxContainer, state: Dictionary, attempt: Dictionary,
		account: Dictionary, selected: String) -> void:
	parent.add_child(SmaKit.title(I18n.t("gap.decide"), 16))
	_add_text(parent, I18n.t("gap.decideHint"))
	_add_exit_rule(parent, state["exitRule"])
	var choices := SmaKit.flow(8)
	parent.add_child(choices)
	var details := SmaKit.vbox(4)
	parent.add_child(details)
	var group := ButtonGroup.new()
	_choice_group = group
	var index := _index
	var confirm := _button(parent, I18n.t("gap.confirm"), func():
		var chosen := group.get_pressed_button()
		if chosen != null:
			game.apply_opening_gap(index, Stage.OPEN, "confirm", chosen.get_meta("action")), true)
	confirm.hide()
	var preview := func(action: String):
		SmaKit.clear_children(details)
		var order := SmaOpeningGap.preview(attempt, action)
		_add_execution(details, order, action)
		_add_text(details, I18n.t("gap.afterOrder", {"cash": _money(order["cash"]), "shares": order["shares"]}))
		confirm.show()
	for action in SmaOpeningGap.available_actions(state):
		var quantity: int = account["startingShares"] if action == "hold" else account["orderShares"]
		var button := _button(choices, I18n.t("gap.action.%s" % action, {"qty": quantity}), preview.bind(action))
		button.name = "Choice_%s" % action
		button.toggle_mode = true
		button.button_group = group
		button.set_meta("action", action)
		if action == selected:
			button.set_pressed_no_signal(true)
			preview.call(action)
			_focus = button
	confirm.name = "ConfirmDecision"
	if _focus == null:
		_focus = choices.get_child(0) as Control


func _add_review(parent: VBoxContainer, state: Dictionary, draft: Dictionary) -> void:
	parent.add_child(SmaKit.title(I18n.t("gap.review"), 16))
	_add_text(parent, I18n.t("gap.reviewHint"))
	_add_exit_rule(parent, state["exitRule"])
	var reflection := LineEdit.new()
	reflection.name = "Reflection"
	reflection.placeholder_text = I18n.t("gap.reflection")
	reflection.max_length = SmaOpeningGap.REVIEW_LIMIT
	reflection.text = draft.get("text", "")
	reflection.caret_column = draft.get("caret", 0)
	parent.add_child(reflection)
	_reflection = reflection
	var outcomes: OptionButton
	if state["exitRule"] != "":
		parent.add_child(SmaKit.caption(I18n.t("intro.exitCheck")))
		outcomes = OptionButton.new()
		outcomes.name = "ExitOutcome"
		for outcome in SmaOpeningGap.EXIT_OUTCOMES:
			outcomes.add_item(I18n.t(EXIT_LABELS[outcome]))
		outcomes.select(draft.get("outcome", 0))
		parent.add_child(outcomes)
		_exit_outcome = outcomes
	var submit := func():
		var outcome := "unrecorded" if outcomes == null else String(SmaOpeningGap.EXIT_OUTCOMES[outcomes.selected])
		game.apply_opening_gap(0, Stage.CLOSED, "review", reflection.text, outcome)
	var save := _button(parent, I18n.t("gap.saveReview"), submit, true)
	save.name = "SaveReflection"
	save.disabled = reflection.text.strip_edges().is_empty()
	reflection.text_changed.connect(func(value): save.disabled = value.strip_edges().is_empty())
	reflection.text_submitted.connect(func(value):
		if not value.strip_edges().is_empty():
			submit.call())
	_focus = reflection


func _add_result(parent: Control, attempt: Dictionary, title: String, exit_rule: String) -> void:
	var result := SmaOpeningGap.snapshot(attempt)
	var trade: Dictionary = result["trade"]
	var box := _card(parent)
	box.add_child(SmaKit.title(title, 16))
	_add_execution(box, trade, attempt["action"])
	_add_text(box, I18n.t("gap.closeMetrics", {"cash": _money(trade["cash"]), "shares": trade["shares"],
		"equity": _money(result["equity"]), "pnl": _signed_money(result["pnl"])}))
	_add_text(box, I18n.t("gap.riskResult", {"drawdown": SmaFormat.pct_plain(result["drawdown"]),
		"budget": SmaFormat.pct_plain(result["budget"], 0),
		"status": I18n.t("gap.overBudget" if result["exceeded"] else "gap.withinBudget"),
	}), 13, SmaUiTheme.NEGATIVE if result["exceeded"] else SmaUiTheme.POSITIVE)
	_add_text(box, I18n.t("gap.feedback.%s" % attempt["action"]), 12, SmaUiTheme.MUTED)
	if not String(attempt["reflection"]).is_empty():
		_add_text(box, I18n.t("gap.yourReview", {"text": attempt["reflection"]}))
		if not exit_rule.is_empty():
			_add_text(box, "%s %s" % [I18n.t("intro.exitCheck"), I18n.t(EXIT_LABELS[attempt["exitOutcome"]])])


func _add_execution(parent: Control, order: Dictionary, action: String) -> void:
	if action == "hold":
		_add_text(parent, I18n.t("gap.holdReceipt", {"shares": order["shares"], "fee": _money(order["fee"])}))
		return
	_add_text(parent, I18n.t("gap.orderReceipt", {
		"side": I18n.t("trade.%s" % action), "qty": order["quantity"], "price": _money(order["fill"]),
		"gross": _money(order["gross"]), "fee": _money(order["fee"]),
	}))


func _add_exit_rule(parent: Control, rule: String) -> void:
	if not rule.is_empty():
		_add_text(parent, I18n.t("gap.exitRule", {"text": rule}), 12, SmaUiTheme.MUTED)


func _columns(parent: Control) -> BoxContainer:
	var container := BoxContainer.new()
	container.vertical = size.x < STACK_WIDTH
	container.add_theme_constant_override("separation", 12)
	container.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(container)
	_splits.append(container)
	return container


func _update_columns() -> void:
	for container in _splits:
		container.vertical = size.x < STACK_WIDTH


func _card(parent: Control) -> VBoxContainer:
	var panel := SmaKit.card(14)
	panel.size_flags_vertical = SIZE_SHRINK_BEGIN
	parent.add_child(panel)
	var content := SmaKit.vbox(8)
	panel.add_child(content)
	return content


func _add_text(parent: Control, text: String, font_size: int = 13, color: Color = Color.TRANSPARENT) -> void:
	var label := SmaKit.label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)


func _action(parent: Control, key: String, event: String) -> Button:
	return _button(parent, I18n.t(key), game.apply_opening_gap.bind(_index, _stage, event), true)


func _button(parent: Control, text: String, callback: Callable, primary: bool = false) -> Button:
	var button := SmaKit.button(text, callback, primary)
	button.focus_mode = FOCUS_ALL
	parent.add_child(button)
	return button


func _back_to_dashboard() -> void:
	var main := get_tree().get_first_node_in_group("main") as SmaMain
	if main != null:
		main.navigate("dashboard")


func _toggle_language() -> void:
	var main := get_tree().get_first_node_in_group("main") as SmaMain
	if main != null:
		main._toggle_language()


func _money(cents: int) -> String:
	return SmaFormat.money(float(cents) / 100.0)


func _signed_money(cents: int) -> String:
	return SmaFormat.signed_money(float(cents) / 100.0)
