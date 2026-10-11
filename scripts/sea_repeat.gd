extends Node2D
## Seal_mini_game: only the seal is here, it can move, and it swims
## (movement animations use "swim_" instead of "galumph_").

const SEAL := preload("res://sprites/seal.tscn")

var seal: CharacterBody2D
var camera := Camera2D.new()
var bounds := Rect2()


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
	add_child(camera)
	camera.make_current()


func enter_state(_s: GameState.State) -> void:
	seal.swim_mode = true
	seal.can_move = true


func _process(_delta: float) -> void:
	# keep the seal inside the water
	seal.position = seal.position.clamp(bounds.position + Vector2(32, 32), bounds.end - Vector2(32, 32))
	camera.position = seal.position
