extends Node

const GapStage := SmaOpeningGap.Stage

## Headless integration smoke test. Runs the real main scene with autoloads,
## starts a game, trades, navigates every screen, saves, loads and quits.

func _ready() -> void:
	Game.save_path = "user://saves/integration.json"
	SmaSaveService.clear(Game.save_path)
	var failures: Array[String] = []
	var main_scene: PackedScene = load("res://ui/main.tscn")
	var main := main_scene.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	Game.new_game("integration-seed")
	await get_tree().process_frame
	if not Game.started:
		failures.append("game did not start")
	if Game.narrative == null or not Game.narrative.is_active():
		failures.append("opening story did not start")
	var opening_second := int(Game.exchange.state["second"])
	Game._process(2.0)
	if int(Game.exchange.state["second"]) != opening_second:
		failures.append("the market clock ran during the opening story")
	if main._dialogue == null or not main._dialogue._portrait_frame.visible:
		failures.append("opening dialogue portrait is not visible")
	# Walk the opening story to the first choice and pick a path.
	for i in 8:
		if not Game.narrative.is_active():
			break
		var view: Dictionary = Game.narrative.current_view()
		if String(view.get("type", "")) == "choice":
			await get_tree().process_frame
			for option: Button in main._dialogue._choices.get_children():
				if option.focus_mode != Control.FOCUS_ALL:
					failures.append("dialogue choices cannot receive keyboard focus")
			Game.narrative.choose(0)
		else:
			Game.narrative.advance()
	if Game.narrative.is_active():
		failures.append("opening story did not finish")
	if String(Game.narrative.flags.get("path", "")) != "value":
		failures.append("story choice did not set the path flag")
	if main._current_screen != "dashboard" or not Game.has_intro_task():
		failures.append("opening did not lead to today's task")
	main.navigate("opening_gap")
	if main._current_screen == "opening_gap" or Game.opening_gap_active:
		failures.append("opening-gap chapter unlocked before the first review")
	main._screens["dashboard"]._open_intro_trade()
	if main._current_screen != "trade" or Game.selected_ticker != "APLA":
		failures.append("first task did not open the APLA ticket")
	var first_chart: SmaCandleChart = main._screens["trade"]._chart
	if first_chart.timeframe != "1m" or first_chart.candles.size() != 1:
		failures.append("new careers do not open with a live 1m candle")
	else:
		var opening_price := float(first_chart.candles[0]["c"])
		await get_tree().create_timer(1.5).timeout
		var live_second := int(Game.exchange.state["second"])
		if live_second <= opening_second \
				or main._clock_label.text != SmaCalendar.session_clock(live_second) \
				or float(first_chart.candles[0]["c"]) == opening_price:
			failures.append("clock and 1m candle did not start automatically after the opening story")
	Game.set_paused(true)
	if not Game.set_intro_plan("Check the spread", "Exit below the morning range", 100.0):
		failures.append("trade plan did not save before the fill")

	await get_tree().process_frame
	var order := Game.submit_order({
		"ticker": "APLA", "side": "buy", "type": "market", "qty": 10,
	})
	if not bool(order.get("ok", false)):
		failures.append("market buy rejected: %s" % order.get("error", ""))
	if int(Game.get_position_qty("APLA")) != 10:
		failures.append("position did not update")
	var first_receipt: Dictionary = Game.intro["receipt"]
	if first_receipt.get("qty") != 10 or first_receipt.get("ticker") != "APLA" \
			or not bool(Game.intro["plan"].get("beforeFill", false)):
		failures.append("first fill did not capture the trade and its plan")
	if Game.narrative == null or not Game.narrative.is_active():
		failures.append("first-trade story did not trigger")
	# Close the first-trade story so it does not block the clock.
	for i in 10:
		if not Game.narrative.is_active():
			break
		var view: Dictionary = Game.narrative.current_view()
		if String(view.get("type", "")) == "choice":
			Game.narrative.choose(0)
		else:
			Game.narrative.advance()

	var expected_minute_step := int(Game.exchange.state["second"]) + 60
	Game.step_minute()
	await get_tree().process_frame
	if int(Game.exchange.state["second"]) != expected_minute_step:
		failures.append("minute step did not advance the clock")

	var speed_key := InputEventKey.new()
	speed_key.keycode = KEY_3
	speed_key.pressed = true
	main._unhandled_input(speed_key)
	if int(Game.speed) != 10:
		failures.append("number shortcut did not select 10x speed")
	Game.set_speed(1)
	var pause_key := InputEventKey.new()
	pause_key.keycode = KEY_SPACE
	pause_key.pressed = true
	var paused_before := Game.paused
	main._unhandled_input(pause_key)
	if Game.paused == paused_before:
		failures.append("space shortcut did not toggle pause")
	Game.set_paused(true)
	var help_key := InputEventKey.new()
	help_key.keycode = KEY_F1
	help_key.pressed = true
	main._unhandled_input(help_key)
	if main._help_dialog == null or not is_instance_valid(main._help_dialog):
		failures.append("F1 did not open the shortcut reference")
	elif main._help_dialog.visible:
		main._help_dialog.hide()

	# Progressive market access must block new exposure but not exits.
	if not bool(Game.market_lock_info("SLDY").get("locked", false)):
		failures.append("energy sector should start locked")
	var locked_buy := Game.submit_order({
		"ticker": "SLDY", "side": "buy", "type": "market", "qty": 1})
	if String(locked_buy.get("error", "")) != "order.marketLocked":
		failures.append("locked-sector buy was not rejected")
	var disguised_open := Game.submit_order({
		"ticker": "SLDY", "side": "sell", "action": "openLong",
		"type": "market", "qty": 1})
	if String(disguised_open.get("error", "")) != "order.marketLocked":
		failures.append("explicit openLong bypassed the market lock")

	for screen_id in ["market", "trade", "portfolio"]:
		main.navigate(screen_id)
		await get_tree().process_frame
		await get_tree().process_frame

	main.navigate("market")
	await get_tree().process_frame
	var market_screen = main._screens["market"]
	if market_screen._heat_tiles.size() < 2:
		failures.append("sector heatmap did not render")
	else:
		market_screen._on_heatmap_sector("technology")
		if market_screen._sector_filter.selected <= 0:
			failures.append("heatmap click did not select a sector")
		market_screen._sector_filter.select(0)
		market_screen._apply_filter()
	market_screen._on_watch_pressed("APLA")
	if not Game.is_watched("APLA"):
		failures.append("market star did not add to watchlist")
	market_screen._watch_only.button_pressed = true
	market_screen._apply_filter()
	await get_tree().process_frame
	var visible_rows := 0
	var visible_unwatched := 0
	for ticker in market_screen._rows.keys():
		var row: Dictionary = market_screen._rows[ticker]
		if row["panel"].visible:
			visible_rows += 1
			if not Game.is_watched(String(ticker)):
				visible_unwatched += 1
	if visible_rows != 1 or visible_unwatched != 0:
		failures.append("watch-only filter did not isolate the watchlist")
	market_screen._watch_only.button_pressed = false
	market_screen._apply_filter()
	market_screen._on_watch_pressed("APLA")
	if Game.is_watched("APLA"):
		failures.append("market star did not remove from watchlist")
	main.navigate("trade")
	await get_tree().process_frame
	_check_trade_language_draft(main, failures)

	main.navigate("academy")
	await get_tree().process_frame
	var section_result := Game.academy_mark_section_read("u1", "s1")
	if not bool(section_result.get("ok", false)):
		failures.append("academy section read failed")
	if not SmaAcademy.is_section_read(Game.academy, "u1", "s1"):
		failures.append("academy section was not recorded")
	var academy_screen = main._screens["academy"]
	academy_screen._open_quiz("u1")
	await get_tree().process_frame
	for child in main.get_children():
		if child is SmaQuizDialog:
			for entry in child._controls.values():
				if String(entry["type"]) == "numeric":
					entry["control"].text = "1"
				elif String(entry["type"]) == "multi":
					entry["checks"][0]["control"].button_pressed = true
				else:
					entry["checks"][0].button_pressed = true
			child._submit()
			child._close()
	await get_tree().process_frame
	if int(SmaAcademy.ensure_unit(Game.academy, "u1").get("quizAttempts", 0)) < 1:
		failures.append("academy quiz submission did not record an attempt")

	academy_screen._open_demo("candle")
	await get_tree().process_frame
	var demo_dialog: SmaDemoDialog = null
	for child in main.get_children():
		if child is SmaDemoDialog:
			demo_dialog = child
	if demo_dialog == null:
		failures.append("candle demo did not open")
	else:
		for i in 3:
			var bullish := demo_dialog.close_price_from_illustration() \
				>= demo_dialog.open_price_from_illustration()
			demo_dialog._answer_candle("bull" if bullish else "bear")
		demo_dialog._close()
	await get_tree().process_frame
	if not bool(Game.academy["demosCompleted"].get("candle", false)):
		failures.append("candle demo was not recorded")
	if not bool(SmaAcademy.evaluate_practice(Game.academy, SmaAcademy.unit("u9"), {})["done"]):
		failures.append("candle demo did not satisfy u9 practice")

	main.navigate("trade")
	await get_tree().process_frame
	var trade_screen = main._screens["trade"]
	trade_screen._open_financials()
	await get_tree().process_frame
	var financials_dialog: SmaFinancialsDialog = null
	for child in main.get_children():
		if child is SmaFinancialsDialog:
			financials_dialog = child
	if financials_dialog == null:
		failures.append("financials dialog did not open")
	else:
		financials_dialog._close()
	if not Game.academy["financialsViewed"].has(Game.selected_ticker):
		failures.append("financials view was not recorded")
	Game.academy_record_financials("NVDO")
	await get_tree().process_frame
	if not bool(SmaAcademy.evaluate_practice(Game.academy, SmaAcademy.unit("u11"), {})["done"]):
		failures.append("two financials views did not satisfy u11 practice")

	Game.toggle_watch("APLA")
	if not Game.is_watched("APLA"):
		failures.append("watchlist toggle failed")
	main.navigate("watchlist")
	await get_tree().process_frame
	var watchlist_screen = main._screens["watchlist"]
	if not watchlist_screen._watch_rows.has("APLA"):
		failures.append("watchlist page did not render the followed ticker")
	if watchlist_screen.get_child_count() == 0:
		failures.append("watchlist page did not render")
	main.navigate("trade")
	await get_tree().process_frame
	trade_screen = main._screens["trade"]
	var alert_reference := float(Game.exchange.quote("APLA").get("last", 0.0))
	var alert_added := Game.add_price_alert("APLA", "above", alert_reference + 1.0)
	if not bool(alert_added.get("ok", false)):
		failures.append("price alert creation failed")
	trade_screen._open_alerts()
	await get_tree().process_frame
	var alert_dialog: SmaPriceAlertDialog = null
	for child in main.get_children():
		if child is SmaPriceAlertDialog:
			alert_dialog = child
	if alert_dialog == null:
		failures.append("price alert dialog did not open")
	else:
		var dialog_price := alert_dialog._current_price()
		alert_dialog._side_option.select(1)
		alert_dialog._price_spin.value = dialog_price * 0.9
		var alerts_before_dialog := Game.price_alerts().size()
		alert_dialog._add_alert()
		if Game.price_alerts().size() != alerts_before_dialog + 1:
			failures.append("price alert dialog did not add an alert")
		else:
			var dialog_alert_id := String(Game.price_alerts()[-1]["id"])
			alert_dialog._remove_alert(dialog_alert_id)
			if Game.price_alerts().size() != alerts_before_dialog:
				failures.append("price alert dialog did not remove an alert")
		alert_dialog._close()
	await get_tree().process_frame

	var trigger_reference := float(Game.exchange.quote("APLA").get("last", 0.0))
	var trigger_result := Game.add_price_alert("APLA", "above", trigger_reference + 0.01)
	if not bool(trigger_result.get("ok", false)):
		failures.append("triggerable price alert creation failed")
	else:
		var trigger_id := String(trigger_result["alert"]["id"])
		var company_state: Dictionary = Game.exchange.state["companies"]["APLA"]
		var original_last := float(company_state["last"])
		var original_second := int(Game.exchange.state["second"])
		company_state["last"] = trigger_reference + 0.02
		Game.exchange.state["second"] = 10
		Game._check_price_alerts()
		var trigger_fired := false
		for entry in Game.price_alerts():
			if String(entry.get("id", "")) == trigger_id:
				trigger_fired = not bool(entry.get("active", true))
		if not trigger_fired:
			failures.append("price alert did not trigger on threshold")
		company_state["last"] = original_last
		Game.exchange.state["second"] = original_second
		Game.remove_price_alert(trigger_id)

	main.navigate("watchlist")
	await get_tree().process_frame
	watchlist_screen = main._screens["watchlist"]
	if watchlist_screen._alerts_box == null \
			or watchlist_screen._alerts_box.get_child_count() == 0:
		failures.append("watchlist page did not render the alert list")
	main.navigate("trade")
	await get_tree().process_frame

	for demo_id in ["macro", "allocation", "risk", "strategies"]:
		academy_screen._open_demo(demo_id)
		await get_tree().process_frame
		var stage_demo: SmaDemoDialog = null
		for child in main.get_children():
			if child is SmaDemoDialog:
				stage_demo = child
		if stage_demo == null:
			failures.append("%s demo did not open" % demo_id)
			continue
		match demo_id:
			"macro":
				stage_demo._macro_fields["inflation"].value = 3.5
			"allocation":
				stage_demo._allocation_fields["stocks"].value = 70.0
			"risk":
				stage_demo._risk_fields["account"].value = 15000.0
			"strategies":
				stage_demo._on_strategy_changed(2)
		stage_demo._close()
		await get_tree().process_frame
		if not bool(Game.academy["demosCompleted"].get(demo_id, false)):
			failures.append("%s demo was not recorded" % demo_id)

	for demo_id in ["shortPnl", "margin", "stopOrder", "orderBook"]:
		academy_screen._open_demo(demo_id)
		await get_tree().process_frame
		var stage_demo: SmaDemoDialog = null
		for child in main.get_children():
			if child is SmaDemoDialog:
				stage_demo = child
		if stage_demo == null:
			failures.append("%s demo did not open" % demo_id)
			continue
		match demo_id:
			"shortPnl":
				stage_demo._short_fields["exit"].value = 45.0
			"margin":
				stage_demo._margin_fields["price"].value = 60.0
			"stopOrder":
				stage_demo._stop_fields["trail"].value = 8.0
			"orderBook":
				stage_demo._book_qty.value = 1000.0
		stage_demo._close()
		await get_tree().process_frame
		var recorded := bool(Game.academy["demosCompleted"].get(demo_id, false))
		if demo_id in ["margin", "orderBook"] and not recorded:
			failures.append("%s demo was not recorded" % demo_id)
		if demo_id in ["shortPnl", "stopOrder"] and recorded:
			failures.append("%s demo should not complete a practice" % demo_id)

	# Verify tool locks are enforced before their lessons are read.
	if String(Game.submit_order({"ticker": "APLA", "side": "buy", "type": "limit",
			"qty": 1, "limitPrice": 10.0}).get("error", "")) != "order.limitLocked":
		failures.append("limit order should stay locked before u4/s3")
	if String(Game.submit_order({"ticker": "APLA", "side": "sell", "type": "stop",
			"qty": 1, "stopPrice": 10.0}).get("error", "")) != "order.stopLocked":
		failures.append("stop order should stay locked before u19/s1")
	if String(Game.submit_order({"ticker": "NVDO", "side": "short", "type": "market",
			"qty": 5}).get("error", "")) != "order.shortLocked":
		failures.append("short selling should stay locked before u17/s1")
	if String(Game.submit_order({"ticker": "APLA", "side": "buy", "type": "market",
			"qty": 1000}).get("error", "")) != "order.marginLocked":
		failures.append("margin leverage should stay locked before u18/s1")
	if String(Game.buy_bond("gov2", 1).get("error", "")) != "order.multiassetLocked":
		failures.append("multi-asset bond should stay locked before u13")

	Game.academy_mark_section_read("u4", "s3")
	Game.academy_mark_section_read("u17", "s1")
	Game.academy_mark_section_read("u18", "s1")
	Game.academy_mark_section_read("u19", "s1")
	Game.academy_mark_section_read("u20", "s1")

	main.navigate("trade")
	await get_tree().process_frame
	_check_trade_stop_language_draft(main, failures)
	trade_screen = main._screens["trade"]
	trade_screen._on_side("sell")
	trade_screen._on_type("stop")
	trade_screen._qty.value = 10
	var stop_reference := float(Game.exchange.quote("APLA").get("last", 0.0)) * 1.2
	trade_screen._stop_price.value = stop_reference
	trade_screen._submit()
	Game.step_minute()
	await get_tree().process_frame
	if not bool(SmaAcademy.evaluate_practice(Game.academy, SmaAcademy.unit("u19"),
			Game.academy_snapshot())["done"]):
		failures.append("filled stop order did not satisfy u19 practice")

	Game.submit_order({"ticker": "VISO", "side": "buy", "type": "market", "qty": 10})
	Game.selected_ticker = "VISO"
	main.navigate("trade")
	await get_tree().process_frame
	trade_screen = main._screens["trade"]
	if not trade_screen._oco_card.visible:
		failures.append("OCO card should show for an open long")
	else:
		var oco_last := float(Game.exchange.quote("VISO").get("last", 0.0))
		trade_screen._oco_qty.value = 10
		trade_screen._oco_tp.value = oco_last * 1.2
		trade_screen._oco_stop.value = oco_last * 0.8
		trade_screen._submit_oco()
		await get_tree().process_frame
		var oco_legs: Array = []
		for row in Game.exchange.open_order_rows("player"):
			if not String(row.get("ocoGroup", "")).is_empty():
				oco_legs.append(row)
		if oco_legs.size() != 2:
			failures.append("OCO UI did not create two legs")
		else:
			Game.cancel_order(String(oco_legs[0]["id"]))
			await get_tree().process_frame
			var live_legs := 0
			for row in Game.exchange.open_order_rows("player"):
				if String(row.get("ocoGroup", "")) == String(oco_legs[0]["ocoGroup"]):
					live_legs += 1
			if live_legs != 0:
				failures.append("cancelling one OCO leg left the sibling working")
	Game.submit_order({"ticker": "VISO", "side": "sell", "type": "market", "qty": 10})
	Game.selected_ticker = "APLA"
	await get_tree().process_frame

	Game.set_layout("advanced")
	await get_tree().process_frame
	main.navigate("trade")
	await get_tree().process_frame
	var advanced_trade = main._screens["trade"]
	if not advanced_trade._indicators_card.visible:
		failures.append("advanced layout should show technical indicators")
	Game.set_layout("beginner")
	await get_tree().process_frame
	academy_screen = main._screens["academy"]

	var short_open := Game.submit_order({
		"ticker": "NVDO", "side": "short", "type": "market", "qty": 5,
	})
	if not bool(short_open.get("ok", false)):
		failures.append("short open rejected: %s" % short_open.get("error", ""))
	var short_cover := Game.submit_order({
		"ticker": "NVDO", "side": "cover", "type": "market", "qty": 5,
	})
	if not bool(short_cover.get("ok", false)):
		failures.append("short cover rejected: %s" % short_cover.get("error", ""))
	if not bool(SmaAcademy.evaluate_practice(Game.academy, SmaAcademy.unit("u17"),
			Game.academy_snapshot())["done"]):
		failures.append("short round trip did not satisfy u17 practice")

	Game.academy_mark_section_read("u21", "s1")
	if Game.option_style() != "european":
		failures.append("options should start European")
	if not bool(Game.set_option_style("american").get("ok", false)):
		failures.append("option style should switch on a flat book")
	if Game.option_style() != "american":
		failures.append("American option style did not persist")
	if not bool(Game.set_option_style("european").get("ok", false)):
		failures.append("option style should switch back")
	main.navigate("options")
	await get_tree().process_frame
	var options_screen = main._screens["options"]
	if options_screen._chain.is_empty():
		failures.append("options chain did not render")
	else:
		options_screen._submit()
		await get_tree().process_frame
		options_screen._select_contract("put", options_screen._selected_strike)
		options_screen._submit()
		await get_tree().process_frame
		if Game.exchange.state["account"]["options"].size() != 2:
			failures.append("option purchases were not recorded")
		if bool(Game.set_option_style("american").get("ok", false)):
			failures.append("option style must lock while contracts are open")
		if not bool(SmaAcademy.evaluate_practice(Game.academy, SmaAcademy.unit("u22"),
				Game.academy_snapshot())["done"]):
			failures.append("call purchase did not satisfy u22 practice")
		if not bool(SmaAcademy.evaluate_practice(Game.academy, SmaAcademy.unit("u23"),
				Game.academy_snapshot())["done"]):
			failures.append("put purchase did not satisfy u23 practice")
		var option_rows: Array = Game.option_rows()
		for row in option_rows:
			if String(row.get("type", "")) == "put":
				options_screen._close_position(String(row["key"]), 1)
				break
		await get_tree().process_frame
		if Game.exchange.state["account"]["options"].size() != 1:
			failures.append("closing an option did not update the position")

	academy_screen._open_demo("greeks")
	await get_tree().process_frame
	var greeks_demo: SmaDemoDialog = null
	for child in main.get_children():
		if child is SmaDemoDialog:
			greeks_demo = child
	if greeks_demo == null:
		failures.append("greeks demo did not open")
	else:
		greeks_demo._greeks_fields["spot"].value = 55.0
		greeks_demo._close()
	await get_tree().process_frame
	if not bool(Game.academy["demosCompleted"].get("greeks", false)):
		failures.append("greeks demo was not recorded")

	academy_screen._open_demo("strategyPayoff")
	await get_tree().process_frame
	var strategy_demo: SmaDemoDialog = null
	for child in main.get_children():
		if child is SmaDemoDialog:
			strategy_demo = child
	if strategy_demo == null:
		failures.append("strategy payoff demo did not open")
	else:
		strategy_demo._payoff_strategy_preset.select(4)
		strategy_demo._update_strategy_payoff()
		if strategy_demo._payoff_strategy_labels["maxProfit"].text \
				!= I18n.t("demo.strategyPayoff.unlimited"):
			failures.append("long straddle should show unlimited profit")
		if strategy_demo._payoff_strategy_chart.values.size() != 41:
			failures.append("strategy payoff chart did not render")
		strategy_demo._close()
	await get_tree().process_frame

	var locked_strategy: Dictionary = Game.open_option_strategy(
		"cashSecuredPut", "APLA", 30, 1)
	if String(locked_strategy.get("error", "")) != "error.optionsSellLocked":
		failures.append("option strategies should stay locked before u25")

	Game.academy_mark_section_read("u25", "s1")
	await get_tree().process_frame
	var uncovered_call: Dictionary = Game.open_option_strategy(
		"coveredCall", "APLA", 30, 1)
	if String(uncovered_call.get("error", "")) != "error.needCoveredShares":
		failures.append("covered call without 100 shares should be rejected")
	main.navigate("options")
	await get_tree().process_frame
	options_screen = main._screens["options"]
	options_screen._select_contract("put", float(options_screen._chain["strikes"][1]))
	options_screen._set_mode("sell")
	await get_tree().process_frame
	options_screen._submit()
	await get_tree().process_frame
	if not bool(SmaAcademy.evaluate_practice(Game.academy, SmaAcademy.unit("u25"),
			Game.academy_snapshot())["done"]):
		failures.append("selling an option did not satisfy u25 practice")
	if not bool(SmaAcademy.evaluate_practice(Game.academy, SmaAcademy.unit("u26"),
			Game.academy_snapshot())["done"]):
		failures.append("cash-secured put did not satisfy u26 practice")
	var spread_result: Dictionary = Game.open_option_strategy(
		"bullCallSpread", "APLA", 30, 1)
	if not bool(spread_result.get("ok", false)):
		failures.append("bull call spread rejected: %s" % spread_result.get("error", ""))
	if not bool(SmaAcademy.evaluate_practice(Game.academy, SmaAcademy.unit("u27"),
			Game.academy_snapshot())["done"]):
		failures.append("call spread did not satisfy u27 practice")
	var volatility_result: Dictionary = Game.open_option_strategy(
		"longStraddle", "APLA", 30, 1)
	if not bool(volatility_result.get("ok", false)):
		failures.append("long straddle rejected: %s" % volatility_result.get("error", ""))
	if not bool(SmaAcademy.evaluate_practice(Game.academy, SmaAcademy.unit("u28"),
			Game.academy_snapshot())["done"]):
		failures.append("long straddle did not satisfy u28 practice")
	var has_short_option := false
	for position in Game.exchange.state["account"]["options"]:
		if int(position.get("qty", 0)) < 0:
			has_short_option = true
	if not has_short_option:
		failures.append("short option position was not recorded")

	var locked_future: Dictionary = Game.open_future("APLA", 30, "long", 1)
	if String(locked_future.get("error", "")) != "error.futuresLocked":
		failures.append("futures should stay locked before u29")
	Game.academy_mark_section_read("u29", "s1")
	await get_tree().process_frame
	main.navigate("futures")
	await get_tree().process_frame
	var futures_screen = main._screens["futures"]
	if futures_screen._chain.is_empty():
		failures.append("futures chain did not render")
	else:
		futures_screen._submit()
		await get_tree().process_frame
		if Game.exchange.state["account"]["futures"].size() != 1:
			failures.append("futures position was not recorded")
		if not bool(SmaAcademy.evaluate_practice(Game.academy, SmaAcademy.unit("u29"),
				Game.academy_snapshot())["done"]):
			failures.append("opening a future did not satisfy u29 practice")
	Game.submit_order({"ticker": "APLA", "side": "buy", "type": "market", "qty": 10})
	var hedge_open: Dictionary = Game.open_future("APLA", 30, "short", 1)
	if not bool(hedge_open.get("ok", false)):
		failures.append("hedge future rejected: %s" % hedge_open.get("error", ""))
	if not bool(SmaAcademy.evaluate_practice(Game.academy, SmaAcademy.unit("u30"),
			Game.academy_snapshot())["done"]):
		failures.append("stock plus short future did not satisfy u30 practice")
	academy_screen._open_demo("stressTest")
	await get_tree().process_frame
	var stress_demo: SmaDemoDialog = null
	for child in main.get_children():
		if child is SmaDemoDialog:
			stress_demo = child
	if stress_demo == null:
		failures.append("stress test demo did not open")
	else:
		stress_demo._stress_fields["equity"].value = 15000.0
		stress_demo._close()
	await get_tree().process_frame
	if not bool(Game.academy["demosCompleted"].get("stressTest", false)):
		failures.append("stress test demo was not recorded")
	if not bool(SmaAcademy.evaluate_practice(Game.academy, SmaAcademy.unit("u31"),
			Game.academy_snapshot())["done"]):
		failures.append("stress test demo did not satisfy u31 practice")
	if not bool(SmaAcademy.evaluate_practice(Game.academy, SmaAcademy.unit("u32"),
			Game.academy_snapshot())["done"]):
		failures.append("stock, option and futures trades did not satisfy u32")

	for section_id in ["s1", "s2", "s3"]:
		Game.academy_mark_section_read("u32", section_id)
	SmaAcademy.record_practice(Game.academy, "u32", Game.get_day())
	var u32_quiz := SmaAcademy.build_quiz("u32", 1)
	var u32_answers := {}
	for question in u32_quiz["questions"]:
		var question_id := String(question["id"])
		if String(question["type"]) == "numeric":
			u32_answers[question_id] = float(question.get("answer", 0.0))
		elif String(question["type"]) == "multi":
			u32_answers[question_id] = question.get("correctIds", [])
		else:
			var ids: Array = question.get("correctIds", [])
			u32_answers[question_id] = ids[0] if not ids.is_empty() else ""
	var u32_grade := SmaAcademy.grade_quiz(u32_quiz, u32_answers)
	SmaAcademy.record_quiz(Game.academy, "u32", int(u32_grade["score"]), Game.get_day())
	if not SmaAcademy.is_unit_unlocked(Game.academy, "b1"):
		failures.append("completing u32 did not unlock branch b1")
	main.navigate("academy")
	await get_tree().process_frame
	academy_screen._select_unit("b1")
	await get_tree().process_frame
	if academy_screen._selected_unit != "b1":
		failures.append("branch b1 did not open in the academy")

	Game.academy["units"]["u13"]["completed"] = true
	main.navigate("multiasset")
	await get_tree().process_frame
	var multiasset_screen = main._screens["multiasset"]
	if multiasset_screen._body.get_child_count() == 0:
		failures.append("multi-asset screen did not render")
	if not bool(Game.buy_bond("gov2", 1).get("ok", false)):
		failures.append("bond purchase failed")
	if not bool(Game.buy_fx("EURUSD", 1000).get("ok", false)):
		failures.append("FX purchase failed")
	if not bool(Game.buy_commodity("gold", 1).get("ok", false)):
		failures.append("commodity purchase failed")
	if not bool(Game.buy_crypto("BTC", 0.01).get("ok", false)):
		failures.append("crypto purchase failed")
	if Game.bond_rows().size() != 1:
		failures.append("bond position was not recorded")
	if Game.fx_rows().size() != 1:
		failures.append("FX position was not recorded")
	if Game.commodity_rows().size() != 1:
		failures.append("commodity position was not recorded")
	if Game.crypto_rows().size() != 1:
		failures.append("crypto position was not recorded")

	main.navigate("history")
	await get_tree().process_frame
	var history_screen = main._screens["history"]
	await history_screen._start_scenario("2008-crisis")
	await get_tree().process_frame
	if history_screen._dataset.is_empty():
		failures.append("history dataset did not load")
	history_screen._selected_symbol = "AAPL"
	history_screen._trade("buy")
	var history_run: Dictionary = Game.history.run("2008-crisis")
	if history_run.is_empty() or int(history_run["account"]["positions"].get("AAPL", {}).get("qty", 0)) != 10:
		failures.append("history trade did not reach the run account")
	history_screen._advance_day()
	await get_tree().process_frame

	for screen_id in ["story", "market"]:
		main.navigate(screen_id)
		await get_tree().process_frame
		await get_tree().process_frame

	# --- Phase 9 surfaces: ETFs, challenges, career, fund, quant, tax and utility pages.
	Game.academy["units"]["u7"]["completed"] = true
	var etf_buy: Dictionary = Game.submit_order({"ticker": "MKT", "side": "buy",
		"type": "market", "qty": 5})
	if not bool(etf_buy.get("ok", false)):
		failures.append("ETF order failed")
	if int(Game.exchange.state["account"]["positions"].get("MKT", {}).get("qty", 0)) != 5:
		failures.append("ETF position missing")
	Game.academy["units"]["u3"]["completed"] = true
	var challenge: Dictionary = Game.start_challenge("firstProfit")
	if not bool(challenge.get("ok", false)):
		failures.append("challenge did not start")
	if Game.challenge_progress().is_empty():
		failures.append("challenge progress missing")
	Game.career["rank"] = 5
	var fund_created: Dictionary = Game.create_fund({
		"name": "Integration Fund", "strategy": "longOnly", "riskProfile": "balanced",
		"initialAum": 1000000.0, "managementRate": 0.02, "performanceRate": 0.2,
		"benchmarkId": "index", "hurdleRate": 0.0, "leverageEnabled": false,
		"taxProfileId": "none",
	})
	if not bool(fund_created.get("ok", false)):
		failures.append("fund creation failed")
	if not bool(Game.narrative.flags.get("had_fund", false)):
		failures.append("fund creation did not set had_fund")
	var fund_clients_before: int = Game.fund.get("clients", []).size()
	if not bool(Game.fund_buy("APLA", 10).get("ok", false)):
		failures.append("fund purchase failed")
	var fund_plan: Dictionary = Game.fund_generate_plan()
	if not bool(fund_plan.get("ok", false)):
		failures.append("fund plan generation failed")
	var quant_result: Dictionary = Game.quant_backtest({
		"ticker": "APLA", "strategy": "smaCross", "initialCash": 100000.0,
	})
	if not bool(quant_result.get("ok", false)):
		failures.append("quant backtest failed")
	var tax_result: Dictionary = Game.tax_estimate({"fxRate": 1.0, "accountType": "gia",
		"incomeBand": "basic", "taxableIncome": 0.0, "isaContributions": 0.0,
		"ukShares": false})
	if not bool(tax_result.get("ok", false)):
		failures.append("tax estimate failed")
	var reports: Array = Game.statement_history("APLA", 8)
	if reports.size() != 8:
		failures.append("quarterly statement history missing")
	if Game.review_summary().is_empty():
		failures.append("review summary missing")
	if Game.review_timeline(5).is_empty():
		failures.append("review timeline missing")
	Game.set_layout("advanced")
	if absf(SmaUiTheme.density - 0.88) > 0.001:
		failures.append("advanced layout density not applied")
	Game.set_layout("beginner")
	if absf(SmaUiTheme.density - 1.0) > 0.001:
		failures.append("beginner layout density not restored")
	Game.set_theme("light")
	if SmaUiTheme.mode != "light":
		failures.append("light theme not applied")
	Game.set_theme("dark")
	if SmaUiTheme.mode != "dark":
		failures.append("dark theme not restored")
	Game.set_theme("pixel")
	if SmaUiTheme.mode != "pixel" or not SmaUiTheme.is_pixel():
		failures.append("pixel theme not applied")
	Game.set_color_scheme("cn")
	if SmaUiTheme.color_scheme != "cn" or SmaUiTheme.POSITIVE.r <= SmaUiTheme.POSITIVE.g:
		failures.append("CN color scheme not applied")
	Game.set_color_scheme("colorblind")
	if SmaUiTheme.color_scheme != "colorblind" or SmaUiTheme.POSITIVE.b <= SmaUiTheme.POSITIVE.r:
		failures.append("colorblind color scheme not applied")
	Game.set_color_scheme("cn")
	var replay := Game.replay_snapshot(Game.replay_max_day())
	if replay.is_empty() or not (replay.get("positions", []) is Array):
		failures.append("replay snapshot missing")

	for screen_id in ["etf", "challenges", "career", "fund", "quant", "tax",
			"statements", "glossary", "sandbox", "roadmap", "boundaries", "settings",
			"replay", "news", "watchlist", "screener", "earnings"]:
		if not main._screens.has(screen_id):
			failures.append("screen not registered: %s" % screen_id)
			continue
		main.navigate(screen_id)
		await get_tree().process_frame
		await get_tree().process_frame
		var surface = main._screens[screen_id]
		if surface.get_child_count() == 0:
			failures.append("screen did not render: %s" % screen_id)
	main.navigate("dashboard")
	await get_tree().process_frame

	var save_ok := Game.save_game(false)
	if not save_ok:
		failures.append("save failed")
	var equity_before := Game.get_equity()
	var day_before := Game.get_day()
	if not Game.load_game():
		failures.append("load failed")
	elif Game.paused:
		failures.append("loading a career left the market clock paused")
	var restored_receipt: Dictionary = Game.intro.get("receipt", {})
	if restored_receipt.get("orderId") != first_receipt.get("orderId") \
			or not is_equal_approx(float(restored_receipt.get("price", 0.0)), float(first_receipt["price"])) \
			or not is_equal_approx(float(restored_receipt.get("weight", 0.0)), float(first_receipt["weight"])):
		failures.append("first-fill receipt changed across save/load")
	var import_path := Game.save_path.get_basename() + "-import.json"
	if not Game.export_save(import_path) or not Game.import_save(import_path):
		failures.append("valid career export did not import")
	var valid_save := FileAccess.get_file_as_bytes(Game.save_path)
	var bad_save := SmaSaveService.read(Game.save_path)
	bad_save["exchange"]["account"]["positions"]["APLA"] = {"qty": 5}
	if not SmaSaveService.export_to(import_path, bad_save):
		failures.append("could not create invalid import fixture")
	elif Game.import_save(import_path) or FileAccess.get_file_as_bytes(Game.save_path) != valid_save:
		failures.append("invalid import overwrote the career slot")
	SmaSaveService.clear(import_path)
	if not Game.save_game(false) or not SmaSaveService.export_to(Game.save_path,
			{"version": 1, "exchange": []}) or not Game.load_game():
		failures.append("valid backup did not recover a corrupt primary save")
	elif not Game.save_game(false):
		failures.append("recovered career could not be saved")
	if absf(Game.get_equity() - equity_before) > 0.01:
		failures.append("equity changed across save/load")
	if Game.get_day() != day_before:
		failures.append("day changed across save/load")
	if not SmaAcademy.is_section_read(Game.academy, "u1", "s1"):
		failures.append("academy progress was not restored")
	if not bool(Game.academy["demosCompleted"].get("candle", false)):
		failures.append("demo completion was not restored")
	if not Game.academy["financialsViewed"].has("NVDO"):
		failures.append("financials views were not restored")
	if not Game.is_watched("APLA"):
		failures.append("watchlist was not restored")
	if String(Game.settings.get("colorScheme", "")) != "cn" or SmaUiTheme.color_scheme != "cn":
		failures.append("color scheme did not persist across save/load")
	Game.set_color_scheme("intl")
	if Game.price_alerts().size() != 1:
		failures.append("price alert was not restored")
	if not bool(Game.academy["demosCompleted"].get("greeks", false)):
		failures.append("greeks demo completion was not restored")
	var restored_short := false
	for position in Game.exchange.state["account"]["options"]:
		if int(position.get("qty", 0)) < 0:
			restored_short = true
	if not restored_short:
		failures.append("short option position was not restored")
	if String(Game.fund.get("status", "none")) != "active":
		failures.append("fund was not restored")
	if int(Game.career.get("rank", 0)) != 5:
		failures.append("career rank was not restored")
	if String(Game.challenges.get("active", {}).get("id", "")) != "firstProfit":
		failures.append("challenge was not restored")
	if int(Game.exchange.state["account"]["positions"].get("MKT", {}).get("qty", 0)) != 5:
		failures.append("ETF position was not restored")
	if Game.exchange.state["account"]["futures"].size() != 2:
		failures.append("futures positions were not restored")
	if Game.bond_rows().size() != 1 or Game.fx_rows().size() != 1 \
			or Game.commodity_rows().size() != 1 or Game.crypto_rows().size() != 1:
		failures.append("multi-asset positions were not restored")
	var restored_history: Dictionary = Game.history.run("2008-crisis")
	if restored_history.is_empty() \
			or int(restored_history["account"]["positions"].get("AAPL", {}).get("qty", 0)) != 10:
		failures.append("history run was not restored")
	main.navigate("portfolio")
	await get_tree().process_frame
	await get_tree().process_frame

	# Consume any milestone story that queued during the long integration run.
	for i in 40:
		if not Game.narrative.is_active():
			break
		var queued_view: Dictionary = Game.narrative.current_view()
		if String(queued_view.get("type", "")) == "choice":
			Game.narrative.choose(0)
		else:
			Game.narrative.advance()

	if bool(Game.narrative.seen.get("client_trust", false)) \
			and Game.fund.get("clients", []).size() <= fund_clients_before:
		failures.append("client trust did not create a real fund client")
	if bool(Game.narrative.seen.get("client_trust", false)):
		var clients_before_retry: int = Game.fund.get("clients", []).size()
		Game.story_add_fund_client("王先生", 50000.0, "client_trust", "low")
		if Game.fund.get("clients", []).size() != clients_before_retry:
			failures.append("story client subscription was not idempotent")

	# Full-day fast-forward runs in chunks so the UI stays responsive.
	Game.step_day()
	for i in 1200:
		await get_tree().process_frame
		if not Game.is_fast_forwarding():
			break
	if Game.is_fast_forwarding():
		failures.append("fast-forward did not finish")
	if Game.get_day() != day_before + 1:
		failures.append("fast-forward did not advance one day")
	var review: Dictionary = Game.intro["review"]
	if review.get("day") != day_before or not review.has("cashPct") or not review.has("fees") \
			or not review.has("firstTradePnl"):
		failures.append("first fill did not produce a session close review")
	for i in 12:
		if not Game.narrative.is_active():
			break
		var view: Dictionary = Game.narrative.current_view()
		if String(view.get("type", "")) == "choice":
			Game.narrative.choose(0)
		else:
			Game.narrative.advance()
	Game.set_intro_exit_outcome("notTriggered")
	Game.finish_intro_review()
	if Game.has_intro_task() or not bool(Game.intro.get("complete", false)):
		failures.append("close review did not complete the task")
	if Game.intro["review"].get("exitOutcome") != "notTriggered":
		failures.append("close review did not keep the player's exit assessment")
	await _check_opening_gap(main, failures)
	await _check_black_friday(main, failures)
	main.navigate("portfolio")
	await get_tree().process_frame
	await get_tree().process_frame

	main.navigate("portfolio")
	await get_tree().process_frame
	await get_tree().process_frame

	# Sandbox runs on a separate book and restores the career save on exit.
	var career_day := Game.get_day()
	var sandbox_start: Dictionary = Game.start_sandbox(50000.0, "sandbox-it", "hard")
	if not bool(sandbox_start.get("ok", false)):
		failures.append("sandbox did not start")
	if not Game.sandbox_mode:
		failures.append("sandbox flag missing")
	if absf(Game.exchange.fee_bps - 3.0) > 0.001:
		failures.append("sandbox difficulty did not change commission")
	if absf(float(Game.exchange.state["account"]["cash"]) - 50000.0) > 0.01:
		failures.append("sandbox cash not applied")
	Game.exit_sandbox()
	await get_tree().process_frame
	if Game.sandbox_mode:
		failures.append("sandbox did not exit")
	if Game.get_day() != career_day:
		failures.append("career day changed after sandbox")
	if String(Game.fund.get("status", "none")) != "active":
		failures.append("career fund was not restored after sandbox")

	# Sweep every teaching demo and quiz dialog so missing fields or signals
	# surface even when a flow is not covered above.
	main.navigate("academy")
	await get_tree().process_frame
	academy_screen = main._screens["academy"]
	for demo_id in SmaDemoDialog.SUPPORTED:
		academy_screen._open_demo(String(demo_id))
		await get_tree().process_frame
		var sweep_demo: SmaDemoDialog = null
		for child in main.get_children():
			if child is SmaDemoDialog:
				sweep_demo = child
		if sweep_demo == null:
			failures.append("demo did not open: %s" % demo_id)
			continue
		sweep_demo._close()
		await get_tree().process_frame
	for unit in SmaAcademy.units():
		var unit_id := String(unit.get("id", ""))
		if unit_id == "" or SmaAcademy.build_quiz(unit_id, 1).is_empty():
			continue
		academy_screen._open_quiz(unit_id)
		await get_tree().process_frame
		var sweep_quiz: SmaQuizDialog = null
		for child in main.get_children():
			if child is SmaQuizDialog:
				sweep_quiz = child
		if sweep_quiz == null:
			failures.append("quiz did not open: %s" % unit_id)
			continue
		sweep_quiz._close()
		await get_tree().process_frame

	main.navigate("fund")
	await get_tree().process_frame
	var fund_screen = main._screens["fund"]
	fund_screen._run_optimizer()
	await get_tree().process_frame
	if fund_screen._optimizer.is_empty():
		failures.append("fund optimizer did not produce weights")
	else:
		fund_screen._apply_optimizer()
		await get_tree().process_frame

	main.navigate("replay")
	await get_tree().process_frame
	var replay_screen = main._screens["replay"]
	replay_screen._previous()
	replay_screen._next()
	replay_screen._latest()
	await get_tree().process_frame
	if replay_screen._selected_day < 0 \
			or Game.replay_snapshot(replay_screen._selected_day).is_empty():
		failures.append("replay snapshot did not render")

	main.navigate("statements")
	await get_tree().process_frame
	var statements_screen = main._screens["statements"]
	var statement_history: Array = Game.statement_history(statements_screen._ticker, 8)
	if statement_history.size() > 1:
		statements_screen._quarter_index = 1
		statements_screen.refresh()
		await get_tree().process_frame
	if statements_screen._quarter_index >= statement_history.size():
		failures.append("statement quarter selection is out of range")

	main.navigate("screener")
	await get_tree().process_frame
	var screener_screen = main._screens["screener"]
	var all_screener_rows: int = screener_screen._rows.size()
	if all_screener_rows <= 0:
		failures.append("screener did not render any rows")
	screener_screen._pe_spin.value = 20.0
	screener_screen._apply()
	if screener_screen._rows.size() >= all_screener_rows:
		failures.append("screener P/E filter did not narrow the results")
	screener_screen._reset()
	if screener_screen._rows.size() != all_screener_rows:
		failures.append("screener reset did not restore all rows")

	main.navigate("earnings")
	await get_tree().process_frame
	var earnings_screen = main._screens["earnings"]
	if earnings_screen._ticker_option == null or earnings_screen._selected_ticker == "":
		failures.append("earnings center did not render the company selector")
	else:
		earnings_screen._on_ticker_changed(1)
		var research_ticker: String = earnings_screen._selected_ticker
		Game.set_chart_timeframe("1W")
		earnings_screen._go_trade()
		await get_tree().process_frame
		if main._current_screen != "trade" or Game.selected_ticker != research_ticker \
				or main._screens["trade"]._timeframe != "1W":
			failures.append("research ticker and timeframe did not reach the trade desk")
		main.navigate("earnings")
		if earnings_screen._selected_ticker != research_ticker:
			failures.append("returning to earnings lost the research selection")

	main.navigate("history")
	await get_tree().process_frame
	var sweep_history = main._screens["history"]
	for scenario_id in ["2008-crisis", "2015-long", "2020-covid", "2022-hikes"]:
		await sweep_history._start_scenario(scenario_id)
		await get_tree().process_frame
		if sweep_history._dataset.is_empty():
			failures.append("history scenario did not load: %s" % scenario_id)
			continue
		sweep_history._advance_day()
		await get_tree().process_frame

	if not SmaDisplay.MODES.has(String(Game.settings.get("displayMode", ""))):
		failures.append("stored display mode is not supported")
	if not SmaDisplay.PRESETS.has(String(Game.settings.get("windowPreset", ""))):
		failures.append("stored window preset is not supported")

	for preset in SmaDisplay.PRESETS:
		Game.set_window_preset(preset)
		if String(Game.settings.get("windowPreset", "")) != preset:
			failures.append("window preset did not persist: %s" % preset)
	Game.set_window_preset("bogus")
	if String(Game.settings.get("windowPreset", "")) != "auto":
		failures.append("invalid window preset did not fall back to auto")

	for mode in SmaDisplay.MODES:
		Game.set_display_mode(mode)
		if String(Game.settings.get("displayMode", "")) != mode:
			failures.append("display mode did not persist: %s" % mode)
	Game.set_display_mode("bogus")
	if String(Game.settings.get("displayMode", "")) != "windowed":
		failures.append("invalid display mode did not fall back to windowed")

	Game.set_display_mode("fullscreen")
	for preset in SmaDisplay.PRESETS:
		Game.set_window_preset(preset)
		if String(Game.settings.get("displayMode", "")) != "fullscreen":
			failures.append("preset changes escaped fullscreen: %s" % preset)

	if DisplayServer.get_name() != "headless" \
			and OS.get_environment("SMA_KEEP_WINDOW") != "1":
		await get_tree().process_frame
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
			failures.append("fullscreen mode was not applied to the window")
		Game.set_display_mode("windowed")
		await get_tree().process_frame
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
			failures.append("windowed mode was not restored")
		if Game.get_window().min_size != SmaDisplay.MIN_SIZE:
			failures.append("window minimum size was not applied")

	Game.set_display_mode("windowed")
	Game.set_window_preset("auto")

	if DisplayServer.get_name() == "headless":
		var window := get_window()
		var original_size := window.size
		var original_scale := window.content_scale_factor
		var original_locale: String = I18n.locale
		I18n.set_locale("en")
		window.size = Vector2i(2560, 1600)
		window.content_scale_factor = 1.25
		main.navigate("trade")
		for frame in 3:
			await get_tree().process_frame
		var compact_trade: SmaTradeScreen = main._screens["trade"]
		var compact_actions := main._speed_picker.get_parent() as Control
		if not main._nav_menu.visible or main._sidebar.visible or not main._speed_picker.visible:
			failures.append("compact layout did not switch to navigation and speed menus")
		if compact_actions.get_global_rect().end.x > main.size.x + 1.0 \
				or compact_trade._submit_button.get_global_rect().end.x > main.size.x + 1.0:
			failures.append("125% English layout clips actions or the order ticket")
		window.size = original_size
		window.content_scale_factor = original_scale
		I18n.set_locale(original_locale)

	_check_live_trade_clock(main, failures)
	await _check_pixel_beta10(main, failures)

	if failures.is_empty():
		print("INTEGRATION OK equity=%.2f day=%d stories=%d" % [
			Game.get_equity(), Game.get_day(), Game.narrative.stories.size()])
		SmaSaveService.clear(Game.save_path)
		Game.save_path = SmaSaveService.SAVE_PATH
		get_tree().quit(0)
	else:
		for failure in failures:
			printerr("INTEGRATION FAIL: ", failure)
		SmaSaveService.clear(Game.save_path)
		Game.save_path = SmaSaveService.SAVE_PATH
		get_tree().quit(1)


