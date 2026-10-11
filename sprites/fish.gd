extends Area2D
## A fish for the seal mini-game. Swims slowly left or right, turns around now
## and then (and at the edge of `bounds`), and plays "collect" then disappears
## when the seal's collision box touches it. The art faces right.

signal caught(fish: Node)

@export var speed := 25.0
@export var min_turn_time := 1.5
@export var max_turn_time := 4.0

## Area the fish stays inside (set by the spawner; empty = no limit).
var bounds := Rect2()
var is_caught := false
var dir := 1.0
var _turn_in := 0.0
var _t := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	dir = [-1.0, 1.0].pick_random()
	_turn_in = randf_range(min_turn_time, max_turn_time)
	_t = randf() * TAU
	body_entered.connect(_on_body_entered)
	sprite.play("swim")
	sprite.flip_h = dir < 0


func _physics_process(delta: float) -> void:
	if is_caught:
		return
	position.x += dir * speed * delta
	_t += delta
	sprite.position.y = sin(_t * 3.0) * 0.5   # gentle bob
	_turn_in -= delta
	var hit_edge := bounds.has_area() and (
		(dir < 0 and position.x < bounds.position.x) or (dir > 0 and position.x > bounds.end.x))
	if _turn_in <= 0.0 or hit_edge:
		dir = -dir
		_turn_in = randf_range(min_turn_time, max_turn_time)
	sprite.flip_h = dir < 0


func _on_body_entered(body: Node) -> void:
	if is_caught or not body is CharacterBody2D:   # only the seal is a body in the sea
		return
	is_caught = true
	set_deferred("monitoring", false)
	caught.emit(self)
	sprite.play("collect")
	var frames := sprite.sprite_frames
	var length := frames.get_frame_count("collect") / maxf(frames.get_animation_speed("collect"), 0.01)
	get_tree().create_timer(length).timeout.connect(queue_free)
