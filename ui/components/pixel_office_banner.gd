## Animated 16-bit Kairosoft + PC-98 pixel trading room diorama (Style B).
## Renders crisp 2x pixel-grid architecture, Bayer-dithered twilight city skyline,
## live colored LED stock ticker tape, 1px-outlined chibi traders & analysts at
## multi-monitor desks, and a live Mentor Pixel Tip Bubble on the right.
class_name SmaPixelOfficeBanner
extends Control

const PX := 2
const INK := Color("#090d16")
const BAYER4 := [
	[0, 8, 2, 10],
	[12, 4, 14, 6],
	[3, 11, 1, 9],
	[15, 7, 13, 5],
]

const PLANT_SPRITE := [
	"....kkkk....",
	"..kkGGGGkk..",
	".kGGggggGGk.",
	"kGGgkkkkggGk",
	".kGgkGGkggk.",
	"kkggkGGkggkk",
	"kGGggggggGGk",
	".kggggggggk.",
	"..kkeeeeekk.",
	"...keeeeek..",
	"..kkkkkkkk..",
	".kwwwwwwwwk.",
	".kssssssssk.",
	"..kwwwwwwk..",
	"..kssssssk..",
	"...kkkkkk...",
]

const ANALYST_FEMALE := [
	"....kkkkkk....",
	"..kkHHHHHHkk..",
	".kHHhHHHHhHHk.",
	"kHHhHhhhhHhHHk",
	"kHhhksssskhhHk",
	"kHhkswwwwskhHk",
	"kHhkswkkwskhHk",
	"kHhksssssskhHk",
	".kHkssmmsskhk.",
	"..kkksssskkk..",
	"..kBBBBBBBBk..",
	".kBBbwwwwbBBk.",
	".kBBbttttbBBk.",
	".kBBbttttbBBk.",
	"..ksskkkkssk..",
	"..kCCCCCCCCk..",
	"..kddddddddk..",
	"...kss..ssk...",
	"...kss..ssk...",
	"...kkk..kkk...",
]

const ANALYST_MALE := [
	"....kkkkkk....",
	"...kHHHHHHk...",
	"..kHHhHHhHHk..",
	"..kHhhhhhhHk..",
	"..kssssssssk..",
	"..kswksskwsk..",
	"..kswksskwsk..",
	"..kssssssssk..",
	"...kssmmssk...",
	"...kkkkkkkk...",
	"..kWWWWWWWWk..",
	".kWWwTTTTwWWk.",
	".kWWwTTTTwWWk.",
	".kWWssWWssWWk.",
	"..kddddddddk..",
	"..kddddddddk..",
	"...kdd..ddk...",
	"...kdd..ddk...",
	"...kkk..kkk...",
]

const TRADER_SEATED := [
	"....kkkkkk....",
	"...kHHHHHHk...",
	"..kHHhHHHHHk..",
	"..kHhhhhhhHk..",
	"..kHhhhhhhss..",
	"...khhhhhssk..",
	"....kkkksssk..",
	"..kkSSSSSSkk..",
	".kSSsSSSSsSSk.",
	".kCCCCCCCCCCk.",
	"kCCccccccccCCk",
	"kCCccccccccCCk",
	"kCCccccccccCCk",
	".kCCCCCCCCCCk.",
	"..kkkkkkkkkk..",
	"....kddddk....",
	"...kddddddk...",
	"..kkkkkkkkkk..",
]

var game: Node
var _screen_id := "market"
var _anim_accum := 0.0
var _frame := 0
var _tape_scroll := 0.0
var _tape_items: Array[Dictionary] = []
var _portrait_cache: Dictionary = {}


func _init() -> void:
	custom_minimum_size = Vector2(280, 118)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func setup(game_ref: Node) -> void:
	game = game_ref
	_refresh_tape()
	queue_redraw()


