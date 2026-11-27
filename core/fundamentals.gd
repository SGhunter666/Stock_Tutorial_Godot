## Deterministic quarterly report model for the simulated companies. The catalog
## stores one annual filing per issuer; this module derives a full, accounting-
## reconciled 3-statement quarterly series (400 formal filings per simulated
## year across all 100 companies, plus 800 historical filings at game start)
## with sector-specific seasonality, margin/CapEx cycles, and forward guidance.
class_name SmaFundamentals
extends RefCounted

const QUARTER_DAYS := 63
const REPORT_LAG_DAYS := 14
const SEASON_DAYS := 20
const FIRST_QUARTER := -8
const MAX_QUARTER := 40
const TAX_RATE := 0.21
const INTEREST_RATE := 0.04
const SEASONAL := [0.96, 0.99, 1.02, 1.03]

static var _base_cache: Dictionary = {}
static var _report_cache: Dictionary = {}

## Real-world sector seasonality (Q1..Q4 weights summing to 4.0):
## - Consumer & Tech peak in Q4 holiday shopping / enterprise budget flush.
## - Financials peak in Q1 capital-markets & underwriting issuance.
## - Energy & Utilities peak in Q1 winter heating and Q3 summer cooling/driving.
## - Industrials, Materials & Real Estate peak in Q2-Q3 construction/leasing.
## - Healthcare & Telecom exhibit steady recurring demand across the year.
const SECTOR_SEASONAL := {
	"consumer": [0.93, 0.96, 0.99, 1.12],
	"communication": [0.95, 0.98, 1.00, 1.07],
	"technology": [0.94, 0.97, 1.01, 1.08],
	"financials": [1.06, 1.00, 0.97, 0.97],
	"energy": [1.04, 0.95, 1.05, 0.96],
	"utilities": [1.05, 0.94, 1.05, 0.96],
	"industrials": [0.93, 1.04, 1.05, 0.98],
	"materials": [0.94, 1.04, 1.04, 0.98],
	"healthcare": [0.98, 1.00, 1.01, 1.01],
	"telecom": [0.98, 0.99, 1.01, 1.02],
	"realestate": [0.96, 1.03, 1.03, 0.98],
}


static func latest_quarter(day: int, ticker: String = "") -> int:
	var quarter := int(floor(float(day - REPORT_LAG_DAYS) / float(QUARTER_DAYS))) - 1
	quarter = clampi(quarter, FIRST_QUARTER, MAX_QUARTER)
	if ticker != "":
		while quarter >= FIRST_QUARTER and report_day_for(ticker, quarter) > day:
			quarter -= 1
	return quarter


static func quarter_end_day(quarter: int) -> int:
	return quarter * QUARTER_DAYS + QUARTER_DAYS - 1


static func report_day(quarter: int) -> int:
	return (quarter + 1) * QUARTER_DAYS + REPORT_LAG_DAYS


## Each issuer keeps a stable slot inside the earnings season, the way real
## companies tend to report in the same part of the cycle every quarter.
static func report_offset(ticker: String) -> int:
	var rng := SmaRng.new("earnings-date:%s" % ticker)
	return rng.rand_int(0, SEASON_DAYS)


static func report_day_for(ticker: String, quarter: int) -> int:
	return report_day(quarter) + report_offset(ticker)


static func period_label(quarter: int) -> String:
	return _period_label(quarter)


## Summary statistics of the formal quarterly filing universe at `day`, used to
## surface coverage transparency (100 companies * 4 quarters = 400 filings/year).
static func filing_coverage(day: int = 0) -> Dictionary:
	var companies := SmaCompanyCatalog.load_companies()
	var company_count := companies.size()
	var released := 0
	for ticker in companies.keys():
		var latest := latest_quarter(day, String(ticker))
		released += maxi(0, latest - FIRST_QUARTER + 1)
	var total_quarters := MAX_QUARTER - FIRST_QUARTER + 1
	return {
		"companies": company_count,
		"perYear": company_count * 4,
		"releasedFilings": released,
		"historyWindowPerCompany": 8,
		"totalModeledFilings": company_count * total_quarters,
	}


static func _round2(value: float) -> float:
	return SmaFormat.round_to(value, 2)


static func _period_label(quarter: int) -> String:
	var date := SmaCalendar.date_for_trading_day(quarter_end_day(quarter))
	var month := int(date["month"])
	var q := int(floor(float(month - 1) / 3.0)) + 1
	return "%d Q%d" % [int(date["year"]), q]


