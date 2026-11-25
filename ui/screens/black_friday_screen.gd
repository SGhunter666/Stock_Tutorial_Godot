## Dedicated playable Black Friday fund liquidity-crisis campaign screen.
## Reuses the same safe stage-machine UX as SmaOpeningGapScreen: step-by-step
## checkpoints (09:30 & 11:00), live liquidity haircut preview, client call
## reaction, written reflection, and same-path counterfactual comparison.
class_name SmaBlackFridayScreen
extends SmaScreen

const Stage := SmaBlackFriday.Stage
const STACK_WIDTH := 930.0

var _body: VBoxContainer
var _scroll: ScrollContainer
var _splits: Array[BoxContainer] = []
var _focus: Control
var _choice_group: ButtonGroup
var _reflection: LineEdit
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
			"caret": _reflection.caret_column}
	return {}


func restore_draft(draft: Dictionary) -> void:
	_render(draft)


func _render(draft: Dictionary) -> void:
	if not built or not visible or not game.black_friday_active:
		return
	_splits.clear()
	_focus = null
	_choice_group = null
	_reflection = null
	SmaKit.clear_children(_body)
	var state: Dictionary = game.black_friday
	if state.is_empty():
		return
	var attempts: Array = state["attempts"]
	_index = attempts.size() - 1
	var attempt: Dictionary = attempts[_index]
	_stage = int(attempt["stage"])
	if draft.get("index") != _index or draft.get("stage") != _stage:
		draft = {}
	var snap := SmaBlackFriday.snapshot(attempt)
	_add_header(state, snap)
	var split := _columns(_body)
	_add_book(split, state, snap)
	var card := _card(split)
	if _stage == Stage.OPEN_0930 or _stage == Stage.CRUNCH_1100:
		_add_decisions(card, state, attempt, snap, String(draft.get("action", "")))
	elif _stage < Stage.CLOSED:
		_add_advance(card, state, attempt, snap)
	elif _index == 0 and _stage == Stage.CLOSED:
		_add_review(card, snap, draft)
	elif _index == 0:
		card.add_child(SmaKit.title(I18n.t("bf.compare"), 16))
		_add_text(card, I18n.t("bf.compareHint"))
		_focus = _action(card, "bf.startComparison", "compare")
	else:
		card.add_child(SmaKit.title(I18n.t("bf.comparisonTitle"), 16))
		var first := SmaBlackFriday.snapshot(attempts[0])
		_add_text(card, I18n.t("bf.comparison", {
			"nav": SmaFormat.pct(float(snap["navReturnPct"]) - float(first["navReturnPct"])),
			"haircut": _signed_money(int(snap["haircutCents"]) - int(first["haircutCents"])),
			"coverage": SmaFormat.pct(float(snap["coveragePct"]) - float(first["coveragePct"])),
		}))
		_add_text(card, I18n.t("bf.comparisonHint"))
		_focus = _button(card, I18n.t("bf.back"), _back_to_dashboard, true)
	if _stage >= Stage.CLOSED or _index == 1:
		var comparing := _index == 1 and _stage == Stage.CLOSED
		var results: Control = _columns(_body) if comparing else _body
		_add_result(results, attempts[0], I18n.t("bf.firstAttempt"))
		if comparing:
			_add_result(results, attempt, I18n.t("bf.secondAttempt"))
	_focus_current.call_deferred()


func _focus_current() -> void:
	if is_visible_in_tree() and is_instance_valid(_focus) and _focus.is_visible_in_tree():
		_focus.grab_focus()


