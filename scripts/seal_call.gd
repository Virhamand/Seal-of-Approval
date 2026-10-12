extends Node
## The seal's call from the shore (autoload: SealCall).
##
## From day 2, once the restaurant has served everyone (GameState.end_service()),
## the seal calls on loop until the player interacts with it. Inside the
## restaurant it sounds muffled; on the beach it gets louder and clearer as the
## chef walks towards the seal. wah() plays the short first bit of the call.

const SOUND := preload("res://assets/sounds/harbor-seal-in-air.mp3")
const BELLY_SLAP := preload("res://assets/sounds/seal-belly-slap.mp3")
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
## Belly slaps, on loop while the seal congratulates the chef.
var slap_player := AudioStreamPlayer.new()
## The low-pass filter on the "SealCall" bus (default_bus_layout.tres, made in
## the editor: buses created from code are silent in the web export).
var _filter: AudioEffectLowPassFilter


func _ready() -> void:
	var idx := AudioServer.get_bus_index(BUS)
	if idx != -1 and AudioServer.get_bus_effect_count(idx) > 0:
		_filter = AudioServer.get_bus_effect(idx, 0) as AudioEffectLowPassFilter
	if _filter == null:
		push_error("SealCall: bus '%s' with a LowPassFilter is missing from default_bus_layout.tres" % BUS)
		_filter = AudioEffectLowPassFilter.new()   # unused, keeps _apply() safe

	var looped: AudioStreamMP3 = SOUND.duplicate()
	looped.loop = true
	call_player.stream = looped
	call_player.bus = BUS
	add_child(call_player)

	var once: AudioStreamMP3 = SOUND.duplicate()
	once.loop = false
	wah_player.stream = once
	wah_player.bus = Settings.SFX_BUS
	add_child(wah_player)

	var slap: AudioStreamMP3 = BELLY_SLAP.duplicate()
	slap.loop = true
	slap_player.stream = slap
	slap_player.bus = Settings.SFX_BUS
	add_child(slap_player)


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


## Start/stop the looping belly-slap sound (played with the "belly_slap" animation).
func belly_slap(on: bool) -> void:
	if on and not slap_player.playing:
		slap_player.play()
	elif not on and slap_player.playing:
		slap_player.stop()


func is_calling() -> bool:
	return call_player.playing
