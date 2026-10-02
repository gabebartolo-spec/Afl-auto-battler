extends Node
## Persistent low-key background music for management screens.
##
## The playlist is intentionally shuffled rather than tied to individual
## screens so navigation does not constantly restart or switch music.
## Live matches pause the current track and resume it afterwards.

const DEFAULT_VOLUME_DB := -20.0
const TRACK_PATHS: Array[String] = [
	"res://assets/audio/music/hub_after_hours.wav",
	"res://assets/audio/music/draft_room_rain.wav",
	"res://assets/audio/music/long_season.wav",
	"res://assets/audio/music/matchday_morning.wav",
]

var _player: AudioStreamPlayer
var _tracks: Array[AudioStream] = []
var _bag: Array[AudioStream] = []
var _last_track: AudioStream
var _paused_for_match := false


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "BackgroundMusic"
	_player.volume_db = DEFAULT_VOLUME_DB
	add_child(_player)
	_player.finished.connect(_on_track_finished)
	_load_tracks()
	_refill_bag()
	_play_next()


func set_route(route: String) -> void:
	_paused_for_match = route.ends_with("/MatchScene.tscn")
	if _player == null:
		return
	if _paused_for_match:
		_player.stream_paused = true
		return
	if _player.stream == null:
		_play_next()
	else:
		_player.stream_paused = false


func set_music_enabled(enabled: bool) -> void:
	if _player == null:
		return
	_player.volume_db = DEFAULT_VOLUME_DB if enabled else -80.0


func _on_track_finished() -> void:
	_play_next()


func _play_next() -> void:
	if _bag.is_empty():
		_refill_bag()
	if _bag.is_empty():
		return

	var track: AudioStream = _bag.pop_front()
	_last_track = track
	_player.stream = track
	_player.play()
	if _paused_for_match:
		_player.stream_paused = true


func _load_tracks() -> void:
	_tracks.clear()
	for path in TRACK_PATHS:
		var stream := load(path) as AudioStream
		if stream != null:
			_tracks.append(stream)


func _refill_bag() -> void:
	_bag = _tracks.duplicate()
	_bag.shuffle()
	if _last_track != null and _bag.size() > 1 and _bag[0] == _last_track:
		_bag.push_back(_bag.pop_front())
