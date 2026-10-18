extends Node
## Persistent, deliberately quiet menu music. The playlist continues across
## management screens and pauses for MatchScene so match audio can stand alone.

## Empty on purpose: the generated tracks were removed 2026-10-18; see assets/audio/music/README.md.
const TRACK_PATHS: Array[String] = []
const MUSIC_DB := -18.0

var _player: AudioStreamPlayer
var _tracks: Array[AudioStream] = []
var _next_track := 0
var _paused_for_match := false


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "BackgroundMusic"
	_player.volume_db = MUSIC_DB
	_player.bus = AudioLevels.bus(AudioLevels.MUSIC)
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_player.finished.connect(_on_finished)
	_load_tracks()
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
	if _paused_for_match or not is_instance_valid(_player) or _tracks.is_empty():
		return
	_player.stream = _tracks[_next_track]
	_next_track = (_next_track + 1) % _tracks.size()
	_player.play()


func _load_tracks() -> void:
	_tracks.clear()
	for path in TRACK_PATHS:
		var stream := load(path) as AudioStream
		if stream != null:
			_tracks.append(stream)
