## Deterministic market news emitted at the start of each trading day:
## 1. Differentiated macro shocks (rate hikes hurt high-P/E tech & REITs while
##    lifting bank NIMs; hot inflation lifts energy & copper while squeezing
##    consumer/industrial margins; recession fear spares defensive sectors).
## 2. Sector-authentic company events (FDA trials for biotech, fab/export news
##    for semiconductors, regulatory/credit events for banks — never absurd
##    "product recalls" on banks or REITs!) plus crowded Hard-to-Borrow Short
##    Squeezes (+11%..+21%).
class_name SmaNews
extends RefCounted

const LIMIT := 80

const COMPANY_EVENTS := [
	{"template": "contractWin", "min": 2.0, "max": 6.0},
	{"template": "lawsuit", "min": -7.0, "max": -2.0},
	{"template": "ceoExit", "min": -5.0, "max": -2.0},
	{"template": "recall", "min": -6.0, "max": -3.0},
	{"template": "upgrade", "min": 1.0, "max": 4.0},
	{"template": "downgrade", "min": -4.0, "max": -1.0},
]

const SECTOR_COMPANY_EVENTS := {
	"technology": [
		{"template": "chipBreakthrough", "min": 3.0, "max": 7.5},
		{"template": "exportRestriction", "min": -7.5, "max": -2.8},
		{"template": "cloudOutage", "min": -5.2, "max": -1.8},
		{"template": "contractWin", "min": 2.2, "max": 6.0},
		{"template": "upgrade", "min": 1.2, "max": 4.2},
		{"template": "downgrade", "min": -4.2, "max": -1.2},
	],
	"healthcare": [
		{"template": "fdaApproval", "min": 4.5, "max": 9.2},
		{"template": "trialFail", "min": -9.5, "max": -4.2},
		{"template": "patentCliff", "min": -5.5, "max": -2.2},
		{"template": "upgrade", "min": 1.2, "max": 4.0},
		{"template": "downgrade", "min": -4.0, "max": -1.2},
	],
	"financials": [
		{"template": "buybackBoost", "min": 2.0, "max": 5.0},
		{"template": "regFine", "min": -5.5, "max": -2.0},
		{"template": "creditLossSpike", "min": -6.5, "max": -2.5},
		{"template": "ceoExit", "min": -4.5, "max": -1.8},
		{"template": "upgrade", "min": 1.0, "max": 3.8},
		{"template": "downgrade", "min": -3.8, "max": -1.0},
	],
	"energy": [
		{"template": "reserveDiscovery", "min": 3.0, "max": 6.8},
		{"template": "pipelineOutage", "min": -6.2, "max": -2.5},
		{"template": "contractWin", "min": 2.0, "max": 5.2},
		{"template": "upgrade", "min": 1.0, "max": 3.8},
		{"template": "downgrade", "min": -3.8, "max": -1.0},
	],
	"materials": [
		{"template": "reserveDiscovery", "min": 2.8, "max": 6.5},
		{"template": "pipelineOutage", "min": -5.8, "max": -2.2},
		{"template": "contractWin", "min": 2.0, "max": 5.0},
		{"template": "upgrade", "min": 1.0, "max": 3.8},
		{"template": "downgrade", "min": -3.8, "max": -1.0},
	],
	"consumer": [
		{"template": "contractWin", "min": 2.0, "max": 5.5},
		{"template": "recall", "min": -6.5, "max": -2.8},
		{"template": "supplyChainHit", "min": -5.2, "max": -2.0},
		{"template": "lawsuit", "min": -5.5, "max": -2.0},
		{"template": "upgrade", "min": 1.2, "max": 4.0},
		{"template": "downgrade", "min": -4.0, "max": -1.2},
	],
	"industrials": [
		{"template": "contractWin", "min": 2.4, "max": 6.2},
		{"template": "recall", "min": -6.8, "max": -3.0},
		{"template": "supplyChainHit", "min": -5.4, "max": -2.0},
		{"template": "lawsuit", "min": -5.8, "max": -2.0},
		{"template": "upgrade", "min": 1.2, "max": 4.0},
		{"template": "downgrade", "min": -4.0, "max": -1.2},
	],
	"communication": [
		{"template": "contractWin", "min": 2.2, "max": 5.8},
		{"template": "regFine", "min": -5.2, "max": -2.0},
		{"template": "ceoExit", "min": -4.8, "max": -2.0},
		{"template": "lawsuit", "min": -5.5, "max": -2.0},
		{"template": "upgrade", "min": 1.2, "max": 4.2},
		{"template": "downgrade", "min": -4.2, "max": -1.2},
	],
	"realestate": [
		{"template": "buybackBoost", "min": 1.8, "max": 4.5},
		{"template": "creditLossSpike", "min": -5.5, "max": -2.0},
		{"template": "lawsuit", "min": -5.0, "max": -1.8},
		{"template": "upgrade", "min": 1.0, "max": 3.5},
		{"template": "downgrade", "min": -3.5, "max": -1.0},
	],
	"utilities": [
		{"template": "contractWin", "min": 1.5, "max": 4.0},
		{"template": "regFine", "min": -4.5, "max": -1.6},
		{"template": "pipelineOutage", "min": -4.8, "max": -1.8},
		{"template": "upgrade", "min": 0.9, "max": 3.0},
		{"template": "downgrade", "min": -3.0, "max": -0.9},
	],
	"telecom": [
		{"template": "contractWin", "min": 1.6, "max": 4.2},
		{"template": "cloudOutage", "min": -4.8, "max": -1.8},
		{"template": "regFine", "min": -4.5, "max": -1.8},
		{"template": "upgrade", "min": 1.0, "max": 3.2},
		{"template": "downgrade", "min": -3.2, "max": -1.0},
	],
}