func _check_pixel_beta10(main: SmaMain, failures: Array[String]) -> void:
	Game.set_theme("pixel")
	for frame in 2:
		await get_tree().process_frame
	if main._office_banner == null or main._pixel_fx == null:
		failures.append("pixel theme did not mount SmaPixelOfficeBanner and SmaPixelFx")
		return
	main.navigate("trade")
	var trade_scr: SmaTradeScreen = main._screens["trade"]
	if trade_scr._px_step_toggle == null or not trade_scr._px_step_toggle.visible:
		failures.append("trade screen missing visible StepPX toggle in pixel mode")
	else:
		trade_scr._px_step_toggle.button_pressed = false
		if trade_scr._chart.pixel_stepped or bool(Game.settings.get("chartPixelStepped", true)):
			failures.append("StepPX toggle did not disable chart.pixel_stepped")
		trade_scr._px_step_toggle.button_pressed = true
		if not trade_scr._chart.pixel_stepped or not bool(Game.settings.get("chartPixelStepped", false)):
			failures.append("StepPX toggle did not restore chart.pixel_stepped")

	var banner := main._office_banner
	banner.size = Vector2(1180, 118)
	if String(banner._hit_test(Vector2(1180 - 40, 118 - 32)).get("zone", "")) != "mentor":
		failures.append("office banner right avatar did not hit mentor hotspot")
	if String(banner._hit_test(Vector2(30, 60)).get("zone", "")) != "honors":
		failures.append("office banner left plaque did not hit honors hotspot")
	var ticker_hit := banner._hit_test(Vector2(520, 12))
	if String(ticker_hit.get("zone", "")) != "ticker" or String(ticker_hit.get("ticker", "")) == "":
		failures.append("office banner LED strip did not hit ticker hotspot")
	if String(banner._hit_test(Vector2(210, 80)).get("zone", "")) != "coffee":
		failures.append("office banner player desk did not hit coffee hotspot")

	for mode in ["mentor", "honors"]:
		main._on_office_hotspot(mode, {"mentor": "lin_lan"})
		await get_tree().process_frame
		var found_popup: SmaOfficePopupDialog = null
		for child in main.get_children():
			if child is SmaOfficePopupDialog:
				found_popup = child
				break
		if found_popup == null:
			failures.append("office hotspot '%s' did not open SmaOfficePopupDialog" % mode)
		else:
			found_popup._close()
			await get_tree().process_frame


