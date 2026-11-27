## Full-spectrum causal price-move attribution engine ("Why Is It Moving?").
## Every price drop or surge — whether on today's live session or on any
## historical daily K-line candle — is mapped to its actual underlying driver
## (earnings expectations gap, sector-specific news, corporate dilution/ex-div,
## macro rate/inflation rotation, ETF component drag, pre-earnings hedging,
## valuation gravity, overbought profit-taking, or order-book flow).
##
## Kept 100% UI-free (`core/` rule): returns structured keys + parameter dicts
## formatted by the UI layer via `I18n.t`.
class_name SmaAttribution
extends RefCounted


static func explain_today(state: Dictionary, ticker: String) -> Dictionary:
	var symbol := ticker.to_upper()
	var companies: Dictionary = state.get("companies", {})
	var cs: Dictionary = companies.get(symbol, {})
	if cs.is_empty():
		return {"key": "attr.flatConsolidation", "params": {}, "changePct": 0.0, "kind": "flow"}
	var prev_close := maxf(0.01, float(cs.get("prevClose", cs.get("last", 1.0))))
	var last := maxf(0.01, float(cs.get("last", prev_close)))
	var change_pct := SmaFormat.round_to((last - prev_close) / prev_close * 100.0, 2)
	var day := int(state.get("dayIndex", 0))
	var seed_str := String(state.get("seed", "sim-exchange-v1"))
	var company: Dictionary = cs.get("company", {})

	# 1. ETF: attribute directly to its #1 intraday driving component holding
	if bool(cs.get("isEtf", false)) or SmaEtfs.is_etf(symbol):
		var etf_def := SmaEtfs.definition(symbol)
		var comps: Array = etf_def.get("components", [])
		if not comps.is_empty():
			var scored: Array = []
			for comp in comps:
				var c_sym := String(comp.get("ticker", ""))
				var c_w := float(comp.get("weight", 0.0))
				var c_cs: Dictionary = companies.get(c_sym, {})
				var c_prev := maxf(0.01, float(c_cs.get("prevClose", c_cs.get("last", 1.0))))
				var c_last := maxf(0.01, float(c_cs.get("last", c_prev)))
				var c_chg := (c_last - c_prev) / c_prev * 100.0
				scored.append({
					"ticker": c_sym,
					"changePct": SmaFormat.round_to(c_chg, 1),
					"todayContrib": c_w * c_chg,
				})
			scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				if change_pct < 0.0:
					return float(a["todayContrib"]) < float(b["todayContrib"])
				return float(a["todayContrib"]) > float(b["todayContrib"]))
			var top: Dictionary = scored[0]
			return {
				"key": "attr.etfDrag" if change_pct < -0.05 else (
					"attr.etfLift" if change_pct > 0.05 else "attr.flatConsolidation"),
				"params": {
					"topTicker": String(top["ticker"]),
					"topPct": SmaFormat.pct(float(top["changePct"]), 1),
				},
				"changePct": change_pct,
				"kind": "etf",
			}

	# 2. Today's Quarterly Earnings Release
	var last_earn: Dictionary = cs.get("lastEarnings", {})
	if not last_earn.is_empty() and int(last_earn.get("day", -999)) == day:
		var reason := String(last_earn.get("reactionReason", "inlineDigest"))
		return {
			"key": "attr.earningsToday",
			"params": {
				"period": String(last_earn.get("periodLabel", "")),
				"reason": reason,
			},
			"changePct": change_pct,
			"kind": "earnings",
		}

	# 3. Today's Company-Specific Breaking News or Intraday Flash Alert
	var news_list: Array = state.get("news", [])
	for idx in range(news_list.size() - 1, -1, -1):
		var item: Dictionary = news_list[idx]
		if int(item.get("day", -999)) < day:
			break
		if int(item.get("day", -999)) == day and String(item.get("ticker", "")) == symbol \
				and String(item.get("kind", "")) == "company":
			return {
				"key": "attr.companyNews",
				"params": {"template": String(item.get("template", "downgrade"))},
				"changePct": change_pct,
				"kind": "news",
			}

	# 4. Today's Corporate Actions (offering dilution, spinoff, split, rights, buyback, halt)
	for action in state.get("corporateActions", []):
		if int(action.get("day", -999)) != day:
			continue
		if String(action.get("ticker", "")) != symbol:
			continue
		var act_type := String(action.get("type", ""))
		return {
			"key": "attr.corp.%s" % act_type,
			"params": {
				"ratio": SmaFormat.num(float(action.get("ratio", 0.0)) * 100.0, 0),
				"splitRatio": SmaFormat.num(float(action.get("ratio", 1.0)), 1),
			},
			"changePct": change_pct,
			"kind": "corporate",
		}

	# 5. Quarterly Ex-Dividend Date Adjustment
	if day > 0 and day % SmaCalendar.QUARTER_DAYS == 0:
		var annual_div := float(company.get("financials", {}).get("dividendPerShare", 0.0))
		var split_f := maxf(0.0001, float(cs.get("splitFactor", 1.0)))
		var dps := annual_div / 4.0 / split_f
		if dps > 0.001 and change_pct < 0.2:
			return {
				"key": "attr.exDividend",
				"params": {"dps": SmaFormat.money(dps)},
				"changePct": change_pct,
				"kind": "corporate",
			}

	# 6. Today's Macro Shock (rate hike/cut, hot/cool inflation, recession/growth)
	for idx in range(news_list.size() - 1, -1, -1):
		var item: Dictionary = news_list[idx]
		if int(item.get("day", -999)) < day:
			break
		if int(item.get("day", -999)) == day and String(item.get("kind", "")) == "macro":
			var tmpl := String(item.get("template", ""))
			var mult := SmaNews.macro_sector_multiplier(tmpl, company)
			var eff := float(item.get("pct", 0.0)) * mult
			var key := "attr.macro.%s" % tmpl
			if tmpl == "rateHike" and eff > 0.0:
				key = "attr.macro.rateHikeBank"
			elif tmpl == "inflationHot" and eff > 0.0:
				key = "attr.macro.inflationHedge"
			elif tmpl == "recessionFear" and absf(mult) <= 0.35:
				key = "attr.macro.recessionSafe"
			return {
				"key": key,
				"params": {},
				"changePct": change_pct,
				"kind": "macro",
			}

	# 7. Post-Earnings Digestion / PEAD (1..3 sessions after earnings release)
	if not last_earn.is_empty():
		var since_earn := day - int(last_earn.get("day", -999))
		if since_earn >= 1 and since_earn <= 3 and absf(change_pct) >= 0.25:
			return {
				"key": "attr.postEarningsDip" if change_pct < 0.0 else "attr.postEarningsFollow",
				"params": {"period": String(last_earn.get("periodLabel", ""))},
				"changePct": change_pct,
				"kind": "earnings",
			}

	# 8. Pre-Earnings Hedging / Anticipation Run-Up (1..8 sessions ahead of report)
	var iv_state := SmaOptions.earnings_iv_state(symbol, day)
	var d_earn := int(iv_state.get("daysToEarnings", 999))
	if d_earn >= 1 and d_earn <= 8 and absf(change_pct) >= 0.35:
		return {
			"key": "attr.preEarningsHedge" if change_pct < 0.0 else "attr.preEarningsRunup",
			"params": {"days": d_earn},
			"changePct": change_pct,
			"kind": "earnings",
		}

	# 9. Sector Rotation / Market Factor / High-Rate Valuation / Overbought Pullback / Order Flow
	if absf(change_pct) < 0.12:
		return {"key": "attr.flatConsolidation", "params": {}, "changePct": change_pct, "kind": "flow"}

	var sector := String(company.get("sector", "technology"))
	var sector_factor := float(state.get("sectorFactors", {}).get(sector, 0.0))
	var market_factor := float(state.get("marketFactor", 0.0))
	var macro := SmaMacro.world(day, seed_str)
	var real_rate := float(macro.get("realRate", 0.3))
	var raw_pe: Variant = company.get("financials", {}).get("pe", 20.0)
	var pe := float(raw_pe) if raw_pe != null else 20.0
	var daily: Array = cs.get("series", {}).get("daily", [])
	var run_5d := 0.0
	if daily.size() >= 6:
		var c_old := maxf(0.01, float(daily[daily.size() - 6].get("c", prev_close)))
		run_5d = SmaFormat.round_to((prev_close / c_old - 1.0) * 100.0, 1)

	if change_pct < 0.0:
		if sector_factor < -0.00045:
			return {
				"key": "attr.sectorPullback",
				"params": {"sector": sector},
				"changePct": change_pct,
				"kind": "flow",
			}
		if market_factor < -0.00045 and float(company.get("beta", 1.0)) >= 0.95:
			return {
				"key": "attr.marketRiskOff",
				"params": {"beta": SmaFormat.num(float(company.get("beta", 1.0)), 2)},
				"changePct": change_pct,
				"kind": "macro",
			}
		if real_rate >= 1.15 and (pe >= 30.0 or sector in ["technology", "realestate"]):
			return {
				"key": "attr.rateValuationDrag",
				"params": {"rate": SmaFormat.num(real_rate, 1), "pe": SmaFormat.num(pe, 1)},
				"changePct": change_pct,
				"kind": "macro",
			}
		if run_5d >= 3.2:
			return {
				"key": "attr.overboughtPullback",
				"params": {"run5d": SmaFormat.pct(run_5d, 1)},
				"changePct": change_pct,
				"kind": "flow",
			}
		return {
			"key": "attr.orderFlowSell",
			"params": {},
			"changePct": change_pct,
			"kind": "flow",
		}
	else:
		if sector_factor > 0.00045:
			return {
				"key": "attr.sectorInflow",
				"params": {"sector": sector},
				"changePct": change_pct,
				"kind": "flow",
			}
		if run_5d <= -3.2:
			return {
				"key": "attr.oversoldBounce",
				"params": {"run5d": SmaFormat.pct(run_5d, 1)},
				"changePct": change_pct,
				"kind": "flow",
			}
		return {
			"key": "attr.orderFlowBuy",
			"params": {},
			"changePct": change_pct,
			"kind": "flow",
		}


