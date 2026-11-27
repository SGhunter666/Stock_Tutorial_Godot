## Deterministic quarterly filing model.
extends "res://tests/test_base.gd"


func run() -> void:
	describe("fundamentals-report")
	var report := SmaFundamentals.report("APLA", 0)
	eq(report.is_empty(), false, "report generated")
	if report.is_empty():
		return
	var income: Dictionary = report["income"]
	var balance: Dictionary = report["balance"]
	var cash_flow: Dictionary = report["cashFlow"]
	var ratios: Dictionary = report["ratios"]
	check(float(income["revenue"]) > 0.0, "revenue is positive")
	check(float(income["sharesOutstanding"]) > 0.0, "shares outstanding present")
	approx(float(income["grossProfit"]), float(income["revenue"]) - float(income["cogs"]),
		0.02, "gross profit reconciles")
	approx(float(income["operatingIncome"]), float(income["grossProfit"])
		- float(income["operatingExpenses"]), 0.02, "operating income reconciles")
	approx(float(balance["totalAssets"]), float(balance["cash"])
		+ float(balance["receivables"]) + float(balance["inventory"])
		+ float(balance["ppe"]), 0.05, "assets reconcile")
	approx(float(balance["totalAssets"]), float(balance["totalLiabilities"])
		+ float(balance["equity"]), 0.05, "assets equal liabilities plus equity")
	approx(float(cash_flow["netChange"]), float(cash_flow["operatingCashFlow"])
		+ float(cash_flow["investingCashFlow"])
		+ float(cash_flow["financingCashFlow"]), 0.05, "cash flow reconciles")
	check(float(ratios["bookValuePerShare"]) > 0.0, "book value per share positive")
	eq(String(report["reportDate"]).length(), 10, "report date formatted")
	eq(String(report["periodLabel"]).find("Q") > 0, true, "period label has a quarter")

	describe("fundamentals-determinism")
	var again := SmaFundamentals.report("APLA", 0)
	approx(float(again["income"]["revenue"]), float(income["revenue"]), 0.001,
		"same quarter is deterministic")

	describe("fundamentals-history")
	var latest := SmaFundamentals.latest_quarter(0)
	eq(latest, -2, "latest released quarter before day zero")
	var history := SmaFundamentals.history("APLA", 8, 0)
	eq(history.size(), 8, "eight quarters returned")
	eq(int(history[0]["quarter"]), latest, "history starts at the latest released quarter")
	eq(int(history[1]["quarter"]), latest - 1, "history descends by quarter")
	eq(String(history[0]["periodLabel"]) != String(history[1]["periodLabel"]), true,
		"quarters have distinct labels")

	describe("fundamentals-splits")
	eq(SmaFundamentals.split_factor_through("APLA", 100), 1.0,
		"split not applied before its quarter")
	eq(SmaFundamentals.split_factor_through("APLA", 6 * 63), 4.0,
		"APLA split factor applied after quarter six")
	eq(SmaFundamentals.split_factor_through("QVAL", 5 * 63), 0.5,
		"reverse split factor applied")

	describe("fundamentals-400-annual-filings")
	var cov := SmaFundamentals.filing_coverage(0)
	eq(int(cov["companies"]), 100, "coverage tracks all 100 listed companies")
	eq(int(cov["perYear"]), 400, "coverage delivers 400 formal filings per simulated year")
	ge(float(cov["releasedFilings"]), 700.0, "at least 700 historical filings released on day 0")
	eq(int(cov["totalModeledFilings"]), 4900, "4900 formal quarterly filings modeled across cycle")
	var companies := SmaCompanyCatalog.load_companies()
	var annual_count := 0
	var guidance_seen := {}
	for ticker in companies.keys():
		for q in [0, 1, 2, 3]:
			var q_rep := SmaFundamentals.report(String(ticker), q)
			if not q_rep.is_empty():
				annual_count += 1
				var q_inc: Dictionary = q_rep["income"]
				var q_bal: Dictionary = q_rep["balance"]
				var q_cf: Dictionary = q_rep["cashFlow"]
				var q_hl: Dictionary = q_rep.get("highlights", {})
				le(absf(float(q_inc["operatingIncome"]) - (float(q_inc["grossProfit"])
					- float(q_inc["operatingExpenses"]))), 0.05,
					"operating income reconciles for %s Q%d" % [ticker, q])
				le(absf(float(q_bal["totalAssets"]) - float(q_bal["totalLiabilities"])
					- float(q_bal["equity"])), 0.05,
					"balance sheet reconciles for %s Q%d" % [ticker, q])
				le(absf(float(q_cf["netChange"]) - (float(q_cf["operatingCashFlow"])
					+ float(q_cf["investingCashFlow"]) + float(q_cf["financingCashFlow"]))), 0.05,
					"cash flow reconciles for %s Q%d" % [ticker, q])
				guidance_seen[String(q_hl.get("guidance", ""))] = true
	eq(annual_count, 400, "all 400 annual quarterly filings generated and reconciled")
	check(guidance_seen.has("raise") and guidance_seen.has("maintain") and guidance_seen.has("cut"),
		"400 filings span raise, maintain, and cut forward guidance")