func _check_live_trade_clock(main: SmaMain, failures: Array[String]) -> void:
	main.navigate("trade")
	Game.set_chart_timeframe("1m")
	Game.set_speed(1)
	Game.set_paused(false)
	Game._accum = 0.0
	var original_second := int(Game.exchange.state["second"])
	var remaining := mini(62, SmaExchange.SESSION_SECONDS - 1 - original_second)
	var chart: SmaCandleChart = main._screens["trade"]._chart
	var previous_price := float(chart.candles.back()["c"])
	for elapsed in range(1, remaining + 1):
		for frame in 16:
			Game._process(1.0 / 16.0)
		var second := original_second + elapsed
		if int(Game.exchange.state["second"]) != second \
				or main._clock_label.text != SmaCalendar.session_clock(second):
			failures.append("1× clock did not display simulated second %d" % second)
			break
		var expected_bars := SmaMinuteSeries.minute_index_for_second(second) + 1
		if chart.candles.size() != expected_bars \
				or not chart.title_text.ends_with(I18n.t("chart.nextMinute", {"seconds": 60 - second % 60})):
			failures.append("1m chart went out of sync at simulated second %d" % second)
			break
		var price := float(chart.candles.back()["c"])
		if price == previous_price:
			failures.append("1m candle price stayed flat at simulated second %d" % second)
			break
		previous_price = price
	Game.set_paused(true)
	var paused_time := main._clock_label.text
	var paused_bar: Dictionary = chart.candles.back().duplicate()
	Game._process(2.0)
	if main._clock_label.text != paused_time or chart.candles.back() != paused_bar:
		failures.append("pausing did not freeze the live clock and candle")


