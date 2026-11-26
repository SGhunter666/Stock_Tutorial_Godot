## Application composition root. Owns the exchange, the story runner, the
## simulation clock and the save slot. UI code only calls these actions and
## listens to signals; it never mutates the account or market directly.
extends Node

signal state_changed(reason: String)
signal tick
signal day_closed(day: int)
signal trade_filled(trade: Dictionary)
signal order_rejected(error_key: String)
signal story_changed
signal toast_requested(message: String)
signal game_started
signal game_loaded
signal game_saved
signal fast_forward_started
signal fast_forward_progress(value: float)
signal fast_forward_finished
signal academy_changed
signal layout_changed
signal theme_changed
signal achievement_unlocked(achievement_ids: Array)
signal margin_call_triggered
signal career_promoted(rank: int)
signal challenge_finished(status: String, challenge_id: String)
signal price_alert_triggered(count: int)

const SAVE_VERSION := 1
const DEFAULT_SEED := "academy-2026"
const START_CASH := 100000.0
const SPEEDS := [1, 5, 10, 30, 60]
const AUTOSAVE_SECONDS := 20.0
const MAX_STEPS_PER_FRAME := 240
const INTRO_TICKER := "APLA"
const INTRO_CASH_TARGET := 40.0
const DAILY_RECORDS_PATH := "user://saves/daily_records.json"

var exchange: SmaExchange = null
var narrative: SmaStoryService = null
var academy: Dictionary = {}
var history: SmaHistoryService = null
var challenges: Dictionary = SmaChallenges.create_state()
var career: Dictionary = SmaCareer.create_state()
var quant: Dictionary = SmaQuant.default_config()
var fund: Dictionary = SmaFund.create_state()
var alerts: Dictionary = SmaAlerts.create_state()
var office: Dictionary = SmaOffice.create_state()
var daily_sprint_active := false
var daily_sprint_code := ""
var daily_records: Array = []
var intro: Dictionary = {}
var opening_gap: Dictionary = {}
var opening_gap_active := false
var black_friday: Dictionary = {}
var black_friday_active := false
var started := false
var paused := true
var speed := 1
var selected_ticker := "APLA"
var settings := {"locale": "zh_CN", "speed": 1, "layout": "beginner",
	"theme": "pixel", "pixelMigrated": true, "showPixelOffice": true,
	"chartPixelStepped": true,
	"colorScheme": "intl", "playerName": "", "displayMode": "windowed",
	"windowPreset": "auto", "uiScale": "auto",
	"masterVolume": 0.8, "musicVolume": 0.22, "sfxVolume": 0.75, "muted": false}
var sandbox_mode := false
var sandbox_config := {"cash": 100000.0, "seed": "sandbox-2026",
	"difficulty": "normal", "commission": 1.0}
var last_error := ""
var active_slot := 1
var save_path := SmaSaveService.SAVE_PATH
var _keep_save_backup := false

var _accum := 0.0
var _ui_accum := 0.0
var _autosave_accum := 0.0
var _last_day := 0
var _last_call_id := ""
var _story_pause := false
var _fast_forward_remaining := 0
var _fast_forward_total := 1
var _fast_forward_active := false


func _ready() -> void:
	I18n.set_locale(String(settings.get("locale", "zh_CN")))
	SmaUiTheme.set_theme_mode(String(settings.get("theme", "pixel")))
	SmaUiTheme.set_color_scheme(String(settings.get("colorScheme", "intl")))
	_apply_layout(String(settings.get("layout", "beginner")))
	_apply_audio_settings()
	if DisplayServer.get_name() != "headless":
		apply_display()
	academy = SmaAcademy.create_state()
	history = SmaHistoryService.new()
	var saved_daily := SmaSaveService.read(DAILY_RECORDS_PATH)
	daily_records = SmaDailyChallenge.normalize_records(saved_daily.get("records", []))


func _process(delta: float) -> void:
	if not started or exchange == null or opening_gap_active or black_friday_active:
		return
	if _fast_forward_active:
		_process_fast_forward()
		return
	if paused or _story_pause:
		return
	_accum += delta * float(speed)
	_ui_accum += delta
	_autosave_accum += delta
	var steps := int(_accum)
	if steps <= 0:
		return
	_accum -= float(steps)
	_accum = minf(_accum, float(MAX_STEPS_PER_FRAME))
	_advance_steps(mini(steps, MAX_STEPS_PER_FRAME))
	if _ui_accum >= 0.08:
		_ui_accum = 0.0
		tick.emit()
	if _autosave_accum >= AUTOSAVE_SECONDS:
		_autosave_accum = 0.0
		save_game(false)


# ---------------------------------------------------------------------------
# Game lifecycle
# ---------------------------------------------------------------------------

func new_game(seed_value: String = DEFAULT_SEED) -> void:
	if not started and SmaSaveService.exists(save_path + ".bak"):
		_keep_save_backup = _decode_save(SmaSaveService.read(save_path)).is_empty()
	sandbox_mode = false
	daily_sprint_active = false
	daily_sprint_code = ""
	exchange = SmaExchange.new(seed_value, START_CASH)
	academy = SmaAcademy.create_state()
	history = SmaHistoryService.new()
	challenges = SmaChallenges.create_state()
	career = SmaCareer.create_state()
	quant = SmaQuant.default_config()
	fund = SmaFund.create_state()
	alerts = SmaAlerts.create_state()
	office = SmaOffice.create_state()
	intro = {"plan": {}, "receipt": {}, "review": {}, "complete": false}
	opening_gap = {}
	opening_gap_active = false
	black_friday = {}
	black_friday_active = false
	narrative = SmaStoryService.new()
	narrative.setup(self)
	narrative.load_content()
	_connect_narrative()
	started = true
	paused = false
	speed = 1
	settings["speed"] = 1
	settings["locale"] = I18n.locale
	settings["chartTimeframe"] = "1m"
	selected_ticker = INTRO_TICKER
	_last_day = 0
	_last_call_id = ""
	_story_pause = false
	_accum = 0.0
	_ui_accum = 0.0
	_autosave_accum = 0.0
	game_started.emit()
	state_changed.emit("new_game")
	narrative.handle_event("game_new", {})
	save_game(false)


func _connect_narrative() -> void:
	if narrative == null:
		return
	narrative.story_started.connect(_on_story_started)
	narrative.story_finished.connect(_on_story_finished)
	narrative.view_changed.connect(_on_story_view_changed)


func _on_story_started(_story_id: String) -> void:
	_story_pause = true
	story_changed.emit()
	state_changed.emit("story_started")


func _on_story_finished(story_id: String) -> void:
	_story_pause = narrative != null and narrative.is_active()
	story_changed.emit()
	state_changed.emit("story_finished")
	if story_id in ["opening", "first_trade", "day_one"] and not sandbox_mode:
		save_game.call_deferred(false)


func _on_story_view_changed() -> void:
	story_changed.emit()


func restart() -> void:
	new_game(DEFAULT_SEED)


# ---------------------------------------------------------------------------
# Simulation clock
# ---------------------------------------------------------------------------

func _advance_steps(steps: int, sample_quotes: bool = true) -> void:
	if exchange == null or steps <= 0:
		return
	var fills: Array = []
	var call_before := _current_call_id()
	for index in steps:
		if int(exchange.state["second"]) == SmaExchange.SESSION_SECONDS - 1:
			_record_intro_close()
		exchange.advance_second(sample_quotes)
		_check_price_alerts()
		if not exchange.last_player_fills.is_empty():
			for fill in exchange.last_player_fills:
				_record_intro_fill(fill)
			fills.append_array(exchange.last_player_fills)
	for fill in fills:
		_emit_trade_fill(fill)
	var day_after := int(exchange.state["dayIndex"])
	if day_after != _last_day:
		_last_day = day_after
		day_closed.emit(day_after)
		var early_assignments: Array = exchange.state.get("earlyAssignments", [])
		if not early_assignments.is_empty():
			toast_requested.emit(I18n.t("toast.optionAssignedEarly", {
				"count": early_assignments.size(),
				"ticker": String(early_assignments[0].get("ticker", ""))}))
			exchange.state["earlyAssignments"] = []
		var paid := 0.0
		var paid_count := 0
		var owed := 0.0
		var owed_count := 0
		for entry in exchange.state["account"].get("dividends", []):
			if int(entry.get("day", -1)) != day_after:
				continue
			var amount := float(entry.get("amount", 0.0))
			if amount >= 0.0:
				paid += amount
				paid_count += 1
			else:
				owed += -amount
				owed_count += 1
		if paid_count > 0:
			toast_requested.emit(I18n.t("toast.dividendPaid", {
				"amount": SmaFormat.money(paid), "count": paid_count}))
		if owed_count > 0:
			toast_requested.emit(I18n.t("toast.dividendOwed", {
				"amount": SmaFormat.money(owed), "count": owed_count}))
		var earnings_count := 0
		for item in exchange.news_today():
			if String(item.get("kind", "")) == "earnings":
				earnings_count += 1
		if earnings_count > 0:
			toast_requested.emit(I18n.t("toast.earningsToday", {
				"count": earnings_count}))
		if narrative != null:
			narrative.handle_event("day_closed", {"day": day_after})
		save_game(false)
		academy_sync_practice()
		_check_challenges()
		_advance_career()
		_advance_fund()
		if daily_sprint_active and day_after >= SmaDailyChallenge.SPRINT_DAYS:
			paused = true
			var sprint_res := record_daily_sprint()
			toast_requested.emit(I18n.t("daily.completedToast", {
				"code": daily_sprint_code,
				"grade": String(sprint_res.get("grade", "B")),
				"score": int(sprint_res.get("score", 1000)),
			}))
	var call_after := _current_call_id()
	if call_after != call_before and not call_after.is_empty():
		toast_requested.emit(I18n.t("toast.margin_call"))
		margin_call_triggered.emit()
		if narrative != null:
			narrative.handle_event("margin_call", {"id": call_after})
	if not fills.is_empty():
		state_changed.emit("trade")
		academy_sync_practice()


func _emit_trade_fill(fill: Dictionary) -> void:
	trade_filled.emit(fill)
	if narrative != null:
		narrative.handle_event("trade_filled", fill)
		if fill.get("side") == "short" or fill.get("action") == "openShort":
			narrative.handle_event("short_opened", fill)
	if String(fill.get("action", "")) == "closeLong" and float(fill.get("realized", 0.0)) > 0.0:
		_push_side_comment("note_tax", "story.char.su_he.name", "note.taxProfit")
	if SmaEtfs.is_etf(String(fill.get("ticker", ""))):
		_push_side_comment("note_etf", "story.char.lin_lan.name", "note.etfCore")


func has_intro_task() -> bool:
	return not intro.is_empty() and not bool(intro.get("complete", false))


func set_intro_plan(reason: String, exit_rule: String, max_loss: float) -> bool:
	if not has_intro_task() or not intro["review"].is_empty():
		return false
	var existing: Dictionary = intro["plan"]
	if not intro["receipt"].is_empty() and bool(existing.get("beforeFill", false)):
		return false
	reason = reason.strip_edges().left(180)
	exit_rule = exit_rule.strip_edges().left(180)
	if reason.is_empty() or exit_rule.is_empty() or not is_finite(max_loss) or max_loss <= 0.0:
		return false
	intro["plan"] = {"reason": reason, "exitRule": exit_rule, "maxLoss": max_loss,
		"beforeFill": intro["receipt"].is_empty()}
	save_game(false)
	state_changed.emit("intro")
	return true


func finish_intro_review() -> void:
	if not has_intro_task() or intro["review"].is_empty():
		return
	intro["complete"] = true
	save_game(false)
	state_changed.emit("intro")


func opening_gap_unlocked() -> bool:
	return started and not sandbox_mode and bool(intro.get("complete", false))


func enter_opening_gap() -> bool:
	if not opening_gap_unlocked() or _story_pause or _fast_forward_active:
		return false
	if opening_gap.is_empty():
		var plan: Dictionary = intro["plan"]
		var next := SmaOpeningGap.start(str(plan.get("exitRule", "")))
		if next.is_empty():
			toast_requested.emit(I18n.t("gap.unavailable"))
			return false
		if not _save_opening_gap(next):
			return false
	opening_gap_active = true
	return true


func leave_opening_gap() -> void:
	opening_gap_active = false


func apply_opening_gap(index: int, stage: int, event: String, value: String = "",
		outcome: String = "unrecorded") -> bool:
	if not opening_gap_active:
		return false
	var next := SmaOpeningGap.transition(opening_gap, index, stage, event, value, outcome)
	if next.is_empty() or not _save_opening_gap(next):
		return false
	state_changed.emit("opening_gap")
	return true


func _save_opening_gap(next: Dictionary) -> bool:
	var previous := opening_gap
	opening_gap = next
	if save_game(false):
		return true
	opening_gap = previous
	toast_requested.emit(I18n.t("toast.saveFailed"))
	return false


func black_friday_unlocked() -> bool:
	if not started or sandbox_mode:
		return false
	return is_fund_active() or is_unit_complete("u31") \
		or (narrative != null and bool(narrative.seen.get("black_friday", false)))


func enter_black_friday() -> bool:
	if not black_friday_unlocked() or _story_pause or _fast_forward_active:
		return false
	if black_friday.is_empty():
		var trust := String(narrative.flags.get("client_trust", "high")) if narrative != null else "high"
		var next := SmaBlackFriday.start(trust)
		if next.is_empty():
			toast_requested.emit(I18n.t("bf.unavailable"))
			return false
		if not _save_black_friday(next):
			return false
	black_friday_active = true
	return true


func leave_black_friday() -> void:
	black_friday_active = false


func apply_black_friday(index: int, stage: int, event: String, value: String = "") -> bool:
	if not black_friday_active:
		return false
	var was_complete := SmaBlackFriday.is_complete(black_friday)
	var next := SmaBlackFriday.transition(black_friday, index, stage, event, value)
	if next.is_empty():
		return false
	if not _save_black_friday(next):
		return false
	if not was_complete and SmaBlackFriday.is_complete(black_friday):
		var snap := SmaBlackFriday.snapshot(black_friday["attempts"][0])
		if narrative != null:
			narrative.flags["crisis_choice"] = String(snap["crisisChoice"])
			narrative.seen["black_friday"] = true
		SmaAcademy.award_xp(academy, "scenario:black_friday", 50)
		save_game(false)
		toast_requested.emit(I18n.t("bf.completedToast"))
		story_changed.emit()
		academy_changed.emit()
	state_changed.emit("black_friday")
	return true


func _save_black_friday(next: Dictionary) -> bool:
	var previous := black_friday
	black_friday = next
	if save_game(false):
		return true
	black_friday = previous
	toast_requested.emit(I18n.t("toast.saveFailed"))
	return false


func set_intro_exit_outcome(value: String) -> void:
	if not has_intro_task() or intro["review"].is_empty() or intro["plan"].is_empty():
		return
	if value not in ["unrecorded", "triggered", "notTriggered"]:
		return
	intro["review"]["exitOutcome"] = value
	save_game(false)
	state_changed.emit("intro")


func _record_intro_fill(fill: Dictionary) -> void:
	if not has_intro_task() or not intro["review"].is_empty():
		return
	var order_id := String(fill.get("orderId", ""))
	var receipt: Dictionary = intro["receipt"]
	if not receipt.is_empty() and receipt.get("orderId") != order_id:
		return
	var qty := int(fill["qty"])
	var price := float(fill["price"])
	var ticker := String(fill["ticker"])
	var position_key := "shorts" if fill.get("action") in ["openShort", "closeShort"] else "positions"
	var equity := get_equity()
	var held := int(exchange.state["account"][position_key].get(ticker, {}).get("qty", 0))
	var total_qty := int(receipt.get("qty", 0)) + qty
	var total_value := float(receipt.get("gross", 0.0)) + qty * price
	intro["receipt"] = {"orderId": order_id, "ticker": ticker, "side": fill["side"],
		"day": int(receipt.get("day", fill["day"])), "qty": total_qty, "gross": total_value,
		"price": total_value / total_qty, "fee": float(receipt.get("fee", 0.0)) + float(fill["fee"]),
		"weight": held * price / equity * 100.0 if equity > 0.0 else 0.0}


func _record_intro_close() -> void:
	if not has_intro_task() or intro["receipt"].is_empty() or not intro["review"].is_empty():
		return
	var equity := get_equity()
	var cash_pct := get_cash() / equity * 100.0 if equity > 0.0 else 0.0
	var session_fees := 0.0
	for trade: Dictionary in exchange.state["account"]["trades"]:
		if int(trade.get("day", -1)) == get_day():
			session_fees += float(trade.get("fee", 0.0))
	intro["review"] = {"day": get_day(), "equity": equity, "cashPct": cash_pct,
		"fees": session_fees, "cashTargetMet": cash_pct >= INTRO_CASH_TARGET}
	var first_trade_pnl: Variant = _first_trade_pnl_at_close()
	if first_trade_pnl != null:
		intro["review"]["firstTradePnl"] = first_trade_pnl


func _first_trade_pnl_at_close() -> Variant:
	var receipt: Dictionary = intro["receipt"]
	if receipt["side"] not in ["buy", "short"]:
		return null
	var ticker := String(receipt["ticker"])
	var is_short: bool = receipt["side"] == "short"
	var close_action := "closeShort" if is_short else "closeLong"
	var direction := -1.0 if is_short else 1.0
	var opened := 0
	var open_qty := 0
	var open_cost := 0.0
	var pnl := 0.0
	for trade: Dictionary in exchange.state["account"]["trades"]:
		if trade.get("ticker") != ticker or int(trade.get("day", -1)) != get_day():
			continue
		var qty := int(trade["qty"])
		var price := float(trade["price"])
		var fee := float(trade.get("fee", 0.0))
		if trade.get("orderId") == receipt["orderId"]:
			opened += qty
			open_qty += qty
			open_cost += qty * price
			pnl -= fee
		elif trade.get("action") == close_action and open_qty > 0:
			var closed := mini(open_qty, qty)
			var basis := open_cost / open_qty * closed
			pnl += (closed * price - basis) * direction - fee * closed / qty
			open_qty -= closed
			open_cost -= basis
	if opened != int(receipt["qty"]):
		return null
	var mark := float(exchange.state["companies"][ticker]["last"])
	return SmaFormat.round_to(pnl + (open_qty * mark - open_cost) * direction, 2)


func _check_price_alerts() -> void:
	if exchange == null:
		return
	if int(exchange.state.get("second", 0)) % 10 != 0:
		return
	if SmaAlerts.active_count(alerts) <= 0:
		return
	var prices: Dictionary = {}
	for entry in SmaAlerts.all(alerts):
		if not bool(entry.get("active", false)):
			continue
		var ticker := String(entry.get("ticker", ""))
		if ticker == "" or prices.has(ticker):
			continue
		var company: Dictionary = exchange.state["companies"].get(ticker, {})
		if company.is_empty():
			continue
		prices[ticker] = float(company.get("last", 0.0))
	if prices.is_empty():
		return
	var triggered := SmaAlerts.check(alerts, prices,
		int(exchange.state["dayIndex"]), int(exchange.state["second"]))
	if triggered.is_empty():
		return
	if triggered.size() == 1:
		var alert: Dictionary = triggered[0]
		toast_requested.emit(I18n.t("toast.priceAlert", {
			"ticker": String(alert.get("ticker", "")),
			"direction": I18n.t("alerts.%s" % String(alert.get("side", "above"))),
			"price": SmaFormat.money(float(alert.get("price", 0.0))),
		}))
	else:
		toast_requested.emit(I18n.t("toast.priceAlertsMultiple", {
			"count": triggered.size()}))
	price_alert_triggered.emit(triggered.size())
	state_changed.emit("alerts")


func set_speed(next_speed: int) -> void:
	if opening_gap_active or not SPEEDS.has(next_speed):
		return
	speed = next_speed
	settings["speed"] = next_speed


func set_layout(value: String) -> void:
	var layout := value if ["beginner", "advanced"].has(value) else "beginner"
	settings["layout"] = layout
	_apply_layout(layout)
	layout_changed.emit()
	save_game(false)


func _apply_layout(value: String) -> void:
	SmaUiTheme.set_density(0.88 if value == "advanced" else 1.0)


func set_theme(value: String) -> void:
	var next_theme := value if ["pixel", "dark", "light"].has(value) else "dark"
	settings["theme"] = next_theme
	settings["pixelMigrated"] = true
	SmaUiTheme.set_theme_mode(next_theme)
	theme_changed.emit()
	save_game(false)


func set_color_scheme(value: String) -> void:
	var scheme := value if ["intl", "cn", "colorblind"].has(value) else "intl"
	settings["colorScheme"] = scheme
	SmaUiTheme.set_color_scheme(scheme)
	theme_changed.emit()
	save_game(false)


func set_audio_volume(key: String, value: float, persist: bool = true) -> void:
	if not ["masterVolume", "musicVolume", "sfxVolume"].has(key):
		return
	settings[key] = clampf(value, 0.0, 1.0)
	_apply_audio_settings()
	if persist:
		save_game(false)


func set_muted(value: bool) -> void:
	settings["muted"] = value
	_apply_audio_settings()
	save_game(false)


func _apply_audio_settings() -> void:
	var audio := get_node_or_null("/root/Sfx")
	if audio != null and audio.has_method("apply_settings"):
		audio.apply_settings(settings)


func set_display_mode(value: String) -> void:
	settings["displayMode"] = SmaDisplay.normalise_mode(value)
	apply_display()
	save_game(false)
	state_changed.emit("display")


func set_window_preset(value: String) -> void:
	settings["windowPreset"] = SmaDisplay.normalise_preset(value)
	apply_display()
	save_game(false)
	state_changed.emit("display")


func set_ui_scale(value: String) -> void:
	settings["uiScale"] = SmaDisplay.normalise_ui_scale(value)
	if DisplayServer.get_name() != "headless":
		var window := get_window()
		if window != null:
			_apply_ui_scale(window, DisplayServer.window_get_size())
	save_game(false)
	state_changed.emit("display")


## Applies the stored window mode/size. The project's canvas_items stretch mode
## scales the 1440x900 layout to the window; SMA_KEEP_WINDOW=1 lets screenshot
## runs keep --resolution.
func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	if window == null:
		return
	if OS.has_feature("web"):
		if String(settings.get("displayMode", "windowed")) == "fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_apply_ui_scale(window, DisplayServer.window_get_size())
		return
	window.min_size = SmaDisplay.MIN_SIZE
	var usable := DisplayServer.screen_get_usable_rect()
	var keep_window := OS.get_environment("SMA_KEEP_WINDOW") == "1"
	if keep_window:
		_apply_ui_scale(window, DisplayServer.window_get_size())
		return
	var resolved := SmaDisplay.resolve_display(
		String(settings.get("displayMode", "windowed")),
		String(settings.get("windowPreset", "auto")), usable)
	if String(resolved["mode"]) == "fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_apply_ui_scale(window, DisplayServer.screen_get_size())
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var target: Vector2i = resolved["size"]
	DisplayServer.window_set_size(target)
	var actual := DisplayServer.window_get_size()
	DisplayServer.window_set_position(SmaDisplay.centered_position(usable, actual))
	_apply_ui_scale(window, actual)


func _apply_ui_scale(window: Window, window_size: Vector2i) -> void:
	window.content_scale_factor = SmaDisplay.resolve_ui_scale(
		String(settings.get("uiScale", "auto")), window_size)


func toggle_pause() -> void:
	if not started or opening_gap_active or _story_pause or _fast_forward_active:
		return
	paused = not paused
	state_changed.emit("clock")


func set_paused(value: bool) -> void:
	if not started or opening_gap_active:
		return
	paused = value
	state_changed.emit("clock")


func step_minute() -> void:
	if not started or opening_gap_active or _story_pause or exchange == null or _fast_forward_active:
		return
	paused = true
	_advance_steps(60)
	tick.emit()
	state_changed.emit("clock")


func step_day() -> void:
	if not started or opening_gap_active or _story_pause or exchange == null or _fast_forward_active:
		return
	paused = true
	_fast_forward_total = maxi(1, SmaExchange.SESSION_SECONDS - int(exchange.state["second"]))
	_fast_forward_remaining = _fast_forward_total
	_fast_forward_active = true
	fast_forward_started.emit()
	fast_forward_progress.emit(0.0)


func _process_fast_forward() -> void:
	if exchange == null:
		_end_fast_forward()
		return
	# Chunking keeps the window responsive; skipping quote-only 1m samples
	# (which finalize_day discards) keeps full-day fast-forward fast and exact.
	var chunk := mini(1200, _fast_forward_remaining)
	if chunk > 0:
		_advance_steps(chunk, false)
		_fast_forward_remaining -= chunk
	var progress := 1.0 - float(_fast_forward_remaining) / float(maxi(1, _fast_forward_total))
	fast_forward_progress.emit(progress)
	tick.emit()
	if _fast_forward_remaining <= 0 or _story_pause:
		_end_fast_forward()


func _end_fast_forward() -> void:
	_fast_forward_active = false
	_fast_forward_remaining = 0
	fast_forward_progress.emit(1.0)
	fast_forward_finished.emit()
	state_changed.emit("clock")


func is_fast_forwarding() -> bool:
	return _fast_forward_active


func is_story_paused() -> bool:
	return _story_pause


func is_market_open() -> bool:
	if exchange == null:
		return false
	return int(exchange.state["second"]) < SmaExchange.SESSION_SECONDS


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

func market_lock_info(ticker: String) -> Dictionary:
	if exchange == null or sandbox_mode:
		return {"locked": false, "ticker": ticker}
	var symbol := ticker.to_upper()
	if SmaEtfs.is_etf(symbol):
		return SmaAcademy.market_lock_info(academy, symbol, SmaEtfs.ETF_SECTOR, true)
	var company := SmaCompanyCatalog.get_company(symbol)
	if company.is_empty():
		return {"locked": false, "ticker": symbol}
	return SmaAcademy.market_lock_info(academy, symbol,
		String(company.get("sector", "")), false)


