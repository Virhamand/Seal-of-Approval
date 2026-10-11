extends Node2D
## Running_restaurant: serve the day's customers.
##
##   Customers come in through the right door tile, line up below the register
##   and show what they want in a bubble (the list at the top right has them in
##   order). F at the fridge takes the item for the oldest order that isn't
##   started: a drink is ready at once, a dish gives its ingredient. F at a
##   stove cooks the ingredient (loading circle, then a bubble with the dish;
##   F again picks it up). F at the register hands the dish over: stars go up
##   and the customer leaves through the left door tile. Customers who wait
##   too long leave on their own. When everyone has gone, GameState.end_service()
##   is called and stepping on the doormat takes the chef out to the beach.

const CUSTOMER := preload("res://scenes/customer.tscn")
const TILESET_IMAGE := preload("res://tiles/interior_tileset.png")
const CELL := 24.0   # 16 px tiles drawn at 1.5x

## Kitchen stations, in tile cells (see the TileMapLayers in the editor).
@export var fridge_cell := Vector2i(1, 3)
@export var stove_cells: Array[Vector2i] = [Vector2i(4, 3), Vector2i(5, 3)]
@export var register_cell := Vector2i(6, 7)
## The doormat: customers come in on the right tile and leave by the left one.
@export var enter_cell := Vector2i(11, 14)
@export var exit_cell := Vector2i(10, 14)
## Where customers wait, front of the line first.
@export var queue_cells: Array[Vector2i] = [
	Vector2i(6, 8), Vector2i(6, 9), Vector2i(6, 10), Vector2i(6, 11),
	Vector2i(6, 12), Vector2i(6, 13), Vector2i(5, 13),
]
## Customers walk along this column (beside the line) and this row (to the door).
@export var aisle_column := 7
@export var aisle_row := 13
## Where the chef starts: in the kitchen on a new day, or just inside the door.
@export var kitchen_start := Vector2(84, 132)
@export var door_start := Vector2(264, 318)
## How close the chef must be to a station to use it.
@export var interact_distance := 30.0
@export var cook_time := 4.0
@export var customer_speed := 60.0
@export var first_customer_delay := 2.0
@export var spawn_interval := 8.0
## Seconds a customer waits in line before giving up (no stars).
@export var patience := 40.0

const MORNING := {
	1: "Only fries and water on the menu... let's see who shows up.",
	2: "A new dish on the menu! Word should get around. %d customers today.",
}
const MORNING_LATER := "%d customers today. Time to get cooking!"

## One customer.
class Guest:
	var node: Node2D
	var sprite: AnimatedSprite2D
	var order := ""
	var started := false       # the chef has taken this order's item from the fridge
	var waiting := false       # in line (can be served), even while still walking up
	var arrived := false       # reached the spot: patience starts counting
	var patience_left := 0.0
	var bubble: Control
	var patience_bar: ProgressBar
	var tween: Tween

## The loading circle over a stove.
class Spinner extends Node2D:
	var progress := 0.0
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 8.0, UiTheme.background)
		draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 24, UiTheme.border, 1.0)
		if progress > 0.0:
			draw_arc(Vector2.ZERO, 5.0, -PI / 2, -PI / 2 + TAU * progress, 24, UiTheme.border, 4.0)

@onready var chef: CharacterBody2D = $Chef

var guests: Array[Guest] = []     # everyone on screen
var line: Array[Guest] = []       # waiting, front first
## What the chef carries: {"dish": String, "cooked": bool, "guest": Guest or null}.
var held := {}
var held_sprite: Sprite2D
## One entry per stove: {"pos", "item", "progress", "spinner", "bubble"}.
var stoves: Array[Dictionary] = []
var _spawned := 0
var _spawn_timer := 0.0
var _left_screen := 0
var _door_area: Area2D
var _orders_box: VBoxContainer
var _day_label: Label
var _tutorial: CanvasLayer
var _tutorial_ready := false


func _ready() -> void:
	held_sprite = Sprite2D.new()
	held_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	held_sprite.position = Vector2(0, -16)
	held_sprite.z_index = 2
	held_sprite.hide()
	chef.add_child(held_sprite)
	for c in stove_cells:
		var spinner := Spinner.new()
		spinner.position = cell_pos(c) + Vector2(0, -8)   # on the burners
		spinner.z_index = 10
		spinner.hide()
		add_child(spinner)
		stoves.append({"pos": cell_pos(c), "item": {}, "progress": 0.0, "spinner": spinner, "bubble": null})
	_build_door()
	_build_orders_panel()


