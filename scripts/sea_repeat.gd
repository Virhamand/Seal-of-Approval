extends Node2D
## Seal_mini_game: only the seal is here and it swims (movement animations use
## "swim_"). Fish swim around; catch FISH_GOAL of them before the timer runs
## out to win a recipe. Either way the game goes back to Talking_to_Seal.

const SEAL := preload("res://sprites/seal.tscn")
const FISH := preload("res://sprites/fish.tscn")

const FISH_GOAL := 10          # fish needed to finish (shown as 0/10)
const MAX_FISH := 3            # fish in the sea at once
const FISH_SCALE := 2.0        # seal is 4x, fish 2x
const EDGE_MARGIN := 24.0      # keep spawns away from the screen / map edge
const MIN_SEAL_DISTANCE := 56.0
const END_DELAY := 0.8         # seconds to enjoy the full bar before leaving
const TIME_LIMIT := 30.0       # seconds to catch every fish

var seal: CharacterBody2D
var camera := Camera2D.new()
var bounds := Rect2()
var caught := 0
var finished := false
var time_left := TIME_LIMIT
## False while the first-time tutorial is showing: timer, fish and seal wait.
var started := true
var _tutorial: CanvasLayer
var _tutorial_ready := false

var _bar: ProgressBar
var _count: Label
var _timer_label: Label


func _ready() -> void:
	var ground: TileMapLayer = $Ground
	var r := ground.get_used_rect()
	var cell := Vector2(ground.tile_set.tile_size) * ground.scale
	bounds = Rect2(Vector2(r.position) * cell, Vector2(r.size) * cell)
	seal = SEAL.instantiate()
	seal.swim_mode = true
	seal.position = bounds.get_center()
	add_child(seal)
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)
	camera.position = seal.position
	add_child(camera)
	camera.make_current()
	_build_hud()


func enter_state(_s: GameState.State) -> void:
	seal.swim_mode = true
	if not GameState.tutorial_seen:
		_show_tutorial()
	seal.can_move = started and not finished
	seal.face("down")   # player in control: start facing down


func _process(delta: float) -> void:
	if finished or not started:
		return
	time_left = maxf(time_left - delta, 0.0)
	_update_timer()
	if time_left <= 0.0:
		_end(false)


func _physics_process(_delta: float) -> void:
	# keep the seal inside the water and the camera on it
	seal.position = seal.position.clamp(bounds.position + Vector2(32, 32), bounds.end - Vector2(32, 32))
	camera.position = seal.position
	_ensure_fish()


## Keep MAX_FISH fish in the sea and at least one of them on screen.
func _ensure_fish() -> void:
	if finished or not started:
		return
	var alive := live_fish()
	# A fish near the screen edge may scroll out next frame, so only count
	# fish comfortably inside the view.
	if not _any_in_view(alive, EDGE_MARGIN):
		# Always keep at least one fish on screen: recycle the farthest one if we're full.
		if alive.size() >= MAX_FISH:
			_farthest_from_seal(alive).queue_free()
		_spawn(view_rect().grow(-EDGE_MARGIN))
	elif alive.size() < MAX_FISH:
		_spawn(bounds.grow(-EDGE_MARGIN))


# ---------------------------------------------------------------- fish
func live_fish() -> Array:
	var out := []
	for c in get_children():
		if c is Area2D and not c.is_queued_for_deletion() and not c.is_caught:
			out.append(c)
	return out


## The part of the sea currently visible on screen.
func view_rect() -> Rect2:
	var size := get_viewport_rect().size / camera.zoom
	return Rect2(camera.get_screen_center_position() - size / 2, size)


func _any_in_view(fish: Array, margin := 8.0) -> bool:
	var v := view_rect().grow(-margin)
	for f in fish:
		if v.has_point(f.position):
			return true
	return false


func _farthest_from_seal(fish: Array) -> Node2D:
	var best: Node2D = fish[0]
	for f in fish:
		if f.position.distance_to(seal.position) > best.position.distance_to(seal.position):
			best = f
	return best


func _spawn(area: Rect2) -> void:
	area = area.intersection(bounds.grow(-EDGE_MARGIN))
	var p := area.get_center()
	for i in 12:   # try to avoid spawning right on top of the seal
		p = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
		if p.distance_to(seal.position) >= MIN_SEAL_DISTANCE:
			break
	var f: Area2D = FISH.instantiate()
	f.scale = Vector2(FISH_SCALE, FISH_SCALE)
	f.position = p
	f.bounds = bounds.grow(-EDGE_MARGIN)
	f.caught.connect(_on_fish_caught)
	add_child(f)


func _on_fish_caught(_fish: Node) -> void:
	if finished:
		return
	caught = mini(caught + 1, FISH_GOAL)
	_update_hud()
	_ensure_fish.call_deferred()   # replace it straight away so the screen is never empty
	if caught >= FISH_GOAL:
		_end(true)


## Stop the round, pause briefly on the final HUD, then report the result.
func _end(won: bool) -> void:
	if finished:
		return
	finished = true
	seal.can_move = false
	get_tree().create_timer(END_DELAY).timeout.connect(_report.bind(won))


func _report(won: bool) -> void:
	if GameState.state == GameState.State.SEAL_MINI_GAME:
		GameState.end_mini_game(won)


# ---------------------------------------------------------------- HUD
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := CenterContainer.new()
	top.theme = UiTheme.theme
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 6
	layer.add_child(top)
	var panel := PanelContainer.new()
	top.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var title := Label.new()
	title.text = "Fish"
	row.add_child(title)
	_bar = ProgressBar.new()
	_bar.max_value = FISH_GOAL
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(140, 12)
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_bar)
	_count = Label.new()
	_count.custom_minimum_size.x = 36
	row.add_child(_count)
	_update_hud()

	# timer, top-right corner
	var corner := MarginContainer.new()
	corner.theme = UiTheme.theme
	corner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.offset_top = 6
	corner.offset_right = -6
	layer.add_child(corner)
	var timer_panel := PanelContainer.new()
	corner.add_child(timer_panel)
	_timer_label = Label.new()
	_timer_label.custom_minimum_size.x = 40
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_panel.add_child(_timer_label)
	_update_timer()


func _update_hud() -> void:
	_bar.value = caught
	_count.text = "%d/%d" % [caught, FISH_GOAL]


# ---------------------------------------------------------------- tutorial
## First mini-game only: how to play. Everything waits until it is dismissed.
func _show_tutorial() -> void:
	started = false
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
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var lines := [
		["Catch the fish!", UiTheme.title_font_size],
		["Move with WASD or the arrow keys.", 0],
		["Catch %d fish in %d seconds." % [FISH_GOAL, int(TIME_LIMIT)], 0],
		["Click or press any key to start", 0],
	]
	for l in lines:
		var label := Label.new()
		label.text = l[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if l[1]:
			label.add_theme_font_size_override("font_size", l[1])
		box.add_child(label)
	get_tree().create_timer(0.4).timeout.connect(func(): _tutorial_ready = true)


func _unhandled_input(event: InputEvent) -> void:
	if started or not _tutorial_ready:
		return
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	var click: bool = event is InputEventMouseButton and event.pressed
	if key or click:
		get_viewport().set_input_as_handled()
		GameState.tutorial_seen = true
		_tutorial.queue_free()
		started = true
		seal.can_move = true


func _update_timer() -> void:
	var secs := int(ceil(time_left))
	_timer_label.text = "%d:%02d" % [secs / 60, secs % 60]
