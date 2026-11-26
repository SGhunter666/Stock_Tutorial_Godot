## Modal dialogue overlay. The panel is presentation only: it renders whatever
## SmaStoryService exposes and forwards advance/choose calls.
class_name SmaDialoguePanel
extends Control

var game: Node
var _dim: ColorRect
var _panel: PanelContainer
var _mood_bar: ColorRect
var _title: Label
var _speaker: Label
var _text: Label
var _choices: VBoxContainer
var _hint: Label
var _continue: Button
var _backlog_btn: Button
var _backlog_panel: PanelContainer
var _backlog_box: VBoxContainer
var _portrait: TextureRect
var _portrait_anim: SmaPortraitAnimator
var _portrait_frame: PanelContainer
var _scene_story_id := ""
var _scene_log: Array[Dictionary] = []
var _last_node_id := ""
var _type_tween: Tween


func setup(game_ref: Node) -> void:
	game = game_ref
	_build()
	refresh()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	visible = false

	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.04, 0.07, 0.78)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(900 if SmaUiTheme.is_pixel() else 820, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel",
		SmaUiTheme.panel_style(SmaUiTheme.PANEL, SmaUiTheme.ACCENT, 20, true))
	center.add_child(_panel)

	var root := SmaKit.vbox(12)
	_panel.add_child(root)
	_mood_bar = ColorRect.new()
	_mood_bar.custom_minimum_size.y = 4 if SmaUiTheme.is_pixel() else 3
	_mood_bar.color = SmaUiTheme.ACCENT_DARK
	root.add_child(_mood_bar)
	var head := SmaKit.hbox(10)
	_title = SmaKit.label("", 12, SmaUiTheme.GOLD if SmaUiTheme.is_pixel() else SmaUiTheme.DIM)
	var speaker_pill := PanelContainer.new()
	speaker_pill.add_theme_stylebox_override("panel", SmaUiTheme.readout_style(10, 4, SmaUiTheme.ACCENT))
	_speaker = SmaKit.label("", 22 if SmaUiTheme.is_pixel() else 16, SmaUiTheme.ACCENT)
	speaker_pill.add_child(_speaker)
	head.add_child(_title)
	head.add_child(SmaKit.hspacer())
	head.add_child(speaker_pill)
	_backlog_btn = SmaKit.toggle(I18n.t("story.backlog"))
	_backlog_btn.toggled.connect(func(on: bool):
		if _backlog_panel != null:
			_backlog_panel.visible = on
			if on:
				_render_backlog())
	head.add_child(_backlog_btn)
	root.add_child(head)
	root.add_child(SmaKit.separator())

	_backlog_panel = SmaKit.card(10)
	_backlog_panel.visible = false
	var backlog_scroll := SmaKit.scroll(150)
	_backlog_box = SmaKit.vbox(4)
	backlog_scroll.add_child(_backlog_box)
	_backlog_panel.add_child(backlog_scroll)
	root.add_child(_backlog_panel)

	var body := SmaKit.hbox(18)
	root.add_child(body)
	_portrait_frame = PanelContainer.new()
	var pw := 192 if SmaUiTheme.is_pixel() else 164
	var ph := 256 if SmaUiTheme.is_pixel() else 220
	_portrait_frame.custom_minimum_size = Vector2(pw + 8, ph + 8)
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.visible = false
	if SmaUiTheme.is_pixel():
		_portrait_frame.add_theme_stylebox_override("panel",
			SmaPixelArt.card_box(Color("#08111f"), SmaUiTheme.ACCENT, Color("#040811"), 4, false))
	else:
		var portrait_style := StyleBoxFlat.new()
		portrait_style.bg_color = Color(0.04, 0.08, 0.13, 1.0)
		portrait_style.set_border_width_all(2)
		portrait_style.set_corner_radius_all(10)
		portrait_style.set_content_margin_all(2)
		_portrait_frame.add_theme_stylebox_override("panel", portrait_style)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(pw, ph)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if SmaUiTheme.is_pixel() \
		else CanvasItem.TEXTURE_FILTER_LINEAR
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_anim = SmaPortraitAnimator.new()
	_portrait_anim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait.add_child(_portrait_anim)
	_portrait_frame.add_child(_portrait)
	body.add_child(_portrait_frame)
	_text = SmaKit.label("", 22 if SmaUiTheme.is_pixel() else 15)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.y = 112
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_text)

	_choices = SmaKit.vbox(8)
	root.add_child(_choices)

	var footer := SmaKit.hbox(8)
	_hint = SmaKit.caption("")
	footer.add_child(_hint)
	footer.add_child(SmaKit.hspacer())
	_continue = SmaKit.button(I18n.t("story.continue"), _advance, true)
	_continue.custom_minimum_size.x = 140
	footer.add_child(_continue)
	root.add_child(footer)


