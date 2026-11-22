## Price alert modal for one ticker. Directions and targets are validated by
## Game; this dialog only collects input and renders the alert list.
class_name SmaPriceAlertDialog
extends Control

signal closed

var game: Node
var _ticker := ""
var _side_option: OptionButton
var _price_spin: SpinBox
var _list: VBoxContainer
var _feedback: Label
var _subtitle: Label


func setup(game_ref: Node, ticker: String) -> void:
	game = game_ref
	_ticker = ticker.strip_edges().to_upper()
	_build()
	_refresh_list()
	if game != null and game.has_signal("state_changed"):
		game.connect("state_changed", Callable(self, "_on_game_state_changed"))


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 57
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.07, 0.82)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := SmaKit.card(20)
	panel.custom_minimum_size = Vector2(640, 420)
	center.add_child(panel)
	var root := SmaKit.vbox(10)
	panel.add_child(root)
	var header := SmaKit.hbox(10)
	header.add_child(SmaKit.label(I18n.t("alerts.title"), 20))
	_subtitle = SmaKit.muted(I18n.t("alerts.subtitle", {
		"ticker": _ticker, "price": SmaFormat.money(_current_price())}), 12)
	header.add_child(_subtitle)
	header.add_child(SmaKit.hspacer())
	header.add_child(SmaKit.button(I18n.t("common.close"), _close))
	root.add_child(header)
	var form := SmaKit.hbox(8)
	form.add_child(SmaKit.caption(I18n.t("alerts.direction")))
	_side_option = OptionButton.new()
	_side_option.add_item(I18n.t("alerts.above"))
	_side_option.set_item_metadata(0, "above")
	_side_option.add_item(I18n.t("alerts.below"))
	_side_option.set_item_metadata(1, "below")
	form.add_child(_side_option)
	form.add_child(SmaKit.caption(I18n.t("alerts.targetPrice")))
	_price_spin = SpinBox.new()
	_price_spin.min_value = 0.01
	_price_spin.max_value = 1000000.0
	_price_spin.step = 0.01
	_price_spin.value = maxf(0.01, _current_price())
	_price_spin.custom_minimum_size.x = 150
	form.add_child(_price_spin)
	form.add_child(SmaKit.button(I18n.t("alerts.add"), _add_alert, true))
	form.add_child(SmaKit.hspacer())
	root.add_child(form)
	_feedback = SmaKit.muted("", 11)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_feedback)
	var scroll := SmaKit.scroll(280)
	_list = SmaKit.vbox(6)
	scroll.add_child(_list)
	root.add_child(scroll)


func _on_game_state_changed(reason: String) -> void:
	if reason != "alerts":
		return
	if _subtitle != null:
		_subtitle.text = I18n.t("alerts.subtitle", {
			"ticker": _ticker, "price": SmaFormat.money(_current_price())})
	_refresh_list()


func _refresh_list() -> void:
	if _list == null:
		return
	SmaKit.clear_children(_list)
	var count := 0
	if game != null:
		for alert in game.price_alerts():
			if String(alert.get("ticker", "")) != _ticker:
				continue
			count += 1
			_list.add_child(_alert_row(alert))
	if count == 0:
		_list.add_child(SmaKit.muted(I18n.t("alerts.empty"), 12))


func _alert_row(alert: Dictionary) -> Control:
	var row := SmaKit.hbox(8)
	var active := bool(alert.get("active", false))
	var direction := I18n.t("alerts.%s" % String(alert.get("side", "above")))
	row.add_child(SmaKit.label("%s %s" % [direction,
		SmaFormat.money(float(alert.get("price", 0.0)))], 13))
	row.add_child(SmaKit.hspacer())
	row.add_child(SmaKit.label(I18n.t("alerts.active" if active else "alerts.triggered"),
		11, SmaUiTheme.POSITIVE if active else SmaUiTheme.DIM))
	row.add_child(SmaKit.muted(I18n.t("alerts.createdDay", {
		"day": int(alert.get("createdDay", 0))}), 10))
	row.add_child(SmaKit.button(I18n.t("alerts.delete"),
		_remove_alert.bind(String(alert.get("id", "")))))
	return row


func _add_alert() -> void:
	if game == null or _side_option == null or _price_spin == null:
		return
	var side := String(_side_option.get_item_metadata(_side_option.selected))
	var result: Dictionary = game.add_price_alert(_ticker, side, _price_spin.value)
	if not bool(result.get("ok", false)):
		_feedback.text = I18n.t(String(result.get("error", "alerts.invalidPrice")))
		return
	var alert: Dictionary = result.get("alert", {})
	_feedback.text = I18n.t("alerts.added", {
		"direction": I18n.t("alerts.%s" % String(alert.get("side", side))),
		"price": SmaFormat.money(float(alert.get("price", _price_spin.value))),
	})
	_refresh_list()


func _remove_alert(alert_id: String) -> void:
	if game == null or alert_id == "":
		return
	if game.remove_price_alert(alert_id):
		_feedback.text = I18n.t("alerts.removed")
		_refresh_list()


func _current_price() -> float:
	if game == null or game.exchange == null:
		return 0.0
	return float(game.exchange.quote(_ticker).get("last", 0.0))


func _close() -> void:
	closed.emit()
	queue_free()
