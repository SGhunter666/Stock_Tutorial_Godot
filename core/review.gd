## Trade review and account timeline. Pure read models over the player ledger:
## the exchange remains the only writer, this module only summarizes what
## already happened.
class_name SmaReview
extends RefCounted


static func timeline(account: Dictionary, limit: int = 12) -> Array:
	var rows: Array = []
	for trade in account.get("trades", []):
		rows.append({
			"kind": "stock", "day": int(trade.get("day", 0)),
			"second": int(trade.get("second", 0)),
			"ticker": String(trade.get("ticker", "")),
			"side": String(trade.get("side", "")),
			"qty": int(trade.get("qty", 0)),
			"price": float(trade.get("price", 0.0)),
			"amount": SmaFormat.round_to(float(trade.get("qty", 0))
				* float(trade.get("price", 0.0)), 2),
			"realized": float(trade.get("realized", 0.0)),
		})
	for trade in account.get("optionTrades", []):
		rows.append({
			"kind": "option", "day": int(trade.get("day", 0)),
			"second": int(trade.get("tick", 0)),
			"ticker": String(trade.get("ticker", "")),
			"side": String(trade.get("side", "")),
			"qty": int(trade.get("qty", 0)),
			"price": float(trade.get("premium", 0.0)),
			"amount": float(trade.get("gross", 0.0)),
			"realized": float(trade.get("realized", 0.0)),
			"label": "%s %s" % [String(trade.get("optionType", "")).to_upper(),
				SmaFormat.num(float(trade.get("strike", 0.0)), 2)],
		})
	for trade in account.get("futuresTrades", []):
		rows.append({
			"kind": "futures", "day": int(trade.get("day", 0)),
			"second": int(trade.get("tick", 0)),
			"ticker": String(trade.get("ticker", "")),
			"side": String(trade.get("action", trade.get("side", ""))),
			"qty": int(trade.get("qty", 0)),
			"price": float(trade.get("price", 0.0)),
			"amount": float(trade.get("margin", 0.0)),
			"realized": float(trade.get("realized", 0.0)),
		})
	for dividend in account.get("dividends", []):
		rows.append({
			"kind": "dividend", "day": int(dividend.get("day", 0)),
			"second": 0, "ticker": String(dividend.get("ticker", "")),
			"side": "dividend", "qty": int(dividend.get("qty", 0)),
			"price": float(dividend.get("dps", 0.0)),
			"amount": float(dividend.get("amount", 0.0)),
			"realized": 0.0,
			"label": String(dividend.get("type", "")),
		})
	rows.sort_custom(func(a, b):
		if int(a["day"]) != int(b["day"]):
			return int(a["day"]) > int(b["day"])
		return int(a["second"]) > int(b["second"]))
	return rows.slice(0, maxi(1, limit))


## Portfolio risk read model: annualized daily volatility, peak-to-trough
## drawdown, gross exposure and a Herfindahl concentration index.
static func portfolio_risk(account: Dictionary, equity_value: float,
		long_rows: Array, short_rows: Array) -> Dictionary:
	var history: Array = account.get("equityHistory", [])
	var returns: Array[float] = []
	var previous := 0.0
	var has_previous := false
	for point in history:
		var value := float(point.get("equity", 0.0))
		if has_previous and previous > 0.0 and value > 0.0:
			returns.append(value / previous - 1.0)
		previous = value
		has_previous = true
	var annual_vol := 0.0
	if returns.size() >= 2:
		var mean := 0.0
		for value in returns:
			mean += value
		mean /= float(returns.size())
		var variance := 0.0
		for value in returns:
			variance += pow(value - mean, 2.0)
		variance /= float(returns.size() - 1)
		annual_vol = sqrt(variance) * sqrt(252.0) * 100.0
	var peak := -INF
	var max_drawdown := 0.0
	for point in history:
		var value := float(point.get("equity", 0.0))
		peak = maxf(peak, value)
		if peak > 0.0:
			max_drawdown = maxf(max_drawdown, (peak - value) / peak * 100.0)
	peak = maxf(peak, equity_value)
	if peak > 0.0:
		max_drawdown = maxf(max_drawdown, (peak - equity_value) / peak * 100.0)
	var gross := 0.0
	var weights: Array[float] = []
	for row in long_rows:
		var market_value := absf(float(row.get("marketValue", 0.0)))
		gross += market_value
		if equity_value > 0.0:
			weights.append(market_value / equity_value)
	for row in short_rows:
		var market_value := absf(float(row.get("marketValue", 0.0)))
		gross += market_value
		if equity_value > 0.0:
			weights.append(market_value / equity_value)
	var exposure := gross / equity_value * 100.0 if equity_value > 0.0 else 0.0
	var hhi := 0.0
	var largest := 0.0
	for weight in weights:
		hhi += weight * weight * 10000.0
		largest = maxf(largest, weight * 100.0)
	var risk_level := "low"
	if annual_vol >= 35.0 or max_drawdown >= 20.0:
		risk_level = "high"
	elif annual_vol >= 18.0 or max_drawdown >= 10.0:
		risk_level = "medium"
	return {
		"hasVolatility": returns.size() >= 2,
		"annualVolPct": annual_vol,
		"maxDrawdownPct": max_drawdown,
		"exposurePct": exposure,
		"hhi": hhi,
		"largestPct": largest,
		"riskLevel": risk_level,
	}


