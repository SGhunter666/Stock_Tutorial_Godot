## Quarterly earnings events tied to the real simulated financial statements,
## priced through a multi-factor "Expectations vs. Reality" market engine.
##
## A stock's post-earnings move depends NOT ONLY on whether EPS beat consensus,
## but also on:
##   1. Forward management guidance ("raise" / "maintain" / "cut")
##   2. Pre-earnings 15-day price run-up & P/E valuation stretch ("Sell the news")
##   3. Gross-margin expansion/compression & CapEx surge ("Quality of beat")
##   4. Macro real-rate & risk-appetite regime ("Valuation multiple headwind")
##   5. Prior selloff / turnaround expectations ("Bad news already priced in")
class_name SmaEarnings
extends RefCounted

const QUARTER_DAYS := 63
const REPORT_LAG_DAYS := 14
const NO_REPORT := -999
const BEAT_THRESHOLD := 2.0
const MISS_THRESHOLD := -2.0
const MAX_IMPACT := 0.11

const REASON_KEYS := [
	"beatAndRaise",
	"solidBeat",
	"sellTheNews",
	"guidanceCutOnBeat",
	"marginSlipOnBeat",
	"capexShockOnBeat",
	"macroHeadwindOnBeat",
	"badNewsPricedIn",
	"doubleMiss",
	"valuationMiss",
	"inlineDigest",
]


static func quarter_for_report_day(day: int) -> int:
	if day < REPORT_LAG_DAYS:
		return NO_REPORT
	if (day - REPORT_LAG_DAYS) % QUARTER_DAYS != 0:
		return NO_REPORT
	return int((day - REPORT_LAG_DAYS) / QUARTER_DAYS) - 1


static func eligible_tickers(state: Dictionary) -> Array:
	var tickers: Array = []
	for ticker in state.get("companies", {}).keys():
		var cs: Dictionary = state["companies"][ticker]
		var company: Dictionary = cs.get("company", {})
		if bool(company.get("isEtf", false)) or bool(cs.get("delisted", false)):
			continue
		if SmaCompanyCatalog.get_company(String(ticker)).is_empty():
			continue
		tickers.append(String(ticker))
	tickers.sort()
	return tickers


## Seasons do not overlap, so a day belongs to at most one reporting quarter.
static func _quarters_in_season(day: int) -> Array:
	var result: Array = []
	var latest := SmaFundamentals.latest_quarter(day)
	for quarter in range(latest, latest + 3):
		var base := SmaFundamentals.report_day(quarter)
		if day >= base and day <= base + SmaFundamentals.SEASON_DAYS:
			result.append(quarter)
	return result


## Wall Street consensus EPS already prices in the company's secular growth rate
## plus analyst dispersion, so high-growth names face high bars to clear.
static func expected_eps(ticker: String, quarter: int) -> float:
	var company := SmaCompanyCatalog.get_company(ticker)
	var qoq_growth := clampf(float(company.get("qoqGrowth", 0.0)), -0.08, 0.12)
	var expected_yoy_mult := pow(1.0 + qoq_growth, 4.0)
	var base := 0.0
	var prior_year := SmaFundamentals.report(ticker, quarter - 4)
	if not prior_year.is_empty():
		base = float(prior_year["income"].get("eps", 0.0)) * expected_yoy_mult
	if base <= 0.0:
		var prior_quarter := SmaFundamentals.report(ticker, quarter - 1)
		if not prior_quarter.is_empty():
			base = float(prior_quarter["income"].get("eps", 0.0)) * (1.0 + qoq_growth)
	if base <= 0.0:
		base = 0.02
	var rng := SmaRng.new("earnings-consensus:%s:%d" % [ticker, quarter])
	return maxf(0.01, SmaFormat.round_to(base * rng.range_float(0.965, 1.045), 4))


static func _guidance(ticker: String, quarter: int, actual: Dictionary) -> String:
	var highlights: Dictionary = actual.get("highlights", {})
	if highlights.has("guidance"):
		var g := String(highlights["guidance"])
		if g in ["raise", "maintain", "cut"]:
			return g
	var prior_year := SmaFundamentals.report(ticker, quarter - 4)
	if prior_year.is_empty():
		return "maintain"
	var prior_revenue := float(prior_year["income"].get("revenue", 0.0))
	if prior_revenue <= 0.0:
		return "maintain"
	var revenue := float(actual["income"].get("revenue", 0.0))
	var growth := revenue / prior_revenue - 1.0
	if growth >= 0.06:
		return "raise"
	if growth <= -0.03:
		return "cut"
	return "maintain"


