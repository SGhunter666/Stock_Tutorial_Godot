## Pure logic for Live Quant Strategy Auto-Trading Bots (bridges Quant Lab ->
## real trading account). Bots read real SmaExchange daily bar history and
## submit real market orders with strict per-bot budget & stop-loss guardrails.
## Zero UI dependencies.
class_name SmaQuantBots
extends RefCounted

const STRATEGIES := [
	{"id": "ma_cross", "labelKey": "bots.strategy.ma_cross", "descKey": "bots.strategyDesc.ma_cross"},
	{"id": "rsi_rebound", "labelKey": "bots.strategy.rsi_rebound", "descKey": "bots.strategyDesc.rsi_rebound"},
	{"id": "boll_revert", "labelKey": "bots.strategy.boll_revert", "descKey": "bots.strategyDesc.boll_revert"},
	{"id": "momentum_break", "labelKey": "bots.strategy.momentum_break", "descKey": "bots.strategyDesc.momentum_break"},
]

const BUDGET_PRESETS := [5000.0, 10000.0, 20000.0, 30000.0]
const STOP_LOSS_PRESETS := [4.0, 6.0, 8.0, 12.0]
const MAX_LOGS_PER_BOT := 12


static func strategy_ids() -> Array[String]:
	var out: Array[String] = []
	for spec in STRATEGIES:
		out.append(String(spec["id"]))
	return out


static func strategy_def(strategy_id: String) -> Dictionary:
	for spec in STRATEGIES:
		if String(spec["id"]) == strategy_id:
			return spec
	return STRATEGIES[0]


static func normalize_store(saved: Variant) -> Dictionary:
	var store := {"nextId": 1, "bots": []}
	if typeof(saved) != TYPE_DICTIONARY:
		return store
	store["nextId"] = maxi(1, int(saved.get("nextId", 1)))
	var raw_bots: Variant = saved.get("bots", [])
	var clean: Array = []
	if typeof(raw_bots) == TYPE_ARRAY:
		for entry in raw_bots:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var tid := String(entry.get("ticker", "")).strip_edges().to_upper()
			if tid == "":
				continue
			var strat := String(entry.get("strategy", "ma_cross"))
			if not strategy_ids().has(strat):
				strat = "ma_cross"
			var logs_raw: Variant = entry.get("logs", [])
			var logs: Array = logs_raw.duplicate(true) if typeof(logs_raw) == TYPE_ARRAY else []
			if logs.size() > MAX_LOGS_PER_BOT:
				logs = logs.slice(logs.size() - MAX_LOGS_PER_BOT, logs.size())
			clean.append({
				"id": maxi(1, int(entry.get("id", clean.size() + 1))),
				"ticker": tid,
				"strategy": strat,
				"budget": clampf(float(entry.get("budget", 10000.0)), 1000.0, 250000.0),
				"stopLossPct": clampf(float(entry.get("stopLossPct", 6.0)), 1.0, 35.0),
				"paused": bool(entry.get("paused", false)),
				"createdDay": maxi(0, int(entry.get("createdDay", 0))),
				"holdingQty": maxi(0, int(entry.get("holdingQty", 0))),
				"entryPrice": maxf(0.0, float(entry.get("entryPrice", 0.0))),
				"trades": maxi(0, int(entry.get("trades", 0))),
				"wins": maxi(0, int(entry.get("wins", 0))),
				"realizedPnl": float(entry.get("realizedPnl", 0.0)),
				"lastSignalDay": int(entry.get("lastSignalDay", -1)),
				"lastAction": String(entry.get("lastAction", "idle")),
				"logs": logs,
			})
	store["bots"] = clean
	return store


