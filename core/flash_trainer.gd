## Pure logic for the "Flash Chart Trainer" (K-Line Blind Arcade Drill).
## Slices a random 55-bar window (40 visible history + 15 hidden future bars)
## from real simulated company histories, masks ticker/date, scores Long / Short
## / Pass decisions with Combo streaks, and awards Academy XP + RP without
## touching the player's real trading cash. Zero UI dependencies.
class_name SmaFlashTrainer
extends RefCounted

const VISIBLE_BARS := 40
const FUTURE_BARS := 15
const MIN_TOTAL_BARS := VISIBLE_BARS + FUTURE_BARS + 2
const PASS_WIN_THRESHOLD_PCT := 1.8


static func normalize_stats(saved: Variant) -> Dictionary:
	var out := {
		"played": 0,
		"wins": 0,
		"streak": 0,
		"bestStreak": 0,
		"score": 0,
		"bestScore": 0,
		"roundIndex": 0,
	}
	if typeof(saved) != TYPE_DICTIONARY:
		return out
	for k in out.keys():
		out[k] = maxi(0, int(saved.get(k, out[k])))
	return out


## Generates one deterministic blind K-line puzzle from exchange companies.
static func generate_round(companies: Dictionary, seed_text: String, round_index: int) -> Dictionary:
	var candidates: Array[String] = []
	for tk in companies.keys():
		var comp: Dictionary = companies[tk]
		var bars: Array = comp.get("series", {}).get("daily", comp.get("dailyBars", []))
		if bars.size() >= MIN_TOTAL_BARS:
			candidates.append(String(tk))
	candidates.sort()
	if candidates.is_empty():
		return {"ok": false}

	var rng := SmaRng.new("%s|flash|%d" % [seed_text, round_index])
	var pick_idx := int(floor(rng.next() * float(candidates.size()))) % candidates.size()
	var tk := candidates[pick_idx]
	var comp: Dictionary = companies[tk]
	var bars: Array = comp.get("series", {}).get("daily", comp.get("dailyBars", []))
	var max_start := bars.size() - (VISIBLE_BARS + FUTURE_BARS)
	var start_idx := int(floor(rng.next() * float(maxi(1, max_start + 1)))) % maxi(1, max_start + 1)

	var visible: Array = []
	var future: Array = []
	for i in VISIBLE_BARS:
		var raw: Dictionary = bars[start_idx + i]
		visible.append({
			"o": float(raw.get("o", 0.0)),
			"h": float(raw.get("h", 0.0)),
			"l": float(raw.get("l", 0.0)),
			"c": float(raw.get("c", 0.0)),
			"v": int(raw.get("v", 100000)),
			"d": "T-%02d" % (VISIBLE_BARS - 1 - i),
			"realDate": String(raw.get("d", "")),
		})
	for j in FUTURE_BARS:
		var raw: Dictionary = bars[start_idx + VISIBLE_BARS + j]
		future.append({
			"o": float(raw.get("o", 0.0)),
			"h": float(raw.get("h", 0.0)),
			"l": float(raw.get("l", 0.0)),
			"c": float(raw.get("c", 0.0)),
			"v": int(raw.get("v", 100000)),
			"d": "T+%02d" % (j + 1),
			"realDate": String(raw.get("d", "")),
		})

	var entry_px := float(visible[visible.size() - 1]["c"])
	var exit_px := float(future[future.size() - 1]["c"])
	var raw_ret := ((exit_px - entry_px) / maxf(0.01, entry_px)) * 100.0
	var max_up := 0.0
	var max_dn := 0.0
	for fb in future:
		var hi_pct := (float(fb["h"]) - entry_px) / maxf(0.01, entry_px) * 100.0
		var lo_pct := (float(fb["l"]) - entry_px) / maxf(0.01, entry_px) * 100.0
		max_up = maxf(max_up, hi_pct)
		max_dn = minf(max_dn, lo_pct)

	var mystery_code := "MYSTERY #%04d" % ((round_index * 7919 + pick_idx * 131 + 1042) % 9000 + 1000)
	var meta: Dictionary = comp.get("company", {})
	if meta.is_empty():
		meta = SmaCompanyCatalog.get_company(tk)
	return {
		"ok": true,
		"roundIndex": round_index,
		"mysteryCode": mystery_code,
		"ticker": tk,
		"companyName": String(meta.get("name", comp.get("name", tk))),
		"sector": String(meta.get("sector", comp.get("sector", ""))),
		"startDate": String(visible[0]["realDate"]),
		"decisionDate": String(visible[visible.size() - 1]["realDate"]),
		"endDate": String(future[future.size() - 1]["realDate"]),
		"entryPrice": SmaFormat.round_to(entry_px, 2),
		"exitPrice": SmaFormat.round_to(exit_px, 2),
		"rawReturnPct": SmaFormat.round_to(raw_ret, 2),
		"maxUpPct": SmaFormat.round_to(max_up, 2),
		"maxDownPct": SmaFormat.round_to(max_dn, 2),
		"visibleBars": visible,
		"futureBars": future,
	}