func set_screen(screen_id: String) -> void:
	if _screen_id == screen_id:
		return
	_screen_id = screen_id
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or DisplayServer.get_name() == "headless":
		return
	if game != null and bool(game.settings.get("reducedMotion", false)):
		return
	_anim_accum += delta
	_tape_scroll += delta * 38.0
	if _anim_accum >= 0.16:
		_anim_accum = 0.0
		_frame = (_frame + 1) % 16
		if _frame % 8 == 0:
			_refresh_tape()
		queue_redraw()


func refresh_state() -> void:
	_refresh_tape()
	queue_redraw()


func _refresh_tape() -> void:
	_tape_items.clear()
	if game == null or game.exchange == null:
		for sym in [["APLA", 182.40, 2.1], ["NVDO", 95.36, 2.4], ["MSFY", 39.20, -0.9], ["MKT", 100.8, 0.8]]:
			_tape_items.append({"sym": sym[0], "price": sym[1], "chg": sym[2]})
		return
	for symbol in ["APLA", "NVDO", "MSFY", "GOGL", "AMZN", "VISO", "MKT"]:
		if not game.exchange.state["companies"].has(symbol):
			continue
		var q: Dictionary = game.exchange.quote(symbol)
		_tape_items.append({
			"sym": symbol,
			"price": float(q.get("last", 0.0)),
			"chg": float(q.get("changePct", 0.0)),
		})


func _px(gx: int, gy: int, gw: int, gh: int, color: Color) -> void:
	draw_rect(Rect2(float(gx * PX), float(gy * PX), float(gw * PX), float(gh * PX)), color)


func _draw_sprite(gx: int, gy: int, rows: Array, pal: Dictionary) -> void:
	for r in rows.size():
		var line := String(rows[r])
		var run_ch := ""
		var run_start := 0
		for c in line.length():
			var ch := line.substr(c, 1)
			if ch != run_ch:
				if run_ch != "" and run_ch != "." and pal.has(run_ch):
					_px(gx + run_start, gy + r, c - run_start, 1, pal[run_ch])
				run_ch = ch
				run_start = c
		if run_ch != "" and run_ch != "." and pal.has(run_ch):
			_px(gx + run_start, gy + r, line.length() - run_start, 1, pal[run_ch])


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


func _sky_bands(alert: bool) -> Array[Color]:
	if alert:
		return [Color("#2b0912"), Color("#4c0f1d"), Color("#7f1d1d"), Color("#b91c1c"), Color("#ef4444")]
	var sec := int(game.exchange.state.get("second", 0)) if (game != null and game.exchange != null) else 0
	var ratio := clampf(float(sec) / 23400.0, 0.0, 1.0)
	if ratio < 0.35:
		# Vibrant violet-rose-amber market-open sunrise (matching Reference B's warm skyline)
		return [Color("#2d1f54"), Color("#5f2f6e"), Color("#a1496b"), Color("#de7b54"), Color("#f6b969")]
	if ratio < 0.68:
		# Crisp mid-session azure & warm horizon
		return [Color("#1e3468"), Color("#2f5899"), Color("#5185c4"), Color("#94bbe3"), Color("#f5cfa0")]
	# Golden-purple closing bell dusk
	return [Color("#241740"), Color("#4e2361"), Color("#8f3566"), Color("#d46548"), Color("#f59e0b")]


