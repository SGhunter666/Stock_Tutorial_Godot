## Application shell: top bar, global collapsible pixel trading floor banner,
## navigation sidebar, feature screens, start overlay, dialogue overlay and toast.
## Screens are rebuilt on locale/theme changes and only mutate state via Game.
class_name SmaMain
extends Control

const NAV_ITEMS := [
	["dashboard", "nav.dashboard"],
	["market", "nav.market"],
	["watchlist", "nav.watchlist"],
	["screener", "nav.screener"],
	["etf", "nav.etf"],
	["trade", "nav.trade"],
	["options", "nav.options"],
	["futures", "nav.futures"],
	["multiasset", "nav.multiasset"],
	["news", "nav.news"],
	["earnings", "nav.earnings"],
	["macro", "nav.macro"],
	["portfolio", "nav.portfolio"],
	["academy", "nav.academy"],
	["challenges", "nav.challenges"],
	["career", "nav.career"],
	["fund", "nav.fund"],
	["quant", "nav.quant"],
	["tax", "nav.tax"],
	["history", "nav.history"],
	["replay", "nav.replay"],
	["statements", "statements.title"],
	["glossary", "nav.glossary"],
	["sandbox", "nav.sandbox"],
	["roadmap", "roadmap.title"],
	["boundaries", "boundaries.title"],
	["settings", "nav.settings"],
	["story", "nav.story"],
]
const NAV_GROUPS := [
	{"id": "overview", "titleKey": "nav.group.overview", "items": [
		["dashboard", "nav.dashboard"],
		["portfolio", "nav.portfolio"],
		["watchlist", "nav.watchlist"],
	]},
	{"id": "research", "titleKey": "nav.group.research", "items": [
		["market", "nav.market"],
		["screener", "nav.screener"],
		["earnings", "nav.earnings"],
		["statements", "statements.title"],
		["news", "nav.news"],
		["macro", "nav.macro"],
	]},
	{"id": "execution", "titleKey": "nav.group.execution", "items": [
		["trade", "nav.trade"],
		["etf", "nav.etf"],
		["options", "nav.options"],
		["futures", "nav.futures"],
		["multiasset", "nav.multiasset"],
	]},
	{"id": "growth", "titleKey": "nav.group.growth", "items": [
		["academy", "nav.academy"],
		["story", "nav.story"],
		["challenges", "nav.challenges"],
		["career", "nav.career"],
	]},
	{"id": "fund_lab", "titleKey": "nav.group.fundLab", "items": [
		["fund", "nav.fund"],
		["quant", "nav.quant"],
		["history", "nav.history"],
		["replay", "nav.replay"],
		["tax", "nav.tax"],
		["sandbox", "nav.sandbox"],
	]},
	{"id": "system", "titleKey": "nav.group.system", "items": [
		["glossary", "nav.glossary"],
		["settings", "nav.settings"],
		["boundaries", "boundaries.title"],
		["roadmap", "roadmap.title"],
	]},
]
const CORE_NAV := ["dashboard", "market", "watchlist", "trade", "portfolio", "academy",
	"story", "settings"]
const COMPACT_WIDTH := 1360.0
const COMPACT_HEIGHT := 740.0

var _screens: Dictionary = {}
var _nav_buttons: Dictionary = {}
var _group_open: Dictionary = {
	"overview": true, "research": true, "execution": true,
	"growth": true, "fund_lab": false, "system": false,
}
var _group_boxes: Dictionary = {}
var _group_headers: Dictionary = {}
var _screen_group: Dictionary = {}
var _current_screen := "market"
var _screen_host: Control
var _office_banner: SmaPixelOfficeBanner
var _office_toggle: Button
var _topbar: Control
var _sidebar: Control
var _nav_menu: MenuButton
var _speed_box: HBoxContainer
var _speed_picker: OptionButton
var _dialogue: SmaDialoguePanel
var _start_overlay: Control
var _ff_overlay: Control
var _ff_bar: ProgressBar
var _ff_percent: Label
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _pixel_fx: SmaPixelFx
var _last_xp := -1
var _help_dialog: AcceptDialog

var _cash_label: Label
var _equity_label: Label
var _pnl_label: Label
var _day_label: Label
var _clock_dot: Label
var _clock_label: Label
var _story_badge: Label
var _pause_button: Button
var _speed_buttons: Dictionary = {}
var _step_buttons: Array[Button] = []
var _start_continue: Button
var _top_metrics: Dictionary = {}


class SmaCrtScanlines extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 90
	func _draw() -> void:
		if not SmaUiTheme.is_pixel():
			return
		var line_col := Color(0.0, 0.0, 0.0, 0.085)
		var y := 0.0
		while y < size.y:
			draw_rect(Rect2(0.0, y, size.x, 1.0), line_col)
			y += 3.0


