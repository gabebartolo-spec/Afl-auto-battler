class_name MarqueeGames
extends RefCounted
## Recurring AFL fixture traditions. These are presentation/scheduling facts,
## never MatchSim bonuses. Future careers preserve the tradition without
## inventing calendar dates the current season model does not track.

const TRADITIONS := [
	{"home": "ESS", "away": "COL", "name": "ANZAC Day"},
	{"home": "RIC", "away": "MEL", "name": "ANZAC Eve"},
	{"home": "RIC", "away": "ESS", "name": "Dreamtime at the 'G"},
	{"home": "MEL", "away": "COL", "name": "King's Birthday"},
	{"home": "ESS", "away": "CAR", "name": "King's Birthday Eve"},
	{"home": "HAW", "away": "GEE", "name": "Easter Monday"},
]


static func tradition(a: String, b: String) -> Dictionary:
	for item in TRADITIONS:
		if (str(item["home"]) == a and str(item["away"]) == b) or (str(item["home"]) == b and str(item["away"]) == a):
			return item.duplicate()
	return {}


static func label(a: String, b: String) -> String:
	return str(tradition(a, b).get("name", ""))
