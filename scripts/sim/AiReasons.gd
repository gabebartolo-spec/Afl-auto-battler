class_name AiReasons
extends RefCounted
## Why a rival club said no, passed or outbid you, in one line of football
## words (P-18, director 2026-10-18: "make the rules transparent; don't make
## the decision"). The decision code picks a reason code at the branch it
## took; this file only turns a code into its sentence from
## data/ai_reasons.json. The sentences hold no values, percentages or hidden
## ratings.

const PATH := "res://data/ai_reasons.json"

static var _data := {}
## Off: the draft and the free-agent market skip working out reasons. Only
## the tests turn it off, to prove the sim decides the same either way.
static var enabled := true


static func reasons() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = (parsed as Dictionary).get("reasons", {}) if parsed is Dictionary else {}
	return _data


static func has(code: String) -> bool:
	return reasons().has(code)


## The sentence for `code` with its placeholders filled from `facts`
## ({"club", "player", "other", "pos", "age", "to", "n"}). "" for an unknown code.
static func line(code: String, facts := {}) -> String:
	var text := str(reasons().get(code, ""))
	for k in facts:
		if str(facts[k]) == "":
			text = text.replace(" {%s}" % str(k), "")  # an empty fact takes its space with it
		text = text.replace("{%s}" % str(k), str(facts[k]))
	return text
