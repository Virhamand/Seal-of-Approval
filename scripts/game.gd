extends Node2D
## Persistent root scene. Loads the level that belongs to the current
## GameState, shows the recipe pop-up when one is waiting, and shows
## temporary debug buttons for the legal next states.

const RECIPE_POPUP := preload("res://scenes/new_recipe.tscn")
const SMALL_WIN := preload("res://assets/sounds/small_win.wav")
const SMALL_LOSS := preload("res://assets/sounds/small_loss.wav")
const VICTORY := preload("res://assets/sounds/victory.wav")
const BELLY_SLAP := preload("res://assets/sounds/seal-belly-slap.mp3")

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
## One-shot jingles (small win / small loss / victory).
var sfx_player := AudioStreamPlayer.new()
## The seal slapping its belly, on loop while talking to it.
var slap_player := AudioStreamPlayer.new()


func _ready() -> void:
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
	if level.has_method("enter_state"):
		level.enter_state(s)
	_update_recipe_popup()
	_update_rating_bar()
	_refresh_debug_ui()
	_update_slap()


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


# ---------------------------------------------------------------- the end
func _show_end_screen() -> void:
	if _end_layer:
		return
	_update_slap()
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
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = "The End"
	title.add_theme_font_size_override("font_size", UiTheme.title_font_size)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var days := Label.new()
	days.text = "You reached %d rating in %d day%s." % [GameState.RATING_MAX, GameState.day, "" if GameState.day == 1 else "s"]
	days.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(days)
	var recipes := Label.new()
	recipes.text = "Recipes on the menu: %d" % GameState.unlocked_recipes.size()
	recipes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(recipes)
	var again := Button.new()
	again.text = "Play again"
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(GameState.restart)
	box.add_child(again)


# ---------------------------------------------------------------- sounds
func _build_sounds() -> void:
	add_child(sfx_player)
	var slap: AudioStreamMP3 = BELLY_SLAP.duplicate()
	slap.loop = true
	slap_player.stream = slap
	add_child(slap_player)


func _play_sfx(stream: AudioStreamWAV) -> void:
	var once: AudioStreamWAV = stream.duplicate()
	once.loop_mode = AudioStreamWAV.LOOP_DISABLED
	sfx_player.stream = once
	sfx_player.play()


## Belly slaps play while talking to the seal (not over The End).
func _update_slap() -> void:
	var want := GameState.state == GameState.State.TALKING_TO_SEAL and not GameState.ending
	if want and not slap_player.playing:
		slap_player.play()
	elif not want and slap_player.playing:
		slap_player.stop()


# ---------------------------------------------------------------- recipe pop-up
func _update_recipe_popup() -> void:
	var want := GameState.state == GameState.State.TALKING_TO_SEAL and GameState.result_pending
	if want and popup == null:
		popup = RECIPE_POPUP.instantiate()
		popup.won = GameState.last_won
		popup.recipe_name = GameState.last_recipe
		popup.dismissed.connect(_on_recipe_dismissed)
		_popup_layer.add_child(popup)
		if GameState.previous_state == GameState.State.SEAL_MINI_GAME:
			_play_sfx(SMALL_WIN if GameState.last_won else SMALL_LOSS)
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