## Scores a player's Long / Short / Pass decision and updates lifetime stats.
static func settle(round_data: Dictionary, choice: String, stats_in: Dictionary) -> Dictionary:
	var stats := normalize_stats(stats_in)
	var c := choice if choice in ["long", "short", "pass"] else "pass"
	var raw_ret := float(round_data.get("rawReturnPct", 0.0))
	var player_ret := 0.0
	var won := false
	var verdict_key := "flash.verdict.passChop"
	var tone := "neutral"

	if c == "long":
		player_ret = raw_ret
		won = raw_ret > 0.35
		verdict_key = "flash.verdict.longHit" if won else "flash.verdict.longMiss"
		tone = "win" if won else "loss"
	elif c == "short":
		player_ret = -raw_ret
		won = raw_ret < -0.35
		verdict_key = "flash.verdict.shortHit" if won else "flash.verdict.shortMiss"
		tone = "win" if won else "loss"
	else:
		player_ret = 0.0
		if absf(raw_ret) <= PASS_WIN_THRESHOLD_PCT:
			won = true
			verdict_key = "flash.verdict.passChop"
			tone = "win"
		elif raw_ret <= -3.5:
			won = true
			verdict_key = "flash.verdict.passDodge"
			tone = "win"
		else:
			won = false
			verdict_key = "flash.verdict.passMissed"
			tone = "neutral"

	stats["played"] = int(stats["played"]) + 1
	stats["roundIndex"] = maxi(int(stats["roundIndex"]) + 1, int(round_data.get("roundIndex", 0)) + 1)
	var delta_score := 0
	var xp := 8
	if won:
		stats["wins"] = int(stats["wins"]) + 1
		stats["streak"] = int(stats["streak"]) + 1
		stats["bestStreak"] = maxi(int(stats["bestStreak"]), int(stats["streak"]))
		var bonus := mini(int(stats["streak"]), 6) * 25
		delta_score = 100 + int(round(absf(player_ret) * 12.0)) + bonus
		xp = 15 + mini(int(stats["streak"]) * 5, 25)
	else:
		stats["streak"] = 0
		delta_score = -40 if c != "pass" else 0
		xp = 8
	stats["score"] = maxi(0, int(stats["score"]) + delta_score)
	stats["bestScore"] = maxi(int(stats["bestScore"]), int(stats["score"]))

	return {
		"ok": true,
		"choice": c,
		"won": won,
		"tone": tone,
		"verdictKey": verdict_key,
		"playerReturnPct": SmaFormat.round_to(player_ret, 2),
		"rawReturnPct": SmaFormat.round_to(raw_ret, 2),
		"scoreDelta": delta_score,
		"xp": xp,
		"stats": stats,
	}
