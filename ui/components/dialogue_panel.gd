## Modal dialogue overlay. The panel is presentation only: it renders whatever
## SmaStoryService exposes and forwards advance/choose calls.
class_name SmaDialoguePanel
extends Control

var game: Node
var _panel: PanelContainer
var _title: Label
var _speaker: Label
var _text: Label
var _choices: VBoxContainer
var _hint: Label
var _continue: Button
var _portrait: TextureRect
var _portrait_frame: PanelContainer


func setup(game_ref: Node) -> void:
	game = game_ref
	_build()
	refresh()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	visible = false

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.07, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(820, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = SmaUiTheme.PANEL
	style.border_color = SmaUiTheme.ACCENT_DARK
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(22)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 18
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var root := SmaKit.vbox(14)
	_panel.add_child(root)
	var head := SmaKit.hbox(10)
	_title = SmaKit.label("", 12, SmaUiTheme.DIM)
	_speaker = SmaKit.label("", 16, SmaUiTheme.ACCENT)
	head.add_child(_title)
	head.add_child(SmaKit.hspacer())
	head.add_child(_speaker)
	root.add_child(head)
	root.add_child(SmaKit.separator())

	var body := SmaKit.hbox(16)
	root.add_child(body)
	_portrait_frame = PanelContainer.new()
	_portrait_frame.custom_minimum_size = Vector2(168, 224)
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.visible = false
	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color = Color(0.05, 0.08, 0.12, 1.0)
	portrait_style.set_border_width_all(2)
	portrait_style.set_corner_radius_all(10)
	portrait_style.set_content_margin_all(2)
	_portrait_frame.add_theme_stylebox_override("panel", portrait_style)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(164, 220)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.add_child(_portrait)
	body.add_child(_portrait_frame)
	_text = SmaKit.label("", 15)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.y = 96
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


func refresh() -> void:
	if game == null or not game.started or game.narrative == null:
		visible = false
		return
	if not game.narrative.is_active():
		visible = false
		return
	var view: Dictionary = game.narrative.current_view()
	visible = true
	_title.text = String(view.get("title", ""))
	_speaker.text = String(view.get("speaker", ""))
	_text.text = String(view.get("text", ""))
	var accent := SmaUiTheme.ACCENT
	var color_text := String(view.get("portraitColor", ""))
	if color_text != "" and Color.html_is_valid(color_text):
		accent = Color.html(color_text)
	_speaker.add_theme_color_override("font_color", accent)
	var portrait_path := String(view.get("portrait", ""))
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		var texture := load(portrait_path) as Texture2D
		if texture != null:
			_portrait.texture = texture
			_portrait_frame.visible = true
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
		for choice in view.get("choices", []):
			var button := SmaKit.button(String(choice["text"]), _choose.bind(int(choice["index"])))
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.focus_mode = Control.FOCUS_ALL
			button.custom_minimum_size.y = 38
			_choices.add_child(button)
		if _choices.get_child_count() == 0:
			_choices.visible = false
			_continue.visible = true
		else:
			var first_choice: Button = _choices.get_child(0)
			first_choice.grab_focus.call_deferred()
	_hint.text = I18n.t("story.choiceKeys") if _choices.visible else "Enter / Space"


func _advance() -> void:
	if game == null or game.narrative == null:
		return
	game.narrative.advance()
	refresh()


func _choose(index: int) -> void:
	if game == null or game.narrative == null:
		return
	game.narrative.choose(index)
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			if _continue.visible:
				_advance()
				get_viewport().set_input_as_handled()