class SmaPixelStartBackdrop extends Control:
	const PX := 4
	const BAYER := [
		[0, 8, 2, 10],
		[12, 4, 14, 6],
		[3, 11, 1, 9],
		[15, 7, 13, 5],
	]
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var gw := int(ceil(size.x / float(PX)))
		var gh := int(ceil(size.y / float(PX)))
		if gw <= 4 or gh <= 4:
			return
		var bands := [
			Color("#050814"),
			Color("#0c1631"),
			Color("#1b2654"),
			Color("#36265e"),
			Color("#6e3562"),
			Color("#b85d48"),
		]
		var nb := bands.size() - 1
		for gy in gh:
			var t := float(gy) / float(maxi(1, gh - 1)) * float(nb)
			var bi := mini(nb - 1, int(floor(t)))
			var frac := t - float(bi)
			var ca: Color = bands[bi]
			var cb: Color = bands[bi + 1]
			var brow: Array = BAYER[gy % 4]
			var thresh := int(frac * 16.0)
			var run_col := cb if int(brow[0]) < thresh else ca
			var run_start := 0
			for gx in gw:
				var c := cb if int(brow[gx % 4]) < thresh else ca
				if c != run_col:
					draw_rect(Rect2(run_start * PX, gy * PX, (gx - run_start) * PX, PX), run_col)
					run_col = c
					run_start = gx
			draw_rect(Rect2(run_start * PX, gy * PX, (gw - run_start) * PX, PX), run_col)

		# Pixel stars in upper sky
		for si in 42:
			var sx := ((si * 73 + 19) % maxi(10, gw - 4)) + 2
			var sy := ((si * 37 + 7) % maxi(6, int(gh * 0.48))) + 2
			var scol := Color("#fef08a") if (si % 5 == 0) else Color("#93c5fd")
			draw_rect(Rect2(sx * PX, sy * PX, PX, PX), scol)

		# Panoramic 16-bit financial district skyline silhouettes
		var back_x := 0
		var bi_idx := 0
		while back_x < gw:
			var bw := 10 + (bi_idx * 7) % 12
			var bh := int(gh * 0.22) + (bi_idx * 13) % maxi(8, int(gh * 0.24))
			draw_rect(Rect2(back_x * PX, (gh - bh) * PX, bw * PX, bh * PX), Color("#111730"))
			back_x += bw + 1
			bi_idx += 1

		var fx := 2
		var fi := 0
		while fx < gw:
			var fw := 12 + (fi * 9) % 14
			var fh := int(gh * 0.16) + (fi * 17 + 5) % maxi(10, int(gh * 0.28))
			var fy := gh - fh
			draw_rect(Rect2(fx * PX, fy * PX, fw * PX, fh * PX), Color("#080d1d"))
			draw_rect(Rect2(fx * PX, fy * PX, 2 * PX, fh * PX), Color("#1e2d4d"))
			if fi % 2 == 0 and fy > 6:
				draw_rect(Rect2((fx + int(fw / 2)) * PX, (fy - 5) * PX, PX, 5 * PX), Color("#38bdf8"))
			for wy in range(fy + 3, gh - 3, 4):
				for wx in range(fx + 3, fx + fw - 2, 3):
					if ((wx * 3 + wy + fi) % 4) == 0:
						var lit := Color("#fbbf24") if ((wx + fi) % 3 != 0) else Color("#5eead4")
						draw_rect(Rect2(wx * PX, wy * PX, PX, 2 * PX), lit)
			fx += fw + 4
			fi += 1
		# Subtle vignette overlay so center Start Card pops cleanly
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.09, 0.42))


func _ready() -> void:
	add_to_group("main")
	Game.state_changed.connect(_on_state_changed)
	Game.tick.connect(_on_tick)
	Game.story_changed.connect(_on_story_changed)
	Game.toast_requested.connect(show_toast)
	Game.game_started.connect(_on_game_started)
	Game.game_loaded.connect(_on_game_loaded)
	Game.fast_forward_started.connect(_on_fast_forward_started)
	Game.fast_forward_progress.connect(_on_fast_forward_progress)
	Game.fast_forward_finished.connect(_on_fast_forward_finished)
	Game.academy_changed.connect(_on_academy_changed)
	I18n.locale_changed.connect(_on_locale_changed)
	Game.layout_changed.connect(_on_layout_changed)
	Game.theme_changed.connect(_on_theme_changed)
	Game.trade_filled.connect(func(trade: Dictionary):
		_play_sound("fill")
		if _pixel_fx != null:
			_pixel_fx.spawn_trade_fill(trade))
	Game.order_rejected.connect(func(_error): _play_sound("reject"))
	Game.day_closed.connect(func(_day): _play_sound("day_close"))
	Game.achievement_unlocked.connect(func(ids: Array):
		_play_sound("achievement")
		if _pixel_fx != null and not ids.is_empty():
			_pixel_fx.spawn_honor(I18n.t("achievement.%s.title" % String(ids[0]))))
	Game.margin_call_triggered.connect(func(): _play_sound("margin_call"))
	Game.career_promoted.connect(func(rank: int):
		_play_sound("promotion")
		if _pixel_fx != null:
			var rdef: Dictionary = SmaCareer.rank_def(rank)
			_pixel_fx.spawn_honor("Rank %d · %s" % [rank, I18n.t(String(rdef.get("titleKey", "career.rank.retail.title")))]))
	Game.challenge_finished.connect(func(status, _id):
		_play_sound("achievement" if status == "completed" else "reject"))
	Game.price_alert_triggered.connect(func(_count): _play_sound("alert"))
	Game.game_started.connect(func(): _play_sound("story"))
	Game.game_loaded.connect(func(): _play_sound("story"))
	resized.connect(_sync_compact_layout)
	_build_ui()
	if not Game.started:
		_show_start_overlay()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and Game.started:
		Game.save_game(false)


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if SmaUiTheme.is_pixel() \
		else CanvasItem.TEXTURE_FILTER_LINEAR
	theme = SmaUiTheme.build()
	_start_overlay = null
	_ff_overlay = null
	_ff_bar = null
	_ff_percent = null
	_dialogue = null
	_office_banner = null
	_office_toggle = null
	_toast_panel = null
	_toast_label = null
	_toast_tween = null
	_pixel_fx = null
	_help_dialog = null
	_nav_buttons.clear()
	_group_boxes.clear()
	_group_headers.clear()
	_screen_group.clear()
	_speed_buttons.clear()
	_step_buttons.clear()
	_top_metrics.clear()
	SmaKit.clear_children(self)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = SmaUiTheme.BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	_topbar = _build_topbar()
	root.add_child(_topbar)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	root.add_child(body)
	_sidebar = _build_sidebar()
	body.add_child(_sidebar)

	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 0)
	body.add_child(right_col)

	if SmaUiTheme.is_pixel():
		_office_banner = SmaPixelOfficeBanner.new()
		_office_banner.custom_minimum_size = Vector2(280, 114)
		_office_banner.setup(Game)
		_office_banner.hotspot_clicked.connect(_on_office_hotspot)
		right_col.add_child(_office_banner)

	var content_margin := MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		content_margin.add_theme_constant_override("margin_%s" % side, 14)
	for side in ["top", "bottom"]:
		content_margin.add_theme_constant_override("margin_%s" % side, 12)
	right_col.add_child(content_margin)
	_screen_host = Control.new()
	_screen_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_screen_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_child(_screen_host)

	_build_screens()
	_dialogue = SmaDialoguePanel.new()
	_dialogue.setup(Game)
	add_child(_dialogue)
	_build_fast_forward_overlay()
	_build_toast()
	_pixel_fx = SmaPixelFx.new()
	_pixel_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_pixel_fx)
	if SmaUiTheme.is_pixel() and not bool(Game.settings.get("reducedMotion", false)):
		var crt := SmaCrtScanlines.new()
		crt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(crt)
	_sync_compact_layout()
	_update_topbar()
	_refresh_nav()
	_sync_music_mood()


