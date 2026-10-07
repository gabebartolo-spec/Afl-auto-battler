class_name StatsTrophies
extends RefCounted
## Season stats > trophies.


static func build(_host: Control) -> Control:
	var v := UiKit.vbox(8)
	v.name = "StatsTrophies"
	return v
