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
var highlight := Color("#DE5F85")    # pink for words that should pop ("Seal of Approval")

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


var _star: Texture2D


## A small pixel star in the border colour (rating bar, "+8" floats).
func star_texture() -> Texture2D:
	if _star:
		return _star
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
				img.set_pixel(x, y, border)
	_star = ImageTexture.create_from_image(img)
	return _star


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

	# volume sliders: track like a progress bar, a small square grabber
	var track := box(surface, border, 1)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	var filled := box(border, border, 0)
	filled.content_margin_top = 4
	filled.content_margin_bottom = 4
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	t.set_icon("grabber", "HSlider", _grabber(background))
	t.set_icon("grabber_highlight", "HSlider", _grabber(accent))

	theme = t


## 10x16 slider handle: `fill` with a border-coloured outline.
func _grabber(fill: Color) -> Texture2D:
	var img := Image.create(10, 16, false, Image.FORMAT_RGBA8)
	img.fill(border)
	img.fill_rect(Rect2i(1, 1, 8, 14), fill)
	return ImageTexture.create_from_image(img)


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