func _tool_lock_error(error_key: String) -> Dictionary:
	last_error = error_key
	order_rejected.emit(last_error)
	return {"ok": false, "error": error_key}


func _order_tool_error(ticker: String, params: Dictionary) -> Dictionary:
	var order_type := String(params.get("type", "market"))
	if order_type == "limit" and not academy_is_tool_unlocked("order.limit"):
		return _tool_lock_error("order.limitLocked")
	if order_type in ["stop", "stopLimit", "trailing"] \
			and not academy_is_tool_unlocked("order.stop"):
		return _tool_lock_error("order.stopLocked")
	var action := SmaExchange.resolve_order_action(
		String(params.get("side", "")), String(params.get("action", "")))
	if action == "openShort" and not academy_is_tool_unlocked("trade.short"):
		return _tool_lock_error("order.shortLocked")
	if action == "openLong" and not academy_is_tool_unlocked("trade.margin"):
		var qty := int(floor(float(params.get("qty", 0))))
		if qty > 0:
			var quote_data: Dictionary = exchange.quote(ticker)
			var price := float(quote_data.get("ask") if quote_data.get("ask") != null
				else quote_data.get("last", 0.0))
			if order_type == "limit":
				price = float(params.get("limitPrice", price))
			elif order_type == "stop" or order_type == "stopLimit":
				price = float(params.get("stopPrice", price))
			var needed := qty * price * (1.0 + exchange.fee_bps / 10000.0)
			if is_finite(needed) and needed > exchange.available_cash() + 1e-6:
				return _tool_lock_error("order.marginLocked")
	return {}


func effective_buying_power() -> float:
	if exchange == null:
		return 0.0
	if not academy_is_tool_unlocked("trade.margin"):
		return maxf(0.0, exchange.available_cash())
	var snapshot := SmaMargin.margin_snapshot(exchange.state)
	return maxf(0.0, float(snapshot.get("buyingPower", 0.0)))


func _market_lock_error(ticker: String) -> Dictionary:
	var lock := market_lock_info(ticker)
	if not bool(lock.get("locked", false)):
		return {}
	last_error = "order.marketLocked"
	order_rejected.emit(last_error)
	return {"ok": false, "error": "order.marketLocked", "lock": lock}


## Reducing an existing position must always stay possible, even if a save was
## created before the sector became progressive.
func _order_reduces_position(ticker: String, params: Dictionary) -> bool:
	if exchange == null:
		return false
	var symbol := ticker.to_upper()
	var account: Dictionary = exchange.state["account"]
	var side := String(params.get("side", ""))
	var action := String(params.get("action", ""))
	# An explicit action wins: an inconsistent side must not turn an opening
	# order into an allowed close.
	if action != "":
		if action == "closeLong":
			return int(account.get("positions", {}).get(symbol, {}).get("qty", 0)) > 0
		if action == "closeShort":
			return int(account.get("shorts", {}).get(symbol, {}).get("qty", 0)) > 0
		return false
	if side == "sell":
		return int(account.get("positions", {}).get(symbol, {}).get("qty", 0)) > 0
	if side == "cover":
		return int(account.get("shorts", {}).get(symbol, {}).get("qty", 0)) > 0
	return false


func submit_order(params: Dictionary) -> Dictionary:
	if not started or exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var ticker := String(params.get("ticker", ""))
	if not _order_reduces_position(ticker, params):
		var lock_error := _market_lock_error(ticker)
		if not lock_error.is_empty():
			return lock_error
	var tool_error := _order_tool_error(ticker, params)
	if not tool_error.is_empty():
		return tool_error
	var fill_start := exchange.last_player_fills.size()
	var result := exchange.submit_order(params)
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "order.invalid"))
		order_rejected.emit(last_error)
		exchange.clear_player_fills()
		return result
	var fills: Array = exchange.last_player_fills.slice(fill_start)
	exchange.clear_player_fills()
	for fill in fills:
		_record_intro_fill(fill)
		_emit_trade_fill(fill)
	if not fills.is_empty():
		save_game(false)
		academy_sync_practice()
	_sync_achievements()
	state_changed.emit("order")
	return result


func option_chain(ticker: String) -> Dictionary:
	if exchange == null:
		return {}
	return exchange.option_chain(ticker)


func option_fee(contract: Dictionary, qty: int) -> float:
	if exchange == null:
		return 0.0
	return exchange.option_fee(contract, qty)


func option_rows() -> Array:
	if exchange == null:
		return []
	return exchange.option_rows()


func option_collateral() -> float:
	if exchange == null:
		return 0.0
	return exchange.option_collateral()


func available_option_cash() -> float:
	if exchange == null:
		return 0.0
	return exchange.available_option_cash()


func available_covered_shares(ticker: String) -> int:
	if exchange == null:
		return 0
	return exchange.available_covered_shares(ticker)


func buy_option(ticker: String, option_type: String, strike: float, expiry_day: int,
		qty: int) -> Dictionary:
	if not started or exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var lock_error := _market_lock_error(ticker)
	if not lock_error.is_empty():
		return lock_error
	if not academy_is_tool_unlocked("options.trade"):
		return {"ok": false, "error": "error.optionsLocked"}
	var result := exchange.buy_option(ticker, option_type, strike, expiry_day, qty)
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "error.priceInvalid"))
		order_rejected.emit(last_error)
		return result
	save_game(false)
	academy_sync_practice()
	if narrative != null:
		narrative.handle_event("option_traded", {"ticker": ticker, "type": option_type, "strike": strike, "qty": qty})
	_push_side_comment("note_option", "story.char.zhou_heng.name", "note.optionTheta")
	state_changed.emit("option")
	return result


func close_option(key: String, qty: int) -> Dictionary:
	if not started or exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var result := exchange.close_option(key, qty)
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "error.noOptionPosition"))
		order_rejected.emit(last_error)
		return result
	save_game(false)
	academy_sync_practice()
	if narrative != null:
		narrative.handle_event("option_traded", {"key": key, "qty": qty})
	state_changed.emit("option")
	return result


func option_style() -> String:
	if exchange == null:
		return "european"
	return exchange.option_style()


func set_option_style(style: String) -> Dictionary:
	if not started or exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var result := exchange.set_option_style(style)
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "exchange.error.option.style"))
		order_rejected.emit(last_error)
		return result
	save_game(false)
	state_changed.emit("option")
	return result


func exercise_option(key: String, qty: int) -> Dictionary:
	if not started or exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var result := exchange.exercise_option(key, qty)
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "exchange.error.option.noPosition"))
		order_rejected.emit(last_error)
		return result
	save_game(false)
	academy_sync_practice()
	if narrative != null:
		narrative.handle_event("option_traded", {"key": key, "qty": qty})
	state_changed.emit("option")
	return result


func sell_option(ticker: String, option_type: String, strike: float, expiry_day: int,
		qty: int) -> Dictionary:
	if not started or exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var lock_error := _market_lock_error(ticker)
	if not lock_error.is_empty():
		return lock_error
	if not academy_is_tool_unlocked("options.trade"):
		return {"ok": false, "error": "error.optionsLocked"}
	if not academy_is_tool_unlocked("options.sell"):
		return {"ok": false, "error": "error.optionsSellLocked"}
	var result := exchange.sell_option(ticker, option_type, strike, expiry_day, qty)
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "error.insufficientOptionCollateral"))
		order_rejected.emit(last_error)
		return result
	save_game(false)
	academy_sync_practice()
	if narrative != null:
		narrative.handle_event("option_traded", {"ticker": ticker, "type": option_type, "strike": strike, "qty": qty})
	_push_side_comment("note_option", "story.char.zhou_heng.name", "note.optionTheta")
	state_changed.emit("option")
	return result


func open_option_strategy(strategy_id: String, ticker: String, expiry_days: int,
		qty: int) -> Dictionary:
	if not started or exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var lock_error := _market_lock_error(ticker)
	if not lock_error.is_empty():
		return lock_error
	if not academy_is_tool_unlocked("options.trade") \
			or not academy_is_tool_unlocked("options.sell"):
		return {"ok": false, "error": "error.optionsSellLocked"}
	var quantity := maxi(1, int(qty))
	var chain := exchange.option_chain(ticker)
	var strategy: Dictionary = SmaOptionStrategies.build(
		strategy_id, chain, expiry_days, quantity)
	if strategy.is_empty():
		return {"ok": false, "error": "error.contractNotFound"}
	var fees := 0.0
	for leg in strategy["legs"]:
		fees += exchange.option_fee(leg["contract"], int(leg["qty"]))
	var epsilon := 0.000000001
	match strategy_id:
		"coveredCall":
			if exchange.available_covered_shares(ticker) < SmaOptions.CONTRACT_SIZE * quantity:
				return {"ok": false, "error": "error.needCoveredShares"}
		"cashSecuredPut":
			var put: Dictionary = strategy["legs"][0]["contract"]
			var needed := float(put["strike"]) * SmaOptions.CONTRACT_SIZE * quantity
			if needed > exchange.available_option_cash() + epsilon:
				return {"ok": false, "error": "error.insufficientOptionCollateral"}
		_:
			var cash_needed := maxf(0.0, float(strategy["netCost"])) + fees
			if cash_needed > exchange.available_cash() + epsilon:
				return {"ok": false, "error": "error.insufficientCash"}
	var legs: Array = strategy["legs"].duplicate(true)
	legs.sort_custom(func(a, b):
		return String(a.get("side", "")) == "sell" and String(b.get("side", "")) == "buy")
	var result: Dictionary = exchange.execute_option_legs(legs)
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "error.contractNotFound"))
		order_rejected.emit(last_error)
		return result
	result["strategy"] = strategy
	save_game(false)
	academy_sync_practice()
	if narrative != null:
		narrative.handle_event("option_traded", {"ticker": ticker, "strategy": strategy_id})
	state_changed.emit("option")
	return result


func futures_chain(ticker: String) -> Dictionary:
	if exchange == null:
		return {}
	return exchange.futures_chain(ticker)


func futures_fee(contract: Dictionary, qty: int) -> float:
	if exchange == null:
		return 0.0
	return exchange.futures_fee(contract, qty)


func futures_rows() -> Array:
	if exchange == null:
		return []
	return exchange.futures_rows()


func futures_margin() -> float:
	if exchange == null:
		return 0.0
	return exchange.futures_margin()


func available_futures_cash() -> float:
	if exchange == null:
		return 0.0
	return exchange.available_futures_cash()


func open_future(ticker: String, expiry_days: int, side: String, qty: int) -> Dictionary:
	if not started or exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var lock_error := _market_lock_error(ticker)
	if not lock_error.is_empty():
		return lock_error
	if not academy_is_tool_unlocked("trade.futures"):
		return {"ok": false, "error": "error.futuresLocked"}
	var result := exchange.open_future(ticker, expiry_days, side, qty)
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "error.insufficientFuturesMargin"))
		order_rejected.emit(last_error)
		return result
	save_game(false)
	academy_sync_practice()
	if narrative != null:
		narrative.handle_event("futures_traded", {"ticker": ticker, "side": side, "qty": qty})
	state_changed.emit("futures")
	return result


func close_future(key: String, qty: int) -> Dictionary:
	if not started or exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var result := exchange.close_future(key, qty)
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "error.noFuturesPosition"))
		order_rejected.emit(last_error)
		return result
	save_game(false)
	academy_sync_practice()
	if narrative != null:
		narrative.handle_event("futures_traded", {"key": key, "qty": qty})
	state_changed.emit("futures")
	return result


func macro_snapshot() -> Dictionary:
	if exchange == null:
		return {}
	return exchange.macro_world()


func news_items() -> Array:
	if exchange == null:
		return []
	return exchange.news_items()


func earnings_calendar(limit: int = 3) -> Array:
	if exchange == null:
		return []
	return SmaEarnings.upcoming(exchange.state, get_day(), limit)


func corporate_actions(limit: int = 8) -> Array:
	return exchange.corporate_actions(limit) if exchange != null else []


func rights_offerings() -> Array:
	return exchange.rights_offerings() if exchange != null else []


func subscribe_rights(offering_id: String) -> Dictionary:
	if exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var result := exchange.subscribe_rights(offering_id)
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "corporate.errorUnknown"))
		order_rejected.emit(last_error)
		return result
	toast_requested.emit(I18n.t("toast.rightsSubscribed", {
		"qty": int(result.get("qty", 0))}))
	save_game(false)
	state_changed.emit("corporate")
	return result


func decline_rights(offering_id: String) -> Dictionary:
	if exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var result := exchange.decline_rights(offering_id)
	if not bool(result.get("ok", false)):
		return result
	toast_requested.emit(I18n.t("toast.rightsDeclined"))
	save_game(false)
	state_changed.emit("corporate")
	return result


