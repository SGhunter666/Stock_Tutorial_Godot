## Base class for feature screens. Main owns navigation and calls refresh/on_tick
## so screens never subscribe to global signals themselves.
class_name SmaScreen
extends Control

var game: Node
var built := false


func setup(game_ref: Node) -> void:
	game = game_ref
	if built:
		refresh("setup")
		return
	_build()
	built = true
	refresh()


func _build() -> void:
	pass


func refresh(_reason: String = "") -> void:
	pass


func on_tick() -> void:
	pass


## Optional transient form state for a language-driven rebuild of the screen.
func capture_draft() -> Dictionary:
	return {}


func restore_draft(_draft: Dictionary) -> void:
	pass