static func _pre_earnings_runup_pct(cs: Dictionary) -> float:
	var daily: Array = cs.get("series", {}).get("daily", [])
	var prev_close := float(cs.get("prevClose", cs.get("last", 0.0)))
	if daily.size() < 5 or prev_close <= 0.01:
		return 0.0
	var lookback := mini(15, daily.size())
	var anchor := float(daily[daily.size() - lookback].get("c", prev_close))
	if anchor <= 0.01:
		return 0.0
	return SmaFormat.round_to((prev_close / anchor - 1.0) * 100.0, 1)


static func _live_pe_ratio(cs: Dictionary) -> float:
	var company: Dictionary = cs.get("company", {})
	var raw_pe: Variant = company.get("financials", {}).get("pe", 22.0)
	var base_pe := float(raw_pe) if raw_pe != null else 22.0
	var base_price := maxf(0.01, float(company.get("price", 100.0)))
	var cur_price := maxf(0.01, float(cs.get("prevClose", cs.get("last", base_price))))
	if base_pe <= 0.0:
		return 22.0
	return clampf(base_pe * (cur_price / base_price), 4.0, 140.0)


## Pure multi-factor pricing evaluation. Exposed publicly so tests and UI tools
## can verify how headline EPS, whisper expectations, guidance, margins, CapEx,
## and macro conditions interact.
static func evaluate_reaction(ticker: String, quarter: int, actual: Dictionary,
		expected: float, pre_runup_pct: float = 0.0, pe_ratio: float = 22.0,
		macro: Dictionary = {}) -> Dictionary:
	var eps := float(actual.get("income", {}).get("eps", 0.0))
	var surprise := (eps - expected) / absf(expected) * 100.0 \
		if absf(expected) > 0.0001 else 0.0
	var guidance := _guidance(ticker, quarter, actual)
	var highlights: Dictionary = actual.get("highlights", {})
	var gm_delta_bps := int(highlights.get("grossMarginDeltaBps", 0))
	var capex_yoy_pct := float(highlights.get("capexYoYPct", 0.0))
	var real_rate := float(macro.get("realRate", 0.4))
	var risk_appetite := int(macro.get("riskAppetite", 55))

	var template := "earningsBeat" if surprise >= BEAT_THRESHOLD else (
		"earningsMiss" if surprise <= MISS_THRESHOLD else "earningsInline")

	# Buy-side "whisper number" rises when the stock rallied ahead of the print
	# or trades at an expensive valuation multiple ("priced for perfection").
	var pe_stretch := clampf((pe_ratio - 30.0) * 0.11, 0.0, 4.5)
	var whisper_bar := clampf(pre_runup_pct * 0.55 + pe_stretch, -4.5, 11.5)
	var effective_surprise := surprise - whisper_bar

	var impact := 0.0
	var reason := "inlineDigest"

	if template == "earningsBeat":
		if guidance == "cut":
			# 1. Beat Q earnings, but cut forward guidance -> Market sells the future!
			impact = clampf(-0.032 - maxf(0.0, pre_runup_pct) * 0.0022
				- clampf(-effective_surprise, 0.0, 8.0) * 0.0035, -MAX_IMPACT, -0.018)
			reason = "guidanceCutOnBeat"
		elif (pre_runup_pct >= 5.5 or (pe_ratio >= 36.0 and pre_runup_pct >= 1.5)) \
				and effective_surprise < 2.2 and guidance != "raise":
			# 2. "Buy the rumor, sell the news" / Whisper miss after big pre-runup!
			impact = clampf(-0.018 - maxf(0.0, pre_runup_pct) * 0.0034
				- maxf(0.0, whisper_bar - surprise) * 0.004, -MAX_IMPACT, -0.012)
			reason = "sellTheNews"
		elif gm_delta_bps <= -75 and guidance != "raise":
			# 3. Revenue/EPS beat came via discounting or cost pressure (margin slip)!
			impact = clampf(-0.015 + float(gm_delta_bps) / 10000.0 * 1.9, -MAX_IMPACT, -0.010)
			reason = "marginSlipOnBeat"
		elif capex_yoy_pct >= 19.0 and pe_ratio >= 24.0 and guidance != "raise":
			# 4. Heavy AI / fab CapEx surge spooks free-cash-flow investors!
			impact = clampf(-0.016 - (capex_yoy_pct - 18.0) * 0.0014, -MAX_IMPACT, -0.010)
			reason = "capexShockOnBeat"
		elif guidance == "maintain" and surprise < 6.5 and pe_ratio >= 27.0 \
				and (real_rate >= 1.6 or risk_appetite <= 38):
			# 5. Tight monetary / risk-off macro compresses high-P/E multiples!
			impact = clampf(-0.012 - maxf(0.0, real_rate - 1.3) * 0.014, -0.065, -0.008)
			reason = "macroHeadwindOnBeat"
		elif guidance == "raise":
			# 6. Classic "Beat and Raise" (Davis Double Play)!
			impact = clampf(0.026 + clampf(effective_surprise, 0.0, 14.0) * 0.0048, 0.018, MAX_IMPACT)
			reason = "beatAndRaise"
		else:
			impact = clampf(0.012 + clampf(effective_surprise, -1.0, 12.0) * 0.0042, 0.006, 0.082)
			reason = "solidBeat"
	elif template == "earningsMiss":
		if guidance == "raise" or (pre_runup_pct <= -6.5 and guidance != "cut") \
				or (pe_ratio <= 13.5 and surprise > -7.5 and guidance != "cut"):
			# 7. "Bad news priced in" / Turnaround guidance sparks relief rally!
			impact = clampf(0.018 + (0.022 if guidance == "raise" else 0.0)
				+ maxf(0.0, -pre_runup_pct - 5.0) * 0.0028, 0.012, MAX_IMPACT)
			reason = "badNewsPricedIn"
		elif guidance == "cut":
			impact = clampf(-0.034 + clampf(surprise, -14.0, 0.0) * 0.0045, -MAX_IMPACT, -0.024)
			reason = "doubleMiss"
		else:
			impact = clampf(-0.014 + clampf(surprise, -12.0, 0.0) * 0.0042, -0.085, -0.009)
			reason = "valuationMiss"
	else:
		# Inline EPS: forward guidance & prior positioning decide the move!
		if guidance == "cut":
			impact = clampf(-0.024 - maxf(0.0, pre_runup_pct) * 0.002, -0.075, -0.014)
			reason = "guidanceCutOnBeat"
		elif pre_runup_pct >= 6.0 and guidance != "raise":
			impact = clampf(-0.015 - pre_runup_pct * 0.0025, -0.065, -0.010)
			reason = "sellTheNews"
		elif guidance == "raise":
			impact = clampf(0.018 + clampf(surprise, -2.0, 2.0) * 0.003, 0.012, 0.055)
			reason = "beatAndRaise"
		else:
			impact = clampf(effective_surprise * 0.0025, -0.022, 0.022)
			reason = "inlineDigest"

	return {
		"template": template,
		"surprisePct": roundf(surprise * 10.0) / 10.0,
		"guidance": guidance,
		"impact": impact,
		"reactionReason": reason,
		"preRunupPct": roundf(pre_runup_pct * 10.0) / 10.0,
		"gmDeltaBps": gm_delta_bps,
		"capexYoYPct": roundf(capex_yoy_pct * 10.0) / 10.0,
	}


