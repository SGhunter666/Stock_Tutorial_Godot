## Quarterly earnings events tied to the real simulated financial statements.
## Every eligible company reports once per quarter, but each issuer keeps its
## own stable slot inside a three-week earnings season, so results arrive on
## different days rather than all at once.
class_name SmaEarnings
extends RefCounted

const QUARTER_DAYS := 63
const REPORT_LAG_DAYS := 14
const NO_REPORT := -999
const BEAT_THRESHOLD := 2.0
const MISS_THRESHOLD := -2.0
const MAX_IMPACT := 0.09


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


static func expected_eps(ticker: String, quarter: int) -> float:
	var base := 0.0
	var prior_year := SmaFundamentals.report(ticker, quarter - 4)
	if not prior_year.is_empty():
		base = float(prior_year["income"].get("eps", 0.0))
	if base <= 0.0:
		var prior_quarter := SmaFundamentals.report(ticker, quarter - 1)
		if not prior_quarter.is_empty():
			base = float(prior_quarter["income"].get("eps", 0.0))
	if base <= 0.0:
		base = 0.01
	var rng := SmaRng.new("earnings-consensus:%s:%d" % [ticker, quarter])
	return SmaFormat.round_to(base * rng.range_float(0.99, 1.04), 4)


static func _guidance(ticker: String, quarter: int, actual: Dictionary) -> String:
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


static func _impact(surprise_pct: float, guidance: String) -> float:
	var impact := clampf(surprise_pct / 100.0 * 1.1, -0.08, 0.08)
	if guidance == "raise":
		impact += 0.015
	elif guidance == "cut":
		impact -= 0.015
	return clampf(impact, -MAX_IMPACT, MAX_IMPACT)


static func _apply_shock(state: Dictionary, ticker: String, impact: float,
		news: Dictionary) -> void:
	var cs: Dictionary = state["companies"].get(ticker, {})
	if cs.is_empty():
		return
	var base := float(cs["company"].get("price", cs["fairValue"]))
	var last := maxf(0.01, float(cs["last"]) * (1.0 + impact))
	cs["last"] = last
	cs["open"] = last
	cs["high"] = last
	cs["low"] = last
	cs["fairValue"] = clampf(float(cs["fairValue"]) * (1.0 + impact * 0.5),
		base * 0.15, base * 6.0)
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
			var eps := float(actual["income"].get("eps", 0.0))
			var expected := expected_eps(String(ticker), quarter)
			var surprise := (eps - expected) / absf(expected) * 100.0 \
				if absf(expected) > 0.0001 else 0.0
			var guidance := _guidance(String(ticker), quarter, actual)
			var template := "earningsBeat" if surprise >= BEAT_THRESHOLD else (
				"earningsMiss" if surprise <= MISS_THRESHOLD else "earningsInline")
			var impact := _impact(surprise, guidance)
			var news := {
				"day": day, "tick": 0, "kind": "earnings", "template": template,
				"ticker": String(ticker), "pct": roundf(impact * 1000.0) / 10.0,
				"quarter": quarter, "periodLabel": String(actual.get("periodLabel", "")),
				"eps": eps, "expectedEps": expected,
				"surprisePct": roundf(surprise * 10.0) / 10.0,
				"guidance": guidance,
			}
			_push(state, news)
			_apply_shock(state, String(ticker), impact, news)
			emitted.append(news)
	return emitted


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