static func summary(account: Dictionary, equity_value: float, day: int) -> Dictionary:
	var closed: Array = []
	for trade in account.get("trades", []):
		var action := String(trade.get("action", ""))
		if action == "closeLong" or action == "closeShort" or String(
				trade.get("side", "")) == "sell" or String(trade.get("side", "")) == "cover":
			closed.append(trade)
	var wins := 0
	var best := {}
	var worst := {}
	var gross_profit := 0.0
	var gross_loss := 0.0
	for trade in closed:
		var realized := float(trade.get("realized", 0.0))
		if realized > 0.0:
			wins += 1
			gross_profit += realized
		elif realized < 0.0:
			gross_loss += absf(realized)
		if best.is_empty() or realized > float(best.get("realized", 0.0)):
			best = trade
		if worst.is_empty() or realized < float(worst.get("realized", 0.0)):
			worst = trade
	var fees := float(account.get("fees", 0.0))
	var dividends := 0.0
	for row in account.get("dividends", []):
		dividends += float(row.get("amount", 0.0))
	var initial := float(account.get("initialCash", 0.0))
	var total_return := (equity_value / initial - 1.0) * 100.0 if initial > 0.0 else 0.0
	var largest := 0.0
	for ticker in account.get("positions", {}).keys():
		var position: Dictionary = account["positions"][ticker]
		largest = maxf(largest, absf(float(position.get("qty", 0))
			* float(position.get("last", position.get("avgCost", 0.0)))))
	var concentration := largest / equity_value * 100.0 if equity_value > 0.0 else 0.0
	return {
		"day": day,
		"trades": account.get("trades", []).size() + account.get("optionTrades", []).size() \
			+ account.get("futuresTrades", []).size(),
		"closedTrades": closed.size(),
		"winRatePct": float(wins) / float(closed.size()) * 100.0 if not closed.is_empty() else 0.0,
		"profitFactor": gross_profit / gross_loss if gross_loss > 0.0 else (
			0.0 if gross_profit <= 0.0 else 99.0),
		"realizedPnl": float(account.get("realizedPnl", 0.0)) \
			+ float(account.get("optionRealized", 0.0)) \
			+ float(account.get("futuresRealized", 0.0)),
		"fees": fees,
		"dividends": SmaFormat.round_to(dividends, 2),
		"totalReturnPct": total_return,
		"openPositions": account.get("positions", {}).size() + account.get("shorts", {}).size(),
		"concentrationPct": concentration,
		"bestTrade": best,
		"worstTrade": worst,
	}


