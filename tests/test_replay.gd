## Historical replay of stock positions and daily equity.
extends "res://tests/test_base.gd"


func _bar(day: int, close_price: float) -> Dictionary:
	return {"d": SmaCalendar.iso_date(day), "o": close_price, "h": close_price,
		"l": close_price, "c": close_price, "v": 1000}


func _state() -> Dictionary:
	return {
		"dayIndex": 3,
		"companies": {
			"APLA": {"last": 125.0, "fairValue": 125.0,
				"series": {"daily": [_bar(1, 52.5), _bar(2, 115.0), _bar(3, 125.0)]}},
		},
		"account": {
			"cash": 100200.0,
			"equityHistory": [
				{"day": 0, "equity": 100000.0}, {"day": 1, "equity": 100050.0},
				{"day": 2, "equity": 100100.0}, {"day": 3, "equity": 100200.0},
			],
			"trades": [
				{"ticker": "APLA", "action": "openLong", "side": "buy", "qty": 10,
					"price": 100.0, "fee": 1.0, "day": 1, "second": 10},
				{"ticker": "APLA", "action": "openLong", "side": "buy", "qty": 10,
					"price": 110.0, "fee": 1.0, "day": 2, "second": 20},
				{"ticker": "APLA", "action": "closeLong", "side": "sell", "qty": 5,
					"price": 120.0, "fee": 1.0, "day": 3, "second": 30},
			],
			"dividends": [{"ticker": "APLA", "amount": 10.0, "day": 2}],
			"shorts": {},
		},
		"corporateActions": [{"type": "split", "ticker": "APLA", "day": 2,
			"ratio": 2.0, "amount": 0.0}],
	}


func run() -> void:
	describe("replay-days")
	var state := _state()
	eq(SmaReplay.max_day(state), 3, "max day from state")
	var before_split := SmaReplay.snapshot(state, 1)
	eq(int(before_split["positions"][0]["qty"]), 10, "historical shares use the original basis")
	approx(float(before_split["positions"][0]["close"]), 105.0, 0.01,
		"historical price uses the same basis as the historical shares")
	var day_two := SmaReplay.snapshot(state, 2)
	eq(int(day_two["day"]), 2, "snapshot day")
	eq(int(day_two["positions"].size()), 1, "one position held")
	eq(int(day_two["positions"][0]["qty"]), 30, "split precedes the same-day buy")
	approx(float(day_two["positions"][0]["avgCost"]), 70.0, 0.01,
		"weighted average cost")
	approx(float(day_two["positions"][0]["close"]), 115.0, 0.01,
		"historical close used")
	approx(float(day_two["stockValue"]), 3450.0, 0.01, "stock exposure")
	approx(float(day_two["equity"]), 100100.0, 0.01, "equity from snapshot")
	approx(float(day_two["dailyPnl"]), 50.0, 0.01, "daily P&L")
	eq(int(day_two["events"].size()), 3, "trade, dividend and corporate action listed")

	describe("replay-later")
	var day_three := SmaReplay.snapshot(state, 3)
	eq(int(day_three["positions"][0]["qty"]), 25, "sale reduces the split-adjusted position")
	approx(float(day_three["stockValue"]), 3125.0, 0.01, "value at latest close")
	approx(float(day_three["dailyPnl"]), 100.0, 0.01, "latest daily P&L")
	eq(day_three["curve"].size(), 4, "curve includes every day through the selection")

	describe("replay-empty")
	var empty := SmaReplay.snapshot(_state(), 0)
	eq(empty["positions"].is_empty(), true, "no positions before the first trade")
	approx(float(empty["equity"]), 100000.0, 0.01, "initial equity")

	describe("replay-short-and-delisting")
	var short_state := {
		"account": {"trades": [
			{"ticker": "APLA", "action": "openShort", "qty": 10, "price": 100.0, "day": 0},
			{"ticker": "APLA", "action": "closeShort", "qty": 2, "price": 80.0, "day": 1},
		]},
		"companies": {"APLA": {"last": 80.0, "series": {"daily": [_bar(1, 80.0)]}}},
		"corporateActions": [{"type": "delisting", "ticker": "APLA", "day": 2}],
	}
	var short_day := SmaReplay.snapshot(short_state, 1)
	eq(int(short_day["positions"][0]["qty"]), 8, "cover reduces short quantity")
	approx(float(short_day["positions"][0]["pnl"]), 160.0, 0.01, "falling price profits a short")
	eq(SmaReplay.snapshot(short_state, 2)["positions"].size(), 0, "delisting closes the short")

	describe("replay-after-ledger-trimming")
	var exchange := SmaExchange.new("replay-limit")
	var entry := exchange.submit_order({"ticker": "APLA", "side": "buy", "qty": 10})
	eq(int(entry["order"]["filledQty"]), 10, "opening shares are filled")
	var close_price := float(exchange.state["companies"]["APLA"]["last"])
	var close_equity := exchange.equity()
	var live := SmaReplay.snapshot(exchange.state, 0, close_equity)
	approx(float(live["equity"]), close_equity, 0.001, "latest replay uses live equity")
	exchange.state["second"] = SmaExchange.SESSION_SECONDS - 1
	exchange.advance_second()
	for index in SmaExchange.ACCOUNT_TRADE_LIMIT:
		exchange.submit_order({"ticker": "GOGL", "side": "buy" if index % 2 == 0 else "sell", "qty": 1})
		if index % 25 == 24:
			exchange.advance_seconds(30)
	var ledger: Array = exchange.state["account"]["trades"]
	eq(ledger.size(), SmaExchange.ACCOUNT_TRADE_LIMIT, "account ledger remains bounded")
	check(not ledger.any(func(trade): return trade["ticker"] == "APLA"),
		"the original entry has left the recent ledger")
	var saved := SmaExchange.from_dict(JSON.parse_string(JSON.stringify(exchange.to_dict())))
	check(saved != null, "the new replay data survives save and load")
	var past := SmaReplay.snapshot(saved.state, 0)
	eq(int(past["positions"][0]["qty"]), 10, "closed session retains the original shares")
	approx(float(past["positions"][0]["close"]), close_price, 0.001, "closed session retains its own price")
	approx(float(past["equity"]), close_equity, 0.001, "closed session retains its equity")
	var latest := SmaReplay.snapshot(saved.state, SmaReplay.max_day(saved.state), saved.equity())
	eq(int(latest["positions"][0]["qty"]), 10, "the current snapshot uses the real position")
	saved.state["account"].erase("replayHistory")
	check(not SmaReplay.snapshot(saved.state, 0)["positionDataAvailable"],
		"old, trimmed histories report missing holdings explicitly")
