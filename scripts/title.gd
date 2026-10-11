extends Node2D
## Title screen: the beach in the background, the game's name at the top and
## a Start button in the middle. Start begins a new game on day 1.

const GAME_SCENE := "res://scenes/game.tscn"
const BEACH := preload("res://scenes/main.tscn")
const SEAL := preload("res://sprites/seal.tscn")

## Where the camera looks on the beach (the restaurant and the shore).
@export var view_center := Vector2(528, 190)

var start_button: Button


func _ready() -> void:
	_build_backdrop()
	_build_ui()


## The beach scenery only (its gameplay script is removed so nothing runs).
func _build_backdrop() -> void:
	var beach := BEACH.instantiate()
	beach.set_script(null)
	add_child(beach)
	var seal := SEAL.instantiate()
	seal.can_move = false
	seal.position = view_center + Vector2(150, 110)
	beach.add_child(seal)
	seal.face("down")
	var camera := Camera2D.new()
	camera.position = view_center
	# stay inside the beach map
	var ground: TileMapLayer = beach.get_node("Ground")
	var r := ground.get_used_rect()
	var cell := Vector2(ground.tile_set.tile_size) * ground.scale
	camera.limit_left = int(r.position.x * cell.x)
	camera.limit_top = int(r.position.y * cell.y)
	camera.limit_right = int(r.end.x * cell.x)
	camera.limit_bottom = int(r.end.y * cell.y)
	add_child(camera)
	camera.make_current()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.theme = UiTheme.theme
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.background, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	# big title on a banner, centred at the top
	var banner := PanelContainer.new()
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.offset_top = 32
	root.add_child(banner)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 16)
	banner.add_child(pad)
	var title := Label.new()
	title.text = "Seal of Approval"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pad.add_child(title)

	# Start button in the middle
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	start_button = Button.new()
	start_button.text = "Start"
	start_button.add_theme_font_size_override("font_size", UiTheme.title_font_size)
	start_button.custom_minimum_size = Vector2(140, 40)
	start_button.pressed.connect(start_game)
	center.add_child(start_button)
	start_button.grab_focus()   # Enter / Space also start


func start_game() -> void:
	GameState.reset()
	get_tree().change_scene_to_file(GAME_SCENE)
