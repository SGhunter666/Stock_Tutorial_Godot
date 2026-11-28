## Timeline ordering and review metrics.
extends "res://tests/test_base.gd"


func run() -> void:
	describe("review-summary")
	var account := {
		"initialCash": 100000.0,
		"cash": 50000.0,
		"fees": 12.0,
		"realizedPnl": 300.0,
		"optionRealized": 50.0,
		"futuresRealized": -20.0,
		"positions": {"APLA": {"qty": 100, "avgCost": 100.0, "last": 120.0}},
		"shorts": {},
		"trades": [
			{"ticker": "APLA", "side": "buy", "action": "openLong", "qty": 100,
				"price": 100.0, "realized": 0.0, "day": 1, "second": 10},
			{"ticker": "APLA", "side": "sell", "action": "closeLong", "qty": 50,
				"price": 120.0, "realized": 1000.0, "day": 2, "second": 20},
			{"ticker": "MSFY", "side": "sell", "action": "closeLong", "qty": 20,
				"price": 90.0, "realized": -400.0, "day": 3, "second": 30},
		],
		"optionTrades": [
			{"ticker": "APLA", "side": "buy", "optionType": "call", "strike": 100.0,
				"qty": 1, "premium": 5.0, "gross": 500.0, "realized": 0.0,
				"day": 4, "tick": 5},
		],
		"futuresTrades": [],
		"dividends": [
			{"ticker": "APLA", "qty": 100, "dps": 0.25, "amount": 25.0, "day": 5},
		],
	}
	var summary := SmaReview.summary(account, 105000.0, 6)
	eq(int(summary["closedTrades"]), 2, "two closed stock trades")
	approx(float(summary["winRatePct"]), 50.0, 0.01, "win rate is one of two")
	approx(float(summary["profitFactor"]), 2.5, 0.01, "profit factor uses gross profit and loss")
	approx(float(summary["realizedPnl"]), 330.0, 0.01, "realized P&L includes all desks")
	approx(float(summary["dividends"]), 25.0, 0.01, "dividends summed")
	approx(float(summary["totalReturnPct"]), 5.0, 0.01, "total return from initial cash")
	approx(float(summary["concentrationPct"]), 12000.0 / 105000.0 * 100.0, 0.01,
		"largest position concentration")

	describe("review-timeline")
	var timeline := SmaReview.timeline(account, 10)
	eq(timeline.size(), 5, "all ledger rows returned")
	eq(String(timeline[0]["kind"]), "dividend", "newest row first")
	eq(int(timeline[0]["day"]), 5, "timeline sorted by day")
	eq(String(timeline[1]["kind"]), "option", "option trade included")
	eq(String(timeline[2]["kind"]), "stock", "stock trade included")
	var limited := SmaReview.timeline(account, 2)
	eq(limited.size(), 2, "limit respected")

	describe("review-risk")
	var risk_account := {
		"equityHistory": [
			{"day": 0, "equity": 100000.0},
			{"day": 1, "equity": 110000.0},
			{"day": 2, "equity": 99000.0},
			{"day": 3, "equity": 105000.0},
		],
	}
	var risk := SmaReview.portfolio_risk(risk_account, 105000.0,
		[{"marketValue": 12000.0}], [{"marketValue": 4500.0}])
	check(bool(risk["hasVolatility"]), "daily history produces a volatility sample")
	approx(float(risk["maxDrawdownPct"]), 10.0, 0.01, "peak-to-trough drawdown")
	approx(float(risk["exposurePct"]), 16500.0 / 105000.0 * 100.0, 0.01,
		"gross exposure includes long and short books")
	approx(float(risk["largestPct"]), 12000.0 / 105000.0 * 100.0, 0.01,
		"largest position weight")
	approx(float(risk["hhi"]), (pow(12000.0 / 105000.0, 2.0)
		+ pow(4500.0 / 105000.0, 2.0)) * 10000.0, 0.1, "concentration HHI")
	eq(String(risk["riskLevel"]), "high", "large daily moves map to high risk")

	describe("behavioral-diagnostics")
	var disp_account := {
		"initialCash": 100000.0,
		"fees": 45.0,
		"equityHistory": [{"day": 0, "equity": 100000.0}, {"day": 14, "equity": 96000.0}],
		"positions": {"NVDO": {"qty": 450, "avgCost": 130.0, "last": 116.0}},
		"shorts": {},
		"trades": [
			{"ticker": "APLA", "side": "buy", "action": "openLong", "qty": 50, "price": 100.0, "realized": 0.0, "day": 1},
			{"ticker": "APLA", "side": "sell", "action": "closeLong", "qty": 50, "price": 102.0, "realized": 100.0, "day": 2},
			{"ticker": "BOEN", "side": "buy", "action": "openLong", "qty": 50, "price": 100.0, "realized": 0.0, "day": 1},
			{"ticker": "BOEN", "side": "sell", "action": "closeLong", "qty": 50, "price": 86.0, "realized": -700.0, "day": 10},
		],
		"optionTrades": [],
		"futuresTrades": [],
	}
	var diag := SmaReview.behavioral_diagnostics(disp_account, 96000.0, 14)
	check(bool(diag["hasEnoughData"]), "diagnostics activates with >= 2 fills")
	check(float(diag["metrics"]["avgLossHoldDays"]) > float(diag["metrics"]["avgWinHoldDays"]),
		"detects longer loss hold than win hold")
	var bias_ids: Array = []
	for b in diag["biases"]:
		bias_ids.append(String(b["id"]))
	check(bias_ids.has("disposition"), "detects Disposition Effect bias")
	check(bias_ids.has("concentration"), "detects high single-name concentration")

	describe("market-events-desk")
	var ex := SmaExchange.new("beta21-event-seed", 100000.0, 1.0)
	var acad := SmaAcademy.create_state()
	eq(SmaMarketEvents.active_event(ex.state, acad).is_empty(), true, "no event on day 0")
	ex.state["dayIndex"] = 1
	var evt := SmaMarketEvents.active_event(ex.state, acad)
	check(not evt.is_empty(), "IPO event active on day 1")
	eq(String(evt["kind"]), "ipo", "slot 0 is Unicorn IPO event")
	check(SmaMarketEvents.has_pending_event(ex.state, acad), "event starts pending")
	var res := SmaMarketEvents.resolve(ex.state, acad, "light", 100000.0)
	check(bool(res.get("ok", false)), "IPO light stake resolves cleanly")
	check(not SmaMarketEvents.has_pending_event(ex.state, acad), "resolved event no longer pending")
	var dup := SmaMarketEvents.resolve(ex.state, acad, "heavy", 100000.0)
	eq(bool(dup.get("ok", false)), false, "cannot resolve same event twice")
	ex.state["dayIndex"] = 4
	var call_evt := SmaMarketEvents.active_event(ex.state, acad)
	eq(String(call_evt["kind"]), "earnings_call", "slot 1 is Earnings Call Q&A")
	var call_res := SmaMarketEvents.resolve(ex.state, acad, "drop", 100000.0)
	check(bool(call_res.get("ok", false)) and float(call_res["resolution"]["cashDelta"]) > 0.0,
		"correct NVDO sell-the-news earnings call awards research alpha")

	describe("indicators-macd-rsi-series")
	var up_closes: Array = []
	for i in 60:
		up_closes.append(100.0 + float(i) * 1.4 + sin(float(i) * 0.4) * 2.0)
	var macd := SmaIndicators.macd_series(up_closes, 12, 26, 9)
	eq(macd["dif"].size(), 60, "MACD dif matches length")
	check(not is_nan(float(macd["hist"][59])), "MACD histogram valid after warmup")
	approx(float(macd["hist"][59]), (float(macd["dif"][59]) - float(macd["dea"][59])) * 2.0,
		0.0001, "MACD hist equals 2*(DIF-DEA)")
	var rsi_arr := SmaIndicators.rsi_series(up_closes, 14)
	eq(rsi_arr.size(), 60, "RSI series matches length")
	check(float(rsi_arr[59]) > 60.0 and float(rsi_arr[59]) <= 100.0,
		"RSI reflects persistent uptrend in [60, 100]")
