extends "res://tests/test_base.gd"


func run() -> void:
	describe("earnings-calendar")
	eq(SmaEarnings.quarter_for_report_day(76), SmaEarnings.NO_REPORT,
		"non-report day has no quarter")
	eq(SmaEarnings.quarter_for_report_day(14), -1,
		"the first base report day maps to quarter minus one")
	eq(SmaEarnings.quarter_for_report_day(77), 0,
		"the second base report day maps to quarter zero")
	var engine := SmaExchange.new("earnings-test", 100000.0)
	var eligible := SmaEarnings.eligible_tickers(engine.state)
	check(eligible.size() >= 30, "the whole stock catalog is eligible to report")
	var rows: Array = SmaEarnings.upcoming(engine.state, 0, 3)
	eq(rows.size(), 3, "upcoming calendar returns three reporting days")
	check(int(rows[0]["day"]) > 0, "the first upcoming report day is in the future")
	check(not rows[0]["tickers"].is_empty(), "the calendar row lists reporting companies")
	if rows.size() > 1:
		check(int(rows[1]["day"]) > int(rows[0]["day"]),
			"calendar days are ordered")

	describe("earnings-full-season")
	var season_engine := SmaExchange.new("earnings-season", 100000.0)
	var season_start := SmaFundamentals.report_day(-1)
	var seen := {}
	var first_events := {}
	var duplicates := 0
	var days_with_events := {}
	var first_event: Dictionary = {}
	var first_event_day := -1
	for offset in SmaFundamentals.SEASON_DAYS + 1:
		var day := season_start + offset
		for event in SmaEarnings.maybe_emit(season_engine.state, day):
			var ticker := String(event["ticker"])
			if seen.has(ticker):
				duplicates += 1
			seen[ticker] = day
			first_events[ticker] = event.duplicate(true)
			days_with_events[day] = true
			if first_event.is_empty():
				first_event = event
				first_event_day = day
	eq(duplicates, 0, "no company reports twice in one season")
	eq(seen.size(), eligible.size(), "every eligible company reports in the season")
	check(days_with_events.size() >= 10,
		"report dates are spread across many trading days")
	check(not first_event.is_empty(), "at least one company reports in the season")
	if not first_event.is_empty():
		eq(String(first_event["kind"]), "earnings", "event kind is earnings")
		check(String(first_event["template"]) in [
			"earningsBeat", "earningsMiss", "earningsInline"],
			"template is an earnings template")
		check(float(first_event["expectedEps"]) > 0.0, "consensus EPS is positive")
		check(String(first_event["guidance"]) in ["raise", "cut", "maintain"],
			"guidance is valid")
		var stored: Dictionary = season_engine.state["companies"] \
			[String(first_event["ticker"])].get("lastEarnings", {})
		eq(String(stored.get("template", "")), String(first_event["template"]),
			"company stores its last earnings")
		eq(int(SmaFundamentals.report_day_for(String(first_event["ticker"]), -1)),
			first_event_day, "event lands on the company's own report date")

	describe("earnings-determinism")
	var replay_engine := SmaExchange.new("earnings-season", 100000.0)
	var replay_events := {}
	for offset in SmaFundamentals.SEASON_DAYS + 1:
		var day := season_start + offset
		for event in SmaEarnings.maybe_emit(replay_engine.state, day):
			replay_events[String(event["ticker"])] = event
	eq(replay_events.size(), first_events.size(),
		"same seed produces the same reporting cohort")
	for ticker in first_events:
		var original: Dictionary = first_events[ticker]
		var replay: Dictionary = replay_events.get(ticker, {})
		eq(int(replay.get("day", -1)), int(original["day"]),
			"report date is deterministic")
		eq(String(replay.get("template", "")), String(original["template"]),
			"earnings template is deterministic")
		approx(float(replay.get("eps", 0.0)), float(original["eps"]), 0.0001,
			"EPS is deterministic")

	describe("earnings-non-report-day")
	var idle_engine := SmaExchange.new("earnings-idle", 100000.0)
	eq(SmaEarnings.maybe_emit(idle_engine.state, 35).size(), 0,
		"gap between seasons emits nothing")

	describe("earnings-exchange-hook")
	var hook_engine := SmaExchange.new("earnings-hook", 100000.0)
	hook_engine.state["dayIndex"] = first_event_day - 1
	hook_engine._close_session(SmaRng.new("earnings-hook"))
	eq(int(hook_engine.state["dayIndex"]), first_event_day,
		"session close reaches an earnings day")
	var earnings_today := 0
	for item in hook_engine.news_today():
		if String(item.get("kind", "")) == "earnings":
			earnings_today += 1
	check(earnings_today > 0, "session close emits earnings into newsToday")

	describe("earnings-report-date")
	var report := SmaFundamentals.report("APLA", -1)
	var report_day := SmaFundamentals.report_day_for("APLA", -1)
	eq(String(report["reportDate"]), SmaCalendar.iso_date(report_day),
		"the statement shows the company-specific report date")
	eq(int(SmaFundamentals.latest_quarter(report_day - 1, "APLA")), -2,
		"a company's quarter stays unavailable before its own report date")
	eq(int(SmaFundamentals.latest_quarter(report_day, "APLA")), -1,
		"the quarter becomes available on the company's report date")

	describe("earnings-expectations-vs-reality")
	var beat_but_drop := 0
	var beat_and_rise := 0
	for ticker in first_events.keys():
		var ev: Dictionary = first_events[ticker]
		check(String(ev.get("reactionReason", "")) in SmaEarnings.REASON_KEYS,
			"valid reaction attribution on %s" % ticker)
		if String(ev["template"]) == "earningsBeat":
			if float(ev["pct"]) < 0.0:
				beat_but_drop += 1
				var cs_after: Dictionary = season_engine.state["companies"][ticker]
				check(float(cs_after["high"]) > float(cs_after["last"]),
					"beat-but-drop prints upper-wick distribution candle: %s" % ticker)
			elif float(ev["pct"]) > 0.0:
				beat_and_rise += 1
	check(beat_and_rise > 0, "solid beats with supportive outlook rise")
	check(beat_but_drop > 0, "some EPS beats still drop due to guidance/valuation/margins")

	var mock_beat_cut := {
		"income": {"eps": 2.15, "revenue": 1000.0},
		"highlights": {"guidance": "cut", "grossMarginDeltaBps": 20, "capexYoYPct": 4.0},
	}
	var r_cut := SmaEarnings.evaluate_reaction("NVDO", 0, mock_beat_cut, 2.00, 3.0, 35.0, {})
	eq(String(r_cut["template"]), "earningsBeat", "headline EPS beat detected")
	eq(String(r_cut["reactionReason"]), "guidanceCutOnBeat", "guidance cut overrides EPS beat")
	check(float(r_cut["impact"]) < 0.0, "stock drops when guidance is cut despite EPS beat")

	var mock_sell_news := {
		"income": {"eps": 2.07, "revenue": 1000.0},
		"highlights": {"guidance": "maintain", "grossMarginDeltaBps": 15, "capexYoYPct": 5.0},
	}
	var r_stn := SmaEarnings.evaluate_reaction("NVDO", 0, mock_sell_news, 2.00, 14.0, 52.0, {})
	eq(String(r_stn["template"]), "earningsBeat", "modest EPS beat after big run-up")
	eq(String(r_stn["reactionReason"]), "sellTheNews", "sell-the-news attribution")
	check(float(r_stn["impact"]) < 0.0, "stock drops on priced-in run-up despite EPS beat")

	var mock_margin_slip := {
		"income": {"eps": 2.08, "revenue": 1000.0},
		"highlights": {"guidance": "maintain", "grossMarginDeltaBps": -140, "capexYoYPct": 5.0},
	}
	var r_gm := SmaEarnings.evaluate_reaction("APLA", 0, mock_margin_slip, 2.00, 0.0, 26.0, {})
	eq(String(r_gm["reactionReason"]), "marginSlipOnBeat", "gross-margin slip attribution")
	check(float(r_gm["impact"]) < 0.0, "stock drops when gross margin slips despite EPS beat")

	var mock_capex := {
		"income": {"eps": 2.10, "revenue": 1000.0},
		"highlights": {"guidance": "maintain", "grossMarginDeltaBps": 10, "capexYoYPct": 34.0},
	}
	var r_capex := SmaEarnings.evaluate_reaction("MSFY", 0, mock_capex, 2.00, 0.0, 32.0, {})
	eq(String(r_capex["reactionReason"]), "capexShockOnBeat", "CapEx surge attribution")
	check(float(r_capex["impact"]) < 0.0, "stock drops on FCF/CapEx shock despite EPS beat")

	var mock_turnaround := {
		"income": {"eps": 1.90, "revenue": 950.0},
		"highlights": {"guidance": "raise", "grossMarginDeltaBps": 40, "capexYoYPct": -5.0},
	}
	var r_turn := SmaEarnings.evaluate_reaction("BOEN", 0, mock_turnaround, 2.00, -11.0, 18.0, {})
	eq(String(r_turn["template"]), "earningsMiss", "headline EPS miss detected")
	eq(String(r_turn["reactionReason"]), "badNewsPricedIn", "bad-news-priced-in attribution")
	check(float(r_turn["impact"]) > 0.0, "stock rallies when turnaround guidance overrides EPS miss")
