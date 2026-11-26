## Pure logic for Kairosoft-style Pixel Trading Office renovation & furnishings.
## Renovation Points (RP) are derived deterministically from Academy XP, trades,
## career rank, certificates, and achievements — never touching the trading cash
## ledger so portfolio return % and career equity gates remain 100% pure.
class_name SmaOffice
extends RefCounted

const STARTER_RP := 160

const ITEMS := [
	{
		"id": "espresso_bar",
		"titleKey": "office.item.espresso_bar.title",
		"descKey": "office.item.espresso_bar.desc",
		"cost": 120,
		"minRank": 1,
	},
	{
		"id": "lucky_cat",
		"titleKey": "office.item.lucky_cat.title",
		"descKey": "office.item.lucky_cat.desc",
		"cost": 140,
		"minRank": 1,
	},
	{
		"id": "bloomberg_rig",
		"titleKey": "office.item.bloomberg_rig.title",
		"descKey": "office.item.bloomberg_rig.desc",
		"cost": 240,
		"minRank": 1,
	},
	{
		"id": "world_clocks",
		"titleKey": "office.item.world_clocks.title",
		"descKey": "office.item.world_clocks.desc",
		"cost": 300,
		"minRank": 2,
	},
	{
		"id": "server_rack",
		"titleKey": "office.item.server_rack.title",
		"descKey": "office.item.server_rack.desc",
		"cost": 380,
		"minRank": 2,
	},
	{
		"id": "bull_statue",
		"titleKey": "office.item.bull_statue.title",
		"descKey": "office.item.bull_statue.desc",
		"cost": 520,
		"minRank": 3,
	},
]


static func create_state() -> Dictionary:
	return {"owned": [], "hidden": []}


static func by_id(item_id: String) -> Dictionary:
	for item in ITEMS:
		if String(item["id"]) == item_id:
			return item
	return {}


static func normalize_state(saved: Variant) -> Dictionary:
	var state := create_state()
	if typeof(saved) != TYPE_DICTIONARY:
		return state
	for key in ["owned", "hidden"]:
		var raw: Variant = saved.get(key, [])
		if typeof(raw) == TYPE_ARRAY:
			var clean: Array = []
			for entry in raw:
				var sid := String(entry)
				if not by_id(sid).is_empty() and not clean.has(sid):
					clean.append(sid)
			state[key] = clean
	return state


static func total_earned_rp(academy: Dictionary, career: Dictionary, trade_count: int) -> int:
	var xp := maxi(0, int(academy.get("xp", 0)))
	var ach_count := (academy.get("achievements", []) as Array).size()
	var rank := maxi(1, int(career.get("rank", 1)))
	var cert_count := (career.get("certificates", []) as Array).size()
	var trades := clampi(trade_count, 0, 200)
	return STARTER_RP + xp + trades * 15 + (rank - 1) * 250 + cert_count * 200 + ach_count * 80


static func spent_rp(state: Dictionary) -> int:
	var total := 0
	for entry in state.get("owned", []):
		var def := by_id(String(entry))
		if not def.is_empty():
			total += int(def["cost"])
	return total


static func available_rp(state: Dictionary, academy: Dictionary, career: Dictionary,
		trade_count: int) -> int:
	return maxi(0, total_earned_rp(academy, career, trade_count) - spent_rp(state))


static func is_owned(state: Dictionary, item_id: String) -> bool:
	return (state.get("owned", []) as Array).has(item_id)


static func is_displayed(state: Dictionary, item_id: String) -> bool:
	return is_owned(state, item_id) and not (state.get("hidden", []) as Array).has(item_id)


static func purchase(state: Dictionary, item_id: String, academy: Dictionary,
		career: Dictionary, trade_count: int) -> Dictionary:
	var def := by_id(item_id)
	if def.is_empty():
		return {"ok": false, "error": "office.errorUnknown"}
	if is_owned(state, item_id):
		return {"ok": false, "error": "office.errorOwned"}
	var rank := maxi(1, int(career.get("rank", 1)))
	if rank < int(def["minRank"]):
		return {"ok": false, "error": "office.errorRank"}
	var avail := available_rp(state, academy, career, trade_count)
	if avail < int(def["cost"]):
		return {"ok": false, "error": "office.errorPoints"}
	var owned: Array = state["owned"]
	owned.append(item_id)
	return {"ok": true, "item": def, "remainingRp": avail - int(def["cost"])}


static func toggle_visibility(state: Dictionary, item_id: String) -> bool:
	if not is_owned(state, item_id):
		return false
	var hidden: Array = state["hidden"]
	if hidden.has(item_id):
		hidden.erase(item_id)
		return true
	hidden.append(item_id)
	return false
