## Read-only portfolio replay. Closed sessions use recorded holdings and prices.
## Older saves can fall back to their retained stock trades and corporate actions.
class_name SmaReplay
extends RefCounted


static func max_day(state: Dictionary) -> int:
	return maxi(0, int(state.get("dayIndex", 0)))


static func equity_curve(state: Dictionary) -> Array:
	var account: Dictionary = state["account"]
	var points := {}
	for entries: Array in [account.get("equityHistory", []), account.get("replayHistory", [])]:
		for entry in entries:
			points[int(entry["day"])] = float(entry["equity"])
	var days := points.keys()
	days.sort()
	var curve: Array = []
	for day in days:
		curve.append({"day": day, "equity": points[day]})
	return curve


static func _equity_at(curve: Array, day: int, fallback: float) -> float:
	var value := fallback
	for entry in curve:
		if int(entry["day"]) > day:
			break
		value = float(entry["equity"])
	return value


static func _close_at(state: Dictionary, ticker: String, day: int,
		adjustment: float, fallback: float) -> float:
	var date := SmaCalendar.iso_date(day)
	var cs: Dictionary = state["companies"].get(ticker, {})
	if cs.is_empty():
		return 0.0
	var daily: Array = cs.get("series", {}).get("daily", [])
	for index in range(daily.size() - 1, -1, -1):
		if String(daily[index].get("d", "")) <= date:
			if String(daily[index].get("d", "")) == date or day < int(state.get("dayIndex", day)):
				return float(daily[index].get("c", 0.0)) * adjustment
			break
	if day >= int(state.get("dayIndex", day)):
		return float(cs.get("last", cs.get("fairValue", 0.0)))
	return fallback


static func _apply_trade(longs: Dictionary, shorts: Dictionary, trade: Dictionary) -> void:
	var ticker := String(trade.get("ticker", ""))
	var action := String(trade.get("action", ""))
	var side := String(trade.get("side", ""))
	var qty := int(trade.get("qty", 0))
	var price := float(trade.get("price", 0.0))
	if action == "":
		if side == "buy":
			action = "openLong"
		elif side == "sell":
			action = "closeLong"
		elif side == "short":
			action = "openShort"
		elif side == "cover":
			action = "closeShort"
	if qty <= 0 or price <= 0.0:
		return
	var positions := shorts if action in ["openShort", "closeShort"] else longs
	if action in ["openLong", "openShort", "rights"]:
		var previous: Dictionary = positions.get(ticker, {"qty": 0, "avgCost": 0.0})
		var total_qty := int(previous["qty"]) + qty
		positions[ticker] = {"qty": total_qty,
			"avgCost": (float(previous["avgCost"]) * int(previous["qty"]) + qty * price)
				/ float(total_qty)}
	elif action in ["closeLong", "closeShort"] and positions.has(ticker):
		var position: Dictionary = positions[ticker]
		position["qty"] = int(position["qty"]) - qty
		if int(position["qty"]) <= 0:
			positions.erase(ticker)


static func _apply_corporate_action(longs: Dictionary, shorts: Dictionary, action: Dictionary) -> void:
	var ticker := String(action.get("ticker", ""))
	var ratio := float(action.get("ratio", 0.0))
	for positions: Dictionary in [longs, shorts]:
		if not positions.has(ticker):
			continue
		if action.get("type") == "delisting":
			positions.erase(ticker)
		elif ratio > 0.0:
			var position: Dictionary = positions[ticker]
			position["qty"] = roundi(float(position["qty"]) * ratio)
			position["avgCost"] = float(position["avgCost"]) / ratio
			if int(position["qty"]) <= 0:
				positions.erase(ticker)