static func deploy(store: Dictionary, ticker: String, strategy: String, budget: float,
		stop_loss_pct: float, max_slots: int, day: int) -> Dictionary:
	var norm := normalize_store(store)
	var bots: Array = norm["bots"]
	if bots.size() >= maxi(1, max_slots):
		return {"ok": false, "error": "bots.errorSlots", "store": norm}
	var tk := ticker.strip_edges().to_upper()
	if tk == "":
		return {"ok": false, "error": "bots.errorTicker", "store": norm}
	var strat := strategy if strategy_ids().has(strategy) else "ma_cross"
	var bot_id := int(norm["nextId"])
	norm["nextId"] = bot_id + 1
	var bot := {
		"id": bot_id,
		"ticker": tk,
		"strategy": strat,
		"budget": clampf(budget, 1000.0, 250000.0),
		"stopLossPct": clampf(stop_loss_pct, 1.0, 35.0),
		"paused": false,
		"createdDay": maxi(0, day),
		"holdingQty": 0,
		"entryPrice": 0.0,
		"trades": 0,
		"wins": 0,
		"realizedPnl": 0.0,
		"lastSignalDay": -1,
		"lastAction": "deployed",
		"logs": [{"day": day, "action": "deployed", "price": 0.0, "qty": 0, "pnl": 0.0}],
	}
	bots.append(bot)
	norm["bots"] = bots
	return {"ok": true, "bot": bot, "store": norm}


## Pure signal engine evaluated on daily closing history + latest spot price.
## Returns {"signal": "buy" | "sell" | "stop_loss" | "hold", "reason": String, "metric": float}.
static func evaluate_signal(strategy: String, closes: Array[float], last_price: float,
		holding_qty: int, entry_price: float, stop_loss_pct: float) -> Dictionary:
	if last_price <= 0.0:
		return {"signal": "hold", "reason": "no_price", "metric": 0.0}
	if holding_qty > 0 and entry_price > 0.0:
		var dd_pct := (last_price - entry_price) / entry_price * 100.0
		if dd_pct <= -absf(stop_loss_pct):
			return {"signal": "stop_loss", "reason": "stop_loss", "metric": SmaFormat.round_to(dd_pct, 2)}

	var series: Array[float] = closes.duplicate()
	if series.is_empty() or not is_equal_approx(series[series.size() - 1], last_price):
		series.append(last_price)
	var n := series.size()
	if n < 22:
		return {"signal": "hold", "reason": "warmup", "metric": 0.0}

	match strategy:
		"rsi_rebound":
			var r := SmaIndicators.rsi(series, 14)
			if is_nan(r):
				return {"signal": "hold", "reason": "warmup", "metric": 50.0}
			if holding_qty <= 0 and r <= 35.0:
				return {"signal": "buy", "reason": "rsi_oversold", "metric": SmaFormat.round_to(r, 1)}
			if holding_qty > 0 and r >= 65.0:
				return {"signal": "sell", "reason": "rsi_takeprofit", "metric": SmaFormat.round_to(r, 1)}
			return {"signal": "hold", "reason": "rsi_neutral", "metric": SmaFormat.round_to(r, 1)}

		"boll_revert":
			var mean := SmaIndicators.sma(series, 20)
			if is_nan(mean):
				return {"signal": "hold", "reason": "warmup", "metric": 0.0}
			var sq := 0.0
			for idx in range(n - 20, n):
				var diff := series[idx] - mean
				sq += diff * diff
			var std := sqrt(sq / 20.0)
			var lower := mean - 1.8 * std
			if holding_qty <= 0 and last_price <= lower * 1.005:
				return {"signal": "buy", "reason": "boll_lower", "metric": SmaFormat.round_to(lower, 2)}
			if holding_qty > 0 and last_price >= mean:
				return {"signal": "sell", "reason": "boll_mean", "metric": SmaFormat.round_to(mean, 2)}
			return {"signal": "hold", "reason": "boll_inside", "metric": SmaFormat.round_to(mean, 2)}

		"momentum_break":
			var s20 := SmaIndicators.sma(series, 20)
			var s10 := SmaIndicators.sma(series, 10)
			var prev10 := series[maxi(0, n - 11)]
			if is_nan(s20) or is_nan(s10) or prev10 <= 0.0:
				return {"signal": "hold", "reason": "warmup", "metric": 0.0}
			var mom10 := (last_price - prev10) / prev10 * 100.0
			if holding_qty <= 0 and mom10 >= 3.0 and last_price > s20:
				return {"signal": "buy", "reason": "mom_breakout", "metric": SmaFormat.round_to(mom10, 2)}
			if holding_qty > 0 and last_price < s10:
				return {"signal": "sell", "reason": "mom_fade", "metric": SmaFormat.round_to(mom10, 2)}
			return {"signal": "hold", "reason": "mom_wait", "metric": SmaFormat.round_to(mom10, 2)}

		_:
			# ma_cross: EMA(5) vs EMA(15)
			var fast := SmaIndicators.ema_series(series, 5)
			var slow := SmaIndicators.ema_series(series, 15)
			var f_now := float(fast[n - 1])
			var s_now := float(slow[n - 1])
			if is_nan(f_now) or is_nan(s_now):
				return {"signal": "hold", "reason": "warmup", "metric": 0.0}
			var spread := (f_now - s_now) / maxf(0.01, s_now) * 100.0
			if holding_qty <= 0 and f_now > s_now * 1.002:
				return {"signal": "buy", "reason": "ema_golden", "metric": SmaFormat.round_to(spread, 2)}
			if holding_qty > 0 and f_now < s_now * 0.998:
				return {"signal": "sell", "reason": "ema_death", "metric": SmaFormat.round_to(spread, 2)}
			return {"signal": "hold", "reason": "ema_hold", "metric": SmaFormat.round_to(spread, 2)}


