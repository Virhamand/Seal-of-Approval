extends Node
## Volume settings (autoload: Settings).
##
## The "Music" and "SFX" buses live in default_bus_layout.tres (made in the
## editor: buses created from code are silent in the web export). Put music
## players on bus "Music" and sound effects on bus "SFX" (Settings.MUSIC_BUS /
## SFX_BUS). Volumes go from 0 to 1 and are saved to user://settings.cfg.

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const SAVE_PATH := "user://settings.cfg"

var music_volume := 1.0
var sfx_volume := 1.0


func _ready() -> void:
	for b in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(b) == -1:
			push_error("Settings: audio bus '%s' is missing from default_bus_layout.tres" % b)
	_load()
	_apply()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply()
	_save()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply()
	_save()


func _apply() -> void:
	_set_bus(MUSIC_BUS, music_volume)
	_set_bus(SFX_BUS, sfx_volume)


func _set_bus(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i == -1:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(i, v <= 0.0)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		music_volume = clampf(cfg.get_value("audio", "music", 1.0), 0.0, 1.0)
		sfx_volume = clampf(cfg.get_value("audio", "sfx", 1.0), 0.0, 1.0)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(SAVE_PATH)