static func snapshot(state: Dictionary, day: int, live_equity: float = NAN) -> Dictionary:
	var account: Dictionary = state["account"]
	var is_live := day == max_day(state) and account.has("positions") and account.has("shorts")
	var close_record: Dictionary = {}
	for entry in account.get("replayHistory", []):
		if int(entry["day"]) == day:
			close_record = entry
			break
	var position_data_available: bool = is_live or not close_record.is_empty() \
		or account.get("trades", []).size() < SmaExchange.ACCOUNT_TRADE_LIMIT
	var rebuild_positions := position_data_available and not is_live and close_record.is_empty()
	var curve := equity_curve(state)
	if is_live and is_finite(live_equity):
		if not curve.is_empty() and int(curve[-1]["day"]) == day:
			curve[-1]["equity"] = live_equity
		else:
			curve.append({"day": day, "equity": live_equity})
	var current_equity := float(account.get("cash", 0.0))
	var equity := _equity_at(curve, day, current_equity)
	var previous_equity := float(account.get("initialCash", equity)) if day == 0 \
		else _equity_at(curve, day - 1, equity)
	var longs: Dictionary = {}
	var shorts: Dictionary = {}
	var marks: Dictionary = close_record.get("marks", {})
	if is_live or not close_record.is_empty():
		var inventory := account if is_live else close_record
		longs = inventory["positions"]
		shorts = inventory["shorts"]
	var trades_today: Array = []
	var dividends_today: Array = []
	var position_actions: Array = []
	var later_splits := {}
	for action in state.get("corporateActions", []) if rebuild_positions else []:
		var kind := String(action.get("type", ""))
		if int(action.get("day", -1)) <= day:
			if kind in ["split", "delisting"]:
				position_actions.append(action)
		elif kind == "split" and float(action.get("ratio", 0.0)) > 0.0:
			# The exchange back-adjusts its stored candles when a split occurs.
			var ticker := String(action.get("ticker", ""))
			later_splits[ticker] = float(later_splits.get(ticker, 1.0)) * float(action["ratio"])
	position_actions.sort_custom(func(a, b): return int(a["day"]) < int(b["day"]))
	var next_action := 0
	for trade in account.get("trades", []):
		var trade_day := int(trade.get("day", 0))
		if trade_day > day:
			continue
		while next_action < position_actions.size() and int(position_actions[next_action]["day"]) <= trade_day:
			_apply_corporate_action(longs, shorts, position_actions[next_action])
			next_action += 1
		if rebuild_positions:
			_apply_trade(longs, shorts, trade)
		if trade_day == day:
			trades_today.append(trade)
	for index in range(next_action, position_actions.size()):
		_apply_corporate_action(longs, shorts, position_actions[index])
	for dividend in state["account"].get("dividends", []):
		if int(dividend.get("day", 0)) == day:
			dividends_today.append(dividend)
	var rows: Array = []
	var long_value := 0.0
	var short_value := 0.0
	for is_short: bool in [false, true]:
		var positions := shorts if is_short else longs
		for ticker in positions:
			var position: Dictionary = positions[ticker]
			var avg_cost := float(position.get("avgPrice", position.get("avgCost", 0.0)))
			var close := avg_cost
			if is_live:
				close = float(state["companies"].get(ticker, {}).get("last", avg_cost))
			elif marks.has(ticker):
				close = float(marks[ticker])
			else:
				close = _close_at(state, String(ticker), day,
					float(later_splits.get(ticker, 1.0)), avg_cost)
			var qty := int(position["qty"])
			var value := float(qty) * close
			var pnl := float(qty) * (close - avg_cost)
			if is_short:
				short_value += value
			else:
				long_value += value
			rows.append({"ticker": String(ticker), "qty": qty, "avgCost": avg_cost,
				"close": close, "value": SmaFormat.round_to(value, 2), "short": is_short,
				"pnl": SmaFormat.round_to(-pnl if is_short else pnl, 2)})
	rows.sort_custom(func(a, b): return absf(float(a["value"])) > absf(float(b["value"])))
	var events: Array = []
	for trade in trades_today:
		events.append({"kind": "stock", "ticker": String(trade.get("ticker", "")),
			"side": String(trade.get("side", "")), "qty": int(trade.get("qty", 0)),
			"amount": SmaFormat.round_to(float(trade.get("qty", 0))
				* float(trade.get("price", 0.0)), 2)})
	for dividend in dividends_today:
		events.append({"kind": "dividend", "ticker": String(dividend.get("ticker", "")),
			"amount": float(dividend.get("amount", 0.0))})
	for action in state.get("corporateActions", []):
		if int(action.get("day", -1)) == day:
			events.append({"kind": "corporate", "ticker": String(action.get("ticker", "")),
				"action": String(action.get("type", "")),
				"amount": float(action.get("amount", 0.0))})
	var curve_to_day: Array = []
	for entry in curve:
		if int(entry["day"]) > day:
			break
		curve_to_day.append(entry)
	return {
		"day": day, "equity": SmaFormat.round_to(equity, 2),
		"dailyPnl": SmaFormat.round_to(equity - previous_equity, 2),
		"longValue": SmaFormat.round_to(long_value, 2),
		"shortValue": SmaFormat.round_to(short_value, 2),
		"stockValue": SmaFormat.round_to(long_value - short_value, 2),
		"positions": rows, "events": events,
		"positionDataAvailable": position_data_available,
		"curve": curve_to_day,
		"tradeCount": trades_today.size(),
	}
