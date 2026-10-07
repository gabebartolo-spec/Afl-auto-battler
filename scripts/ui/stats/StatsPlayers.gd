class_name StatsPlayers
extends RefCounted
## Season stats > players.


static func build(_host: Control) -> Control:
	var v := UiKit.vbox(8)
	v.name = "StatsPlayers"
	return v