func _add_header(state: Dictionary, snap: Dictionary) -> void:
	var header := SmaKit.flow(12)
	header.add_child(SmaKit.title(I18n.t("bf.title"), 24))
	_button(header, I18n.t("bf.back"), _back_to_dashboard)
	_button(header, "中 / EN", _toggle_language)
	_body.add_child(header)
	var brief := _card(_body)
	var points: Array = snap["points"]
	var time_label := I18n.t("bf.premarket") if _stage == Stage.BRIEFING else String(points.back()["time"])
	_add_text(brief, I18n.t("bf.session", {"time": time_label, "attempt": _index + 1}),
		12, SmaUiTheme.MUTED)
	_add_text(brief, I18n.t("bf.headline"), 17, SmaUiTheme.WARNING)
	_add_text(brief, I18n.t("bf.briefing"))
	var trust_key := "bf.wangCall.%s" % String(state.get("clientTrust", "high"))
	if _stage >= Stage.CRUNCH_1100:
		_add_text(brief, I18n.t(trust_key), 13, SmaUiTheme.INFO)
	var metrics := SmaKit.flow(16)
	for pair in [
		["bf.nav", "%.4f (%s)" % [float(snap["nav"]), SmaFormat.pct(float(snap["navReturnPct"]))]],
		["bf.aum", _money(int(snap["aum"]))],
		["bf.cash", _money(int(snap["cash"]))],
		["bf.coverage", SmaFormat.pct_plain(float(snap["coveragePct"]), 0)],
		["bf.haircut", _money(int(snap["haircutCents"]))],
		["bf.drawdown", SmaFormat.pct_plain(float(snap["maxDrawdown"]), 1)],
	]:
		var col := SmaKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		col.add_child(SmaKit.caption(I18n.t(pair[0])))
		col.add_child(SmaKit.label(pair[1], 15))
		metrics.add_child(col)
	brief.add_child(metrics)


func _add_book(parent: Control, _state: Dictionary, snap: Dictionary) -> void:
	var card := _card(parent)
	card.add_child(SmaKit.title(I18n.t("bf.bookTitle"), 16))
	var points: Array = snap["points"]
	var current: Dictionary = points.back()
	_add_text(card, I18n.t("bf.bookHoldings", {
		"liquid": SmaFormat.quantity(float(snap["liquidShares"])),
		"liquidPrice": _money(int(current["liquid_cents"])),
		"illiquid": SmaFormat.quantity(float(snap["illiquidShares"])),
		"illiquidPrice": _money(int(current["illiquid_cents"])),
	}))
	if _stage == Stage.OPEN_0930 or _stage == Stage.CRUNCH_1100:
		_add_text(card, I18n.t("bf.bidAsk", {
			"bid": _money(int(current.get("liquid_bid_cents", current["liquid_cents"]))),
			"ask": _money(int(current.get("liquid_ask_cents", current["liquid_cents"]))),
			"unpaid": _money(int(snap["unpaidCents"])),
		}), 12, SmaUiTheme.WARNING)
	var nav_points: Array = snap["navPoints"]
	if nav_points.size() > 1:
		var chart := SmaLineChart.new()
		chart.custom_minimum_size = Vector2(180, 150)
		chart.set_series(nav_points, SmaUiTheme.NEGATIVE if float(snap["nav"]) < 1.0 else SmaUiTheme.POSITIVE,
			"number", I18n.t("gap.previousClose"), String(current["time"]))
		card.add_child(chart)
	for i in points.size():
		var p: Dictionary = points[i]
		_add_text(card, I18n.t("bf.markAt", {
			"time": I18n.t("gap.previousClose") if i == 0 else String(p["time"]),
			"liquid": _money(int(p["liquid_cents"])),
			"nav": "%.4f" % float(nav_points[i]),
		}), 12, SmaUiTheme.MUTED)


func _add_advance(parent: VBoxContainer, _state: Dictionary, attempt: Dictionary,
		snap: Dictionary) -> void:
	if _stage == Stage.BRIEFING:
		parent.add_child(SmaKit.title(I18n.t("bf.beforeOpen"), 16))
		_add_text(parent, I18n.t("bf.setupSummary"))
		_focus = _action(parent, "bf.open0930", "advance")
	elif _stage == Stage.AFTER_0930:
		parent.add_child(SmaKit.title(I18n.t("bf.receipt0930"), 16))
		_add_receipt(parent, snap["openReceipt"], String(attempt["openAction"]))
		_focus = _action(parent, "bf.advance1100", "advance")
	else:
		parent.add_child(SmaKit.title(I18n.t("bf.receipt1100"), 16))
		_add_receipt(parent, snap["crunchReceipt"], String(attempt["crunchAction"]))
		_focus = _action(parent, "bf.advanceClose", "advance")


