class_name Customer
extends AnimatedSprite2D
## A customer that recolours itself from preset colour lists when it spawns.
##
## Usage:
##   var c := preload("res://customer.tscn").instantiate()   # or Customer.new()
##   add_child(c)              # randomize_look() runs automatically in _ready()
##   c.play("walk_down")
##
## Animations: idle_/walk_/sit_/eat_ + down/left/right/up, plus "wave" and "happy".

const SHEET := preload("res://sprites/customer_base.png")
const RECOLOR_SHADER := preload("res://shaders/customer_recolor.gdshader")

## Preset colour lists. Edit these in the Inspector or here.
@export var skin_tones: Array[Color] = [
	Color("#f6d0b1"), Color("#e3a87a"), Color("#c98a5e"),
	Color("#a86a42"), Color("#7d4a2c"), Color("#5a3420"),
]
@export var hair_colors: Array[Color] = [
	Color("#2b1d14"), Color("#55311c"), Color("#7a4a2c"), Color("#b5793a"),
	Color("#e3c06a"), Color("#c9452e"), Color("#8a8f99"), Color("#f2f0ea"),
]
@export var shirt_colors: Array[Color] = [
	Color("#4fa3a5"), Color("#e2483d"), Color("#2f4f8f"), Color("#f2c14e"),
	Color("#6aa84f"), Color("#9b59b6"), Color("#f28e2b"), Color("#ff8fab"),
]
@export var pants_colors: Array[Color] = [
	Color("#5a5f7a"), Color("#3a3a48"), Color("#2f4f8f"), Color("#8c6239"), Color("#e9e4da"),
]
@export var shoe_colors: Array[Color] = [
	Color("#8a5a3a"), Color("#2b2b33"), Color("#f2f0ea"), Color("#c9452e"),
]
## Set false if you want to call apply_look() yourself after spawning.
@export var randomize_on_ready := true

const BLUSH_TINT := Color("#e88472")

# SpriteFrames are built once and shared by every customer.
static var _shared_frames: SpriteFrames


func _ready() -> void:
	if sprite_frames == null:
		sprite_frames = Customer.build_frames()
	# Each customer needs its own material so colours aren't shared.
	var mat := ShaderMaterial.new()
	mat.shader = RECOLOR_SHADER
	material = mat
	if randomize_on_ready:
		randomize_look()
	if not is_playing():
		play("idle_down")


## Pick one colour from each preset list and apply it.
func randomize_look(rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var look := {
		"skin": _pick(skin_tones, rng),
		"hair": _pick(hair_colors, rng),
		"shirt": _pick(shirt_colors, rng),
		"pants": _pick(pants_colors, rng),
		"shoes": _pick(shoe_colors, rng),
	}
	apply_look(look)
	return look


## Apply specific colours, e.g. apply_look({"skin": Color("#c98a5e"), "shirt": Color.RED}).
## Missing keys keep their current colour. Shadows and blush are derived automatically.
func apply_look(look: Dictionary) -> void:
	var mat := material as ShaderMaterial
	if look.has("skin"):
		var s: Color = look["skin"]
		mat.set_shader_parameter("skin", s)
		mat.set_shader_parameter("skin_shadow", s.darkened(0.16))
		mat.set_shader_parameter("blush", s.lerp(BLUSH_TINT, 0.6))
	if look.has("hair"):
		var h: Color = look["hair"]
		mat.set_shader_parameter("hair", h)
		mat.set_shader_parameter("hair_shadow", h.darkened(0.3))
	if look.has("shirt"):
		var t: Color = look["shirt"]
		mat.set_shader_parameter("shirt", t)
		mat.set_shader_parameter("shirt_shadow", t.darkened(0.25))
	if look.has("pants"):
		mat.set_shader_parameter("pants", look["pants"])
	if look.has("shoes"):
		mat.set_shader_parameter("shoes", look["shoes"])


func _pick(list: Array[Color], rng: RandomNumberGenerator) -> Color:
	return list[rng.randi_range(0, list.size() - 1)]


## Slices customer_base.png (6 x 6 grid of 16x16 frames) into named animations.
static func build_frames() -> SpriteFrames:
	if _shared_frames != null:
		return _shared_frames
	var f := SpriteFrames.new()
	f.remove_animation("default")
	var dirs := ["down", "left", "right", "up"]
	for row in dirs.size():
		_add(f, "idle_" + dirs[row], [[row, 0], [row, 1]], 3.0)
		_add(f, "walk_" + dirs[row], [[row, 2], [row, 3], [row, 4], [row, 5]], 8.0)
	# row 4: sit/eat down, left, right   row 5: sit/eat up, wave, happy
	var sit_cells := {"down": [4, 0], "left": [4, 2], "right": [4, 4], "up": [5, 0]}
	for d in sit_cells:
		var r: int = sit_cells[d][0]
		var c: int = sit_cells[d][1]
		_add(f, "sit_" + d, [[r, c]], 1.0)
		_add(f, "eat_" + d, [[r, c], [r, c], [r, c + 1], [r, c]], 4.0)
	_add(f, "wave", [[5, 2], [5, 3]], 5.0)
	_add(f, "happy", [[5, 4], [5, 5]], 5.0)
	_shared_frames = f
	return f


static func _add(f: SpriteFrames, anim: String, cells: Array, fps: float) -> void:
	f.add_animation(anim)
	f.set_animation_speed(anim, fps)
	f.set_animation_loop(anim, true)
	for cell in cells:
		var tex := AtlasTexture.new()
		tex.atlas = SHEET
		tex.region = Rect2(cell[1] * 16, cell[0] * 16, 16, 16)
		f.add_frame(anim, tex)
