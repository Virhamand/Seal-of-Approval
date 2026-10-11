extends Node2D
## The beach.
##   Walking_on_Beach: only the chef, who can walk around.
##   Talking_to_Seal: the seal appears next to the chef and both are frozen.

const CHEF := preload("res://sprites/chef.tscn")
const SEAL := preload("res://sprites/seal.tscn")

@export var chef_start := Vector2(560, 300)
@export var seal_offset := Vector2(56, 0)   # where the seal appears relative to the chef

## Remembered across visits so the chef is where you left him after the mini-game.
static var _last_chef_position := Vector2.INF

var chef: CharacterBody2D
var seal: CharacterBody2D = null
var camera := Camera2D.new()


func _ready() -> void:
	chef = CHEF.instantiate()
	chef.position = chef_start if _last_chef_position == Vector2.INF else _last_chef_position
	add_child(chef)
	tree_exiting.connect(func(): _last_chef_position = chef.position)
	_setup_camera()


func enter_state(s: GameState.State) -> void:
	match s:
		GameState.State.WALKING_ON_BEACH:
			_remove_seal()
			chef.can_move = true
			chef.face("down")   # player in control: start facing down
		GameState.State.TALKING_TO_SEAL:
			chef.can_move = false
			_spawn_seal()
			# face each other
			chef.face(dir_name(seal.position - chef.position))
			seal.face(dir_name(chef.position - seal.position))


func _spawn_seal() -> void:
	if seal:
		return
	seal = SEAL.instantiate()
	seal.can_move = false
	seal.position = chef.position + seal_offset
	add_child(seal)


## "down"/"left"/"right"/"up" for the main direction of vector `v`.
static func dir_name(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "right" if v.x > 0 else "left"
	return "down" if v.y > 0 else "up"


func _remove_seal() -> void:
	if seal:
		seal.queue_free()
		seal = null


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


func _process(_delta: float) -> void:
	camera.position = chef.position
