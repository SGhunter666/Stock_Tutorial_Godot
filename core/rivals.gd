## Deterministic live rival trader arena ("远望同期四人实盘风云榜").
## Pure core logic with zero UI dependencies: evaluates Gu Yan, Chen Xi, and
## Lao Chen against the actual prices and daily bars in `exchange.state` so
## players compete head-to-head with living classmates every trading day.
class_name SmaRivals
extends RefCounted

const RIVALS := [
	{
		"id": "gu_yan",
		"nameKey": "story.char.gu_yan.name",
		"styleKey": "rivals.style.gu_yan",
		"basket": ["NVDO", "CONB", "TSLO", "RDDX"],
		"baseLeverage": 2.20,
		"dailyCarry": -0.00038,
		"earlyMomentumDays": 11,
		"earlyAlpha": 0.0038,
		"canMarginCall": true,
		"portrait": "res://assets/portraits/gu_yan.jpg",
		"pixelPortrait": "res://assets/portraits/pixel/gu_yan.png",
		"color": "#d98c5f",
	},
	{
		"id": "chen_xi",
		"nameKey": "story.char.chen_xi.name",
		"styleKey": "rivals.style.chen_xi",
		"basket": ["MSFY", "TSMX", "AVGM", "LLLY"],
		"baseLeverage": 0.85,
		"dailyCarry": 0.00024,
		"earlyMomentumDays": 0,
		"earlyAlpha": 0.0,
		"canMarginCall": false,
		"portrait": "res://assets/portraits/chen_xi.jpg",
		"pixelPortrait": "res://assets/portraits/pixel/chen_xi.png",
		"color": "#6fa8dc",
	},
	{
		"id": "lao_chen",
		"nameKey": "story.char.lao_chen.name",
		"styleKey": "rivals.style.lao_chen",
		"basket": ["BRKB", "XOMN", "CSTK", "JNJX"],
		"baseLeverage": 0.72,
		"dailyCarry": 0.00020,
		"earlyMomentumDays": 0,
		"earlyAlpha": 0.0,
		"canMarginCall": false,
		"portrait": "res://assets/portraits/lao_chen.jpg",
		"pixelPortrait": "res://assets/portraits/pixel/lao_chen.png",
		"color": "#a0a0a0",
	},
]


static func leaderboard(state: Dictionary, player_equity: float,
		start_cash: float = 100000.0) -> Array:
	var safe_start := maxf(1.0, start_cash)
	var companies: Dictionary = state.get("companies", {})
	var day := int(state.get("dayIndex", 0))
	var account: Dictionary = state.get("account", {})
	var player_prev := safe_start
	var eq_hist: Array = account.get("equityHistory", [])
	if not eq_hist.is_empty():
		var last_snap: Dictionary = eq_hist.back()
		player_prev = maxf(1.0, float(last_snap.get("equity", safe_start)))
	var player_dd := _compute_history_drawdown(eq_hist, player_equity, safe_start)
	var player_holdings := _top_player_tickers(account, companies)
	var entries: Array = [{
		"id": "player",
		"isPlayer": true,
		"nameKey": "rivals.you",
		"styleKey": "rivals.style.player",
		"equity": SmaFormat.round_to(player_equity, 2),
		"returnPct": SmaFormat.round_to((player_equity - safe_start) / safe_start * 100.0, 2),
		"todayPct": SmaFormat.round_to((player_equity - player_prev) / player_prev * 100.0, 2),
		"maxDrawdownPct": SmaFormat.round_to(player_dd, 2),
		"holdings": player_holdings,
		"leverage": 1.0,
		"marginCalled": false,
		"marginCallDay": -1,
		"statusKey": "rivals.status.player",
		"quoteKey": "rivals.quote.player",
		"portrait": "",
		"pixelPortrait": "",
		"color": "#f2c14e",
	}]
	for rival_def in RIVALS:
		entries.append(simulate_rival(state, rival_def, safe_start))
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ea := float(a.get("equity", 0.0))
		var eb := float(b.get("equity", 0.0))
		if not is_equal_approx(ea, eb):
			return ea > eb
		return bool(a.get("isPlayer", false)) and not bool(b.get("isPlayer", false)))
	var player_rank := 1
	for idx in entries.size():
		entries[idx]["rank"] = idx + 1
		if bool(entries[idx].get("isPlayer", false)):
			player_rank = idx + 1
	for entry in entries:
		if bool(entry.get("isPlayer", false)):
			if int(entry["rank"]) == 1 and day >= 1:
				entry["statusKey"] = "rivals.status.playerLead"
			continue
		_assign_rival_dialogue(entry, player_equity, player_rank, day)
	return entries