func _apply_mood(story_id: String) -> void:
	var dim_color := Color(0.02, 0.04, 0.07, 0.78)
	var bar_color := SmaUiTheme.ACCENT_DARK
	if story_id in ["black_friday", "crisis_eve", "leverage_night", "macro_shock"]:
		dim_color = Color(0.11, 0.03, 0.04, 0.84)
		bar_color = SmaUiTheme.NEGATIVE
	elif story_id in ["opening", "graduation", "graduation_unfunded", "epilogue"]:
		dim_color = Color(0.04, 0.06, 0.11, 0.82)
		bar_color = SmaUiTheme.ACCENT
	elif story_id in ["research", "options_expiry", "short_mirror"]:
		dim_color = Color(0.03, 0.05, 0.11, 0.82)
		bar_color = SmaUiTheme.INFO
	if _dim != null:
		_dim.color = dim_color
	if _mood_bar != null:
		_mood_bar.color = bar_color


func _render_backlog() -> void:
	if _backlog_box == null:
		return
	SmaKit.clear_children(_backlog_box)
	if _scene_log.is_empty():
		_backlog_box.add_child(SmaKit.muted(I18n.t("story.backlogEmpty"), 11))
		return
	for entry in _scene_log:
		var line := SmaKit.label("%s: %s" % [
			String(entry.get("speaker", "")), String(entry.get("text", ""))],
			11, SmaUiTheme.MUTED)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_backlog_box.add_child(line)


func refresh() -> void:
	if game == null or not game.started or game.narrative == null:
		visible = false
		return
	if not game.narrative.is_active():
		visible = false
		_scene_story_id = ""
		_last_node_id = ""
		_scene_log.clear()
		if _backlog_panel != null:
			_backlog_panel.visible = false
		if _backlog_btn != null:
			_backlog_btn.set_pressed_no_signal(false)
		return
	var view: Dictionary = game.narrative.current_view()
	visible = true
	var story_id := String(view.get("story_id", ""))
	var node_id := String(view.get("node_id", ""))
	if story_id != _scene_story_id:
		_scene_story_id = story_id
		_last_node_id = ""
		_scene_log.clear()
		if _backlog_panel != null:
			_backlog_panel.visible = false
		if _backlog_btn != null:
			_backlog_btn.set_pressed_no_signal(false)
	_apply_mood(story_id)
	var title_text := String(view.get("title", ""))
	if bool(view.get("replay", false)):
		title_text = "%s · %s" % [title_text, I18n.t("story.replayBadge")]
	_title.text = title_text
	var speaker_text := String(view.get("speaker", ""))
	var body_text := String(view.get("text", ""))
	_speaker.text = speaker_text
	_text.text = body_text
	if node_id != "" and node_id != _last_node_id:
		_last_node_id = node_id
		_scene_log.append({"speaker": speaker_text, "text": body_text})
		if _scene_log.size() > 24:
			_scene_log = _scene_log.slice(_scene_log.size() - 24)
		if _backlog_panel != null and _backlog_panel.visible:
			_render_backlog()
		_start_typewriter(body_text)
	else:
		_finish_typewriter()
	var accent := SmaUiTheme.ACCENT
	var color_text := String(view.get("portraitColor", ""))
	if color_text != "" and Color.html_is_valid(color_text):
		accent = Color.html(color_text)
	_speaker.add_theme_color_override("font_color", accent)
	var portrait_path := String(view.get("portrait", ""))
	var char_id := String(view.get("character", ""))
	if portrait_path != "" and SmaUiTheme.is_pixel():
		var px_path := "res://assets/portraits/pixel/%s.png" % char_id
		if char_id != "" and ResourceLoader.exists(px_path):
			portrait_path = px_path
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if SmaUiTheme.is_pixel() \
		else CanvasItem.TEXTURE_FILTER_LINEAR
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		var texture := load(portrait_path) as Texture2D
		if texture != null:
			_portrait.texture = texture
			_portrait_frame.visible = true
			if _portrait_anim != null:
				_portrait_anim.configure(char_id, texture,
					SmaPortraitAnimator.resolve_mood(story_id, body_text))
				_portrait_anim.set_talking(_is_typing())
			if SmaUiTheme.is_pixel():
				_portrait_frame.add_theme_stylebox_override("panel",
					SmaPixelArt.card_box(Color("#08111f"), accent, Color("#040811"), 4, false))
			else:
				var portrait_style := _portrait_frame.get_theme_stylebox("panel") as StyleBoxFlat
				if portrait_style != null:
					portrait_style.border_color = accent
		else:
			_portrait_frame.visible = false
	else:
		_portrait_frame.visible = false
	SmaKit.clear_children(_choices)
	var node_type := String(view.get("type", "line"))
	var has_choices := node_type == "choice"
	_choices.visible = has_choices
	_continue.visible = not has_choices
	if has_choices:
		var visible_choices: Array = view.get("choices", [])
		for pos in visible_choices.size():
			var choice: Dictionary = visible_choices[pos]
			var label_text := "%d. %s" % [pos + 1, String(choice["text"])]
			var button := SmaKit.button(label_text, _choose.bind(int(choice["index"])))
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.focus_mode = Control.FOCUS_ALL
			button.custom_minimum_size.y = 38
			button.set_meta("choice_index", int(choice["index"]))
			_choices.add_child(button)
		if _choices.get_child_count() == 0:
			_choices.visible = false
			_continue.visible = true
		else:
			var first_choice: Button = _choices.get_child(0)
			_focus_choice.call_deferred(first_choice)
	_hint.text = I18n.t("story.choiceKeys") if _choices.visible else "Enter / Space"


