class_name AudioLevels
extends RefCounted
## FL-004: two levels the player sets - music, and the crowd at the football -
## each on its own bus under Master, so "Mute sounds" still silences everything.
## Off, quiet or normal: a choice a player makes once, not a mixing desk.

const MUSIC := "Music"
const CROWD := "Crowd"
const LEVELS := [["off", "Off"], ["quiet", "Quiet"], ["normal", "Normal"]]
const QUIET_DB := -10.0


## The bus, made under Master if it isn't there yet.
static func bus(name: String) -> String:
	if AudioServer.get_bus_index(name) < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, name)
		AudioServer.set_bus_send(i, "Master")
	return name


static func apply(name: String, level: String) -> void:
	var i := AudioServer.get_bus_index(bus(name))
	AudioServer.set_bus_mute(i, level == "off")
	AudioServer.set_bus_volume_db(i, QUIET_DB if level == "quiet" else 0.0)


static func valid(level: String) -> String:
	return level if level in ["off", "quiet", "normal"] else "normal"