func review_summary() -> Dictionary:
	if exchange == null:
		return {}
	return SmaReview.summary(exchange.state["account"], exchange.equity(),
		int(exchange.state["dayIndex"]))


func portfolio_risk() -> Dictionary:
	if exchange == null:
		return {}
	return SmaReview.portfolio_risk(exchange.state["account"], exchange.equity(),
		exchange.position_rows(), exchange.short_rows())


func review_timeline(limit: int = 12) -> Array:
	if exchange == null:
		return []
	return SmaReview.timeline(exchange.state["account"], limit)


func replay_max_day() -> int:
	return SmaReplay.max_day(exchange.state) if exchange != null else 0


func replay_snapshot(day: int) -> Dictionary:
	if exchange == null:
		return {}
	var latest := SmaReplay.max_day(exchange.state)
	var selected := clampi(day, 0, latest)
	return SmaReplay.snapshot(exchange.state, selected, exchange.equity() if selected == latest else NAN)


func market_index() -> float:
	return exchange.market_index() if exchange != null else 0.0


func market_index_change() -> float:
	return exchange.market_index_change() if exchange != null else 0.0


func macro_calendar() -> Array:
	return exchange.macro_calendar() if exchange != null else []


func global_markets() -> Array:
	return exchange.global_markets() if exchange != null else []


func bond_quotes() -> Array:
	return exchange.bond_quotes() if exchange != null else []


func bond_rows() -> Array:
	return exchange.bond_rows() if exchange != null else []


func buy_bond(bond_id: String, qty: int) -> Dictionary:
	if not started or exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	if not multiasset_unlocked():
		return _tool_lock_error("order.multiassetLocked")
	var result := exchange.buy_bond(bond_id, qty)
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "bond.errorUnknown"))
		order_rejected.emit(last_error)
		return result
	save_game(false)
	_sync_achievements()
	state_changed.emit("multiasset")
	return result


func sell_bond(bond_id: String, qty: int) -> Dictionary:
	if not started or exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var result := exchange.sell_bond(bond_id, qty)
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "bond.errorUnknown"))
		order_rejected.emit(last_error)
		return result
	save_game(false)
	state_changed.emit("multiasset")
	return result


func fx_quotes() -> Array:
	return exchange.fx_quotes() if exchange != null else []


func fx_rows() -> Array:
	return exchange.fx_rows() if exchange != null else []


func buy_fx(pair_id: String, units: int) -> Dictionary:
	if not started or exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	if not multiasset_unlocked():
		return _tool_lock_error("order.multiassetLocked")
	var result := exchange.buy_fx(pair_id, units)
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "fx.errorUnknown"))
		order_rejected.emit(last_error)
		return result
	save_game(false)
	_sync_achievements()
	state_changed.emit("multiasset")
	return result


func sell_fx(pair_id: String, units: int) -> Dictionary:
	if not started or exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var result := exchange.sell_fx(pair_id, units)
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "fx.errorUnknown"))
		order_rejected.emit(last_error)
		return result
	save_game(false)
	state_changed.emit("multiasset")
	return result


func commodity_quotes() -> Array:
	return exchange.commodity_quotes() if exchange != null else []


func commodity_rows() -> Array:
	return exchange.commodity_rows() if exchange != null else []


func buy_commodity(commodity_id: String, qty: int) -> Dictionary:
	if not started or exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	if not multiasset_unlocked():
		return _tool_lock_error("order.multiassetLocked")
	var result := exchange.buy_commodity(commodity_id, qty)
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "commodity.errorUnknown"))
		order_rejected.emit(last_error)
		return result
	save_game(false)
	_sync_achievements()
	state_changed.emit("multiasset")
	return result


func sell_commodity(commodity_id: String, qty: int) -> Dictionary:
	if not started or exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var result := exchange.sell_commodity(commodity_id, qty)
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "commodity.errorUnknown"))
		order_rejected.emit(last_error)
		return result
	save_game(false)
	state_changed.emit("multiasset")
	return result


func crypto_quotes() -> Array:
	return exchange.crypto_quotes() if exchange != null else []


func crypto_rows() -> Array:
	return exchange.crypto_rows() if exchange != null else []


func buy_crypto(crypto_id: String, units: float) -> Dictionary:
	if not started or exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	if not multiasset_unlocked():
		return _tool_lock_error("order.multiassetLocked")
	var result := exchange.buy_crypto(crypto_id, units)
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "crypto.errorUnknown"))
		order_rejected.emit(last_error)
		return result
	save_game(false)
	_sync_achievements()
	state_changed.emit("multiasset")
	return result


func sell_crypto(crypto_id: String, units: float) -> Dictionary:
	if not started or exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var result := exchange.sell_crypto(crypto_id, units)
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "crypto.errorUnknown"))
		order_rejected.emit(last_error)
		return result
	save_game(false)
	state_changed.emit("multiasset")
	return result


func statement_history(ticker: String, count: int = 8) -> Array:
	var day := int(exchange.state["dayIndex"]) if exchange != null else 0
	return SmaFundamentals.history(ticker.to_upper(), count, day)


func etf_nav(ticker: String) -> float:
	if exchange == null:
		return 0.0
	return SmaEtfs.nav(exchange.state["companies"], ticker)


func etf_holdings(ticker: String) -> Array:
	if exchange == null:
		return []
	return SmaEtfs.holdings_rows(exchange.state["companies"], ticker)


func etf_rows() -> Array:
	if exchange == null:
		return []
	var rows: Array = []
	for ticker in SmaEtfs.tickers():
		var quote: Dictionary = exchange.quote(ticker)
		var nav_value := SmaEtfs.nav(exchange.state["companies"], ticker)
		var last := float(quote.get("last", 0.0))
		var definition := SmaEtfs.definition(ticker)
		rows.append({
			"ticker": ticker,
			"name": String(definition.get("name", ticker)),
			"last": last,
			"nav": nav_value,
			"premium": SmaEtfs.premium(last, nav_value),
			"changePct": float(quote.get("changePct", 0.0)),
			"expenseRatio": float(definition.get("expenseRatio", 0.0)),
			"volume": int(quote.get("volume", 0)),
			"bid": quote.get("bid", null),
			"ask": quote.get("ask", null),
		})
	return rows


func submit_oco(params: Dictionary) -> Dictionary:
	if not started or exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	if not academy_is_tool_unlocked("order.limit"):
		return _tool_lock_error("order.limitLocked")
	if not academy_is_tool_unlocked("order.stop"):
		return _tool_lock_error("order.stopLocked")
	var ticker := String(params.get("ticker", ""))
	if not _order_reduces_position(ticker, params):
		var lock_error := _market_lock_error(ticker)
		if not lock_error.is_empty():
			return lock_error
	var fill_start := exchange.last_player_fills.size()
	var result := exchange.submit_oco(params)
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "order.invalid"))
		order_rejected.emit(last_error)
		exchange.clear_player_fills()
		return result
	var fills: Array = exchange.last_player_fills.slice(fill_start)
	exchange.clear_player_fills()
	for fill in fills:
		_record_intro_fill(fill)
		_emit_trade_fill(fill)
	if not fills.is_empty():
		save_game(false)
		academy_sync_practice()
	_sync_achievements()
	state_changed.emit("order")
	return result


func cancel_order(order_id: String) -> Dictionary:
	if not started or exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var order_result := exchange.cancel_order(order_id)
	if not bool(order_result.get("ok", false)):
		last_error = String(order_result.get("error", "order.invalid"))
		order_rejected.emit(last_error)
		return order_result
	academy_sync_practice()
	state_changed.emit("order")
	return order_result


func quant_history(ticker: String) -> Array:
	if exchange == null:
		return []
	return SmaQuant.history_for(exchange, ticker)


func quant_backtest(config: Dictionary) -> Dictionary:
	if exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var normalized := SmaQuant.normalize_config(config)
	var ticker := String(normalized["ticker"])
	if ticker == "":
		ticker = selected_ticker
		normalized["ticker"] = ticker
	var result := SmaQuant.run_backtest(SmaQuant.history_for(exchange, ticker),
		String(normalized["strategy"]), normalized["params"],
		float(normalized["initialCash"]), float(normalized["commission"]))
	if bool(result.get("ok", false)):
		SmaAcademy.record_milestone(academy, "quant")
		_push_side_comment("note_quant", "story.char.chen_xi.name", "note.quantOverfit")
		_sync_achievements()
	return result


func quant_optimize(config: Dictionary) -> Dictionary:
	if exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var normalized := SmaQuant.normalize_config(config)
	var ticker := String(normalized["ticker"])
	if ticker == "":
		ticker = selected_ticker
	var result := SmaQuant.optimize(SmaQuant.history_for(exchange, ticker),
		String(normalized["strategy"]), normalized["params"],
		float(normalized["initialCash"]), float(normalized["commission"]),
		int(normalized["splitPct"]), String(normalized["objective"]))
	if bool(result.get("ok", false)):
		SmaAcademy.record_milestone(academy, "quant")
		_push_side_comment("note_quant", "story.char.chen_xi.name", "note.quantOverfit")
		_sync_achievements()
	return result


func quant_factor_research(factor: String, lookback: int) -> Dictionary:
	if exchange == null:
		return {"factor": factor, "lookback": lookback, "rows": [], "count": 0}
	SmaAcademy.record_milestone(academy, "quant")
	_sync_achievements()
	return SmaQuant.factor_research(exchange, factor, lookback)


func quant_regression(lookback: int, horizon: int) -> Dictionary:
	if exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var result := SmaQuant.factor_regression(exchange, lookback, horizon)
	if bool(result.get("ok", false)):
		SmaAcademy.record_milestone(academy, "quant")
		_push_side_comment("note_quant", "story.char.chen_xi.name", "note.quantOverfit")
		_sync_achievements()
	return result


func quant_ml(config: Dictionary) -> Dictionary:
	if exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var normalized := SmaQuant.normalize_config(config)
	var result := SmaQuant.ml_stock_selection(exchange, int(normalized["mlLookback"]),
		int(normalized["mlHorizon"]), int(normalized["mlTopN"]),
		int(normalized["mlTestPct"]), String(normalized["mlModel"]),
		bool(normalized["mlAutoTune"]))
	if bool(result.get("ok", false)):
		SmaAcademy.record_milestone(academy, "quant")
		_push_side_comment("note_quant", "story.char.chen_xi.name", "note.quantOverfit")
		_sync_achievements()
	return result


func set_quant_config(config: Dictionary) -> void:
	quant = SmaQuant.normalize_config(config)


func career_context() -> Dictionary:
	if exchange == null:
		return {"academy": academy}
	var account: Dictionary = exchange.state["account"]
	var tickers: Array = SmaCompanyCatalog.load_companies().keys()
	return {
		"academy": academy,
		"day": int(exchange.state["dayIndex"]),
		"equity": exchange.equity(),
		"initialCash": float(account.get("initialCash", START_CASH)),
		"careerIncome": float(account.get("careerIncome", 0.0)),
		"trades": account.get("trades", []).size(),
		"optionTrades": account.get("optionTrades", []).size(),
		"futuresTrades": account.get("futuresTrades", []).size(),
		"equityHistory": account.get("equityHistory", []),
		"challengesCompleted": challenges.get("completed", []),
		"tickers": tickers,
	}


func career_progress() -> Dictionary:
	return SmaCareer.progress(career, career_context())


func promote_career() -> Dictionary:
	var result := SmaCareer.promote(career, career_context(),
		int(exchange.state["dayIndex"]) if exchange != null else 0)
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "career.errorNotReady"))
		order_rejected.emit(last_error)
		return result
	var rank: Dictionary = result.get("rank", {})
	toast_requested.emit(I18n.t("toast.careerPromoted", {
		"rank": I18n.t(String(rank.get("titleKey", ""))),
		"xp": int(result.get("xp", 0)),
	}))
	for certificate in result.get("certificates", []):
		toast_requested.emit(I18n.t("toast.certificateEarned", {
			"names": I18n.t(String(certificate.get("id", ""))),
		}))
	save_game(false)
	career_promoted.emit(int(career.get("rank", 0)))
	if narrative != null:
		narrative.handle_event("career_promoted", {"rank": int(career.get("rank", 0))})
	_sync_achievements()
	state_changed.emit("career")
	return result


func accept_research_task(task_id: String) -> Dictionary:
	if exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var result := SmaCareer.accept_task(career, task_id,
		int(exchange.state["dayIndex"]))
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "career.task.errorUnavailable"))
		order_rejected.emit(last_error)
		return result
	save_game(false)
	state_changed.emit("career")
	return result


func career_report_context(task_id: String) -> Dictionary:
	if exchange == null:
		return {}
	var task: Dictionary = {}
	for entry in career.get("tasks", []):
		if String(entry.get("id", "")) == task_id:
			task = entry
			break
	if task.is_empty():
		return {}
	var ticker := String(task.get("ticker", ""))
	var quote: Dictionary = exchange.quote(ticker)
	var candles: Array = exchange.get_candles(ticker, "1D")
	return {
		"ticker": ticker,
		"last": float(quote.get("last", 0.0)),
		"trend": SmaCareer.trend_for(candles),
	}


