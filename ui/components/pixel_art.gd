## Procedural 16-bit pixel-art UI factory: cached 9-slice StyleBoxTextures with
## notched pixel corners & 3D arcade bevels, crisp pixel icons, and company badges.
class_name SmaPixelArt
extends RefCounted

const INK := Color("#04070e")

static var _style_cache: Dictionary = {}
static var _icon_cache: Dictionary = {}
static var _badge_cache: Dictionary = {}


static func clear_caches() -> void:
	_style_cache.clear()
	_icon_cache.clear()
	_badge_cache.clear()


static func _put(img: Image, gx: int, gy: int, scale: int, col: Color) -> void:
	img.fill_rect(Rect2i(gx * scale, gy * scale, scale, scale), col)


static func card_box(bg: Color, hi: Color, shadow: Color, margin: int = 10,
		rivets: bool = true) -> StyleBoxTexture:
	var key := "card2|%s|%s|%s|%d|%s" % [bg.to_html(), hi.to_html(), shadow.to_html(), margin, str(rivets)]
	if _style_cache.has(key):
		return (_style_cache[key] as StyleBoxTexture).duplicate() as StyleBoxTexture
	var p := 2
	var gw := 14
	var gh := 14
	var bw := gw - 2 # 12x12 card body + 2-grid (4px) hard pixel drop shadow on right/bottom
	var bh := gh - 2
	var img := Image.create(gw * p, gh * p, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var drop := Color(0.02, 0.03, 0.06, 0.56)
	# 1. Hard notched pixel drop shadow shifted by (+2, +2) grid units (4px)
	for sy in bh:
		for sx in bw:
			if (sx == 0 or sx == bw - 1) and (sy == 0 or sy == bh - 1):
				continue
			_put(img, sx + 2, sy + 2, p, drop)
	# 2. Notched 3D pixel card body
	for gy in bh:
		for gx in bw:
			var is_corner := (gx == 0 or gx == bw - 1) and (gy == 0 or gy == bh - 1)
			if is_corner:
				continue
			var is_outer := gx == 0 or gx == bw - 1 or gy == 0 or gy == bh - 1
			var is_step := (gx == 1 or gx == bw - 2) and (gy == 1 or gy == bh - 2)
			if is_outer or is_step:
				_put(img, gx, gy, p, INK)
			elif gy == 1 or gx == 1:
				_put(img, gx, gy, p, hi)
			elif gy == bh - 2 or gx == bw - 2:
				_put(img, gx, gy, p, shadow)
			else:
				_put(img, gx, gy, p, bg)
	if rivets:
		var rivet_col := hi.lerp(bg, 0.25)
		for pt in [Vector2i(2, 2), Vector2i(bw - 3, 2), Vector2i(2, bh - 3), Vector2i(bw - 3, bh - 3)]:
			_put(img, pt.x, pt.y, p, rivet_col)
	var tex := ImageTexture.create_from_image(img)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = 8
	sb.texture_margin_top = 8
	sb.texture_margin_right = 12
	sb.texture_margin_bottom = 12
	sb.content_margin_left = margin
	sb.content_margin_top = margin
	sb.content_margin_right = margin + 4
	sb.content_margin_bottom = margin + 4
	_style_cache[key] = sb
	return sb.duplicate() as StyleBoxTexture


static func row_box(bg: Color, rim: Color, pad_h: int = 8, pad_v: int = 6) -> StyleBoxTexture:
	var key := "row|%s|%s|%d|%d" % [bg.to_html(), rim.to_html(), pad_h, pad_v]
	if _style_cache.has(key):
		return (_style_cache[key] as StyleBoxTexture).duplicate() as StyleBoxTexture
	var p := 2
	var gw := 10
	var gh := 10
	var img := Image.create(gw * p, gh * p, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var top_hi := bg.lightened(0.14)
	var bot_sh := bg.darkened(0.28)
	for gy in gh:
		for gx in gw:
			if (gx == 0 or gx == gw - 1) and (gy == 0 or gy == gh - 1):
				continue
			if gx == 0 or gx == gw - 1 or gy == 0 or gy == gh - 1:
				_put(img, gx, gy, p, rim)
			elif gy == 1:
				_put(img, gx, gy, p, top_hi)
			elif gy == gh - 2:
				_put(img, gx, gy, p, bot_sh)
			else:
				_put(img, gx, gy, p, bg)
	var tex := ImageTexture.create_from_image(img)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = 6
	sb.texture_margin_top = 6
	sb.texture_margin_right = 6
	sb.texture_margin_bottom = 6
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	_style_cache[key] = sb
	return sb.duplicate() as StyleBoxTexture


static func progress_bg_box(bg: Color, rim: Color) -> StyleBoxTexture:
	var key := "pbg|%s|%s" % [bg.to_html(), rim.to_html()]
	if _style_cache.has(key):
		return (_style_cache[key] as StyleBoxTexture).duplicate() as StyleBoxTexture
	var p := 2
	var img := Image.create(8 * p, 8 * p, false, Image.FORMAT_RGBA8)
	img.fill(INK)
	for gy in range(1, 7):
		for gx in range(1, 7):
			_put(img, gx, gy, p, rim if (gy == 6 or gx == 6) else bg)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.texture_margin_left = 4
	sb.texture_margin_top = 4
	sb.texture_margin_right = 4
	sb.texture_margin_bottom = 4
	_style_cache[key] = sb
	return sb.duplicate() as StyleBoxTexture


static func progress_fill_box(fill: Color) -> StyleBoxTexture:
	var key := "pfill|%s" % fill.to_html()
	if _style_cache.has(key):
		return (_style_cache[key] as StyleBoxTexture).duplicate() as StyleBoxTexture
	var p := 2
	# 4-grid (8px) tiled LED segment: 3 cols lit + 1 col dark gap!
	var img := Image.create(4 * p, 8 * p, false, Image.FORMAT_RGBA8)
	img.fill(INK)
	var hi := fill.lightened(0.35)
	var sh := fill.darkened(0.28)
	for gy in range(1, 7):
		for gx in 3:
			var c := hi if gy == 1 else (sh if gy == 6 else fill)
			_put(img, gx, gy, p, c)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.texture_margin_top = 2
	sb.texture_margin_bottom = 2
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	_style_cache[key] = sb
	return sb.duplicate() as StyleBoxTexture


static func scroll_box(face: Color, hi: Color, track: bool = false) -> StyleBoxTexture:
	var key := "scr|%s|%s|%s" % [face.to_html(), hi.to_html(), str(track)]
	if _style_cache.has(key):
		return (_style_cache[key] as StyleBoxTexture).duplicate() as StyleBoxTexture
	var p := 2
	var img := Image.create(6 * p, 8 * p, false, Image.FORMAT_RGBA8)
	img.fill(INK)
	for gy in range(1, 7):
		for gx in range(1, 5):
			var c := face
			if not track and (gy == 1 or gx == 1):
				c = hi
			elif not track and gy == 6:
				c = face.darkened(0.3)
			_put(img, gx, gy, p, c)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.texture_margin_left = 4
	sb.texture_margin_top = 4
	sb.texture_margin_right = 4
	sb.texture_margin_bottom = 4
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	_style_cache[key] = sb
	return sb.duplicate() as StyleBoxTexture


static func button_box(face: Color, top_hi: Color, ledge: Color, margin: int = 8,
		pressed: bool = false) -> StyleBoxTexture:
	var key := "btn|%s|%s|%s|%d|%s" % [face.to_html(), top_hi.to_html(), ledge.to_html(), margin, str(pressed)]
	if _style_cache.has(key):
		return (_style_cache[key] as StyleBoxTexture).duplicate() as StyleBoxTexture
	var p := 2
	var gw := 12
	var gh := 14
	var img := Image.create(gw * p, gh * p, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var left_hi := face.lightened(0.16)
	if not pressed:
		for gy in gh:
			for gx in gw:
				var is_corner := (gx == 0 or gx == gw - 1) and (gy == 0 or gy == gh - 1)
				if is_corner:
					continue
				var is_outer := gx == 0 or gx == gw - 1 or gy == 0 or gy == gh - 1
				var is_step := (gx == 1 or gx == gw - 2) and (gy == 1 or gy == gh - 2)
				if is_outer or is_step:
					_put(img, gx, gy, p, INK)
				elif gy == 1:
					_put(img, gx, gy, p, top_hi)
				elif gy == gh - 2 or gy == gh - 3:
					_put(img, gx, gy, p, ledge)
				elif gx == 1:
					_put(img, gx, gy, p, left_hi)
				elif gx == gw - 2:
					_put(img, gx, gy, p, ledge)
				else:
					_put(img, gx, gy, p, face)
	else:
		var sunken := ledge.darkened(0.28)
		for gy in range(1, gh):
			for gx in gw:
				var is_corner := (gx == 0 or gx == gw - 1) and (gy == 1 or gy == gh - 1)
				if is_corner:
					continue
				var is_outer := gx == 0 or gx == gw - 1 or gy == 1 or gy == gh - 1
				var is_step := (gx == 1 or gx == gw - 2) and (gy == 2 or gy == gh - 2)
				if is_outer or is_step:
					_put(img, gx, gy, p, INK)
				elif gy == 2 or gx == 1:
					_put(img, gx, gy, p, sunken)
				elif gy == gh - 2:
					_put(img, gx, gy, p, top_hi)
				else:
					_put(img, gx, gy, p, face)
	var tex := ImageTexture.create_from_image(img)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = 8
	sb.texture_margin_right = 8
	sb.texture_margin_top = 8
	sb.texture_margin_bottom = 10
	sb.content_margin_left = margin + 3
	sb.content_margin_right = margin + 3
	if pressed:
		sb.content_margin_top = margin + 2
		sb.content_margin_bottom = maxi(2, margin - 1)
	else:
		sb.content_margin_top = maxi(3, margin - 1)
		sb.content_margin_bottom = margin + 2
	_style_cache[key] = sb
	return sb.duplicate() as StyleBoxTexture


static func readout_box(bg: Color, rim: Color, pad_h: int = 10, pad_v: int = 5) -> StyleBoxTexture:
	var key := "readout|%s|%s|%d|%d" % [bg.to_html(), rim.to_html(), pad_h, pad_v]
	if _style_cache.has(key):
		return (_style_cache[key] as StyleBoxTexture).duplicate() as StyleBoxTexture
	var p := 2
	var gw := 10
	var gh := 10
	var img := Image.create(gw * p, gh * p, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var top_shadow := bg.darkened(0.45)
	for gy in gh:
		for gx in gw:
			var is_corner := (gx == 0 or gx == gw - 1) and (gy == 0 or gy == gh - 1)
			if is_corner:
				continue
			var is_outer := gx == 0 or gx == gw - 1 or gy == 0 or gy == gh - 1
			var is_step := (gx == 1 or gx == gw - 2) and (gy == 1 or gy == gh - 2)
			if is_outer or is_step:
				_put(img, gx, gy, p, INK)
			elif gy == 1 or gx == 1:
				_put(img, gx, gy, p, top_shadow)
			elif gy == gh - 2 or gx == gw - 2:
				_put(img, gx, gy, p, rim)
			else:
				_put(img, gx, gy, p, bg)
	var tex := ImageTexture.create_from_image(img)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = 6
	sb.texture_margin_top = 6
	sb.texture_margin_right = 6
	sb.texture_margin_bottom = 6
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	_style_cache[key] = sb
	return sb.duplicate() as StyleBoxTexture


static func _pattern_tex(rows: Array, palette: Dictionary, scale: int = 2) -> ImageTexture:
	var h := rows.size()
	var w := String(rows[0]).length() if h > 0 else 1
	var img := Image.create(w * scale, h * scale, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var line := String(rows[y])
		for x in mini(w, line.length()):
			var ch := line.substr(x, 1)
			if ch == "." or not palette.has(ch):
				continue
			_put(img, x, y, scale, palette[ch])
	return ImageTexture.create_from_image(img)


static func icon(kind: String) -> ImageTexture:
	if _icon_cache.has(kind):
		return _icon_cache[kind]
	var pal := {
		"k": INK,
		"w": Color("#f8fafc"),
		"s": Color("#94a3b8"),
		"d": Color("#334155"),
		"g": Color("#22c55e"),
		"G": Color("#86efac"),
		"e": Color("#15803d"),
		"r": Color("#ef4444"),
		"R": Color("#fca5a5"),
		"y": Color("#fbbf24"),
		"Y": Color("#fef08a"),
		"o": Color("#b45309"),
		"c": Color("#5eead4"),
		"b": Color("#3b82f6"),
		"p": Color("#a855f7"),
	}
	var rows: Array = []
	match kind:
		"logo":
			rows = [
				".kkkkkkkkkk.",
				"kyyyyyyyyyyk",
				"kyddddddddyk",
				"kyd..G...dyk",
				"kyd..G.r.dyk",
				"kyd.gG.rkdyk",
				"kyd.gGcr.dyk",
				"kydcck..cdyk",
				"kyddddddddyk",
				"kooooooooook",
				".kkkkkkkkkk.",
			]
		"cash":
			rows = [
				".kkkkkkkkkk.",
				"kGGGGGGGGGGk",
				"kGeeeeeeeeGk",
				"kGeGyyyyGeGk",
				"kGeyGyyGyeGk",
				"kGeGyyyyGeGk",
				"kGeeeeeeeeGk",
				"kggggggggggk",
				".kkkkkkkkkk.",
			]
		"calendar":
			rows = [
				".kkkkkkkk.",
				"krRrrrrRrk",
				"krrrrrrrrk",
				"kkkkkkkkkk",
				"kwwwwwwwwk",
				"kwddwwddwk",
				"kwddwwddwk",
				"kssssssssk",
				".kkkkkkkk.",
			]
		"equity":
			rows = [
				"..kkkkkk..",
				".kYYYYYYk.",
				"kYyyyyyyYk",
				"kyyYwwyyyk",
				"kyyYyyyyyk",
				"kyyYwwyyyk",
				"kYyyyyyyYk",
				".kooooook.",
				"..kkkkkk..",
			]
		"pnl":
			rows = [
				"....kkkk..",
				"...kGGGGk.",
				"..kGggggGk",
				"....kggk..",
				".kkkggk...",
				"kGGGGk....",
				"kgggk.....",
				".kkk......",
			]
		"office":
			rows = [
				"..kkkkkk..",
				".kbbbbbbk.",
				"kbYbbYbbbk",
				"kbbbbbbbbk",
				"kbYbbYbbbk",
				"kbbbbbbbbk",
				"kbddbbddbk",
				"kkkkkkkkkk",
			]
		"dashboard":
			rows = [
				"...kk...",
				"..kyyk..",
				".kyyyyk.",
				"kkkkkkkk",
				"kwccccwk",
				"kwcggcwk",
				"kwwwwwwk",
				"kkkkkkkk",
			]
		"portfolio":
			rows = [
				"..kkkk..",
				".kssssk.",
				"kkkkkkkk",
				"kooooook",
				"kyyyyyyk",
				"kooooook",
				"kooooook",
				"kkkkkkkk",
			]
		"watchlist":
			rows = [
				"...kk...",
				"..kYYk..",
				"kkYYYYkk",
				".kyyyyk.",
				"..kyyk..",
				".kykkyk.",
				"kyk..kyk",
				"kk....kk",
			]
		"market":
			rows = [
				".....kk.",
				"....kGGk",
				"..kkkggk",
				"..kbbkgk",
				"kkkbbkgk",
				"kyybbkgk",
				"kyybbkgk",
				"kkkkkkkk",
			]
		"trade":
			rows = [
				"..k..k..",
				".kGkkrk.",
				".kGkkrk.",
				".kgkkrk.",
				"..k.krk.",
				"....k.k.",
				"kkkkkkkk",
				"cccccccc",
			]
		"academy":
			rows = [
				"..kkkk..",
				"kkyyyykk",
				"kYYYYYYk",
				".koooook",
				".kwwwwk.",
				".kwddwk.",
				"..kkkk..",
				"....kyk.",
			]
		"story":
			rows = [
				".kkkkkk.",
				"kcccccck",
				"kcwwwwck",
				"kcccccck",
				"kcwwccck",
				".kkckkkk",
				"..kck...",
				"..kk....",
			]
		"challenges":
			rows = [
				"kkkkkkkk",
				"kYYYYYYk",
				".kyyyyk.",
				"..kyyk..",
				"...kk...",
				"..kyyk..",
				".koooook",
				"kkkkkkkk",
			]
		"career":
			rows = [
				"..kkkk..",
				".kwwwwk.",
				".kwrrwk.",
				"..krrk..",
				"..krrk..",
				".krrrrk.",
				"..krrk..",
				"...kk...",
			]
		"fund":
			rows = [
				"..kkkk..",
				".kcccck.",
				"kcYccYck",
				"kcccccck",
				"kcYccYck",
				"kcccccck",
				"kcddccdk",
				"kkkkkkkk",
			]
		"quant":
			rows = [
				".k.kk.k.",
				"kkkkkkkk",
				"kcccccck",
				"kcGGGGck",
				"kcGggGck",
				"kcccccck",
				"kkkkkkkk",
				".k.kk.k.",
			]
		"settings":
			rows = [
				"..kkkk..",
				".kssssk.",
				"kswwwwsk",
				"kswddwsk",
				"kswddwsk",
				"kswwwwsk",
				".kssssk.",
				"..kkkk..",
			]
		"cb_unchecked":
			rows = [
				".kkkkkk.",
				"kssssssk",
				"ksddddsk",
				"ksddddsk",
				"ksddddsk",
				"ksddddsk",
				"kssssssk",
				".kkkkkk.",
			]
		"cb_checked":
			rows = [
				".kkkkkk.",
				"kGGGGGGk",
				"kGggggGk",
				"kGgggwwk",
				"kGwwgwwk",
				"kGgwwwgk",
				"kGggggGk",
				".kkkkkk.",
			]
		"radio_unchecked":
			rows = [
				"..kkkk..",
				".kssssk.",
				"ksddddsk",
				"ksddddsk",
				"ksddddsk",
				"ksddddsk",
				".kssssk.",
				"..kkkk..",
			]
		"radio_checked":
			rows = [
				"..kkkk..",
				".kcccck.",
				"kcddddck",
				"kcdGGdck",
				"kcdGGdck",
				"kcddddck",
				".kcccck.",
				"..kkkk..",
			]
		"slider_grabber":
			rows = [
				".kkkkk.",
				"kYYYYYk",
				"kyyyyyk",
				"kykkkyk",
				"kyyyyyk",
				"kykkkyk",
				"kyyyyyk",
				"koooook",
				".kkkkk.",
			]
		"slider_grabber_hi":
			rows = [
				".kkkkk.",
				"kwwwwwk",
				"kYYYYYk",
				"kYkkkYk",
				"kYYYYYk",
				"kYkkkYk",
				"kYYYYYk",
				"kyyyyyk",
				".kkkkk.",
			]
		"screener":
			rows = [
				".kkkkk..",
				"kccccck.",
				"kcwwwck.",
				"kcwwwck.",
				"kccccck.",
				".kkkkkyk",
				".....kyk",
				"......kk",
			]
		"etf":
			rows = [
				"kkkkkkkk",
				"krrkgggk",
				"krrkgggk",
				"kkkkkkkk",
				"kbbkyyyk",
				"kbbkyyyk",
				"kkkkkkkk",
				"........",
			]
		"options":
			rows = [
				"..kkkk..",
				".kYYYYk.",
				"kyykkkyk",
				".kyyyyk.",
				"...kyk..",
				"...kyyk.",
				"...kyk..",
				"...kyyk.",
			]
		"futures":
			rows = [
				"...kkkk.",
				"..kYYYYk",
				".kyyyk..",
				"kyyyyyk.",
				"..kkyyk.",
				".kyyyk..",
				"kyyk....",
				"kk......",
			]
		"multiasset":
			rows = [
				"..kkkk..",
				".kYYYYk.",
				"kyyyyyyk",
				"kkkkkkkk",
				"kcccccck",
				"kcbbbbck",
				"kcccccck",
				".kkkkkk.",
			]
		"news":
			rows = [
				"kkkkkkkk",
				"kwwwwwwk",
				"kwrrwwwk",
				"kwrrddwk",
				"kwwwwwwk",
				"kwddddwk",
				"kssssssk",
				"kkkkkkkk",
			]
		"earnings":
			rows = [
				"....kkk.",
				"..kkyYYk",
				"kkyyyyyk",
				"krrryyyk",
				"krrryyyk",
				"kkyyyyyk",
				".kkooyYk",
				"..kk.kk.",
			]
		"macro":
			rows = [
				"..kkkk..",
				".kbbbbk.",
				"kbGbbGbk",
				"kGGbbGGk",
				"kbbbbbbk",
				"kbGbbGbk",
				".kbbbbk.",
				"..kkkk..",
			]
		"statements":
			rows = [
				".kkkkkk.",
				"kwwwwwwk",
				"kwggggwk",
				"kwwwwwwk",
				"kwyyyywk",
				"kwwwwwwk",
				"kwbbbbwk",
				".kkkkkk.",
			]
		"history":
			rows = [
				"..kkkk..",
				".kwwwwk.",
				"kwddkkwk",
				"kwddkwwk",
				"kwwwkkwk",
				"kwwwwwwk",
				".kssssk.",
				"..kkkk..",
			]
		"replay":
			rows = [
				".kkkkkk.",
				"kddddddk",
				"kdGkGGdk",
				"kdgkggdk",
				"kdGkGGdk",
				"kddddddk",
				".kkkkkk.",
				"........",
			]
		"tax":
			rows = [
				".kkkkkk.",
				"kyyyyyyk",
				"kywyywyk",
				"kyyywyyk",
				"kyywyyyk",
				"kywyywyk",
				"kooooook",
				".kkkkkk.",
			]
		"sandbox":
			rows = [
				"..kkkk..",
				"...kk...",
				"..kwwk..",
				".kwppwk.",
				"kwppppwk",
				"kppppppk",
				"kcccccck",
				".kkkkkk.",
			]
		"glossary":
			rows = [
				"kkkkkkkk",
				"kwwkwwwk",
				"kwdkwdwk",
				"kwwkwwwk",
				"kwdkwdwk",
				"kwwkrwwk",
				"kkkkkkkk",
				"....kk..",
			]
		"boundaries":
			rows = [
				".kkkkkk.",
				"kcccccck",
				"kcbbbbck",
				"kcbYYbck",
				".kcbbck.",
				"..kcck..",
				"...kk...",
				"........",
			]
		"roadmap":
			rows = [
				"..kkkk..",
				"..krrrk.",
				"..krrrrk",
				"..krrrk.",
				"..kwwk..",
				"..kwwk..",
				".kssssk.",
				"kkkkkkkk",
			]
		"opt_arrow":
			rows = [
				"........",
				".kkkkkk.",
				"kYYYYYYk",
				".kyyyyk.",
				"..kyyk..",
				"...kk...",
				"........",
				"........",
			]
		"spin_updown":
			rows = [
				"...kk...",
				"..kcck..",
				".kcccck.",
				"kkkkkkkk",
				"........",
				"kkkkkkkk",
				".kyyyyk.",
				"..kyyk..",
				"...kk...",
			]
		"star_on":
			rows = [
				"...kk...",
				"..kYYk..",
				"kkYYYYkk",
				".kyyyyk.",
				"..kyyk..",
				".kykkyk.",
				"kyk..kyk",
				"........",
			]
		"star_off":
			rows = [
				"...kk...",
				"..kssk..",
				"kksssskk",
				".ksddsk.",
				"..kssk..",
				".kskksk.",
				"ksk..ksk",
				"........",
			]
		_:
			rows = [
				".kkkkkk.",
				"kcccccck",
				"kcwwwwck",
				"kcwwwwck",
				"kcccccck",
				".kkkkkk.",
				"........",
				"........",
			]
	var tex := _pattern_tex(rows, pal, 2)
	_icon_cache[kind] = tex
	return tex


static func ticker_badge(ticker: String, sector: String, locked: bool = false) -> ImageTexture:
	var key := "%s|%s|%s" % [ticker, sector, "L" if locked else "U"]
	if _badge_cache.has(key):
		return _badge_cache[key]
	var p := 2
	var gw := 10
	var gh := 10
	var img := Image.create(gw * p, gh * p, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if locked:
		var bg_l := Color("#1e293b")
		var hi_l := Color("#475569")
		for gy in gh:
			for gx in gw:
				if (gx == 0 or gx == gw - 1) and (gy == 0 or gy == gh - 1):
					continue
				if gx == 0 or gx == gw - 1 or gy == 0 or gy == gh - 1:
					_put(img, gx, gy, p, INK)
				elif gx == 1 or gy == 1:
					_put(img, gx, gy, p, hi_l)
				else:
					_put(img, gx, gy, p, bg_l)
		for gx in range(3, 7):
			_put(img, gx, 2, p, Color("#94a3b8"))
		_put(img, 3, 3, p, Color("#94a3b8"))
		_put(img, 6, 3, p, Color("#94a3b8"))
		for gy in range(4, 8):
			for gx in range(2, 8):
				_put(img, gx, gy, p, Color("#fbbf24") if gy < 6 else Color("#d97706"))
		var ltex := ImageTexture.create_from_image(img)
		_badge_cache[key] = ltex
		return ltex

	# Sector palette (matching Reference B's vibrant company icon tiles)
	var bg := Color("#1d4ed8")
	var fg := Color("#f8fafc")
	var acc := Color("#fbbf24")
	match sector:
		"technology", "tech":
			bg = Color("#1d4ed8")
			fg = Color("#f8fafc")
			acc = Color("#f87171")
		"semiconductors":
			bg = Color("#14532d")
			fg = Color("#4ade80")
			acc = Color("#bbf7d0")
		"finance", "financials":
			bg = Color("#1e3a8a")
			fg = Color("#fbbf24")
			acc = Color("#fef08a")
		"healthcare":
			bg = Color("#0f766e")
			fg = Color("#f8fafc")
			acc = Color("#5eead4")
		"consumer", "retail":
			bg = Color("#9a3412")
			fg = Color("#fef3c7")
			acc = Color("#fb923c")
		"energy", "industrials":
			bg = Color("#78350f")
			fg = Color("#fde047")
			acc = Color("#f59e0b")
		"etf":
			bg = Color("#312e81")
			fg = Color("#5eead4")
			acc = Color("#fbbf24")
		_:
			var h_val := fmod(float(ticker.hash() & 0x7fffffff) / 137.0, 1.0)
			bg = Color.from_hsv(h_val, 0.68, 0.58)
			fg = Color("#f8fafc")
			acc = Color("#fbbf24")

	# Special iconic badges for flagship stocks (APLA, NVDO, MSFY, MKT)
	if ticker == "MSFY":
		bg = Color("#f1f5f9")
	elif ticker == "NVDO":
		bg = Color("#182218")
		fg = Color("#4ade80")
		acc = Color("#86efac")
	elif ticker == "APLA":
		bg = Color("#1d4ed8")
		fg = Color("#ffffff")
		acc = Color("#ef4444")

	var hi := bg.lightened(0.24)
	var sh := bg.darkened(0.32)
	for gy in gh:
		for gx in gw:
			if (gx == 0 or gx == gw - 1) and (gy == 0 or gy == gh - 1):
				continue
			if gx == 0 or gx == gw - 1 or gy == 0 or gy == gh - 1:
				_put(img, gx, gy, p, INK)
			elif gy == 1 or gx == 1:
				_put(img, gx, gy, p, hi)
			elif gy == gh - 2 or gx == gw - 2:
				_put(img, gx, gy, p, sh)
			else:
				_put(img, gx, gy, p, bg)

	if ticker == "MSFY":
		for dy in 2:
			for dx in 2:
				_put(img, 2 + dx, 2 + dy, p, Color("#ef4444"))
				_put(img, 5 + dx, 2 + dy, p, Color("#22c55e"))
				_put(img, 2 + dx, 5 + dy, p, Color("#3b82f6"))
				_put(img, 5 + dx, 5 + dy, p, Color("#eab308"))
	elif ticker == "NVDO":
		for gx in range(3, 7):
			_put(img, gx, 3, p, fg)
			_put(img, gx, 6, p, fg)
		_put(img, 2, 4, p, fg)
		_put(img, 7, 4, p, fg)
		_put(img, 4, 4, p, acc)
		_put(img, 5, 5, p, acc)
	elif ticker == "APLA":
		_put(img, 4, 2, p, fg)
		_put(img, 5, 2, p, fg)
		_put(img, 3, 3, p, fg)
		_put(img, 6, 3, p, fg)
		_put(img, 3, 4, p, fg)
		_put(img, 6, 4, p, fg)
		for gx in range(3, 7):
			_put(img, gx, 5, p, acc)
		_put(img, 2, 6, p, fg)
		_put(img, 7, 6, p, fg)
	else:
		# Deterministic pixel glyph inside badge
		var seed_bits := ticker.hash()
		_put(img, 3, 6, p, fg)
		_put(img, 4, 5, p, fg)
		_put(img, 5, 4, p, acc)
		_put(img, 6, 3, p, acc)
		if (seed_bits & 1) == 0:
			_put(img, 3, 3, p, fg)
			_put(img, 6, 6, p, fg)
		else:
			_put(img, 4, 3, p, acc)
			_put(img, 5, 6, p, fg)

	var tex := ImageTexture.create_from_image(img)
	_badge_cache[key] = tex
	return tex
