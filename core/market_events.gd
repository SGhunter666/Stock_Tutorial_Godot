## Interactive High-Stakes Market Event Decision Desk:
##   1. Hot Unicorn IPO Subscriptions ("ipo")
##   2. Live Earnings Call Q&A Pricing ("earnings_call")
##   3. FOMC Rate Decision Night Positioning ("fomc")
## Pure deterministic core module with zero UI dependencies.
class_name SmaMarketEvents
extends RefCounted

const SLOT_INTERVAL := 3

const TEMPLATES := [
	{
		"code": "ipo_qacl",
		"kind": "ipo",
		"ticker": "NVDO",
		"issuer": "QACL · QuantAI Cloud",
		"revGrowth": 92.0,
		"netMargin": -22.0,
		"psMultiple": 31.0,
		"oversub": 7.2,
		"basePop": 0.24,
		"rateSensitive": true,
	},
	{
		"code": "call_nvdo",
		"kind": "earnings_call",
		"ticker": "NVDO",
		"surprisePct": 11.4,
		"runupPct": 18.5,
		"correctCall": "drop",
	},
	{
		"code": "fomc_cycle",
		"kind": "fomc",
		"ticker": "MKT",
		"bias": "auto",
	},
	{
		"code": "ipo_hlxb",
		"kind": "ipo",
		"ticker": "LLLY",
		"issuer": "HLXB · HelixBio",
		"revGrowth": 0.0,
		"netMargin": -100.0,
		"psMultiple": 48.0,
		"oversub": 1.3,
		"basePop": -0.17,
		"rateSensitive": true,
	},
	{
		"code": "call_tslo",
		"kind": "earnings_call",
		"ticker": "TSLO",
		"surprisePct": -6.2,
		"runupPct": -22.0,
		"correctCall": "rally",
	},
	{
		"code": "ipo_nvpy",
		"kind": "ipo",
		"ticker": "VISO",
		"issuer": "NVPY · NovaPay",
		"revGrowth": 34.0,
		"netMargin": 19.0,
		"psMultiple": 6.4,
		"oversub": 4.6,
		"basePop": 0.16,
		"rateSensitive": false,
	},
	{
		"code": "call_msfy",
		"kind": "earnings_call",
		"ticker": "MSFY",
		"surprisePct": 4.8,
		"runupPct": 16.0,
		"correctCall": "drop",
	},
	{
		"code": "fomc_inflation",
		"kind": "fomc",
		"ticker": "FINX",
		"bias": "hawkish",
	},
	{
		"code": "call_boen",
		"kind": "earnings_call",
		"ticker": "BOEN",
		"surprisePct": 5.1,
		"runupPct": 9.4,
		"correctCall": "drop",
	},
]


static func slot_for_day(day: int) -> int:
	if day < 1:
		return -1
	return int((day - 1) / SLOT_INTERVAL)


