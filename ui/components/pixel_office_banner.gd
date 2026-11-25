## Animated 16-bit Kairosoft-style pixel trading office diorama (Style B).
## Evolves visually across 3 career tiers:
##   Tier 1 (Rank 1-2): Cozy starter home trading desk with CRT & coffee
##   Tier 2 (Rank 3-4): Farview Academy multi-monitor quant research studio
##   Tier 3 (Rank 5+ / Active Fund): Panoramic "Farview Fund I" trading floor
##     with scrolling live LED ticker tape, dusk skyline, and hired staff sprites.
class_name SmaPixelOfficeBanner
extends Control

const PX := 3

var game: Node
var _anim_accum := 0.0
var _frame := 0
var _tape_scroll := 0.0
var _tape_text := "APLA +0.0%   NVDO +0.0%   MSFY +0.0%   MKT +0.0%"


func _init() -> void:
	custom_minimum_size = Vector2(280, 128)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(game_ref: Node) -> void:
	game = game_ref
	_refresh_tape_text()
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or DisplayServer.get_name() == "headless":
		return
	if game != null and bool(game.settings.get("reducedMotion", false)):
		return
	_anim_accum += delta
	_tape_scroll += delta * 34.0
	if _anim_accum >= 0.28:
		_anim_accum = 0.0
		_frame = (_frame + 1) % 8
		if _frame == 0:
			_refresh_tape_text()
		queue_redraw()


func refresh_state() -> void:
	_refresh_tape_text()
	queue_redraw()


func _refresh_tape_text() -> void:
	if game == null or game.exchange == null:
		return
	var parts: Array[String] = []
	for symbol in ["APLA", "NVDO", "MSFY", "GOGL", "VISO", "MKT"]:
		if not game.exchange.state["companies"].has(symbol):
			continue
		var q: Dictionary = game.exchange.quote(symbol)
		var chg := float(q.get("changePct", 0.0))
		var arrow := "▲" if chg >= 0.0 else "▼"
		parts.append("%s %s %s%s" % [
			symbol, SmaFormat.num(float(q.get("last", 0.0)), 2),
			arrow, SmaFormat.pct_plain(absf(chg), 1),
		])
	if not parts.is_empty():
		_tape_text = "    ".join(parts)


func _px(gx: int, gy: int, gw: int, gh: int, color: Color) -> void:
	draw_rect(Rect2(float(gx * PX), float(gy * PX), float(gw * PX), float(gh * PX)), color)


func _tier() -> int:
	if game == null:
		return 1
	if game.is_fund_active() or int(game.career.get("rank", 1)) >= 5:
		return 3
	if int(game.career.get("rank", 1)) >= 3:
		return 2
	return 1


func _is_alert_state() -> bool:
	if game == null or game.exchange == null:
		return false
	if game.exchange.state["account"]["margin"].get("call", null) != null:
		return true
	if game.is_fund_active() and game.get_fund_drawdown() >= 12.0:
		return true
	return false


func _sky_palette() -> Array[Color]:
	if _is_alert_state():
		return [Color("#3b0a14"), Color("#5c1422"), Color("#7f1d1d")]
	var sec := int(game.exchange.state.get("second", 0)) if (game != null and game.exchange != null) else 0
	var ratio := clampf(float(sec) / 23400.0, 0.0, 1.0)
	if ratio < 0.35:
		return [Color("#1e3a5f"), Color("#2b547e"), Color("#60a5fa")]
	if ratio < 0.72:
		return [Color("#1d4ed8"), Color("#3b82f6"), Color("#93c5fd")]
	return [Color("#311b47"), Color("#6d2859"), Color("#d97706")]