func enter_state(_s: GameState.State) -> void:
	chef.can_move = true
	chef.face("down")   # player in control: start facing down
	var from_beach := GameState.previous_state == GameState.State.WALKING_ON_BEACH
	chef.position = door_start if from_beach else kitchen_start
	if not GameState.service_done:
		GameState.start_service()
		_spawned = GameState.customers_done   # anyone who was in line comes back
		_spawn_timer = first_customer_delay
		if not GameState.cooking_tutorial_seen:
			_show_tutorial()   # the morning line comes after it
		elif not from_beach:
			_say(_morning_line(), 0.0)
	_refresh_orders_panel()


func _morning_line() -> String:
	var n := GameState.customers_today
	if GameState.day in MORNING:
		return MORNING[GameState.day] % n if "%d" in MORNING[GameState.day] else MORNING[GameState.day]
	return MORNING_LATER % n


func cell_pos(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * CELL


# ---------------------------------------------------------------- each frame
func _process(delta: float) -> void:
	# new customers (none while the tutorial is up)
	if _tutorial == null and not GameState.service_done and _spawned < GameState.customers_today:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = spawn_interval
			_spawn_guest()
	# cooking
	for st in stoves:
		if not st.item.is_empty() and st.progress < 1.0:
			st.progress = minf(st.progress + delta / cook_time, 1.0)
			st.spinner.progress = st.progress
			st.spinner.queue_redraw()
			if st.progress >= 1.0:
				st.spinner.hide()
				st.bubble = _make_bubble(GameState.recipe_icon(st.item.dish))
				st.bubble.position = st.pos + Vector2(-st.bubble.size.x / 2, -30)
	# waiting customers lose patience
	for g in line.duplicate():
		g.bubble.position = g.node.position + Vector2(-g.bubble.size.x / 2, -46)
		if not g.arrived:
			continue
		g.patience_left -= delta
		g.patience_bar.value = g.patience_left / patience * 100.0
		if g.patience_left <= 0.0:
			_give_up(g)


func _unhandled_input(event: InputEvent) -> void:
	if _tutorial != null:
		var key: bool = event is InputEventKey and event.pressed and not event.echo
		var click: bool = event is InputEventMouseButton and event.pressed
		if _tutorial_ready and (key or click):
			get_viewport().set_input_as_handled()
			_close_tutorial()
		return
	if event.is_action_pressed("interact") and chef.can_move:
		get_viewport().set_input_as_handled()
		_interact()


# ---------------------------------------------------------------- tutorial
## First day only: how the kitchen works. Customers wait until it is closed.
func _show_tutorial() -> void:
	chef.can_move = false
	_tutorial = CanvasLayer.new()
	_tutorial.layer = 15
	add_child(_tutorial)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.text, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tutorial.add_child(dim)
	var center := CenterContainer.new()
	center.theme = UiTheme.theme
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tutorial.add_child(center)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(pad)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	pad.add_child(box)
	var title := Label.new()
	title.text = "Running the restaurant"
	title.add_theme_font_size_override("font_size", UiTheme.title_font_size)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var steps := [
		[_tile_icon(10, 3, 1, 2), "Customers line up at the counter and show what they want."],
		[_tile_icon(10, 3, 1, 2), "F at the fridge takes the item for the oldest order."],
		[_tile_icon(5, 3), "F at a stove cooks it. When the circle is full, F again picks it up."],
		[_tile_icon(15, 2), "F at the register hands it over. Happy customers give stars!"],
		[GameState.recipe_icon("Water"), "Drinks are ready straight from the fridge."],
		[_tile_icon(5, 0), "Once everyone has left, step on the doormat to go outside."],
	]
	steps[0][0] = _customer_icon()
	for st in steps:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var pic := TextureRect.new()
		pic.texture = st[0]
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.custom_minimum_size = Vector2(32, 32)
		row.add_child(pic)
		var label := Label.new()
		label.text = st[1]
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label)
		box.add_child(row)
	var hint := Label.new()
	hint.text = "Click or press any key to open up"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	get_tree().create_timer(0.4).timeout.connect(func(): _tutorial_ready = true)


