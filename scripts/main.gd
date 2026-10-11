extends Node2D
## The beach.
##   Walking_on_Beach: the chef walks around. The seal lives on the bottom shore.
##   Talking_to_Seal: chef and seal are frozen, facing each other.
##
## Story beats handled here:
##   Day 1: the camera pans to the fainted seal; "[F] Feed" makes it get up and
##          unlocks the first recipe.
##   Days 2+: "[F] Play" starts the mini-game.
##   Rating full: the camera pans to the waiting seal; "[F] Talk" -> congratulations
##          -> The End.
## Interact with the F key ("interact" action) or by clicking the seal.

const CHEF := preload("res://sprites/chef.tscn")
const SEAL := preload("res://sprites/seal.tscn")

@export var chef_start := Vector2(560, 300)
## The restaurant door's Area2D. Walking into it enters the restaurant; coming out
## of the restaurant puts the chef just below it.
@export var door_area_path: NodePath = ^"Sprite2D/Area2D"
## Extra gap between the bottom of the door area and the chef.
@export var door_exit_gap := 10.0
## Where the seal waits. Leave at (0, 0) to place it automatically on the bottom shore.
@export var seal_spot := Vector2.ZERO
## How close the chef must be to interact with the seal.
@export var interact_distance := 72.0
## Camera pan timings (seconds).
@export var pan_time := 1.4
@export var pan_hold := 1.8
## Day 1: how long the seal stares at the chef after getting up, before the recipe pop-up.
@export var stare_time := 1.5

const FEED_TEXT := "[F] Feed malnourished seal Fries and Water"
const PLAY_TEXT := "[F] Play"
const TALK_TEXT := "[F] Talk"
const CONGRATS := [
	"You did it! 100 rating!",
	"The whole shore is talking about your cooking.",
	"Thanks for the fries and water on that first day. Best meal of my life.",
]

var chef: CharacterBody2D
var seal: CharacterBody2D
var camera := Camera2D.new()

var _cutscene := false
var _from_restaurant := false
var _shock: PanelContainer
var _prompt: PanelContainer
var _prompt_label: Label
var _dialogue_layer: CanvasLayer
var _dialogue_label: Label
var _dialogue_lines: Array = []
var _dialogue_index := -1


func _ready() -> void:
	add_to_group("beach")
	_from_restaurant = GameState.state == GameState.State.WALKING_ON_BEACH \
			and GameState.previous_state == GameState.State.RUNNING_RESTAURANT
	chef = CHEF.instantiate()
	var remembered := GameState.beach_chef_position
	var door := _door_exit()
	if _from_restaurant and door != Vector2.INF:
		chef.position = door   # just walked out of the restaurant
	else:
		chef.position = chef_start if remembered == Vector2.INF else remembered
	add_child(chef)
	tree_exiting.connect(func(): GameState.beach_chef_position = chef.position)

	seal = SEAL.instantiate()
	seal.can_move = false
	seal.position = seal_spot if seal_spot != Vector2.ZERO else _auto_seal_spot()
	add_child(seal)
	if GameState.seal_fed:
		seal.face("down")
	elif _from_restaurant:
		_seal_still_standing()   # it collapses once the camera gets there
	else:
		seal.auto_animate = false
		seal.sprite.play("die")

	_build_prompt()
	_setup_camera()
	var door_area := get_node_or_null(door_area_path) as Area2D
	if door_area:
		door_area.body_entered.connect(_on_door_entered)


func enter_state(s: GameState.State) -> void:
	match s:
		GameState.State.WALKING_ON_BEACH:
			_end_dialogue()
			chef.can_move = true
			chef.face("down")   # player in control: start facing down
			if GameState.seal_fed:
				seal.face("down")
			if GameState.previous_state == GameState.State.RUNNING_RESTAURANT and _story_needs_seal():
				if not GameState.seal_fed:
					_shock_then_pan()
				else:
					_pan_to_seal()
		GameState.State.TALKING_TO_SEAL:
			chef.can_move = false
			_prompt.hide()
			chef.face(dir_name(seal.position - chef.position))
			if not GameState.seal_fed:
				_feed_seal()
			else:
				seal.face(dir_name(chef.position - seal.position))
				if GameState.result_pending:
					pass   # the recipe pop-up is shown by the game
				elif GameState.is_rating_full():
					_start_dialogue(CONGRATS)
				else:
					# "[F] Play": a short "wah", then the mini-game
					SealCall.wah()
					get_tree().create_timer(0.8).timeout.connect(_start_mini_game)


## True when the seal is the reason to come to the beach right now.
func _story_needs_seal() -> bool:
	return (not GameState.seal_fed) or (GameState.is_rating_full() and not GameState.ending)