func _build_topbar() -> Control:
	var bar := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#08101f") if SmaUiTheme.is_pixel() else SmaUiTheme.BG_DEEP
	style.border_color = SmaUiTheme.BORDER
	style.border_width_bottom = 2 if SmaUiTheme.is_pixel() else 1
	style.set_content_margin_all(0)
	bar.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_%s" % side, 14)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 8)
	bar.add_child(margin)
	var toolbar := SmaKit.flow(12)
	margin.add_child(toolbar)
	var row := SmaKit.hbox(10)
	toolbar.add_child(row)

	_nav_menu = MenuButton.new()
	_nav_menu.text = I18n.t("nav.menu")
	_nav_menu.focus_mode = Control.FOCUS_ALL
	var navigation := _nav_menu.get_popup()
	for index in NAV_ITEMS.size():
		navigation.add_radio_check_item(I18n.t(String(NAV_ITEMS[index][1])), index)
	navigation.id_pressed.connect(func(id): navigate(String(NAV_ITEMS[id][0])))
	row.add_child(_nav_menu)

	if SmaUiTheme.is_pixel():
		var logo := SmaKit.icon_rect("logo", Vector2(26, 26))
		logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(logo)

	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 1)
	var brand_main := SmaKit.label(
		"%s [SMA]" % I18n.t("app.title") if SmaUiTheme.is_pixel() else "SMA",
		18, SmaUiTheme.GOLD if SmaUiTheme.is_pixel() else SmaUiTheme.ACCENT)
	brand.add_child(brand_main)
	if not SmaUiTheme.is_pixel():
		brand.add_child(SmaKit.caption(I18n.t("app.title")))
	row.add_child(brand)
	row.add_child(_vertical_divider())

	var clock_pill := PanelContainer.new()
	clock_pill.add_theme_stylebox_override("panel", SmaUiTheme.readout_style(8, 4))
	var clock_row := SmaKit.hbox(6)
	clock_pill.add_child(clock_row)
	if SmaUiTheme.is_pixel():
		var cal_icon := SmaKit.icon_rect("calendar", Vector2(18, 18))
		cal_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		clock_row.add_child(cal_icon)
	var clock_box := VBoxContainer.new()
	clock_box.add_theme_constant_override("separation", 0)
	_day_label = SmaKit.label("—", 11, SmaUiTheme.MUTED)
	var time_row := SmaKit.hbox(4)
	_clock_dot = SmaKit.label("●", 11, SmaUiTheme.POSITIVE)
	_clock_label = SmaKit.label("09:30:00", 14, SmaUiTheme.ACCENT if SmaUiTheme.is_pixel() else SmaUiTheme.TEXT)
	time_row.add_child(_clock_dot)
	time_row.add_child(_clock_label)
	clock_box.add_child(_day_label)
	clock_box.add_child(time_row)
	clock_row.add_child(clock_box)
	row.add_child(clock_pill)

	for spec in [
		["cash", "header.cash", "cash", Vector2(22, 16)],
		["equity", "header.equity", "equity", Vector2(18, 18)],
		["pnl", "header.day_pnl", "pnl", Vector2(16, 16)],
	]:
		var metric_pill := PanelContainer.new()
		metric_pill.add_theme_stylebox_override("panel", SmaUiTheme.readout_style(8, 4))
		var m_row := SmaKit.hbox(6)
		metric_pill.add_child(m_row)
		if SmaUiTheme.is_pixel():
			var m_icon := SmaKit.icon_rect(String(spec[2]), spec[3])
			m_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			m_row.add_child(m_icon)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		box.add_child(SmaKit.caption(I18n.t(String(spec[1]))))
		var val_col := SmaUiTheme.POSITIVE if (SmaUiTheme.is_pixel() and String(spec[0]) == "cash") else SmaUiTheme.TEXT
		var value := SmaKit.label("—", 14, val_col)
		box.add_child(value)
		_top_metrics[String(spec[0])] = value
		m_row.add_child(box)
		row.add_child(metric_pill)
	_cash_label = _top_metrics["cash"]
	_equity_label = _top_metrics["equity"]
	_pnl_label = _top_metrics["pnl"]

	var actions := SmaKit.hbox(6)
	toolbar.add_child(actions)
	_speed_box = HBoxContainer.new()
	_speed_box.add_theme_constant_override("separation", 3)
	var group := ButtonGroup.new()
	for value in Game.SPEEDS:
		var button := SmaKit.toggle("%d×" % value, group)
		button.custom_minimum_size.x = 38
		button.pressed.connect(_on_speed.bind(int(value)))
		_speed_buttons[int(value)] = button
		_speed_box.add_child(button)
	actions.add_child(_speed_box)

	_speed_picker = OptionButton.new()
	for value in Game.SPEEDS:
		_speed_picker.add_item("%d×" % value)
	_speed_picker.item_selected.connect(func(index): _on_speed(int(Game.SPEEDS[index])))
	actions.add_child(_speed_picker)

	_pause_button = SmaKit.arcade_button(I18n.t("header.pause"), "amber", _toggle_pause)
	_pause_button.custom_minimum_size.x = 64
	actions.add_child(_pause_button)

	var minute_button := SmaKit.button(I18n.t("header.step_minute"), _step_minute)
	minute_button.tooltip_text = I18n.t("header.step_minute")
	_step_buttons.append(minute_button)
	actions.add_child(minute_button)

	var day_button := SmaKit.button(I18n.t("header.step_day"), _step_day)
	day_button.tooltip_text = I18n.t("header.step_day")
	_step_buttons.append(day_button)
	actions.add_child(day_button)

	if SmaUiTheme.is_pixel():
		_office_toggle = SmaKit.toggle(I18n.t("pixelOffice.toggle"))
		_office_toggle.icon = SmaPixelArt.icon("office")
		_office_toggle.button_pressed = bool(Game.settings.get("showPixelOffice", true))
		_office_toggle.toggled.connect(func(on: bool):
			Game.settings["showPixelOffice"] = on
			_sync_compact_layout())
		actions.add_child(_office_toggle)

	var save_button := SmaKit.button(I18n.t("header.save"), func(): Game.save_game(true))
	actions.add_child(save_button)

	var language := SmaKit.button("中 / EN", _toggle_language)
	actions.add_child(language)
	return bar