const MACRO_EVENTS := [
	{"template": "rateCut", "min": 1.0, "max": 3.0},
	{"template": "rateHike", "min": -3.0, "max": -1.0},
	{"template": "inflationCool", "min": 1.0, "max": 2.5},
	{"template": "inflationHot", "min": -2.5, "max": -1.0},
	{"template": "growthStrong", "min": 1.0, "max": 2.5},
	{"template": "recessionFear", "min": -2.5, "max": -1.0},
]


## Differentiates how each sector reacts to a macro shock (`pct` has the sign of
## the broad equity index reaction). Negative return values invert the sign (e.g.
## energy & copper rally when `inflationHot` has `pct < 0`, and traditional
## banks gain NIM when `rateHike` has `pct < 0`).
static func macro_sector_multiplier(template: String, company: Dictionary) -> float:
	var sector := String(company.get("sector", ""))
	var beta := clampf(float(company.get("beta", 1.0)), 0.45, 2.0)
	match template:
		"rateHike":
			if sector == "financials" and beta < 1.5:
				return -0.35
			if sector in ["technology", "realestate"]:
				return 1.32 * beta
			if sector == "utilities":
				return 1.15
			if sector in ["energy", "healthcare"]:
				return 0.55
			return 0.95 * beta
		"rateCut":
			if sector in ["realestate", "technology"]:
				return 1.32 * beta
			if sector == "utilities":
				return 1.18
			if sector == "financials" and beta < 1.5:
				return 0.35
			return 0.95 * beta
		"inflationHot":
			if sector in ["energy", "materials"]:
				return -0.82
			if sector in ["consumer", "industrials", "technology"]:
				return 1.18 * beta
			return 0.85 * beta
		"inflationCool":
			if sector in ["consumer", "technology"]:
				return 1.22 * beta
			if sector in ["energy", "materials"]:
				return -0.25
			return 0.90 * beta
		"recessionFear":
			if sector in ["healthcare", "utilities", "telecom"]:
				return 0.28
			if sector in ["industrials", "energy", "materials", "financials"]:
				return 1.28 * beta
			return 1.0 * beta
		"growthStrong":
			if sector in ["industrials", "financials", "energy", "consumer", "technology"]:
				return 1.12 * beta
			if sector in ["utilities", "telecom"]:
				return 0.42
			return 0.90 * beta
	return beta