func _start_typewriter(body_text: String) -> void:
	_finish_typewriter()
	if DisplayServer.get_name() == "headless" \
			or bool(game.settings.get("reducedMotion", false)) \
			or body_text.length() < 8:
		_text.visible_characters = -1
		if _portrait_anim != null:
			_portrait_anim.set_talking(false)
		return
	_text.visible_characters = 0
	if _portrait_anim != null:
		_portrait_anim.set_talking(true)
	var duration := clampf(float(body_text.length()) * 0.012, 0.25, 1.35)
	_type_tween = create_tween()
	_type_tween.tween_property(_text, "visible_characters", body_text.length(), duration)
	_type_tween.tween_callback(func():
		_text.visible_characters = -1
		if _portrait_anim != null:
			_portrait_anim.set_talking(false))


func _finish_typewriter() -> void:
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	_type_tween = null
	if _text != null:
		_text.visible_characters = -1
	if _portrait_anim != null:
		_portrait_anim.set_talking(false)


func _is_typing() -> bool:
	return _type_tween != null and _type_tween.is_valid() and _type_tween.is_running()


func _focus_choice(button: Variant) -> void:
	if button != null and is_instance_valid(button):
		var b := button as Button
		if b != null and b.is_inside_tree() and b.is_visible_in_tree():
			b.grab_focus()


func _advance() -> void:
	if _is_typing():
		_finish_typewriter()
		return
	if game == null or game.narrative == null:
		return
	game.narrative.advance()
	refresh()


func _choose(index: int) -> void:
	_finish_typewriter()
	if game == null or game.narrative == null:
		return
	game.narrative.choose(index)
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if _choices.visible:
			var number_keys := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
			var idx := number_keys.find(event.keycode)
			if idx >= 0 and idx < _choices.get_child_count():
				var btn := _choices.get_child(idx) as Button
				if btn != null and btn.has_meta("choice_index"):
					_choose(int(btn.get_meta("choice_index")))
					get_viewport().set_input_as_handled()
					return
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			if _continue.visible:
				_advance()
				get_viewport().set_input_as_handled()
