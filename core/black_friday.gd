## Playable Black Friday fund liquidity-crisis campaign. Pure integer-cents
## state machine modeled on SmaOpeningGap: deterministic, resumable at every
## checkpoint, and supports a counterfactual comparison attempt on the same path.
class_name SmaBlackFriday
extends RefCounted

enum Stage { BRIEFING, OPEN_0930, AFTER_0930, CRUNCH_1100, AFTER_1100, CLOSED, REVIEWED }

const SCENARIO_PATH := "res://data/scenarios/black_friday.json"
const ACTIONS := ["protect", "attack", "gate"]
const REVIEW_LIMIT := 400

static var _scenario: Dictionary = {}


static func _data() -> Dictionary:
	if _scenario.is_empty() and FileAccess.file_exists(SCENARIO_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCENARIO_PATH))
		if parsed is Dictionary and parsed.get("id") == "black_friday":
			_scenario = parsed
	return _scenario


static func _new_attempt() -> Dictionary:
	return {
		"stage": Stage.BRIEFING,
		"openAction": "",
		"crunchAction": "",
		"reflection": "",
	}


static func start(client_trust: String = "high") -> Dictionary:
	var data := _data()
	if data.is_empty():
		return {}
	var trust := client_trust if client_trust in ["high", "low"] else "high"
	return {
		"id": data["id"],
		"version": data["version"],
		"clientTrust": trust,
		"attempts": [_new_attempt()],
	}


static func is_valid(state: Dictionary) -> bool:
	if state.is_empty():
		return true
	var data := _data()
	if data.is_empty() or state.get("id") != data["id"] or state.get("version") != data["version"] \
			or not (state.get("clientTrust") is String) or not (state.get("attempts") is Array):
		return false
	var attempts: Array = state["attempts"]
	if attempts.is_empty() or attempts.size() > 2:
		return false
	for attempt in attempts:
		if not (attempt is Dictionary) or not _valid_attempt(attempt):
			return false
	return attempts.size() == 1 or (int(attempts[0]["stage"]) == Stage.REVIEWED \
		and int(attempts[1]["stage"]) != Stage.REVIEWED)


static func _valid_attempt(attempt: Dictionary) -> bool:
	var saved_stage: Variant = attempt.get("stage")
	if not (saved_stage is int or saved_stage is float):
		return false
	if not (attempt.get("openAction") is String) or not (attempt.get("crunchAction") is String) \
			or not (attempt.get("reflection") is String):
		return false
	if not is_finite(float(saved_stage)) or saved_stage < Stage.BRIEFING or saved_stage > Stage.REVIEWED:
		return false
	var phase := int(saved_stage)
	if phase != saved_stage:
		return false
	var open_action := String(attempt["openAction"])
	var crunch_action := String(attempt["crunchAction"])
	if (phase < Stage.AFTER_0930 and open_action != "") \
			or (phase >= Stage.AFTER_0930 and not (open_action in ACTIONS)):
		return false
	if (phase < Stage.AFTER_1100 and crunch_action != "") \
			or (phase >= Stage.AFTER_1100 and not (crunch_action in ACTIONS)):
		return false
	var reflection := String(attempt["reflection"])
	if phase == Stage.REVIEWED:
		return not reflection.strip_edges().is_empty() and reflection.length() <= REVIEW_LIMIT
	return reflection.is_empty()


static func is_complete(state: Dictionary) -> bool:
	return not state.is_empty() and int(state["attempts"][0]["stage"]) == Stage.REVIEWED


static func available_actions(state: Dictionary, stage: int) -> Array:
	var actions := ACTIONS.duplicate()
	if state.get("attempts", []).size() == 2 and stage == Stage.OPEN_0930:
		actions.erase(String(state["attempts"][0].get("openAction", "")))
	return actions


