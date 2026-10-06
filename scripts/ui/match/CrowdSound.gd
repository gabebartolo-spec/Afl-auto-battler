class_name CrowdSound
extends Node
## FL-004: the crowd at a match you watch (assets/audio/crowd, generated, original).
## A low murmur under everything, a roar for a goal, a lift for a behind and the
## siren at full time - each said once, when the pitch shows it, never when the
## match is skipped through, and never two at once (a roar isn't cut off by a
## behind). Presentation only: muted, the match tells you exactly the same.

const BED_DB := -14.0
const ROAR_DB := -6.0
const LIFT_DB := -9.0
const DIR := "res://assets/audio/crowd/"

var _bed: AudioStreamPlayer
var _cue: AudioStreamPlayer
var _siren_done := false


func _ready() -> void:
	_bed = _player(BED_DB)
	_cue = _player(0.0)
	var bed := load(DIR + "crowd_bed.wav") as AudioStreamWAV
	if bed != null:
		bed = bed.duplicate() as AudioStreamWAV
		bed.loop_mode = AudioStreamWAV.LOOP_FORWARD
		bed.loop_begin = 0
		bed.loop_end = int(bed.get_length() * bed.mix_rate)
		_bed.stream = bed
		_bed.play()


func _player(db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = AudioLevels.bus(AudioLevels.CROWD)
	p.volume_db = db
	add_child(p)
	return p


## A football event as the pitch shows it: "goal" or "behind".
func event(kind: String) -> void:
	if kind == "goal":
		_play("crowd_goal.wav", ROAR_DB, true)
	elif kind == "behind":
		_play("crowd_behind.wav", LIFT_DB, false)


## Full time: the siren, once.
func full_time() -> void:
	if _siren_done:
		return
	_siren_done = true
	_play("crowd_siren.wav", ROAR_DB, true)


## What's playing now (tests): the cue's file, or "".
func cue() -> String:
	return _cue.stream.resource_path.get_file() if _cue.playing and _cue.stream != null else ""


func _play(file: String, db: float, over: bool) -> void:
	if _cue.playing and not over:
		return     # let the roar finish
	var s := load(DIR + file) as AudioStream
	if s == null:
		return
	_cue.stream = s
	_cue.volume_db = db
	_cue.play()
