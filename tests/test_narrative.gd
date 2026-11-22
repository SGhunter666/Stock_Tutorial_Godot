extends "res://tests/test_base.gd"


class FakeHost:
	var cash := 100000.0
	var day := 0
	var trades := 0
	var cash_effects: Array = []
	var messages: Array = []
	var story_clients: Array = []

	func get_cash() -> float:
		return cash

	func get_equity() -> float:
		return cash

	func get_position_qty(_ticker: String) -> int:
		return 0

	func get_trade_count() -> int:
		return trades

	func get_day() -> int:
		return day

	var completed_units: Dictionary = {}
	var career_rank: int = 1
	var fund_active: bool = false
	var fund_drawdown: float = 0.0

	func is_unit_complete(unit_id: String) -> bool:
		return bool(completed_units.get(unit_id, false))

	func get_career_rank() -> int:
		return career_rank

	func is_fund_active() -> bool:
		return fund_active

	func get_fund_drawdown() -> float:
		return fund_drawdown

	func story_add_cash(amount: float, memo: String) -> void:
		cash += amount
		cash_effects.append([amount, memo])

	func toast(message: String) -> void:
		messages.append(message)

	func story_add_fund_client(client_name: String, principal: float,
			tag: String = "", risk: String = "medium") -> void:
		story_clients.append([client_name, principal, tag, risk])

	func localize(value: Variant) -> String:
		if typeof(value) == TYPE_DICTIONARY:
			var table: Dictionary = value
			return String(table.get("zh_CN", table.get("en", "")))
		return String(value)


func _make_service(host: FakeHost) -> SmaStoryService:
	var service := SmaStoryService.new()
	service.setup(host)
	check(service.load_content(), "story content loads")
	return service


func _advance_to_choice(service: SmaStoryService) -> Dictionary:
	for i in 12:
		if not service.is_active():
			break
		var view: Dictionary = service.current_view()
		if String(view.get("type", "")) == "choice":
			return view
		service.advance()
	return service.current_view()


