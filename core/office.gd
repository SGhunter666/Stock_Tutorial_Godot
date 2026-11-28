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
		"perkKey": "office.perk.espresso_bar",
		"cost": 120,
		"minRank": 1,
	},
	{
		"id": "lucky_cat",
		"titleKey": "office.item.lucky_cat.title",
		"descKey": "office.item.lucky_cat.desc",
		"perkKey": "office.perk.lucky_cat",
		"cost": 140,
		"minRank": 1,
	},
	{
		"id": "research_board",
		"titleKey": "office.item.research_board.title",
		"descKey": "office.item.research_board.desc",
		"perkKey": "office.perk.research_board",
		"cost": 180,
		"minRank": 1,
	},
	{
		"id": "bloomberg_rig",
		"titleKey": "office.item.bloomberg_rig.title",
		"descKey": "office.item.bloomberg_rig.desc",
		"perkKey": "office.perk.bloomberg_rig",
		"cost": 240,
		"minRank": 1,
	},
	{
		"id": "world_clocks",
		"titleKey": "office.item.world_clocks.title",
		"descKey": "office.item.world_clocks.desc",
		"perkKey": "office.perk.world_clocks",
		"cost": 300,
		"minRank": 2,
	},
	{
		"id": "server_rack",
		"titleKey": "office.item.server_rack.title",
		"descKey": "office.item.server_rack.desc",
		"perkKey": "office.perk.server_rack",
		"cost": 380,
		"minRank": 2,
	},
	{
		"id": "vip_lounge",
		"titleKey": "office.item.vip_lounge.title",
		"descKey": "office.item.vip_lounge.desc",
		"perkKey": "office.perk.vip_lounge",
		"cost": 460,
		"minRank": 3,
	},
	{
		"id": "bull_statue",
		"titleKey": "office.item.bull_statue.title",
		"descKey": "office.item.bull_statue.desc",
		"perkKey": "office.perk.bull_statue",
		"cost": 520,
		"minRank": 3,
	},
]


## Computes active non-cash gameplay perks granted by owned office furnishings.
## Never mutates trading cash so portfolio return % remains 100% pure.
static func active_perks(state: Dictionary) -> Dictionary:
	var has_espresso := is_owned(state, "espresso_bar")
	var has_cat := is_owned(state, "lucky_cat")
	var has_board := is_owned(state, "research_board")
	var has_bloomberg := is_owned(state, "bloomberg_rig")
	var has_clocks := is_owned(state, "world_clocks")
	var has_server := is_owned(state, "server_rack")
	var has_vip := is_owned(state, "vip_lounge")
	var has_bull := is_owned(state, "bull_statue")
	var bot_slots := 1 + (1 if has_server else 0) + (1 if has_bloomberg else 0)
	var xp_bonus := (10 if has_espresso else 0) + (15 if has_board else 0) \
		+ (10 if has_clocks else 0) + (15 if has_vip else 0)
	return {
		"botSlots": bot_slots,
		"xpBonusPct": xp_bonus,
		"hasDailyCoffee": has_espresso,
		"hasLuckyMood": has_cat,
		"hasJournalBoost": has_board,
		"hasDeskSentiment": has_bloomberg,
		"hasGlobalEdge": has_clocks,
		"hasVisitorBonus": has_vip,
		"hasGoldSeal": has_bull,
	}


static func scaled_xp(state: Dictionary, base_xp: int) -> int:
	if base_xp <= 0:
		return 0
	var bonus := int(active_perks(state).get("xpBonusPct", 0))
	return maxi(base_xp, int(round(float(base_xp) * (1.0 + float(bonus) / 100.0))))


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
