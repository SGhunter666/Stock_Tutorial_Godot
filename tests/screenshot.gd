extends Node

## Renders each screen to PNG for visual review. Run with a real renderer:
##   godot --path godot res://tests/screenshot.tscn

const DEFAULT_OUT_DIR := "/tmp/sma_shots"

var out_dir := DEFAULT_OUT_DIR
var main: Node


func _ready() -> void:
	var override := OS.get_environment("SMA_SHOT_DIR")
	if override != "":
		out_dir = override
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.save_path = "user://saves/screenshot.json"
	SmaSaveService.clear(Game.save_path)
	var scene: PackedScene = load("res://ui/main.tscn")
	main = scene.instantiate()
	add_child(main)
	await _settle(8)
	if OS.get_environment("SMA_BETA20_ONLY") == "1":
		Game.new_game("beta20-smooth")
		await _settle(4)
		_dismiss_story()
		Game.submit_order({"ticker": "NVDO", "side": "buy", "type": "market", "qty": 80})
		_dismiss_story()
		Game.submit_order({"ticker": "MSFY", "side": "buy", "type": "market", "qty": 30})
		Game.submit_order({"ticker": "APLA", "side": "buy", "type": "market", "qty": 20})
		for d in 4:
			Game._advance_steps(SmaExchange.SESSION_SECONDS, false)
			_dismiss_story()
		Game.exchange.state["account"]["cash"] = float(Game.exchange.state["account"]["cash"]) + 2500.0
		Game.intro["complete"] = true
		if main._pixel_fx != null:
			main._pixel_fx._popups.clear()
			main._pixel_fx._sparks.clear()
			main._pixel_fx.queue_redraw()
		main._refresh_nav()
		main.navigate("dashboard")
		main._screens["dashboard"].refresh()
		await _settle(5)
		await _shot("beta20_dashboard_recap")
		main.navigate("career")
		main._screens["career"].refresh()
		await _settle(5)
		await _shot("beta20_career_live_track")
		var soon_tk := "NVDO"
		for tk in SmaCompanyCatalog.load_companies().keys():
			var ner := SmaEarnings.next_for_ticker(String(tk), Game.get_day())
			if not ner.is_empty() and int(ner.get("daysUntil", 99)) <= 12:
				soon_tk = String(tk)
				break
		Game.select_ticker(soon_tk)
		main.navigate("trade")
		var ts20: SmaTradeScreen = main._screens["trade"]
		ts20._on_timeframe("1D")
		ts20.refresh()
		await _settle(5)
		await _shot("beta20_trade_earnings_feed")
		SmaSaveService.clear(Game.save_path)
		Game.save_path = SmaSaveService.SAVE_PATH
		get_tree().quit(0)
		return
	if OS.get_environment("SMA_BETA19_ONLY") == "1":
		Game.new_game("beta19-rivals")
		await _settle(4)
		_dismiss_story()
		Game.submit_order({"ticker": "NVDO", "side": "buy", "type": "market", "qty": 60})
		_dismiss_story()
		Game.submit_order({"ticker": "MSFY", "side": "buy", "type": "market", "qty": 30})
		for d in 5:
			Game._advance_steps(SmaExchange.SESSION_SECONDS, false)
			_dismiss_story()
		Game._advance_steps(900, true)
		Game.intro["complete"] = true
		if main._pixel_fx != null:
			main._pixel_fx._popups.clear()
			main._pixel_fx._sparks.clear()
			main._pixel_fx.queue_redraw()
		main.navigate("dashboard")
		main._screens["dashboard"].refresh()
		await _settle(5)
		await _shot("beta19_rivals_dashboard")
		Game.narrative.start_story("earnings_paradox")
		Game.narrative.advance()
		await _settle(5)
		await _shot("beta19_earnings_story")
		SmaSaveService.clear(Game.save_path)
		Game.save_path = SmaSaveService.SAVE_PATH
		get_tree().quit(0)
		return
	if OS.get_environment("SMA_BETA18_ONLY") == "1":
		Game.new_game("beta18-attribution")
		await _settle(4)
		_dismiss_story()
		for uid in Game.academy["units"].keys():
			Game.academy["units"][uid]["completed"] = true
			Game.academy_mark_section_read(String(uid), "s1")
		var day_now: int = Game.get_day()
		Game.exchange.state["companies"]["BOEN"]["last"] = float(Game.exchange.state["companies"]["BOEN"]["prevClose"]) * 0.935
		Game.exchange.state["companies"]["BOEN"]["fairValue"] = Game.exchange.state["companies"]["BOEN"]["last"]
		Game.exchange.state["corporateActions"].push_front({
			"type": "offering", "ticker": "BOEN", "day": day_now, "ratio": 0.09, "impact": -0.065,
		})
		Game.exchange.refresh_liquidity("BOEN")
		Game.exchange.state["quotes"].erase("BOEN")
		Game.select_ticker("BOEN")
		main.navigate("trade")
		var ts18: SmaTradeScreen = main._screens["trade"]
		ts18._on_timeframe("1D")
		ts18.refresh()
		await _settle(4)
		var chart18: SmaCandleChart = ts18._chart
		if chart18._visible.size() > 15:
			var target_idx := chart18._visible.size() - 12
			for idx in range(chart18._visible.size() - 1, 5, -1):
				var d_key := String(chart18._visible[idx].get("d", ""))
				if chart18.candle_notes.has(d_key):
					target_idx = idx
					break
			chart18._hover_index = target_idx
			chart18._hover_pos = Vector2(
				chart18._left + chart18._slot * (float(target_idx) + 0.5),
				(chart18._top + chart18._price_bottom) * 0.45)
			chart18.queue_redraw()
		await _settle(4)
		await _shot("beta18_attribution_trade")
		SmaSaveService.clear(Game.save_path)
		Game.save_path = SmaSaveService.SAVE_PATH
		get_tree().quit(0)
		return
	if OS.get_environment("SMA_BETA17_ONLY") == "1":
		Game.new_game("beta17-realism")
		await _settle(4)
		_dismiss_story()
		for uid in Game.academy["units"].keys():
			Game.academy["units"][uid]["completed"] = true
			Game.academy_mark_section_read(String(uid), "s1")
		Game.exchange.state["dayIndex"] = 12
		var pre_ticker := "NVDO"
		var cur_day: int = Game.get_day()
		for tk in SmaCompanyCatalog.load_companies().keys():
			var ivs := SmaOptions.earnings_iv_state(String(tk), cur_day)
			if String(ivs.get("status", "")) == "preEarnings":
				pre_ticker = String(tk)
				break
		Game.select_ticker(pre_ticker)
		main.navigate("options")
		var os17: SmaOptionsScreen = main._screens["options"]
		os17._ticker = pre_ticker
		os17.refresh()
		await _settle(5)
		await _shot("beta17_options_iv")
		main.navigate("etf")
		var etfs17: SmaEtfScreen = main._screens["etf"]
		etfs17._selected = "SEMI"
		etfs17.refresh()
		await _settle(5)
		await _shot("beta17_etf_8funds")
		var conb_cs: Dictionary = Game.exchange.state["companies"]["CONB"]
		conb_cs["last"] = float(conb_cs["prevClose"]) * 0.91
		conb_cs["fairValue"] = conb_cs["last"]
		Game.exchange.refresh_liquidity("CONB")
		Game.exchange.state["quotes"].erase("CONB")
		Game.select_ticker("CONB")
		main.navigate("trade")
		var ts17: SmaTradeScreen = main._screens["trade"]
		ts17._on_timeframe("1D")
		ts17._on_side("short")
		ts17.refresh()
		await _settle(5)
		await _shot("beta17_trade_htb_stress")
		SmaSaveService.clear(Game.save_path)
		Game.save_path = SmaSaveService.SAVE_PATH
		get_tree().quit(0)
		return
	if OS.get_environment("SMA_BETA16_ONLY") == "1":
		Game.new_game("beta16-earnings")
		await _settle(4)
		_dismiss_story()
		for uid in ["u1", "u2", "u3", "u4", "u5", "u6", "u7", "u8", "u9", "u10", "u11", "u12"]:
			if Game.academy["units"].has(uid):
				Game.academy["units"][uid]["completed"] = true
		Game.set_chart_timeframe("1D")
		var pick_ticker := "NVDO"
		var recent_hist := SmaEarnings.recent_historical(Game.get_day(),
			String(Game.exchange.state.get("seed", "beta16-earnings")), 40)
		for ev in recent_hist:
			if String(ev.get("template", "")) == "earningsBeat" and float(ev.get("pct", 0.0)) < 0.0:
				pick_ticker = String(ev["ticker"])
				break
		Game.select_ticker(pick_ticker)
		main.navigate("earnings")
		await _settle(5)
		await _shot("beta16_earnings_center")
		main.navigate("statements")
		await _settle(5)
		await _shot("beta16_statements_400")
		SmaSaveService.clear(Game.save_path)
		Game.save_path = SmaSaveService.SAVE_PATH
		get_tree().quit(0)
		return
	if OS.get_environment("SMA_BETA15_ONLY") == "1":
		Game.new_game("beta15-stocks")
		await _settle(4)
		_dismiss_story()
		for uid in ["u1", "u2", "u3", "u4", "u5", "u6", "u7", "u8"]:
			if Game.academy["units"].has(uid):
				Game.academy["units"][uid]["completed"] = true
		main.navigate("market")
		await _settle(5)
		await _shot("beta15_market_100")
		Game.select_ticker("TSMX")
		main.navigate("trade")
		var ts15: SmaTradeScreen = main._screens["trade"]
		ts15._on_timeframe("1D")
		ts15._boll_toggle.button_pressed = true
		ts15._sync_chart_overlays()
		ts15.refresh()
		await _settle(5)
		await _shot("beta15_tsmx_kline")
		ts15._open_financials()
		await _settle(5)
		await _shot("beta15_tsmx_financials")
		SmaSaveService.clear(Game.save_path)
		Game.save_path = SmaSaveService.SAVE_PATH
		get_tree().quit(0)
		return
	if OS.get_environment("SMA_FONT_CHECK") == "1":
		Game.new_game("font-check")
		await _settle(4)
		_dismiss_story()
		Game.submit_order({"ticker": "APLA", "side": "buy", "type": "market", "qty": 30})
		_dismiss_story()
		for i in 6:
			Game.step_minute()
		main.navigate("settings")
		await _settle(5)
		await _shot("beta14_settings_comfortable")
		Game.set_font_scale("large")
		main.navigate("trade")
		await _settle(5)
		await _shot("beta14_trade_large")
		Game.set_font_scale("xlarge")
		main.navigate("settings")
		await _settle(5)
		await _shot("beta14_settings_xlarge")
		Game.set_font_scale("comfortable")
		SmaSaveService.clear(Game.save_path)
		Game.save_path = SmaSaveService.SAVE_PATH
		get_tree().quit(0)
		return
	if OS.get_environment("SMA_BETA12_ONLY") == "1":
		await _capture_beta12_showcase()
		SmaSaveService.clear(Game.save_path)
		Game.save_path = SmaSaveService.SAVE_PATH
		get_tree().quit(0)
		return
	if OS.get_environment("SMA_BETA10_ONLY") == "1":
		Game.new_game("screenshot-seed")
		await _settle(4)
		_dismiss_story()
		Game.academy_mark_section_read("u4", "s1")
		Game.academy_mark_section_read("u4", "s3")
		Game.academy_mark_section_read("u19", "s1")
		Game.academy_mark_section_read("u20", "s1")
		Game.submit_order({"ticker": "APLA", "side": "buy", "type": "market", "qty": 60})
		_dismiss_story()
		for i in 12:
			Game.step_minute()
		Game.submit_order({"ticker": "APLA", "side": "sell", "type": "market", "qty": 20})
		_dismiss_story()
		Game.career["rank"] = 3
		Game.career["certificates"] = [
			{"id": "core_foundations", "day": 0},
			{"id": "risk_execution", "day": 0},
		]
		if not Game.academy["achievements"].has("first_trade"):
			Game.academy["achievements"].append("first_trade")
		Game.academy["xp"] = 260
		await _capture_beta10_showcase()
		SmaSaveService.clear(Game.save_path)
		Game.save_path = SmaSaveService.SAVE_PATH
		get_tree().quit(0)
		return
	await _shot("start")

	Game.new_game("screenshot-seed")
	await _settle(8)
	await _shot("dialogue")

	for i in 20:
		if not Game.narrative.is_active():
			break
		var view: Dictionary = Game.narrative.current_view()
		if String(view.get("type", "")) == "choice":
			Game.narrative.choose(0)
		else:
			Game.narrative.advance()
	await _settle(4)

	main.navigate("market")
	await _settle(6)
	await _shot("market")

	Game.toggle_watch("APLA")
	var alert_last := float(Game.exchange.quote("APLA").get("last", 0.0))
	Game.add_price_alert("APLA", "above", alert_last * 1.05)
	main.navigate("watchlist")
	await _settle(6)
	await _shot("watchlist")
	main.navigate("screener")
	await _settle(6)
	await _shot("screener")
	main.navigate("earnings")
	await _settle(6)
	await _shot("earnings")
	main.navigate("market")
	await _settle(2)

	main.navigate("trade")
	await _settle(6)
	await _shot("trade")
	Game.academy_mark_section_read("u19", "s1")
	main._screens["trade"].refresh()
	main._screens["trade"]._on_type("stop")
	await _settle(4)
	await _shot("trade_stop")
	main._screens["trade"]._on_type("trailing")
	await _settle(4)
	await _shot("trade_trailing")
	main._screens["trade"]._on_type("market")
	await _settle(2)

	Game.submit_order({"ticker": "APLA", "side": "buy", "type": "market", "qty": 40})
	for i in 10:
		if not Game.narrative.is_active():
			break
		var story_view: Dictionary = Game.narrative.current_view()
		if String(story_view.get("type", "")) == "choice":
			Game.narrative.choose(0)
		else:
			Game.narrative.advance()
	for i in 8:
		Game.step_minute()
	await _settle(6)
	var trade_screen = main._screens["trade"]
	trade_screen._right_scroll.scroll_vertical = 100000
	await _settle(4)
	await _shot("trade_filled")
	Game.academy_mark_section_read("u4", "s3")
	trade_screen.refresh()
	trade_screen._right_scroll.scroll_vertical = 0
	await _settle(4)
	if trade_screen._oco_card.visible:
		var oco_last := float(Game.exchange.quote(Game.selected_ticker).get("last", 0.0))
		trade_screen._oco_tp.value = SmaFormat.round_to(oco_last * 1.1, 2)
		trade_screen._oco_stop.value = SmaFormat.round_to(oco_last * 0.9, 2)
		await _settle(4)
		await _shot("trade_oco")
	Game.set_layout("advanced")
	await _settle(6)
	main.navigate("trade")
	await _settle(6)
	await _shot("trade_advanced")
	Game.set_layout("beginner")
	await _settle(6)
	main.navigate("trade")
	await _settle(4)

	main.navigate("portfolio")
	await _settle(6)
	await _shot("portfolio")

	main.navigate("dashboard")
	await _settle(6)
	await _shot("dashboard")

	main.navigate("academy")
	await _settle(8)
	await _shot("academy")
	var academy_screen = main._screens["academy"]
	academy_screen._open_glossary("stock")
	await _settle(6)
	await _shot("glossary")
	for child in main.get_children():
		if child is SmaGlossaryDialog:
			child._close()
	await _settle(3)
	academy_screen._open_quiz("u1")
	await _settle(6)
	await _shot("quiz")
	for child in main.get_children():
		if child is SmaQuizDialog:
			child._close()
	await _settle(3)
	for unit_id in ["u1", "u2", "u3", "u4"]:
		Game.academy["units"][unit_id]["completed"] = true
	academy_screen._select_unit("u5")
	await _settle(6)
	await _shot("academy_stage2")
	for unit_id in ["u5", "u6", "u7", "u8"]:
		Game.academy["units"][unit_id]["completed"] = true
	academy_screen._select_unit("u9")
	await _settle(6)
	await _shot("academy_stage3")
	academy_screen._open_demo("candle")
	await _settle(6)
	await _shot("demo_candle")
	for child in main.get_children():
		if child is SmaDemoDialog:
			child._close()
	await _settle(3)
	academy_screen._open_demo("indicators")
	await _settle(6)
	for child in main.get_children():
		if child is SmaDemoDialog:
			child._view_period(5)
			child._view_period(10)
			child._answer_indicator(10)
	await _settle(4)
	await _shot("demo_indicators")
	for child in main.get_children():
		if child is SmaDemoDialog:
			child._close()
	await _settle(3)
	academy_screen._open_demo("dcf")
	await _settle(6)
	for child in main.get_children():
		if child is SmaDemoDialog:
			child._calculate_dcf()
	await _settle(4)
	await _shot("demo_dcf")
	for child in main.get_children():
		if child is SmaDemoDialog:
			child._close()
	await _settle(3)
	main.navigate("trade")
	await _settle(6)
	main._screens["trade"]._open_financials()
	await _settle(6)
	await _shot("financials")
	for child in main.get_children():
		if child is SmaFinancialsDialog:
			child._close()
	await _settle(3)
	main.navigate("academy")
	await _settle(4)
	for unit_id in ["u9", "u10", "u11"]:
		Game.academy["units"][unit_id]["completed"] = true
	for unit_id in ["u10", "u11", "u12"]:
		academy_screen._select_unit(unit_id)
		await _settle(4)
		await _shot("academy_%s" % unit_id)
	for unit_id in ["u12", "u13", "u14", "u15"]:
		Game.academy["units"][unit_id]["completed"] = true
	for unit_id in ["u13", "u14", "u15", "u16"]:
		academy_screen._select_unit(unit_id)
		await _settle(4)
		await _shot("academy_%s" % unit_id)
	for demo_id in ["macro", "allocation", "risk", "strategies"]:
		academy_screen._open_demo(demo_id)
		await _settle(6)
		await _shot("demo_%s" % demo_id)
		for child in main.get_children():
			if child is SmaDemoDialog:
				child._close()
		await _settle(3)
	for unit_id in ["u16", "u17", "u18", "u19"]:
		Game.academy["units"][unit_id]["completed"] = true
	for unit_id in ["u17", "u18", "u19", "u20"]:
		academy_screen._select_unit(unit_id)
		await _settle(4)
		await _shot("academy_%s" % unit_id)
	for demo_id in ["shortPnl", "margin", "stopOrder", "orderBook"]:
		academy_screen._open_demo(demo_id)
		await _settle(6)
		await _shot("demo_%s" % demo_id)
		for child in main.get_children():
			if child is SmaDemoDialog:
				child._close()
		await _settle(3)
	for unit_id in ["u20", "u21", "u22", "u23"]:
		Game.academy["units"][unit_id]["completed"] = true
	for unit_id in ["u21", "u22", "u23", "u24"]:
		academy_screen._select_unit(unit_id)
		await _settle(4)
		await _shot("academy_%s" % unit_id)
	for unit_id in ["u24", "u25", "u26", "u27"]:
		Game.academy["units"][unit_id]["completed"] = true
	for unit_id in ["u25", "u26", "u27", "u28"]:
		academy_screen._select_unit(unit_id)
		await _settle(4)
		await _shot("academy_%s" % unit_id)
	for unit_id in ["u28", "u29", "u30", "u31"]:
		Game.academy["units"][unit_id]["completed"] = true
	for unit_id in ["u29", "u30", "u31", "u32"]:
		academy_screen._select_unit(unit_id)
		await _settle(4)
		await _shot("academy_%s" % unit_id)
	for demo_id in ["optionPayoff", "greeks", "strategyPayoff",
			"futuresPnl", "hedge", "stressTest"]:
		academy_screen._open_demo(demo_id)
		await _settle(6)
		await _shot("demo_%s" % demo_id)
		for child in main.get_children():
			if child is SmaDemoDialog:
				child._close()
		await _settle(3)

	Game.academy["units"]["u32"]["completed"] = true
	for unit_id in ["b1", "b2", "b3", "b4", "b5", "b6"]:
		academy_screen._select_unit(unit_id)
		await _settle(4)
		await _shot("academy_%s" % unit_id)
	var academy_left_scroll: ScrollContainer = academy_screen.get_child(0) \
		.get_child(1).get_child(0).get_child(0)
	academy_left_scroll.scroll_vertical = 100000
	await _settle(4)
	await _shot("academy_branches")
	academy_left_scroll.scroll_vertical = 0

	main.navigate("macro")
	await _settle(6)
	await _shot("macro")

	Game.academy_mark_section_read("u21", "s1")
	main.navigate("options")
	await _settle(6)
	await _shot("options")
	Game.set_option_style("american")
	main.navigate("options")
	await _settle(6)
	await _shot("options_american")
	Game.set_option_style("european")
	main.navigate("options")
	await _settle(4)
	var chain := Game.option_chain("APLA")
	if not chain.is_empty():
		var contract := SmaOptions.find_contract(chain, "call", float(chain["strikes"][3]),
			int(chain["expiries"][0]["expiryDay"]))
		Game.buy_option("APLA", "call", float(contract["strike"]),
			int(contract["expiryDay"]), 1)
		_dismiss_story()
		main._screens["options"].refresh()
		await _settle(4)
		await _shot("options_position")

	Game.academy_mark_section_read("u25", "s1")
	main.navigate("options")
	await _settle(6)
	var options_screen = main._screens["options"]
	if not options_screen._chain.is_empty():
		options_screen._select_contract("put",
			float(options_screen._chain["strikes"][1]))
		options_screen._set_mode("sell")
		await _settle(4)
		await _shot("options_sell")
		options_screen._submit()
		await _settle(4)
		await _shot("options_short")
		var strategy_result: Dictionary = Game.open_option_strategy(
			"bullCallSpread", "APLA", 30, 1)
		if bool(strategy_result.get("ok", false)):
			main._screens["options"].refresh()
			await _settle(4)
			await _shot("options_strategy")
		var options_scroll: ScrollContainer = options_screen.get_child(0).get_child(0)
		options_scroll.scroll_vertical = 100000
		await _settle(6)
		await _shot("options_positions")
		options_scroll.scroll_vertical = 0

	Game.academy_mark_section_read("u29", "s1")
	main.navigate("futures")
	await _settle(6)
	await _shot("futures")
	var futures_screen = main._screens["futures"]
	if not futures_screen._chain.is_empty():
		futures_screen._submit()
		await _settle(4)
		futures_screen._set_side("short")
		await _settle(4)
		futures_screen._submit()
		await _settle(4)
		await _shot("futures_positions")

	main.navigate("multiasset")
	await _settle(6)
	await _shot("multiasset")
	Game.buy_bond("gov2", 2)
	Game.buy_fx("EURUSD", 1000)
	Game.buy_commodity("gold", 2)
	Game.buy_crypto("BTC", 0.01)
	main._screens["multiasset"].refresh()
	await _settle(4)
	await _shot("multiasset_positions")
	main._screens["multiasset"]._active_tab = "crypto"
	main._screens["multiasset"].refresh("tab")
	await _settle(4)
	await _shot("multiasset_bottom")
	main._screens["multiasset"]._active_tab = "bonds"
	main._screens["multiasset"].refresh("tab")

	main.navigate("history")
	await _settle(6)
	await _shot("history_scenarios")
	var history_screen = main._screens["history"]
	await history_screen._start_scenario("2008-crisis")
	await _settle(8)
	await _shot("history_lab")
	history_screen._advance_day()
	await _settle(6)
	await _shot("history_lab_day")

	main.navigate("story")
	await _settle(6)
	await _shot("story")

	Game.narrative.start_story("opening")
	await _settle(6)
	await _shot("dialogue_replay")
	for i in 12:
		if not Game.narrative.is_active():
			break
		var replay_view: Dictionary = Game.narrative.current_view()
		if String(replay_view.get("type", "")) == "choice":
			Game.narrative.choose(0)
		else:
			Game.narrative.advance()
	await _settle(3)

	Game.step_day()
	await _settle(3)
	await _shot("fast_forward")
	for i in 1200:
		if not Game.is_fast_forwarding():
			break
		await get_tree().process_frame
	for i in 12:
		if not Game.narrative.is_active():
			break
		var view: Dictionary = Game.narrative.current_view()
		if String(view.get("type", "")) == "choice":
			Game.narrative.choose(0)
		else:
			Game.narrative.advance()
	main.navigate("market")
	await _settle(6)
	await _shot("market_day1")

	main.navigate("replay")
	await _settle(8)
	await _shot("replay")
	main._screens["replay"]._previous()
	await _settle(6)
	await _shot("replay_scrub")

	main.navigate("news")
	await _settle(6)
	await _shot("news")

	main.navigate("etf")
	await _settle(6)
	await _shot("etf")
	Game.academy["units"]["u7"]["completed"] = true
	Game.submit_order({"ticker": "MKT", "side": "buy", "type": "market", "qty": 10})
	main._screens["etf"].refresh()
	await _settle(4)
	await _shot("etf_position")

	main.navigate("challenges")
	await _settle(6)
	await _shot("challenges")
	Game.start_challenge("firstProfit")
	main._screens["challenges"].refresh()
	await _settle(4)
	await _shot("challenges_active")
	Game.abandon_challenge()

	Game.career["rank"] = 5
	main.navigate("career")
	await _settle(6)
	await _shot("career")
	main._screens["career"]._active_tab = "certs"
	main._screens["career"].refresh("tab")
	await _settle(4)
	await _shot("career_ladder")
	main._screens["career"]._active_tab = "promotion"
	main._screens["career"].refresh("tab")

	Game.create_fund({
		"name": I18n.t("fund.defaultName"), "strategy": "longOnly", "riskProfile": "balanced",
		"initialAum": 1000000.0, "managementRate": 0.02, "performanceRate": 0.2,
		"benchmarkId": "index", "hurdleRate": 0.0, "leverageEnabled": false,
		"taxProfileId": "none",
	})
	_dismiss_story()
	Game.fund_buy("APLA", 200)
	Game.fund_buy("MSFY", 150)
	main.navigate("fund")
	await _settle(8)
	await _shot("fund")
	main._screens["fund"]._active_tab = "risk"
	main._screens["fund"].refresh("tab")
	await _settle(4)
	await _shot("fund_bottom")
	main._screens["fund"]._active_tab = "quant"
	Game.fund_generate_plan()
	main._screens["fund"].refresh("tab")
	await _settle(6)
	await _shot("fund_plan")
	main._screens["fund"]._run_optimizer()
	await _settle(8)
	var fund_scroll: ScrollContainer = main._screens["fund"]._scroll
	var fund_body: Control = main._screens["fund"]._body
	if fund_body.get_child_count() > 0:
		fund_scroll.ensure_control_visible(fund_body.get_child(fund_body.get_child_count() - 1))
	await _settle(6)
	await _shot("fund_optimizer")
	fund_scroll.scroll_vertical = 0
	main._screens["fund"]._active_tab = "overview"
	main._screens["fund"].refresh("tab")

	main.navigate("quant")
	await _settle(10)
	await _shot("quant")
	var quant_scroll: ScrollContainer = main._screens["quant"].get_child(0).get_child(0)
	quant_scroll.scroll_vertical = 600
	await _settle(4)
	await _shot("quant_results")
	quant_scroll.scroll_vertical = 0
	main.navigate("tax")
	await _settle(6)
	await _shot("tax")
	var tax_scroll: ScrollContainer = main._screens["tax"].get_child(0).get_child(0)
	tax_scroll.scroll_vertical = 100000
	await _settle(4)
	await _shot("tax_bottom")
	tax_scroll.scroll_vertical = 0
	main.navigate("statements")
	await _settle(6)
	await _shot("statements")
	main.navigate("glossary")
	await _settle(6)
	await _shot("glossary_page")
	main.navigate("sandbox")
	await _settle(6)
	await _shot("sandbox")
	main.navigate("roadmap")
	await _settle(6)
	await _shot("roadmap")
	main.navigate("boundaries")
	await _settle(6)
	await _shot("boundaries")
	main.navigate("settings")
	await _settle(6)
	await _shot("settings")
	var settings_scroll: ScrollContainer = main._screens["settings"].get_child(0).get_child(0)
	settings_scroll.scroll_vertical = 100000
	await _settle(4)
	await _shot("settings_bottom")

	Game.set_layout("advanced")
	await _settle(6)
	main.navigate("dashboard")
	await _settle(6)
	await _shot("dashboard_advanced")
	Game.set_layout("beginner")
	await _settle(4)

	Game.set_theme("light")
	await _settle(8)
	main.navigate("dashboard")
	await _settle(8)
	await _shot("dashboard_light")
	main.navigate("market")
	await _settle(6)
	await _shot("market_light")
	main.navigate("replay")
	await _settle(8)
	await _shot("replay_light")
	main.navigate("settings")
	await _settle(6)
	await _shot("settings_light")
	main.navigate("trade")
	await _settle(8)
	main._screens["trade"]._on_timeframe("1D")
	await _settle(6)
	await _shot("trade_light")
	main.navigate("quant")
	await _settle(8)
	await _shot("quant_light")
	main.navigate("fund")
	await _settle(8)
	await _shot("fund_light")
	main.navigate("academy")
	await _settle(8)
	main._screens["academy"]._open_demo("optionPayoff")
	await _settle(8)
	await _shot("demo_optionPayoff_light")
	for child in main.get_children():
		if child is SmaDemoDialog:
			child._close()
	await _settle(4)

	Game.set_theme("pixel")
	await _settle(6)

	I18n.set_locale("en")
	Game.settings["locale"] = "en"
	await _settle(10)
	main.navigate("dashboard")
	await _settle(8)
	await _shot("dashboard_en")
	main.navigate("market")
	await _settle(6)
	await _shot("market_en")
	main.navigate("trade")
	await _settle(8)
	main._screens["trade"]._on_timeframe("1D")
	await _settle(6)
	await _shot("trade_en")
	main.navigate("replay")
	await _settle(8)
	await _shot("replay_en")
	main.navigate("fund")
	main._screens["fund"]._active_tab = "quant"
	main._screens["fund"].refresh("tab")
	await _settle(8)
	main._screens["fund"]._run_optimizer()
	await _settle(8)
	var fund_scroll_en: ScrollContainer = main._screens["fund"]._scroll
	var fund_body_en: Control = main._screens["fund"]._body
	if fund_body_en.get_child_count() > 0:
		fund_scroll_en.ensure_control_visible(fund_body_en.get_child(fund_body_en.get_child_count() - 1))
	await _settle(6)
	await _shot("fund_optimizer_en")
	I18n.set_locale("zh_CN")
	Game.settings["locale"] = "zh_CN"
	await _settle(10)
	await _capture_beta10_showcase()

	SmaSaveService.clear(Game.save_path)
	Game.save_path = SmaSaveService.SAVE_PATH
	get_tree().quit(0)