static func _apply_shock(state: Dictionary, ticker: String, impact: float,
		news: Dictionary) -> void:
	var cs: Dictionary = state["companies"].get(ticker, {})
	if cs.is_empty():
		return
	var base := float(cs["company"].get("price", cs["fairValue"]))
	var prev_close := maxf(0.01, float(cs.get("prevClose", cs.get("last", base))))
	var target_last := maxf(0.01, SmaFormat.round_to(prev_close * (1.0 + impact), 2))
	var template := String(news.get("template", "earningsInline"))
	var open_price := target_last
	var post_drift := 1.0 + impact * 0.08
	if template == "earningsBeat" and impact < 0.0:
		# Classic "Good news, stock drops" candle: opening headline spike up,
		# followed by heavy institutional distribution leaving an upper wick!
		open_price = maxf(0.01, SmaFormat.round_to(prev_close * 1.015, 2))
		post_drift = 0.996
	elif template == "earningsMiss" and impact > 0.0:
		# Classic "Bad news priced in" reversal candle: opening headline dip,
		# followed by value buying & short covering leaving a lower wick!
		open_price = maxf(0.01, SmaFormat.round_to(prev_close * 0.985, 2))
		post_drift = 1.004
	else:
		open_price = maxf(0.01, SmaFormat.round_to(prev_close * (1.0 + impact * 0.78), 2))
	var high_price := maxf(open_price, target_last)
	var low_price := minf(open_price, target_last)
	cs["open"] = open_price
	cs["high"] = high_price
	cs["low"] = low_price
	cs["last"] = target_last
	cs["fairValue"] = clampf(target_last * post_drift, base * 0.15, base * 6.0)
	var day := int(news.get("day", state.get("dayIndex", 0)))
	var date := SmaCalendar.iso_date(day)
	var avg_vol := float(cs.get("company", {}).get("avgVolume", 400000.0))
	var block_qty := maxi(400, int(round(avg_vol * 0.075)))
	if cs.has("series") and cs["series"] is Dictionary:
		SmaMinuteSeries.apply_trade(cs["series"], {
			"date": date, "second": 0, "price": open_price, "qty": block_qty,
		})
		SmaMinuteSeries.apply_trade(cs["series"], {
			"date": date, "second": 0, "price": target_last, "qty": block_qty,
		})
	cs["volume"] = int(cs.get("volume", 0)) + block_qty * 2
	cs["trades"] = int(cs.get("trades", 0)) + 2
	news["pct"] = roundf((target_last / prev_close - 1.0) * 1000.0) / 10.0
	cs["lastEarnings"] = news
	state["quotes"].erase(ticker)