func submit_investment_report(input: Dictionary) -> Dictionary:
	if exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var task_id := String(input.get("taskId", ""))
	var context_data := career_report_context(task_id)
	if context_data.is_empty():
		return {"ok": false, "error": "career.report.errorTask"}
	var ticker := String(context_data["ticker"])
	context_data["inspected"] = academy.get("inspectedTickers", []).has(ticker)
	context_data["financialsDone"] = SmaAcademy.is_unit_complete(academy, "u12")
	context_data["academy"] = academy
	var result := SmaCareer.submit_report(career, input, context_data,
		int(exchange.state["dayIndex"]))
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "career.report.errorTask"))
		order_rejected.emit(last_error)
		return result
	var cash := float(result.get("cash", 0.0))
	if cash > 0.0:
		var account: Dictionary = exchange.state["account"]
		account["cash"] = SmaFormat.round_to(float(account["cash"]) + cash, 2)
		account["careerIncome"] = SmaFormat.round_to(
			float(account.get("careerIncome", 0.0)) + cash, 2)
	toast_requested.emit(I18n.t("toast.reportGraded", {
		"score": int(result["report"]["score"]),
		"grade": String(result["report"]["grade"]),
		"xp": int(result.get("xp", 0)),
	}))
	save_game(false)
	academy_sync_practice()
	state_changed.emit("career")
	return result


func _advance_career() -> void:
	if exchange == null:
		return
	var day := int(exchange.state["dayIndex"])
	var ctx := career_context()
	var account: Dictionary = exchange.state["account"]
	var salary := SmaCareer.apply_salary(account, career, day)
	if bool(salary.get("paid", false)):
		toast_requested.emit(I18n.t("toast.careerSalary", {
			"amount": SmaFormat.money(float(salary["amount"])),
			"rank": I18n.t(String(SmaCareer.rank_def(int(career["rank"]))["titleKey"])),
		}))
	var evaluation := SmaCareer.evaluate(career, ctx, day)
	if bool(evaluation.get("due", false)):
		var record: Dictionary = evaluation["evaluation"]
		toast_requested.emit(I18n.t("toast.careerEvaluation", {
			"grade": String(record["grade"]), "score": int(record["score"]),
		}))
	SmaCareer.refresh_tasks(career, day, ctx.get("tickers", []))
	var synced := SmaCareer.sync_certificates(career, ctx, day)
	for certificate in synced.get("newlyEarned", []):
		toast_requested.emit(I18n.t("toast.certificateEarned", {
			"names": String(certificate.get("id", "")),
		}))
	if bool(salary.get("paid", false)) or bool(evaluation.get("due", false)) \
			or not synced.get("newlyEarned", []).is_empty():
		state_changed.emit("career")


func fund_unlocked() -> bool:
	return SmaFund.unlocked(career)


func fund_quotes() -> Dictionary:
	var quotes := {}
	if exchange == null:
		return quotes
	for ticker in SmaCompanyCatalog.load_companies().keys():
		quotes[String(ticker)] = exchange.quote(String(ticker))
	return quotes


func fund_metrics() -> Dictionary:
	if exchange == null:
		return {}
	return SmaFund.metrics(fund, fund_quotes(), exchange.market_index(),
		float(exchange.quote("MKT").get("last", 0.0)), int(exchange.state["dayIndex"]))


func fund_leaderboard() -> Array:
	return SmaFund.leaderboard(fund, int(exchange.state["dayIndex"]) if exchange != null else 0)


func fund_attribution() -> Dictionary:
	if exchange == null:
		return {}
	return SmaFund.attribution(fund, exchange)


func fund_risk_model() -> Dictionary:
	if exchange == null:
		return {"ok": false, "error": "fund.riskModel.history"}
	return SmaFund.factor_risk(fund, exchange, 60)


func create_fund(input: Dictionary) -> Dictionary:
	if exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	if not fund_unlocked():
		return {"ok": false, "error": "fund.errorLocked"}
	if String(fund.get("status", "none")) == "active":
		return {"ok": false, "error": "fund.errorAlreadyActive"}
	var benchmark_id := String(input.get("benchmarkId", "index"))
	var benchmark_start := 0.0
	if benchmark_id == "index":
		benchmark_start = exchange.market_index()
	elif benchmark_id == "mkt":
		benchmark_start = float(exchange.quote("MKT").get("last", 0.0))
	var result := SmaFund.setup(String(input.get("name", "")),
		String(input.get("strategy", "longOnly")), String(input.get("riskProfile", "balanced")),
		float(input.get("initialAum", SmaFund.AUM_OPTIONS[1])),
		float(input.get("managementRate", 0.02)), float(input.get("performanceRate", 0.2)),
		benchmark_id, float(input.get("hurdleRate", 0.0)),
		bool(input.get("leverageEnabled", false)), String(input.get("taxProfileId", "none")),
		int(exchange.state["dayIndex"]), String(exchange.state["seed"]), benchmark_start)
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "fund.errorName"))
		order_rejected.emit(last_error)
		return result
	fund = result["fund"]
	if narrative != null:
		narrative.set_flag("had_fund", true)
	toast_requested.emit(I18n.t("toast.fundCreated", {"name": String(fund["name"])}))
	_push_side_comment("note_fund", "story.char.su_he.name", "note.fundFiduciary")
	save_game(false)
	_sync_achievements()
	state_changed.emit("fund")
	if narrative != null:
		narrative.handle_event("fund_created", {"name": String(fund["name"])})
	return {"ok": true, "fund": fund}


func fund_buy(ticker: String, qty: int) -> Dictionary:
	if exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var result := SmaFund.buy(fund, fund_quotes(), ticker, qty,
		int(exchange.state["dayIndex"]))
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "fund.errorNotActive"))
		order_rejected.emit(last_error)
		return result
	save_game(false)
	state_changed.emit("fund")
	return result


func fund_sell(ticker: String, qty: int) -> Dictionary:
	if exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var result := SmaFund.sell(fund, fund_quotes(), ticker, qty,
		int(exchange.state["dayIndex"]))
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "fund.errorNotActive"))
		order_rejected.emit(last_error)
		return result
	save_game(false)
	state_changed.emit("fund")
	return result


func fund_hire(role_id: String) -> Dictionary:
	var result := SmaFund.hire(fund, role_id)
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "fund.errorUnknownRole"))
		order_rejected.emit(last_error)
		return result
	toast_requested.emit(I18n.t("toast.fundHired", {
		"role": I18n.t(String(result["role"]["nameKey"]))}))
	save_game(false)
	state_changed.emit("fund")
	return result


func fund_fire(role_id: String) -> Dictionary:
	var result := SmaFund.fire(fund, role_id)
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "fund.errorNoEmployee"))
		order_rejected.emit(last_error)
		return result
	toast_requested.emit(I18n.t("toast.fundFired"))
	save_game(false)
	state_changed.emit("fund")
	return result


func fund_accept_client(candidate_id: String) -> Dictionary:
	if exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var result := SmaFund.accept_client(fund, candidate_id, fund_metrics(),
		int(exchange.state["dayIndex"]))
	if not bool(result.get("ok", false)):
		return result
	toast_requested.emit(I18n.t("toast.fundClientJoined", {
		"name": String(result["client"]["name"])}))
	save_game(false)
	state_changed.emit("fund")
	return result


func fund_settle_redemption(client_id: String) -> Dictionary:
	if exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var result := SmaFund.settle_redemption(fund, client_id, fund_metrics(),
		int(exchange.state["dayIndex"]))
	if not bool(result.get("ok", false)):
		return result
	save_game(false)
	state_changed.emit("fund")
	return result


func fund_withdraw_company_cash() -> Dictionary:
	if exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var result := SmaFund.withdraw_company_cash(fund, exchange.state["account"])
	if not bool(result.get("ok", false)):
		return result
	toast_requested.emit(I18n.t("toast.fundCashWithdrawn", {
		"amount": SmaFormat.money(float(result["amount"]))}))
	save_game(false)
	state_changed.emit("fund")
	return result


func fund_set_strategy(config: Dictionary) -> void:
	fund["quantPlan"] = SmaFund._normalize_plan(config)
	save_game(false)
	state_changed.emit("fund")


func fund_generate_plan() -> Dictionary:
	if exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var result := SmaFund.build_plan(fund, exchange, int(exchange.state["dayIndex"]),
		fund.get("quantPlan", {}))
	if bool(result.get("ok", false)):
		fund["quantPlan"]["plan"] = result["plan"]
		fund["quantPlan"]["lastPlanDay"] = int(exchange.state["dayIndex"])
		save_game(false)
		state_changed.emit("fund")
	return result


func fund_apply_plan() -> Dictionary:
	if exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var plan: Dictionary = fund.get("quantPlan", {}).get("plan", {})
	var result := SmaFund.apply_plan(fund, exchange, plan, int(exchange.state["dayIndex"]))
	if bool(result.get("ok", false)):
		fund["quantPlan"]["plan"] = null
		toast_requested.emit(I18n.t("toast.fundPlanApplied", {
			"applied": int(result.get("applied", 0)),
			"failed": result.get("failures", []).size(),
		}))
		save_game(false)
		state_changed.emit("fund")
	return result


func fund_research() -> Dictionary:
	if exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	return SmaFund.research_plan(fund, exchange, fund.get("quantPlan", {}), 70, "sharpe")


func fund_apply_research(config: Dictionary) -> void:
	var plan: Dictionary = fund.get("quantPlan", {})
	plan["topN"] = int(config.get("topN", plan.get("topN", 5)))
	plan["cashBuffer"] = float(config.get("cashBuffer", plan.get("cashBuffer", 0.1)))
	plan["rebalanceDays"] = int(config.get("rebalanceDays",
		plan.get("rebalanceDays", 21)))
	plan["plan"] = null
	fund["quantPlan"] = SmaFund._normalize_plan(plan)
	toast_requested.emit(I18n.t("toast.fundResearchApplied"))
	save_game(false)
	state_changed.emit("fund")


func fund_optimize(method: String, lookback: int, max_weight: float,
		cash_buffer: float) -> Dictionary:
	if exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	return SmaFund.optimize_portfolio(exchange, method, lookback, max_weight, cash_buffer)


func fund_apply_optimizer(weights: Array) -> Dictionary:
	if exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var plan := SmaFund.optimizer_plan(fund, exchange, weights,
		int(exchange.state["dayIndex"]))
	if not bool(plan.get("ok", false)):
		return plan
	var result := SmaFund.apply_plan(fund, exchange, plan["plan"],
		int(exchange.state["dayIndex"]))
	toast_requested.emit(I18n.t("toast.fundOptimizerPlan", {
		"count": plan["plan"]["trades"].size()}))
	save_game(false)
	state_changed.emit("fund")
	return result


func _advance_fund() -> void:
	if exchange == null or String(fund.get("status", "none")) != "active":
		return
	var day := int(exchange.state["dayIndex"])
	var result := SmaFund.advance_day(fund, exchange, day)
	var events: Array = result.get("events", [])
	for event in events:
		var event_type := String(event.get("type", ""))
		if event_type == "redemptionRequest":
			toast_requested.emit(I18n.t("toast.fundRedemptionRequest", {
				"name": String(event.get("name", ""))}))
			if narrative != null:
				narrative.handle_event("redemption_requested", event)
		elif event_type == "closed":
			toast_requested.emit(I18n.t("toast.fundClosed", {
				"reason": I18n.t("fund.closeReason.%s" % String(event.get("reason", "")))}))
	var m := fund_metrics()
	if float(m.get("drawdown", 0.0)) >= 15.0 and narrative != null:
		narrative.handle_event("drawdown_breached", {"drawdown": float(m.get("drawdown", 0.0))})
	var auto := SmaFund.auto_rebalance(fund, exchange, day)
	if bool(auto.get("executed", false)):
		toast_requested.emit(I18n.t("toast.fundAutoRebalance", {
			"applied": int(auto.get("applied", 0)), "failed": 0}))
	if not events.is_empty() or bool(auto.get("executed", false)):
		state_changed.emit("fund")


func tax_estimate(config: Dictionary) -> Dictionary:
	if exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var input := config.duplicate(true)
	input["trades"] = exchange.state["account"].get("trades", [])
	input["dividends"] = exchange.state["account"].get("dividends", [])
	var uk_shares: Array = []
	if bool(input.get("ukShares", true)):
		for ticker in SmaCompanyCatalog.load_companies().keys():
			uk_shares.append(String(ticker))
	input["ukShareTickers"] = uk_shares
	var result := SmaTax.estimate(input)
	if bool(result.get("ok", false)):
		SmaAcademy.record_milestone(academy, "tax")
		_sync_achievements()
	return result


func challenge_progress() -> Dictionary:
	if exchange == null:
		return {}
	return SmaChallenges.progress(challenges, exchange)