# ---------------------------------------------------------------- interaction
func _process(_delta: float) -> void:
	if not _cutscene:
		camera.position = chef.position
	_update_prompt()


func _update_prompt() -> void:
	var show := GameState.state == GameState.State.WALKING_ON_BEACH and not _cutscene \
			and chef.position.distance_to(seal.position) <= interact_distance
	if show:
		_prompt_label.text = _prompt_text()
		_prompt.reset_size()
		_prompt.position = seal.position + Vector2(-_prompt.size.x / 2, -44 - _prompt.size.y)
	_prompt.visible = show


func _prompt_text() -> String:
	if not GameState.seal_fed:
		return FEED_TEXT
	if GameState.is_rating_full():
		return TALK_TEXT
	return PLAY_TEXT


func _unhandled_input(event: InputEvent) -> void:
	if _dialogue_index >= 0:
		var key: bool = event is InputEventKey and event.pressed and not event.echo
		var click: bool = event is InputEventMouseButton and event.pressed
		if key or click:
			get_viewport().set_input_as_handled()
			_next_dialogue_line()
		return
	if not _prompt.visible:
		return
	var clicked_seal: bool = event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and _seal_rect().has_point((make_input_local(event) as InputEventMouseButton).position)
	if event.is_action_pressed("interact") or clicked_seal:
		get_viewport().set_input_as_handled()
		GameState.go(GameState.State.TALKING_TO_SEAL)


func _seal_rect() -> Rect2:
	var size := Vector2(16, 16) * seal.scale
	return Rect2(seal.position - size / 2, size)


## Walking into the restaurant door goes back to Running_restaurant (same day).
func _on_door_entered(body: Node2D) -> void:
	if body == chef and not _cutscene and GameState.state == GameState.State.WALKING_ON_BEACH:
		GameState.go.call_deferred(GameState.State.RUNNING_RESTAURANT)


func _start_mini_game() -> void:
	if GameState.state == GameState.State.TALKING_TO_SEAL and GameState.can_go(GameState.State.SEAL_MINI_GAME):
		GameState.go(GameState.State.SEAL_MINI_GAME)


# ---------------------------------------------------------------- day-1 seal
func _seal_still_standing() -> void:
	seal.auto_animate = false
	seal.sprite.play("fall")
	seal.sprite.pause()
	seal.sprite.frame = 0


func _play_fainted() -> void:
	seal.auto_animate = false
	seal.sprite.play("fall")
	if not seal.sprite.animation_finished.is_connected(_on_fall_finished):
		seal.sprite.animation_finished.connect(_on_fall_finished)


func _on_fall_finished() -> void:
	if not GameState.seal_fed and seal.sprite.animation == "fall":
		seal.sprite.play("die")   # loops


## Fries and water: the eyes open (fall frame 2), it gets up (fall backwards),
## then idles. Unlocks the first recipe.
func _feed_seal() -> void:
	seal.auto_animate = false
	var spr: AnimatedSprite2D = seal.sprite
	spr.play("fall")
	spr.pause()
	spr.frame = 2   # the frame where its eyes aren't crossed out
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	spr.play_backwards("fall")
	spr.frame = 2
	await spr.animation_finished
	if not is_inside_tree():
		return
	seal.auto_animate = true
	seal.face(dir_name(chef.position - seal.position))
	await get_tree().create_timer(stare_time).timeout   # it just looks at you for a moment
	if not is_inside_tree():
		return
	GameState.feed_seal()


