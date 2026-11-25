## Story archive: current chapter, spoiler-safe chapter replay, character
## gallery, readable key decisions and event history.
class_name SmaStoryScreen
extends SmaScreen

const CHAPTER_ORDER := [
	"opening", "first_trade", "day_one", "dividend", "diversify", "research",
	"macro_shock", "short_mirror", "leverage_night", "options_expiry",
	"client_trust", "crisis_eve", "black_friday", "graduation",
	"graduation_unfunded", "epilogue",
]
const CHARACTER_ORDER := ["lin_lan", "gu_yan", "su_he", "zhou_heng", "chen_xi", "wang", "lao_chen"]
const DECISION_FLAGS := [
	"path", "discipline", "mission_day1", "income_style", "diversify",
	"research", "risk_response", "ethics", "leverage", "option_style",
	"client_trust", "hedge", "crisis_choice", "ending_path",
]

var _active_box: VBoxContainer
var _objective_box: VBoxContainer
var _catalog_box: VBoxContainer
var _flags_box: VBoxContainer
var _characters_box: VBoxContainer
var _notes_box: VBoxContainer
var _report_box: VBoxContainer
var _history_box: VBoxContainer


func _build() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := SmaKit.scroll()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var root := SmaKit.vbox(12)
	scroll.add_child(root)

	var heading := SmaKit.vbox(2)
	heading.add_child(SmaKit.title(I18n.t("story.title"), 22))
	heading.add_child(SmaKit.muted(I18n.t("story.subtitle")))
	heading.add_child(SmaKit.caption(I18n.t("story.event_hint")))
	root.add_child(heading)

	var active_card := SmaKit.card(14)
	_active_box = SmaKit.vbox(8)
	active_card.add_child(_active_box)
	root.add_child(active_card)

	var objective_card := SmaKit.card(12)
	_objective_box = SmaKit.vbox(6)
	objective_card.add_child(_objective_box)
	root.add_child(objective_card)

	var columns := SmaKit.hbox(12)
	root.add_child(columns)

	var catalog_card := SmaKit.card(12)
	var catalog := SmaKit.vbox(8)
	catalog_card.add_child(catalog)
	catalog.add_child(SmaKit.label(I18n.t("story.chapters"), 14))
	var catalog_scroll := SmaKit.scroll(260)
	_catalog_box = SmaKit.vbox(6)
	catalog_scroll.add_child(_catalog_box)
	catalog.add_child(catalog_scroll)
	columns.add_child(catalog_card)

	var flags_card := SmaKit.card(12)
	var flags := SmaKit.vbox(8)
	flags_card.add_child(flags)
	flags.add_child(SmaKit.label(I18n.t("story.decisions"), 14))
	var flags_scroll := SmaKit.scroll(260)
	_flags_box = SmaKit.vbox(5)
	flags_scroll.add_child(_flags_box)
	flags.add_child(flags_scroll)
	columns.add_child(flags_card)

	var history_card := SmaKit.card(12)
	var history := SmaKit.vbox(8)
	history_card.add_child(history)
	history.add_child(SmaKit.label(I18n.t("story.history"), 14))
	var history_scroll := SmaKit.scroll(260)
	_history_box = SmaKit.vbox(4)
	history_scroll.add_child(_history_box)
	history.add_child(history_scroll)
	columns.add_child(history_card)

	var char_card := SmaKit.card(12)
	var char_wrap := SmaKit.vbox(8)
	char_card.add_child(char_wrap)
	char_wrap.add_child(SmaKit.label(I18n.t("story.charactersTitle"), 14))
	char_wrap.add_child(SmaKit.muted(I18n.t("story.charactersSubtitle"), 11))
	_characters_box = SmaKit.vbox(8)
	char_wrap.add_child(_characters_box)
	root.add_child(char_card)

	var notes_card := SmaKit.card(12)
	var notes_wrap := SmaKit.vbox(6)
	notes_card.add_child(notes_wrap)
	notes_wrap.add_child(SmaKit.label(I18n.t("story.notesTitle"), 14))
	notes_wrap.add_child(SmaKit.muted(I18n.t("story.notesSubtitle"), 11))
	_notes_box = SmaKit.vbox(5)
	notes_wrap.add_child(_notes_box)
	root.add_child(notes_card)

	var report_card := SmaKit.card(12)
	var report_wrap := SmaKit.vbox(8)
	report_card.add_child(report_wrap)
	report_wrap.add_child(SmaKit.label(I18n.t("story.reportTitle"), 14))
	report_wrap.add_child(SmaKit.muted(I18n.t("story.reportSubtitle"), 11))
	_report_box = SmaKit.vbox(6)
	report_wrap.add_child(_report_box)
	root.add_child(report_card)


