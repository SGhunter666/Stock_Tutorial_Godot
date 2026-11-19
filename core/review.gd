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