static func active_event(state: Dictionary, academy: Dictionary) -> Dictionary:
	var day := int(state.get("dayIndex", 0))
	var slot := slot_for_day(day)
	if slot < 0:
		return {}
	var tmpl: Dictionary = TEMPLATES[slot % TEMPLATES.size()]
	var code := String(tmpl["code"])
	var event_id := "mkt-evt-%d-%s" % [slot, code]
	var store := _event_store(academy)
	var resolved_map: Dictionary = store.get("resolved", {})
	var resolved_entry: Dictionary = resolved_map.get(event_id, {})

	var kind := String(tmpl["kind"])
	var macro: Dictionary = state.get("macro", {})
	var policy_rate := float(macro.get("policyRate", 3.5))
	var inflation := float(macro.get("inflation", 2.4))
	var regime := String(macro.get("regime", "expansion"))

	var choices: Array = []
	if kind == "ipo":
		choices = [
			{"id": "heavy", "labelKey": "events.choice.ipoHeavy", "stake": 8000.0},
			{"id": "light", "labelKey": "events.choice.ipoLight", "stake": 2500.0},
			{"id": "skip", "labelKey": "events.choice.ipoSkip", "stake": 0.0},
		]
	elif kind == "earnings_call":
		choices = [
			{"id": "rally", "labelKey": "events.choice.callRally", "stake": 0.0},
			{"id": "drop", "labelKey": "events.choice.callDrop", "stake": 0.0},
			{"id": "wait", "labelKey": "events.choice.callWait", "stake": 0.0},
		]
	else:
		choices = [
			{"id": "dovish", "labelKey": "events.choice.fomcDovish", "stake": 0.0},
			{"id": "hawkish", "labelKey": "events.choice.fomcHawkish", "stake": 0.0},
			{"id": "hedge", "labelKey": "events.choice.fomcHedge", "stake": 0.0},
		]

	return {
		"id": event_id,
		"slot": slot,
		"day": day,
		"expiresDay": (slot + 1) * SLOT_INTERVAL,
		"code": code,
		"kind": kind,
		"ticker": String(tmpl.get("ticker", "MKT")),
		"issuer": String(tmpl.get("issuer", "")),
		"titleKey": "events.%s.title" % code,
		"clueKey": "events.%s.clue" % code,
		"metrics": {
			"revGrowth": float(tmpl.get("revGrowth", 0.0)),
			"netMargin": float(tmpl.get("netMargin", 0.0)),
			"psMultiple": float(tmpl.get("psMultiple", 0.0)),
			"oversub": float(tmpl.get("oversub", 0.0)),
			"surprisePct": float(tmpl.get("surprisePct", 0.0)),
			"runupPct": float(tmpl.get("runupPct", 0.0)),
			"policyRate": SmaFormat.round_to(policy_rate, 2),
			"inflation": SmaFormat.round_to(inflation, 2),
			"regime": regime,
		},
		"choices": choices,
		"resolved": not resolved_entry.is_empty(),
		"resolution": resolved_entry,
	}


static func has_pending_event(state: Dictionary, academy: Dictionary) -> bool:
	var evt := active_event(state, academy)
	return not evt.is_empty() and not bool(evt.get("resolved", false))