func refresh(_reason: String = "") -> void:
	if game == null or not game.started or game.narrative == null:
		return
	_update_active()
	_update_objective()
	_update_catalog()
	_update_flags()
	_update_history()
	_update_characters()
	_update_notes()
	_update_report_card()


func _update_objective() -> void:
	SmaKit.clear_children(_objective_box)
	var obj: Dictionary = game.current_objective()
	var head := SmaKit.hbox(8)
	head.add_child(SmaKit.label(I18n.t(String(obj.get("actKey", "objective.act1"))),
		11, SmaUiTheme.ACCENT))
	head.add_child(SmaKit.label(String(obj.get("title", "")), 14))
	head.add_child(SmaKit.hspacer())
	var target := String(obj.get("target", "academy"))
	var jump := SmaKit.button(String(obj.get("button", "")), func():
		var main := get_tree().get_first_node_in_group("main") as SmaMain
		if main != null:
			main.navigate(target), true)
	head.add_child(jump)
	_objective_box.add_child(head)
	var detail := SmaKit.muted(String(obj.get("detail", "")), 12)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_box.add_child(detail)


func _update_notes() -> void:
	SmaKit.clear_children(_notes_box)
	var notes: Array = game.side_comments()
	if notes.is_empty():
		_notes_box.add_child(SmaKit.muted(I18n.t("story.noNotes")))
		return
	for index in range(notes.size() - 1, -1, -1):
		var item: Dictionary = notes[index]
		var line := SmaKit.label("[%s] %s: %s" % [
			SmaCalendar.iso_date(int(item.get("day", 0))),
			I18n.t(String(item.get("speakerKey", ""))),
			I18n.t(String(item.get("textKey", ""))),
		], 12, SmaUiTheme.MUTED)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_notes_box.add_child(line)


func _update_report_card() -> void:
	SmaKit.clear_children(_report_box)
	var r: Dictionary = game.graduation_report()
	var status_text := I18n.t("story.reportGraduated" if bool(r["graduated"]) else "story.reportInProgress", {
		"name": String(r["playerName"]),
		"rank": I18n.t(String(r["careerRankKey"])),
		"day": int(r["day"]) + 1,
	})
	_report_box.add_child(SmaKit.label(status_text, 13,
		SmaUiTheme.POSITIVE if bool(r["graduated"]) else SmaUiTheme.ACCENT))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	for metric in [
		["story.report.equity", SmaFormat.money(float(r["equity"])),
			SmaFormat.pct(float(r["netReturnPct"]))],
		["story.report.drawdown", SmaFormat.pct_plain(float(r["maxDrawdownPct"]), 1),
			I18n.t("story.report.winRate", {"pct": SmaFormat.pct_plain(float(r["winRatePct"]), 1)})],
		["story.report.academy", "%d / %d" % [int(r["unitsDone"]), int(r["unitsTotal"])],
			I18n.t("story.report.branches", {"count": int(r["branchesDone"])})],
		["story.report.honors", "%d / %d" % [int(r["achievementsCount"]), int(r["achievementsTotal"])],
			I18n.t("story.report.certs", {"count": int(r["certificatesCount"])})],
	]:
		var cell := SmaKit.vbox(2)
		cell.add_child(SmaKit.caption(I18n.t(String(metric[0]))))
		cell.add_child(SmaKit.label(String(metric[1]), 14))
		cell.add_child(SmaKit.muted(String(metric[2]), 10))
		grid.add_child(cell)
	_report_box.add_child(grid)
	var export_row := SmaKit.hbox(8)
	var export_path := "user://saves/farview_report_slot_%d.json" % int(game.active_slot)
	export_row.add_child(SmaKit.button(I18n.t("story.exportReport"), func():
		game.export_graduation_report(export_path), true))
	export_row.add_child(SmaKit.caption(export_path))
	_report_box.add_child(export_row)