func _sync_compact_layout() -> void:
	if _sidebar == null:
		return
	var compact := size.x < COMPACT_WIDTH
	var in_scenario: bool = Game.opening_gap_active or Game.black_friday_active
	_topbar.visible = not in_scenario
	_sidebar.visible = not compact and not in_scenario
	_nav_menu.visible = compact
	_speed_box.visible = not compact
	_speed_picker.visible = compact
	if _office_banner != null:
		var want_office := bool(Game.settings.get("showPixelOffice", true))
		var tall_enough := size.y >= COMPACT_HEIGHT or size.y <= 10.0
		var hide_for_screen := _current_screen in ["settings", "boundaries", "roadmap", "glossary"]
		_office_banner.visible = Game.started and want_office and tall_enough \
			and not in_scenario and not hide_for_screen


func _build_sidebar() -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#060b16") if SmaUiTheme.is_pixel() else SmaUiTheme.BG_DEEP
	style.border_color = SmaUiTheme.BORDER
	style.border_width_right = 2 if SmaUiTheme.is_pixel() else 1
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size.x = 208

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var nav_scroll := ScrollContainer.new()
	nav_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	nav_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(nav_scroll)
	var nav_box := VBoxContainer.new()
	nav_box.add_theme_constant_override("separation", 4)
	nav_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_scroll.add_child(nav_box)
	var group := ButtonGroup.new()
	var advanced_nav: bool = String(Game.settings.get("layout", "beginner")) == "advanced"
	var header_col := SmaUiTheme.GOLD if SmaUiTheme.is_pixel() else SmaUiTheme.DIM
	for section in NAV_GROUPS:
		var gid := String(section["id"])
		var expanded := true if advanced_nav else bool(_group_open.get(gid, true))
		_group_open[gid] = expanded
		var header := Button.new()
		header.flat = true
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if SmaUiTheme.is_pixel():
			header.add_theme_font_override("font", SmaUiTheme.pixel_font_12())
			header.add_theme_font_size_override("font_size", 12)
		else:
			header.add_theme_font_size_override("font_size", 11)
		header.add_theme_color_override("font_color", header_col)
		header.text = "%s %s" % ["▾" if expanded else "▸", I18n.t(String(section["titleKey"]))]
		var items_box := SmaKit.vbox(3)
		items_box.visible = expanded
		header.pressed.connect(func():
			var next := not bool(_group_open.get(gid, true))
			_group_open[gid] = next
			items_box.visible = next
			header.text = "%s %s" % ["▾" if next else "▸", I18n.t(String(section["titleKey"]))])
		nav_box.add_child(header)
		nav_box.add_child(items_box)
		_group_headers[gid] = header
		_group_boxes[gid] = items_box
		for entry in section["items"]:
			var screen_id := String(entry[0])
			_screen_group[screen_id] = gid
			var button := SmaKit.toggle(I18n.t(String(entry[1])), group)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size.y = 32
			if SmaUiTheme.is_pixel():
				button.icon = SmaPixelArt.icon(screen_id)
			button.pressed.connect(func(): navigate(screen_id))
			_nav_buttons[screen_id] = button
			items_box.add_child(button)
	_story_badge = SmaKit.caption("")
	nav_box.add_child(_story_badge)
	var disclaimer := SmaKit.caption(I18n.t("app.disclaimer"))
	disclaimer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(disclaimer)
	return panel


func _vertical_divider() -> Control:
	var line := ColorRect.new()
	line.color = SmaUiTheme.BORDER
	line.custom_minimum_size.x = 2 if SmaUiTheme.is_pixel() else 1
	line.custom_minimum_size.y = 34
	return line