func _draw() -> void:
	var w := int(floor(size.x / float(PX)))
	var h := int(floor(size.y / float(PX)))
	if w < 80 or h < 45:
		return
	var tier := _tier()
	var alert := _is_alert_state()
	var sky := _sky_bands(alert)
	var floor_y := h - 7

	# 1. Outer frame & warm studio wall (matching Reference B's warm cream & slate interior)
	var wall_col := Color("#ead8b8") if not alert else Color("#3b1c24")
	var wall_trim := Color("#d1bc97") if not alert else Color("#592633")
	_px(0, 0, w, h, INK)
	_px(1, 1, w - 2, floor_y - 1, wall_col)
	_px(1, floor_y - 4, w - 2, 4, wall_trim)
	_px(1, floor_y - 4, w - 2, 1, Color("#bfa57d") if not alert else Color("#7f1d1d"))

	# 2. Left architectural zone: Elevator / Bookshelf + Hanging Academy/Fund Banner
	var win_x := mini(168, maxi(124, int(w * 0.27)))
	_draw_left_zone(tier, win_x, floor_y, alert)

	# 3. Right panoramic zone: Recessed LED Ticker Bar + Bayer-Dithered Skyline Windows
	var win_total_w := maxi(60, w - win_x - 3)
	_draw_led_and_windows(win_x, win_total_w, floor_y, sky, alert)

	# 4. Warm wooden floor & bottom beam divider
	_px(1, floor_y, w - 2, h - floor_y - 1, Color("#6b4226"))
	_px(1, floor_y, w - 2, 1, INK)
	_px(1, floor_y + 1, w - 2, 1, Color("#9c6640"))
	_px(1, h - 2, w - 2, 1, Color("#3d2312"))
	for gx in range(8, w - 4, 22):
		_px(gx, floor_y + 2, 1, h - floor_y - 4, Color("#4a2c18"))

	# 5. Desks, monitors, plants & animated 1px-outlined chibi staff
	_draw_floor_actors(tier, win_x, w, floor_y, alert)

	# 6. Dynamic text overlays (Banner title, scrolling colored LED quotes, Mentor tip bubble)
	_draw_text_and_mentor_overlay(tier, win_x, win_total_w, alert)


func _draw_left_zone(tier: int, win_x: int, floor_y: int, alert: bool) -> void:
	# Hanging white/cream cloth banner with pixel pins (like "FARVIEW FUND I" in Reference B)
	var bx := 26
	var bw := maxi(80, win_x - bx - 10)
	var by := 4
	var bh := 15
	# Corner pins & cords
	_px(bx - 1, by - 1, 3, 3, INK)
	_px(bx, by, 1, 1, Color("#94a3b8"))
	_px(bx + bw - 2, by - 1, 3, 3, INK)
	_px(bx + bw - 1, by, 1, 1, Color("#94a3b8"))
	# Banner body with notched outline & cloth shadow
	_px(bx, by + 1, bw, bh, INK)
	_px(bx + 1, by + 2, bw - 2, bh - 2, Color("#f8fafc") if not alert else Color("#fee2e2"))
	_px(bx + 1, by + bh - 2, bw - 2, 1, Color("#cbd5e1"))
	_px(bx + 2, by + 3, bw - 4, 1, Color("#e2e8f0"))

	# Far-left prop: Silver Elevator (Tier 2/3) or Cozy Bookshelf (Tier 1)
	if tier >= 2:
		var ex := 4
		var ey := 20
		var ew := 18
		var eh := floor_y - ey
		_px(ex, ey, ew, eh, INK)
		_px(ex + 1, ey + 1, ew - 2, eh - 1, Color("#64748b"))
		_px(ex + 2, ey + 2, ew - 4, eh - 2, Color("#94a3b8"))
		_px(ex + int(ew / 2), ey + 2, 1, eh - 2, Color("#334155"))
		_px(ex + 3, ey + 3, 2, eh - 5, Color("#cbd5e1"))
		# Elevator floor LED
		_px(ex + 7, ey - 3, 4, 2, INK)
		_px(ex + 8, ey - 2, 2, 1, Color("#4ade80") if not alert else Color("#ef4444"))
		# Framed Gold Award Plaque beside elevator
		_px(ex + ew + 4, ey + 2, 12, 10, INK)
		_px(ex + ew + 5, ey + 3, 10, 8, Color("#fbbf24"))
		_px(ex + ew + 6, ey + 4, 8, 6, Color("#1e293b"))
		_px(ex + ew + 7, ey + 6, 6, 2, Color("#5eead4"))
	else:
		var sx := 4
		var sy := 23
		var sw := 18
		var sh := floor_y - sy
		_px(sx, sy, sw, sh, INK)
		_px(sx + 1, sy + 1, sw - 2, sh - 1, Color("#784421"))
		_px(sx + 2, sy + 2, sw - 4, 1, Color("#a36236"))
		for shelf_y in [sy + 4, sy + 12, sy + 20]:
			if shelf_y + 5 >= floor_y:
				break
			_px(sx + 2, shelf_y, sw - 4, 6, Color("#3d210f"))
			var book_cols := [Color("#ef4444"), Color("#3b82f6"), Color("#22c55e"), Color("#fbbf24"), Color("#a855f7")]
			for bi in 4:
				_px(sx + 3 + bi * 3, shelf_y + 1, 2, 5, book_cols[(bi + shelf_y) % book_cols.size()])


