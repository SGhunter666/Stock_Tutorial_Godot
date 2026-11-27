extends "res://tests/test_base.gd"


func run() -> void:
	describe("exchange-init")
	var exchange := SmaExchange.new("test-seed", 100000.0)
	eq(exchange.state["companies"].size(), 108, "universe has 100 companies and 8 ETFs")
	eq(exchange.state["quotes"].size(), 108, "every instrument has a quote")
	approx(exchange.equity(), 100000.0, 0.001, "initial equity equals cash")

	describe("exchange-buy")
	var buy := exchange.submit_order({"ticker": "APLA", "side": "buy", "type": "market", "qty": 10})
	check(bool(buy["ok"]), "market buy accepted")
	eq(buy["order"]["status"], "filled", "market buy filled")
	eq(int(exchange.state["account"]["positions"]["APLA"]["qty"]), 10, "long position updated")
	check(float(exchange.state["account"]["cash"]) < 100000.0, "cash decreased")
	check(float(exchange.state["account"]["fees"]) > 0.0, "fee charged")
	var avg_cost := float(exchange.state["account"]["positions"]["APLA"]["avgCost"])
	check(avg_cost > 0.0, "average cost recorded")

	describe("exchange-sell")
	var cash_before := float(exchange.state["account"]["cash"])
	var sell := exchange.submit_order({"ticker": "APLA", "side": "sell", "type": "market", "qty": 5})
	check(bool(sell["ok"]), "market sell accepted")
	eq(int(exchange.state["account"]["positions"]["APLA"]["qty"]), 5, "position reduced")
	check(float(exchange.state["account"]["cash"]) > cash_before, "sell proceeds credited")
	eq(int(exchange.state["account"]["trades"].size()), 2, "two fills recorded")

	describe("exchange-short")
	var short_result := exchange.submit_order({"ticker": "MSFY", "side": "short", "type": "market", "qty": 10})
	check(bool(short_result["ok"]), "short accepted")
	eq(int(exchange.state["account"]["shorts"]["MSFY"]["qty"]), 10, "short position recorded")
	var cover := exchange.submit_order({"ticker": "MSFY", "side": "cover", "type": "market", "qty": 5})
	check(bool(cover["ok"]), "cover accepted")
	eq(int(exchange.state["account"]["shorts"]["MSFY"]["qty"]), 5, "short position reduced")
	var oversell := exchange.submit_order({"ticker": "APLA", "side": "sell", "type": "market", "qty": 1000000})
	eq(oversell["error"], "order.insufficientShares", "oversell rejected")

	describe("exchange-resting-order")
	var last := float(exchange.quote("NVDO")["last"])
	var limit := exchange.submit_order({
		"ticker": "NVDO", "side": "buy", "type": "limit",
		"qty": 20, "limitPrice": last * 0.5,
	})
	check(bool(limit["ok"]), "limit order accepted")
	eq(exchange.open_order_rows("player").size(), 1, "limit order is working")
	var cancel := exchange.cancel_order(String(limit["order"]["id"]))
	check(bool(cancel["ok"]), "cancel accepted")
	eq(exchange.open_order_rows("player").size(), 0, "cancelled order is no longer working")

	describe("exchange-liquidity")
	var huge_player := exchange.submit_order({"ticker": "APLA", "side": "buy", "type": "market", "qty": 1000000})
	eq(huge_player["error"], "order.insufficientMargin", "player order beyond margin is rejected")
	var huge := exchange.submit_order({
		"ticker": "APLA", "side": "buy", "type": "market", "qty": 1000000,
		"owner": "sim:test",
	})
	check(bool(huge["ok"]), "simulated order is accepted but not fully filled")
	check(int(huge["order"]["filledQty"]) > 0, "simulated order partially fills")
	check(int(huge["order"]["remaining"]) > 0, "simulated order leaves a remainder")
	check(String(huge["order"]["reason"]) == "insufficientLiquidity", "remainder reason recorded")

	describe("exchange-fill-events")
	var event_exchange := SmaExchange.new("fill-events", 100000.0)
	event_exchange.submit_order({"ticker": "APLA", "side": "buy", "type": "market", "qty": 10})
	event_exchange.clear_player_fills()
	var stop_price := float(event_exchange.quote("APLA")["last"]) + 1.0
	var stop := event_exchange.submit_order({
		"ticker": "APLA", "side": "sell", "action": "closeLong",
		"type": "stop", "qty": 10, "stopPrice": stop_price,
	})
	check(bool(stop["ok"]), "stop order accepted")
	event_exchange.advance_second()
	check(event_exchange.last_player_fills.size() >= 1,
		"player fills survive simulated-trader activity")
	var stop_filled := false
	for fill in event_exchange.last_player_fills:
		if String(fill.get("ticker", "")) == "APLA" and String(fill.get("action", "")) == "closeLong":
			stop_filled = true
	check(stop_filled, "stop order filled during the simulated second")

	describe("exchange-oco")
	var oco_exchange := SmaExchange.new("oco", 100000.0)
	oco_exchange.submit_order({"ticker": "VISO", "side": "buy", "type": "market", "qty": 10})
	var oco_reference := float(oco_exchange.quote("VISO")["last"])
	var oco := oco_exchange.submit_oco({
		"ticker": "VISO", "action": "closeLong", "qty": 10,
		"takeProfitPrice": oco_reference * 1.2, "stopPrice": oco_reference * 0.8,
	})
	check(bool(oco["ok"]), "OCO pair accepted")
	eq(oco["orders"].size(), 2, "OCO creates two legs")
	eq(oco_exchange.open_order_rows("player").size(), 2, "both OCO legs are working")
	var first_id := String(oco["orders"][0]["id"])
	oco_exchange.cancel_order(first_id)
	eq(oco_exchange.open_order_rows("player").size(), 0, "cancelling one leg cancels the sibling")

	describe("exchange-determinism")
	var left := SmaExchange.new("repeatable", 100000.0)
	var right := SmaExchange.new("repeatable", 100000.0)
	left.advance_seconds(30)
	right.advance_seconds(30)
	for ticker in left.state["companies"].keys():
		approx(float(left.quote(ticker)["last"]), float(right.quote(ticker)["last"]), 0.0,
			"same seed quote %s" % ticker)
	approx(left.equity(), right.equity(), 0.0, "same seed equity")

	describe("exchange-fast-forward-parity")
	var ff_full := SmaExchange.new("ff-parity", 100000.0)
	var ff_fast := SmaExchange.new("ff-parity", 100000.0)
	for _i in 120:
		ff_full.advance_second(true)
		ff_fast.advance_second(false)
	for ticker in ff_full.state["companies"].keys():
		approx(float(ff_full.quote(ticker)["last"]), float(ff_fast.quote(ticker)["last"]), 0.0,
			"fast-forward price parity %s" % ticker)
	approx(ff_full.equity(), ff_fast.equity(), 0.0, "fast-forward equity parity")
	eq(str(ff_full.state["rngState"]), str(ff_fast.state["rngState"]),
		"fast-forward RNG state parity")

	describe("exchange-save-roundtrip")
	var restored := SmaExchange.from_dict(exchange.to_dict())
	check(restored != null, "save payload restores")
	approx(restored.equity(), exchange.equity(), 0.001, "equity survives restore")
	eq(int(restored.state["account"]["positions"]["APLA"]["qty"]), 5, "position survives restore")
	eq(str(restored.state["rngState"]), str(exchange.state["rngState"]), "rng state survives restore")
	restored.advance_seconds(10)
	exchange.advance_seconds(10)
	approx(float(restored.quote("APLA")["last"]), float(exchange.quote("APLA")["last"]), 0.0,
		"restored market continues identically")

	describe("exchange-session-rollover")
	var clock_exchange := SmaExchange.new("rollover", 100000.0)
	clock_exchange.submit_order({"ticker": "APLA", "side": "buy", "type": "market", "qty": 5})
	clock_exchange.advance_seconds(60)
	check(clock_exchange.get_candles("APLA", "1m").size() > 0, "intraday candle recorded")
	clock_exchange.state["second"] = SmaExchange.SESSION_SECONDS - 1
	clock_exchange.advance_second()
	eq(int(clock_exchange.state["dayIndex"]), 1, "session close advances the day")
	eq(int(clock_exchange.state["second"]), 0, "clock resets to the open")
	var daily := clock_exchange.get_candles("APLA", "1D")
	ge(float(daily.size()), 1.0, "daily candle finalised")
	approx(float(clock_exchange.state["companies"]["APLA"]["prevClose"]),
		float(clock_exchange.state["companies"]["APLA"]["last"]), 0.0001,
		"previous close resets to the last price")
	var next_session := clock_exchange.get_candles("APLA", "1m")
	eq(next_session.size(), 1, "new session starts with one candle")
	eq(next_session[0]["time"], "09:30", "next session restarts the minute chart")
	_check_live_minutes()
	_check_intraday_quotes()

	describe("exchange-margin")
	var snapshot := SmaMargin.margin_snapshot(clock_exchange.state)
	check(is_finite(float(snapshot["equity"])), "margin equity finite")
	check(is_finite(float(snapshot["maintenanceExcess"])), "maintenance excess finite")
	ge(float(snapshot["buyingPower"]), 0.0, "buying power non-negative")
	eq(snapshot["status"], "ok", "healthy account is not in a margin call")
	var easy_fee := SmaMargin.borrow_fee_rate(SmaCompanyCatalog.get_company("APLA"))
	var hard_fee := SmaMargin.borrow_fee_rate(SmaCompanyCatalog.get_company("CONB"))
	le(easy_fee, 0.01, "mega-cap blue chip has easy-to-borrow short fee")
	ge(hard_fee, 0.25, "volatile speculative stock has hard-to-borrow short fee")
	check(hard_fee > easy_fee * 20.0, "hard-to-borrow rate is vastly higher than blue-chip rate")

	describe("exchange-liquidity-stress")
	var stress_ex := SmaExchange.new("stress-spread-test", 100000.0)
	var calm_q := stress_ex.quote("NVDO")
	var calm_spread := float(calm_q["ask"]) - float(calm_q["bid"])
	var nvdo_cs: Dictionary = stress_ex.state["companies"]["NVDO"]
	nvdo_cs["last"] = float(nvdo_cs["prevClose"]) * 0.91
	nvdo_cs["fairValue"] = nvdo_cs["last"]
	stress_ex.refresh_liquidity("NVDO")
	stress_ex.state["quotes"].erase("NVDO")
	var panic_q := stress_ex.quote("NVDO")
	var panic_spread := float(panic_q["ask"]) - float(panic_q["bid"])
	check(panic_spread > calm_spread * 2.0,
		"9% crash widens market-maker bid-ask spread significantly")
	ge(float(panic_q["spreadMult"]), 2.2, "quote exposes liquidity stress multiplier")

	describe("exchange-dividends")
	var dividend_exchange := SmaExchange.new("dividend-test", 100000.0)
	dividend_exchange.state["account"]["positions"]["APLA"] = {
		"qty": 100, "avgCost": 100.0,
	}
	dividend_exchange.state["dayIndex"] = SmaCalendar.QUARTER_DAYS - 1
	dividend_exchange.state["second"] = SmaExchange.SESSION_SECONDS - 1
	dividend_exchange.advance_second()
	var dividend_rows: Array = dividend_exchange.state["account"].get("dividends", [])
	eq(dividend_rows.size(), 1, "quarterly dividend paid")
	if not dividend_rows.is_empty():
		check(float(dividend_rows[0]["amount"]) > 0.0, "dividend amount is positive")
		eq(String(dividend_rows[0]["ticker"]), "APLA", "dividend attributed to the holding")


