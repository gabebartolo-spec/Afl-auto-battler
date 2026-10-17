class_name BestAndFairest
extends RefCounted
## The club best and fairest by its real name (data/bf_medals.json, P-54,
## director 2026-10-18): the Doig Medal at Fremantle, the Syd Barker Medal at
## North Melbourne, the Charles Sutton Medal at the Bulldogs. A club with no
## entry (Tasmania, Canberra, a Forge club) keeps "Best and fairest". Words
## only: the award is voted and stored as it always was, nothing here is read
## by the match.

const PATH := "res://data/bf_medals.json"
const DEFAULT := "Best and fairest"

static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func _clubs() -> Dictionary:
	return data().get("clubs", {})


## True for a club whose best and fairest has a name of its own.
static func is_named(club: String) -> bool:
	return _clubs().has(club)


## "Doig Medal", or "Best and fairest" for a club without a named award.
static func award_name(club: String) -> String:
	if _clubs().has(club):
		return str((_clubs()[club] as Dictionary).get("name", DEFAULT))
	return DEFAULT


## A section heading: the medal's name, or, with no medal, "<Club> best and fairest".
static func heading(club: String, club_name: String) -> String:
	if is_named(club):
		return award_name(club)
	return "%s best and fairest" % club_name


## How many of them a coach holds: "Doig Medal", "2 Doig Medals", or for a club
## with no medal "Tasmania best and fairest", "2 Tasmania best and fairests".
static func count_line(club: String, club_name: String, n: int) -> String:
	if is_named(club):
		return award_name(club) if n == 1 else "%d %s" % [n, plural(award_name(club))]
	return "%s best and fairest" % club_name if n == 1 else "%d %s best and fairests" % [n, club_name]


## The last word made plural: Medal, Trophy, Award, Champion.
static func plural(title: String) -> String:
	if title.ends_with("Trophy"):
		return title.trim_suffix("Trophy") + "Trophies"
	return title + "s"
