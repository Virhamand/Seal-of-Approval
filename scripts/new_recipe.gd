extends CanvasLayer
## Mini-game result pop-up, shown over Talking_to_Seal:
## "New Recipe Unlocked!" on a win, "Out of time!" when the timer ran out.
## Colours come from UiTheme (the panel keeps the translucency set in the scene).
## Any key press or mouse click emits `dismissed`.

signal dismissed

## Set before adding to the tree.
var won := true
## "" means every recipe is already unlocked.
var recipe_name := ""
## Ignore input for a moment so a key still held from the mini-game doesn't skip it.
@export var input_delay := 0.4
## Gap between the picture frame and the recipe icon (pixels).
@export var icon_padding := 8.0

@onready var panel: ColorRect = $ColorRect
@onready var title: Label = $Label
@onready var name_label: Label = $RecipeName
@onready var picture: ColorRect = $ColorRect2

var _accepting := false
var _hint: Label


func _ready() -> void:
	# theme colours, keeping the panel's alpha from the scene
	panel.color = Color(UiTheme.background, panel.color.a)
	picture.color = UiTheme.surface
	# let clicks fall through the panel so they reach _unhandled_input below
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for l in [title, name_label]:
		l.theme = UiTheme.theme
		l.add_theme_color_override("font_color", UiTheme.text)
		l.add_theme_font_size_override("font_size", UiTheme.title_font_size)
	# centre both labels across the panel so long names fit
	for l in [title, name_label]:
		l.position.x = panel.position.x
		l.size.x = panel.size.x
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if won:
		name_label.text = recipe_name if recipe_name != "" else "Menu complete!"
		_show_icon()
	else:
		title.text = "Out of time!"
		name_label.text = "No new recipe today"
		picture.hide()
	_hint = Label.new()
	_hint.theme = UiTheme.theme
	_hint.text = "Click or press any key to start the next day"
	_hint.add_theme_color_override("font_color", UiTheme.text)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(panel.position.x, panel.position.y + panel.size.y - 28)
	_hint.size.x = panel.size.x
	add_child(_hint)
	get_tree().create_timer(input_delay).timeout.connect(func(): _accepting = true)


## The unlocked recipe's menu icon, scaled up inside the picture frame.
func _show_icon() -> void:
	var icon := GameState.recipe_icon(recipe_name)
	if icon == null:
		picture.hide()
		return
	var tex := TextureRect.new()
	tex.texture = icon
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.offset_left = icon_padding
	tex.offset_top = icon_padding
	tex.offset_right = -icon_padding
	tex.offset_bottom = -icon_padding
	picture.add_child(tex)


func _unhandled_input(event: InputEvent) -> void:
	if not _accepting:
		return
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	var click: bool = event is InputEventMouseButton and event.pressed
	if key or click:
		_accepting = false
		get_viewport().set_input_as_handled()
		dismissed.emit()