func _draw_led_and_windows(win_x: int, total_w: int, floor_y: int, sky: Array[Color], alert: bool) -> void:
	# Recessed dark LED ticker strip across the top of the windows
	var led_y := 3
	var led_h := 10
	_px(win_x, led_y, total_w, led_h, INK)
	_px(win_x + 1, led_y + 1, total_w - 2, led_h - 2, Color("#070b12"))
	_px(win_x + 1, led_y + led_h - 2, total_w - 2, 1, Color("#334155"))

	# Panoramic window frame below LED bar
	var wy := led_y + led_h
	var wh := floor_y - wy
	_px(win_x, wy, total_w, wh, INK)
	_px(win_x + 1, wy + 1, total_w - 2, wh - 1, Color("#2f3346"))

	var inner_x := win_x + 3
	var inner_y := wy + 3
	var inner_w := total_w - 6
	var inner_h := wh - 4
	if inner_w <= 8 or inner_h <= 8:
		return

	# Bayer 4x4 ordered-dithered sky gradient
	var n_bands := sky.size() - 1
	for ry in inner_h:
		var t := float(ry) / float(maxi(1, inner_h - 1)) * float(n_bands)
		var bi := mini(n_bands - 1, int(floor(t)))
		var frac := t - float(bi)
		var c_a: Color = sky[bi]
		var c_b: Color = sky[bi + 1]
		if frac < 0.15:
			_px(inner_x, inner_y + ry, inner_w, 1, c_a)
		elif frac > 0.85:
			_px(inner_x, inner_y + ry, inner_w, 1, c_b)
		else:
			var bayer_row: Array = BAYER4[ry % 4]
			var thresh := int(frac * 16.0)
			var run_col := c_b if int(bayer_row[0]) < thresh else c_a
			var run_start := 0
			for rx in inner_w:
				var c_cur := c_b if int(bayer_row[rx % 4]) < thresh else c_a
				if c_cur != run_col:
					_px(inner_x + run_start, inner_y + ry, rx - run_start, 1, run_col)
					run_col = c_cur
					run_start = rx
			_px(inner_x + run_start, inner_y + ry, inner_w - run_start, 1, run_col)

	# Distant skyline layer
	var back_col := sky[0].lerp(Color("#1a1433"), 0.55)
	var bx := inner_x + 2
	var b_idx := 0
	while bx < inner_x + inner_w - 10:
		var bw := 10 + (b_idx * 5) % 9
		var bh := 12 + (b_idx * 7 + 3) % 16
		_px(bx, inner_y + inner_h - bh, bw, bh, back_col)
		bx += bw + 2
		b_idx += 1

	# Foreground 3D skyscraper silhouettes with lit yellow/cyan pixel windows
	var front_col := Color("#23193d") if not alert else Color("#280911")
	var front_hi := Color("#3b2c5e") if not alert else Color("#4c1220")
	var fx := inner_x + 6
	var f_idx := 0
	while fx < inner_x + inner_w - 12:
		var fw := 11 + (f_idx * 7) % 10
		var fh := 10 + (f_idx * 11 + 5) % 20
		var fy := inner_y + inner_h - fh
		_px(fx, fy, fw, fh, front_col)
		_px(fx, fy, 2, fh, front_hi)
		if f_idx % 3 == 0 and fy - 4 > inner_y:
			_px(fx + int(fw / 2), fy - 4, 1, 4, front_hi)
		for wy_lit in range(fy + 3, inner_y + inner_h - 2, 4):
			for wx_lit in range(fx + 3, fx + fw - 2, 3):
				if ((wx_lit + wy_lit + f_idx) % 3) != 0:
					var win_lit := Color("#fde047") if ((wx_lit + f_idx) % 4 != 0) else Color("#67e8f9")
					_px(wx_lit, wy_lit, 1, 2, win_lit)
		fx += fw + 6
		f_idx += 1

	# Subtle 45-degree glass sheen streaks across windowpanes
	var sheen := Color(1.0, 1.0, 1.0, 0.08)
	for s_off in range(14, inner_w - 20, 56):
		for ry in inner_h:
			var sx := inner_x + s_off - int(ry * 0.6)
			if sx >= inner_x and sx + 5 < inner_x + inner_w:
				_px(sx, inner_y + ry, 4, 1, sheen)

	# Vertical steel window mullions (3-4 panes like Reference B)
	var panes := 3 if inner_w > 180 else 2
	var pane_w := int(inner_w / panes)
	for p_i in range(1, panes):
		var mx := inner_x + p_i * pane_w
		_px(mx - 1, wy + 1, 3, wh - 1, INK)
		_px(mx, wy + 1, 1, wh - 1, Color("#475569"))