func _close_tutorial() -> void:
	GameState.cooking_tutorial_seen = true
	_tutorial.queue_free()
	_tutorial = null
	chef.can_move = true
	_say(_morning_line(), 0.0)


## A tile from the interior tileset as a texture (atlas coords, size in tiles).
static func _tile_icon(x: int, y: int, w := 1, h := 1) -> Texture2D:
	var tex := AtlasTexture.new()
	tex.atlas = TILESET_IMAGE
	tex.region = Rect2(x * 16, y * 16, w * 16, h * 16)
	return tex


## The customer sheet's first frame.
static func _customer_icon() -> Texture2D:
	var tex := AtlasTexture.new()
	tex.atlas = preload("res://sprites/sprite_sheets/customer_base.png")
	tex.region = Rect2(0, 0, 16, 16)
	return tex


# ---------------------------------------------------------------- the chef
## F: use whichever station is next to the chef.
func _interact() -> void:
	var p := chef.position
	var best := ""
	var best_i := -1
	var best_d := interact_distance
	var d := p.distance_to(cell_pos(fridge_cell))
	if d <= best_d:
		best = "fridge"; best_d = d
	d = p.distance_to(cell_pos(register_cell))
	if d <= best_d:
		best = "register"; best_d = d
	for i in stoves.size():
		d = p.distance_to(stoves[i].pos)
		if d <= best_d:
			best = "stove"; best_i = i; best_d = d
	match best:
		"fridge": _use_fridge()
		"register": _use_register()
		"stove": _use_stove(stoves[best_i])


func _use_fridge() -> void:
	if not held.is_empty():
		# put it back so the order can be started again
		if held.guest != null and held.guest.waiting:
			held.guest.started = false
		_clear_held()
		_say("Back in the fridge.", 2.0)
		_refresh_orders_panel()
		return
	for g in line:
		if not g.started:
			g.started = true
			var drink := GameState.is_drink(g.order)
			held = {"dish": g.order, "cooked": drink, "guest": g}
			_show_held()
			_say(("%s, coming up!" if drink else "One %s. This needs to go on the stove.") % g.order, 2.5)
			_refresh_orders_panel()
			return
	_say("No orders to prepare right now.", 2.0)


func _use_stove(st: Dictionary) -> void:
	if held.is_empty():
		if not st.item.is_empty() and st.progress >= 1.0:
			held = st.item
			held.cooked = true
			st.item = {}
			st.progress = 0.0
			st.bubble.queue_free()
			st.bubble = null
			_show_held()
			_say("%s is ready! To the register." % held.dish, 2.5)
		elif not st.item.is_empty():
			_say("Still cooking...", 1.5)
		else:
			_say("I need an ingredient from the fridge first.", 2.0)
	elif held.cooked:
		_say("That's already done. It goes to the register.", 2.0)
	elif st.item.is_empty():
		st.item = held
		st.progress = 0.0
		st.spinner.progress = 0.0
		st.spinner.show()
		st.spinner.queue_redraw()
		held = {}
		_clear_held()
	else:
		_say("That stove is busy. Try the other one.", 2.0)


func _use_register() -> void:
	if held.is_empty():
		_say("I need to prepare an order first.", 2.0)
		return
	if not held.cooked:
		_say("I have to cook that first!", 2.0)
		return
	var g: Guest = held.guest if held.guest != null and held.guest.waiting and held.guest.order == held.dish else null
	if g == null:
		for other in line:
			if other.order == held.dish:
				g = other
				break
	if g == null:
		_say("Nobody ordered that... back to the fridge with it.", 2.5)
		return
	_serve(g)


func _show_held() -> void:
	var icon := GameState.recipe_icon(held.dish) if held.cooked else GameState.ingredient_icon(GameState.ingredient_of(held.dish))
	held_sprite.texture = icon
	held_sprite.show()


func _clear_held() -> void:
	held = {}
	held_sprite.hide()


