## 16-bit PC-98 portrait micro-animator: exact 96x128 pixel-grid eye blinking,
## typewriter lip-sync frames, brow/smile expression shifts, and pixel emote badges
## ("calm", "crisis", "praise", "focus"). Respects reducedMotion.
class_name SmaPortraitAnimator
extends Control

const PX := 2
const INK := Color("#090d16")

## Exact 96x128 grid coordinates measured directly from assets/portraits/pixel/*.png
const RIGS := {
	"lin_lan": {
		"left_eye": Rect2i(37, 33, 7, 3),
		"right_eye": Rect2i(53, 33, 7, 3),
		"skin_pt": Vector2i(48, 31),
		"mouth": Rect2i(46, 47, 6, 2),
	},
	"gu_yan": {
		"left_eye": Rect2i(45, 39, 7, 3),
		"right_eye": Rect2i(60, 40, 6, 3),
		"skin_pt": Vector2i(51, 34),
		"mouth": Rect2i(51, 56, 7, 2),
	},
	"chen_xi": {
		"left_eye": Rect2i(40, 40, 8, 4),
		"right_eye": Rect2i(55, 40, 8, 4),
		"skin_pt": Vector2i(49, 39),
		"mouth": Rect2i(48, 53, 7, 3),
	},
	"su_he": {
		"left_eye": Rect2i(30, 39, 6, 3),
		"right_eye": Rect2i(43, 39, 6, 3),
		"skin_pt": Vector2i(38, 45),
		"mouth": Rect2i(37, 53, 6, 2),
	},
	"zhou_heng": {
		"left_eye": Rect2i(32, 42, 7, 3),
		"right_eye": Rect2i(50, 42, 7, 3),
		"skin_pt": Vector2i(45, 34),
		"mouth": Rect2i(41, 56, 8, 2),
	},
	"wang": {
		"left_eye": Rect2i(28, 48, 6, 3),
		"right_eye": Rect2i(46, 48, 7, 3),
		"skin_pt": Vector2i(38, 40),
		"mouth": Rect2i(36, 67, 8, 2),
	},
	"lao_chen": {
		"left_eye": Rect2i(38, 32, 6, 2),
		"right_eye": Rect2i(50, 32, 6, 2),
		"skin_pt": Vector2i(45, 29),
		"mouth": Rect2i(43, 46, 7, 2),
	},
}

const BADGE_ALERT := [
	".kkkkkkkk.",
	"krrrrrrrrk",
	"krwwrrwwrk",
	"krwwrrwwrk",
	"krwwrrwwrk",
	"krrrrrrrrk",
	"krwwrrwwrk",
	"krrrrrrrrk",
	".kkkkkkkk.",
]

const BADGE_PRAISE := [
	"...kkkk...",
	"..kYYYYk..",
	"kkYYYYYYkk",
	"kYYywwyYYk",
	".kYYwwYYk.",
	"..kYYYYk..",
	".kYYkkYYk.",
	"kYYk..kYYk",
	".kk....kk.",
]

const BADGE_FOCUS := [
	".kkkkkkkk.",
	"kcccccccck",
	"kcwwwwccck",
	"kcccwwccck",
	"kccwwcccck",
	"kcccccccck",
	"kccwwcccck",
	"kcccccccck",
	".kkkkkkkk.",
]

var char_id := "lin_lan"
var mood := "calm"
var talking := false
var force_blink := false
var force_mouth_open := false

var _skin_cache: Dictionary = {}
var _blink_timer := 2.4
var _blink_remain := 0.0
var _talk_accum := 0.0
var _talk_step := 0
var _badge_bob := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func resolve_mood(story_id: String, body_text: String) -> String:
	var low := body_text.to_lower()
	if story_id in ["black_friday", "crisis_eve", "leverage_night", "macro_shock"] \
			or body_text.contains("追缴") or body_text.contains("暴跌") \
			or body_text.contains("警报") or body_text.contains("爆仓") \
			or low.contains("margin call") or low.contains("crash") or low.contains("panic"):
		return "crisis"
	if story_id in ["graduation", "epilogue"] \
			or body_text.contains("恭喜") or body_text.contains("干得漂亮") \
			or body_text.contains("做得好") or body_text.contains("稳健") \
			or low.contains("congrat") or low.contains("well done") or low.contains("proud"):
		return "praise"
	if body_text.contains("？") or body_text.contains("?") \
			or story_id in ["research", "options_expiry", "short_mirror"]:
		return "focus"
	return "calm"


func configure(next_char: String, tex: Texture2D, next_mood: String = "calm") -> void:
	char_id = next_char if RIGS.has(next_char) else "lin_lan"
	mood = next_mood
	if tex != null and not _skin_cache.has(char_id):
		var img := tex.get_image()
		if img != null and not img.is_empty():
			var pt: Vector2i = RIGS[char_id]["skin_pt"]
			var sx := clampi(pt.x * 2, 0, img.get_width() - 1)
			var sy := clampi(pt.y * 2, 0, img.get_height() - 1)
			_skin_cache[char_id] = img.get_pixel(sx, sy)
	queue_redraw()


func set_talking(is_talking: bool) -> void:
	if talking == is_talking:
		return
	talking = is_talking
	if not talking:
		_talk_step = 0
	queue_redraw()