func _build_screens() -> void:
	_screens.clear()
	_screens["dashboard"] = SmaDashboardScreen.new()
	_screens["opening_gap"] = SmaOpeningGapScreen.new()
	_screens["black_friday"] = SmaBlackFridayScreen.new()
	_screens["market"] = SmaMarketScreen.new()
	_screens["watchlist"] = SmaWatchlistScreen.new()
	_screens["screener"] = SmaScreenerScreen.new()
	_screens["etf"] = SmaEtfScreen.new()
	_screens["trade"] = SmaTradeScreen.new()
	_screens["options"] = SmaOptionsScreen.new()
	_screens["futures"] = SmaFuturesScreen.new()
	_screens["multiasset"] = SmaMultiAssetScreen.new()
	_screens["news"] = SmaNewsScreen.new()
	_screens["earnings"] = SmaEarningsCenterScreen.new()
	_screens["macro"] = SmaMacroScreen.new()
	_screens["portfolio"] = SmaPortfolioScreen.new()
	_screens["academy"] = SmaAcademyScreen.new()
	_screens["challenges"] = SmaChallengesScreen.new()
	_screens["career"] = SmaCareerScreen.new()
	_screens["fund"] = SmaFundScreen.new()
	_screens["quant"] = SmaQuantScreen.new()
	_screens["tax"] = SmaTaxScreen.new()
	_screens["history"] = SmaHistoryScreen.new()
	_screens["replay"] = SmaReplayScreen.new()
	_screens["statements"] = SmaStatementsScreen.new()
	_screens["glossary"] = SmaGlossaryScreen.new()
	_screens["sandbox"] = SmaSandboxScreen.new()
	_screens["roadmap"] = SmaRoadmapScreen.new()
	_screens["boundaries"] = SmaBoundariesScreen.new()
	_screens["settings"] = SmaSettingsScreen.new()
	_screens["story"] = SmaStoryScreen.new()
	for id in _screens.keys():
		var screen: SmaScreen = _screens[id]
		screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_screen_host.add_child(screen)
		screen.setup(Game)
		screen.visible = false
	navigate(_current_screen, false)


func _build_toast() -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.add_theme_stylebox_override("panel",
		SmaUiTheme.panel_style(SmaUiTheme.PANEL_ALT, SmaUiTheme.GOLD if SmaUiTheme.is_pixel() else SmaUiTheme.ACCENT_DARK, 10, false))
	_toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_panel.position = Vector2(size.x * 0.5, size.y - 70)
	_toast_panel.visible = false
	_toast_panel.z_index = 60
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = SmaKit.label("", 12)
	_toast_panel.add_child(_toast_label)
	add_child(_toast_panel)


# ---------------------------------------------------------------------------
# Navigation and refresh
# ---------------------------------------------------------------------------

func navigate(screen_id: String, force: bool = false) -> void:
	if not _screens.has(screen_id):
		return
	if screen_id == "opening_gap":
		if not Game.enter_opening_gap():
			return
	elif Game.opening_gap_active:
		Game.leave_opening_gap()
	if screen_id == "black_friday":
		if not Game.enter_black_friday():
			return
		_play_sound("crisis_alarm")
	elif Game.black_friday_active:
		Game.leave_black_friday()
	_current_screen = screen_id
	var navigation := _nav_menu.get_popup()
	for index in NAV_ITEMS.size():
		navigation.set_item_checked(index, NAV_ITEMS[index][0] == screen_id)
	var gid := String(_screen_group.get(screen_id, ""))
	if gid != "" and _group_boxes.has(gid) and not bool(_group_open.get(gid, false)):
		_group_open[gid] = true
		_group_boxes[gid].visible = true
		if _group_headers.has(gid):
			for section in NAV_GROUPS:
				if String(section["id"]) == gid:
					_group_headers[gid].text = "▾ %s" % I18n.t(String(section["titleKey"]))
					break
	for id in _screens.keys():
		_screens[id].visible = id == screen_id
	for id in _nav_buttons.keys():
		_nav_buttons[id].button_pressed = id == screen_id
	var screen: SmaScreen = _screens[screen_id]
	if force or not screen.built:
		screen.setup(Game)
	else:
		screen.refresh("nav")
	if _office_banner != null:
		_office_banner.set_screen(screen_id)
		_office_banner.refresh_state()
	_sync_compact_layout()
	_sync_music_mood()


func open_ticker(ticker: String, screen_id: String = "trade") -> void:
	Game.select_ticker(ticker)
	navigate(screen_id)


func _refresh_nav() -> void:
	for id in _nav_buttons.keys():
		_nav_buttons[id].button_pressed = id == _current_screen
	if _story_badge != null:
		var active := Game.started and Game.narrative != null and Game.narrative.is_active()
		_story_badge.text = "● %s" % I18n.t("story.active") if active else ""


func _on_state_changed(reason: String) -> void:
	_update_topbar()
	_refresh_nav()
	if _office_banner != null:
		_office_banner.set_screen(_current_screen)
		_office_banner.refresh_state()
	if _screens.has(_current_screen):
		_screens[_current_screen].refresh(reason)


func _on_tick() -> void:
	_update_topbar()
	if Game.is_fast_forwarding():
		return
	if _screens.has(_current_screen):
		_screens[_current_screen].on_tick()


func _on_story_changed() -> void:
	_refresh_nav()
	if _dialogue != null:
		_dialogue.refresh()
	if _screens.has(_current_screen):
		_screens[_current_screen].refresh("story")


func _current_xp() -> int:
	return int(SmaAcademy.level_info(Game.academy).get("xp", 0)) if Game.started else -1


func _on_academy_changed() -> void:
	var now_xp := _current_xp()
	if _last_xp >= 0 and now_xp > _last_xp and _pixel_fx != null:
		_pixel_fx.spawn_xp_gain(now_xp - _last_xp)
	_last_xp = now_xp
	if _screens.has("academy"):
		_screens["academy"].refresh("academy")


func _on_game_started() -> void:
	_last_xp = _current_xp()
	if _start_overlay != null:
		_start_overlay.visible = false
	_sync_compact_layout()
	navigate("dashboard" if Game.has_intro_task() else "market")


func _on_game_loaded() -> void:
	_last_xp = _current_xp()
	if _start_overlay != null:
		_start_overlay.visible = false
	# A save carries its own theme and layout, so rebuild before showing it.
	_build_ui()
	navigate("dashboard" if Game.has_intro_task() or Game.opening_gap_unlocked() else "market")