# ---------------------------------------------------------------- customers
func _spawn_guest() -> void:
	_spawned += 1
	var g := Guest.new()
	g.node = CUSTOMER.instantiate()
	g.node.scale = Vector2(2, 2)   # match the chef
	g.node.z_index = 3
	g.node.position = cell_pos(enter_cell) + Vector2(0, 40)   # just off screen
	add_child(g.node)
	g.sprite = g.node.get_node("Customer")
	g.order = GameState.pick_order()
	guests.append(g)
	var spot := line.size()
	line.append(g)
	get_tree().call_group("game", "hide_direction")   # the morning line is over
	g.waiting = true
	g.patience_left = patience
	g.bubble = _make_bubble(GameState.recipe_icon(g.order), true)
	g.patience_bar = g.bubble.get_node("Box/Patience")
	_refresh_orders_panel()
	await _walk(g, _path_to_spot(spot), "idle_up")
	g.arrived = true


## From the door to line spot `i`: in, along the aisle row, up the aisle column, step into place.
func _path_to_spot(i: int) -> Array[Vector2]:
	var spot := cell_pos(queue_cells[i])
	var path: Array[Vector2] = [cell_pos(enter_cell), cell_pos(Vector2i(enter_cell.x, aisle_row))]
	if queue_cells[i].y != aisle_row:
		path.append(cell_pos(Vector2i(aisle_column, aisle_row)))
		path.append(cell_pos(Vector2i(aisle_column, queue_cells[i].y)))
	path.append(spot)
	return path


## From line spot `i` back out through the exit tile.
func _path_out(i: int) -> Array[Vector2]:
	var path: Array[Vector2] = []
	if queue_cells[i].y != aisle_row:
		path.append(cell_pos(Vector2i(aisle_column, queue_cells[i].y)))
		path.append(cell_pos(Vector2i(aisle_column, aisle_row)))
	path.append(cell_pos(Vector2i(exit_cell.x, aisle_row)))
	path.append(cell_pos(exit_cell))
	path.append(cell_pos(exit_cell) + Vector2(0, 40))
	return path


## Walk the customer through `points`, playing walk_ animations, then `end_anim`.
func _walk(g: Guest, points: Array[Vector2], end_anim: String) -> void:
	if g.tween and g.tween.is_valid():
		g.tween.kill()
	var t := create_tween()
	g.tween = t
	var from := g.node.position
	for p in points:
		var dir := p - from
		if dir.length() < 0.5:
			continue
		var anim := "walk_" + _dir_name(dir)
		t.tween_callback(g.sprite.play.bind(anim))
		t.tween_property(g.node, "position", p, dir.length() / customer_speed)
		from = p
	t.tween_callback(g.sprite.play.bind(end_anim))
	await t.finished


func _serve(g: Guest) -> void:
	var stars := GameState.stars_for(g.order)
	GameState.add_rating(stars)
	_float_stars(stars, g.node.position + Vector2(22, -36))
	_clear_held()
	_leave(g, "happy", true)
	_say("Enjoy!", 1.5)


func _give_up(g: Guest) -> void:
	_leave(g, "idle_down", false)
	_say("Oh no, a customer got tired of waiting...", 3.0)


## The customer leaves the line and walks out; everyone behind shuffles up.
func _leave(g: Guest, anim: String, happy: bool) -> void:
	var i := line.find(g)
	line.erase(g)
	g.waiting = false
	if not held.is_empty() and held.guest == g:
		held.guest = null   # the chef can still serve it to someone else who ordered it
	g.bubble.queue_free()
	g.bubble = null
	GameState.customers_done += 1
	_refresh_orders_panel()
	for k in line.size():
		_walk(line[k], [cell_pos(queue_cells[k])], "idle_up")
	g.sprite.play(anim)
	if happy:
		await get_tree().create_timer(0.8).timeout
		if not is_inside_tree():
			return
	await _walk(g, _path_out(i), "walk_down")
	if not is_inside_tree():
		return
	guests.erase(g)
	g.node.queue_free()
	_left_screen += 1
	if GameState.customers_done >= GameState.customers_today and line.is_empty() and guests.is_empty():
		GameState.end_service()