func start_challenge(challenge_id: String) -> Dictionary:
	if not started or exchange == null:
		return {"ok": false, "error": "game.notStarted"}
	var result := SmaChallenges.start(challenges, academy, challenge_id,
		int(exchange.state["dayIndex"]), exchange.equity())
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "challenges.errorUnknown"))
		order_rejected.emit(last_error)
		return result
	save_game(false)
	state_changed.emit("challenge")
	return result


func abandon_challenge() -> Dictionary:
	if not started:
		return {"ok": false, "error": "game.notStarted"}
	var result := SmaChallenges.abandon(challenges)
	if not bool(result.get("ok", false)):
		return result
	save_game(false)
	state_changed.emit("challenge")
	return result


func _check_challenges() -> void:
	if exchange == null:
		return
	var result := SmaChallenges.check(challenges, academy, exchange)
	var status := String(result.get("status", ""))
	if status.is_empty():
		return
	if status == "completed":
		var definition: Dictionary = result.get("definition", {})
		toast_requested.emit(I18n.t("toast.challengeCompleted", {
			"challenge": I18n.t(String(definition.get("titleKey", ""))),
			"xp": int(result.get("xp", definition.get("xp", 0))),
		}))
		challenge_finished.emit(status, String(result.get("id", "")))
		_push_side_comment("note_challenge", "story.char.gu_yan.name", "note.challengeWin")
		_sync_achievements()
		state_changed.emit("challenge")
	elif status == "failed":
		var definition: Dictionary = result.get("definition", {})
		toast_requested.emit(I18n.t("toast.challengeFailed", {
			"challenge": I18n.t(String(definition.get("titleKey", ""))),
		}))
		challenge_finished.emit(status, String(result.get("id", "")))
		state_changed.emit("challenge")


func select_ticker(ticker: String) -> void:
	if exchange == null:
		return
	var symbol := ticker.to_upper()
	if exchange.state["companies"].has(symbol):
		selected_ticker = symbol
		if SmaAcademy.record_inspection(academy, symbol):
			academy_sync_practice()
		state_changed.emit("selection")


func chart_timeframe() -> String:
	var value := String(settings.get("chartTimeframe", "1m"))
	return value if SmaMinuteSeries.CHART_TIMEFRAMES.has(value) else "1m"


func set_chart_timeframe(value: String) -> void:
	if SmaMinuteSeries.CHART_TIMEFRAMES.has(value) and value != chart_timeframe():
		settings["chartTimeframe"] = value
		state_changed.emit("chart_timeframe")


# ---------------------------------------------------------------------------
# Watchlist and price alerts
# ---------------------------------------------------------------------------

func is_watched(ticker: String) -> bool:
	return SmaAlerts.is_watched(alerts, ticker)


func toggle_watch(ticker: String) -> bool:
	if exchange == null:
		return false
	var symbol := ticker.strip_edges().to_upper()
	if not exchange.state["companies"].has(symbol):
		return false
	var watched := SmaAlerts.toggle_watch(alerts, symbol)
	save_game(false)
	state_changed.emit("alerts")
	return watched


func watchlist() -> Array:
	return SmaAlerts.watchlist(alerts)


func price_alerts() -> Array:
	return SmaAlerts.all(alerts)


func add_price_alert(ticker: String, side: String, price: float) -> Dictionary:
	if exchange == null:
		return {"ok": false, "alert": {}, "error": "alerts.invalidTicker"}
	var symbol := ticker.strip_edges().to_upper()
	var company: Dictionary = exchange.state["companies"].get(symbol, {})
	if company.is_empty():
		return {"ok": false, "alert": {}, "error": "alerts.invalidTicker"}
	var direction := side.strip_edges().to_lower()
	if not SmaAlerts.SIDES.has(direction):
		return {"ok": false, "alert": {}, "error": "alerts.invalidDirection"}
	var last := float(company.get("last", 0.0))
	if price <= 0.0 or not is_finite(price) or last <= 0.0:
		return {"ok": false, "alert": {}, "error": "alerts.invalidPrice"}
	if direction == "above" and price <= last:
		return {"ok": false, "alert": {}, "error": "alerts.aboveMustBeHigher"}
	if direction == "below" and price >= last:
		return {"ok": false, "alert": {}, "error": "alerts.belowMustBeLower"}
	var result := SmaAlerts.add_alert(alerts, symbol, direction, price,
		int(exchange.state["dayIndex"]))
	if bool(result.get("ok", false)):
		_push_side_comment("note_alert", "story.char.chen_xi.name", "note.priceAlert")
		save_game(false)
		state_changed.emit("alerts")
	return result


func remove_price_alert(alert_id: String) -> bool:
	var removed := SmaAlerts.remove_alert(alerts, alert_id)
	if removed:
		save_game(false)
		state_changed.emit("alerts")
	return removed


func clear_triggered_alerts() -> int:
	var removed := SmaAlerts.remove_triggered(alerts)
	if removed > 0:
		save_game(false)
		state_changed.emit("alerts")
	return removed


# ---------------------------------------------------------------------------
# Academy
# ---------------------------------------------------------------------------

func academy_snapshot() -> Dictionary:
	var account: Dictionary = exchange.state["account"] if exchange != null else {}
	return {
		"trades": account.get("trades", []),
		"orders": exchange.state["orders"] if exchange != null else [],
		"positions": account.get("positions", {}),
		"shorts": account.get("shorts", {}),
		"dividends": account.get("dividends", []),
		"margin": account.get("margin", {}),
		"bonds": account.get("bonds", []),
		"fx": account.get("fx", []),
		"commodities": account.get("commodities", []),
		"crypto": account.get("crypto", []),
		"optionTrades": account.get("optionTrades", []),
		"options": account.get("options", []),
		"futures": account.get("futures", []),
		"futuresTrades": account.get("futuresTrades", []),
		"realizedPnl": float(account.get("realizedPnl", 0.0)) \
			+ float(account.get("optionRealized", 0.0)) \
			+ float(account.get("futuresRealized", 0.0)),
		"cash": float(account.get("cash", 0.0)),
		"equity": exchange.equity() if exchange != null else 0.0,
		"etfTickers": exchange.state.get("etfTickers", []) if exchange != null else [],
		"careerRank": int(career.get("rank", 1)),
		"challengesCompleted": challenges.get("completed", []),
		"fundFounded": String(fund.get("status", "none")) != "none",
		"milestones": academy.get("milestones", {}),
		"day": get_day(),
	}


func _record_achievements(achievement_ids: Array) -> void:
	if achievement_ids.is_empty():
		return
	achievement_unlocked.emit(achievement_ids)
	for achievement_id in achievement_ids:
		toast_requested.emit(I18n.t("toast.achievement", {
			"name": I18n.t(SmaAcademy.achievement_title_key(String(achievement_id))),
		}))


func _sync_achievements() -> void:
	if academy.is_empty():
		return
	_record_achievements(SmaAcademy.evaluate_achievements(academy, academy_snapshot()))


func academy_sync_practice() -> void:
	if exchange == null or academy.is_empty():
		return
	var snapshot := academy_snapshot()
	var completed := SmaAcademy.sync_practice(academy, snapshot, get_day())
	var achievements := SmaAcademy.evaluate_achievements(academy, snapshot)
	if completed.is_empty() and achievements.is_empty():
		return
	for entry in completed:
		if bool(entry.get("completed", false)):
			toast_requested.emit(I18n.t("toast.unitComplete"))
			if narrative != null:
				narrative.handle_event("unit_completed", {"unit_id": String(entry.get("unitId", ""))})
	_record_achievements(achievements)
	academy_changed.emit()
	save_game(false)


func academy_mark_section_read(unit_id: String, section_id: String) -> Dictionary:
	var result := SmaAcademy.mark_section_read(academy, unit_id, section_id, get_day())
	if bool(result.get("ok", false)):
		var achievements := SmaAcademy.evaluate_achievements(academy, academy_snapshot())
		_record_achievements(achievements)
		academy_changed.emit()
		if bool(result.get("completed", false)):
			toast_requested.emit(I18n.t("toast.unitComplete"))
			if narrative != null:
				narrative.handle_event("unit_completed", {"unit_id": unit_id})
		save_game(false)
		result["achievements"] = achievements
	return result


func academy_submit_quiz(unit_id: String, session: Dictionary, answers: Dictionary) -> Dictionary:
	var grade := SmaAcademy.grade_quiz(session, answers)
	var record := SmaAcademy.record_quiz(academy, unit_id, int(grade["score"]), get_day())
	var achievements := SmaAcademy.evaluate_achievements(academy, academy_snapshot())
	_record_achievements(achievements)
	academy_changed.emit()
	if bool(record.get("completed", false)):
		toast_requested.emit(I18n.t("toast.unitComplete"))
		if narrative != null:
			narrative.handle_event("unit_completed", {"unit_id": unit_id})
	save_game(false)
	return {"grade": grade, "record": record, "achievements": achievements}


func academy_submit_test_out(unit_id: String, session: Dictionary,
		answers: Dictionary) -> Dictionary:
	var grade := SmaAcademy.grade_quiz(session, answers)
	var passed := int(grade.get("score", 0)) >= SmaAcademy.TEST_OUT_SCORE
	grade["passed"] = passed
	var record := SmaAcademy.record_test_out(academy, unit_id, int(grade["score"]), get_day())
	var achievements := SmaAcademy.evaluate_achievements(academy, academy_snapshot())
	_record_achievements(achievements)
	academy_changed.emit()
	if bool(record.get("testedOut", false)):
		toast_requested.emit(I18n.t("academy.testOutPassedToast", {
			"unit": I18n.t(String(SmaAcademy.unit(unit_id).get("titleKey", unit_id))),
		}))
		if narrative != null:
			narrative.handle_event("unit_completed", {"unit_id": unit_id})
	save_game(false)
	return {"grade": grade, "record": record, "achievements": achievements}


func set_player_name(value: String) -> void:
	var clean := value.strip_edges().substr(0, 24)
	settings["playerName"] = clean
	if started and not sandbox_mode:
		save_game(false)
	state_changed.emit("settings")


func display_player_name() -> String:
	var saved := String(settings.get("playerName", "")).strip_edges()
	return saved if saved != "" else I18n.t("player.defaultName")


func _push_side_comment(note_id: String, speaker_key: String, text_key: String) -> void:
	if academy.is_empty() or sandbox_mode:
		return
	var milestones: Dictionary = academy.get("milestones", {})
	var notes: Array = milestones.get("notes", []) if milestones.get("notes") is Array else []
	for item in notes:
		if item is Dictionary and String(item.get("id", "")) == note_id:
			return
	notes.append({
		"id": note_id,
		"speakerKey": speaker_key,
		"textKey": text_key,
		"day": get_day(),
	})
	milestones["notes"] = notes
	academy["milestones"] = milestones
	toast_requested.emit("%s: %s" % [I18n.t(speaker_key), I18n.t(text_key)])


func side_comments() -> Array:
	var milestones: Dictionary = academy.get("milestones", {})
	var notes: Variant = milestones.get("notes", [])
	return notes if notes is Array else []


## Global objective tracker across all 4 acts, giving one clear next step
## plus optional active-challenge progress and path-tailored hint.
func current_objective() -> Dictionary:
	var path_flag := String(narrative.flags.get("path", "")) if narrative != null else ""
	var path_hint := ""
	if path_flag == "value":
		path_hint = I18n.t("objective.pathHint.value")
	elif path_flag == "momentum":
		path_hint = I18n.t("objective.pathHint.momentum")
	var challenge_info := challenge_progress() if exchange != null else {}
	if has_intro_task():
		return {
			"act": 1, "actKey": "objective.act1",
			"title": I18n.t("objective.intro.title"),
			"detail": I18n.t("objective.intro.detail"),
			"target": "trade" if intro.get("receipt", {}).is_empty() else "dashboard",
			"button": I18n.t("objective.goTrade" if intro.get("receipt", {}).is_empty() else "objective.goDashboard"),
			"pathHint": path_hint, "challenge": challenge_info,
		}
	if opening_gap_unlocked() and not SmaOpeningGap.is_complete(opening_gap):
		return {
			"act": 1, "actKey": "objective.act1",
			"title": I18n.t("objective.gap.title"),
			"detail": I18n.t("objective.gap.detail"),
			"target": "opening_gap",
			"button": I18n.t("gap.start" if opening_gap.is_empty() else "gap.resume"),
			"pathHint": path_hint, "challenge": challenge_info,
		}
	if not is_unit_complete("u4"):
		return {
			"act": 1, "actKey": "objective.act1",
			"title": I18n.t("objective.core.title"),
			"detail": I18n.t("objective.core.detail"),
			"target": "academy",
			"button": I18n.t("objective.goAcademy"),
			"pathHint": path_hint, "challenge": challenge_info,
		}
	if int(career.get("rank", 1)) < 5 and not is_fund_active():
		return {
			"act": 2, "actKey": "objective.act2",
			"title": I18n.t("objective.tracks.title"),
			"detail": I18n.t("objective.tracks.detail", {
				"done": SmaAcademy.overall_progress(academy)["completed"],
				"total": SmaAcademy.overall_progress(academy)["total"],
			}),
			"target": "academy",
			"button": I18n.t("objective.goAcademy"),
			"pathHint": path_hint, "challenge": challenge_info,
		}
	if not is_fund_active() and not is_unit_complete("u32"):
		return {
			"act": 3, "actKey": "objective.act3",
			"title": I18n.t("objective.fund.title"),
			"detail": I18n.t("objective.fund.detail"),
			"target": "fund",
			"button": I18n.t("objective.goFund"),
			"pathHint": path_hint, "challenge": challenge_info,
		}
	if black_friday_unlocked() and not SmaBlackFriday.is_complete(black_friday):
		return {
			"act": 3, "actKey": "objective.act3",
			"title": I18n.t("objective.blackFriday.title"),
			"detail": I18n.t("objective.blackFriday.detail"),
			"target": "black_friday",
			"button": I18n.t("bf.start" if black_friday.is_empty() else "bf.resume"),
			"pathHint": path_hint, "challenge": challenge_info,
		}
	if not is_unit_complete("u32"):
		return {
			"act": 4, "actKey": "objective.act4",
			"title": I18n.t("objective.graduation.title"),
			"detail": I18n.t("objective.graduation.detail"),
			"target": "academy",
			"button": I18n.t("objective.goAcademy"),
			"pathHint": path_hint, "challenge": challenge_info,
		}
	return {
		"act": 4, "actKey": "objective.act4",
		"title": I18n.t("objective.mastery.title"),
		"detail": I18n.t("objective.mastery.detail"),
		"target": "story",
		"button": I18n.t("objective.goStory"),
		"pathHint": path_hint, "challenge": challenge_info,
	}