static func _push(state: Dictionary, entry: Dictionary) -> void:
	var items: Array = state.get("news", [])
	entry["id"] = int(state.get("newsSeq", 1))
	state["newsSeq"] = int(state.get("newsSeq", 1)) + 1
	items.append(entry)
	while items.size() > SmaNews.LIMIT:
		items.pop_front()
	state["news"] = items


## Emits results for every company whose staggered report date is `day`.
static func maybe_emit(state: Dictionary, day: int) -> Array:
	var emitted: Array = []
	var quarters := _quarters_in_season(day)
	if quarters.is_empty():
		return emitted
	var seed_str := String(state.get("seed", "sim-exchange-v1"))
	var macro := SmaMacro.world(day, seed_str)
	var tickers := eligible_tickers(state)
	for quarter in quarters:
		if quarter < SmaFundamentals.FIRST_QUARTER:
			continue
		for ticker in tickers:
			if SmaFundamentals.report_day_for(String(ticker), quarter) != day:
				continue
			var actual := SmaFundamentals.report(String(ticker), quarter)
			if actual.is_empty():
				continue
			var cs: Dictionary = state["companies"].get(String(ticker), {})
			var eps := float(actual["income"].get("eps", 0.0))
			var expected := expected_eps(String(ticker), quarter)
			var pre_runup := _pre_earnings_runup_pct(cs)
			var pe_ratio := _live_pe_ratio(cs)
			var reaction := evaluate_reaction(String(ticker), quarter, actual,
				expected, pre_runup, pe_ratio, macro)
			var impact := float(reaction["impact"])
			var news := {
				"day": day, "tick": 0, "kind": "earnings",
				"template": String(reaction["template"]),
				"ticker": String(ticker),
				"pct": roundf(impact * 1000.0) / 10.0,
				"quarter": quarter,
				"periodLabel": String(actual.get("periodLabel", "")),
				"eps": eps,
				"expectedEps": expected,
				"surprisePct": float(reaction["surprisePct"]),
				"guidance": String(reaction["guidance"]),
				"reactionReason": String(reaction["reactionReason"]),
				"preRunupPct": float(reaction["preRunupPct"]),
				"gmDeltaBps": int(reaction["gmDeltaBps"]),
				"capexYoYPct": float(reaction["capexYoYPct"]),
				"yoyRevenuePct": float(actual.get("highlights", {}).get("yoyRevenuePct", 0.0)),
			}
			_push(state, news)
			_apply_shock(state, String(ticker), impact, news)
			emitted.append(news)
	return emitted


