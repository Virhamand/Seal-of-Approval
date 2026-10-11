extends Control
## Settings pop-up with Music and Sound Effects volume sliders.
## Add it to a CanvasLayer; it fills the screen and emits `closed` on Back / Esc.

signal closed

var music_slider: HSlider
var sfx_slider: HSlider
var back_button: Button


func _ready() -> void:
	theme = UiTheme.theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.text, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	center.add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(pad)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	pad.add_child(box)
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", UiTheme.title_font_size)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	music_slider = _slider_row(box, "Music", Settings.music_volume, Settings.set_music_volume)
	sfx_slider = _slider_row(box, "Sound Effects", Settings.sfx_volume, Settings.set_sfx_volume)
	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(100, 0)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(close)
	box.add_child(back_button)
	music_slider.grab_focus()


## "Label  [-----o----]  80%" row. Returns the slider.
func _slider_row(parent: Control, text: String, value: float, on_change: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 100
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = round(value * 100)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var pct := Label.new()
	pct.custom_minimum_size.x = 40
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.text = "%d%%" % slider.value
	row.add_child(pct)
	slider.value_changed.connect(func(v: float):
		pct.text = "%d%%" % v
		on_change.call(v / 100.0))
	return slider


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()