func _add_decisions(parent: VBoxContainer, state: Dictionary, attempt: Dictionary,
		_snap: Dictionary, selected: String) -> void:
	var is_open := _stage == Stage.OPEN_0930
	parent.add_child(SmaKit.title(I18n.t("bf.decide0930" if is_open else "bf.decide1100"), 16))
	_add_text(parent, I18n.t("bf.decideHint0930" if is_open else "bf.decideHint1100"))
	var choices := SmaKit.flow(8)
	parent.add_child(choices)
	var details := SmaKit.vbox(4)
	parent.add_child(details)
	var group := ButtonGroup.new()
	_choice_group = group
	var index := _index
	var stage_now := _stage
	var event_name := "confirm_open" if is_open else "confirm_crunch"
	var confirm := _button(parent, I18n.t("bf.confirm"), func():
		var chosen := group.get_pressed_button()
		if chosen != null:
			game.apply_black_friday(index, stage_now, event_name, String(chosen.get_meta("action"))), true)
	confirm.hide()
	var preview_fn := func(action: String):
		SmaKit.clear_children(details)
		var simulated := SmaBlackFriday.preview(attempt, action)
		var receipt: Dictionary = simulated["openReceipt"] if is_open else simulated["crunchReceipt"]
		_add_receipt(details, receipt, action)
		_add_text(details, I18n.t("bf.afterDecision", {
			"cash": _money(int(simulated["cash"])),
			"coverage": SmaFormat.pct_plain(float(simulated["coveragePct"]), 0),
			"nav": "%.4f" % float(simulated["nav"]),
		}))
		confirm.show()
	for action in SmaBlackFriday.available_actions(state, stage_now):
		var button := _button(choices, I18n.t("bf.action.%s" % action), preview_fn.bind(action))
		button.name = "BfChoice_%s" % action
		button.toggle_mode = true
		button.button_group = group
		button.set_meta("action", action)
		if action == selected:
			button.set_pressed_no_signal(true)
			preview_fn.call(action)
	if not choices.get_children().is_empty():
		_focus = choices.get_child(0) as Control


func _add_receipt(parent: VBoxContainer, receipt: Dictionary, action: String) -> void:
	_add_text(parent, I18n.t("bf.actionDesc.%s" % action))
	if receipt.is_empty():
		return
	var sold := int(receipt.get("sold", 0))
	var bought := int(receipt.get("bought", 0))
	if sold > 0:
		_add_text(parent, I18n.t("bf.soldLine", {
			"qty": SmaFormat.quantity(float(sold)),
			"price": _money(int(receipt["fill"])),
			"haircut": _money(int(receipt["haircut"])),
			"honored": _money(int(receipt["honored"])),
		}), 12, SmaUiTheme.MUTED)
	elif bought > 0:
		_add_text(parent, I18n.t("bf.boughtLine", {
			"qty": SmaFormat.quantity(float(bought)),
			"price": _money(int(receipt["fill"])),
			"fee": _money(int(receipt["fee"])),
		}), 12, SmaUiTheme.MUTED)
	else:
		_add_text(parent, I18n.t("bf.gatedLine", {
			"wave": _money(int(receipt.get("wave", 0))),
		}), 12, SmaUiTheme.WARNING)


