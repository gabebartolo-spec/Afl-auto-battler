class_name Rivalries
extends RefCounted
## Established club rivalries. Presentation/history only: being a rivalry
## never changes ratings, MatchSim odds or player attributes.
##
## Uneven counts are deliberate. A club can have several genuine rivals;
## this is not a pairing system and marquee fixtures are a separate concept.

const ESTABLISHED := [
	["COL", "CAR", "Collingwood–Carlton"],
	["ADE", "PAD", "Showdown"],
	["HAW", "GEE", "Hawthorn–Geelong"],
	["FRE", "WCE", "Western Derby"],
	["ESS", "COL", "Essendon–Collingwood"],
	["RIC", "CAR", "Richmond–Carlton"],
	["SYD", "GWS", "Sydney Derby"],
	["BRL", "GCS", "QClash"],
	["MEL", "COL", "Melbourne–Collingwood"],
	["WBD", "COL", "Western Bulldogs–Collingwood"],
	["PAD", "COL", "Port Adelaide–Collingwood"],
]


static func established(a: String, b: String) -> Dictionary:
	for row in ESTABLISHED:
		if (str(row[0]) == a and str(row[1]) == b) or (str(row[0]) == b and str(row[1]) == a):
			return {"clubs": [str(row[0]), str(row[1])], "name": str(row[2])}
	return {}


static func are_rivals(a: String, b: String) -> bool:
	return not established(a, b).is_empty()


static func label(a: String, b: String) -> String:
	return str(established(a, b).get("name", ""))
