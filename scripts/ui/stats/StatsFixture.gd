class_name StatsFixture
extends RefCounted
## Season stats > fixture.


static func build(_host: Control) -> Control:
	var v := UiKit.vbox(8)
	v.name = "StatsFixture"
	return v