func academy_record_glossary(term_id: String) -> void:
	if SmaAcademy.record_glossary_visit(academy, term_id):
		_sync_achievements()
		academy_changed.emit()
		save_game(false)


func academy_complete_demo(demo_id: String) -> void:
	if not SmaAcademy.record_demo_completed(academy, demo_id):
		return
	academy_sync_practice()
	academy_changed.emit()
	save_game(false)
	toast_requested.emit(I18n.t("toast.demo_completed"))


func academy_record_financials(ticker: String) -> void:
	if not SmaAcademy.record_financials_viewed(academy, ticker):
		return
	academy_sync_practice()
	academy_changed.emit()
	save_game(false)


func academy_is_tool_unlocked(tool_id: String) -> bool:
	if sandbox_mode:
		return true
	return SmaAcademy.is_tool_unlocked(academy, tool_id)


func multiasset_unlocked() -> bool:
	return sandbox_mode or SmaAcademy.is_unit_complete(academy, "u13")


func academy_mark_language_switched() -> void:
	if bool(academy.get("languageSwitched", false)):
		return
	academy["languageSwitched"] = true
	_sync_achievements()
	academy_changed.emit()


func history_commit() -> void:
	SmaAcademy.record_milestone(academy, "history")
	_sync_achievements()
	save_game(false)
	state_changed.emit("history")


# ---------------------------------------------------------------------------
# Story host interface
# ---------------------------------------------------------------------------

func get_cash() -> float:
	return float(exchange.state["account"]["cash"]) if exchange != null else 0.0


func get_equity() -> float:
	return exchange.equity() if exchange != null else 0.0


func get_position_qty(ticker: String) -> int:
	if exchange == null:
		return 0
	return int(exchange.state["account"]["positions"].get(ticker.to_upper(), {}).get("qty", 0))


func get_trade_count() -> int:
	if exchange == null:
		return 0
	return exchange.state["account"]["trades"].size()


func get_day() -> int:
	return int(exchange.state["dayIndex"]) if exchange != null else 0


func localize(value: Variant) -> String:
	return I18n.resolve(value)


func story_add_cash(amount: float, memo: String = "story") -> void:
	if exchange == null:
		return
	exchange.apply_cash_adjustment(amount, memo)
	state_changed.emit("story_cash")


## Story-driven subscription: a named client really joins the active fund,
## bringing principal and units into the simulated AUM.
func story_add_fund_client(client_name: String, principal: float,
		tag: String = "", risk: String = "medium") -> bool:
	if exchange == null or not is_fund_active():
		return false
	if tag != "":
		for entry in fund.get("clients", []):
			if String(entry.get("storyTag", "")) == tag:
				return false
	var day := int(exchange.state["dayIndex"])
	var candidate_id := "story-client-%d-%d" % [day, fund.get("clients", []).size()]
	var candidates: Array = fund.get("candidates", [])
	for entry in candidates:
		if String(entry.get("id", "")) == candidate_id:
			return false
	var risk_profile := risk if ["low", "medium", "high"].has(risk) else "medium"
	candidates.append({
		"id": candidate_id, "name": client_name, "typeKey": "individual",
		"risk": risk_profile, "horizon": "long", "liquidity": "medium",
		"principal": maxf(1000.0, principal),
	})
	fund["candidates"] = candidates
	var result := SmaFund.accept_client(fund, candidate_id, fund_metrics(), day)
	if not bool(result.get("ok", false)):
		var remaining: Array = []
		for entry in fund.get("candidates", []):
			if String(entry.get("id", "")) != candidate_id:
				remaining.append(entry)
		fund["candidates"] = remaining
		return false
	if tag != "":
		var accepted: Dictionary = result.get("client", {})
		var accepted_id := String(accepted.get("id", ""))
		for entry in fund.get("clients", []):
			if String(entry.get("id", "")) == accepted_id:
				entry["storyTag"] = tag
				break
	state_changed.emit("fund")
	return true


func toast(message: String) -> void:
	toast_requested.emit(message)


func is_unit_complete(unit_id: String) -> bool:
	return SmaAcademy.is_unit_complete(academy, unit_id)


func get_career_rank() -> int:
	return int(career.get("rank", 1))


func is_fund_active() -> bool:
	return String(fund.get("status", "none")) == "active"


func get_fund_drawdown() -> float:
	if not is_fund_active():
		return 0.0
	var m := fund_metrics()
	return float(m.get("drawdown", 0.0))


# ---------------------------------------------------------------------------
# Save / load
# ---------------------------------------------------------------------------

func start_sandbox(cash: float, seed_value: String, difficulty: String) -> Dictionary:
	if sandbox_mode:
		return {"ok": false, "error": "sandbox.errorActive"}
	if started and not save_game(false):
		return {"ok": false, "error": "toast.saveFailed"}
	var safe_difficulty := difficulty if ["easy", "normal", "hard"].has(difficulty) else "normal"
	var commission := 0.0 if safe_difficulty == "easy" else (
		3.0 if safe_difficulty == "hard" else 1.0)
	var safe_cash := clampf(cash, 1000.0, 10000000.0)
	var safe_seed := seed_value.strip_edges().substr(0, 48)
	if safe_seed == "":
		safe_seed = "sandbox-2026"
	sandbox_config = {"cash": safe_cash, "seed": safe_seed,
		"difficulty": safe_difficulty, "commission": commission}
	sandbox_mode = true
	intro = {}
	opening_gap = {}
	opening_gap_active = false
	black_friday = {}
	black_friday_active = false
	exchange = SmaExchange.new(safe_seed, safe_cash, commission)
	academy = SmaAcademy.create_state()
	history = SmaHistoryService.new()
	challenges = SmaChallenges.create_state()
	career = SmaCareer.create_state()
	quant = SmaQuant.default_config()
	fund = SmaFund.create_state()
	alerts = SmaAlerts.create_state()
	office = SmaOffice.create_state()
	narrative = SmaStoryService.new()
	narrative.setup(self)
	narrative.load_content()
	_connect_narrative()
	started = true
	paused = false
	speed = 1
	selected_ticker = "APLA"
	_last_day = 0
	_last_call_id = ""
	_story_pause = false
	_accum = 0.0
	_ui_accum = 0.0
	_autosave_accum = 0.0
	game_started.emit()
	state_changed.emit("sandbox")
	return {"ok": true}


func exit_sandbox() -> void:
	if not sandbox_mode:
		return
	sandbox_mode = false
	daily_sprint_active = false
	daily_sprint_code = ""
	if has_save() and load_game():
		return
	started = false
	exchange = null
	state_changed.emit("sandbox_exit")


# ---------------------------------------------------------------------------
# Pixel Office Renovation & Daily Same-Seed Sprint
# ---------------------------------------------------------------------------

func office_available_rp() -> int:
	return SmaOffice.available_rp(office, academy, career, get_trade_count())


func purchase_office_item(item_id: String) -> Dictionary:
	var result := SmaOffice.purchase(office, item_id, academy, career, get_trade_count())
	if not bool(result.get("ok", false)):
		last_error = String(result.get("error", "office.errorUnknown"))
		return result
	if started and not sandbox_mode:
		save_game(false)
	state_changed.emit("office")
	return result


func toggle_office_item(item_id: String) -> bool:
	var shown := SmaOffice.toggle_visibility(office, item_id)
	if started and not sandbox_mode:
		save_game(false)
	state_changed.emit("office")
	return shown


func start_daily_sprint(raw_code: String = "") -> Dictionary:
	if sandbox_mode:
		exit_sandbox()
	var code := SmaDailyChallenge.sanitize_code(raw_code)
	var seed_val := SmaDailyChallenge.seed_for_code(code)
	var res := start_sandbox(SmaDailyChallenge.START_CASH, seed_val, "normal")
	if not bool(res.get("ok", false)):
		return res
	daily_sprint_active = true
	daily_sprint_code = code
	if narrative != null:
		for sid in narrative.stories.keys():
			narrative.seen[String(sid)] = true
	paused = true
	state_changed.emit("daily")
	return {"ok": true, "code": code, "seed": seed_val}


func daily_sprint_status() -> Dictionary:
	if exchange == null:
		return {}
	var account: Dictionary = exchange.state["account"]
	var total_trades: int = (account.get("trades", []) as Array).size() \
		+ (account.get("optionTrades", []) as Array).size() \
		+ (account.get("futuresTrades", []) as Array).size()
	var eval := SmaDailyChallenge.evaluate(
		SmaDailyChallenge.START_CASH,
		exchange.equity(),
		account.get("equityHistory", []),
		total_trades,
		int(exchange.state["dayIndex"])
	)
	var code := daily_sprint_code if daily_sprint_code != "" else SmaDailyChallenge.today_code()
	eval["code"] = code
	eval["seed"] = SmaDailyChallenge.seed_for_code(code)
	eval["playerName"] = display_player_name()
	return eval


func record_daily_sprint() -> Dictionary:
	var status := daily_sprint_status()
	if status.is_empty():
		return {}
	daily_records = SmaDailyChallenge.record_result(daily_records, status)
	SmaSaveService.export_to(DAILY_RECORDS_PATH, {"records": daily_records})
	state_changed.emit("daily")
	return status


func restart_sandbox() -> void:
	if not sandbox_mode:
		return
	var config := sandbox_config.duplicate(true)
	exit_sandbox()
	start_sandbox(float(config["cash"]), String(config["seed"]),
		String(config["difficulty"]))


func save_now() -> bool:
	return save_game(true)


func save_info() -> Dictionary:
	var path := save_path
	if not SmaSaveService.exists(path) or _keep_save_backup:
		path += ".bak"
	var exists := SmaSaveService.exists(path)
	var modified := 0
	if exists:
		modified = int(FileAccess.get_modified_time(path))
	return {"exists": exists, "modified": modified, "path": path if exists else save_path,
		"bytes": FileAccess.get_size(path) if exists else 0}


func reset_progress() -> void:
	restart()


func export_save(target_path: String) -> bool:
	var payload := SmaSaveService.read(save_path + (".bak" if _keep_save_backup else ""))
	if payload.is_empty() or not SmaSaveService.export_to(target_path, payload):
		return false
	toast_requested.emit(I18n.t("toast.exported"))
	return true


func export_save_web() -> bool:
	if started and not sandbox_mode:
		save_game(false)
	var payload := SmaSaveService.read(save_path + (".bak" if _keep_save_backup else ""))
	if payload.is_empty():
		toast_requested.emit(I18n.t("toast.no_save"))
		return false
	if not SmaWebIo.download_json(payload, "Farview_Save_Slot%d.json" % active_slot):
		return false
	toast_requested.emit(I18n.t("toast.exported"))
	return true


func import_save(source_path: String) -> bool:
	var payload := SmaSaveService.read(source_path)
	return import_save_payload(payload)


func import_save_payload(payload: Dictionary) -> bool:
	var loaded := _decode_save(payload)
	if loaded.is_empty():
		toast_requested.emit(I18n.t("toast.importInvalid"))
		return false
	if not _write_save(payload):
		toast_requested.emit(I18n.t("toast.saveFailed"))
		return false
	_apply_loaded_save(loaded)
	toast_requested.emit(I18n.t("toast.importOk"))
	return true


func import_save_json_text(raw_json: String) -> bool:
	var parsed: Variant = JSON.parse_string(raw_json)
	if typeof(parsed) != TYPE_DICTIONARY:
		toast_requested.emit(I18n.t("toast.importInvalid"))
		return false
	return import_save_payload(parsed as Dictionary)


