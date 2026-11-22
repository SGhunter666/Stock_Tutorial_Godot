extends "res://tests/test_base.gd"


func run() -> void:
	describe("alerts-defaults")
	var state := SmaAlerts.create_state()
	eq(SmaAlerts.watchlist(state).size(), 0, "watchlist starts empty")
	eq(SmaAlerts.all(state).size(), 0, "alerts start empty")
	eq(SmaAlerts.active_count(state), 0, "no active alerts")
	check(not SmaAlerts.is_watched(state, "APLA"), "nothing watched initially")

	describe("alerts-watchlist")
	var watched := SmaAlerts.toggle_watch(state, "apla")
	check(watched, "toggle adds a ticker")
	check(SmaAlerts.is_watched(state, "APLA"), "ticker lookup is case-insensitive")
	eq(SmaAlerts.watchlist(state).size(), 1, "watchlist has one ticker")
	var duplicate := SmaAlerts.toggle_watch(state, "APLA")
	check(not duplicate, "second toggle removes the ticker")
	eq(SmaAlerts.watchlist(state).size(), 0, "ticker removed")
	check(not SmaAlerts.toggle_watch(state, "  "), "blank ticker is rejected")

	describe("alerts-add-remove")
	state = SmaAlerts.create_state()
	var added := SmaAlerts.add_alert(state, "apla", "above", 120.556, 3)
	check(bool(added.get("ok", false)), "alert added")
	var alert: Dictionary = added.get("alert", {})
	eq(String(alert.get("ticker", "")), "APLA", "ticker normalized")
	eq(String(alert.get("side", "")), "above", "side stored")
	approx(float(alert.get("price", 0.0)), 120.56, 0.001, "price rounded to cents")
	eq(int(alert.get("createdDay", -1)), 3, "creation day stored")
	check(bool(alert.get("active", false)), "new alert is active")
	eq(SmaAlerts.alerts_for(state, "APLA").size(), 1, "alerts_for filters ticker")
	eq(SmaAlerts.alerts_for(state, "GOGL").size(), 0, "other ticker has no alerts")
	check(not bool(SmaAlerts.add_alert(state, "APLA", "sideways", 100.0, 3).get("ok", true)),
		"invalid side rejected")
	check(not bool(SmaAlerts.add_alert(state, "APLA", "above", 0.0, 3).get("ok", true)),
		"non-positive price rejected")
	var alert_id := String(alert.get("id", ""))
	check(SmaAlerts.remove_alert(state, alert_id), "alert removed by id")
	eq(SmaAlerts.all(state).size(), 0, "alert list empty after removal")
	check(not SmaAlerts.remove_alert(state, alert_id), "removing twice is a no-op")

	describe("alerts-limit")
	state = SmaAlerts.create_state()
	for index in SmaAlerts.MAX_ALERTS:
		SmaAlerts.add_alert(state, "APLA", "above", 100.0 + float(index), index)
	eq(SmaAlerts.all(state).size(), SmaAlerts.MAX_ALERTS, "alert cap reached")
	var overflow := SmaAlerts.add_alert(state, "APLA", "above", 999.0, 0)
	check(not bool(overflow.get("ok", true)), "alert over cap is rejected")
	eq(String(overflow.get("error", "")), "alerts.limitReached",
		"alert cap reports the right error")

	describe("alerts-check")
	state = SmaAlerts.create_state()
	var above := SmaAlerts.add_alert(state, "APLA", "above", 120.0, 2)
	var below := SmaAlerts.add_alert(state, "APLA", "below", 90.0, 2)
	check(not above.is_empty() and not below.is_empty(), "two alerts created")
	var prices := {"APLA": 119.99}
	eq(SmaAlerts.check(state, prices, 2, 10).size(), 0, "no trigger before threshold")
	prices["APLA"] = 120.0
	var hits := SmaAlerts.check(state, prices, 2, 20)
	eq(hits.size(), 1, "equality triggers the above alert")
	eq(String(hits[0].get("side", "")), "above", "above alert triggered")
	check(not bool(hits[0].get("active", true)), "triggered alert deactivated")
	eq(int(hits[0].get("triggeredDay", -1)), 2, "trigger day recorded")
	approx(float(hits[0].get("triggeredPrice", 0.0)), 120.0, 0.001,
		"trigger price recorded")
	eq(SmaAlerts.check(state, prices, 2, 30).size(), 0,
		"triggered alert does not repeat")
	prices["APLA"] = 90.01
	eq(SmaAlerts.check(state, prices, 3, 0).size(), 0, "below not hit yet")
	prices["APLA"] = 90.0
	hits = SmaAlerts.check(state, prices, 3, 10)
	eq(hits.size(), 1, "equality triggers the below alert")
	eq(SmaAlerts.active_count(state), 0, "all alerts inactive after both fire")
	eq(SmaAlerts.check(state, {"UNKNOWN": 1.0}, 3, 20).size(), 0,
		"unknown ticker ignored")
	SmaAlerts.add_alert(state, "APLA", "above", 200.0, 4)
	eq(SmaAlerts.remove_triggered(state), 2, "triggered alerts are cleared")
	eq(SmaAlerts.all(state).size(), 1, "active alert survives the cleanup")
	eq(SmaAlerts.active_count(state), 1, "surviving alert stays active")

	describe("alerts-normalize")
	var dirty := {
		"watchlist": ["apla", "APLA", "", "gogl", 7],
		"alerts": [
			{"ticker": "apla", "side": "above", "price": 120.0, "active": true,
				"createdDay": 2},
			{"ticker": "gogl", "side": "below", "price": -5.0},
			{"ticker": "viso", "side": "below", "price": 50.0, "id": "alert-1",
				"active": false, "triggeredDay": 4, "triggeredPrice": 49.5},
			{"side": "above", "price": 10.0},
			"bad",
		],
		"seq": 2,
	}
	var normalized := SmaAlerts.normalize_state(dirty)
	eq(SmaAlerts.watchlist(normalized).size(), 2, "watchlist deduped and cleaned")
	eq(SmaAlerts.all(normalized).size(), 2, "invalid alerts dropped")
	var first: Dictionary = SmaAlerts.all(normalized)[0]
	eq(String(first.get("ticker", "")), "APLA", "missing ticker handled")
	check(String(first.get("id", "")) != "", "missing id assigned")
	eq(String(first.get("side", "")), "above", "side preserved")
	var second: Dictionary = SmaAlerts.all(normalized)[1]
	eq(String(second.get("id", "")), "alert-1", "saved id preserved")
	check(not bool(second.get("active", true)), "triggered state preserved")
	approx(float(second.get("triggeredPrice", 0.0)), 49.5, 0.001,
		"trigger price preserved")
	var reloaded := SmaAlerts.normalize_state(
		JSON.parse_string(JSON.stringify(normalized)))
	eq(SmaAlerts.all(reloaded).size(), 2, "roundtrip keeps alerts")
	eq(SmaAlerts.watchlist(reloaded).size(), 2, "roundtrip keeps watchlist")
	eq(SmaAlerts.check(reloaded, {"VISO": 49.0}, 5, 10).size(), 0,
		"already-triggered alert stays inactive after roundtrip")
	eq(SmaAlerts.all(SmaAlerts.normalize_state("bad")).size(), 0,
		"non-dict normalize is empty")
	var empty := SmaAlerts.normalize_state({})
	eq(SmaAlerts.watchlist(empty).size(), 0, "old save without watchlist is empty")
	eq(SmaAlerts.all(empty).size(), 0, "old save without alerts is empty")
	eq(int(empty.get("seq", 0)), 1, "old save starts alert ids at one")
