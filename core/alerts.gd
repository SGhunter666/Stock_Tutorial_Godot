## Watchlist and price alerts. Pure logic: Game owns persistence, validation
## against live quotes and user-facing toasts; this module only keeps the
## watchlist/alert dictionaries consistent and reports triggered alerts.
class_name SmaAlerts
extends RefCounted

const MAX_ALERTS := 200
const SIDES := ["above", "below"]


static func create_state() -> Dictionary:
	return {"watchlist": [], "alerts": [], "seq": 1}


static func normalize_state(saved: Variant) -> Dictionary:
	var state := create_state()
	if typeof(saved) != TYPE_DICTIONARY:
		return state
	var source: Dictionary = saved
	var watch_source: Variant = source.get("watchlist", [])
	if typeof(watch_source) == TYPE_ARRAY:
		for entry in watch_source:
			if typeof(entry) != TYPE_STRING:
				continue
			var symbol := String(entry).strip_edges().to_upper()
			if symbol == "" or state["watchlist"].has(symbol):
				continue
			state["watchlist"].append(symbol)
	var alert_source: Variant = source.get("alerts", [])
	state["seq"] = maxi(1, int(source.get("seq", 1)))
	var used_ids: Dictionary = {}
	if typeof(alert_source) == TYPE_ARRAY:
		for entry in alert_source:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			if state["alerts"].size() >= MAX_ALERTS:
				break
			var alert := _clean_alert(entry)
			if alert.is_empty():
				continue
			var alert_id := String(alert["id"])
			if alert_id == "" or used_ids.has(alert_id):
				alert_id = _next_id(state)
			alert["id"] = alert_id
			used_ids[alert_id] = true
			state["alerts"].append(alert)
	for alert in state["alerts"]:
		state["seq"] = maxi(int(state["seq"]),
			_id_number(String(alert.get("id", ""))) + 1)
	return state


static func is_watched(state: Dictionary, ticker: String) -> bool:
	var symbol := ticker.strip_edges().to_upper()
	var entries: Variant = state.get("watchlist", [])
	if typeof(entries) != TYPE_ARRAY:
		return false
	return entries.has(symbol)


static func toggle_watch(state: Dictionary, ticker: String) -> bool:
	var symbol := ticker.strip_edges().to_upper()
	if symbol == "":
		return false
	var entries: Variant = state.get("watchlist", [])
	if typeof(entries) != TYPE_ARRAY:
		entries = []
	if entries.has(symbol):
		entries.erase(symbol)
		state["watchlist"] = entries
		return false
	entries.append(symbol)
	state["watchlist"] = entries
	return true


static func watchlist(state: Dictionary) -> Array:
	var entries: Variant = state.get("watchlist", [])
	if typeof(entries) != TYPE_ARRAY:
		return []
	return entries.duplicate()


static func all(state: Dictionary) -> Array:
	var entries: Variant = state.get("alerts", [])
	if typeof(entries) != TYPE_ARRAY:
		return []
	return entries.duplicate()


static func add_alert(state: Dictionary, ticker: String, side: String,
		price: float, day: int) -> Dictionary:
	var symbol := ticker.strip_edges().to_upper()
	var direction := side.strip_edges().to_lower()
	if symbol == "":
		return {"ok": false, "alert": {}, "error": "alerts.invalidTicker"}
	if not SIDES.has(direction):
		return {"ok": false, "alert": {}, "error": "alerts.invalidDirection"}
	if price <= 0.0 or not is_finite(price):
		return {"ok": false, "alert": {}, "error": "alerts.invalidPrice"}
	var entries: Variant = state.get("alerts", [])
	if typeof(entries) != TYPE_ARRAY:
		entries = []
	if entries.size() >= MAX_ALERTS:
		return {"ok": false, "alert": {}, "error": "alerts.limitReached"}
	var alert := {
		"id": _next_id(state),
		"ticker": symbol,
		"side": direction,
		"price": SmaFormat.round_to(price, 2),
		"active": true,
		"createdDay": maxi(0, day),
		"triggeredDay": -1,
		"triggeredPrice": 0.0,
	}
	entries.append(alert)
	state["alerts"] = entries
	return {"ok": true, "alert": alert, "error": ""}


