extends CharacterBody2D

@export var speed := 60.0
## When false the chef ignores input and stands still. Set by the current game state.
@export var can_move := true
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var facing := "down"


## Turn to `dir` ("down", "left", "right", "up") and show the standing pose.
## Called by the level whenever the game state changes.
func face(dir: String) -> void:
	facing = dir
	velocity = Vector2.ZERO
	sprite.play("idle_" + facing)

func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("left", "right", "up", "down") if can_move else Vector2.ZERO
	velocity = dir * speed
	move_and_slide()
	
	if dir != Vector2.ZERO:
		if abs(dir.x) > abs(dir.y):
			facing = "right" if dir.x > 0 else "left"
		else:
			facing = "down" if dir.y > 0 else "up"
		sprite.play("walk_" + facing)
	else:
		sprite.play("idle_" + facing)