static func resolve(state: Dictionary, academy: Dictionary, choice_id: String,
		cash_available: float) -> Dictionary:
	var evt := active_event(state, academy)
	if evt.is_empty():
		return {"ok": false, "error": "events.errorNone"}
	if bool(evt.get("resolved", false)):
		return {"ok": false, "error": "events.errorAlready"}
	var valid := false
	var stake := 0.0
	for c in evt["choices"]:
		if String(c["id"]) == choice_id:
			valid = true
			stake = float(c.get("stake", 0.0))
			break
	if not valid:
		return {"ok": false, "error": "events.errorChoice"}
	if stake > 0.0 and cash_available < stake:
		return {"ok": false, "error": "events.errorCash"}

	var code := String(evt["code"])
	var kind := String(evt["kind"])
	var slot := int(evt["slot"])
	var seed_str := "%s|mkt-event|%d|%s" % [String(state.get("seed", "sim")), slot, code]
	var rng := SmaRng.new(seed_str)
	var tmpl: Dictionary = TEMPLATES[slot % TEMPLATES.size()]
	var macro: Dictionary = state.get("macro", {})
	var policy_rate := float(macro.get("policyRate", 3.5))
	var inflation := float(macro.get("inflation", 2.4))

	var cash_delta := 0.0
	var xp_gain := 20
	var tone := "neutral"
	var explain_key := "events.%s.explain" % code
	var metric_text := ""
	var verdict_key := "events.verdict.neutral"

	if kind == "ipo":
		var base_pop := float(tmpl.get("basePop", 0.0))
		var rate_drag := -0.14 if (bool(tmpl.get("rateSensitive", false)) and policy_rate >= 4.75) else 0.0
		var noise := rng.range_float(-0.07, 0.08)
		var pop_pct := clampf(base_pop + rate_drag + noise, -0.32, 0.42)
		metric_text = SmaFormat.pct(pop_pct * 100.0, 1)
		if choice_id == "skip":
			if pop_pct < 0.0:
				cash_delta = 250.0
				xp_gain = 35
				tone = "win"
				verdict_key = "events.verdict.ipoDodged"
			else:
				cash_delta = 0.0
				xp_gain = 15
				tone = "neutral"
				verdict_key = "events.verdict.ipoPassed"
		else:
			cash_delta = SmaFormat.round_to(stake * pop_pct, 2)
			xp_gain = 35 if cash_delta >= 0.0 else 25
			tone = "win" if cash_delta > 0.0 else "loss"
			verdict_key = "events.verdict.ipoPop" if cash_delta >= 0.0 else "events.verdict.ipoBreak"
	elif kind == "earnings_call":
		var correct := String(tmpl.get("correctCall", "drop"))
		var move_pct := rng.range_float(5.5, 9.5) * (1.0 if correct == "rally" else -1.0)
		metric_text = SmaFormat.pct(move_pct, 1)
		if choice_id == "wait":
			cash_delta = 150.0
			xp_gain = 20
			tone = "neutral"
			verdict_key = "events.verdict.callCalm"
		elif choice_id == correct:
			cash_delta = 650.0
			xp_gain = 40
			tone = "win"
			verdict_key = "events.verdict.callHit"
		else:
			cash_delta = -320.0
			xp_gain = 25
			tone = "loss"
			verdict_key = "events.verdict.callMiss"
	else:
		var bias := String(tmpl.get("bias", "auto"))
		var outcome := "hawkish"
		if bias == "hawkish":
			outcome = "hawkish"
		else:
			if inflation >= 3.2:
				outcome = "hawkish"
			elif policy_rate >= 4.5 and inflation <= 2.5:
				outcome = "dovish"
			else:
				outcome = "dovish" if rng.next() >= 0.5 else "hawkish"
		metric_text = "events.fomcOutcome.%s" % outcome
		if choice_id == "hedge":
			cash_delta = 220.0
			xp_gain = 30
			tone = "win"
			verdict_key = "events.verdict.fomcHedge"
		elif choice_id == outcome:
			cash_delta = 820.0
			xp_gain = 45
			tone = "win"
			verdict_key = "events.verdict.fomcHit"
		else:
			cash_delta = -450.0
			xp_gain = 25
			tone = "loss"
			verdict_key = "events.verdict.fomcMiss"

	var resolution := {
		"eventId": String(evt["id"]),
		"choiceId": choice_id,
		"day": int(evt["day"]),
		"cashDelta": cash_delta,
		"xp": xp_gain,
		"tone": tone,
		"metricText": metric_text,
		"verdictKey": verdict_key,
		"explainKey": explain_key,
	}
	var store := _event_store(academy)
	var resolved_map: Dictionary = store.get("resolved", {})
	resolved_map[String(evt["id"])] = resolution
	store["resolved"] = resolved_map
	var history: Array = store.get("history", [])
	history.push_front(resolution)
	store["history"] = history.slice(0, 24)
	_save_event_store(academy, store)
	SmaAcademy.award_xp(academy, "mktevt:%s" % String(evt["id"]), xp_gain)
	return {"ok": true, "event": evt, "resolution": resolution}


static func _event_store(academy: Dictionary) -> Dictionary:
	var milestones: Dictionary = academy.get("milestones", {})
	var raw: Variant = milestones.get("marketEvents", {})
	return raw.duplicate(true) if typeof(raw) == TYPE_DICTIONARY else {}


static func _save_event_store(academy: Dictionary, store: Dictionary) -> void:
	if academy.is_empty():
		return
	var milestones: Dictionary = academy.get("milestones", {})
	milestones["marketEvents"] = store
	academy["milestones"] = milestones