func _check_trade_language_draft(main: SmaMain, failures: Array[String]) -> void:
	var ticket: SmaTradeScreen = main._screens["trade"]
	var original := ticket.capture_draft()
	var locale: String = I18n.locale
	ticket._on_side("sell")
	# Before u19/s1 is read, selecting stop should remain blocked at market.
	ticket._on_type("stop")
	if ticket._order_type != "market":
		failures.append("locked stop order type should not activate before u19/s1")
	ticket._qty.get_line_edit().text = "27"
	I18n.toggle()
	ticket = main._screens["trade"]
	var side := ticket._side_group.get_pressed_button()
	var order_type := ticket._type_group.get_pressed_button()
	if ticket._qty.value != 27 \
			or side == null or side.text != I18n.t("trade.sell") \
			or order_type == null or order_type.text != I18n.t("trade.market"):
		failures.append("language switch discarded the trade order draft")
	I18n.set_locale(locale)
	ticket = main._screens["trade"]
	ticket.restore_draft(original)


func _check_trade_stop_language_draft(main: SmaMain, failures: Array[String]) -> void:
	var ticket: SmaTradeScreen = main._screens["trade"]
	var original := ticket.capture_draft()
	var locale: String = I18n.locale
	ticket._on_side("sell")
	ticket._on_type("stop")
	# Leave the edits in the LineEdits, as when the player switches without pressing Enter.
	ticket._qty.get_line_edit().text = "27"
	ticket._stop_price.get_line_edit().text = "41.25"
	I18n.toggle()
	ticket = main._screens["trade"]
	var side := ticket._side_group.get_pressed_button()
	var order_type := ticket._type_group.get_pressed_button()
	if ticket._qty.value != 27 or ticket._stop_price.value != 41.25 \
			or side == null or side.text != I18n.t("trade.sell") \
			or order_type == null or order_type.text != I18n.t("trade.stop") \
			or not ticket._stop_row.visible:
		failures.append("language switch discarded the unlocked stop trade order draft")
	I18n.set_locale(locale)
	ticket = main._screens["trade"]
	ticket.restore_draft(original)