func _draw() -> void:
	var w := int(floor(size.x / float(PX)))
	var h := int(floor(size.y / float(PX)))
	if w < 40 or h < 30:
		return
	var tier := _tier()
	var alert := _is_alert_state()
	var sky := _sky_palette()

	# Outer pixel frame
	var wall_col := Color("#231c2e") if tier == 1 else (Color("#162336") if tier == 2 else Color("#2a2232"))
	if alert:
		wall_col = Color("#2b1219")
	_px(0, 0, w, h, Color("#3b5b7e") if not alert else Color("#f87171"))
	_px(1, 1, w - 2, h - 2, wall_col)

	# Wooden / tiled floor
	var floor_y := h - 10
	_px(1, floor_y, w - 2, 9, Color("#3d2c24") if tier != 2 else Color("#1e293b"))
	_px(1, floor_y, w - 2, 1, Color("#6b4c3b") if tier != 2 else Color("#334155"))
	for fx in range(4, w - 2, 12):
		_px(fx, floor_y + 1, 1, 8, Color("#2b1e19") if tier != 2 else Color("#0f172a"))

	if tier == 1:
		_draw_tier1_home(w, floor_y, sky, alert)
	elif tier == 2:
		_draw_tier2_academy(w, floor_y, sky, alert)
	else:
		_draw_tier3_fund_floor(w, floor_y, sky, alert)

	# Crisp top-left scene badge & LED ticker tape
	_draw_overlays(tier, alert)


func _draw_window(gx: int, gy: int, gw: int, gh: int, sky: Array[Color]) -> void:
	_px(gx - 1, gy - 1, gw + 2, gh + 2, Color("#475569"))
	var band := maxi(1, int(gh / 3))
	_px(gx, gy, gw, band, sky[0])
	_px(gx, gy + band, gw, band, sky[1])
	_px(gx, gy + band * 2, gw, gh - band * 2, sky[2])
	# City skyline silhouettes
	var step := 7
	var idx := 0
	for bx in range(gx + 2, gx + gw - 5, step):
		var bh := 6 + ((idx * 5 + 3) % 10)
		_px(bx, gy + gh - bh, 5, bh, Color("#0f172a"))
		if bh >= 9:
			_px(bx + 1, gy + gh - bh + 2, 1, 1, Color("#fde047"))
			_px(bx + 3, gy + gh - bh + 5, 1, 1, Color("#fde047"))
		idx += 1
	# Window mullion crossbars
	_px(gx + int(gw / 2), gy, 1, gh, Color("#334155"))


func _draw_plant(gx: int, floor_y: int) -> void:
	_px(gx + 1, floor_y - 4, 4, 4, Color("#d4d4d8"))
	_px(gx, floor_y - 5, 6, 1, Color("#a1a1aa"))
	_px(gx + 2, floor_y - 9, 2, 4, Color("#15803d"))
	_px(gx, floor_y - 11, 6, 3, Color("#22c55e"))
	_px(gx + 1, floor_y - 13, 4, 2, Color("#4ade80"))


func _draw_desk_trader(gx: int, floor_y: int, shirt: Color, hair: Color,
		monitors: int, phase_offset: int, alert: bool) -> void:
	var bob := 0 if ((_frame + phase_offset) % 4 < 2) else 1
	# Chair back
	_px(gx + 2, floor_y - 11, 7, 8, Color("#334155"))
	_px(gx + 4, floor_y - 3, 3, 3, Color("#1e293b"))
	# Person torso & head
	_px(gx + 3, floor_y - 13 + bob, 5, 6, shirt)
	_px(gx + 3, floor_y - 18 + bob, 5, 5, Color("#fde2d4"))
	_px(gx + 2, floor_y - 19 + bob, 7, 2, hair)
	_px(gx + 2, floor_y - 17 + bob, 2, 3, hair)
	# Desk
	_px(gx - 3, floor_y - 7, 24, 2, Color("#d97706"))
	_px(gx - 2, floor_y - 5, 22, 5, Color("#78350f"))
	_px(gx + 14, floor_y - 4, 5, 4, Color("#92400e"))
	# Monitors with mini chart glow
	var screen_col := Color("#ef4444") if alert else Color("#22c55e")
	for m in monitors:
		var mx := gx + 9 + m * 6
		_px(mx, floor_y - 14, 6, 6, Color("#0f172a"))
		_px(mx + 1, floor_y - 13, 4, 4, Color("#081c15") if not alert else Color("#2c0b0e"))
		_px(mx + 1, floor_y - 11, 2, 1, screen_col)
		_px(mx + 3, floor_y - 12, 2, 1, screen_col)
		_px(mx + 2, floor_y - 8, 2, 1, Color("#475569"))
	# Steaming coffee mug
	_px(gx - 1, floor_y - 9, 2, 2, Color("#f8fafc"))
	var steam_y := floor_y - 11 - ((_frame + phase_offset) % 2)
	_px(gx - 1, steam_y, 1, 1, Color(1, 1, 1, 0.55))


