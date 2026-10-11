extends Node2D
## Title screen: solid palette background, the game's name at the top, Start and
## Settings buttons in the middle, the seal slapping its belly below them and the
## menu's food rocking left and right on both sides.

const GAME_SCENE := "res://scenes/game.tscn"
const SEAL := preload("res://sprites/seal.tscn")
const SETTINGS_MENU := preload("res://scripts/settings_menu.gd")

## The seal is drawn at this scale on the title screen only.
@export var seal_scale := 6.0
## Where the seal stands (screen pixels, 640x360 view).
@export var seal_position := Vector2(320, 296)

## Food icons: drawn at this scale, rocking this many degrees each way, one swing per `food_swing_time` seconds.
@export var food_scale := 3.0
@export var food_angle := 12.0
@export var food_swing_time := 1.2
## Where each food sits (screen pixels), in GameState.RECIPE_ICONS order.
@export var food_positions: Array[Vector2] = [
	Vector2(80, 110), Vector2(170, 175), Vector2(80, 240), Vector2(170, 305),
	Vector2(560, 110), Vector2(470, 175), Vector2(560, 240), Vector2(470, 305),
]

var start_button: Button
var settings_button: Button
var seal: CharacterBody2D
var _ui: CanvasLayer
var _settings: Control


func _ready() -> void:
	# solid background behind everything
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	var bg := ColorRect.new()
	bg.color = UiTheme.background
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_layer.add_child(bg)

	seal = SEAL.instantiate()
	seal.can_move = false
	seal.auto_animate = false
	seal.scale = Vector2(seal_scale, seal_scale)
	seal.position = seal_position
	add_child(seal)
	seal.sprite.play("belly_slap")

	_build_food()
	_build_ui()


## The menu items, each rocking left and right (alternate ones start the other way).
func _build_food() -> void:
	var names: Array = GameState.RECIPE_ICONS.keys()
	for i in mini(names.size(), food_positions.size()):
		var food := Sprite2D.new()
		food.texture = GameState.recipe_icon(names[i])
		food.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		food.scale = Vector2(food_scale, food_scale)
		food.position = food_positions[i]
		add_child(food)
		var dir := 1.0 if i % 2 == 0 else -1.0
		food.rotation_degrees = -food_angle * dir
		var rock := create_tween().set_loops()
		rock.tween_property(food, "rotation_degrees", food_angle * dir, food_swing_time) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		rock.tween_property(food, "rotation_degrees", -food_angle * dir, food_swing_time) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := Control.new()
	root.theme = UiTheme.theme
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)

	# big title, centred at the top
	var title := Label.new()
	title.text = "Seal of Approval"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.offset_top = 28
	root.add_child(title)

	# Start (and Settings under it) in the middle
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -40   # keep the buttons clear of the seal
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	center.add_child(buttons)
	start_button = Button.new()
	start_button.text = "Start"
	start_button.add_theme_font_size_override("font_size", UiTheme.title_font_size)
	start_button.custom_minimum_size = Vector2(140, 40)
	start_button.pressed.connect(start_game)
	buttons.add_child(start_button)
	settings_button = Button.new()
	settings_button.text = "Settings"
	settings_button.custom_minimum_size = Vector2(140, 28)
	settings_button.pressed.connect(open_settings)
	buttons.add_child(settings_button)
	start_button.grab_focus()   # Enter / Space start; arrow keys move between buttons


func open_settings() -> void:
	if _settings:
		return
	_settings = SETTINGS_MENU.new()
	_settings.closed.connect(func():
		_settings = null
		settings_button.grab_focus())
	_ui.add_child(_settings)


func start_game() -> void:
	GameState.reset()
	get_tree().change_scene_to_file(GAME_SCENE)