static func split_factor_through(ticker: String, day: int) -> float:
	var factor := 1.0
	for entry in SmaCorporate.SPLITS.get(ticker, []):
		if int(entry["quarter"]) * QUARTER_DAYS <= day:
			factor *= float(entry["ratio"])
	return factor


static func _seasonal_weight(sector: String, quarter: int) -> float:
	var date := SmaCalendar.date_for_trading_day(quarter_end_day(quarter))
	var q_index := clampi(int(floor(float(int(date["month"]) - 1) / 3.0)), 0, 3)
	var weights: Array = SECTOR_SEASONAL.get(sector, SEASONAL)
	return float(weights[q_index])


static func _base_report(ticker: String, quarter: int) -> Dictionary:
	var cache_key := "%s:%d" % [ticker, quarter]
	if _base_cache.has(cache_key):
		return _base_cache[cache_key]
	var company := SmaCompanyCatalog.get_company(ticker)
	if company.is_empty():
		return {}
	var financials: Dictionary = company.get("financials", {})
	var sector := String(company.get("sector", "technology"))
	var stage := String(company.get("stage", "mature"))
	var shares := maxf(1.0, float(company.get("sharesOutstanding",
		company.get("shares", 1.0))))
	var annual_revenue := float(financials.get("revenue", 0.0))
	var annual_gross := float(financials.get("grossProfit", 0.0))
	var annual_operating := float(financials.get("operatingIncome", 0.0))
	var assets := float(financials.get("totalAssets", 0.0))
	var liabilities := float(financials.get("totalLiabilities", 0.0))
	var debt := float(financials.get("debt", 0.0))
	var cash := float(financials.get("cash", 0.0))
	var capex := absf(float(financials.get("capex", 0.0)))
	var rng := SmaRng.new("fundamentals:%s:%d" % [ticker, quarter])
	var season := _seasonal_weight(sector, quarter)
	var cycle := 1.0 + 0.038 * sin(float(quarter) * 0.82 + float(abs(hash(ticker)) % 628) / 100.0)
	var qoq_growth := clampf(float(company.get("qoqGrowth", 0.0)), -0.08, 0.12)
	var growth_trend := pow(1.0 + qoq_growth, clampf(float(quarter), -12.0, 16.0))
	var rev_noise := rng.normal() * 0.022
	var revenue := maxf(1.0, annual_revenue / 4.0 * season * cycle * growth_trend * (1.0 + rev_noise))
	var base_gm := annual_gross / annual_revenue if annual_revenue > 0.0 else 0.35
	var gross_margin := clampf(base_gm + rng.normal() * 0.012, 0.02, 0.95)
	var gross_profit := revenue * gross_margin
	var base_om := annual_operating / annual_revenue if annual_revenue > 0.0 else 0.12
	var operating_margin := clampf(
		base_om + (gross_margin - base_gm) * 0.65 + rng.normal() * 0.008,
		-0.25, maxf(0.01, gross_margin - 0.01))
	var operating_income := revenue * operating_margin
	var operating_expenses := maxf(0.0, gross_profit - operating_income)
	var interest_expense := debt * INTEREST_RATE / 4.0
	var pretax := operating_income - interest_expense
	var tax_expense := maxf(0.0, pretax * TAX_RATE)
	var net_income := pretax - tax_expense
	var eps := net_income / shares
	var annual_dividend := float(financials.get("dividendPerShare", 0.0))
	var quarterly_dividend := annual_dividend / 4.0
	var dividends_paid := quarterly_dividend * shares
	var revenue_scale := revenue / maxf(1.0, annual_revenue / 4.0)
	var cash_balance := cash * clampf(0.85 + rng.next() * 0.3, 0.7, 1.2) * revenue_scale
	var receivables := revenue * clampf(0.12 + rng.next() * 0.08, 0.1, 0.2)
	var inventory := (revenue - gross_profit) * clampf(0.2 + rng.next() * 0.15, 0.15, 0.35)
	var ppe := maxf(0.0, assets - cash_balance - receivables - inventory)
	var total_assets := cash_balance + receivables + inventory + ppe
	var other_liabilities := maxf(0.0, liabilities - debt)
	var total_liabilities := debt + other_liabilities
	var equity := total_assets - total_liabilities
	var depreciation := ppe * 0.02
	var working_capital := (receivables + inventory) * (rng.next() - 0.5) * 0.1
	var operating_cash := net_income + depreciation - working_capital
	var capex_surge_roll := rng.next()
	var capex_cycle := clampf(
		1.0 + rng.normal() * 0.16 + (0.18 if (stage == "highGrowth" or sector == "technology") and capex_surge_roll < 0.32 else 0.0),
		0.65, 1.72)
	var quarter_capex := -capex / 4.0 * growth_trend * capex_cycle
	var investing_cash := quarter_capex + (rng.next() - 0.5) * revenue * 0.01
	var debt_issuance := (rng.next() - 0.5) * debt * 0.02
	var financing_cash := debt_issuance - dividends_paid
	var net_change := operating_cash + investing_cash + financing_cash
	var free_cash := operating_cash + quarter_capex
	var as_of_day := report_day_for(ticker, quarter)
	var split_factor := split_factor_through(ticker, as_of_day)
	var result := {
		"ticker": ticker,
		"quarter": quarter,
		"periodLabel": _period_label(quarter),
		"reportDate": SmaCalendar.iso_date(as_of_day),
		"splitFactor": split_factor,
		"income": {
			"revenue": _round2(revenue),
			"cogs": _round2(revenue - gross_profit),
			"grossProfit": _round2(gross_profit),
			"operatingExpenses": _round2(operating_expenses),
			"operatingIncome": _round2(operating_income),
			"interestExpense": _round2(interest_expense),
			"pretaxIncome": _round2(pretax),
			"taxExpense": _round2(tax_expense),
			"netIncome": _round2(net_income),
			"eps": SmaFormat.round_to(eps, 4),
			"sharesOutstanding": shares,
			"dividendsPaid": _round2(dividends_paid),
		},
		"balance": {
			"cash": _round2(cash_balance),
			"receivables": _round2(receivables),
			"inventory": _round2(inventory),
			"ppe": _round2(ppe),
			"totalAssets": _round2(total_assets),
			"debt": _round2(debt),
			"otherLiabilities": _round2(other_liabilities),
			"totalLiabilities": _round2(total_liabilities),
			"equity": _round2(equity),
		},
		"cashFlow": {
			"operatingCashFlow": _round2(operating_cash),
			"capex": _round2(quarter_capex),
			"investingCashFlow": _round2(investing_cash),
			"financingCashFlow": _round2(financing_cash),
			"debtIssuance": _round2(debt_issuance),
			"dividendsPaid": _round2(dividends_paid),
			"netChange": _round2(net_change),
			"freeCashFlow": _round2(free_cash),
		},
		"ratios": {
			"grossMargin": gross_margin,
			"operatingMargin": operating_margin,
			"netMargin": net_income / revenue if revenue > 0.0 else 0.0,
			"roe": net_income / equity if equity > 0.0 else 0.0,
			"debtToEquity": debt / equity if equity > 0.0 else 0.0,
			"bookValuePerShare": equity / shares,
			"annualDividendPerShare": annual_dividend,
			"quarterlyDividendPerShare": quarterly_dividend,
		},
	}
	_base_cache[cache_key] = result
	return result