# ---------------------------------------------------------------- door
## Stepping on the doormat goes out to the beach once everyone has been served.
func _build_door() -> void:
	var mid := (cell_pos(enter_cell) + cell_pos(exit_cell)) / 2
	_door_area = Area2D.new()
	_door_area.position = mid
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(CELL * 2, CELL)
	shape.shape = rect
	_door_area.add_child(shape)
	add_child(_door_area)
	_door_area.body_entered.connect(_on_door_entered)
	# nothing past the doormat: an invisible wall just below the screen
	var wall := StaticBody2D.new()
	wall.position = mid + Vector2(0, CELL * 0.5 + 4)
	var wall_shape := CollisionShape2D.new()
	var wall_rect := RectangleShape2D.new()
	wall_rect.size = Vector2(CELL * 2 + 8, 8)
	wall_shape.shape = wall_rect
	wall.add_child(wall_shape)
	add_child(wall)


func _on_door_entered(body: Node2D) -> void:
	if body != chef or not chef.can_move:
		return
	if GameState.service_done:
		GameState.go.call_deferred(GameState.State.WALKING_ON_BEACH)
	else:
		_say("busy", 2.5)


# ---------------------------------------------------------------- UI bits
## Direction box at the bottom (see game.gd). `text` can be a DIRECTIONS key.
func _say(text: String, seconds: float) -> void:
	get_tree().call_group("game", "show_direction", text, GameState.State.RUNNING_RESTAURANT, seconds)


## A small panel with a 16x16 icon (and a patience bar under it for customers).
func _make_bubble(icon: Texture2D, with_patience := false) -> Control:
	var panel := PanelContainer.new()
	panel.theme = UiTheme.theme
	panel.z_index = 10
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var pic := TextureRect.new()
	pic.texture = icon
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	pic.custom_minimum_size = Vector2(16, 16)
	box.add_child(pic)
	if with_patience:
		var bar := ProgressBar.new()
		bar.name = "Patience"
		bar.show_percentage = false
		bar.value = 100
		bar.custom_minimum_size = Vector2(16, 4)
		box.add_child(bar)
	add_child(panel)
	panel.reset_size()
	return panel


## "+8 [star]" drifting up from the served customer.
func _float_stars(stars: int, at: Vector2) -> void:
	var row := HBoxContainer.new()
	row.theme = UiTheme.theme
	row.z_index = 11
	row.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.text = "+%d" % stars
	label.add_theme_color_override("font_color", UiTheme.highlight)
	row.add_child(label)
	var star := TextureRect.new()
	star.texture = UiTheme.star_texture()
	star.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(star)
	add_child(row)
	row.reset_size()
	row.position = at + Vector2(-row.size.x / 2, 0)
	var t := create_tween().set_parallel()
	t.tween_property(row, "position:y", at.y - 24, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(row, "modulate:a", 0.0, 1.0).set_delay(0.4)
	t.chain().tween_callback(row.queue_free)


## Pending orders (oldest first) and the day's progress, under the rating bar.
func _build_orders_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 7
	add_child(layer)
	var corner := MarginContainer.new()
	corner.theme = UiTheme.theme
	corner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.offset_top = 32
	corner.offset_right = -6
	layer.add_child(corner)
	var panel := PanelContainer.new()
	corner.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Orders"
	box.add_child(title)
	_orders_box = VBoxContainer.new()
	_orders_box.add_theme_constant_override("separation", 2)
	box.add_child(_orders_box)
	_day_label = Label.new()
	box.add_child(_day_label)


func _refresh_orders_panel() -> void:
	for c in _orders_box.get_children():
		c.queue_free()
	if line.is_empty():
		var none := Label.new()
		none.text = "  (none yet)"
		none.modulate.a = 0.6
		_orders_box.add_child(none)
	for g in line:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var pic := TextureRect.new()
		pic.texture = GameState.recipe_icon(g.order)
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(pic)
		var name_label := Label.new()
		name_label.text = g.order + ("  (started)" if g.started else "")
		row.add_child(name_label)
		if g.started:
			row.modulate.a = 0.6
		_orders_box.add_child(row)
	var left := GameState.customers_today - GameState.customers_done
	_day_label.text = "Day %d  |  %d customer%s left" % [GameState.day, left, "" if left == 1 else "s"]


## "down"/"left"/"right"/"up" for the main direction of vector `v`.
static func _dir_name(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "right" if v.x > 0 else "left"
	return "down" if v.y > 0 else "up"