func _add_review(parent: VBoxContainer, snap: Dictionary, draft: Dictionary) -> void:
	parent.add_child(SmaKit.title(I18n.t("bf.reviewTitle"), 16))
	_add_text(parent, I18n.t("bf.outcome.%s" % String(snap["crisisChoice"])), 13,
		SmaUiTheme.POSITIVE if String(snap["crisisChoice"]) == "protect" else SmaUiTheme.WARNING)
	_add_text(parent, I18n.t("bf.reviewPrompt"))
	var input := LineEdit.new()
	input.name = "BfReflectionInput"
	input.max_length = SmaBlackFriday.REVIEW_LIMIT
	input.placeholder_text = I18n.t("bf.reflectionPlaceholder")
	input.text = String(draft.get("text", ""))
	input.caret_column = mini(int(draft.get("caret", input.text.length())), input.text.length())
	parent.add_child(input)
	_reflection = input
	var submit := _button(parent, I18n.t("bf.submitReview"), func():
		game.apply_black_friday(0, Stage.CLOSED, "review", input.text), true)
	submit.name = "BfReviewSubmit"
	submit.disabled = input.text.strip_edges().is_empty()
	input.text_changed.connect(func(text: String): submit.disabled = text.strip_edges().is_empty())
	_focus = input


func _add_result(parent: Control, attempt: Dictionary, heading: String) -> void:
	var snap := SmaBlackFriday.snapshot(attempt)
	var card := _card(parent)
	card.add_child(SmaKit.title(heading, 16))
	_add_text(card, I18n.t("bf.resultActions", {
		"open": I18n.t("bf.action.%s" % String(attempt.get("openAction", "protect"))),
		"crunch": I18n.t("bf.action.%s" % String(attempt.get("crunchAction", "protect"))),
	}))
	_add_text(card, I18n.t("bf.resultStats", {
		"nav": "%.4f (%s)" % [float(snap["nav"]), SmaFormat.pct(float(snap["navReturnPct"]))],
		"coverage": SmaFormat.pct_plain(float(snap["coveragePct"]), 0),
		"haircut": _money(int(snap["haircutCents"])),
		"drawdown": SmaFormat.pct_plain(float(snap["maxDrawdown"]), 1),
		"trust": I18n.t("bf.trust.%s" % String(snap["trustOutcome"])),
	}), 12, SmaUiTheme.MUTED)
	if not String(attempt.get("reflection", "")).is_empty():
		_add_text(card, I18n.t("bf.savedReflection", {"text": String(attempt["reflection"])}))


func _action(parent: VBoxContainer, label_key: String, event: String) -> Button:
	var index := _index
	var stage_now := _stage
	return _button(parent, I18n.t(label_key), func():
		game.apply_black_friday(index, stage_now, event), true)


func _button(parent: Control, label: String, handler: Callable, primary: bool = false) -> Button:
	var button := SmaKit.button(label, handler, primary)
	button.focus_mode = Control.FOCUS_ALL
	parent.add_child(button)
	return button


func _card(parent: Control) -> VBoxContainer:
	var card := SmaKit.card(14)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := SmaKit.vbox(8)
	card.add_child(content)
	parent.add_child(card)
	return content


func _columns(parent: Control) -> BoxContainer:
	var box := BoxContainer.new()
	box.vertical = size.x > 0.0 and size.x < STACK_WIDTH
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	_splits.append(box)
	return box


func _update_columns() -> void:
	var stacked := size.x > 0.0 and size.x < STACK_WIDTH
	for box in _splits:
		if is_instance_valid(box):
			box.vertical = stacked


func _add_text(parent: Control, text: String, font_size: int = 13,
		color: Color = SmaUiTheme.TEXT) -> void:
	var label := SmaKit.label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)


func _money(cents: int) -> String:
	return SmaFormat.money(float(cents) / 100.0)


func _signed_money(cents: int) -> String:
	return SmaFormat.signed_money(float(cents) / 100.0)


func _back_to_dashboard() -> void:
	var main := get_tree().get_first_node_in_group("main") as SmaMain
	if main != null:
		main.navigate("dashboard")


func _toggle_language() -> void:
	I18n.toggle()
