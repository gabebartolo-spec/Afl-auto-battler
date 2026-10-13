class_name ClubHistory
extends RefCounted
## A club's real premierships before the career starts (the trophy room's
## "Before you"), read from data/club_premierships.csv:
##
##   code,year,competition,source,as
##   GEE,1925,VFL,https://...,
##   BRL,1898,VFL,https://...,Fitzroy
##
## One row per flag: the club's code, the year, VFL or AFL, the page the
## year was taken from, and `as`: empty for the club's own flags, or the name
## it is shown under ("Fitzroy" for the flags Brisbane carries from the club
## it merged with). No commas inside a field. A row with a code and a source but no year says the
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


## code -> {"years": [int, ...] oldest first (own flags), "comps": {year: "VFL"/"AFL"},
## "also": {label: [years]}, "none": bool}
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
		var label := str(cells[4]).strip_edges() if cells.size() > 4 else ""
		if year > 0 and label != "":
			var also: Dictionary = d["also"]
			if not also.has(label):
				also[label] = []
			if not (also[label] as Array).has(year):
				(also[label] as Array).append(year)
		elif year > 0:
			if not (d["years"] as Array).has(year):
				(d["years"] as Array).append(year)
			(d["comps"] as Dictionary)[year] = str(cells[2]).strip_edges() if cells.size() > 2 else ""
		else:
			d["none"] = true
		out[code] = d
	f.close()
	for code in out:
		(out[code]["years"] as Array).sort()
		for label in out[code]["also"]:
			(out[code]["also"][label] as Array).sort()
	return out


## True for a club that was not in the league before the career began: an
## expansion club or one made in Club Forge.
static func is_new_club(code: String) -> bool:
	var c: Dictionary = GameDB.clubs.get(code, {})
	return bool(c.get("custom", false)) or int(c.get("enter", 0)) > GameDB.DATA_SEASON


## What is on record for a club before the career: {"known": bool, "years": [], "also": {label: [years]}}.
## `known` is false when the file has nothing for a real club yet.
static func before_career(code: String) -> Dictionary:
	if is_new_club(code):
		return {"known": true, "years": [], "also": {}}
	var d: Dictionary = table().get(code, {})
	if d.is_empty():
		return {"known": false, "years": [], "also": {}}
	var years: Array = (d["years"] as Array).duplicate()
	var also: Dictionary = (d.get("also", {}) as Dictionary).duplicate(true)
	return {"known": not years.is_empty() or not also.is_empty() or bool(d["none"]), "years": years, "also": also}
