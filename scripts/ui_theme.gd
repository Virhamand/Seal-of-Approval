extends Node
## UI colour theme (autoload: UiTheme).
##
## Every menu, button, progress bar and text box gets its colours from here.
## To re-theme the game, change the colours below — nothing else needs editing.
## Palette: https://colorhunt.co/palette/f9e8a2b4e1eb95bdd778a4cb

var background := Color("#F9E8A2")   # panels, text boxes, pop-ups
var surface := Color("#B4E1EB")      # buttons, empty part of progress bars
var accent := Color("#95BDD7")       # button hover
var border := Color("#78A4CB")       # outlines, pressed buttons, progress fill
var text := Color("#2B3A55")         # all text (dark so it reads on the light palette)

## Pixel font for every text. m5x7 is drawn for multiples of 16, so keep sizes at 16/32/48.
var font_path := "res://assets/fonts/m5x7.ttf"
var font_size := 16
var title_font_size := 32
var corner_radius := 3

var font: Font

## The Godot Theme built from the colours above. Assign it to any Control's
## `theme` property and that Control and its children use it.
var theme: Theme


func _ready() -> void:
	rebuild()
	# every Control in the game window inherits the theme (and so the font)
	get_tree().root.theme = theme


## Rebuild `theme` after changing colours at runtime.
func rebuild() -> void:
	var t := Theme.new()
	font = load(font_path)
	if font is FontFile:
		# crisp pixels: no smoothing or sub-pixel placement
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font.hinting = TextServer.HINTING_NONE
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	t.default_font = font
	t.default_font_size = font_size

	var panel := box(background, border, 2)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	t.set_stylebox("normal", "Button", box(surface, border, 1))
	t.set_stylebox("hover", "Button", box(accent, border, 1))
	t.set_stylebox("pressed", "Button", box(border, border, 1))
	t.set_stylebox("disabled", "Button", box(surface.darkened(0.1), border, 1))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", text)

	t.set_color("font_color", "Label", text)

	t.set_stylebox("background", "ProgressBar", box(surface, border, 1))
	t.set_stylebox("fill", "ProgressBar", box(border, border, 0))
	t.set_color("font_color", "ProgressBar", text)

	theme = t


func box(bg: Color, edge: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(corner_radius)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb
