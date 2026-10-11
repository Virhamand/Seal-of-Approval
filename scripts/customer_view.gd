extends Node2D
## Preview: one random customer per animation, two rows. Press Space/Enter to re-roll.

const ANIMS := ["idle_down", "walk_down", "walk_left", "walk_right", "walk_up",
		"sit_down", "eat_down", "wave", "happy"]

var crowd := Node2D.new()

func _ready() -> void:
	add_child(crowd)
	var cam := Camera2D.new()
	cam.zoom = Vector2(4, 4)          # 16 px sprites are tiny at 1x
	cam.position = Vector2(108, 24)
	add_child(cam)
	spawn()

func spawn() -> void:
	for c in crowd.get_children():
		c.queue_free()
	for row in 2:
		for i in ANIMS.size():
			var c := Customer.new()
			c.position = Vector2(12 + i * 24, 12 + row * 24)
			crowd.add_child(c)
			c.play(ANIMS[i])

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		spawn()