func _check_live_minutes() -> void:
	describe("live-one-minute-chart")
	var series := SmaMinuteSeries.create()
	var date := SmaCalendar.iso_date(0)
	var bars := SmaMinuteSeries.candles(series, "1m", date, 0, 100.0)
	eq(bars.size(), 1, "opening price is available before the first trade")
	check(bars[0]["partial"] and bars[0]["c"] == 100.0 and bars[0]["v"] == 0,
		"first candle starts flat with zero volume")
	SmaMinuteSeries.apply_trade(series, {"date": date, "second": 4, "price": 104.0, "qty": 5})
	SmaMinuteSeries.apply_trade(series, {"date": date, "second": 59, "price": 98.0, "qty": 2})
	bars = SmaMinuteSeries.candles(series, "1m", date, 59, 100.0)
	eq(bars.size(), 1, "elapsed seconds update the same candle")
	check(bars[0]["o"] == 104.0 and bars[0]["h"] == 104.0 and bars[0]["l"] == 98.0
		and bars[0]["c"] == 98.0 and bars[0]["v"] == 7, "minute OHLCV derives from real simulated fills")
	bars = SmaMinuteSeries.candles(series, "1m", date, 60, 100.0)
	eq(bars.size(), 2, "minute boundary creates exactly one new candle without a fill")
	check(not bars[0]["partial"] and bars[1]["partial"] and bars[1]["time"] == "09:31"
		and bars[1]["c"] == 98.0 and bars[1]["v"] == 0, "only the newest candle remains open")
	var previous: Dictionary = bars[0]
	SmaMinuteSeries.apply_trade(series, {"date": date, "second": 65, "price": 101.0, "qty": 3})
	bars = SmaMinuteSeries.candles(series, "1m", date, 65, 100.0)
	eq(bars[0], previous, "a new-minute trade leaves the previous candle intact")
	check(bars[1]["c"] == 101.0 and bars[1]["v"] == 3, "trade updates only its own minute")
	bars = SmaMinuteSeries.candles(series, "1m", date, 180, 100.0)
	check(bars.size() == 4 and bars[2]["time"] == "09:32" and bars[2]["v"] == 0
		and not bars[2]["partial"] and bars[3]["partial"], "quiet minutes follow the clock without fake volume")