func _check_opening_gap(main: SmaMain, failures: Array[String]) -> void:
	# Earlier checks can leave several queued story scenes after the close.
	for line in 128:
		if not Game.narrative.is_active():
			break
		if Game.narrative.current_view().get("type") == "choice":
			Game.narrative.choose(0)
		else:
			Game.narrative.advance()
	var legacy := SmaSaveService.read(Game.save_path)
	legacy.erase("openingGap")
	if Game._decode_save(legacy).is_empty():
		failures.append("a completed beta-02.1 save could not unlock the new chapter")
	main.navigate("dashboard")
	var entry := main.find_child("OpeningGapEntry", true, false) as Button
	if entry == null or entry.disabled or entry.focus_mode != Control.FOCUS_ALL:
		failures.append("dashboard did not offer a keyboard-accessible assessment entry")
		return
	Game.set_paused(false)
	var career: Dictionary = JSON.parse_string(JSON.stringify(Game.exchange.to_dict()))
	entry = main.find_child("OpeningGapEntry", true, false) as Button
	entry.pressed.emit()
	if not Game.opening_gap_active or main._current_screen != "opening_gap":
		failures.append("opening-gap entry did not navigate to the chapter")
		return
	Game._process(3.0)
	Game.step_minute()
	if JSON.parse_string(JSON.stringify(Game.exchange.to_dict())) != career or main._topbar.visible:
		failures.append("the chapter did not suspend the career clock and controls")
	main.navigate("dashboard")
	if Game.paused or Game.opening_gap_active:
		failures.append("leaving the chapter did not preserve the running clock")
	Game.set_paused(true)
	main.navigate("opening_gap")
	if not Game.apply_opening_gap(0, GapStage.BRIEFING, "advance") \
			or not _resume_gap(main, GapStage.OPEN):
		failures.append("opening quotes could not be resumed")
		return

	var saved_path := Game.save_path
	Game.save_path = saved_path.path_join("invalid-slot.json")
	var failed_order := Game.apply_opening_gap(0, GapStage.OPEN, "confirm", "buy")
	Game.save_path = saved_path
	if failed_order or Game.opening_gap["attempts"][0]["stage"] != GapStage.OPEN:
		failures.append("a failed write consumed the opening decision")
	var screen: SmaOpeningGapScreen = main._screens["opening_gap"]
	var buy := screen.find_child("Choice_buy", true, false) as Button
	var confirm := screen.find_child("ConfirmDecision", true, false) as Button
	if buy == null or confirm == null or confirm.visible or buy.focus_mode != Control.FOCUS_ALL:
		failures.append("opening decision controls did not render correctly")
		return
	buy.button_pressed = true
	buy.pressed.emit()
	if not confirm.visible or confirm.focus_mode != Control.FOCUS_ALL:
		failures.append("the preview did not enable keyboard confirmation")
	I18n.toggle()
	screen = main._screens["opening_gap"]
	buy = screen.find_child("Choice_buy", true, false) as Button
	confirm = screen.find_child("ConfirmDecision", true, false) as Button
	if buy == null or not buy.button_pressed or confirm == null or not confirm.visible \
			or Game.opening_gap["attempts"][0]["stage"] != GapStage.OPEN:
		failures.append("language switch discarded or submitted the opening decision draft")
		return
	confirm.pressed.emit()
	if Game.apply_opening_gap(0, GapStage.OPEN, "confirm", "sell") \
			or not _resume_gap(main, GapStage.DECIDED):
		failures.append("confirmed decision was not persisted exactly once")
		return
	if not Game.apply_opening_gap(0, GapStage.DECIDED, "advance") \
			or not _resume_gap(main, GapStage.INTRADAY) \
			or not Game.apply_opening_gap(0, GapStage.INTRADAY, "advance") \
			or not _resume_gap(main, GapStage.CLOSED):
		failures.append("the intraday or close reveal could not be resumed")
		return
	var review := main.find_child("Reflection", true, false) as LineEdit
	var outcome := main.find_child("ExitOutcome", true, false) as OptionButton
	if review == null or outcome == null:
		failures.append("the closing reflection or exit-condition assessment was not displayed")
		return
	outcome.select(1)
	var draft_text := "Adding at the open used more cash and crossed my risk budget."
	review.text = draft_text
	I18n.toggle()
	review = main.find_child("Reflection", true, false) as LineEdit
	outcome = main.find_child("ExitOutcome", true, false) as OptionButton
	var submit_review := main.find_child("SaveReflection", true, false) as Button
	if review == null or review.text != draft_text or outcome == null or outcome.selected != 1 \
			or submit_review == null or submit_review.disabled:
		failures.append("language switch discarded the opening-gap review draft")
		return
	review.text_submitted.emit(review.text)
	if not SmaOpeningGap.is_complete(Game.opening_gap) \
			or not Game.apply_opening_gap(0, GapStage.REVIEWED, "compare") \
			or not Game.apply_opening_gap(1, GapStage.BRIEFING, "advance") \
			or not Game.apply_opening_gap(1, GapStage.OPEN, "confirm", "hold") \
			or not Game.apply_opening_gap(1, GapStage.DECIDED, "advance") \
			or not Game.apply_opening_gap(1, GapStage.INTRADAY, "advance") \
			or not _resume_gap(main, GapStage.CLOSED):
		failures.append("the comparison was not playable or persisted")
		return
	if Game.opening_gap["attempts"][0]["action"] != "buy" \
			or Game.opening_gap["attempts"][0]["exitOutcome"] != "triggered" \
			or Game.opening_gap["attempts"][1]["action"] != "hold" \
			or JSON.parse_string(JSON.stringify(Game.exchange.to_dict())) != career:
		failures.append("the comparison changed the first result or the career account")
	await _check_gap_layout(main, failures)
	main.navigate("dashboard")


