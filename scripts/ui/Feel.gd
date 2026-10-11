class_name Feel
extends RefCounted
## Game feel (director, 2026-10-11): what a finger feels and hears. Footy-real
## sounds (a boot through the ball for a main action, a stud tapping concrete
## for a choice, the siren at the end of a flow, a thump and the crowd when a
## big moment lands) and a light buzz on a phone. UiKit calls this; screens
## never do, so every screen gets it from one place.
##
## Presentation only: nothing here touches a save or the simulation. Each part
## has its own Off in Settings (Button sounds, Vibration, Reduced motion), and
## Mute sounds still silences everything through the Master bus.
## Sounds: assets/audio/feel/, made by tools/audio/build_feel.py.

const DIR := "res://assets/audio/feel/"
## kind -> [file, volume dB]. Modest: under the music, never over the crowd.
const SOUNDS := {
	"main": ["kick_main.wav", -13.0],
	"soft": ["kick_soft.wav", -13.0],
	"tick": ["stud_tick.wav", -11.0],
	"end": ["siren_blip.wav", -9.0],
	"land": ["sting.wav", -10.0],
}
## kind -> [milliseconds, strength 0..1] on a phone.
const BUZZ := {
	"main": [22, 0.45],
	"soft": [16, 0.3],
	"tick": [10, 0.2],
	"end": [30, 0.55],
	"land": [40, 0.8],
}

## The settings, kept here so a tap never reads the settings file
## (GameState writes them at start and on every change).
static var haptics := true
static var reduced := false

## Tests: behave as a phone (the Vibration row shows, a buzz is recorded), and
## let motion run in a headless test run.
static var force_phone := false
static var test_motion := false

## What was asked for since the last clear(), in order: sounds started
## ("main", "tick"...), buzzes given (ms), motions started ("press", "land",
## "attention", "drift"). The proof that an effect ran, or was skipped.
static var heard: Array = []
static var felt: Array = []
static var moved: Array = []

static var _streams := {}


static func clear() -> void:
	heard.clear()
	felt.clear()
	moved.clear()


## A phone that can buzz. A PC has no motor: nothing happens there.
static func phone() -> bool:
	return force_phone or OS.has_feature("mobile")


## A press of `kind`: its sound and its buzz.
static func press(kind: String) -> void:
	sound(kind)
	buzz(kind)


static func sound(kind: String) -> void:
	if not SOUNDS.has(kind):
		return
	# Button sounds Off mutes the bus: start nothing at all.
	var bus := AudioServer.get_bus_index(AudioLevels.bus(AudioLevels.INTERFACE))
	if bus >= 0 and AudioServer.is_bus_mute(bus):
		return
	var p := _player(kind == "land" or kind == "end")
	if p == null:
		return
	var s := _stream(str(SOUNDS[kind][0]))
	if s == null:
		return
	heard.append(kind)
	p.stream = s
	p.volume_db = float(SOUNDS[kind][1])
	p.play()


static func buzz(kind: String) -> void:
	if not haptics or not BUZZ.has(kind) or not phone():
		return
	var ms := int(BUZZ[kind][0])
	felt.append(ms)
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, float(BUZZ[kind][1]))


static func _stream(file: String) -> AudioStream:
	if not _streams.has(file):
		_streams[file] = load(DIR + file) as AudioStream
	return _streams[file]


## Two players kept by the MusicManager autoload, so a sound outlives the
## screen its button left: one for taps (a new tap cuts the last), one for
## moments. (An autoload is never busy building children, unlike the root
## while a scene loads.)
static func _player(moment: bool) -> AudioStreamPlayer:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var keeper: Node = tree.root.get_node_or_null("MusicManager")
	if keeper == null:
		keeper = tree.root
	var host := keeper.get_node_or_null("FeelAudio")
	if host == null:
		host = Node.new()
		host.name = "FeelAudio"
		host.process_mode = Node.PROCESS_MODE_ALWAYS
		for n in ["Tap", "Moment"]:
			var p := AudioStreamPlayer.new()
			p.name = n
			p.bus = AudioLevels.bus(AudioLevels.INTERFACE)
			host.add_child(p)
		keeper.add_child(host)
	return host.get_node("Moment" if moment else "Tap") as AudioStreamPlayer
