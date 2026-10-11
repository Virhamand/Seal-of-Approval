extends Node2D
## Running_restaurant: the chef can move, the seal can't, and customers
## stroll out of the centre of the screen one at a time.

const CUSTOMER := preload("res://scenes/customer.tscn")
const WALK_TIME := 3.0      # seconds before a customer is deleted
const WALK_SPEED := 40.0    # pixels per second
const DIRS := {"down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT, "up": Vector2.UP}

@onready var chef: CharacterBody2D = $chef
@onready var seal: CharacterBody2D = $seal

var current_customer: Node2D = null
var _spawning := false


func enter_state(_s: GameState.State) -> void:
	chef.can_move = true
	seal.can_move = false
	if not _spawning:
		_spawning = true
		_spawn_customer()


func _spawn_customer() -> void:
	var c: Node2D = CUSTOMER.instantiate()
	c.scale = Vector2(2, 2)   # match the chef
	c.position = get_viewport_rect().size / 2
	add_child(c)
	var dir_name: String = DIRS.keys().pick_random()
	(c.get_node("Customer") as AnimatedSprite2D).play("walk_" + dir_name)
	current_customer = c
	# Walk for WALK_TIME seconds, delete, then send the next one.
	var t := create_tween()
	t.tween_property(c, "position", c.position + DIRS[dir_name] * WALK_SPEED * WALK_TIME, WALK_TIME)
	t.tween_callback(c.queue_free)
	t.tween_callback(_spawn_customer)
