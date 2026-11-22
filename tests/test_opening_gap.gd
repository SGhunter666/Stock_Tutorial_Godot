extends "res://tests/test_base.gd"

const Stage := SmaOpeningGap.Stage


func run() -> void:
	describe("opening-gap-settlement")
	var initial := SmaOpeningGap.start(" Reduce exposure on a gap down. ")
	check(not initial.is_empty(), "scenario data is available")
	if initial.is_empty():
		return
	var brief := SmaOpeningGap.snapshot(initial["attempts"][0])
	eq(brief["points"].size(), 1, "the briefing only exposes the previous close")
	eq(brief["equity"], 2200000, "opening account equity in cents")
	eq(brief["trade"]["cash"], 1200000, "briefing cash in cents")
	eq(initial["exitRule"], "Reduce exposure on a gap down.", "saved rule matches the first plan")
	var opened := SmaOpeningGap.transition(initial, 0, Stage.BRIEFING, "advance")
	var quote := SmaOpeningGap.snapshot(opened["attempts"][0])
	eq(quote["points"].size(), 2, "the open keeps later prices hidden")
	eq(quote["overnight"], -80000, "the overnight gap belongs to the original holding")
	var rows := [
		["sell", 50, 1659650, 2139650, -60350, 9195, 100, 5.47045455, false],
		["hold", 100, 1200000, 2160000, -40000, 0, 0, 7.27272727, false],
		["buy", 150, 739650, 2179650, -20350, 9205, 100, 9.10681818, true],
	]
	var bought: Dictionary = {}
	for row in rows:
		var action: String = row[0]
		var preview := SmaOpeningGap.preview(opened["attempts"][0], action)
		var decided := SmaOpeningGap.transition(opened, 0, Stage.OPEN, "confirm", action)
		var fill := SmaOpeningGap.snapshot(decided["attempts"][0])
		eq(fill["trade"], preview, "%s preview equals actual receipt" % action)
		eq(fill["points"].size(), 2, "%s decision keeps later prices hidden" % action)
		check(SmaOpeningGap.transition(decided, 0, Stage.OPEN, "confirm", action).is_empty(),
			"%s repeated confirmation changes nothing" % action)
		var intraday := SmaOpeningGap.transition(decided, 0, Stage.DECIDED, "advance")
		eq(SmaOpeningGap.snapshot(intraday["attempts"][0])["points"].size(), 3, "no early closing print")
		var closed := SmaOpeningGap.transition(intraday, 0, Stage.INTRADAY, "advance")
		var result := SmaOpeningGap.snapshot(closed["attempts"][0])
		eq(result["trade"]["shares"], row[1], "%s closing position" % action)
		eq(result["trade"]["cash"], row[2], "%s closing cash" % action)
		eq(result["equity"], row[3], "%s closing equity" % action)
		eq(result["pnl"], row[4], "%s net P&L" % action)
		eq(result["trade"]["fill"], row[5], "%s execution price" % action)
		eq(result["trade"]["fee"], row[6], "%s fees" % action)
		approx(result["drawdown"], row[7], 0.00001, "%s drawdown" % action)
		eq(result["exceeded"], row[8], "%s budget outcome" % action)
		check(SmaOpeningGap.is_valid(JSON.parse_string(JSON.stringify(closed))), "attempt survives JSON")
		if action == "buy":
			bought = closed

	describe("opening-gap-comparison")
	check(SmaOpeningGap.transition(bought, 0, Stage.CLOSED, "compare").is_empty(),
		"comparison unlocks after review")
	check(SmaOpeningGap.transition(bought, 0, Stage.CLOSED, "review", " ").is_empty(),
		"a blank reflection cannot complete the chapter")
	var reviewed := SmaOpeningGap.transition(bought, 0, Stage.CLOSED, "review", "My risk grew.", "triggered")
	check(SmaOpeningGap.is_complete(reviewed), "going over budget still allows completion")
	var comparison := SmaOpeningGap.transition(reviewed, 0, Stage.REVIEWED, "compare")
	eq(comparison["attempts"][0], reviewed["attempts"][0], "the comparison keeps the original result")
	eq(SmaOpeningGap.snapshot(comparison["attempts"][1]), brief, "the second attempt starts identically")
	var compare_open := SmaOpeningGap.transition(comparison, 1, Stage.BRIEFING, "advance")
	check(SmaOpeningGap.transition(compare_open, 1, Stage.OPEN, "confirm", "buy").is_empty(),
		"the second attempt has to use another action")
	var malformed := comparison.duplicate(true)
	malformed["attempts"][1]["stage"] = 2.5
	check(not SmaOpeningGap.is_valid(malformed), "invalid stages are rejected")
	check(SmaOpeningGap.is_valid({}), "old saves can omit the scenario")