## Reconstructs a deterministic historical earnings event for `ticker` and
## `quarter` (used by initial 120-day K-line history and Day-1 Earnings Center).
static func historical_event(ticker: String, quarter: int,
		seed_str: String = "sim-exchange-v1") -> Dictionary:
	var company := SmaCompanyCatalog.get_company(ticker)
	if company.is_empty() or bool(company.get("isEtf", false)):
		return {}
	var actual := SmaFundamentals.report(ticker, quarter)
	if actual.is_empty():
		return {}
	var report_day := SmaFundamentals.report_day_for(ticker, quarter)
	var expected := expected_eps(ticker, quarter)
	var raw_pe: Variant = company.get("financials", {}).get("pe", 22.0)
	var pe_val := float(raw_pe) if raw_pe != null else 22.0
	var pe_ratio := clampf(pe_val if pe_val > 0.0 else 22.0, 4.0, 140.0)
	var stage := String(company.get("stage", "mature"))
	var runup_rng := SmaRng.new("%s|hist-runup|%s|%d" % [seed_str, ticker, quarter])
	var stage_bias := 2.8 if stage == "highGrowth" else (-2.6 if stage == "turnaround" else 0.4)
	var pre_runup := clampf(stage_bias + runup_rng.normal() * 5.6, -16.0, 20.0)
	var macro := SmaMacro.world(maxi(0, report_day), seed_str)
	var reaction := evaluate_reaction(ticker, quarter, actual, expected,
		pre_runup, pe_ratio, macro)
	var impact := float(reaction["impact"])
	return {
		"day": report_day,
		"tick": 0,
		"kind": "earnings",
		"template": String(reaction["template"]),
		"ticker": ticker,
		"pct": roundf(impact * 1000.0) / 10.0,
		"quarter": quarter,
		"periodLabel": String(actual.get("periodLabel", "")),
		"eps": float(actual["income"].get("eps", 0.0)),
		"expectedEps": expected,
		"surprisePct": float(reaction["surprisePct"]),
		"guidance": String(reaction["guidance"]),
		"reactionReason": String(reaction["reactionReason"]),
		"preRunupPct": float(reaction["preRunupPct"]),
		"gmDeltaBps": int(reaction["gmDeltaBps"]),
		"capexYoYPct": float(reaction["capexYoYPct"]),
		"yoyRevenuePct": float(actual.get("highlights", {}).get("yoyRevenuePct", 0.0)),
		"historical": true,
	}


## Returns the most recent already-released historical earnings events prior to
## or on `day`, sorted chronologically (oldest -> newest, matching news_items).
static func recent_historical(day: int, seed_str: String = "sim-exchange-v1",
		limit: int = 16) -> Array:
	var companies := SmaCompanyCatalog.load_companies()
	var events: Array = []
	var base_q := SmaFundamentals.latest_quarter(day)
	for ticker in companies.keys():
		var q := SmaFundamentals.latest_quarter(day, String(ticker))
		if q < base_q - 1:
			continue
		var ev := historical_event(String(ticker), q, seed_str)
		if not ev.is_empty() and int(ev["day"]) <= day:
			events.append(ev)
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["day"]) != int(b["day"]):
			return int(a["day"]) < int(b["day"])
		return String(a["ticker"]) < String(b["ticker"]))
	if events.size() > limit:
		events = events.slice(events.size() - limit)
	return events


## Next reporting days, grouped by date, for the news-screen calendar.
static func upcoming(state: Dictionary, day: int, limit: int = 3) -> Array:
	var by_day := {}
	var latest := SmaFundamentals.latest_quarter(day)
	var tickers := eligible_tickers(state)
	for quarter in range(latest, latest + 3):
		if quarter < SmaFundamentals.FIRST_QUARTER:
			continue
		var base := SmaFundamentals.report_day(quarter)
		if base + SmaFundamentals.SEASON_DAYS <= day:
			continue
		var period := SmaFundamentals.period_label(quarter)
		for ticker in tickers:
			var report_day := SmaFundamentals.report_day_for(String(ticker), quarter)
			if report_day <= day:
				continue
			if not by_day.has(report_day):
				by_day[report_day] = {"day": report_day, "quarter": quarter,
					"periodLabel": period, "tickers": []}
			by_day[report_day]["tickers"].append(String(ticker))
	var days: Array = by_day.keys()
	days.sort()
	var rows: Array = []
	for report_day in days:
		var row: Dictionary = by_day[report_day]
		row["tickers"].sort()
		rows.append(row)
		if rows.size() >= limit:
			break
	return rows