func _draw_monitor(gx: int, gy: int, gw: int, gh: int, alert: bool, seed_off: int) -> void:
	_px(gx, gy, gw, gh, INK)
	_px(gx + 1, gy + 1, gw - 2, gh - 2, Color("#334155"))
	_px(gx + 2, gy + 2, gw - 4, gh - 4, Color("#061310") if not alert else Color("#24080d"))
	# Mini candlestick chart inside monitor
	var up_col := Color("#4ade80") if not alert else Color("#f87171")
	var dn_col := Color("#f87171")
	var cols := maxi(2, gw - 5)
	for ci in cols:
		if ci % 2 == 1:
			continue
		var step := ((ci + (_frame / 2) + seed_off) % 5)
		var cy := gy + gh - 4 - mini(gh - 6, step)
		var ch := clampi(2 + (step % 2), 1, maxi(1, gh - 5))
		_px(gx + 2 + ci, clampi(cy, gy + 2, gy + gh - 4), 1,
			mini(ch, gy + gh - 3 - clampi(cy, gy + 2, gy + gh - 4)),
			up_col if ((ci + seed_off) % 4 != 0) else dn_col)


func _draw_workstation_left(gx: int, floor_y: int, quad: bool, alert: bool) -> void:
	var desk_y := floor_y - 12
	var desk_w := 56
	# Monitors on left half of desk
	if quad:
		_draw_monitor(gx + 6, desk_y - 20, 14, 10, alert, 0)
		_draw_monitor(gx + 21, desk_y - 20, 14, 10, alert, 2)
	_draw_monitor(gx + 6, desk_y - 10, 14, 10, alert, 1)
	_draw_monitor(gx + 21, desk_y - 10, 14, 10, alert, 3)
	_px(gx + 12, desk_y - 1, 3, 1, INK)
	_px(gx + 27, desk_y - 1, 3, 1, INK)

	# Steaming coffee mug on right side of desk
	_px(gx + 47, desk_y - 4, 4, 4, INK)
	_px(gx + 48, desk_y - 3, 2, 3, Color("#f8fafc"))
	var steam_shift := (_frame / 2) % 3
	_px(gx + 48 + (steam_shift % 2), desk_y - 6 - steam_shift, 1, 1, Color(1, 1, 1, 0.65))

	# Wooden desk with drawers & under-desk PC tower
	_px(gx, desk_y, desk_w, 3, INK)
	_px(gx + 1, desk_y + 1, desk_w - 2, 1, Color("#d98a4e"))
	_px(gx + 1, desk_y + 2, desk_w - 2, 1, Color("#9a582b"))
	# Legs & drawer cabinet
	_px(gx + 2, desk_y + 3, 2, 9, INK)
	_px(gx + 5, desk_y + 4, 7, 8, INK)
	_px(gx + 6, desk_y + 5, 5, 7, Color("#334155"))
	_px(gx + 7, desk_y + 6, 1, 1, Color("#4ade80") if (_frame % 4 != 0) else Color("#fbbf24"))
	_px(gx + 41, desk_y + 3, 13, 9, INK)
	_px(gx + 42, desk_y + 4, 11, 8, Color("#b8733e"))
	_px(gx + 42, desk_y + 7, 11, 1, INK)
	_px(gx + 46, desk_y + 5, 3, 1, Color("#5c3116"))
	_px(gx + 46, desk_y + 9, 3, 1, Color("#5c3116"))

	# Seated chibi trader (player) in ergonomic swivel chair
	var bob := 0 if (_frame % 8 < 4) else 1
	var t_pal := {
		"k": INK,
		"H": Color("#4a2c18"), "h": Color("#6e4326"),
		"s": Color("#fcd5b8"),
		"S": Color("#e2e8f0"),
		"C": Color("#1e293b"), "c": Color("#334155"),
		"d": Color("#0f172a"),
	}
	_draw_sprite(gx + 24, floor_y - 18 + bob, TRADER_SEATED, t_pal)


