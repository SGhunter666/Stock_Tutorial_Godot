## Window sizing helpers. The UI is authored against a 1440x900 canvas and the
## project's canvas_items + expand stretch mode scales it to the window.
class_name SmaDisplay
extends RefCounted

const BASE_SIZE := Vector2i(1440, 900)
const MIN_SIZE := Vector2i(1280, 720)
const MAX_SIZE := Vector2i(2560, 1600)
const PRESETS := ["auto", "1280x720", "1280x800", "1366x768", "1440x900",
	"1600x900", "1680x1050", "1920x1080", "1920x1200", "2560x1440", "2560x1600"]
const MODES := ["windowed", "fullscreen"]
const UI_SCALES := ["auto", "1.0", "1.1", "1.25"]


static func normalise_mode(mode: String) -> String:
	return mode if MODES.has(mode) else "windowed"


static func normalise_preset(preset: String) -> String:
	return preset if PRESETS.has(preset) else "auto"


static func normalise_ui_scale(value: String) -> String:
	return value if UI_SCALES.has(value) else "auto"


## 125% is only safe on a large window; smaller windows fall back to 110%.
static func resolve_ui_scale(value: String, window_size: Vector2i) -> float:
	var mode := normalise_ui_scale(value)
	if mode == "auto":
		# Small windows lose physical text size under canvas scaling; a mild
		# 110% UI scale keeps the chart and labels readable.
		return 1.1 if window_size.x < BASE_SIZE.x or window_size.y < BASE_SIZE.y else 1.0
	var requested := float(mode)
	var max_scale := 1.1
	if window_size.x >= 1600 and window_size.y >= 1000:
		max_scale = 1.25
	return clampf(requested, 1.0, max_scale)


static func target_window_size(screen_size: Vector2i, preset: String) -> Vector2i:
	var target := BASE_SIZE
	if normalise_preset(preset) == "auto":
		target = Vector2i(int(float(screen_size.x) * 0.9),
			int(float(screen_size.y) * 0.88))
	else:
		var dimensions := preset.split("x")
		if dimensions.size() == 2:
			target = Vector2i(int(dimensions[0]), int(dimensions[1]))
	target.x = clampi(target.x, MIN_SIZE.x, maxi(MIN_SIZE.x, mini(screen_size.x, MAX_SIZE.x)))
	target.y = clampi(target.y, MIN_SIZE.y, maxi(MIN_SIZE.y, mini(screen_size.y, MAX_SIZE.y)))
	return target


## Snapshot used by the settings screen to explain the automatic choice.
static func display_snapshot() -> Dictionary:
	var usable := DisplayServer.screen_get_usable_rect()
	var window := DisplayServer.window_get_size()
	if window.x <= 0 or window.y <= 0:
		window = BASE_SIZE
	var usable_size := usable.size
	if usable_size.x <= 0 or usable_size.y <= 0:
		usable_size = BASE_SIZE
	return {
		"window": window,
		"usable": usable_size,
		"auto": target_window_size(usable_size, "auto"),
	}


static func centered_position(usable: Rect2i, window_size: Vector2i) -> Vector2i:
	return usable.position + (usable.size - window_size) / 2


## Pure display decision: headless tests can cover the fullscreen branch without
## touching the DisplayServer.
static func resolve_display(mode: String, preset: String, usable: Rect2i) -> Dictionary:
	if normalise_mode(mode) == "fullscreen":
		return {"mode": "fullscreen", "size": usable.size, "position": usable.position}
	var size := target_window_size(usable.size, normalise_preset(preset))
	return {"mode": "windowed", "size": size, "position": centered_position(usable, size)}