static func simulate_rival(state: Dictionary, rival_def: Dictionary,
		start_cash: float = 100000.0) -> Dictionary:
	var companies: Dictionary = state.get("companies", {})
	var day := int(state.get("dayIndex", 0))
	var day0_iso := SmaCalendar.iso_date(0)
	var basket: Array = []
	for raw_t in rival_def.get("basket", []):
		var t := String(raw_t)
		if companies.has(t):
			basket.append(t)
	var base_lev := float(rival_def.get("baseLeverage", 1.0))
	var cur_lev := base_lev
	var carry := float(rival_def.get("dailyCarry", 0.0))
	var early_days := int(rival_def.get("earlyMomentumDays", 0))
	var early_alpha := float(rival_def.get("earlyAlpha", 0.0))
	var can_mc := bool(rival_def.get("canMarginCall", false))

	var sim_bars_by_ticker := {}
	var start_prices := {}
	var min_bars := 999999
	for t in basket:
		var cs: Dictionary = companies[t]
		var split_factor := maxf(0.0001, float(cs.get("splitFactor", 1.0)))
		var p0 := maxf(0.01, float(cs.get("company", {}).get("price", cs.get("last", 100.0))) / split_factor)
		start_prices[t] = p0
		var sim_closes: Array = []
		var daily_arr: Array = cs.get("series", {}).get("daily", [])
		for bar in daily_arr:
			var bar_date := String(bar.get("d", bar.get("t", "")))
			if bar_date >= day0_iso:
				sim_closes.append(maxf(0.01, float(bar.get("c", p0))))
		sim_bars_by_ticker[t] = sim_closes
		if sim_closes.size() < min_bars:
			min_bars = sim_closes.size()
	if basket.is_empty() or min_bars == 999999:
		min_bars = 0

	var equity := start_cash
	var peak := start_cash
	var max_dd := 0.0
	var margin_called := false
	var margin_call_day := -1

	for d_idx in min_bars:
		var basket_ret := 0.0
		for t in basket:
			var closes: Array = sim_bars_by_ticker[t]
			var prev_p: float = float(start_prices[t]) if d_idx == 0 else float(closes[d_idx - 1])
			var close_p: float = float(closes[d_idx])
			basket_ret += (close_p - prev_p) / maxf(0.01, prev_p)
		basket_ret /= float(maxi(1, basket.size()))
		var bonus := early_alpha if (d_idx < early_days and not margin_called) else 0.0
		var day_ret := clampf(basket_ret * cur_lev + carry + bonus, -0.42, 0.45)
		equity = maxf(5000.0, equity * (1.0 + day_ret))
		if can_mc and not margin_called:
			var cur_dd := (peak - equity) / maxf(1.0, peak) * 100.0
			if cur_dd >= 21.0 or basket_ret <= -0.058:
				margin_called = true
				margin_call_day = d_idx
				equity = maxf(5000.0, equity * 0.915)
				cur_lev = 0.85
		peak = maxf(peak, equity)
		max_dd = maxf(max_dd, (peak - equity) / maxf(1.0, peak) * 100.0)

	var prev_equity := equity
	var live_ret := 0.0
	if not basket.is_empty():
		for t in basket:
			var cs: Dictionary = companies[t]
			var prev_c := maxf(0.01, float(cs.get("prevClose", cs.get("open", cs.get("last", 1.0)))))
			if day == 0:
				prev_c = float(start_prices.get(t, prev_c))
			var last_c := maxf(0.01, float(cs.get("last", prev_c)))
			live_ret += (last_c - prev_c) / prev_c
		live_ret /= float(basket.size())
		var live_step := clampf(live_ret * cur_lev, -0.35, 0.35)
		equity = maxf(5000.0, prev_equity * (1.0 + live_step))
		peak = maxf(peak, equity)
		max_dd = maxf(max_dd, (peak - equity) / maxf(1.0, peak) * 100.0)

	var today_pct := (equity - prev_equity) / maxf(1.0, prev_equity) * 100.0
	return {
		"id": String(rival_def["id"]),
		"isPlayer": false,
		"nameKey": String(rival_def["nameKey"]),
		"styleKey": String(rival_def["styleKey"]),
		"equity": SmaFormat.round_to(equity, 2),
		"returnPct": SmaFormat.round_to((equity - start_cash) / start_cash * 100.0, 2),
		"todayPct": SmaFormat.round_to(today_pct, 2),
		"maxDrawdownPct": SmaFormat.round_to(max_dd, 2),
		"holdings": basket.slice(0, 3),
		"leverage": SmaFormat.round_to(cur_lev, 2),
		"marginCalled": margin_called,
		"marginCallDay": margin_call_day,
		"statusKey": "rivals.status.%s.normal" % String(rival_def["id"]),
		"quoteKey": "rivals.quote.%s.normal" % String(rival_def["id"]),
		"portrait": String(rival_def.get("portrait", "")),
		"pixelPortrait": String(rival_def.get("pixelPortrait", "")),
		"color": String(rival_def.get("color", "#4fb3a8")),
	}