## Behavioral finance diagnostics over the player's actual fills and holdings.
## Detects Disposition Effect, FOMO chasing, overtrading fee drag, sizing
## concentration, and drawdown/event discipline. Pure and UI-free.
static func behavioral_diagnostics(account: Dictionary, equity_value: float,
		day: int, companies: Dictionary = {}) -> Dictionary:
	var trades: Array = account.get("trades", [])
	var option_trades: Array = account.get("optionTrades", [])
	var futures_trades: Array = account.get("futuresTrades", [])
	var total_fills := trades.size() + option_trades.size() + futures_trades.size()
	var initial_cash := maxf(1.0, float(account.get("initialCash", 100000.0)))
	var fees := float(account.get("fees", 0.0))

	var open_day: Dictionary = {}
	var win_holds: Array[float] = []
	var loss_holds: Array[float] = []
	var win_pnls: Array[float] = []
	var loss_pnls: Array[float] = []
	var entry_count := 0
	var chase_count := 0
	var earnings_gamble_count := 0
	var add_to_loser_count := 0
	var avg_entry_price: Dictionary = {}

	for t in trades:
		var tk := String(t.get("ticker", ""))
		var action := String(t.get("action", ""))
		var side := String(t.get("side", ""))
		var tday := int(t.get("day", 0))
		var price := float(t.get("price", 0.0))
		var is_open := action in ["openLong", "openShort"] or side in ["buy", "short"]
		var is_close := action in ["closeLong", "closeShort"] or side in ["sell", "cover"]
		if is_open and not is_close:
			entry_count += 1
			if open_day.has(tk) and avg_entry_price.has(tk):
				var prev_p := float(avg_entry_price[tk])
				if (action == "openLong" or side == "buy") and price < prev_p * 0.96:
					add_to_loser_count += 1
			if not open_day.has(tk):
				open_day[tk] = tday
				avg_entry_price[tk] = price
			if companies.has(tk):
				var cs: Dictionary = companies[tk]
				var prev_c := maxf(0.01, float(cs.get("prevClose", price)))
				if (action == "openLong" or side == "buy") and (price - prev_c) / prev_c >= 0.032:
					chase_count += 1
			if not SmaEtfs.is_etf(tk):
				var next_er := SmaEarnings.next_for_ticker(tk, tday)
				if not next_er.is_empty() and int(next_er.get("daysUntil", 99)) <= 2:
					var notional := price * float(t.get("qty", 0))
					if notional > equity_value * 0.18:
						earnings_gamble_count += 1
		elif is_close:
			var realized := float(t.get("realized", 0.0))
			var held_days := float(maxi(0, tday - int(open_day.get(tk, tday))))
			if realized > 0.0:
				win_holds.append(held_days)
				win_pnls.append(realized)
			elif realized < 0.0:
				loss_holds.append(held_days)
				loss_pnls.append(absf(realized))
			open_day.erase(tk)
			avg_entry_price.erase(tk)

	var positions: Dictionary = account.get("positions", {})
	var bag_hold_count := 0
	var largest_pos := 0.0
	for tk in positions.keys():
		var pos: Dictionary = positions[tk]
		var qty := int(pos.get("qty", 0))
		if qty <= 0:
			continue
		var avg := float(pos.get("avgCost", 0.0))
		var mark := float(companies.get(tk, {}).get("last", pos.get("last", avg)))
		largest_pos = maxf(largest_pos, absf(float(qty) * mark))
		if avg > 0.0 and (mark - avg) / avg <= -0.07:
			bag_hold_count += 1
			loss_holds.append(float(maxi(1, day - int(open_day.get(tk, day)))))
	for tk in account.get("shorts", {}).keys():
		var sp: Dictionary = account["shorts"][tk]
		var sqty := int(sp.get("qty", 0))
		if sqty <= 0:
			continue
		var savg := float(sp.get("avgPrice", 0.0))
		var smark := float(companies.get(tk, {}).get("last", savg))
		largest_pos = maxf(largest_pos, absf(float(sqty) * smark))
		if savg > 0.0 and (savg - smark) / savg <= -0.07:
			bag_hold_count += 1

	var avg_win_hold := _avg_float(win_holds)
	var avg_loss_hold := _avg_float(loss_holds)
	var avg_win := _avg_float(win_pnls)
	var avg_loss := _avg_float(loss_pnls)
	var payoff_ratio := (avg_win / avg_loss) if avg_loss > 0.0 else (2.0 if avg_win > 0.0 else 1.0)
	var concentration_pct := (largest_pos / maxf(1.0, equity_value)) * 100.0
	var fee_drag_pct := (fees / initial_cash) * 100.0
	var trades_per_day := float(total_fills) / float(maxi(1, day + 1))
	var chase_ratio_pct := (float(chase_count) / float(maxi(1, entry_count))) * 100.0

	var peak := initial_cash
	var max_dd_pct := 0.0
	for pt in account.get("equityHistory", []):
		var eq := float(pt.get("equity", initial_cash))
		peak = maxf(peak, eq)
		max_dd_pct = maxf(max_dd_pct, (peak - eq) / maxf(1.0, peak) * 100.0)
	peak = maxf(peak, equity_value)
	max_dd_pct = maxf(max_dd_pct, (peak - equity_value) / maxf(1.0, peak) * 100.0)

	var disp_score := 78.0
	if not win_holds.is_empty() and not loss_holds.is_empty():
		if avg_loss_hold > avg_win_hold + 1.5:
			disp_score -= minf(38.0, (avg_loss_hold - avg_win_hold) * 6.5)
		elif avg_win_hold >= avg_loss_hold:
			disp_score += 12.0
	if not win_pnls.is_empty() and not loss_pnls.is_empty():
		if payoff_ratio < 0.85:
			disp_score -= minf(28.0, (0.85 - payoff_ratio) * 45.0)
		elif payoff_ratio >= 1.35:
			disp_score += 12.0
	disp_score -= float(bag_hold_count) * 9.0
	disp_score -= float(add_to_loser_count) * 8.0
	disp_score = clampf(disp_score, 15.0, 98.0)

	var chase_score := clampf(92.0 - chase_ratio_pct * 0.85 - float(add_to_loser_count) * 5.0, 18.0, 98.0)
	var overtrade_score := clampf(95.0 - maxf(0.0, trades_per_day - 2.5) * 9.5 - fee_drag_pct * 18.0, 18.0, 98.0)
	var sizing_score := clampf(96.0 - maxf(0.0, concentration_pct - 24.0) * 1.45, 15.0, 98.0)
	var risk_score := clampf(94.0 - max_dd_pct * 2.4 - float(earnings_gamble_count) * 12.0, 15.0, 98.0)

	var overall := (disp_score + chase_score + overtrade_score + sizing_score + risk_score) / 5.0
	var grade := "S" if overall >= 88.0 else ("A" if overall >= 78.0 else (
		"B" if overall >= 66.0 else ("C" if overall >= 52.0 else "D")))

	var biases: Array = []
	if disp_score < 65.0 or (avg_loss_hold > avg_win_hold + 1.5 and not loss_holds.is_empty()):
		biases.append({"id": "disposition", "severity": "high" if disp_score < 50.0 else "medium"})
	if chase_score < 68.0 or chase_count >= 2:
		biases.append({"id": "fomoChase", "severity": "high" if chase_score < 52.0 else "medium"})
	if overtrade_score < 68.0 or trades_per_day >= 5.0:
		biases.append({"id": "overtrading", "severity": "high" if overtrade_score < 52.0 else "medium"})
	if sizing_score < 68.0 or concentration_pct >= 45.0:
		biases.append({"id": "concentration", "severity": "high" if concentration_pct >= 60.0 else "medium"})
	if add_to_loser_count >= 1:
		biases.append({"id": "averagingDown", "severity": "medium"})
	if earnings_gamble_count >= 1:
		biases.append({"id": "earningsGamble", "severity": "medium"})

	var archetype := "calmObserver"
	var mentor_speaker := "story.char.lin_lan.name"
	var mentor_comment := "diag.comment.calmObserver"
	if total_fills < 2:
		archetype = "calmObserver"
		mentor_speaker = "story.char.lin_lan.name"
		mentor_comment = "diag.comment.calmObserver"
	elif overall >= 82.0 and biases.is_empty():
		archetype = "disciplinedCompounder"
		mentor_speaker = "story.char.lin_lan.name"
		mentor_comment = "diag.comment.disciplinedCompounder"
	elif sizing_score <= disp_score and sizing_score <= overtrade_score and concentration_pct >= 42.0:
		archetype = "concentratedGambler"
		mentor_speaker = "story.char.su_he.name"
		mentor_comment = "diag.comment.concentratedGambler"
	elif disp_score <= overtrade_score and disp_score <= chase_score and disp_score < 68.0:
		archetype = "dispositionHolder"
		mentor_speaker = "story.char.lao_chen.name"
		mentor_comment = "diag.comment.dispositionHolder"
	elif overtrade_score <= chase_score and overtrade_score < 70.0:
		archetype = "overtrader"
		mentor_speaker = "story.char.chen_xi.name"
		mentor_comment = "diag.comment.overtrader"
	elif chase_score < 72.0:
		archetype = "fomoChaser"
		mentor_speaker = "story.char.lao_chen.name"
		mentor_comment = "diag.comment.fomoChaser"
	else:
		archetype = "balancedLearner"
		mentor_speaker = "story.char.lin_lan.name"
		mentor_comment = "diag.comment.balancedLearner"

	return {
		"hasEnoughData": total_fills >= 2,
		"totalFills": total_fills,
		"overallScore": SmaFormat.round_to(overall, 1),
		"grade": grade,
		"archetypeKey": "diag.archetype.%s" % archetype,
		"mentorSpeakerKey": mentor_speaker,
		"mentorCommentKey": mentor_comment,
		"scores": {
			"disposition": SmaFormat.round_to(disp_score, 1),
			"chaseControl": SmaFormat.round_to(chase_score, 1),
			"overtrading": SmaFormat.round_to(overtrade_score, 1),
			"sizing": SmaFormat.round_to(sizing_score, 1),
			"risk": SmaFormat.round_to(risk_score, 1),
		},
		"metrics": {
			"avgWinHoldDays": SmaFormat.round_to(avg_win_hold, 1),
			"avgLossHoldDays": SmaFormat.round_to(avg_loss_hold, 1),
			"payoffRatio": SmaFormat.round_to(payoff_ratio, 2),
			"feeDragPct": SmaFormat.round_to(fee_drag_pct, 2),
			"tradesPerDay": SmaFormat.round_to(trades_per_day, 1),
			"concentrationPct": SmaFormat.round_to(concentration_pct, 1),
			"maxDrawdownPct": SmaFormat.round_to(max_dd_pct, 1),
			"chaseCount": chase_count,
			"bagHoldCount": bag_hold_count,
			"addToLoserCount": add_to_loser_count,
			"earningsGambleCount": earnings_gamble_count,
		},
		"biases": biases,
	}


static func _avg_float(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values:
		total += v
	return total / float(values.size())