static func transition(state: Dictionary, index: int, stage: int, event: String,
		value: String = "") -> Dictionary:
	if state.is_empty():
		return {}
	var attempts: Array = state["attempts"]
	if index != attempts.size() - 1 or stage != int(attempts[index]["stage"]):
		return {}
	var next := state.duplicate(true)
	var attempt: Dictionary = next["attempts"][index]
	match event:
		"advance":
			if stage not in [Stage.BRIEFING, Stage.AFTER_0930, Stage.AFTER_1100]:
				return {}
			attempt["stage"] = stage + 1
		"confirm_open":
			if stage != Stage.OPEN_0930 or not (value in available_actions(state, Stage.OPEN_0930)):
				return {}
			attempt["openAction"] = value
			attempt["stage"] = Stage.AFTER_0930
		"confirm_crunch":
			if stage != Stage.CRUNCH_1100 or not (value in ACTIONS):
				return {}
			attempt["crunchAction"] = value
			attempt["stage"] = Stage.AFTER_1100
		"review":
			var reflection := value.strip_edges()
			if index != 0 or stage != Stage.CLOSED or reflection.is_empty() \
					or reflection.length() > REVIEW_LIMIT:
				return {}
			attempt["reflection"] = reflection
			attempt["stage"] = Stage.REVIEWED
		"compare":
			if index != 0 or stage != Stage.REVIEWED or attempts.size() >= 2:
				return {}
			next["attempts"].append(_new_attempt())
		_:
			return {}
	return next


static func derive_crisis_choice(attempt: Dictionary) -> String:
	var open_action := String(attempt.get("openAction", ""))
	var crunch_action := String(attempt.get("crunchAction", ""))
	if open_action == "gate" or crunch_action == "gate":
		return "gate"
	if open_action == "attack" or crunch_action == "attack":
		return "attack"
	if open_action == "protect" or crunch_action == "protect":
		return "protect"
	return "protect"