static func gu_yan_snapshot(state: Dictionary, start_cash: float = 100000.0) -> Dictionary:
	return simulate_rival(state, RIVALS[0], start_cash)


static func _assign_rival_dialogue(entry: Dictionary, player_equity: float,
		player_rank: int, day: int) -> void:
	var rid := String(entry.get("id", ""))
	var rank := int(entry.get("rank", 4))
	var ret := float(entry.get("returnPct", 0.0))
	var today := float(entry.get("todayPct", 0.0))
	if rid == "gu_yan":
		if bool(entry.get("marginCalled", false)):
			entry["statusKey"] = "rivals.status.gu_yan.marginCall"
			entry["quoteKey"] = "rivals.quote.gu_yan.marginCall"
		elif rank == 1 and float(entry.get("equity", 0.0)) > player_equity * 1.015:
			entry["statusKey"] = "rivals.status.gu_yan.hot"
			entry["quoteKey"] = "rivals.quote.gu_yan.lead"
		elif today <= -2.5:
			entry["statusKey"] = "rivals.status.gu_yan.drawdown"
			entry["quoteKey"] = "rivals.quote.gu_yan.shake"
		else:
			entry["statusKey"] = "rivals.status.gu_yan.normal"
			entry["quoteKey"] = "rivals.quote.gu_yan.normal"
	elif rid == "chen_xi":
		if rank == 1:
			entry["statusKey"] = "rivals.status.chen_xi.lead"
			entry["quoteKey"] = "rivals.quote.chen_xi.lead"
		elif player_rank == 1 and day >= 3:
			entry["statusKey"] = "rivals.status.chen_xi.normal"
			entry["quoteKey"] = "rivals.quote.chen_xi.praise"
		else:
			entry["statusKey"] = "rivals.status.chen_xi.normal"
			entry["quoteKey"] = "rivals.quote.chen_xi.normal"
	elif rid == "lao_chen":
		if today >= 0.0 and ret > 2.0:
			entry["statusKey"] = "rivals.status.lao_chen.steady"
			entry["quoteKey"] = "rivals.quote.lao_chen.steady"
		elif rank == 4 and day >= 2:
			entry["statusKey"] = "rivals.status.lao_chen.normal"
			entry["quoteKey"] = "rivals.quote.lao_chen.lag"
		else:
			entry["statusKey"] = "rivals.status.lao_chen.normal"
			entry["quoteKey"] = "rivals.quote.lao_chen.normal"


static func _compute_history_drawdown(eq_hist: Array, current_eq: float,
		start_cash: float) -> float:
	var peak := start_cash
	var max_dd := 0.0
	for point in eq_hist:
		var val := float(point.get("equity", start_cash))
		peak = maxf(peak, val)
		if peak > 0.0:
			max_dd = maxf(max_dd, (peak - val) / peak * 100.0)
	peak = maxf(peak, current_eq)
	if peak > 0.0:
		max_dd = maxf(max_dd, (peak - current_eq) / peak * 100.0)
	return max_dd


static func _top_player_tickers(account: Dictionary, companies: Dictionary) -> Array:
	var scored: Array = []
	var positions: Dictionary = account.get("positions", {})
	for t in positions.keys():
		var qty := int(positions[t].get("qty", 0))
		if qty <= 0:
			continue
		var price := float(companies.get(t, {}).get("last", positions[t].get("avgCost", 0.0)))
		scored.append({"ticker": String(t), "val": float(qty) * price})
	var shorts: Dictionary = account.get("shorts", {})
	for t in shorts.keys():
		var sqty := int(shorts[t].get("qty", 0))
		if sqty <= 0:
			continue
		var sprice := float(companies.get(t, {}).get("last", shorts[t].get("avgPrice", 0.0)))
		scored.append({"ticker": "-%s" % String(t), "val": float(sqty) * sprice})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["val"]) > float(b["val"]))
	var out: Array = []
	for idx in mini(3, scored.size()):
		out.append(String(scored[idx]["ticker"]))
	return out
