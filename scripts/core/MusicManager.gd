extends Node
## Persistent, deliberately quiet menu music. The playlist continues across
## management screens and pauses for MatchScene so match audio can stand alone.

const TRACKS := [
	preload("res://assets/audio/music/hub_after_hours.wav"),
	preload("res://assets/audio/music/draft_room_rain.wav"),
	preload("res://assets/audio/music/long_season.wav"),
	preload("res://assets/audio/music/matchday_morning.wav"),
]
const MUSIC_DB := -18.0

var _player: AudioStreamPlayer
var _next_track := 0
var _paused_for_match := false


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "BackgroundMusic"
	_player.volume_db = MUSIC_DB
	_player.bus = "Master"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_player.finished.connect(_on_finished)
	call_deferred("_play_next")


## Router tells us where the game is going. MatchScene stays silent; returning
## to any management screen resumes the exact track rather than restarting it.
func set_context(context: String) -> void:
	var pause := context == "match" or context.ends_with("MatchScene.tscn")
	if pause == _paused_for_match:
		return
	_paused_for_match = pause
	if not is_instance_valid(_player):
		return
	if pause:
		if _player.playing:
			_player.stream_paused = true
	else:
		if _player.stream_paused:
			_player.stream_paused = false
		elif not _player.playing:
			_play_next()


func _on_finished() -> void:
	if not _paused_for_match:
		_play_next()


func _play_next() -> void:
	if _paused_for_match or not is_instance_valid(_player) or TRACKS.is_empty():
		return
	_player.stream = TRACKS[_next_track]
	_next_track = (_next_track + 1) % TRACKS.size()
	_player.play()