func _is_reduced() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var g := tree.root.get_node_or_null("Game")
		if g != null:
			return bool(g.settings.get("reducedMotion", false))
	return false


func _process(delta: float) -> void:
	if not is_visible_in_tree() or DisplayServer.get_name() == "headless" or _is_reduced():
		return
	var dirty := false
	_badge_bob += delta * 4.5
	if mood != "calm":
		dirty = true
	if _blink_remain > 0.0:
		_blink_remain = maxf(0.0, _blink_remain - delta)
		if _blink_remain <= 0.0:
			dirty = true
	else:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_blink_remain = 0.13
			_blink_timer = 2.6 + float((char_id.hash() & 7)) * 0.25
			dirty = true

	if talking:
		_talk_accum += delta
		if _talk_accum >= 0.09:
			_talk_accum = 0.0
			_talk_step = (_talk_step + 1) % 4
			dirty = true
	elif _talk_step != 0:
		_talk_step = 0
		dirty = true

	if dirty:
		queue_redraw()


func _grect(gx: int, gy: int, gw: int, gh: int, col: Color, sx: float, sy: float) -> void:
	draw_rect(Rect2(roundf(float(gx) * sx), roundf(float(gy) * sy),
		maxf(2.0, roundf(float(gw) * sx)), maxf(2.0, roundf(float(gh) * sy))), col)


func _draw() -> void:
	if size.x < 32.0 or size.y < 32.0 or not RIGS.has(char_id):
		return
	var rig: Dictionary = RIGS[char_id]
	var sx := size.x / 96.0
	var sy := size.y / 128.0
	var skin: Color = _skin_cache.get(char_id, Color("#f5cba7"))
	var skin_sh := skin.darkened(0.16)
	var lash := Color("#161014")
	var le: Rect2i = rig["left_eye"]
	var re: Rect2i = rig["right_eye"]
	var mo: Rect2i = rig["mouth"]

	# 1. Mood atmosphere tint & brow expression pixels
	if mood == "crisis":
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.85, 0.12, 0.16, 0.08))
		# Furrowed inner brow pixels
		_grect(le.position.x + le.size.x - 2, le.position.y - 1, 2, 1, lash, sx, sy)
		_grect(re.position.x, re.position.y - 1, 2, 1, lash, sx, sy)
	elif mood == "praise":
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.98, 0.82, 0.24, 0.06))
		# Subtle warm smile corners
		_grect(mo.position.x - 1, mo.position.y - 1, 1, 1, Color("#8c4646"), sx, sy)
		_grect(mo.position.x + mo.size.x, mo.position.y - 1, 1, 1, Color("#8c4646"), sx, sy)

	# 2. 16-bit Eye Blink (cleanly inside lens frames for glasses wearers)
	if _blink_remain > 0.0 or force_blink:
		for eye in [le, re]:
			_grect(eye.position.x, eye.position.y, eye.size.x, maxi(1, eye.size.y - 1), skin, sx, sy)
			if eye.size.y >= 3:
				_grect(eye.position.x, eye.position.y, eye.size.x, 1, skin_sh, sx, sy)
			_grect(eye.position.x, eye.position.y + eye.size.y - 1, eye.size.x, 1, lash, sx, sy)

	# 3. PC-98 Lip-Flap Talking frames during typewriter playback
	var mouth_open := force_mouth_open or (talking and (_talk_step == 1 or _talk_step == 3))
	var mouth_half := talking and _talk_step == 2
	if mouth_open:
		_grect(mo.position.x + 1, mo.position.y, maxi(2, mo.size.x - 2), mo.size.y, Color("#4c1820"), sx, sy)
		_grect(mo.position.x + 2, mo.position.y, maxi(1, mo.size.x - 4), 1, Color("#f1f5f9"), sx, sy)
		_grect(mo.position.x + 1, mo.position.y + mo.size.y, maxi(2, mo.size.x - 2), 1, Color("#c96b6b"), sx, sy)
	elif mouth_half:
		_grect(mo.position.x + 1, mo.position.y, maxi(2, mo.size.x - 2), 1, Color("#6e2932"), sx, sy)

	# 4. Top-right PC-98 / Kairosoft Pixel Emote Badge
	if mood in ["crisis", "praise", "focus"]:
		var rows: Array = BADGE_ALERT if mood == "crisis" else (BADGE_PRAISE if mood == "praise" else BADGE_FOCUS)
		var pal := {
			"k": INK,
			"r": Color("#ef4444"),
			"w": Color("#ffffff"),
			"Y": Color("#fef08a"),
			"y": Color("#f59e0b"),
			"c": Color("#0ea5e9"),
		}
		var bob_y := 0 if _is_reduced() else (2 if sin(_badge_bob) > 0.0 else 0)
		var bx := size.x - float(String(rows[0]).length() * PX) - 6.0
		var by := 6.0 + float(bob_y)
		for ry in rows.size():
			var line := String(rows[ry])
			for rx in line.length():
				var ch := line.substr(rx, 1)
				if ch != "." and pal.has(ch):
					draw_rect(Rect2(bx + float(rx * PX), by + float(ry * PX), float(PX), float(PX)), pal[ch])
