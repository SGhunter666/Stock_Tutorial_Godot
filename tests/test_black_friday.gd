## Playable Black Friday liquidity-crisis scenario state machine & accounting.
extends "res://tests/test_base.gd"


func run() -> void:
	describe("black-friday-init")
	var state := SmaBlackFriday.start("high")
	check(not state.is_empty(), "scenario starts cleanly")
	check(SmaBlackFriday.is_valid(state), "initial state is valid")
	eq(SmaBlackFriday.is_complete(state), false, "initial state is not complete")
	var snap0 := SmaBlackFriday.snapshot(state["attempts"][0])
	eq(int(snap0["startAum"]), 100000000, "starting AUM is $1,000,000 in cents")
	approx(float(snap0["nav"]), 1.0, 0.0001, "starting NAV is 1.0")

	describe("black-friday-protect-path")
	state = SmaBlackFriday.transition(state, 0, SmaBlackFriday.Stage.BRIEFING, "advance")
	check(not state.is_empty(), "briefing advances to 09:30")
	var preview_protect := SmaBlackFriday.preview(state["attempts"][0], "protect")
	check(int(preview_protect["haircutCents"]) > 0, "protect preview shows real liquidity haircut")
	approx(float(preview_protect["coveragePct"]), 100.0, 0.01, "protect covers wave 1 redemptions")

	state = SmaBlackFriday.transition(state, 0, SmaBlackFriday.Stage.OPEN_0930, "confirm_open", "protect")
	eq(int(state["attempts"][0]["stage"]), SmaBlackFriday.Stage.AFTER_0930, "09:30 decision recorded")
	check(SmaBlackFriday.transition(state, 0, SmaBlackFriday.Stage.OPEN_0930, "confirm_open", "gate").is_empty(),
		"stale stage transition is discarded")
	state = SmaBlackFriday.transition(state, 0, SmaBlackFriday.Stage.AFTER_0930, "advance")
	state = SmaBlackFriday.transition(state, 0, SmaBlackFriday.Stage.CRUNCH_1100, "confirm_crunch", "protect")
	state = SmaBlackFriday.transition(state, 0, SmaBlackFriday.Stage.AFTER_1100, "advance")
	eq(int(state["attempts"][0]["stage"]), SmaBlackFriday.Stage.CLOSED, "reaches 14:30 close")
	var snap_protect := SmaBlackFriday.snapshot(state["attempts"][0])
	approx(float(snap_protect["coveragePct"]), 100.0, 0.01, "protect honors 100% of redemptions")
	check(int(snap_protect["haircutCents"]) > 0, "protect realizes liquidity haircut cost")
	eq(String(snap_protect["crisisChoice"]), "protect", "derives protect crisis choice")
	eq(String(snap_protect["trustOutcome"]), "retained", "client trust retained under protect")

	describe("black-friday-review-and-compare")
	check(SmaBlackFriday.transition(state, 0, SmaBlackFriday.Stage.CLOSED, "review", "   ").is_empty(),
		"blank reflection is rejected")
	state = SmaBlackFriday.transition(state, 0, SmaBlackFriday.Stage.CLOSED, "review",
		"Cash buffers must be sized before a panic run hits.")
	check(SmaBlackFriday.is_complete(state), "review completes attempt 1")
	state = SmaBlackFriday.transition(state, 0, SmaBlackFriday.Stage.REVIEWED, "compare")
	eq(state["attempts"].size(), 2, "comparison starts attempt 2")
	var open_choices2 := SmaBlackFriday.available_actions(state, SmaBlackFriday.Stage.OPEN_0930)
	check(not open_choices2.has("protect"), "attempt 2 excludes attempt 1 opening move")
	state = SmaBlackFriday.transition(state, 1, SmaBlackFriday.Stage.BRIEFING, "advance")
	state = SmaBlackFriday.transition(state, 1, SmaBlackFriday.Stage.OPEN_0930, "confirm_open", "gate")
	state = SmaBlackFriday.transition(state, 1, SmaBlackFriday.Stage.AFTER_0930, "advance")
	state = SmaBlackFriday.transition(state, 1, SmaBlackFriday.Stage.CRUNCH_1100, "confirm_crunch", "gate")
	state = SmaBlackFriday.transition(state, 1, SmaBlackFriday.Stage.AFTER_1100, "advance")
	var snap_gate := SmaBlackFriday.snapshot(state["attempts"][1])
	eq(int(snap_gate["haircutCents"]), 0, "gate incurs zero fire-sale haircut")
	approx(float(snap_gate["coveragePct"]), 0.0, 0.01, "gate freezes redemptions")
	eq(String(snap_gate["crisisChoice"]), "gate", "derives gate crisis choice")
	eq(String(snap_gate["trustOutcome"]), "strained", "gate strains client trust")
	check(float(snap_gate["nav"]) > float(snap_protect["nav"]),
		"gate preserves higher NAV than fire-sale liquidation")

	describe("black-friday-attack-path")
	var attack_state := SmaBlackFriday.start("low")
	attack_state = SmaBlackFriday.transition(attack_state, 0, SmaBlackFriday.Stage.BRIEFING, "advance")
	attack_state = SmaBlackFriday.transition(attack_state, 0, SmaBlackFriday.Stage.OPEN_0930, "confirm_open", "attack")
	attack_state = SmaBlackFriday.transition(attack_state, 0, SmaBlackFriday.Stage.AFTER_0930, "advance")
	attack_state = SmaBlackFriday.transition(attack_state, 0, SmaBlackFriday.Stage.CRUNCH_1100, "confirm_crunch", "attack")
	attack_state = SmaBlackFriday.transition(attack_state, 0, SmaBlackFriday.Stage.AFTER_1100, "advance")
	var snap_attack := SmaBlackFriday.snapshot(attack_state["attempts"][0])
	eq(String(snap_attack["crisisChoice"]), "attack", "derives attack crisis choice")
	eq(String(snap_attack["trustOutcome"]), "broken", "attack breaks fiduciary trust")
	approx(float(snap_attack["coveragePct"]), 0.0, 0.01, "attack leaves redemptions unpaid")
	check(float(snap_attack["maxDrawdown"]) > float(snap_protect["maxDrawdown"]),
		"attack suffers deeper intraday drawdown")

	describe("black-friday-validation")
	var roundtrip: Variant = JSON.parse_string(JSON.stringify(state))
	check(roundtrip is Dictionary and SmaBlackFriday.is_valid(roundtrip),
		"serialized state survives JSON roundtrip")
	var bad := state.duplicate(true)
	bad["attempts"][0]["openAction"] = "invalid"
	eq(SmaBlackFriday.is_valid(bad), false, "invalid action fails validation")