func _draw_center_analysts(gx: int, floor_y: int, include_male: bool, alert: bool) -> void:
	var desk_y := floor_y - 12
	var desk_w := 74 if include_male else 38
	# Monitors behind desk
	_draw_monitor(gx + 22, desk_y - 11, 14, 10, alert, 4)
	_px(gx + 28, desk_y - 1, 2, 1, INK)
	if include_male:
		_draw_monitor(gx + 37, desk_y - 11, 14, 10, alert, 6)
		_px(gx + 43, desk_y - 1, 2, 1, INK)

	# Desk surface & legs
	_px(gx + 12, desk_y, desk_w, 3, INK)
	_px(gx + 13, desk_y + 1, desk_w - 2, 1, Color("#d98a4e"))
	_px(gx + 13, desk_y + 2, desk_w - 2, 1, Color("#9a582b"))
	_px(gx + 14, desk_y + 3, 2, 9, INK)
	_px(gx + 12 + desk_w - 4, desk_y + 3, 2, 9, INK)
	if include_male:
		_px(gx + 46, desk_y + 3, 2, 9, INK)

	# Female analyst (Lin Lan / Research mentor) with tablet
	var blink_f := (_frame == 7)
	var f_pal := {
		"k": INK,
		"H": Color("#5c3324"), "h": Color("#824b37"),
		"s": Color("#fcd5b8"),
		"w": Color("#fcd5b8") if blink_f else Color("#ffffff"),
		"m": Color("#c26d68"),
		"B": Color("#94a3b8"), "b": Color("#cbd5e1"),
		"t": Color("#475569"),
		"C": Color("#1e3a5f"), "d": Color("#1e293b"),
	}
	_draw_sprite(gx + 2, floor_y - 20, ANALYST_FEMALE, f_pal)

	if include_male:
		var blink_m := (_frame == 13)
		var m_pal := {
			"k": INK,
			"H": Color("#1e293b"), "h": Color("#334155"),
			"s": Color("#d69e76"),
			"w": Color("#d69e76") if blink_m else Color("#ffffff"),
			"m": Color("#8c583a"),
			"W": Color("#f8fafc"),
			"T": Color("#2563eb"),
			"d": Color("#1e293b"),
		}
		_draw_sprite(gx + 54, floor_y - 19, ANALYST_MALE, m_pal)


