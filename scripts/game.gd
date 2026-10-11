extends Node2D
## Persistent root scene. Loads the level that belongs to the current
## GameState, shows the recipe pop-up when one is waiting, and shows
## temporary debug buttons for the legal next states.

const RECIPE_POPUP := preload("res://scenes/new_recipe.tscn")
const TITLE_SCENE := "res://scenes/title.tscn"
const ROSETTE := preload("res://sprites/sprite_sheets/rosette.png")
const SMALL_WIN := preload("res://assets/sounds/small_win.wav")
const SMALL_LOSS := preload("res://assets/sounds/small_loss.wav")
const VICTORY := preload("res://assets/sounds/victory.wav")

@onready var level_root: Node2D = $Level

var level: Node = null
var level_path := ""
var popup: Node = null
var _popup_layer: CanvasLayer
var _label: Label
var _buttons: HBoxContainer
var _rating_panel: Control
var _rating_bar: ProgressBar
var _rating_value: Label
var _end_layer: CanvasLayer
var _direction_layer: CanvasLayer
var _direction_label: Label
## The state the direction box belongs to; it disappears when we leave it.
var _direction_state := -1

## Chef's "thinking out loud" direction boxes (edit the wording here).
const DIRECTIONS := {
	"walk": "Phew, that's everyone served! I think I'll take a walk on the beach.",
	"unusual": "Huh? I hear an unusual sound outside... I should go check it out.",
	"familiar": "I hear a familiar sound outside. I should go take a look.",
	"seal": "That seal doesn't look so good... I should go check on it.",
	"door": "Nothing going on out here yet. I should head back inside through the restaurant door.",
}
## What "Return to Main Menu" does (tests swap this out).
var go_to_main_menu := func(): get_tree().change_scene_to_file(TITLE_SCENE)
## One-shot jingles (small win / small loss / victory).
var sfx_player := AudioStreamPlayer.new()


func _ready() -> void:
	add_to_group("game")
	_build_sounds()
	_popup_layer = CanvasLayer.new()
	_popup_layer.layer = 5
	add_child(_popup_layer)
	_build_rating_bar()
	_build_debug_ui()
	GameState.state_changed.connect(_on_state_changed)
	GameState.result_ready.connect(func(): _update_recipe_popup(); _refresh_debug_ui())
	GameState.rating_changed.connect(func(_v): _update_rating_bar())
	GameState.ending_reached.connect(_show_end_screen)
	GameState.restarted.connect(_on_restarted)
	GameState.service_finished.connect(_on_service_finished)
	_show_state(GameState.state)


func level_path_for(s: GameState.State) -> String:
	match s:
		GameState.State.RUNNING_RESTAURANT:
			return "res://scenes/temp_restaurant_scene.tscn"
		GameState.State.WALKING_ON_BEACH, GameState.State.TALKING_TO_SEAL:
			return "res://scenes/main.tscn"   # the beach
		GameState.State.SEAL_MINI_GAME:
			return "res://scenes/sea_repeat.tscn"
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
	if s != _direction_state:
		hide_direction()
	if level.has_method("enter_state"):
		level.enter_state(s)
	if s == GameState.State.WALKING_ON_BEACH and GameState.seal_fed \
			and not GameState.seal_calling() and not GameState.is_rating_full():
		show_direction(DIRECTIONS.door, s)   # nothing for the chef to do out here yet
	_update_recipe_popup()
	_update_rating_bar()
	_refresh_debug_ui()


func _on_restarted() -> void:
	sfx_player.stop()   # cut the victory jingle on Play again
	if _end_layer:
		_end_layer.queue_free()
		_end_layer = null
	# force a fresh level even if the scene path is the same
	if level:
		level_root.remove_child(level)
		level.queue_free()
		level = null
	level_path = ""


# ---------------------------------------------------------------- rating bar
## Top-right "Rating 35/100" bar. Hidden during the seal mini-game.
func _build_rating_bar() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	var corner := MarginContainer.new()
	corner.theme = UiTheme.theme
	corner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.offset_top = 6
	corner.offset_right = -6
	layer.add_child(corner)
	_rating_panel = corner
	var panel := PanelContainer.new()
	corner.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	var star := TextureRect.new()
	star.texture = _star_texture()
	star.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	star.custom_minimum_size = Vector2(11, 11)
	row.add_child(star)
	var title := Label.new()
	title.text = "Rating"
	row.add_child(title)
	_rating_bar = ProgressBar.new()
	_rating_bar.max_value = GameState.RATING_MAX
	_rating_bar.show_percentage = false
	_rating_bar.custom_minimum_size = Vector2(90, 10)
	_rating_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_rating_bar)
	_rating_value = Label.new()
	_rating_value.custom_minimum_size.x = 48
	row.add_child(_rating_value)


func _update_rating_bar() -> void:
	_rating_bar.value = GameState.rating
	_rating_value.text = "%d/%d" % [GameState.rating, GameState.RATING_MAX]
	_rating_panel.visible = GameState.state != GameState.State.SEAL_MINI_GAME