static func report(ticker: String, quarter: int) -> Dictionary:
	var cache_key := "%s:%d" % [ticker, quarter]
	if _report_cache.has(cache_key):
		return _report_cache[cache_key]
	var base_entry := _base_report(ticker, quarter)
	if base_entry.is_empty():
		return {}
	var current: Dictionary = base_entry.duplicate(true)
	var company := SmaCompanyCatalog.get_company(ticker)
	var qoq_growth := clampf(float(company.get("qoqGrowth", 0.0)), -0.08, 0.12)
	var expected_annual := pow(1.0 + qoq_growth, 4.0) - 1.0
	var prior_year := _base_report(ticker, quarter - 4)
	var prior_quarter := _base_report(ticker, quarter - 1)
	var next_quarter := _base_report(ticker, quarter + 1)
	var prior_next := _base_report(ticker, quarter - 3)
	var cur_rev := float(current["income"]["revenue"])
	var cur_eps := float(current["income"]["eps"])
	var cur_gm := float(current["ratios"]["grossMargin"])
	var cur_capex := absf(float(current["cashFlow"]["capex"]))
	var yoy_rev_pct := 0.0
	var yoy_eps_pct := 0.0
	var gm_delta_bps := 0
	var capex_yoy_pct := 0.0
	if not prior_year.is_empty():
		var py_rev := float(prior_year["income"]["revenue"])
		var py_eps := float(prior_year["income"]["eps"])
		var py_gm := float(prior_year["ratios"]["grossMargin"])
		var py_capex := absf(float(prior_year["cashFlow"]["capex"]))
		if py_rev > 0.0:
			yoy_rev_pct = SmaFormat.round_to((cur_rev / py_rev - 1.0) * 100.0, 1)
		if absf(py_eps) > 0.0001:
			yoy_eps_pct = SmaFormat.round_to((cur_eps - py_eps) / absf(py_eps) * 100.0, 1)
		gm_delta_bps = int(round((cur_gm - py_gm) * 10000.0))
		if py_capex > 0.0:
			capex_yoy_pct = SmaFormat.round_to((cur_capex / py_capex - 1.0) * 100.0, 1)
	var qoq_rev_pct := 0.0
	if not prior_quarter.is_empty() and float(prior_quarter["income"]["revenue"]) > 0.0:
		qoq_rev_pct = SmaFormat.round_to(
			(cur_rev / float(prior_quarter["income"]["revenue"]) - 1.0) * 100.0, 1)
	var guidance := "maintain"
	var forward_yoy_pct := yoy_rev_pct
	if not next_quarter.is_empty() and not prior_next.is_empty():
		var next_rev := float(next_quarter["income"]["revenue"])
		var base_next_rev := maxf(1.0, float(prior_next["income"]["revenue"]))
		var fwd_growth := next_rev / base_next_rev - 1.0
		forward_yoy_pct = SmaFormat.round_to(fwd_growth * 100.0, 1)
		var fwd_om_shift := float(next_quarter["ratios"]["operatingMargin"]) \
			- float(prior_next["ratios"]["operatingMargin"])
		var mgmt_rng := SmaRng.new("guidance:%s:%d" % [ticker, quarter])
		var guidance_signal := (fwd_growth - expected_annual) + fwd_om_shift * 0.85 \
			+ mgmt_rng.normal() * 0.026
		if guidance_signal >= 0.020:
			guidance = "raise"
		elif guidance_signal <= -0.018:
			guidance = "cut"
	current["highlights"] = {
		"yoyRevenuePct": yoy_rev_pct,
		"qoqRevenuePct": qoq_rev_pct,
		"yoyEpsPct": yoy_eps_pct,
		"grossMarginDeltaBps": gm_delta_bps,
		"capexYoYPct": capex_yoy_pct,
		"forwardRevenueYoYPct": forward_yoy_pct,
		"guidance": guidance,
	}
	_report_cache[cache_key] = current
	return current