static func _append_log(bot: Dictionary, entry: Dictionary) -> void:
	var logs: Array = bot.get("logs", [])
	logs.append(entry)
	if logs.size() > MAX_LOGS_PER_BOT:
		logs = logs.slice(logs.size() - MAX_LOGS_PER_BOT, logs.size())
	bot["logs"] = logs


## Executes one signal pass across all active bots (or a single target_bot_id
## when > 0) against the live SmaExchange. Returns summary events for toasts.
static func run_step(store: Dictionary, exchange: SmaExchange, day: int,
		target_bot_id: int = -1, force_same_day: bool = false) -> Dictionary:
	var norm := normalize_store(store)
	var events: Array = []
	if exchange == null:
		return {"store": norm, "events": events}
	var companies: Dictionary = exchange.state.get("companies", {})
	var account: Dictionary = exchange.state.get("account", {})
	var positions: Dictionary = account.get("positions", {})
	var bots: Array = norm["bots"]

	for i in bots.size():
		var bot: Dictionary = bots[i]
		if target_bot_id > 0 and int(bot["id"]) != target_bot_id:
			continue
		if bool(bot["paused"]):
			continue
		if not force_same_day and int(bot["lastSignalDay"]) == day:
			continue
		var tk := String(bot["ticker"])
		if not companies.has(tk):
			continue
		var comp: Dictionary = companies[tk]
		var last := float(comp.get("last", 0.0))
		if last <= 0.0:
			continue
		# Clamp tracked bot holding to actual account shares in case user sold manually.
		var actual_pos_qty := int(positions.get(tk, {}).get("qty", 0))
		var hold_qty := mini(int(bot["holdingQty"]), actual_pos_qty)
		bot["holdingQty"] = hold_qty
		if hold_qty <= 0:
			bot["entryPrice"] = 0.0

		var closes: Array[float] = []
		var daily_bars: Array = comp.get("series", {}).get("daily", comp.get("dailyBars", []))
		for bar in daily_bars:
			closes.append(float(bar.get("c", 0.0)))
		var eval := evaluate_signal(String(bot["strategy"]), closes, last, hold_qty,
			float(bot["entryPrice"]), float(bot["stopLossPct"]))
		bot["lastSignalDay"] = day
		var sig := String(eval["signal"])

		if sig == "buy" and hold_qty <= 0:
			var cash_avail := maxf(0.0, float(account.get("cash", 0.0)) * 0.96)
			var spend := minf(float(bot["budget"]), cash_avail)
			var buy_qty := int(floor(spend / maxf(0.01, last * 1.003)))
			if buy_qty > 0:
				var res: Dictionary = exchange.submit_order({
					"ticker": tk, "side": "buy", "type": "market", "qty": buy_qty,
				})
				if bool(res.get("ok", false)):
					var ord: Dictionary = res.get("order", {})
					var filled_qty := int(ord.get("filledQty", 0))
					var avg_px := float(ord.get("avgFillPrice", last))
					if avg_px <= 0.0:
						avg_px = last
					if filled_qty > 0:
						bot["holdingQty"] = filled_qty
						bot["entryPrice"] = SmaFormat.round_to(avg_px, 2)
						bot["lastAction"] = "buy"
						var log_entry := {
							"day": day, "action": "buy", "reason": String(eval["reason"]),
							"price": SmaFormat.round_to(avg_px, 2), "qty": filled_qty, "pnl": 0.0,
						}
						_append_log(bot, log_entry)
						events.append({"botId": int(bot["id"]), "ticker": tk, "action": "buy",
							"qty": filled_qty, "price": SmaFormat.round_to(avg_px, 2), "pnl": 0.0})
		elif (sig == "sell" or sig == "stop_loss") and hold_qty > 0:
			var avail := exchange.available_shares(tk)
			var sell_qty := mini(hold_qty, avail)
			if sell_qty > 0:
				var res: Dictionary = exchange.submit_order({
					"ticker": tk, "side": "sell", "type": "market", "qty": sell_qty,
				})
				if bool(res.get("ok", false)):
					var ord: Dictionary = res.get("order", {})
					var sold_qty := int(ord.get("filledQty", 0))
					var exit_px := float(ord.get("avgFillPrice", last))
					if exit_px <= 0.0:
						exit_px = last
					var fees := float(ord.get("fees", 0.0))
					if sold_qty > 0:
						var trade_pnl := SmaFormat.round_to(
							(exit_px - float(bot["entryPrice"])) * float(sold_qty) - fees, 2)
						bot["holdingQty"] = maxi(0, hold_qty - sold_qty)
						if int(bot["holdingQty"]) <= 0:
							bot["entryPrice"] = 0.0
						bot["trades"] = int(bot["trades"]) + 1
						if trade_pnl > 0.0:
							bot["wins"] = int(bot["wins"]) + 1
						bot["realizedPnl"] = SmaFormat.round_to(float(bot["realizedPnl"]) + trade_pnl, 2)
						bot["lastAction"] = sig
						var log_entry := {
							"day": day, "action": sig, "reason": String(eval["reason"]),
							"price": SmaFormat.round_to(exit_px, 2), "qty": sold_qty, "pnl": trade_pnl,
						}
						_append_log(bot, log_entry)
						events.append({"botId": int(bot["id"]), "ticker": tk, "action": sig,
							"qty": sold_qty, "price": SmaFormat.round_to(exit_px, 2), "pnl": trade_pnl})
		else:
			bot["lastAction"] = "hold"
		bots[i] = bot

	norm["bots"] = bots
	return {"store": norm, "events": events}