## A small pixel star in the theme's border colour.
func _star_texture() -> Texture2D:
	var rows := [
		".....#.....",
		".....#.....",
		"....###....",
		"###########",
		".#########.",
		"..#######..",
		"..#######..",
		".####.####.",
		".###...###.",
		"##.......##",
	]
	var img := Image.create(11, 10, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == "#":
				img.set_pixel(x, y, UiTheme.border)
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- direction boxes
## Everyone has been served: tell the player where to go next.
func _on_service_finished() -> void:
	if GameState.state != GameState.State.RUNNING_RESTAURANT:
		return
	if GameState.day == 1:
		show_direction(DIRECTIONS.walk, GameState.state)
	elif GameState.seal_calling():
		show_direction(DIRECTIONS.unusual if GameState.day == 2 else DIRECTIONS.familiar, GameState.state)


## Show the chef's direction box at the bottom. `text` is a DIRECTIONS key or
## any line. It stays (without blocking the game) until the player leaves
## `for_state`. Levels reach it with
## get_tree().call_group("game", "show_direction", "seal", GameState.state).
func show_direction(text: String, for_state: int) -> void:
	if _direction_layer == null:
		_build_direction_box()
	_direction_label.text = DIRECTIONS.get(text, text)
	_direction_state = for_state
	_direction_layer.show()


func hide_direction() -> void:
	_direction_state = -1
	if _direction_layer:
		_direction_layer.hide()


func _build_direction_box() -> void:
	_direction_layer = CanvasLayer.new()
	_direction_layer.layer = 6
	add_child(_direction_layer)
	var holder := MarginContainer.new()
	holder.theme = UiTheme.theme
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE   # never blocks clicks in the level
	holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	for side in ["left", "right", "bottom"]:
		holder.add_theme_constant_override("margin_" + side, 16)
	_direction_layer.add_child(holder)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var who := Label.new()
	who.text = "Chef"
	box.add_child(who)
	_direction_label = Label.new()
	_direction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_direction_label.custom_minimum_size = Vector2(0, 36)
	box.add_child(_direction_label)


# ---------------------------------------------------------------- the end
func _show_end_screen() -> void:
	if _end_layer:
		return
	_play_sfx(VICTORY)
	_end_layer = CanvasLayer.new()
	_end_layer.layer = 20
	add_child(_end_layer)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.text, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_layer.add_child(dim)
	var center := CenterContainer.new()
	center.theme = UiTheme.theme
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_layer.add_child(center)
	# the end panel with the rosette to its right
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	center.add_child(row)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = "The End"
	title.add_theme_font_size_override("font_size", UiTheme.title_font_size)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var earned := Label.new()
	earned.text = "You have earned the"
	earned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(earned)
	var seal_of_approval := Label.new()
	seal_of_approval.text = "Seal of Approval"
	seal_of_approval.add_theme_font_size_override("font_size", UiTheme.title_font_size)
	seal_of_approval.add_theme_color_override("font_color", UiTheme.highlight)
	seal_of_approval.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(seal_of_approval)
	var menu := Button.new()
	menu.text = "Return to Main Menu"
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.pressed.connect(_return_to_main_menu)
	box.add_child(menu)
	# the rosette pops in next to the panel (drawn at 2x)
	var rosette := TextureRect.new()
	rosette.texture = ROSETTE
	rosette.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rosette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rosette.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rosette.custom_minimum_size = ROSETTE.get_size() * 2
	rosette.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rosette)
	rosette.pivot_offset = rosette.custom_minimum_size / 2
	rosette.scale = Vector2.ZERO
	var pop := create_tween()
	pop.tween_interval(0.3)
	pop.tween_property(rosette, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _return_to_main_menu() -> void:
	sfx_player.stop()
	GameState.reset()
	go_to_main_menu.call()


# ---------------------------------------------------------------- sounds
func _build_sounds() -> void:
	sfx_player.bus = Settings.SFX_BUS
	add_child(sfx_player)


func _play_sfx(stream: AudioStreamWAV) -> void:
	var once: AudioStreamWAV = stream.duplicate()
	once.loop_mode = AudioStreamWAV.LOOP_DISABLED
	sfx_player.stream = once
	sfx_player.play()


# ---------------------------------------------------------------- recipe pop-up
func _update_recipe_popup() -> void:
	var want := GameState.state == GameState.State.TALKING_TO_SEAL and GameState.result_pending
	if want and popup == null:
		popup = RECIPE_POPUP.instantiate()
		popup.won = GameState.last_won
		popup.recipe_name = GameState.last_recipe
		popup.dismissed.connect(_on_recipe_dismissed)
		_popup_layer.add_child(popup)
		_play_sfx(SMALL_WIN if GameState.last_won else SMALL_LOSS)   # every new recipe (day 1 too)
	elif not want and popup != null:
		popup.queue_free()
		popup = null


func _on_recipe_dismissed() -> void:
	GameState.go(GameState.State.RUNNING_RESTAURANT)   # next day


# ---------------------------------------------------------------- temporary debug UI
func _build_debug_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var panel := PanelContainer.new()
	panel.theme = UiTheme.theme
	panel.position = Vector2(4, 4)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_label = Label.new()
	box.add_child(_label)
	_buttons = HBoxContainer.new()
	box.add_child(_buttons)
	var fill := Button.new()
	fill.text = "Fill rating"
	fill.focus_mode = Control.FOCUS_NONE
	fill.pressed.connect(func(): GameState.set_rating(GameState.RATING_MAX))
	var serve := Button.new()
	serve.text = "Finish serving"
	serve.focus_mode = Control.FOCUS_NONE
	serve.pressed.connect(GameState.end_service)
	var row := HBoxContainer.new()
	row.add_child(fill)
	row.add_child(serve)
	box.add_child(row)


func _refresh_debug_ui() -> void:
	_label.text = "Day %d  |  %s" % [GameState.day, GameState.state_name(GameState.state)]
	for b in _buttons.get_children():
		b.queue_free()
	for next in GameState.allowed_next():
		var b := Button.new()
		b.text = GameState.state_name(next)
		if GameState.result_pending and next == GameState.State.RUNNING_RESTAURANT:
			b.text += " (new day)"
		b.focus_mode = Control.FOCUS_NONE   # so arrow keys / space never press it
		b.pressed.connect(GameState.go.bind(next))
		_buttons.add_child(b)