func run() -> void:
	describe("story-load")
	var host := FakeHost.new()
	var service := _make_service(host)
	eq(service.stories.size(), 16, "sixteen stories registered")
	eq(service.triggers.size(), 36, "thirty-six trigger definitions registered")
	eq(service.characters.size(), 7, "seven character portraits registered")
	check(service.speaker_lookup.has("Lin Lan"), "english character alias registered")
	check(service.speaker_lookup.has("Mr. Wang"), "client character alias registered")
	for character_id in service.characters:
		check(ResourceLoader.exists(String(service.characters[character_id].get("portrait", ""))),
			"portrait asset exists: " + String(character_id))

	describe("story-opening")
	service.handle_event("game_new")
	check(service.is_active(), "new game starts the opening")
	var view := service.current_view()
	check(String(view.get("text", "")).contains("远望"), "opening text resolves zh_CN")
	eq(String(view.get("speaker", "")).contains("林岚"), true, "speaker resolves")
	eq(String(view.get("character", "")), "lin_lan", "opening resolves Lin Lan")
	eq(String(view.get("portrait", "")), "res://assets/portraits/lin_lan.jpg",
		"opening uses Lin Lan portrait")
	check(String(view.get("portraitColor", "")) != "", "speaker accent color resolves")
	view = _advance_to_choice(service)
	eq(String(view.get("type", "")), "choice", "opening reaches a choice")
	eq(view["choices"].size(), 2, "opening offers two choices")
	check(service.choose(0), "first choice accepted")
	eq(String(service.flags.get("path", "")), "value", "choice sets the path flag")
	for i in 8:
		if not service.is_active():
			break
		service.advance()
	check(not service.is_active(), "opening finishes")

	describe("story-system-speaker")
	var system_host := FakeHost.new()
	var system_service := _make_service(system_host)
	system_service.start_story("black_friday")
	var system_view: Dictionary = system_service.current_view()
	eq(String(system_view.get("portrait", "")), "", "system speaker has no portrait")
	eq(String(system_view.get("character", "")), "", "system speaker has no character")

	describe("story-trigger-once")
	service.handle_event("trade_filled", {"ticker": "APLA"})
	check(service.is_active(), "first fill triggers first_trade")
	eq(service.active_id, "first_trade", "correct story started")
	view = _advance_to_choice(service)
	eq(view["choices"].size(), 2, "value path shows its conditional choice plus the basic one")
	check(service.choose(0), "value choice accepted")
	for i in 8:
		if not service.is_active():
			break
		service.advance()
	service.handle_event("trade_filled", {"ticker": "APLA"})
	check(not service.is_active(), "once trigger does not replay")

	describe("story-conditions")
	var host2 := FakeHost.new()
	var service2 := _make_service(host2)
	service2.flags["path"] = "momentum"
	service2.start_story("first_trade")
	var momentum_view := _advance_to_choice(service2)
	eq(momentum_view["choices"].size(), 2, "momentum path also has two visible choices")
	eq(int(momentum_view["choices"][0]["index"]), 1, "value choice is filtered out")

	describe("story-day-condition")
	var host3 := FakeHost.new()
	var service3 := _make_service(host3)
	service3.handle_event("day_closed", {"day": 0})
	check(not service3.is_active(), "day trigger waits for day 1")
	host3.day = 1
	service3.handle_event("day_closed", {"day": 1})
	check(service3.is_active(), "day trigger fires on day 1")
	eq(service3.active_id, "day_one", "day-one story started")

	describe("story-effects")
	var host4 := FakeHost.new()
	var service4 := _make_service(host4)
	service4.stories["effect_test"] = {
		"id": "effect_test",
		"title": {"zh_CN": "效果测试", "en": "Effect test"},
		"start": "choice",
		"nodes": {
			"choice": {
				"type": "choice",
				"text": {"zh_CN": "接受", "en": "Accept"},
				"choices": [{
					"text": {"zh_CN": "领取补贴", "en": "Take the grant"},
					"next": "end",
					"effects": [
						{"set_flag": "paid", "value": true},
						{"add_cash": 250.0, "memo": "grant"},
						{"toast": {"zh_CN": "补贴到账", "en": "Grant received"}},
					],
				}],
			},
			"end": {"type": "end"},
		},
	}
	service4.start_story("effect_test")
	check(service4.choose(0), "effect choice accepted")
	eq(bool(service4.flags.get("paid", false)), true, "set_flag effect applied")
	approx(host4.cash, 100250.0, 0.001, "add_cash effect applied")
	eq(host4.messages.size(), 1, "toast effect forwarded to host")

	describe("story-persistence")
	var saved := service.to_dict()
	var host5 := FakeHost.new()
	var service5 := _make_service(host5)
	service5.from_dict(saved)
	eq(String(service5.flags.get("path", "")), "value", "flags survive restore")
	check(bool(service5.seen.get("opening", false)), "seen stories survive restore")
	eq(service5.stories.size(), 16, "stories are re-registered on load")

	describe("story-new-conditions")
	var host8 := FakeHost.new()
	var service8 := _make_service(host8)
	host8.completed_units["u5"] = true
	service8.handle_event("unit_completed", {"unit_id": "u5"})
	check(service8.is_active(), "unit_completed triggers dividend story")
	eq(service8.active_id, "dividend", "dividend story started")

	describe("story-unfunded-graduation")
	var host10 := FakeHost.new()
	var service10 := _make_service(host10)
	host10.completed_units["u32"] = true
	host10.fund_active = false
	service10.handle_event("unit_completed", {"unit_id": "u32"})
	check(service10.is_active(), "u32 without a fund triggers graduation")
	eq(service10.active_id, "graduation_unfunded", "unfunded graduation story started")
	var reached_epilogue := false
	for i in 10:
		if not service10.is_active():
			break
		if service10.active_id == "epilogue":
			reached_epilogue = true
			break
		var unfunded_view: Dictionary = service10.current_view()
		if String(unfunded_view.get("type", "")) == "choice":
			service10.choose(0)
		else:
			service10.advance()
	check(reached_epilogue, "unfunded graduation leads into the epilogue")

	var host11 := FakeHost.new()
	var service11 := _make_service(host11)
	host11.completed_units["u32"] = true
	host11.fund_active = true
	service11.handle_event("unit_completed", {"unit_id": "u32"})
	check(not service11.is_active(), "fund-active player does not get the unfunded branch")

	describe("story-graduation-priority")
	var host12 := FakeHost.new()
	var service12 := _make_service(host12)
	host12.completed_units["u32"] = true
	host12.fund_active = false
	service12.seen["black_friday"] = true
	service12.handle_event("unit_completed", {"unit_id": "u32"})
	eq(service12.active_id, "graduation", "fund-line graduation wins after Black Friday")
	check(not service12.queue.has("graduation_unfunded"),
		"unfunded graduation is not queued behind the fund graduation")

	describe("story-epilogue-manager")
	var host13 := FakeHost.new()
	var service13 := _make_service(host13)
	service13.flags["ending_path"] = "manager"
	service13.start_story("epilogue")
	var manager_view: Dictionary = _advance_to_choice(service13)
	var manager_visible := false
	for choice in manager_view["choices"]:
		if String(choice["text"]).contains("稳健掌舵人"):
			manager_visible = true
	check(manager_visible, "manager choice follows the graduation decision")

	describe("story-independent-ending")
	var host14 := FakeHost.new()
	var service14 := _make_service(host14)
	service14.flags["ending_path"] = "independent"
	service14.start_story("epilogue")
	var independent_view: Dictionary = _advance_to_choice(service14)
	var independent_visible := false
	var star_visible := false
	for choice in independent_view["choices"]:
		if String(choice["text"]).contains("独立交易员"):
			independent_visible = true
		if String(choice["text"]).contains("明星交易员"):
			star_visible = true
	check(independent_visible, "independent trader gets its own epilogue branch")
	check(not star_visible, "independent trader does not get the hedge-fund ending")

	describe("story-unfunded-choice")
	var host15 := FakeHost.new()
	var service15 := _make_service(host15)
	host15.completed_units["u32"] = true
	service15.handle_event("unit_completed", {"unit_id": "u32"})
	for i in 8:
		if not service15.is_active():
			break
		var unfunded_choice_view: Dictionary = service15.current_view()
		if String(unfunded_choice_view.get("type", "")) == "choice":
			service15.choose(1)
			break
		service15.advance()
	eq(String(service15.flags.get("ending_path", "")), "independent",
		"independent choice sets its own ending flag")

	describe("story-gate-ending")
	var host16 := FakeHost.new()
	var service16 := _make_service(host16)
	service16.flags["crisis_choice"] = "gate"
	service16.start_story("epilogue")
	var gate_view: Dictionary = _advance_to_choice(service16)
	var gate_visible := false
	for choice in gate_view["choices"]:
		if String(choice["text"]).contains("暂停赎回"):
			gate_visible = true
	check(gate_visible, "gate decision gets its own epilogue branch")

	describe("story-flag-text")
	var host17 := FakeHost.new()
	var service17 := _make_service(host17)
	service17.flags["option_style"] = "covered"
	service17.start_story("epilogue")
	service17.advance()
	var style_view: Dictionary = service17.current_view()
	check(String(style_view.get("text", "")).contains("收租"),
		"flag-specific epilogue text resolves")

	var host18 := FakeHost.new()
	var service18 := _make_service(host18)
	service18.start_story("epilogue")
	service18.advance()
	var default_view: Dictionary = service18.current_view()
	check(String(default_view.get("text", "")).contains("档案只记录"),
		"default epilogue text used when no flag matches")

	describe("story-client-subscription")
	var host19 := FakeHost.new()
	var service19 := _make_service(host19)
	service19.start_story("client_trust")
	var client_choice: Dictionary = _advance_to_choice(service19)
	eq(client_choice["choices"].size(), 2, "client trust offers two choices")
	service19.choose(0)
	eq(host19.story_clients.size(), 1, "high-trust choice subscribes the client")
	eq(String(host19.story_clients[0][0]), "王先生", "client name forwarded")
	approx(float(host19.story_clients[0][1]), 50000.0, 0.001, "principal forwarded")
	eq(String(host19.story_clients[0][2]), "client_trust", "client story tag forwarded")
	eq(String(host19.story_clients[0][3]), "low", "client risk profile forwarded")

	describe("story-epilogue-branching")
	var host9 := FakeHost.new()
	var service9 := _make_service(host9)
	service9.flags["ending_path"] = "manager"
	service9.flags["client_trust"] = "high"
	service9.flags["crisis_choice"] = "protect"
	service9.start_story("epilogue")
	check(service9.is_active(), "epilogue story starts")
	var epilogue_view := _advance_to_choice(service9)
	eq(String(epilogue_view.get("type", "")), "choice", "epilogue presents branch choice")
	check(epilogue_view["choices"].size() >= 2, "manager choice is available")

	describe("story-post-epilogue-guard")
	var host20 := FakeHost.new()
	host20.completed_units["u29"] = true
	host20.fund_active = true
	var service20 := _make_service(host20)
	service20.seen["client_trust"] = true
	service20.seen["epilogue"] = true
	service20.handle_event("unit_completed", {"unit_id": "u29"})
	check(not service20.is_active(), "crisis eve is blocked after the epilogue")

	var host21 := FakeHost.new()
	host21.completed_units["u31"] = true
	host21.fund_active = true
	var service21 := _make_service(host21)
	service21.seen["client_trust"] = true
	service21.seen["crisis_eve"] = true
	service21.seen["epilogue"] = true
	service21.handle_event("unit_completed", {"unit_id": "u31"})
	check(not service21.is_active(), "black friday is blocked after the epilogue")

	describe("story-low-trust-call")
	var host22 := FakeHost.new()
	var service22 := _make_service(host22)
	service22.flags["client_trust"] = "low"
	service22.start_story("black_friday")
	for i in 8:
		if String(service22.current_view().get("node_id", "")) == "mr_wang_call":
			break
		service22.advance()
	var low_view: Dictionary = service22.current_view()
	check(String(low_view.get("text", "")).contains("不会亏"),
		"low-trust client recalls the overpromise")

	var host23 := FakeHost.new()
	var service23 := _make_service(host23)
	service23.flags["client_trust"] = "high"
	service23.start_story("black_friday")
	for i in 8:
		if String(service23.current_view().get("node_id", "")) == "mr_wang_call":
			break
		service23.advance()
	var high_view: Dictionary = service23.current_view()
	check(String(high_view.get("text", "")).contains("两成"),
		"high-trust client recalls the honest disclosure")

	describe("story-career-ending-separation")
	var host24 := FakeHost.new()
	var service24 := _make_service(host24)
	service24.flags["ending_path"] = "mentor"
	service24.flags["crisis_choice"] = "attack"
	service24.start_story("epilogue")
	var career_view: Dictionary = _advance_to_choice(service24)
	var has_manager := false
	var has_star := false
	for choice in career_view["choices"]:
		var label := String(choice["text"])
		if label.contains("稳健掌舵人"):
			has_manager = true
		if label.contains("明星交易员"):
			has_star = true
	check(not has_manager, "manager file follows the manager ending path")
	check(not has_star, "star file follows the star ending path")

	describe("story-low-trust-manager-ending")
	var host25 := FakeHost.new()
	var service25 := _make_service(host25)
	service25.flags["ending_path"] = "manager"
	service25.flags["client_trust"] = "low"
	service25.start_story("epilogue")
	var manager_choice: Dictionary = _advance_to_choice(service25)
	var manager_index := -1
	for choice in manager_choice["choices"]:
		if String(choice["text"]).contains("稳健掌舵人"):
			manager_index = int(choice["index"])
	if manager_index >= 0:
		service25.choose(manager_index)
		var manager_low_view: Dictionary = service25.current_view()
		check(String(manager_low_view.get("text", "")).contains("没有寄过桂花茶"),
			"low-trust manager ending reflects the lost trust")
	else:
		check(false, "manager ending available for the manager path")
