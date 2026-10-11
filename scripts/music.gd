extends Node
## Background music (autoload: Music). One track per part of the game, looped,
## on the "Music" bus so the Settings slider controls it.
##   Music.play("interior")   # switch tracks (does nothing if it's already playing)
##   Music.stop()

const TRACKS := {
	"main_menu": "res://assets/sounds/main_menu_music.mp3",
	"interior": "res://assets/sounds/interior_music.mp3",
	"seaside": "res://assets/sounds/seaside_music.wav",
	"seal_mini_game": "res://assets/sounds/seal_mini_game_music.wav",
	"ending": "res://assets/sounds/ending_music.mp3",
}

var player := AudioStreamPlayer.new()
var current := ""


func _ready() -> void:
	player.bus = Settings.MUSIC_BUS
	add_child(player)


## The track for a game state.
static func track_for(state: GameState.State) -> String:
	match state:
		GameState.State.RUNNING_RESTAURANT:
			return "interior"
		GameState.State.SEAL_MINI_GAME:
			return "seal_mini_game"
	return "seaside"   # the beach: walking and talking to the seal


func play(track: String) -> void:
	if track == current and player.playing:
		return
	current = track
	var stream: AudioStream = load(TRACKS[track]).duplicate()
	if stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	player.stream = stream
	player.play()


func stop() -> void:
	current = ""
	player.stop()
