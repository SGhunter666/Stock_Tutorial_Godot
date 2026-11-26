## Arcade floating pixel popups & coin/star particle bursts for trade fills,
## XP gains, achievements, and interactive trading-floor props.
class_name SmaPixelFx
extends Control

const INK := Color("#04070e")

var _popups: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 35


func _is_reduced() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	var g := tree.root.get_node_or_null("Game")
	if g != null:
		return bool(g.settings.get("reducedMotion", false))
	return false


func spawn_trade_fill(trade: Dictionary) -> void:
	if not SmaUiTheme.is_pixel() or DisplayServer.get_name() == "headless" or _is_reduced():
		return
	var ticker := String(trade.get("ticker", ""))
	var qty := float(trade.get("qty", 0.0))
	var price := float(trade.get("price", 0.0))
	var realized := float(trade.get("realized", 0.0))
	var action := String(trade.get("action", ""))
	var is_buy := action in ["openLong", "closeShort"] or String(trade.get("side", "")) in ["buy", "cover"]
	var arrow := "▲" if is_buy else "▼"
	var text := "%s %s ×%s @ %s" % [arrow, ticker, SmaFormat.quantity(qty), SmaFormat.money(price)]
	var col := SmaUiTheme.POSITIVE if is_buy else SmaUiTheme.ACCENT
	if absf(realized) >= 0.01:
		text += "  (%s)" % SmaFormat.signed_money(realized)
		col = SmaUiTheme.POSITIVE if realized >= 0.0 else SmaUiTheme.NEGATIVE
	var anchor := Vector2(maxf(340.0, size.x * 0.44), maxf(280.0, size.y * 0.58))
	_add_popup(anchor, text, col, SmaPixelArt.icon("equity" if realized > 0.0 else "trade"))
	spawn_burst(anchor, SmaUiTheme.GOLD if realized > 0.0 else col, 10)


func spawn_xp_gain(delta_xp: int) -> void:
	if delta_xp <= 0 or not SmaUiTheme.is_pixel() or DisplayServer.get_name() == "headless" or _is_reduced():
		return
	var anchor := Vector2(maxf(340.0, size.x * 0.44), maxf(240.0, size.y * 0.48))
	_add_popup(anchor, "★ +%d XP" % delta_xp, SmaUiTheme.GOLD, SmaPixelArt.icon("watchlist"))
	spawn_burst(anchor, SmaUiTheme.GOLD, 8)


func spawn_honor(title_text: String) -> void:
	if not SmaUiTheme.is_pixel() or DisplayServer.get_name() == "headless" or _is_reduced():
		return
	var anchor := Vector2(maxf(340.0, size.x * 0.50), maxf(240.0, size.y - 132.0))
	_add_popup(anchor, "★ " + title_text, SmaUiTheme.GOLD, SmaPixelArt.icon("challenges"), 2.1)
	spawn_burst(anchor, SmaUiTheme.GOLD, 14)


func spawn_burst(origin: Vector2, color: Color, count: int = 8) -> void:
	if not SmaUiTheme.is_pixel() or DisplayServer.get_name() == "headless" or _is_reduced():
		return
	for i in count:
		var angle := (TAU * float(i) / float(maxi(1, count))) - PI * 0.5 + float((i * 7) % 5 - 2) * 0.12
		var spd := 68.0 + float((i * 29) % 64)
		_sparks.append({
			"pos": origin,
			"vel": Vector2(cos(angle) * spd, sin(angle) * spd - 36.0),
			"life": 0.0,
			"max_life": 0.55 + float(i % 3) * 0.12,
			"color": color if (i % 2 == 0) else color.lightened(0.35),
			"px": 4 if (i % 3 != 0) else 6,
		})
	queue_redraw()


func _add_popup(origin: Vector2, text: String, color: Color, icon_tex: Texture2D = null,
		duration: float = 1.55) -> void:
	var offset_y := float(_popups.size() * 28)
	_popups.append({
		"pos": origin + Vector2(0.0, offset_y),
		"vel_y": -34.0,
		"life": 0.0,
		"max_life": duration,
		"text": text,
		"color": color,
		"icon": icon_tex,
	})
	if _popups.size() > 5:
		_popups.pop_front()
	queue_redraw()


func _process(delta: float) -> void:
	if _popups.is_empty() and _sparks.is_empty():
		return
	var i := _popups.size() - 1
	while i >= 0:
		var p: Dictionary = _popups[i]
		p["life"] = float(p["life"]) + delta
		if float(p["life"]) >= float(p["max_life"]):
			_popups.remove_at(i)
		else:
			var pos: Vector2 = p["pos"]
			pos.y += float(p["vel_y"]) * delta
			p["vel_y"] = lerpf(float(p["vel_y"]), -10.0, clampf(delta * 3.0, 0.0, 1.0))
			p["pos"] = pos
		i -= 1

	var j := _sparks.size() - 1
	while j >= 0:
		var s: Dictionary = _sparks[j]
		s["life"] = float(s["life"]) + delta
		if float(s["life"]) >= float(s["max_life"]):
			_sparks.remove_at(j)
		else:
			var spos: Vector2 = s["pos"]
			var svel: Vector2 = s["vel"]
			svel.y += 220.0 * delta
			spos += svel * delta
			s["pos"] = spos
			s["vel"] = svel
		j -= 1
	queue_redraw()


func _draw() -> void:
	for s in _sparks:
		var ratio := clampf(1.0 - float(s["life"]) / float(s["max_life"]), 0.0, 1.0)
		var c: Color = s["color"]
		c.a = ratio
		var px_sz := float(s["px"])
		var sp: Vector2 = s["pos"]
		draw_rect(Rect2(roundf(sp.x / 2.0) * 2.0, roundf(sp.y / 2.0) * 2.0, px_sz, px_sz), c)

	var font := SmaUiTheme.pixel_font_12()
	if font == null:
		return
	for p in _popups:
		var life_t := float(p["life"]) / float(p["max_life"])
		var alpha := 1.0 if life_t < 0.72 else clampf((1.0 - life_t) / 0.28, 0.0, 1.0)
		var text := String(p["text"])
		var col: Color = p["color"]
		var icon_tex: Texture2D = p["icon"]
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var icon_pad := 22.0 if icon_tex != null else 0.0
		var bw := roundf((tw + icon_pad + 20.0) / 2.0) * 2.0
		var bh := 26.0
		var pos: Vector2 = p["pos"]
		var bx := clampf(roundf((pos.x - bw * 0.5) / 2.0) * 2.0, 8.0, maxf(8.0, size.x - bw - 8.0))
		var by := roundf(pos.y / 2.0) * 2.0

		var bg := Color(0.04, 0.08, 0.15, 0.95 * alpha)
		var rim := Color(col.r, col.g, col.b, alpha)
		var ink_a := Color(INK.r, INK.g, INK.b, alpha)
		draw_rect(Rect2(bx - 2.0, by - 2.0, bw + 4.0, bh + 4.0), ink_a)
		draw_rect(Rect2(bx, by, bw, bh), bg)
		draw_rect(Rect2(bx, by, bw, 2.0), rim)
		draw_rect(Rect2(bx, by + bh - 2.0, bw, 2.0), rim.darkened(0.35))
		var tx := bx + 10.0
		if icon_tex != null:
			draw_texture_rect(icon_tex, Rect2(tx, by + 5.0, 16.0, 16.0), false, Color(1, 1, 1, alpha))
			tx += 20.0
		draw_string(font, Vector2(tx, by + 18.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(col.r, col.g, col.b, alpha))