static func summary(store: Dictionary, companies: Dictionary) -> Dictionary:
	var norm := normalize_store(store)
	var bots: Array = norm["bots"]
	var active_count := 0
	var total_pnl := 0.0
	var total_trades := 0
	var total_wins := 0
	var enriched: Array = []
	for bot in bots:
		var tk := String(bot["ticker"])
		var last := float(companies.get(tk, {}).get("last", 0.0))
		var hold := int(bot["holdingQty"])
		var entry_px := float(bot["entryPrice"])
		var unreal := SmaFormat.round_to((last - entry_px) * float(hold), 2) if (hold > 0 and last > 0.0 and entry_px > 0.0) else 0.0
		var real_pnl := float(bot["realizedPnl"])
		var net := SmaFormat.round_to(real_pnl + unreal, 2)
		if not bool(bot["paused"]):
			active_count += 1
		total_pnl += net
		total_trades += int(bot["trades"])
		total_wins += int(bot["wins"])
		var row: Dictionary = bot.duplicate(true)
		row["lastPrice"] = last
		row["unrealizedPnl"] = unreal
		row["totalPnl"] = net
		row["winRatePct"] = SmaFormat.round_to(float(bot["wins"]) / float(bot["trades"]) * 100.0, 1) if int(bot["trades"]) > 0 else 0.0
		enriched.append(row)
	return {
		"bots": enriched,
		"count": bots.size(),
		"activeCount": active_count,
		"totalPnl": SmaFormat.round_to(total_pnl, 2),
		"totalTrades": total_trades,
		"winRatePct": SmaFormat.round_to(float(total_wins) / float(total_trades) * 100.0, 1) if total_trades > 0 else 0.0,
	}
