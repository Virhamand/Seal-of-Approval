extends CharacterBody2D

@export var speed := 140.0
## When false the seal ignores input and stands still. Set by the current game state.
@export var can_move := true
## Movement animations use "swim_" in the sea mini-game, "galumph_" on land.
@export var swim_mode := false
## When false, the seal stops picking idle/move animations by itself so a
## cutscene can play "fall"/"die" without being overwritten.
@export var auto_animate := true
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var facing := "down"


## Turn to `dir` ("down", "left", "right", "up") and show the right still pose:
## idle on land, swimming in the sea. Called by the level whenever the state changes.
func face(dir: String) -> void:
	facing = dir
	velocity = Vector2.ZERO
	sprite.play(("swim_" if swim_mode else "idle_") + facing)

func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("left", "right", "up", "down") if can_move else Vector2.ZERO
	velocity = dir * speed
	move_and_slide()
	
	if not auto_animate:
		return
	if dir != Vector2.ZERO:
		if abs(dir.x) > abs(dir.y):
			facing = "right" if dir.x > 0 else "left"
		else:
			facing = "down" if dir.y > 0 else "up"
		sprite.play(("swim_" if swim_mode else "galumph_") + facing)
	# don't play idle while swimming (keep the swim animation going in the water)
	elif not swim_mode:
		sprite.play("idle_" + facing)