func _draw_floor_actors(tier: int, win_x: int, w: int, floor_y: int, alert: bool) -> void:
	var plant_pal := {
		"k": INK,
		"G": Color("#86efac"), "g": Color("#22c55e"), "e": Color("#15803d"),
		"w": Color("#f8fafc"), "s": Color("#cbd5e1"),
	}
	# Left workstation (Player's desk)
	var left_desk_x := maxi(26, win_x - 74)
	_draw_workstation_left(left_desk_x, floor_y, tier >= 2, alert)

	# Potted plant separating left wall & window
	if win_x + 4 < w - 30:
		_draw_sprite(win_x - 14, floor_y - 16, PLANT_SPRITE, plant_pal)

	# Center analyst desk in front of panoramic window (Lin Lan + Gu Yan)
	var center_x := win_x + 16
	if center_x + 48 < w - 20:
		_draw_center_analysts(center_x, floor_y, center_x + 92 < w - 24, alert)

	# Right workstation on wide trading floors (Chen Xi / Quant Trader)
	var right_reserve := 136 if w >= 420 else 18
	var third_x := center_x + 104
	if third_x + 58 < w - right_reserve:
		_draw_workstation_left(third_x, floor_y, tier >= 3, alert)

	# Far-right plant
	if w - right_reserve - 16 > center_x + 56:
		_draw_sprite(w - right_reserve - 14, floor_y - 16, PLANT_SPRITE, plant_pal)


func _mentor_tip_info(alert: bool) -> Dictionary:
	if alert:
		return {"char": "gu_yan", "tip": I18n.t("pixelOffice.alert")}
	match _screen_id:
		"options", "futures":
			return {"char": "lao_chen", "tip": I18n.t("pixelOffice.tipOptions")}
		"quant", "screener", "statements", "earnings":
			return {"char": "chen_xi", "tip": I18n.t("pixelOffice.tipQuant")}
		"academy", "challenges":
			return {"char": "lin_lan", "tip": I18n.t("pixelOffice.tipAcademy")}
		"career", "fund":
			return {"char": "su_he", "tip": I18n.t("pixelOffice.tipFund")}
		"portfolio", "tax", "multiasset", "etf":
			return {"char": "gu_yan", "tip": I18n.t("pixelOffice.tipPortfolio")}
		"trade":
			if game != null and game.started and game.has_intro_task():
				return {"char": "lin_lan", "tip": I18n.t("pixelOffice.tipIntro")}
			return {"char": "lin_lan", "tip": I18n.t("pixelOffice.tipTrade")}
	if game != null and game.started:
		if game.has_intro_task():
			return {"char": "lin_lan", "tip": I18n.t("pixelOffice.tipIntro")}
		if game.is_fund_active():
			return {"char": "su_he", "tip": I18n.t("pixelOffice.tipFund")}
		if game.exchange != null:
			var idx_chg := float(game.market_index_change())
			if idx_chg >= 0.8:
				return {"char": "lin_lan", "tip": I18n.t("pixelOffice.tipBull")}
			if idx_chg <= -0.8:
				return {"char": "gu_yan", "tip": I18n.t("pixelOffice.tipBear")}
	return {"char": "lin_lan", "tip": I18n.t("pixelOffice.tipDefault")}


func _load_portrait(char_id: String) -> Texture2D:
	if _portrait_cache.has(char_id):
		return _portrait_cache[char_id]
	var path := "res://assets/portraits/pixel/%s.png" % char_id
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			_portrait_cache[char_id] = tex
			return tex
	return null


