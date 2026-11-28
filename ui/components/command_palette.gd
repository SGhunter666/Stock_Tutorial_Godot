## Global Command Palette (Cmd+K / Ctrl+K) — Bloomberg-style instant jump
## across all 108 stocks/ETFs, all screens, and quick trading-floor actions.
class_name SmaCommandPalette
extends Control

signal closed
signal ticker_selected(ticker: String)
signal screen_selected(screen_id: String)
signal action_selected(action_id: String)

var game: Node
var _nav_items: Array = []
var _search: LineEdit
var _list_box: VBoxContainer
var _items: Array[Dictionary] = []
var _selected_idx := 0
var _row_buttons: Array[Button] = []


func setup(game_ref: Node, nav_items: Array) -> void:
	game = game_ref
	_nav_items = nav_items
	_build()
	_refresh_results("")
	_search.grab_focus.call_deferred()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 74

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.08, 0.78)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close())
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var card := SmaKit.modal_card(14)
	card.custom_minimum_size = Vector2(640, 440)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)

	var root := SmaKit.vbox(8)
	card.add_child(root)

	var head := SmaKit.hbox(8)
	head.add_child(SmaKit.label(I18n.t("palette.title"), 14, SmaUiTheme.GOLD))
	head.add_child(SmaKit.hspacer())
	head.add_child(SmaKit.caption(I18n.t("palette.hint")))
	root.add_child(head)

	_search = LineEdit.new()
	_search.placeholder_text = I18n.t("palette.placeholder")
	_search.custom_minimum_size.y = 36
	_search.text_changed.connect(func(t: String):
		_selected_idx = 0
		_refresh_results(t))
	_search.text_submitted.connect(func(_t: String):
		_activate_selected())
	root.add_child(_search)

	var scroll := SmaKit.scroll(320)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_box = SmaKit.vbox(3)
	scroll.add_child(_list_box)
	root.add_child(scroll)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	if key.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_DOWN and not _items.is_empty():
		_selected_idx = (_selected_idx + 1) % _items.size()
		_highlight_selected()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_UP and not _items.is_empty():
		_selected_idx = (_selected_idx - 1 + _items.size()) % _items.size()
		_highlight_selected()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		if not _items.is_empty():
			_activate_selected()
			get_viewport().set_input_as_handled()


