## Deterministic Daily Same-Seed 10-Day Sprint rules and risk-adjusted scoring.
## Pure logic module (zero UI dependencies).
class_name SmaDailyChallenge
extends RefCounted

const SPRINT_DAYS := 10
const START_CASH := 100000.0
const MAX_RECORDS := 60


static func today_code() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d.get("year", 2026)), int(d.get("month", 1)), int(d.get("day", 1))]


static func sanitize_code(raw: String) -> String:
	var cleaned := raw.strip_edges().substr(0, 24)
	if cleaned == "":
		return today_code()
	var out := ""
	for i in cleaned.length():
		var ch := cleaned.substr(i, 1)
		var code := ch.unicode_at(0)
		var is_alnum := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) \
			or (code >= 97 and code <= 122) or ch == "-" or ch == "_"
		if is_alnum:
			out += ch
	return out if out != "" else today_code()


static func seed_for_code(code: String) -> String:
	return "daily-" + sanitize_code(code).to_lower()


static func evaluate(start_cash: float, equity_now: float, equity_history: Array,
		trades_count: int, days_elapsed: int) -> Dictionary:
	var base := maxf(1.0, start_cash)
	var ret_pct := SmaFormat.round_to((equity_now - base) / base * 100.0, 2)
	var peak := base
	var max_dd := 0.0
	for pt in equity_history:
		if typeof(pt) != TYPE_DICTIONARY:
			continue
		var eq := float(pt.get("equity", base))
		peak = maxf(peak, eq)
		if peak > 0.0:
			max_dd = maxf(max_dd, (peak - eq) / peak * 100.0)
	peak = maxf(peak, equity_now)
	if peak > 0.0:
		max_dd = maxf(max_dd, (peak - equity_now) / peak * 100.0)
	max_dd = SmaFormat.round_to(max_dd, 2)

	# Risk-adjusted arcade score: rewards net return, penalizes deep drawdown,
	# and requires real market participation (>= 1 trade for positive bonus).
	var participation := mini(trades_count, 8) * 8.0
	var raw_score := 1000.0 + ret_pct * 85.0 - max_dd * 55.0 + participation
	if trades_count <= 0:
		raw_score = minf(raw_score, 950.0)
	var score := maxi(0, int(round(raw_score)))
	var grade := "C"
	if score >= 1450:
		grade = "S"
	elif score >= 1220:
		grade = "A"
	elif score >= 1040:
		grade = "B"
	elif score < 880:
		grade = "D"
	return {
		"returnPct": ret_pct,
		"maxDrawdownPct": max_dd,
		"trades": trades_count,
		"days": days_elapsed,
		"equity": SmaFormat.round_to(equity_now, 2),
		"score": score,
		"grade": grade,
		"completed": days_elapsed >= SPRINT_DAYS,
	}


static func normalize_records(saved: Variant) -> Array:
	var out: Array = []
	if typeof(saved) != TYPE_ARRAY:
		return out
	for entry in saved:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var code := sanitize_code(String(entry.get("code", "")))
		out.append({
			"code": code,
			"seed": String(entry.get("seed", seed_for_code(code))),
			"playerName": String(entry.get("playerName", "")).substr(0, 24),
			"score": int(entry.get("score", 0)),
			"grade": String(entry.get("grade", "C")),
			"returnPct": float(entry.get("returnPct", 0.0)),
			"maxDrawdownPct": float(entry.get("maxDrawdownPct", 0.0)),
			"equity": float(entry.get("equity", START_CASH)),
			"trades": int(entry.get("trades", 0)),
			"days": int(entry.get("days", 0)),
		})
	out.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	if out.size() > MAX_RECORDS:
		out = out.slice(0, MAX_RECORDS)
	return out


static func record_result(records: Array, entry: Dictionary) -> Array:
	var list := normalize_records(records)
	var code := sanitize_code(String(entry.get("code", "")))
	var replaced := false
	for i in list.size():
		if String(list[i]["code"]) == code:
			if int(entry.get("score", 0)) >= int(list[i]["score"]):
				list[i] = entry.duplicate(true)
			replaced = true
			break
	if not replaced:
		list.append(entry.duplicate(true))
	return normalize_records(list)
