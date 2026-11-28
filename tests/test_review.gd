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

	describe("beta22-quant-bots")
	var bot_store := SmaQuantBots.normalize_store({})
	var dep1 := SmaQuantBots.deploy(bot_store, "NVDO", "ma_cross", 15000.0, 6.0, 1, 2)
	check(bool(dep1["ok"]), "deploys first quant bot into slot 1")
	bot_store = dep1["store"]
	var dep2 := SmaQuantBots.deploy(bot_store, "MSFY", "rsi_rebound", 10000.0, 8.0, 1, 2)
	eq(bool(dep2["ok"]), false, "enforces max bot slot cap")
	var up_series: Array[float] = []
	for i in 30:
		up_series.append(100.0 + float(i) * 1.6)
	var ma_sig := SmaQuantBots.evaluate_signal("ma_cross", up_series, 150.0, 0, 0.0, 6.0)
	eq(String(ma_sig["signal"]), "buy", "EMA golden cross triggers buy signal")
	var sl_sig := SmaQuantBots.evaluate_signal("ma_cross", up_series, 88.0, 50, 100.0, 6.0)
	eq(String(sl_sig["signal"]), "stop_loss", "hard stop-loss triggers exit on -12% drop")
	var ex_bot := SmaExchange.new("beta22-bot-run", 100000.0, 1.0)
	# Force an uptrend tail on NVDO so ma_cross buys immediately on run_step
	var nvdo_bars: Array = ex_bot.state["companies"]["NVDO"]["series"]["daily"]
	var base_p := float(ex_bot.state["companies"]["NVDO"]["last"])
	for k in range(maxi(0, nvdo_bars.size() - 25), nvdo_bars.size()):
		var step_p := base_p * (0.82 + float(k - (nvdo_bars.size() - 25)) * 0.008)
		nvdo_bars[k]["c"] = step_p
	var step_res := SmaQuantBots.run_step(bot_store, ex_bot, 5, -1, true)
	var bot_sum := SmaQuantBots.summary(step_res["store"], ex_bot.state["companies"])
	eq(int(bot_sum["count"]), 1, "summary reports 1 bot")
	check(int(bot_sum["bots"][0]["holdingQty"]) > 0, "live bot executed real market buy order")

	describe("beta22-risk-sizer")
	var rs_long := SmaRiskSizer.calculate(100.0, 95.0, 115.0, 100000.0, 2.0, "buy", 100000.0)
	check(bool(rs_long["ok"]), "valid long R:R calculation succeeds")
	eq(int(rs_long["qty"]), 400, "risk $2,000 / $5 stop = 400 shares")
	approx(float(rs_long["rrRatio"]), 3.0, 0.01, "R:R is 1 : 3.0")
	var rs_bad := SmaRiskSizer.calculate(100.0, 105.0, 115.0, 100000.0, 2.0, "buy", 100000.0)
	eq(bool(rs_bad["ok"]), false, "rejects stop-loss above entry on long")
	var rs_short := SmaRiskSizer.calculate(100.0, 104.0, 88.0, 100000.0, 1.0, "short", 100000.0)
	check(bool(rs_short["ok"]), "valid short R:R calculation succeeds")
	eq(int(rs_short["qty"]), 250, "short risk $1,000 / $4 stop = 250 shares")
	approx(float(rs_short["rrRatio"]), 3.0, 0.01, "short R:R is 1 : 3.0")

	describe("beta22-journal-and-office-perks")
	var j_fills := [
		{"day": 1, "orderId": "O1", "ticker": "NVDO", "action": "openLong", "second": 10, "realized": 0.0},
		{"day": 2, "orderId": "O2", "ticker": "NVDO", "action": "closeLong", "second": 20, "realized": 820.0},
		{"day": 3, "orderId": "O3", "ticker": "TSLO", "action": "closeLong", "second": 30, "realized": -340.0},
	]
	var j_store := {}
	j_store = SmaJournal.set_entry(j_store, SmaJournal.fill_key(j_fills[0], 0), "dip_buy", "Support bounce")
	j_store = SmaJournal.set_entry(j_store, SmaJournal.fill_key(j_fills[2], 2), "fomo", "Chased spike")
	var j_sum := SmaJournal.summarize_by_tag(j_fills, j_store)
	eq(int(j_sum["taggedCount"]), 2, "counts 2 explicit journal entries")
	eq(String(j_sum["bestTag"]["id"]), "dip_buy", "inherits entry tag onto close fill & finds best edge")
	approx(float(j_sum["bestTag"]["realizedPnl"]), 820.0, 0.01, "dip_buy attributes +$820 realized PnL")
	eq(String(j_sum["worstTag"]["id"]), "fomo", "identifies fomo as biggest capital leak")
	var off := SmaOffice.create_state()
	eq(int(SmaOffice.active_perks(off)["botSlots"]), 1, "base office has 1 bot slot")
	off["owned"] = ["espresso_bar", "research_board", "bloomberg_rig", "server_rack"]
	var perks := SmaOffice.active_perks(off)
	eq(int(perks["botSlots"]), 3, "server_rack + bloomberg_rig expands to 3 bot slots")
	eq(int(perks["xpBonusPct"]), 25, "espresso_bar + research_board grants +25% XP")
	check(bool(perks["hasDeskSentiment"]), "bloomberg_rig unlocks desk sentiment")
	eq(SmaOffice.scaled_xp(off, 20), 25, "scaled_xp applies +25% bonus cleanly")

	describe("beta22-flash-chart-trainer")
	var fl_round := SmaFlashTrainer.generate_round(ex_bot.state["companies"], "flash-test", 0)
	check(bool(fl_round["ok"]), "generates valid blind K-line round")
	eq((fl_round["visibleBars"] as Array).size(), SmaFlashTrainer.VISIBLE_BARS, "provides 40 masked history bars")
	eq((fl_round["futureBars"] as Array).size(), SmaFlashTrainer.FUTURE_BARS, "holds 15 hidden future bars")
	var fl_stats := SmaFlashTrainer.normalize_stats({})
	var pick := "long" if float(fl_round["rawReturnPct"]) >= 0.0 else "short"
	var fl_res := SmaFlashTrainer.settle(fl_round, pick, fl_stats)
	check(bool(fl_res["ok"]), "settles flash trainer choice cleanly")
	eq(int(fl_res["stats"]["played"]), 1, "increments played count")
	check(int(fl_res["xp"]) >= 8, "awards Academy XP without modifying cash")