func _capture_beta10_showcase() -> void:
	_dismiss_story()
	main.navigate("trade")
	var ts: SmaTradeScreen = main._screens["trade"]
	ts._on_timeframe("1D")
	ts._boll_toggle.button_pressed = true
	ts._px_step_toggle.button_pressed = true
	ts._sync_chart_overlays()
	ts.refresh()
	await _settle(6)
	if main._pixel_fx != null:
		main._pixel_fx._popups.clear()
		main._pixel_fx._sparks.clear()
		main._pixel_fx.spawn_trade_fill({
			"ticker": "APLA", "qty": 40, "price": 182.40,
			"action": "openLong", "side": "buy", "realized": 148.60,
		})
		main._pixel_fx.spawn_xp_gain(45)
	await get_tree().process_frame
	await _shot("beta10_trade_stepped")
	if main._pixel_fx != null:
		main._pixel_fx._popups.clear()
		main._pixel_fx._sparks.clear()
		main._pixel_fx.queue_redraw()

	main._on_office_hotspot("mentor", {"mentor": "lin_lan"})
	await _settle(4)
	await _shot("beta10_mentor_diag")
	for child in main.get_children():
		if child is SmaOfficePopupDialog:
			child._close()
	await _settle(3)

	main._on_office_hotspot("honors", {})
	await _settle(4)
	await _shot("beta10_honors_case")
	for child in main.get_children():
		if child is SmaOfficePopupDialog:
			child._close()
	await _settle(3)

	main.navigate("market")
	await _settle(4)
	if main._office_banner != null:
		var q_txt := I18n.t("pixelOffice.quip.1")
		main._office_banner._quip_text = q_txt
		main._office_banner._quip_timer = 5.0
		main._office_banner.queue_redraw()
		main._on_office_hotspot("coffee", {"pos": Vector2(440, 130), "quip": q_txt})
	await get_tree().process_frame
	await _shot("beta10_coffee_easter")

	main.navigate("dashboard")
	await _settle(5)
	await _shot("beta11_dashboard_desk")

	Game.toggle_watch("APLA")
	Game.toggle_watch("NVDO")
	var alert_px := float(Game.exchange.quote("APLA").get("last", 180.0))
	Game.add_price_alert("APLA", "above", SmaFormat.round_to(alert_px * 1.03, 2))
	main.navigate("watchlist")
	await _settle(5)
	await _shot("beta11_watchlist_desk")
	main.navigate("screener")
	await _settle(5)
	await _shot("beta11_screener_desk")
	main.navigate("earnings")
	await _settle(5)
	await _shot("beta11_earnings_desk")

	Game.exchange.state["account"]["equityHistory"] = [
		{"day": 0, "equity": 100000.0},
		{"day": 1, "equity": 100640.0},
		{"day": 2, "equity": 100280.0},
		{"day": 3, "equity": 101420.0},
		{"day": 4, "equity": 101950.0},
		{"day": 5, "equity": 103180.0},
		{"day": 6, "equity": 102890.0},
		{"day": 7, "equity": 104560.0},
	]
	main.navigate("portfolio")
	main._screens["portfolio"]._last_rebuild = 0
	main._screens["portfolio"].refresh("force")
	await _settle(5)
	await _shot("beta11_portfolio_crt")

	main.navigate("academy")
	await _settle(4)
	main._screens["academy"]._open_demo("optionPayoff")
	await _settle(5)
	await _shot("beta11_demo_payoff")
	for child in main.get_children():
		if child is SmaDemoDialog:
			child._close()
	await _settle(3)

	Game.set_theme("light")
	await _settle(6)
	_dismiss_story()
	main.navigate("trade")
	var ts_light: SmaTradeScreen = main._screens["trade"]
	ts_light._on_timeframe("1D")
	ts_light._boll_toggle.button_pressed = true
	ts_light._sync_chart_overlays()
	ts_light.refresh()
	await _settle(5)
	await _shot("beta11_kairosoft_light")
	main.navigate("market")
	await _settle(5)
	await _shot("beta11_kairosoft_market")
	Game.set_theme("pixel")
	await _settle(5)