func _on_office_hotspot(kind: String, payload: Dictionary) -> void:
	match kind:
		"mentor":
			_play_sound("story")
			var dlg := SmaOfficePopupDialog.new()
			add_child(dlg)
			dlg.navigate_requested.connect(func(dest: String): navigate(dest))
			dlg.setup(Game, "mentor", String(payload.get("mentor", "lin_lan")))
		"honors":
			_play_sound("achievement")
			var dlg := SmaOfficePopupDialog.new()
			add_child(dlg)
			dlg.navigate_requested.connect(func(dest: String): navigate(dest))
			dlg.setup(Game, "honors")
		"coffee":
			_play_sound("pixel_coffee")
			if _pixel_fx != null:
				_pixel_fx.spawn_burst(payload.get("pos", size * 0.5), SmaUiTheme.GOLD, 8)
			show_toast("♦ " + String(payload.get("quip", "")))
		"ticker":
			_play_sound("pixel_click")
			var sym := String(payload.get("ticker", "APLA"))
			open_ticker(sym, "etf" if SmaEtfs.is_etf(sym) else "trade")


func _build_fast_forward_overlay() -> void:
	_ff_overlay = Control.new()
	_ff_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ff_overlay.z_index = 45
	_ff_overlay.visible = false
	_ff_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_ff_overlay)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.07, 0.72)
	_ff_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ff_overlay.add_child(center)
	var panel := SmaKit.card(22)
	panel.custom_minimum_size = Vector2(480, 0)
	center.add_child(panel)
	var box := SmaKit.vbox(10)
	panel.add_child(box)
	box.add_child(SmaKit.title(I18n.t("fast_forward.title"), 20))
	box.add_child(SmaKit.muted(I18n.t("fast_forward.hint")))
	_ff_bar = ProgressBar.new()
	_ff_bar.min_value = 0
	_ff_bar.max_value = 100
	_ff_bar.value = 0
	_ff_bar.show_percentage = false
	_ff_bar.custom_minimum_size = Vector2(420, 14)
	box.add_child(_ff_bar)
	_ff_percent = SmaKit.caption("0%")
	box.add_child(_ff_percent)


func _on_fast_forward_started() -> void:
	if _ff_overlay != null:
		_ff_overlay.visible = true
		_ff_bar.value = 0
		_ff_percent.text = "0%"


func _on_fast_forward_progress(value: float) -> void:
	if _ff_bar == null:
		return
	var percent := clampf(value, 0.0, 1.0)
	_ff_bar.value = percent * 100.0
	_ff_percent.text = "%d%%" % int(round(percent * 100.0))


func _on_fast_forward_finished() -> void:
	if _ff_overlay != null:
		_ff_overlay.visible = false
	_update_topbar()


func _update_topbar() -> void:
	if not Game.started or Game.exchange == null:
		_day_label.text = "—"
		_clock_label.text = "09:30:00"
		_cash_label.text = "—"
		_equity_label.text = "—"
		_pnl_label.text = "—"
		_sync_music_mood()
		return
	var day := int(Game.exchange.state["dayIndex"])
	_day_label.text = "DAY %02d · %s" % [day + 1, SmaCalendar.format_date(day, I18n.locale)]
	if _clock_dot != null:
		_clock_dot.text = "⏸" if Game.paused else "●"
		_clock_dot.add_theme_color_override("font_color",
			SmaUiTheme.WARNING if Game.paused else SmaUiTheme.POSITIVE)
	_clock_label.text = SmaCalendar.session_clock(int(Game.exchange.state["second"]))
	var cash := float(Game.exchange.state["account"]["cash"])
	var equity := Game.exchange.equity()
	var pnl := equity - _day_start_equity()
	_cash_label.text = SmaFormat.money(cash)
	_equity_label.text = SmaFormat.money(equity)
	_pnl_label.text = SmaFormat.signed_money(pnl)
	_pnl_label.add_theme_color_override("font_color", SmaKit.value_color(pnl))
	_pause_button.text = I18n.t("header.play") if Game.paused else I18n.t("header.pause")
	var fast_forwarding: bool = Game.is_fast_forwarding()
	_pause_button.disabled = Game.is_story_paused() or fast_forwarding
	for value in _speed_buttons.keys():
		_speed_buttons[value].button_pressed = int(Game.speed) == int(value)
		_speed_buttons[value].disabled = fast_forwarding
	_speed_picker.select(Game.SPEEDS.find(int(Game.speed)))
	_speed_picker.disabled = fast_forwarding
	for button in _step_buttons:
		button.disabled = Game.is_story_paused() or fast_forwarding
	_sync_music_mood()


func _day_start_equity() -> float:
	var history: Array = Game.exchange.state["account"]["equityHistory"]
	var day := int(Game.exchange.state["dayIndex"])
	var value := float(Game.exchange.state["account"]["initialCash"])
	for point in history:
		if int(point.get("day", 0)) < day:
			value = float(point.get("equity", value))
	return value


# ---------------------------------------------------------------------------
# Header actions
# ---------------------------------------------------------------------------

func _on_speed(value: int) -> void:
	Game.set_speed(value)
	if Game.paused and not Game.is_story_paused():
		Game.set_paused(false)
	_update_topbar()


func _toggle_pause() -> void:
	Game.toggle_pause()
	_update_topbar()


func _step_minute() -> void:
	Game.step_minute()
	_update_topbar()


func _step_day() -> void:
	Game.step_day()
	_update_topbar()


func _toggle_language() -> void:
	I18n.toggle()
	Game.settings["locale"] = I18n.locale
	Game.academy_mark_language_switched()


func _on_locale_changed(_locale: String) -> void:
	var start_visible := _start_overlay != null and _start_overlay.visible
	var previous := _screens.get(_current_screen) as SmaScreen
	var draft := previous.capture_draft() if previous != null and not start_visible else {}
	_build_ui()
	if not Game.started or start_visible:
		_show_start_overlay()
	elif not draft.is_empty():
		var current := _screens.get(_current_screen) as SmaScreen
		if current != null:
			current.restore_draft(draft)