func _check_intraday_quotes() -> void:
	describe("per-second-reference-price")
	var market := SmaExchange.new("live-quote-regression")
	var previous := float(market.get_candles("APLA").back()["c"])
	var first_closed: Dictionary = {}
	for second in range(1, 62):
		market.advance_second()
		var bars := market.get_candles("APLA")
		var live: Dictionary = bars.back()
		check(live["partial"] and float(live["c"]) != previous,
			"the active candle changes on simulated second %d" % second)
		previous = float(live["c"])
		if second == 60:
			first_closed = bars[0].duplicate()
			check(not first_closed["partial"] and live["o"] == live["c"]
				and live["h"] == live["l"], "the new minute starts with a single price")
		if second == 61:
			eq(bars[0], first_closed, "closed candle is frozen while the new candle moves")
			check(live["o"] != live["c"], "the new candle grows from its first price")
	var displayed_volume := 0
	for bar in market.get_candles("APLA"):
		displayed_volume += int(bar["v"])
	eq(displayed_volume, market.quote("APLA")["volume"], "reference ticks do not create volume")
	var restored := SmaExchange.from_dict(JSON.parse_string(JSON.stringify(market.to_dict())))
	check(restored != null, "a save with an active reference candle restores")
	if restored != null:
		market.advance_second()
		restored.advance_second()
		eq(restored.get_candles("APLA"), market.get_candles("APLA"),
			"the price and wick continue identically after save and load")
	var legacy := SmaMinuteSeries.create()
	var date := SmaCalendar.iso_date(0)
	SmaMinuteSeries.apply_trade(legacy, {"date": date, "second": 60, "price": 98.0, "qty": 2})
	SmaMinuteSeries.apply_trade(legacy, {"date": date, "second": 60, "price": 102.0, "qty": 3})
	SmaMinuteSeries.apply_quote(legacy, date, 60, 101.0, 100.0)
	var next: Dictionary = SmaMinuteSeries.candles(legacy, "1m", date, 60, 100.0).back()
	check(next["o"] == next["c"] and next["h"] == next["l"] and next["v"] == 5,
		"the first quote at a minute boundary starts flat even if trades arrived first")