func _draw_text_and_mentor_overlay(tier: int, win_x: int, win_total_w: int, alert: bool) -> void:
	var font12 := SmaUiTheme.pixel_font_12()
	var font10 := SmaUiTheme.pixel_font_10()
	if font12 == null:
		return

	# 1. Hanging cloth banner title on left wall
	var title_str := I18n.t("pixelOffice.tier1")
	if tier == 2:
		title_str = I18n.t("pixelOffice.tier2")
	elif tier == 3:
		title_str = String(game.fund.get("name", I18n.t("fund.defaultName"))) \
			if (game != null and game.is_fund_active()) else I18n.t("pixelOffice.tier3")
	var banner_px_x := float(28 * PX)
	var banner_px_w := float(maxi(76, win_x - 38) * PX)
	draw_string(font12, Vector2(banner_px_x, float(14 * PX)), title_str,
		HORIZONTAL_ALIGNMENT_CENTER, banner_px_w, 12,
		Color("#1e293b") if not alert else Color("#991b1b"))

	# 2. Live colored scrolling LED stock ticker tape inside recessed dark LED bar
	var led_left := float((win_x + 3) * PX)
	var led_right := float((win_x + win_total_w - 3) * PX)
	var led_width := maxf(40.0, led_right - led_left)
	if not _tape_items.is_empty():
		var item_stride := 138.0
		var cycle_w := maxf(led_width, float(_tape_items.size()) * item_stride)
		var base_shift := fmod(_tape_scroll, cycle_w)
		var copies := 2
		for copy_idx in copies:
			for idx in _tape_items.size():
				var item: Dictionary = _tape_items[idx]
				var draw_x := led_left + float(idx) * item_stride + float(copy_idx) * cycle_w - base_shift
				if draw_x + 128.0 < led_left + 4.0 or draw_x > led_right - 96.0:
					continue
				if draw_x < led_left + 2.0:
					continue
				var chg := float(item["chg"])
				var arrow := "▲" if chg >= 0.0 else "▼"
				var seg := "%s %s %s%s" % [
					String(item["sym"]),
					SmaFormat.num(float(item["price"]), 2),
					arrow,
					SmaFormat.pct_plain(absf(chg), 1),
				]
				var col := SmaUiTheme.POSITIVE if chg >= 0.0 else SmaUiTheme.NEGATIVE
				if alert:
					col = SmaUiTheme.NEGATIVE
				draw_string(font12, Vector2(roundf(draw_x), float(10 * PX)), seg,
					HORIZONTAL_ALIGNMENT_LEFT, minf(132.0, led_right - draw_x), 12, col)

	# 3. Mentor Pixel Tip Bubble + Chibi Portrait Avatar in bottom-right corner (Reference B!)
	if size.x >= 840.0:
		var info := _mentor_tip_info(alert)
		var tip_text := String(info["tip"])
		var tex := _load_portrait(String(info["char"]))
		var avatar_size := 48.0
		var avatar_x := size.x - avatar_size - 12.0
		var avatar_y := size.y - avatar_size - 16.0
		var bubble_w := 196.0
		var bubble_h := 40.0
		var bubble_x := avatar_x - bubble_w - 8.0
		var bubble_y := avatar_y + 4.0

		# Cream speech bubble with crisp 2px pixel outline
		draw_rect(Rect2(bubble_x - 2, bubble_y - 2, bubble_w + 4, bubble_h + 4), INK)
		draw_rect(Rect2(bubble_x, bubble_y, bubble_w, bubble_h),
			Color("#fef3c7") if not alert else Color("#fee2e2"))
		draw_rect(Rect2(bubble_x, bubble_y, bubble_w, 2), Color("#fffbeb"))
		draw_rect(Rect2(bubble_x, bubble_y + bubble_h - 2, bubble_w, 2), Color("#fcd34d"))
		# Speech pointer triangle toward mentor avatar
		draw_rect(Rect2(bubble_x + bubble_w, bubble_y + 16, 4, 6), INK)
		draw_rect(Rect2(bubble_x + bubble_w, bubble_y + 18, 2, 2),
			Color("#fef3c7") if not alert else Color("#fee2e2"))

		draw_multiline_string(font12 if font10 == null else font12,
			Vector2(bubble_x + 8, bubble_y + 15), tip_text,
			HORIZONTAL_ALIGNMENT_LEFT, bubble_w - 14.0, 12, 2, Color("#0f172a"))

		# Framed pixel mentor avatar
		draw_rect(Rect2(avatar_x - 2, avatar_y - 2, avatar_size + 4, avatar_size + 4), INK)
		draw_rect(Rect2(avatar_x, avatar_y, avatar_size, avatar_size), Color("#1e293b"))
		if tex != null:
			# Crop upper bust of pixel portrait cleanly inside square avatar box
			var src_w := float(tex.get_width())
			var src_h := minf(float(tex.get_height()), src_w)
			draw_texture_rect_region(tex,
				Rect2(avatar_x + 2, avatar_y + 2, avatar_size - 4, avatar_size - 4),
				Rect2(0, 0, src_w, src_h))
		draw_rect(Rect2(avatar_x, avatar_y, avatar_size, avatar_size), SmaUiTheme.GOLD, false, 2.0)