## Builds a date-keyed lookup (`YYYY-MM-DD -> Dictionary`) of all historical &
## live fundamental catalysts for `ticker`, consumed by `SmaCandleChart` hover
## tooltips so past earnings/news/corporate candles show their exact cause.
static func candle_catalyst_map(state: Dictionary, ticker: String) -> Dictionary:
	var symbol := ticker.to_upper()
	var notes := {}
	var day := int(state.get("dayIndex", 0))
	var seed_str := String(state.get("seed", "sim-exchange-v1"))
	if not SmaEtfs.is_etf(symbol) and not SmaCompanyCatalog.get_company(symbol).is_empty():
		var latest_q := SmaFundamentals.latest_quarter(day, symbol)
		for q in range(maxi(SmaFundamentals.FIRST_QUARTER, -4), latest_q + 1):
			var r_day := SmaFundamentals.report_day_for(symbol, q)
			if r_day <= day:
				var ev := SmaEarnings.historical_event(symbol, q, seed_str)
				if not ev.is_empty():
					notes[SmaCalendar.iso_date(r_day)] = {
						"kind": "earnings",
						"period": String(ev.get("periodLabel", "")),
						"reason": String(ev.get("reactionReason", "inlineDigest")),
					}
	var cs: Dictionary = state.get("companies", {}).get(symbol, {})
	var live_earn: Dictionary = cs.get("lastEarnings", {})
	if not live_earn.is_empty():
		notes[SmaCalendar.iso_date(int(live_earn.get("day", 0)))] = {
			"kind": "earnings",
			"period": String(live_earn.get("periodLabel", "")),
			"reason": String(live_earn.get("reactionReason", "inlineDigest")),
		}
	for action in state.get("corporateActions", []):
		if String(action.get("ticker", "")) == symbol:
			var d_iso := SmaCalendar.iso_date(int(action.get("day", 0)))
			notes[d_iso] = {
				"kind": "corporate",
				"type": String(action.get("type", "")),
			}
	for item in state.get("news", []):
		var i_day := int(item.get("day", 0))
		var d_iso := SmaCalendar.iso_date(i_day)
		var i_kind := String(item.get("kind", ""))
		if i_kind == "company" and String(item.get("ticker", "")) == symbol:
			notes[d_iso] = {
				"kind": "news",
				"template": String(item.get("template", "")),
			}
		elif i_kind == "macro" and not notes.has(d_iso):
			notes[d_iso] = {
				"kind": "macro",
				"template": String(item.get("template", "")),
			}
	return notes
