extends "res://tests/test_base.gd"


func run() -> void:
	describe("save-json-roundtrip")
	var exchange := SmaExchange.new("save-seed", 100000.0)
	exchange.submit_order({"ticker": "GOGL", "side": "buy", "type": "market", "qty": 12})
	exchange.advance_seconds(25)
	exchange.set_option_style("american")
	var payload := exchange.to_dict()
	var text := JSON.stringify(payload)
	var parsed: Variant = JSON.parse_string(text)
	check(typeof(parsed) == TYPE_DICTIONARY, "payload survives JSON")
	var restored := SmaExchange.from_dict(parsed)
	check(restored != null, "restored exchange is valid")
	eq(int(restored.state["account"]["positions"]["GOGL"]["qty"]), 12, "position restored from JSON")
	approx(restored.equity(), exchange.equity(), 0.01, "equity restored from JSON")
	eq(int(restored.state["dayIndex"]), int(exchange.state["dayIndex"]), "day restored")
	eq(int(restored.state["second"]), int(exchange.state["second"]), "second restored")
	approx(float(restored.quote("GOGL")["last"]), float(exchange.quote("GOGL")["last"]), 0.0001,
		"quotes derive from restored prices")
	eq(restored.option_style(), "american", "option settlement style restored")

	describe("save-orders")
	var exchange2 := SmaExchange.new("save-orders", 100000.0)
	var last := float(exchange2.quote("VISO")["last"])
	var limit := exchange2.submit_order({
		"ticker": "VISO", "side": "buy", "type": "limit", "qty": 7,
		"limitPrice": last * 0.6,
	})
	check(bool(limit["ok"]), "resting order created")
	var restored2 := SmaExchange.from_dict(JSON.parse_string(JSON.stringify(exchange2.to_dict())))
	eq(restored2.open_order_rows("player").size(), 1, "working order restored")
	var book := restored2.get_book("VISO", 30)
	var has_resting := false
	for bid in book["bids"]:
		if absf(float(bid["price"]) - float(limit["order"]["limitPrice"])) < 0.011:
			has_resting = true
	check(has_resting, "resting order reinserted into the book")

	describe("save-corruption")
	var bad := SmaExchange.from_dict({"version": 99, "companies": {}})
	check(bad == null, "unsupported save version is rejected")
	var bad2 := SmaExchange.from_dict({"version": 1})
	check(bad2 == null, "missing companies are rejected")
	var missing_cost := exchange.to_dict().duplicate(true)
	missing_cost["account"]["positions"]["GOGL"].erase("avgCost")
	check(SmaExchange.from_dict(missing_cost) == null, "missing position cost is rejected")
	var broken_exchange := SmaExchange.from_dict(exchange.to_dict())
	broken_exchange.state["account"]["positions"]["GOGL"].erase("avgCost")
	var balance := float(broken_exchange.state["account"]["cash"])
	var rejected := broken_exchange.submit_order(
		{"ticker": "GOGL", "side": "sell", "type": "market", "qty": 1})
	eq(rejected.get("error"), "order.invalidPosition", "invalid holding rejects an order")
	approx(float(broken_exchange.state["account"]["cash"]), balance, 0.0,
		"rejected sale leaves the balance intact")

	describe("save-file-service")
	var test_path := "user://saves/test-save.json"
	SmaSaveService.clear(test_path)
	var ok := SmaSaveService.write({"version": 1, "hello": "world"}, test_path)
	check(ok, "save service writes a file")
	var loaded := SmaSaveService.read(test_path)
	eq(loaded.get("hello", ""), "world", "save service reads it back")
	check(SmaSaveService.write({"version": 1, "hello": "new"}, test_path), "save can be replaced")
	eq(SmaSaveService.read(test_path + ".bak").get("hello"), "world", "previous save kept")
	check(SmaSaveService.write({"version": 1, "hello": "recovered"}, test_path, true),
		"write after recovery succeeds")
	eq(SmaSaveService.read(test_path + ".bak").get("hello"), "world", "recovery preserves backup")
	SmaSaveService.clear(test_path)
	check(not SmaSaveService.exists(test_path), "save service clears the slot")
	check(not SmaSaveService.exists(test_path + ".bak"), "clearing a slot also clears its backup")

	describe("save-multi-slots")
	eq(SmaSaveService.slot_path(1), SmaSaveService.SAVE_PATH, "slot 1 maps to legacy career.json")
	eq(SmaSaveService.slot_path(4), "user://saves/career_slot_4.json", "slot 4 has dedicated file")
	eq(SmaSaveService.list_slots().size(), SmaSaveService.SLOT_COUNT, "all 4 slots listed")
	var slot4_path := SmaSaveService.slot_path(4)
	SmaSaveService.clear(slot4_path)
	eq(bool(SmaSaveService.slot_summary(4)["exists"]), false, "empty slot 4 reports exists=false")
	check(SmaSaveService.write({
		"version": 1, "savedAt": 12345,
		"settings": {"playerName": "测试学员"},
		"exchange": {"dayIndex": 7, "account": {"cash": 104500.0, "equityHistory": [{"day": 7, "equity": 104500.0}]}},
		"career": {"rank": 3},
		"narrative": {"seen": {"opening": true, "epilogue": true}},
	}, slot4_path), "slot 4 writes cleanly")
	var s4 := SmaSaveService.slot_summary(4)
	eq(bool(s4["exists"]), true, "slot 4 summary detects save")
	eq(String(s4["playerName"]), "测试学员", "slot 4 summary reads player name")
	eq(int(s4["day"]), 7, "slot 4 summary reads day")
	approx(float(s4["equity"]), 104500.0, 0.01, "slot 4 summary reads equity")
	eq(int(s4["rank"]), 3, "slot 4 summary reads career rank")
	eq(bool(s4["graduated"]), true, "slot 4 summary detects graduation")
	SmaSaveService.clear(slot4_path)