func _refresh_results(raw_query: String) -> void:
	SmaKit.clear_children(_list_box)
	_items.clear()
	_row_buttons.clear()
	var q := raw_query.strip_edges().to_lower()

	# 1. Quick Actions
	var actions := [
		{"id": "flash_trainer", "title": I18n.t("palette.actFlash"), "tag": I18n.t("palette.tagAction"), "keywords": "flash kline drill 盲打 训练"},
		{"id": "office_shop", "title": I18n.t("palette.actOffice"), "tag": I18n.t("palette.tagAction"), "keywords": "office shop 装修 办公室 家具"},
		{"id": "step_day", "title": I18n.t("palette.actStepDay"), "tag": I18n.t("palette.tagAction"), "keywords": "next day 推进 一天"},
		{"id": "toggle_pause", "title": I18n.t("palette.actPause"), "tag": I18n.t("palette.tagAction"), "keywords": "pause play 暂停 继续"},
		{"id": "save", "title": I18n.t("palette.actSave"), "tag": I18n.t("palette.tagAction"), "keywords": "save 保存 存档"},
	]
	for act in actions:
		var hay := ("%s %s" % [String(act["title"]), String(act["keywords"])]).to_lower()
		if q == "" or hay.contains(q):
			_items.append({
				"kind": "action", "id": String(act["id"]),
				"title": String(act["title"]), "right": String(act["tag"]), "score": 80,
			})

	# 2. Navigation Screens
	for nav in _nav_items:
		var sid := String(nav[0])
		var lbl := I18n.t(String(nav[1]))
		var hay := ("%s %s" % [sid, lbl]).to_lower()
		if q != "" and not hay.contains(q):
			continue
		if q == "" and sid not in ["dashboard", "trade", "portfolio", "quant", "flash_trainer", "earnings", "fund", "career"]:
			continue
		_items.append({
			"kind": "screen", "id": sid, "title": lbl,
			"right": I18n.t("palette.tagScreen"), "score": 90 if sid.begins_with(q) else 70,
		})

	# 3. Stocks & ETFs (all 108 tickers)
	if game != null and game.started and game.exchange != null:
		var companies: Dictionary = game.exchange.state.get("companies", {})
		var tk_list: Array[String] = []
		for tk in companies.keys():
			tk_list.append(String(tk))
		tk_list.sort()
		var added_stocks := 0
		for tk in tk_list:
			var comp: Dictionary = companies[tk]
			var meta: Dictionary = comp.get("company", {})
			if meta.is_empty():
				meta = SmaCompanyCatalog.get_company(tk)
			var cname := String(meta.get("name", comp.get("name", tk)))
			var sec_id := String(meta.get("sector", comp.get("sector", "etf" if SmaEtfs.is_etf(tk) else "")))
			var sec_lbl := I18n.t("sector.%s" % sec_id) if I18n.has_key("sector.%s" % sec_id) else sec_id
			var hay := ("%s %s %s %s" % [tk, cname, sec_id, sec_lbl]).to_lower()
			if q != "" and not hay.contains(q):
				continue
			if q == "" and added_stocks >= 8:
				continue
			var last := float(comp.get("last", 0.0))
			var prev := float(comp.get("prevClose", last))
			var chg := ((last - prev) / maxf(0.01, prev)) * 100.0
			var score := 120 if tk.to_lower() == q else (105 if tk.to_lower().begins_with(q) else 65)
			_items.append({
				"kind": "ticker", "id": tk,
				"title": "%s · %s (%s)" % [tk, cname, sec_lbl],
				"right": "%s  %s" % [SmaFormat.money(last), SmaFormat.pct(chg, 2)],
				"chg": chg,
				"score": score,
			})
			added_stocks += 1

	_items.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
	if _items.size() > 24:
		_items = _items.slice(0, 24)
	if _items.is_empty():
		_list_box.add_child(SmaKit.muted(I18n.t("palette.empty"), 12))
		return

	_selected_idx = clampi(_selected_idx, 0, _items.size() - 1)
	for i in _items.size():
		var item: Dictionary = _items[i]
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size.y = 32
		btn.text = "%s    [%s]" % [String(item["title"]), String(item["right"])]
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var idx := i
		btn.pressed.connect(func():
			_selected_idx = idx
			_activate_selected())
		_list_box.add_child(btn)
		_row_buttons.append(btn)
	_highlight_selected()


func _highlight_selected() -> void:
	var sel_bg := Color(SmaUiTheme.ACCENT.r, SmaUiTheme.ACCENT.g, SmaUiTheme.ACCENT.b, 0.24)
	for i in _row_buttons.size():
		var btn := _row_buttons[i]
		if i == _selected_idx:
			btn.add_theme_stylebox_override("normal",
				SmaUiTheme.panel_style(sel_bg, SmaUiTheme.GOLD, 6, false))
		else:
			btn.add_theme_stylebox_override("normal",
				SmaUiTheme.panel_style(SmaUiTheme.PANEL_ALT, SmaUiTheme.BORDER, 6, false))


func _activate_selected() -> void:
	if _selected_idx < 0 or _selected_idx >= _items.size():
		return
	var item: Dictionary = _items[_selected_idx]
	var kind := String(item.get("kind", ""))
	var target_id := String(item.get("id", ""))
	_close()
	if kind == "ticker":
		ticker_selected.emit(target_id)
	elif kind == "screen":
		screen_selected.emit(target_id)
	elif kind == "action":
		action_selected.emit(target_id)


func _close() -> void:
	closed.emit()
	queue_free()