static func _simulate_to(open_action: String, crunch_action: String, point_limit: int,
		data: Dictionary) -> Dictionary:
	var points: Array = data["points"]
	var blocks: Dictionary = data["trade_blocks"]
	var redemptions: Dictionary = data["redemptions"]
	var fee_cents := int(data["fee_cents"])
	var cash := int(data["cash_cents"])
	var liquid := int(data["liquid_shares"])
	var illiquid := int(data["illiquid_shares"])
	var units := int(data["total_units"])
	var start_aum := cash + liquid * int(points[0]["liquid_cents"]) + illiquid * int(points[0]["illiquid_cents"])
	var nav_points: Array[float] = [1.0]
	var aum_points: Array[int] = [start_aum]
	var haircut_cents := 0
	var fee_total_cents := 0
	var requested_cents := 0
	var honored_cents := 0
	var unpaid_cents := 0
	var gated := false
	var peak_nav := 1.0
	var max_drawdown := 0.0
	var open_receipt := {}
	var crunch_receipt := {}

	if point_limit >= 1:
		var p1: Dictionary = points[1]
		var wave1 := int(redemptions["open_cents"])
		requested_cents += wave1
		var sold_qty := 0
		var bought_qty := 0
		var fill_price := 0
		var step_haircut := 0
		var step_fee := 0
		var step_honored := 0
		if open_action == "protect":
			sold_qty = mini(liquid, int(blocks["open_sell_shares"]))
			fill_price = int(p1["liquid_bid_cents"])
			step_haircut = (int(p1["liquid_cents"]) - fill_price) * sold_qty
			step_fee = fee_cents
			liquid -= sold_qty
			cash += sold_qty * fill_price - step_fee
			haircut_cents += step_haircut
			fee_total_cents += step_fee
			step_honored = mini(cash, wave1)
			cash -= step_honored
			honored_cents += step_honored
			unpaid_cents += wave1 - step_honored
		elif open_action == "attack":
			# Counter-cyclical gamble deploys reserve cash plus short-term repo leverage.
			bought_qty = int(blocks["open_buy_shares"])
			fill_price = int(p1["liquid_ask_cents"])
			if bought_qty > 0:
				step_fee = fee_cents
				liquid += bought_qty
				cash -= bought_qty * fill_price + step_fee
				fee_total_cents += step_fee
			unpaid_cents += wave1
		elif open_action == "gate":
			gated = true
			unpaid_cents += wave1
		var pre_nav_aum := cash + liquid * int(p1["liquid_cents"]) + illiquid * int(p1["illiquid_cents"])
		var nav1 := _nav_after_payout(pre_nav_aum, units, step_honored, p1)
		if step_honored > 0 and nav1 > 0.0:
			var burned := int(round(float(step_honored) / (nav1 * 100.0)))
			units = maxi(1, units - burned)
		var post_aum1 := cash + liquid * int(p1["liquid_cents"]) + illiquid * int(p1["illiquid_cents"])
		var final_nav1 := float(post_aum1) / float(units * 100)
		peak_nav = maxf(peak_nav, final_nav1)
		max_drawdown = maxf(max_drawdown, (peak_nav - final_nav1) / peak_nav * 100.0)
		nav_points.append(final_nav1)
		aum_points.append(post_aum1)
		open_receipt = {
			"action": open_action, "sold": sold_qty, "bought": bought_qty,
			"fill": fill_price, "haircut": step_haircut, "fee": step_fee,
			"honored": step_honored, "wave": wave1,
		}

	if point_limit >= 2:
		var p2: Dictionary = points[2]
		var wave2 := int(redemptions["crunch_cents"])
		requested_cents += wave2
		var sold_qty2 := 0
		var bought_qty2 := 0
		var fill_price2 := 0
		var step_haircut2 := 0
		var step_fee2 := 0
		var step_honored2 := 0
		if crunch_action == "protect":
			sold_qty2 = mini(liquid, int(blocks["crunch_sell_shares"]))
			fill_price2 = int(p2["liquid_bid_cents"])
			step_haircut2 = (int(p2["liquid_cents"]) - fill_price2) * sold_qty2
			step_fee2 = fee_cents
			liquid -= sold_qty2
			cash += sold_qty2 * fill_price2 - step_fee2
			haircut_cents += step_haircut2
			fee_total_cents += step_fee2
			var due := wave2 + (unpaid_cents if not gated else 0)
			step_honored2 = mini(cash, due)
			cash -= step_honored2
			honored_cents += step_honored2
			unpaid_cents = maxi(0, requested_cents - honored_cents)
		elif crunch_action == "attack":
			bought_qty2 = int(blocks["crunch_buy_shares"])
			fill_price2 = int(p2["liquid_ask_cents"])
			if bought_qty2 > 0:
				step_fee2 = fee_cents
				liquid += bought_qty2
				cash -= bought_qty2 * fill_price2 + step_fee2
				fee_total_cents += step_fee2
			unpaid_cents = maxi(0, requested_cents - honored_cents)
		elif crunch_action == "gate":
			gated = true
			unpaid_cents = maxi(0, requested_cents - honored_cents)
		var pre_nav_aum2 := cash + liquid * int(p2["liquid_cents"]) + illiquid * int(p2["illiquid_cents"])
		var nav2 := _nav_after_payout(pre_nav_aum2, units, step_honored2, p2)
		if step_honored2 > 0 and nav2 > 0.0:
			var burned2 := int(round(float(step_honored2) / (nav2 * 100.0)))
			units = maxi(1, units - burned2)
		var post_aum2 := cash + liquid * int(p2["liquid_cents"]) + illiquid * int(p2["illiquid_cents"])
		var final_nav2 := float(post_aum2) / float(units * 100)
		peak_nav = maxf(peak_nav, final_nav2)
		max_drawdown = maxf(max_drawdown, (peak_nav - final_nav2) / peak_nav * 100.0)
		nav_points.append(final_nav2)
		aum_points.append(post_aum2)
		crunch_receipt = {
			"action": crunch_action, "sold": sold_qty2, "bought": bought_qty2,
			"fill": fill_price2, "haircut": step_haircut2, "fee": step_fee2,
			"honored": step_honored2, "wave": wave2,
		}

	if point_limit >= 3:
		var p3: Dictionary = points[3]
		var post_aum3 := cash + liquid * int(p3["liquid_cents"]) + illiquid * int(p3["illiquid_cents"])
		var final_nav3 := float(post_aum3) / float(units * 100)
		peak_nav = maxf(peak_nav, final_nav3)
		max_drawdown = maxf(max_drawdown, (peak_nav - final_nav3) / peak_nav * 100.0)
		nav_points.append(final_nav3)
		aum_points.append(post_aum3)

	var coverage_pct := 100.0 if requested_cents == 0 \
		else clampf(float(honored_cents) / float(requested_cents) * 100.0, 0.0, 100.0)
	var current_nav := float(nav_points.back())
	var current_aum := int(aum_points.back())
	var crisis_choice := derive_crisis_choice({"openAction": open_action, "crunchAction": crunch_action})
	var trust_outcome := "retained"
	if crisis_choice == "attack" or (not gated and coverage_pct < 50.0 and point_limit >= 2):
		trust_outcome = "broken"
	elif gated or coverage_pct < 99.9:
		trust_outcome = "strained"
	return {
		"points": points.slice(0, point_limit + 1).duplicate(true),
		"navPoints": nav_points,
		"aumPoints": aum_points,
		"nav": current_nav,
		"navReturnPct": (current_nav - 1.0) * 100.0,
		"aum": current_aum,
		"startAum": start_aum,
		"cash": cash,
		"liquidShares": liquid,
		"illiquidShares": illiquid,
		"units": units,
		"haircutCents": haircut_cents,
		"feeCents": fee_total_cents,
		"requestedCents": requested_cents,
		"honoredCents": honored_cents,
		"unpaidCents": unpaid_cents,
		"coveragePct": coverage_pct,
		"gated": gated,
		"maxDrawdown": max_drawdown,
		"drawdownLimit": float(data["drawdown_limit_pct"]),
		"exceededLimit": max_drawdown > float(data["drawdown_limit_pct"]),
		"crisisChoice": crisis_choice,
		"trustOutcome": trust_outcome,
		"openReceipt": open_receipt,
		"crunchReceipt": crunch_receipt,
	}


