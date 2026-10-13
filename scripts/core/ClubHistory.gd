class_name ClubHistory
extends RefCounted
## A club's real premierships before the career starts (the trophy room's
## "Before you"), read from data/club_premierships.csv:
##
##   code,year,competition,source
##   GEE,1925,VFL,https://...
##
## One row per flag: the club's code, the year, VFL or AFL, and the page the
## year was taken from. A row with a code and a source but no year says the
## club is confirmed to have won none. A club that is not in the file at all
## is simply not on record yet: the trophy room shows nothing for it rather
## than guess. Clubs that were never in the league before the career
## (Tasmania, Canberra, a Club Forge club) have none by definition.

const PATH := "res://data/club_premierships.csv"

static var _rows = null


## Forget the cached file (tests).
static func reload() -> void:
	_rows = null


## Replace the table (tests): code -> {"years": [...], "comps": {}, "none": bool}.
static func use(rows: Dictionary) -> void:
	_rows = rows


## code -> {"years": [int, ...] oldest first, "comps": {year: "VFL"/"AFL"}, "none": bool}
static func table() -> Dictionary:
	if _rows == null:
		_rows = _parse(PATH)
	return _rows


static func _parse(path: String) -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(path):
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var first := true
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "":
			continue
		if first:
			first = false
			continue   # the header
		var cells := line.split(",")
		var code := str(cells[0]).strip_edges()
		if code == "":
			continue
		var d: Dictionary = out.get(code, {"years": [], "comps": {}, "none": false})
		var year := str(cells[1]).strip_edges().to_int() if cells.size() > 1 else 0
		if year > 0:
			if not (d["years"] as Array).has(year):
				(d["years"] as Array).append(year)
			(d["comps"] as Dictionary)[year] = str(cells[2]).strip_edges() if cells.size() > 2 else ""
		else:
			d["none"] = true
		out[code] = d
	f.close()
	for code in out:
		(out[code]["years"] as Array).sort()
	return out


## True for a club that was not in the league before the career began: an
## expansion club or one made in Club Forge.
static func is_new_club(code: String) -> bool:
	var c: Dictionary = GameDB.clubs.get(code, {})
	return bool(c.get("custom", false)) or int(c.get("enter", 0)) > GameDB.DATA_SEASON


## What is on record for a club before the career: {"known": bool, "years": []}.
## `known` is false when the file has nothing for a real club yet.
static func before_career(code: String) -> Dictionary:
	if is_new_club(code):
		return {"known": true, "years": []}
	var d: Dictionary = table().get(code, {})
	if d.is_empty():
		return {"known": false, "years": []}
	var years: Array = (d["years"] as Array).duplicate()
	return {"known": not years.is_empty() or bool(d["none"]), "years": years}