func _resume_gap(main: SmaMain, expected: int) -> bool:
	if not Game.load_game() or Game.opening_gap.is_empty():
		return false
	main.navigate("opening_gap")
	return Game.opening_gap_active and Game.opening_gap["attempts"].back()["stage"] == expected


func _check_gap_layout(main: SmaMain, failures: Array[String]) -> void:
	var window := get_window()
	var original_size := window.size
	var original_scale := window.content_scale_factor
	var original_locale: String = I18n.locale
	for locale in ["zh_CN", "en"]:
		I18n.set_locale(locale)
		for resolution in [Vector2i(1280, 800), Vector2i(1920, 1200), Vector2i(2560, 1600)]:
			window.size = resolution
			window.content_scale_factor = SmaDisplay.resolve_ui_scale("1.25", resolution)
			for frame in 3:
				await get_tree().process_frame
			var screen: SmaOpeningGapScreen = main._screens["opening_gap"]
			if screen._splits.size() != 2 or screen._body.get_global_rect().end.x > screen.get_global_rect().end.x + 1.0:
				failures.append("comparison layout clips at %s (%s)" % [resolution, locale])
	window.size = original_size
	window.content_scale_factor = original_scale
	I18n.set_locale(original_locale)


func _check_black_friday(main: SmaMain, failures: Array[String]) -> void:
	Game.set_player_name("林小望")
	if Game.display_player_name() != "林小望":
		failures.append("custom trainee name did not apply")
	var obj: Dictionary = Game.current_objective()
	if String(obj.get("title", "")).is_empty() or String(obj.get("target", "")).is_empty():
		failures.append("global objective tracker returned empty objective")
	if Game.side_comments().is_empty():
		failures.append("expected at least one non-blocking mentor side-comment")
	if not Game.black_friday_unlocked():
		failures.append("black friday campaign should unlock when fund is active")
		return
	main.navigate("black_friday")
	await get_tree().process_frame
	if not Game.black_friday_active or Game.black_friday.is_empty():
		failures.append("black friday campaign did not enter cleanly")
		return
	var BfStage := SmaBlackFriday.Stage
	if not Game.apply_black_friday(0, BfStage.BRIEFING, "advance") \
			or not Game.apply_black_friday(0, BfStage.OPEN_0930, "confirm_open", "protect") \
			or not Game.apply_black_friday(0, BfStage.AFTER_0930, "advance") \
			or not Game.apply_black_friday(0, BfStage.CRUNCH_1100, "confirm_crunch", "protect") \
			or not Game.apply_black_friday(0, BfStage.AFTER_1100, "advance") \
			or not Game.apply_black_friday(0, BfStage.CLOSED, "review",
				"Liquidity buffers must be planned before panic strikes."):
		failures.append("black friday attempt 1 could not complete")
		return
	if String(Game.narrative.flags.get("crisis_choice", "")) != "protect":
		failures.append("black friday attempt 1 did not write crisis_choice into narrative flags")
	if not Game.apply_black_friday(0, BfStage.REVIEWED, "compare") \
			or not Game.apply_black_friday(1, BfStage.BRIEFING, "advance") \
			or not Game.apply_black_friday(1, BfStage.OPEN_0930, "confirm_open", "gate") \
			or not Game.apply_black_friday(1, BfStage.AFTER_0930, "advance") \
			or not Game.apply_black_friday(1, BfStage.CRUNCH_1100, "confirm_crunch", "gate") \
			or not Game.apply_black_friday(1, BfStage.AFTER_1100, "advance"):
		failures.append("black friday comparison attempt 2 failed")
		return
	if not Game.load_game() or not SmaBlackFriday.is_complete(Game.black_friday) \
			or Game.display_player_name() != "林小望":
		failures.append("black friday state or playerName did not survive save/load")
	var report := Game.graduation_report()
	if String(report.get("playerName", "")) != "林小望" or float(report.get("equity", 0.0)) <= 0.0:
		failures.append("graduation report card did not compute expected fields")
	var report_path := Game.save_path.get_basename() + "-report.json"
	if not Game.export_graduation_report(report_path) \
			or SmaSaveService.import_from(report_path).get("playerName", "") != "林小望":
		failures.append("graduation report JSON export failed")
	SmaSaveService.clear(report_path)
	# Verify tabbed dense screens render cleanly across all tabs.
	main.navigate("fund")
	await get_tree().process_frame
	var fund_screen: SmaFundScreen = main._screens["fund"]
	for tab in ["overview", "quant", "clients", "risk"]:
		fund_screen._active_tab = tab
		fund_screen.refresh("tab")
		if fund_screen._body.get_child_count() == 0:
			failures.append("fund tab did not render: %s" % tab)
	main.navigate("career")
	await get_tree().process_frame
	var career_screen: SmaCareerScreen = main._screens["career"]
	for tab in ["promotion", "tasks", "certs"]:
		career_screen._active_tab = tab
		career_screen.refresh("tab")
		if career_screen._body.get_child_count() == 0:
			failures.append("career tab did not render: %s" % tab)
	main.navigate("multiasset")
	await get_tree().process_frame
	var ma_screen: SmaMultiAssetScreen = main._screens["multiasset"]
	for tab in ["bonds", "fx", "commodities", "crypto"]:
		ma_screen._active_tab = tab
		ma_screen.refresh("tab")
		if ma_screen._body.get_child_count() == 0:
			failures.append("multiasset tab did not render: %s" % tab)
	main.navigate("dashboard")
	await get_tree().process_frame