static func remove_alert(state: Dictionary, alert_id: String) -> bool:
	var entries: Variant = state.get("alerts", [])
	if typeof(entries) != TYPE_ARRAY:
		return false
	for index in range(entries.size() - 1, -1, -1):
		var entry: Variant = entries[index]
		if typeof(entry) == TYPE_DICTIONARY \
				and String(entry.get("id", "")) == alert_id:
			entries.remove_at(index)
			state["alerts"] = entries
			return true
	return false


## Removes every alert that has already fired and returns how many were removed.
static func remove_triggered(state: Dictionary) -> int:
	var entries: Variant = state.get("alerts", [])
	if typeof(entries) != TYPE_ARRAY:
		return 0
	var removed := 0
	for index in range(entries.size() - 1, -1, -1):
		var entry: Variant = entries[index]
		if typeof(entry) == TYPE_DICTIONARY \
				and not bool(entry.get("active", true)):
			entries.remove_at(index)
			removed += 1
	if removed > 0:
		state["alerts"] = entries
	return removed


static func alerts_for(state: Dictionary, ticker: String) -> Array:
	var symbol := ticker.strip_edges().to_upper()
	var result: Array = []
	var entries: Variant = state.get("alerts", [])
	if typeof(entries) != TYPE_ARRAY:
		return result
	for entry in entries:
		if typeof(entry) == TYPE_DICTIONARY \
				and String(entry.get("ticker", "")) == symbol:
			result.append(entry)
	return result


static func active_count(state: Dictionary) -> int:
	var count := 0
	var entries: Variant = state.get("alerts", [])
	if typeof(entries) != TYPE_ARRAY:
		return 0
	for entry in entries:
		if typeof(entry) == TYPE_DICTIONARY and bool(entry.get("active", false)):
			count += 1
	return count


## Marks every active alert whose target is met and returns the triggered
## entries. Prices are ticker -> latest trade price for this simulated step.
static func check(state: Dictionary, prices: Dictionary, day: int,
		_second: int) -> Array:
	var triggered: Array = []
	var entries: Variant = state.get("alerts", [])
	if typeof(entries) != TYPE_ARRAY:
		return triggered
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if not bool(entry.get("active", false)):
			continue
		var ticker := String(entry.get("ticker", ""))
		if not prices.has(ticker):
			continue
		var last := float(prices[ticker])
		var target := float(entry.get("price", 0.0))
		if last <= 0.0 or target <= 0.0:
			continue
		var side := String(entry.get("side", ""))
		var hit := (side == "above" and last >= target) \
			or (side == "below" and last <= target)
		if not hit:
			continue
		entry["active"] = false
		entry["triggeredDay"] = day
		entry["triggeredPrice"] = SmaFormat.round_to(last, 2)
		triggered.append(entry)
	return triggered


static func _clean_alert(entry: Dictionary) -> Dictionary:
	var ticker := String(entry.get("ticker", "")).strip_edges().to_upper()
	var side := String(entry.get("side", "")).strip_edges().to_lower()
	var price := float(entry.get("price", 0.0))
	if ticker == "" or not SIDES.has(side) or price <= 0.0:
		return {}
	var active := true
	var active_value: Variant = entry.get("active", true)
	if typeof(active_value) == TYPE_BOOL:
		active = bool(active_value)
	return {
		"id": String(entry.get("id", "")).strip_edges(),
		"ticker": ticker,
		"side": side,
		"price": SmaFormat.round_to(price, 2),
		"active": active,
		"createdDay": maxi(0, int(entry.get("createdDay", 0))),
		"triggeredDay": maxi(-1, int(entry.get("triggeredDay", -1))),
		"triggeredPrice": maxf(0.0, float(entry.get("triggeredPrice", 0.0))),
	}


static func _next_id(state: Dictionary) -> String:
	var sequence := maxi(1, int(state.get("seq", 1)))
	while true:
		var candidate := "alert-%d" % sequence
		sequence += 1
		var exists := false
		var entries: Variant = state.get("alerts", [])
		if typeof(entries) == TYPE_ARRAY:
			for entry in entries:
				if typeof(entry) == TYPE_DICTIONARY \
						and String(entry.get("id", "")) == candidate:
					exists = true
					break
		if not exists:
			state["seq"] = sequence
			return candidate
	return ""


static func _id_number(alert_id: String) -> int:
	if not alert_id.begins_with("alert-"):
		return 0
	var tail := alert_id.substr(6)
	return int(tail) if tail.is_valid_int() else 0