# ---------------------------------------------------------------- camera pan
## Day 1: the chef hops twice in shock with a "!" over his head, then the camera
## pans to the seal, which collapses as the camera arrives.
func _shock_then_pan() -> void:
	_cutscene = true
	chef.can_move = false
	camera.position = _clamped(chef.position)
	await get_tree().create_timer(stare_time).timeout
	if _shock == null:
		_shock = PanelContainer.new()
		_shock.theme = UiTheme.theme
		_shock.z_index = 10
		_shock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mark := Label.new()
		mark.text = "!"
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shock.add_child(mark)
		add_child(_shock)
	_shock.reset_size()
	_shock.position = chef.position + Vector2(-_shock.size.x / 2, -20 - _shock.size.y)
	_shock.show()
	var spr: AnimatedSprite2D = chef.sprite
	var hop := create_tween()
	for i in 2:
		hop.tween_property(spr, "position:y", -5.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hop.tween_property(spr, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	hop.tween_interval(0.35)
	hop.tween_callback(func():
		_shock.hide()
		_pan_to_seal(_play_fainted))


## Pan to the seal, hold, pan back. `on_arrive` runs when the camera reaches the seal.
func _pan_to_seal(on_arrive: Callable = Callable()) -> void:
	_cutscene = true
	chef.can_move = false
	var target := _clamped(seal.position)
	var back := _clamped(chef.position)
	camera.position = back
	var t := create_tween()
	t.tween_property(camera, "position", target, pan_time).set_trans(Tween.TRANS_SINE)
	if on_arrive.is_valid():
		t.tween_callback(on_arrive)
	t.tween_interval(pan_hold)
	t.tween_property(camera, "position", back, pan_time).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func():
		_cutscene = false
		if GameState.state == GameState.State.WALKING_ON_BEACH:
			chef.can_move = true)


## Camera position after limits, so tweens don't "stick" at the map edge.
func _clamped(p: Vector2) -> Vector2:
	var half := get_viewport_rect().size / 2
	return Vector2(
		clampf(p.x, camera.limit_left + half.x, camera.limit_right - half.x),
		clampf(p.y, camera.limit_top + half.y, camera.limit_bottom - half.y))


# ---------------------------------------------------------------- dialogue
func _start_dialogue(lines: Array) -> void:
	_dialogue_lines = lines
	_dialogue_index = -1
	if _dialogue_layer == null:
		_dialogue_layer = CanvasLayer.new()
		_dialogue_layer.layer = 6
		add_child(_dialogue_layer)
		var holder := MarginContainer.new()
		holder.theme = UiTheme.theme
		holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
		for side in ["left", "right", "bottom"]:
			holder.add_theme_constant_override("margin_" + side, 16)
		_dialogue_layer.add_child(holder)
		var panel := PanelContainer.new()
		holder.add_child(panel)
		var box := VBoxContainer.new()
		panel.add_child(box)
		var who := Label.new()
		who.text = "Seal"
		box.add_child(who)
		_dialogue_label = Label.new()
		_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_dialogue_label.custom_minimum_size = Vector2(0, 36)
		box.add_child(_dialogue_label)
		var hint := Label.new()
		hint.text = "Click or press any key"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		box.add_child(hint)
	_dialogue_layer.show()
	_next_dialogue_line()


func _next_dialogue_line() -> void:
	_dialogue_index += 1
	if _dialogue_index >= _dialogue_lines.size():
		_end_dialogue()
		GameState.reach_ending()
		return
	_dialogue_label.text = _dialogue_lines[_dialogue_index]


func _end_dialogue() -> void:
	_dialogue_index = -1
	if _dialogue_layer:
		_dialogue_layer.hide()


# ---------------------------------------------------------------- setup
func _build_prompt() -> void:
	_prompt = PanelContainer.new()
	_prompt.theme = UiTheme.theme
	_prompt.z_index = 10
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_label = Label.new()
	_prompt.add_child(_prompt_label)
	add_child(_prompt)
	_prompt.hide()


## Just below the restaurant door's Area2D (or Vector2.INF if there is no door).
func _door_exit() -> Vector2:
	var area := get_node_or_null(door_area_path) as Area2D
	if area == null:
		return Vector2.INF
	var shape := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null:
		return to_local(area.global_position) + Vector2(0, 24)
	var half_h := 0.0
	if shape.shape is RectangleShape2D:
		half_h = (shape.shape as RectangleShape2D).size.y / 2.0 * absf(shape.global_scale.y)
	# chef's feet: his collision box sits ~8 px below his centre at scale 2
	return to_local(shape.global_position) + Vector2(0, half_h + door_exit_gap + 16)


## Middle of the lowest row of sand on the Ground layer, one tile up from the water.
func _auto_seal_spot() -> Vector2:
	var ground: TileMapLayer = $Ground
	var lowest := -1000000
	var xs: Array[int] = []
	for c in ground.get_used_cells():
		var td := ground.get_cell_tile_data(c)
		if td == null or td.terrain_set != 0 or td.terrain != 0:
			continue
		if c.y > lowest:
			lowest = c.y
			xs = [c.x]
		elif c.y == lowest:
			xs.append(c.x)
	if xs.is_empty():
		return chef_start + Vector2(0, 120)
	xs.sort()
	var cell := Vector2i(xs[xs.size() / 2], lowest - 1)
	return ground.to_global(ground.map_to_local(cell))


func _setup_camera() -> void:
	var ground: TileMapLayer = $Ground
	var r := ground.get_used_rect()
	var cell := Vector2(ground.tile_set.tile_size) * ground.scale
	camera.limit_left = int(r.position.x * cell.x)
	camera.limit_top = int(r.position.y * cell.y)
	camera.limit_right = int(r.end.x * cell.x)
	camera.limit_bottom = int(r.end.y * cell.y)
	camera.position = chef.position
	add_child(camera)
	camera.make_current()


## "down"/"left"/"right"/"up" for the main direction of vector `v`.
static func dir_name(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "right" if v.x > 0 else "left"
	return "down" if v.y > 0 else "up"