func _capture_beta12_showcase() -> void:
	var had_daily := SmaSaveService.exists(Game.DAILY_RECORDS_PATH)
	var orig_daily := Game.daily_records.duplicate(true)

	Game.new_game("beta12-showcase")
	await _settle(4)
	_dismiss_story()
	Game.set_player_name("林小望")
	Game.career["rank"] = 4
	Game.career["certificates"] = [
		{"id": "core_foundations", "day": 0},
		{"id": "risk_execution", "day": 2},
		{"id": "quant_derivatives", "day": 5},
	]
	Game.academy["xp"] = 2400
	Game.academy["achievements"] = ["first_trade", "profit_1k", "diversified", "unit_master"]
	for uid in ["u1", "u2", "u3", "u4", "u17", "u19", "u20", "u32"]:
		if Game.academy["units"].has(uid):
			Game.academy["units"][uid]["completed"] = true
	Game.fund["status"] = "active"
	Game.fund["name"] = "远望阿尔法一号"
	Game.fund["employees"] = [
		{"role": "research", "hiredDay": 1},
		{"role": "trader", "hiredDay": 2},
		{"role": "risk", "hiredDay": 3},
		{"role": "quant", "hiredDay": 4},
	]
	Game.submit_order({"ticker": "APLA", "side": "buy", "type": "market", "qty": 60})
	_dismiss_story()
	for i in 10:
		Game.step_minute()
	Game.exchange.state["account"]["equityHistory"] = [
		{"day": 0, "equity": 100000.0},
		{"day": 1, "equity": 101280.0},
		{"day": 2, "equity": 100850.0},
		{"day": 3, "equity": 103420.0},
		{"day": 4, "equity": 105190.0},
		{"day": 5, "equity": 104760.0},
		{"day": 6, "equity": 108640.0},
		{"day": 7, "equity": 112480.0},
	]
	Game.exchange.state["account"]["cash"] = 101800.0

	# Purchase 5 items and leave 1 affordable in the shop so both states show!
	for iid in ["espresso_bar", "lucky_cat", "bloomberg_rig", "world_clocks", "bull_statue"]:
		Game.purchase_office_item(iid)

	# 1. Upgraded Kairosoft Office Banner + Trade Terminal
	main.navigate("trade")
	if main._office_banner != null:
		main._office_banner.refresh_state()
	await _settle(6)
	await _shot("beta12_office_upgraded")

	# 2. Kairosoft Renovation Workshop Modal
	main._on_office_hotspot("shop", {})
	await _settle(5)
	await _shot("beta12_renovation_shop")
	for child in main.get_children():
		if child is SmaOfficePopupDialog:
			child._close()
	await _settle(3)

	# 3. PC-98 Portrait Micro-Animation & Crisis Emote Badge
	if Game.narrative != null:
		var target_st := "black_friday" if Game.narrative.stories.has("black_friday") else "opening"
		Game.narrative.seen.erase(target_st)
		Game.narrative.start_story(target_st)
		for step_i in 4:
			if not Game.narrative.is_active():
				break
			var cv: Dictionary = Game.narrative.current_view()
			if String(cv.get("portrait", "")) != "" and String(cv.get("characterId", "")) != "":
				break
			Game.narrative.advance()
	await _settle(3)
	if main._dialogue != null and main._dialogue._portrait_anim != null:
		main._dialogue._portrait_anim.mood = "crisis"
		main._dialogue._portrait_anim.force_mouth_open = true
		main._dialogue._portrait_anim.queue_redraw()
	await _settle(3)
	await _shot("beta12_portrait_anim")
	if main._dialogue != null and main._dialogue._portrait_anim != null:
		main._dialogue._portrait_anim.force_mouth_open = false
	_dismiss_story()
	await _settle(3)

	# 4. Gold-Rimmed 16-bit Pixel Diploma / Battle Poster Modal
	var poster: SmaReportPoster = main.open_poster()
	await _settle(6)
	await _shot("beta12_diploma_poster")
	if poster != null and is_instance_valid(poster):
		if poster._saved_user_path != "":
			DirAccess.remove_absolute(ProjectSettings.globalize_path(poster._saved_user_path))
		poster._close()
	await _settle(3)

	# 5. Daily Same-Seed 10-Day Sprint HUD + Leaderboard
	Game.save_game(false)
	Game.daily_records = SmaDailyChallenge.normalize_records([
		{"code": "2026-11-25", "grade": "S", "score": 1542, "returnPct": 7.45, "maxDrawdownPct": 1.12, "trades": 6},
		{"code": "2026-11-24", "grade": "A", "score": 1318, "returnPct": 4.20, "maxDrawdownPct": 0.95, "trades": 5},
	])
	Game.start_daily_sprint("2026-11-26")
	Game.submit_order({"ticker": "NVDO", "side": "buy", "type": "market", "qty": 45})
	for d in 4:
		Game.exchange.state["dayIndex"] = d + 1
		Game.exchange.state["account"]["equityHistory"].append({"day": d, "equity": 100000.0 + float(d + 1) * 980.0})
	Game.exchange.state["account"]["cash"] += 3850.0
	Game.record_daily_sprint()
	main.navigate("challenges")
	await _settle(6)
	await _shot("beta12_daily_sprint")

	Game.exit_sandbox()
	Game.daily_records = orig_daily
	if had_daily:
		SmaSaveService.export_to(Game.DAILY_RECORDS_PATH, {"records": orig_daily})
	else:
		SmaSaveService.clear(Game.DAILY_RECORDS_PATH)


func _dismiss_story() -> void:
	for i in 24:
		if Game.narrative == null or not Game.narrative.is_active():
			break
		var v: Dictionary = Game.narrative.current_view()
		if String(v.get("type", "")) == "choice":
			Game.narrative.choose(0)
		else:
			Game.narrative.advance()


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
	await get_tree().create_timer(0.12).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, name]
	image.save_png(path)
	print("SHOT ", path, " ", image.get_width(), "x", image.get_height())