func has_save() -> bool:
	return SmaSaveService.exists(save_path) or SmaSaveService.exists(save_path + ".bak")


func save_game(manual: bool = true) -> bool:
	if sandbox_mode:
		if manual:
			toast_requested.emit(I18n.t("sandbox.noSave"))
		return false
	if not started or exchange == null:
		return false
	var payload := {
		"version": SAVE_VERSION,
		"savedAt": int(Time.get_unix_time_from_system()),
		"settings": settings,
		"selectedTicker": selected_ticker,
		"exchange": exchange.to_dict(),
		"narrative": narrative.to_dict() if narrative != null else {},
		"academy": academy,
		"history": history.to_dict() if history != null else {},
		"challenges": challenges,
		"career": career,
		"quant": quant,
		"fund": fund,
		"alerts": alerts,
		"office": office,
		"intro": intro,
		"openingGap": opening_gap,
		"blackFriday": black_friday,
	}
	var ok := _write_save(payload)
	if ok:
		game_saved.emit()
		if manual:
			toast_requested.emit(I18n.t("toast.saved"))
	elif manual:
		toast_requested.emit(I18n.t("toast.saveFailed"))
	return ok


func _write_save(payload: Dictionary) -> bool:
	if not SmaSaveService.write(payload, save_path, _keep_save_backup):
		return false
	_keep_save_backup = false
	SmaWebIo.flush_idb()
	return true


func load_game() -> bool:
	var loaded := _decode_save(SmaSaveService.read(save_path))
	_keep_save_backup = loaded.is_empty()
	if _keep_save_backup:
		loaded = _decode_save(SmaSaveService.read(save_path + ".bak"))
	if loaded.is_empty():
		toast_requested.emit(I18n.t("toast.no_save"))
		return false
	_apply_loaded_save(loaded)
	if _keep_save_backup:
		toast_requested.emit(I18n.t("toast.backupLoaded"))
	return true


func _decode_save(payload: Dictionary) -> Dictionary:
	if payload.get("version") != SAVE_VERSION \
			or typeof(payload.get("exchange")) != TYPE_DICTIONARY:
		return {}
	for key in ["settings", "academy", "challenges", "career", "quant", "fund",
			"alerts", "office", "history", "narrative", "intro", "openingGap", "blackFriday"]:
		if typeof(payload.get(key, {})) != TYPE_DICTIONARY:
			return {}
	var saved_story: Dictionary = payload.get("narrative", {})
	var saved_settings: Dictionary = payload.get("settings", {})
	for key in ["locale", "layout", "theme", "colorScheme", "playerName", "displayMode",
			"windowPreset", "uiScale", "chartTimeframe"]:
		if typeof(saved_settings.get(key, "")) != TYPE_STRING:
			return {}
	for key in ["speed", "masterVolume", "musicVolume", "sfxVolume"]:
		if typeof(saved_settings.get(key, 0)) not in [TYPE_INT, TYPE_FLOAT]:
			return {}
	if typeof(payload.get("selectedTicker", "")) != TYPE_STRING:
		return {}
	var saved_intro: Dictionary = payload.get("intro", {})
	if not saved_intro.is_empty():
		for key in ["plan", "receipt", "review"]:
			if typeof(saved_intro.get(key)) != TYPE_DICTIONARY:
				return {}
	var saved_gap: Dictionary = payload.get("openingGap", {})
	if not SmaOpeningGap.is_valid(saved_gap) \
			or (not saved_gap.is_empty() and not bool(saved_intro.get("complete", false))):
		return {}
	var saved_bf: Dictionary = payload.get("blackFriday", {})
	if not SmaBlackFriday.is_valid(saved_bf):
		return {}
	for key in ["flags", "seen"]:
		if typeof(saved_story.get(key, {})) != TYPE_DICTIONARY:
			return {}
	for key in ["history", "queue"]:
		if typeof(saved_story.get(key, [])) != TYPE_ARRAY:
			return {}
	var saved_history: Dictionary = payload.get("history", {})
	if typeof(saved_history.get("runs", {})) != TYPE_DICTIONARY:
		return {}
	for run_data in saved_history.get("runs", {}).values():
		if typeof(run_data) != TYPE_DICTIONARY:
			return {}
	var saved_academy: Dictionary = payload.get("academy", {})
	if typeof(saved_academy.get("units", {})) != TYPE_DICTIONARY:
		return {}
	for unit in saved_academy.get("units", {}).values():
		if typeof(unit) != TYPE_DICTIONARY:
			return {}
	var saved_quant: Dictionary = payload.get("quant", {})
	if typeof(saved_quant.get("params", {})) != TYPE_DICTIONARY:
		return {}
	var engine := SmaExchange.from_dict(payload["exchange"])
	if engine == null:
		return {}
	var saved_day := int(engine.state["dayIndex"])
	var history_service := SmaHistoryService.new()
	history_service.from_dict(saved_history)
	var story_service := SmaStoryService.new()
	story_service.setup(self)
	if not story_service.load_content():
		return {}
	story_service.from_dict(saved_story)
	if story_service.is_active() and story_service.current_node().is_empty():
		return {}
	return {
		"exchange": engine, "history": history_service, "narrative": story_service,
		"academy": SmaAcademy.normalize_state(saved_academy),
		"challenges": SmaChallenges.normalize_state(payload.get("challenges", {})),
		"career": SmaCareer.normalize_state(payload.get("career", {}), saved_day),
		"quant": SmaQuant.normalize_config(saved_quant),
		"fund": SmaFund.normalize_state(payload.get("fund", {}), saved_day, String(engine.state["seed"])),
		"alerts": SmaAlerts.normalize_state(payload.get("alerts", {})),
		"office": SmaOffice.normalize_state(payload.get("office", {})),
		"intro": saved_intro,
		"openingGap": saved_gap,
		"blackFriday": saved_bf,
		"settings": saved_settings, "selectedTicker": payload.get("selectedTicker", INTRO_TICKER),
	}


func _apply_loaded_save(loaded: Dictionary) -> void:
	exchange = loaded["exchange"]
	academy = loaded["academy"]
	challenges = loaded["challenges"]
	career = loaded["career"]
	quant = loaded["quant"]
	fund = loaded["fund"]
	alerts = loaded["alerts"]
	office = loaded.get("office", SmaOffice.create_state())
	daily_sprint_active = false
	daily_sprint_code = ""
	intro = loaded["intro"]
	opening_gap = loaded["openingGap"]
	opening_gap_active = false
	black_friday = loaded.get("blackFriday", {})
	black_friday_active = false
	history = loaded["history"]
	narrative = loaded["narrative"]
	_connect_narrative()
	var saved_settings: Dictionary = loaded["settings"]
	for key in saved_settings.keys():
		settings[key] = saved_settings[key]
	if not bool(saved_settings.get("pixelMigrated", false)):
		settings["theme"] = "pixel"
		settings["pixelMigrated"] = true
	I18n.set_locale(String(settings.get("locale", "zh_CN")))
	SmaUiTheme.set_theme_mode(String(settings.get("theme", "pixel")))
	SmaUiTheme.set_color_scheme(String(settings.get("colorScheme", "intl")))
	_apply_layout(String(settings.get("layout", "beginner")))
	_apply_audio_settings()
	apply_display()
	selected_ticker = String(loaded["selectedTicker"])
	if not exchange.state["companies"].has(selected_ticker):
		selected_ticker = "APLA"
	var known_tickers: Dictionary = exchange.state["companies"]
	var kept_watch: Array = []
	for symbol in alerts["watchlist"]:
		if known_tickers.has(String(symbol)):
			kept_watch.append(String(symbol))
	alerts["watchlist"] = kept_watch
	var kept_alerts: Array = []
	for alert in alerts["alerts"]:
		if known_tickers.has(String(alert.get("ticker", ""))):
			kept_alerts.append(alert)
	alerts["alerts"] = kept_alerts
	started = true
	sandbox_mode = false
	paused = false
	var saved_speed := int(settings.get("speed", 1))
	speed = saved_speed if SPEEDS.has(saved_speed) else 1
	_accum = 0.0
	_ui_accum = 0.0
	_autosave_accum = 0.0
	_last_day = int(exchange.state["dayIndex"])
	_last_call_id = _current_call_id()
	_story_pause = narrative.is_active()
	game_loaded.emit()
	state_changed.emit("loaded")
	if _story_pause:
		story_changed.emit()


func delete_save() -> void:
	SmaSaveService.clear(save_path)
	_keep_save_backup = false
	toast_requested.emit(I18n.t("toast.deleted"))


func select_save_slot(slot: int) -> String:
	active_slot = clampi(slot, 1, SmaSaveService.SLOT_COUNT)
	save_path = SmaSaveService.slot_path(active_slot)
	_keep_save_backup = false
	state_changed.emit("slot")
	return save_path


func save_slots() -> Array:
	return SmaSaveService.list_slots()


func delete_save_slot(slot: int) -> void:
	var path := SmaSaveService.slot_path(slot)
	SmaSaveService.clear(path)
	if path == save_path:
		_keep_save_backup = false
	toast_requested.emit(I18n.t("toast.deleted"))
	state_changed.emit("slot")


func graduation_report() -> Dictionary:
	var equity_now := get_equity()
	var start_cash := float(exchange.state["account"].get("initialCash", START_CASH)) \
		if exchange != null else START_CASH
	var net_return := ((equity_now - start_cash) / start_cash * 100.0) if start_cash > 0.0 else 0.0
	var rev: Dictionary = review_summary() if exchange != null else {}
	var overall := SmaAcademy.overall_progress(academy)
	var branches_done := 0
	for entry in SmaAcademy.branch_units():
		if SmaAcademy.is_unit_complete(academy, String(entry["id"])):
			branches_done += 1
	var rank_num := int(career.get("rank", 1))
	var rank_def := SmaCareer.rank_def(rank_num)
	var certs: Array = career.get("certificates", [])
	var seen_map: Dictionary = narrative.seen if narrative != null else {}
	var flags_map: Dictionary = narrative.flags if narrative != null else {}
	var graduated := is_unit_complete("u32") \
		or bool(seen_map.get("epilogue", false)) \
		or bool(seen_map.get("graduation", false)) \
		or bool(seen_map.get("graduation_unfunded", false))
	var eq_hist: Array = exchange.state["account"].get("equityHistory", []) if exchange != null else []
	var peak := start_cash
	var max_dd := 0.0
	for point in eq_hist:
		var val := float(point.get("equity", start_cash))
		peak = maxf(peak, val)
		if peak > 0.0:
			max_dd = maxf(max_dd, (peak - val) / peak * 100.0)
	if equity_now > 0.0:
		peak = maxf(peak, equity_now)
		max_dd = maxf(max_dd, (peak - equity_now) / peak * 100.0)
	return {
		"version": String(ProjectSettings.get_setting("application/config/version", "beta-06")),
		"playerName": display_player_name(),
		"day": get_day(),
		"date": SmaCalendar.iso_date(get_day()),
		"graduated": graduated,
		"startEquity": start_cash,
		"equity": equity_now,
		"netReturnPct": SmaFormat.round_to(net_return, 2),
		"maxDrawdownPct": SmaFormat.round_to(max_dd, 2),
		"winRatePct": float(rev.get("winRatePct", 0.0)),
		"totalTrades": get_trade_count(),
		"realizedPnl": float(rev.get("realizedPnl", 0.0)),
		"careerRank": rank_num,
		"careerRankKey": String(rank_def.get("titleKey", "career.rank.retail.title")),
		"unitsDone": int(overall.get("completed", 0)),
		"unitsTotal": int(overall.get("total", 32)),
		"branchesDone": branches_done,
		"xp": int(academy.get("xp", 0)),
		"certificatesCount": certs.size(),
		"achievementsCount": academy.get("achievements", []).size(),
		"achievementsTotal": SmaAcademy.ACHIEVEMENTS.size(),
		"storiesSeen": seen_map.size(),
		"storiesTotal": narrative.stories.size() if narrative != null else 16,
		"endingPath": String(flags_map.get("ending_path", "")),
		"crisisChoice": String(flags_map.get("crisis_choice", "")),
		"decisions": flags_map.duplicate(true),
		"fundActive": is_fund_active(),
		"fundName": String(fund.get("name", "")) if is_fund_active() else "",
	}


func export_graduation_report(path: String) -> bool:
	var report := graduation_report()
	var ok := SmaSaveService.export_to(path, report)
	SmaWebIo.flush_idb()
	if ok and SmaWebIo.is_web():
		SmaWebIo.download_json(report, "Farview_Report_Slot%d.json" % active_slot)
	toast_requested.emit(I18n.t("story.reportExported" if ok else "toast.saveFailed"))
	return ok


func _current_call_id() -> String:
	if exchange == null:
		return ""
	var call: Variant = exchange.state["account"]["margin"].get("call", null)
	return String(call.get("id", "")) if call != null else ""
