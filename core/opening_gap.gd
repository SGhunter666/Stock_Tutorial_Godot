## Fixed training account with a versioned price path. The saved decisions and
## stages are enough to reconstruct every balance and receipt without replaying orders.
class_name SmaOpeningGap
extends RefCounted

enum Stage { BRIEFING, OPEN, DECIDED, INTRADAY, CLOSED, REVIEWED }

const SCENARIO_PATH := "res://data/scenarios/opening_gap.json"
const ACTIONS := ["sell", "hold", "buy"]
const EXIT_OUTCOMES := ["unrecorded", "triggered", "notTriggered"]
const REVIEW_LIMIT := 400

static var _scenario: Dictionary = {}


static func _data() -> Dictionary:
	if _scenario.is_empty() and FileAccess.file_exists(SCENARIO_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCENARIO_PATH))
		if parsed is Dictionary and parsed.get("id") == "opening_gap":
			_scenario = parsed
	return _scenario


static func _new_attempt() -> Dictionary:
	return {"stage": Stage.BRIEFING, "action": "", "reflection": "", "exitOutcome": "unrecorded"}


static func start(exit_rule: String) -> Dictionary:
	var data := _data()
	if data.is_empty():
		return {}
	return {"id": data["id"], "version": data["version"], "exitRule": exit_rule.strip_edges(),
		"attempts": [_new_attempt()]}


static func is_valid(state: Dictionary) -> bool:
	if state.is_empty():
		return true
	var data := _data()
	if data.is_empty() or state.get("id") != data["id"] or state.get("version") != data["version"] \
			or not state.get("exitRule") is String or not state.get("attempts") is Array:
		return false
	var attempts: Array = state["attempts"]
	if attempts.is_empty() or attempts.size() > 2:
		return false
	for attempt in attempts:
		if not attempt is Dictionary or not _valid_attempt(attempt, state["exitRule"]):
			return false
	return attempts.size() == 1 or (attempts[0]["stage"] == Stage.REVIEWED \
		and attempts[1]["stage"] != Stage.REVIEWED and attempts[1]["action"] != attempts[0]["action"])


static func _valid_attempt(attempt: Dictionary, exit_rule: String) -> bool:
	var saved_stage: Variant = attempt.get("stage")
	if not (saved_stage is int or saved_stage is float) or not attempt.get("action") is String \
			or not attempt.get("reflection") is String or not attempt.get("exitOutcome") is String:
		return false
	if not is_finite(float(saved_stage)) or saved_stage < Stage.BRIEFING or saved_stage > Stage.REVIEWED:
		return false
	var phase := int(saved_stage)
	if phase != saved_stage:
		return false
	var action: String = attempt["action"]
	if (phase < Stage.DECIDED and action != "") or (phase >= Stage.DECIDED and not action in ACTIONS):
		return false
	var reflection: String = attempt["reflection"]
	var outcome: String = attempt["exitOutcome"]
	if phase == Stage.REVIEWED:
		return not reflection.strip_edges().is_empty() and reflection.length() <= REVIEW_LIMIT \
			and outcome in EXIT_OUTCOMES and (exit_rule != "" or outcome == "unrecorded")
	return reflection.is_empty() and outcome == "unrecorded"


static func is_complete(state: Dictionary) -> bool:
	return not state.is_empty() and state["attempts"][0]["stage"] == Stage.REVIEWED


static func available_actions(state: Dictionary) -> Array:
	var actions := ACTIONS.duplicate()
	if state["attempts"].size() == 2:
		actions.erase(state["attempts"][0]["action"])
	return actions


## A click belongs to one stage and attempt. Discard delayed or repeated clicks
## before they can run a second transition.
static func transition(state: Dictionary, index: int, stage: int, event: String,
		value: String = "", outcome: String = "unrecorded") -> Dictionary:
	if state.is_empty():
		return {}
	var attempts: Array = state["attempts"]
	if index != attempts.size() - 1 or stage != attempts[index]["stage"]:
		return {}
	var next := state.duplicate(true)
	var attempt: Dictionary = next["attempts"][index]
	match event:
		"advance":
			if stage not in [Stage.BRIEFING, Stage.DECIDED, Stage.INTRADAY]:
				return {}
			attempt["stage"] = stage + 1
		"confirm":
			if stage != Stage.OPEN or not value in available_actions(state):
				return {}
			attempt["action"] = value
			attempt["stage"] = Stage.DECIDED
		"review":
			var reflection := value.strip_edges()
			if index != 0 or stage != Stage.CLOSED or reflection.is_empty() \
					or reflection.length() > REVIEW_LIMIT or not outcome in EXIT_OUTCOMES \
					or (state["exitRule"] == "" and outcome != "unrecorded"):
				return {}
			attempt["reflection"] = reflection
			attempt["exitOutcome"] = outcome
			attempt["stage"] = Stage.REVIEWED
		"compare":
			if index != 0 or stage != Stage.REVIEWED:
				return {}
			next["attempts"].append(_new_attempt())
		_:
			return {}
	return next


static func _execution(action: String, data: Dictionary) -> Dictionary:
	var cash := int(data["cash_cents"])
	var shares := int(data["shares"])
	var price := 0
	var quantity := 0
	var fee := 0
	var open: Dictionary = data["points"][1]
	if action in ["buy", "sell"]:
		quantity = int(data["order_shares"])
		fee = int(data["fee_cents"])
		price = int(open["ask_cents"] if action == "buy" else open["bid_cents"])
		var change := quantity if action == "buy" else -quantity
		shares += change
		cash -= change * price + fee
	return {"cash": cash, "shares": shares, "fill": price, "fee": fee,
		"quantity": quantity, "gross": price * quantity}


static func snapshot(attempt: Dictionary) -> Dictionary:
	var data := _data()
	var stage := int(attempt["stage"])
	var all_points: Array = data["points"]
	var last_index := 0 if stage == Stage.BRIEFING else clampi(stage - 1, 1, 3)
	var points := all_points.slice(0, last_index + 1).duplicate(true)
	var start_equity := int(data["cash_cents"]) + int(data["shares"]) * int(points[0]["price_cents"])
	var trade := _execution(attempt["action"], data)
	var peak := start_equity
	var drawdown := 0.0
	var equity := start_equity
	var equity_points: Array[int] = [start_equity]
	var overnight := 0
	if last_index > 0:
		var open_equity := int(data["cash_cents"]) + int(data["shares"]) * int(points[1]["price_cents"])
		overnight = open_equity - start_equity
		peak = maxi(peak, open_equity)
		drawdown = 100.0 * float(peak - open_equity) / float(peak)
		for point in points.slice(1):
			equity = int(trade["cash"]) + int(trade["shares"]) * int(point["price_cents"])
			peak = maxi(peak, equity)
			drawdown = maxf(drawdown, 100.0 * float(peak - equity) / float(peak))
			equity_points.append(equity)
	var budget := float(data["drawdown_budget_pct"])
	return {
		"ticker": data["ticker"], "headline": data["headline"], "briefing": data["briefing"],
		"points": points, "equityPoints": equity_points, "orderShares": int(data["order_shares"]),
		"startingShares": int(data["shares"]), "trade": trade, "equity": equity,
		"pnl": equity - start_equity, "overnight": overnight, "drawdown": drawdown,
		"budget": budget, "exceeded": drawdown > budget,
	}


static func preview(attempt: Dictionary, action: String) -> Dictionary:
	if attempt["stage"] != Stage.OPEN or not action in ACTIONS:
		return {}
	return _execution(action, _data())