static func history(ticker: String, count: int = 8, day: int = 0) -> Array:
	var latest := latest_quarter(day, ticker)
	var reports: Array = []
	for index in maxi(1, count):
		var quarter := latest - index
		var entry := report(ticker, quarter)
		if not entry.is_empty():
			reports.append(entry)
	return reports


## Live Trailing-Twelve-Month (TTM) fundamentals and dynamic valuation ratios
## (`P/E`, `P/B`, dividend yield, market cap) recomputed from the 4 most recent
## released quarterly filings, live traded `price`, and `split_factor`.
static func live_valuation(ticker: String, live_price: float, day: int = 0,
		split_factor: float = 1.0) -> Dictionary:
	var company := SmaCompanyCatalog.get_company(ticker)
	if company.is_empty():
		return {}
	var financials: Dictionary = company.get("financials", {})
	var safe_split := maxf(0.0001, split_factor)
	var ttm_quarters := history(ticker, 4, day)
	if ttm_quarters.is_empty():
		var base_eps := float(financials.get("eps", 0.0)) / safe_split
		var raw_pe: Variant = financials.get("pe", null)
		var fallback_pe: Variant = (live_price / base_eps) if (base_eps > 0.01 and live_price > 0.0) else raw_pe
		return {
			"periodRange": "TTM",
			"revenue": float(financials.get("revenue", 0.0)),
			"grossProfit": float(financials.get("grossProfit", 0.0)),
			"operatingIncome": float(financials.get("operatingIncome", 0.0)),
			"netIncome": float(financials.get("netIncome", 0.0)),
			"eps": base_eps,
			"totalAssets": float(financials.get("totalAssets", 0.0)),
			"totalLiabilities": float(financials.get("totalLiabilities", 0.0)),
			"equity": float(financials.get("equity", 0.0)),
			"cash": float(financials.get("cash", 0.0)),
			"debt": float(financials.get("debt", 0.0)),
			"operatingCashFlow": float(financials.get("operatingCashFlow", 0.0)),
			"capex": float(financials.get("capex", 0.0)),
			"freeCashFlow": float(financials.get("freeCashFlow", 0.0)),
			"pe": fallback_pe,
			"pb": financials.get("pb", null),
			"roe": float(financials.get("roe", 0.0)),
			"roic": float(financials.get("roic", 0.0)),
			"dividendPerShare": float(financials.get("dividendPerShare", 0.0)) / safe_split,
			"dividendYieldPct": 0.0,
			"marketCap": float(company.get("sharesOutstanding", company.get("shares", 1.0))) * safe_split * live_price,
		}
	var ttm_rev := 0.0
	var ttm_gp := 0.0
	var ttm_op := 0.0
	var ttm_ni := 0.0
	var ttm_eps_raw := 0.0
	var ttm_ocf := 0.0
	var ttm_capex := 0.0
	var ttm_fcf := 0.0
	for q_rep in ttm_quarters:
		var inc: Dictionary = q_rep["income"]
		var cf: Dictionary = q_rep["cashFlow"]
		ttm_rev += float(inc.get("revenue", 0.0))
		ttm_gp += float(inc.get("grossProfit", 0.0))
		ttm_op += float(inc.get("operatingIncome", 0.0))
		ttm_ni += float(inc.get("netIncome", 0.0))
		ttm_eps_raw += float(inc.get("eps", 0.0))
		ttm_ocf += float(cf.get("operatingCashFlow", 0.0))
		ttm_capex += float(cf.get("capex", 0.0))
		ttm_fcf += float(cf.get("freeCashFlow", 0.0))
	var scale := 4.0 / float(ttm_quarters.size())
	ttm_rev *= scale
	ttm_gp *= scale
	ttm_op *= scale
	ttm_ni *= scale
	ttm_eps_raw *= scale
	ttm_ocf *= scale
	ttm_capex *= scale
	ttm_fcf *= scale
	var latest_rep: Dictionary = ttm_quarters[0]
	var bal: Dictionary = latest_rep["balance"]
	var rat: Dictionary = latest_rep["ratios"]
	var base_shares := maxf(1.0, float(company.get("sharesOutstanding", company.get("shares", 1.0))))
	var adj_shares := base_shares * safe_split
	var adj_eps := SmaFormat.round_to(ttm_eps_raw / safe_split, 3)
	var adj_bvps := float(rat.get("bookValuePerShare", 0.0)) / safe_split
	var adj_div := float(rat.get("annualDividendPerShare", 0.0)) / safe_split
	var live_pe: Variant = SmaFormat.round_to(live_price / adj_eps, 1) \
		if (adj_eps > 0.01 and live_price > 0.0) else null
	var live_pb: Variant = SmaFormat.round_to(live_price / adj_bvps, 2) \
		if (adj_bvps > 0.01 and live_price > 0.0) else null
	var div_yield := SmaFormat.round_to(adj_div / live_price * 100.0, 2) if live_price > 0.0 else 0.0
	var eq_val := maxf(1.0, float(bal.get("equity", 1.0)))
	var invested_cap := maxf(1.0, eq_val + float(bal.get("debt", 0.0)) - float(bal.get("cash", 0.0)) * 0.5)
	var ttm_roe := clampf(ttm_ni / eq_val, -0.95, 1.8)
	var ttm_roic := clampf(ttm_op * (1.0 - TAX_RATE) / invested_cap, -0.8, 1.5)
	var oldest_label := String(ttm_quarters[ttm_quarters.size() - 1].get("periodLabel", ""))
	var newest_label := String(latest_rep.get("periodLabel", ""))
	return {
		"periodRange": "%s – %s (TTM)" % [oldest_label, newest_label],
		"revenue": _round2(ttm_rev),
		"grossProfit": _round2(ttm_gp),
		"operatingIncome": _round2(ttm_op),
		"netIncome": _round2(ttm_ni),
		"eps": adj_eps,
		"totalAssets": float(bal.get("totalAssets", 0.0)),
		"totalLiabilities": float(bal.get("totalLiabilities", 0.0)),
		"equity": float(bal.get("equity", 0.0)),
		"cash": float(bal.get("cash", 0.0)),
		"debt": float(bal.get("debt", 0.0)),
		"operatingCashFlow": _round2(ttm_ocf),
		"capex": _round2(ttm_capex),
		"freeCashFlow": _round2(ttm_fcf),
		"pe": live_pe,
		"pb": live_pb,
		"roe": ttm_roe,
		"roic": ttm_roic,
		"dividendPerShare": SmaFormat.round_to(adj_div, 3),
		"dividendYieldPct": div_yield,
		"marketCap": _round2(adj_shares * live_price),
		"splitFactor": safe_split,
	}