func _draw_tier1_home(w: int, floor_y: int, sky: Array[Color], alert: bool) -> void:
	# Bookshelf on left
	_px(8, floor_y - 18, 14, 18, Color("#5c3a21"))
	_px(9, floor_y - 16, 12, 4, Color("#3b2314"))
	_px(10, floor_y - 15, 2, 3, Color("#ef4444"))
	_px(13, floor_y - 15, 2, 3, Color("#3b82f6"))
	_px(16, floor_y - 15, 3, 3, Color("#22c55e"))
	_px(9, floor_y - 10, 12, 4, Color("#3b2314"))
	_px(10, floor_y - 9, 3, 3, Color("#eab308"))
	_px(15, floor_y - 9, 2, 3, Color("#a855f7"))
	# Apartment window
	var win_x := maxi(30, int(w * 0.52))
	_draw_window(win_x, 8, mini(46, w - win_x - 10), floor_y - 13, sky)
	# Player desk
	_draw_desk_trader(maxi(28, int(w * 0.25)), floor_y, Color("#2563eb"), Color("#1e293b"), 1, 0, alert)
	_draw_plant(mini(w - 12, win_x + 50), floor_y)


func _draw_tier2_academy(w: int, floor_y: int, sky: Array[Color], alert: bool) -> void:
	# Quant factor whiteboard
	_px(8, 8, 26, 15, Color("#e2e8f0"))
	_px(9, 9, 24, 13, Color("#f8fafc"))
	_px(11, 18, 5, 1, Color("#0d9488"))
	_px(16, 16, 6, 1, Color("#0d9488"))
	_px(22, 13, 7, 1, Color("#0d9488"))
	# Panoramic studio window
	var win_x := 40
	var win_w := maxi(32, w - 76)
	_draw_window(win_x, 8, win_w, floor_y - 13, sky)
	# Blinking server rack on right
	var rx := w - 22
	_px(rx, floor_y - 20, 12, 20, Color("#0f172a"))
	for sy in range(floor_y - 18, floor_y - 3, 4):
		_px(rx + 2, sy, 8, 2, Color("#1e293b"))
		var blink_on := ((_frame + sy) % 3) == 0
		_px(rx + 3, sy, 1, 1, Color("#4ade80") if blink_on else Color("#fbbf24"))
	# Two desks: Trainee + Chen Xi
	_draw_desk_trader(maxi(42, int(w * 0.26)), floor_y, Color("#2563eb"), Color("#1e293b"), 2, 0, alert)
	if w > 120:
		_draw_desk_trader(int(w * 0.56), floor_y, Color("#0d9488"), Color("#0f172a"), 2, 2, alert)
	_draw_plant(33, floor_y)