func _on_layout_changed() -> void:
	var start_visible := _start_overlay != null and _start_overlay.visible
	_build_ui()
	if not Game.started or start_visible:
		_show_start_overlay()


func _on_theme_changed() -> void:
	var start_visible := _start_overlay != null and _start_overlay.visible
	_build_ui()
	if not Game.started or start_visible:
		_show_start_overlay()


# ---------------------------------------------------------------------------
# Start overlay and toast
# ---------------------------------------------------------------------------

func _show_start_overlay() -> void:
	if _start_overlay != null:
		_start_overlay.visible = true
		return
	_start_overlay = Control.new()
	_start_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_start_overlay.z_index = 40
	add_child(_start_overlay)
	if SmaUiTheme.is_pixel():
		var px_bg := SmaPixelStartBackdrop.new()
		px_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_start_overlay.add_child(px_bg)
	else:
		var dim := ColorRect.new()
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.color = Color(0.02, 0.04, 0.07, 0.9)
		_start_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_start_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", SmaUiTheme.panel_style(
		SmaUiTheme.PANEL, SmaUiTheme.GOLD if SmaUiTheme.is_pixel() else SmaUiTheme.BORDER, 24, true))
	panel.custom_minimum_size = Vector2(760 if SmaUiTheme.is_pixel() else 620, 0)
	center.add_child(panel)

	var outer := SmaKit.hbox(20)
	panel.add_child(outer)

	if SmaUiTheme.is_pixel() and ResourceLoader.exists("res://assets/portraits/pixel/lin_lan.png"):
		var left_col := SmaKit.vbox(8)
		left_col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var p_frame := PanelContainer.new()
		p_frame.add_theme_stylebox_override("panel",
			SmaPixelArt.card_box(Color("#091322"), SmaUiTheme.ACCENT, Color("#040811"), 4, false))
		var p_rect := TextureRect.new()
		p_rect.texture = load("res://assets/portraits/pixel/lin_lan.png") as Texture2D
		p_rect.custom_minimum_size = Vector2(192, 256)
		p_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		p_frame.add_child(p_rect)
		left_col.add_child(p_frame)
		var welcome_badge := SmaKit.label(I18n.t("pixelOffice.mentorWelcome"), 12, SmaUiTheme.ACCENT)
		welcome_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		left_col.add_child(welcome_badge)
		outer.add_child(left_col)

	var box := SmaKit.vbox(12)
	outer.add_child(box)
	var brand_row := SmaKit.hbox(8)
	if SmaUiTheme.is_pixel():
		brand_row.add_child(SmaKit.icon_rect("logo", Vector2(22, 22)))
	brand_row.add_child(SmaKit.label("FARVIEW TRADING ACADEMY · [SMA]", 13,
		SmaUiTheme.GOLD if SmaUiTheme.is_pixel() else SmaUiTheme.ACCENT))
	box.add_child(brand_row)
	box.add_child(SmaKit.title(I18n.t("start.title"), 34))
	box.add_child(SmaKit.muted(I18n.t("start.subtitle"), 13))
	box.add_child(SmaKit.caption(I18n.t("app.tagline")))
	box.add_child(SmaKit.separator())
	var name_row := SmaKit.hbox(8)
	name_row.add_child(SmaKit.label(I18n.t("start.playerNameLabel"), 12, SmaUiTheme.MUTED))
	var name_edit := LineEdit.new()
	name_edit.name = "StartPlayerName"
	name_edit.placeholder_text = I18n.t("start.playerNamePlaceholder")
	name_edit.text = String(Game.settings.get("playerName", ""))
	name_edit.max_length = 24
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(v: String): Game.settings["playerName"] = v.strip_edges().substr(0, 24))
	name_row.add_child(name_edit)
	box.add_child(name_row)
	var slot_box := SmaKit.vbox(4)
	slot_box.add_child(SmaKit.caption(I18n.t("start.saveSlotTitle")))
	var slot_row := SmaKit.hbox(6)
	var slot_group := ButtonGroup.new()
	var slot_info := SmaKit.caption("")
	var refresh_slot_ui := func():
		var summary := SmaSaveService.slot_summary(Game.active_slot)
		if bool(summary.get("exists", false)):
			var pname := String(summary.get("playerName", ""))
			if pname == "":
				pname = I18n.t("player.defaultName")
			slot_info.text = I18n.t("start.slotSummary", {
				"slot": Game.active_slot, "name": pname,
				"day": int(summary["day"]) + 1,
				"equity": SmaFormat.money(float(summary["equity"])),
				"rank": int(summary["rank"]),
			})
		else:
			slot_info.text = I18n.t("start.slotEmpty", {"slot": Game.active_slot})
		if _start_continue != null:
			_start_continue.disabled = not Game.has_save()
	for slot in range(1, SmaSaveService.SLOT_COUNT + 1):
		var s_summary := SmaSaveService.slot_summary(slot)
		var badge := "●" if bool(s_summary.get("exists", false)) else "○"
		var btn := SmaKit.toggle("%s %s" % [badge, I18n.t("settings.slotLabel", {"slot": slot})], slot_group)
		btn.button_pressed = slot == Game.active_slot
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func():
			Game.select_save_slot(slot)
			refresh_slot_ui.call())
		slot_row.add_child(btn)
	slot_box.add_child(slot_row)
	slot_box.add_child(slot_info)
	box.add_child(slot_box)

	var cta_row := SmaKit.hbox(10)
	var new_game := SmaKit.arcade_button("▶ " + I18n.t("start.new_game"), "buy", _start_new_game, 20)
	new_game.custom_minimum_size.y = 46
	new_game.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cta_row.add_child(new_game)
	_start_continue = SmaKit.arcade_button("⏵ " + I18n.t("start.continue"), "amber", _continue_game, 20)
	_start_continue.custom_minimum_size.y = 46
	_start_continue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_continue.disabled = not Game.has_save()
	cta_row.add_child(_start_continue)
	box.add_child(cta_row)

	refresh_slot_ui.call()
	if not Game.has_save():
		box.add_child(SmaKit.caption(I18n.t("start.no_save")))
	box.add_child(SmaKit.separator())
	var footer := SmaKit.hbox(8)
	footer.add_child(SmaKit.caption(I18n.t("start.footer")))
	footer.add_child(SmaKit.hspacer())
	footer.add_child(SmaKit.caption(I18n.t("app.version", {
		"version": String(ProjectSettings.get_setting("application/config/version", "beta-08")),
	})))
	var next_mode := "dark" if SmaUiTheme.is_pixel() else "pixel"
	var theme_btn := SmaKit.button(
		I18n.t("settings.themeDark" if SmaUiTheme.is_pixel() else "settings.themePixel"),
		func(): Game.set_theme(next_mode))
	footer.add_child(theme_btn)
	footer.add_child(SmaKit.button(I18n.t("start.language"), _toggle_language))
	box.add_child(footer)
	var disclaimer := SmaKit.caption(I18n.t("app.disclaimer"))
	disclaimer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(disclaimer)