static func pool_for_company(company: Dictionary) -> Array:
	var sector := String(company.get("sector", ""))
	if SECTOR_COMPANY_EVENTS.has(sector):
		return SECTOR_COMPANY_EVENTS[sector]
	return COMPANY_EVENTS


static func _apply_shock(cs: Dictionary, pct: float) -> void:
	var last := maxf(0.01, float(cs.get("last", 0.0)) * (1.0 + pct / 100.0))
	var base := maxf(0.01, float(cs.get("company", {}).get("price", last)))
	cs["last"] = last
	cs["open"] = last
	cs["high"] = maxf(float(cs.get("high", last)), last)
	cs["low"] = minf(float(cs.get("low", last)), last)
	cs["fairValue"] = clampf(last, base * 0.15, base * 6.0)


static func _push(state: Dictionary, entry: Dictionary) -> void:
	var items: Array = state.get("news", [])
	entry["id"] = int(state.get("newsSeq", 0))
	state["newsSeq"] = int(state.get("newsSeq", 0)) + 1
	items.append(entry)
	while items.size() > LIMIT:
		items.pop_front()
	state["news"] = items


static func _eligible_companies(state: Dictionary) -> Array:
	var result: Array = []
	for ticker in state["companies"].keys():
		var cs: Dictionary = state["companies"][ticker]
		var company: Dictionary = cs.get("company", {})
		if bool(company.get("isEtf", false)) or bool(cs.get("delisted", false)):
			continue
		result.append({"ticker": String(ticker), "company": company})
	return result


## Emits one macro roll (with sector-differentiated impact) and up to two
## sector-authentic company events (including Hard-to-Borrow short squeezes).
static func maybe_emit(state: Dictionary, rng: SmaRng) -> Array:
	var emitted: Array = []
	var companies := _eligible_companies(state)
	if companies.is_empty():
		return emitted
	var day := int(state.get("dayIndex", 0))
	if rng.next() < 0.22:
		var kind: Dictionary = rng.pick(MACRO_EVENTS)
		var tmpl := String(kind["template"])
		var pct := rng.range_float(float(kind["min"]), float(kind["max"]))
		for entry in companies:
			var cs: Dictionary = state["companies"][String(entry["ticker"])]
			var mult := macro_sector_multiplier(tmpl, entry["company"])
			_apply_shock(cs, pct * mult)
		var news := {
			"day": day, "tick": 0, "kind": "macro",
			"template": tmpl, "ticker": "",
			"pct": roundf(pct * 10.0) / 10.0,
		}
		_push(state, news)
		emitted.append(news)
	if rng.next() < 0.52:
		var count := 2 if rng.next() < 0.20 else 1
		for index in count:
			var entry: Dictionary = rng.pick(companies)
			var company: Dictionary = entry["company"]
			var htb_fee := SmaMargin.borrow_fee_rate(company)
			var kind: Dictionary
			if htb_fee >= 0.12 and rng.next() < 0.22:
				kind = {"template": "shortSqueeze", "min": 10.5, "max": 21.0}
			else:
				kind = rng.pick(pool_for_company(company))
			var pct := rng.range_float(float(kind["min"]), float(kind["max"]))
			var cs: Dictionary = state["companies"][String(entry["ticker"])]
			_apply_shock(cs, pct)
			var news := {
				"day": day, "tick": 0, "kind": "company",
				"template": String(kind["template"]),
				"ticker": String(entry["ticker"]),
				"pct": roundf(pct * 10.0) / 10.0,
			}
			_push(state, news)
			emitted.append(news)
	return emitted