func _draw_tier3_fund_floor(w: int, floor_y: int, sky: Array[Color], alert: bool) -> void:
	# Wall plaque backdrop on left
	_px(6, 5, 42, 11, Color("#f1f5f9"))
	_px(7, 6, 40, 9, Color("#cbd5e1"))
	# Panoramic skyline windows behind LED ticker
	var win_start := 54
	var win_total := maxi(36, w - win_start - 8)
	var half_w := maxi(16, int((win_total - 4) / 2))
	_draw_window(win_start, 11, half_w, floor_y - 15, sky)
	if win_start + half_w + 4 + half_w < w - 4:
		_draw_window(win_start + half_w + 4, 11, half_w, floor_y - 15, sky)
	# LED ticker strip bar above windows
	_px(win_start, 4, win_total, 5, Color("#05080f"))
	# Desks populated by player + hired fund team!
	var team_count := 2
	if game != null and game.is_fund_active():
		team_count = clampi(1 + int(game.fund.get("team", []).size()), 2, 4)
	var palettes := [
		[Color("#2563eb"), Color("#1e293b")],
		[Color("#0d9488"), Color("#0f172a")],
		[Color("#7c3aed"), Color("#3b1d0e")],
		[Color("#d97706"), Color("#1f2937")],
	]
	var usable_w := maxi(60, w - 26)
	var spacing := maxi(28, int(usable_w / maxi(1, team_count)))
	for i in team_count:
		var dx := 12 + i * spacing
		if dx + 22 > w - 6:
			break
		var pal: Array = palettes[i % palettes.size()]
		_draw_desk_trader(dx, floor_y, pal[0], pal[1], 2 if i == 0 else 1, i * 2, alert)
	_draw_plant(4, floor_y)
	if w > 100:
		_draw_plant(w - 10, floor_y)


func _draw_overlays(tier: int, alert: bool) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var title_str := I18n.t("pixelOffice.tier1")
	if tier == 2:
		title_str = I18n.t("pixelOffice.tier2")
	elif tier == 3:
		title_str = String(game.fund.get("name", I18n.t("fund.defaultName"))) \
			if (game != null and game.is_fund_active()) else I18n.t("pixelOffice.tier3")
	if tier == 3:
		draw_string(font, Vector2(24, 34), title_str.left(14), HORIZONTAL_ALIGNMENT_LEFT,
			116, 11, Color("#0f172a"))
		# Scrolling LED ticker text inside the dark LED bar
		var led_x := float(54 * PX)
		var led_w := maxf(80.0, size.x - led_x - float(10 * PX))
		var shift := fmod(_tape_scroll, maxf(120.0, float(_tape_text.length() * 7)))
		var led_col := SmaUiTheme.NEGATIVE if alert else SmaUiTheme.POSITIVE
		var visible_chars := maxi(12, int(led_w / 6.8))
		var char_offset := int(floor(shift / 7.0)) % maxi(1, _tape_text.length())
		var looped := (_tape_text + "    " + _tape_text).substr(char_offset, visible_chars)
		draw_string(font, Vector2(led_x + 4.0, 24.0), looped, HORIZONTAL_ALIGNMENT_LEFT,
			led_w - 8.0, 10, led_col)
	else:
		draw_rect(Rect2(10, 8, 196, 18), Color(0.03, 0.05, 0.09, 0.82))
		draw_string(font, Vector2(16, 21), title_str, HORIZONTAL_ALIGNMENT_LEFT,
			186, 11, SmaUiTheme.ACCENT)
	# Status pill on top right
	var clock_str := SmaCalendar.session_clock(int(game.exchange.state["second"])) \
		if (game != null and game.exchange != null) else "09:30:00"
	var status_str := I18n.t("pixelOffice.alert") if alert else (
		"%s · %s" % [
			I18n.t("header.marketOpen" if (game != null and game.is_market_open()) else "header.marketClosed"),
			clock_str,
		])
	var badge_w := 156.0
	var badge_x := size.x - badge_w - 10.0
	if tier < 3 and badge_x > 210.0:
		draw_rect(Rect2(badge_x, 8, badge_w, 18), Color(0.03, 0.05, 0.09, 0.85))
		draw_string(font, Vector2(badge_x + 6.0, 21.0), status_str, HORIZONTAL_ALIGNMENT_RIGHT,
			badge_w - 12.0, 10, SmaUiTheme.NEGATIVE if alert else SmaUiTheme.WARNING)