func _start_new_game() -> void:
	if Game.has_save():
		var dialog := ConfirmationDialog.new()
		dialog.title = I18n.t("start.replaceTitle")
		dialog.dialog_text = I18n.t("start.replaceMessage")
		dialog.ok_button_text = I18n.t("start.new_game")
		dialog.get_cancel_button().text = I18n.t("start.cancel")
		dialog.canceled.connect(dialog.queue_free)
		dialog.confirmed.connect(func():
			dialog.queue_free()
			Game.new_game())
		add_child(dialog)
		dialog.popup_centered()
		dialog.get_cancel_button().grab_focus()
		return
	Game.new_game()


func _continue_game() -> void:
	if Game.load_game() and _start_overlay != null:
		_start_overlay.visible = false


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var ctrl: bool = key_event.ctrl_pressed or key_event.meta_pressed
	if key_event.keycode == KEY_F1:
		_toggle_shortcuts()
		get_viewport().set_input_as_handled()
		return
	if ctrl and key_event.keycode == KEY_S:
		Game.save_game(true)
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode == KEY_ESCAPE and _help_dialog != null \
			and is_instance_valid(_help_dialog) and _help_dialog.visible:
		_help_dialog.hide()
		get_viewport().set_input_as_handled()
		return
	if ctrl or key_event.alt_pressed or _shortcuts_blocked():
		return
	var speeds := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]
	var speed_index := speeds.find(key_event.keycode)
	if speed_index >= 0:
		_on_speed(int(Game.SPEEDS[speed_index]))
		get_viewport().set_input_as_handled()
		return
	match key_event.keycode:
		KEY_SPACE:
			Game.toggle_pause()
			_update_topbar()
		KEY_N:
			Game.step_day()
			_update_topbar()
		KEY_M:
			Game.step_minute()
			_update_topbar()
		_:
			return
	get_viewport().set_input_as_handled()


func _shortcuts_blocked() -> bool:
	if not Game.started or Game.opening_gap_active or Game.black_friday_active:
		return true
	if _start_overlay != null and _start_overlay.visible:
		return true
	if _ff_overlay != null and _ff_overlay.visible:
		return true
	if Game.narrative != null and Game.narrative.is_active():
		return true
	if Game.is_fast_forwarding():
		return true
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit or focus is BaseButton or focus is HSlider:
		return true
	return false


func _toggle_shortcuts() -> void:
	if _help_dialog != null and is_instance_valid(_help_dialog):
		if _help_dialog.visible:
			_help_dialog.hide()
		else:
			_help_dialog.popup_centered()
		return
	var dialog := AcceptDialog.new()
	dialog.title = I18n.t("shortcuts.title")
	dialog.ok_button_text = I18n.t("common.close")
	dialog.dialog_text = "\n".join([
		I18n.t("shortcuts.pause"),
		I18n.t("shortcuts.day"),
		I18n.t("shortcuts.minute"),
		I18n.t("shortcuts.speed"),
		I18n.t("shortcuts.save"),
		I18n.t("shortcuts.help"),
		"",
		I18n.t("shortcuts.hint"),
	])
	dialog.min_size = Vector2i(520, 340)
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())
	add_child(dialog)
	_help_dialog = dialog
	dialog.popup_centered()


func _sync_music_mood() -> void:
	var audio := get_node_or_null("/root/Sfx")
	if audio == null or not audio.has_method("set_music_mood"):
		return
	var crisis: bool = Game.black_friday_active or Game.opening_gap_active
	if not crisis and Game.started and Game.exchange != null:
		crisis = Game.exchange.state["account"]["margin"].get("call", null) != null
	var mood := String(audio.resolve_mood(
		SmaUiTheme.is_pixel(), Game.started, Game.paused, crisis, _current_screen))
	audio.set_music_mood(mood)


func _play_sound(sound: String) -> void:
	var audio := get_node_or_null("/root/Sfx")
	if audio != null and audio.has_method("play"):
		audio.play(sound)


func show_toast(message: String) -> void:
	if _toast_panel == null or message == "":
		return
	_toast_label.text = message
	_toast_panel.visible = true
	_toast_panel.modulate = Color.WHITE
	_toast_panel.reset_size()
	_toast_panel.position = Vector2(size.x * 0.5 - _toast_panel.size.x * 0.5, size.y - 76)
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.6)
	if not bool(Game.settings.get("reducedMotion", false)):
		_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.35)
	_toast_tween.tween_callback(func(): _toast_panel.visible = false)