static func _nav_after_payout(post_cash_aum: int, units: int, payout_cents: int,
		_point: Dictionary) -> float:
	if units <= 0:
		return 1.0
	var pre_aum := post_cash_aum + payout_cents
	return maxf(0.01, float(pre_aum) / float(units * 100))


static func snapshot(attempt: Dictionary) -> Dictionary:
	var data := _data()
	if data.is_empty():
		return {}
	var stage := int(attempt.get("stage", Stage.BRIEFING))
	var point_limit := 0
	if stage == Stage.OPEN_0930 or stage == Stage.AFTER_0930:
		point_limit = 1
	elif stage == Stage.CRUNCH_1100 or stage == Stage.AFTER_1100:
		point_limit = 2
	elif stage >= Stage.CLOSED:
		point_limit = 3
	var open_action := String(attempt.get("openAction", "")) if stage >= Stage.AFTER_0930 else ""
	var crunch_action := String(attempt.get("crunchAction", "")) if stage >= Stage.AFTER_1100 else ""
	return _simulate_to(open_action, crunch_action, point_limit, data)


static func preview(attempt: Dictionary, action: String) -> Dictionary:
	var data := _data()
	var stage := int(attempt.get("stage", Stage.BRIEFING))
	if data.is_empty() or not (action in ACTIONS):
		return {}
	if stage == Stage.OPEN_0930:
		return _simulate_to(action, "", 1, data)
	if stage == Stage.CRUNCH_1100:
		return _simulate_to(String(attempt.get("openAction", "")), action, 2, data)
	return {}
