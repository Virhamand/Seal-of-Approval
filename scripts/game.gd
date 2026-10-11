extends Node2D
## Persistent root scene. Loads the level that belongs to the current
## GameState and shows temporary debug buttons for the legal next states.

@onready var level_root: Node2D = $Level

var level: Node = null
var level_path := ""
var _label: Label
var _buttons: HBoxContainer


func _ready() -> void:
	_build_debug_ui()
	GameState.state_changed.connect(_on_state_changed)
	_show_state(GameState.state)


func level_path_for(s: GameState.State) -> String:
	match s:
		GameState.State.RUNNING_RESTAURANT:
			return "res://scenes/temp_restaurant_scene.tscn"
		GameState.State.WALKING_ON_BEACH, GameState.State.TALKING_TO_SEAL:
			return "res://scenes/main.tscn"   # the beach
		GameState.State.SEAL_MINI_GAME:
			return "res://scenes/sea_repeat.tscn"
		GameState.State.UNLOCK_RECIPE:
			return "res://scenes/new_recipe.tscn"
	return ""


func _on_state_changed(_from: GameState.State, to: GameState.State) -> void:
	_show_state(to)


func _show_state(s: GameState.State) -> void:
	var path := level_path_for(s)
	# Walking <-> Talking share the beach, so keep it (and the chef's position).
	if path != level_path:
		if level:
			level_root.remove_child(level)
			level.queue_free()
		level = load(path).instantiate()
		level_root.add_child(level)
		level_path = path
	if level.has_method("enter_state"):
		level.enter_state(s)
	_refresh_debug_ui()


# ---------------------------------------------------------------- temporary debug UI
func _build_debug_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(4, 4)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 10)
	box.add_child(_label)
	_buttons = HBoxContainer.new()
	box.add_child(_buttons)


func _refresh_debug_ui() -> void:
	_label.text = "Day %d  |  %s" % [GameState.day, GameState.state_name(GameState.state)]
	for b in _buttons.get_children():
		b.queue_free()
	for next in GameState.allowed_next():
		var b := Button.new()
		b.text = GameState.state_name(next)
		if GameState.state == GameState.State.UNLOCK_RECIPE:
			b.text += " (new day)"
		b.add_theme_font_size_override("font_size", 10)
		b.focus_mode = Control.FOCUS_NONE   # so arrow keys / space never press it
		b.pressed.connect(GameState.go.bind(next))
		_buttons.add_child(b)
