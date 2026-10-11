extends Node
## The seal's call from the shore (autoload: SealCall).
##
## From day 2, once the restaurant has served everyone (GameState.end_service()),
## the seal calls on loop until the player interacts with it. Inside the
## restaurant it sounds muffled; on the beach it gets louder and clearer as the
## chef walks towards the seal. wah() plays the short first bit of the call.

const SOUND := preload("res://assets/sounds/harbor-seal-in-air.mp3")
const BUS := "SealCall"

## Short "wah" = the first WAH_LENGTH seconds of the sound.
@export var wah_length := 0.58
## Muffled sound heard from inside the restaurant.
@export var restaurant_volume_db := -16.0
@export var restaurant_cutoff_hz := 500.0
## On the beach: quiet + muffled at far_distance, full and clear at near_distance (pixels).
@export var far_distance := 700.0
@export var near_distance := 80.0
@export var far_volume_db := -20.0
@export var near_volume_db := 0.0
@export var far_cutoff_hz := 700.0
@export var near_cutoff_hz := 20000.0

var call_player := AudioStreamPlayer.new()
var wah_player := AudioStreamPlayer.new()
var _filter := AudioEffectLowPassFilter.new()


func _ready() -> void:
	# a bus with a low-pass filter so the call can be muffled
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, BUS)
	AudioServer.set_bus_send(idx, "Master")
	AudioServer.add_bus_effect(idx, _filter)

	var looped: AudioStreamMP3 = SOUND.duplicate()
	looped.loop = true
	call_player.stream = looped
	call_player.bus = BUS
	add_child(call_player)

	var once: AudioStreamMP3 = SOUND.duplicate()
	once.loop = false
	wah_player.stream = once
	add_child(wah_player)


func _process(_delta: float) -> void:
	var want := GameState.seal_calling() and GameState.state != GameState.State.SEAL_MINI_GAME
	if want and not call_player.playing:
		call_player.play()
	elif not want and call_player.playing:
		call_player.stop()
	if not want:
		return
	if GameState.state == GameState.State.RUNNING_RESTAURANT:
		_apply(restaurant_volume_db, restaurant_cutoff_hz)
		return
	var beach := get_tree().get_first_node_in_group("beach")
	if beach == null:
		_apply(far_volume_db, far_cutoff_hz)
		return
	var d: float = beach.chef.global_position.distance_to(beach.seal.global_position)
	var t := clampf(inverse_lerp(far_distance, near_distance, d), 0.0, 1.0)
	_apply(lerpf(far_volume_db, near_volume_db, t), lerpf(far_cutoff_hz, near_cutoff_hz, t * t))


func _apply(volume_db: float, cutoff_hz: float) -> void:
	call_player.volume_db = volume_db
	_filter.cutoff_hz = cutoff_hz


## The seal's short "wah" when you start playing with it.
func wah() -> void:
	wah_player.play(0.0)
	get_tree().create_timer(wah_length).timeout.connect(wah_player.stop)


func is_calling() -> bool:
	return call_player.playing