func on_tick() -> void:
	pass


func _update_active() -> void:
	SmaKit.clear_children(_active_box)
	if game.narrative.is_active():
		var view: Dictionary = game.narrative.current_view()
		var head := SmaKit.hbox(10)
		head.add_child(SmaKit.label(I18n.t("story.active"), 13, SmaUiTheme.ACCENT))
		head.add_child(SmaKit.label(String(view.get("title", "")), 15))
		head.add_child(SmaKit.hspacer())
		var open := SmaKit.button(I18n.t("story.continue"), func(): _advance(), true)
		head.add_child(open)
		_active_box.add_child(head)
		_active_box.add_child(SmaKit.muted(String(view.get("speaker", ""))))
		var text := SmaKit.label(String(view.get("text", "")), 13)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_active_box.add_child(text)
	else:
		_active_box.add_child(SmaKit.label(I18n.t("story.none"), 13, SmaUiTheme.MUTED))
		var seen_count: int = game.narrative.seen.size()
		_active_box.add_child(SmaKit.caption(I18n.t("story.progressCount", {
			"seen": seen_count, "total": game.narrative.stories.size()})))
		var replay := SmaKit.button(I18n.t("story.replay"), _replay, true)
		replay.custom_minimum_size.x = 160
		replay.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		replay.disabled = not bool(game.narrative.seen.get("opening", false))
		_active_box.add_child(replay)


func _update_catalog() -> void:
	SmaKit.clear_children(_catalog_box)
	var ordered: Array = []
	for story_id in CHAPTER_ORDER:
		if game.narrative.stories.has(story_id):
			ordered.append(story_id)
	for story_id in game.narrative.stories.keys():
		if not ordered.has(story_id):
			ordered.append(story_id)
	for index in ordered.size():
		var story_id := String(ordered[index])
		var story: Dictionary = game.narrative.stories[story_id]
		var seen := bool(game.narrative.seen.get(story_id, false))
		var row := SmaKit.hbox(8)
		var title := I18n.t("story.lockedChapter", {"num": index + 1})
		if seen and story.has("title"):
			title = "%02d · %s" % [index + 1, game.localize(story["title"])]
		row.add_child(SmaKit.cell(title, 1.6, HORIZONTAL_ALIGNMENT_LEFT,
			SmaUiTheme.TEXT if seen else SmaUiTheme.DIM))
		row.add_child(SmaKit.cell(I18n.t("story.seen") if seen else I18n.t("story.locked"), 0.55,
			HORIZONTAL_ALIGNMENT_RIGHT, SmaUiTheme.POSITIVE if seen else SmaUiTheme.DIM, 10))
		var open := SmaKit.button(I18n.t("story.replayShort") if seen else I18n.t("story.locked"),
			_start_replay.bind(story_id))
		open.disabled = not seen
		SmaKit.set_small_font(open, 10)
		open.custom_minimum_size.x = 58
		row.add_child(open)
		_catalog_box.add_child(row)


func _update_flags() -> void:
	SmaKit.clear_children(_flags_box)
	var flags: Dictionary = game.narrative.flags
	var shown := 0
	for key in DECISION_FLAGS:
		if not flags.has(key):
			continue
		shown += 1
		var raw_val := str(flags[key])
		var label_key := "story.decision.%s" % key
		var val_key := "story.decision.%s.%s" % [key, raw_val]
		var label_text: String = I18n.t(label_key) if I18n.has_key(label_key) else key
		var val_text: String = I18n.t(val_key) if I18n.has_key(val_key) else raw_val
		_flags_box.add_child(SmaKit.data_row([label_text, val_text],
			[1.1, 1.1], [SmaUiTheme.MUTED, SmaUiTheme.ACCENT],
			[HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_RIGHT]))
	if shown == 0:
		_flags_box.add_child(SmaKit.muted(I18n.t("story.no_flags")))


func _update_characters() -> void:
	SmaKit.clear_children(_characters_box)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	for char_id in CHARACTER_ORDER:
		var info: Dictionary = game.narrative.characters.get(char_id, {})
		var item := PanelContainer.new()
		item.add_theme_stylebox_override("panel", SmaUiTheme.panel_style(SmaUiTheme.PANEL_ALT, SmaUiTheme.BORDER, 8, false))
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hbox := SmaKit.hbox(10)
		item.add_child(hbox)
		var portrait_path := String(info.get("portrait", ""))
		if SmaUiTheme.is_pixel():
			var px_path := String(info.get("pixelPortrait", "res://assets/portraits/pixel/%s.png" % char_id))
			if ResourceLoader.exists(px_path):
				portrait_path = px_path
		if portrait_path != "" and ResourceLoader.exists(portrait_path):
			var tex := load(portrait_path) as Texture2D
			if tex != null:
				var rect := TextureRect.new()
				rect.texture = tex
				rect.custom_minimum_size = Vector2(96, 128) if SmaUiTheme.is_pixel() else Vector2(48, 64)
				rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if SmaUiTheme.is_pixel() \
					else CanvasItem.TEXTURE_FILTER_LINEAR
				hbox.add_child(rect)
		var meta := SmaKit.vbox(2)
		var accent := SmaUiTheme.ACCENT
		var hex := String(info.get("color", ""))
		if hex != "" and Color.html_is_valid(hex):
			accent = Color.html(hex)
		meta.add_child(SmaKit.label(I18n.t("story.char.%s.name" % char_id), 13, accent))
		var role := SmaKit.caption(I18n.t("story.char.%s.role" % char_id))
		meta.add_child(role)
		var bio := SmaKit.muted(I18n.t("story.char.%s.bio" % char_id), 11)
		bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		meta.add_child(bio)
		hbox.add_child(meta)
		grid.add_child(item)
	_characters_box.add_child(grid)


func _update_history() -> void:
	SmaKit.clear_children(_history_box)
	var history: Array = game.narrative.history
	if history.is_empty():
		_history_box.add_child(SmaKit.muted(I18n.t("story.no_history")))
		return
	var start := maxi(0, history.size() - 16)
	for index in range(history.size() - 1, start - 1, -1):
		var entry: Dictionary = history[index]
		var story_id := String(entry.get("story", ""))
		var title := story_id
		if game.narrative.stories.has(story_id) and game.narrative.stories[story_id].has("title"):
			title = game.localize(game.narrative.stories[story_id]["title"])
		var kind := String(entry.get("kind", ""))
		var kind_key := "story.kind_%s" % kind
		var kind_label := I18n.t(kind_key) if I18n.has_key(kind_key) else kind
		_history_box.add_child(SmaKit.data_row([
			"T%s" % str(entry.get("day", 0)), title, kind_label,
		], [0.5, 1.8, 0.9], [SmaUiTheme.MUTED, SmaUiTheme.TEXT, SmaUiTheme.ACCENT],
			[HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_LEFT]))


func _advance() -> void:
	if game.narrative.is_active():
		game.narrative.advance()


func _start_replay(story_id: String) -> void:
	if not game.narrative.is_active():
		game.narrative.start_replay(story_id)


func _replay() -> void:
	_start_replay("opening")
