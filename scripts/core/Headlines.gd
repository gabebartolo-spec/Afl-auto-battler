class_name Headlines
extends RefCounted
## FL-006 (ROADMAP 9.3): a short, characterful headline over your result -
## editorial flavour, never game information. Each line is said only when the
## match's own facts support it (docs/research/AFL_FLAVOUR_WRITING_SAMPLES.md
## section 2); otherwise there is no headline and the plain result stands
## alone. Losses get none: neutral reporting beats a joke. Nothing here is read
## by the game.
##
## In order, the first that is true:
##  - comeback: won after trailing by COMEBACK or more at a break;
##  - made it interesting: won by CLOSE_WIN or less after leading by BLOWN or
##    more at a break;
##  - close: won by CLOSE or less;
##  - rivalry: beat a real rival (data/banners.json rivalry pairs);
##  - draw: nothing between them.
## The break-by-break claims need every quarter's score to add up to the final
## score (extra time doesn't), or they are not made.

const COMEBACK := 24
const BLOWN := 30
const CLOSE_WIN := 12
const CLOSE := 6
const BREAKS := ["quarter time", "half-time", "three-quarter time"]


## The headline for `me`'s match (0 home, 1 away), or "".
static func for_match(res: Dictionary, me: int) -> String:
	var s: Array = res.get("score", [0, 0])
	var mine := int(s[me])
	var theirs := int(s[1 - me])
	if mine == theirs:
		return "Nothing between them."
	if mine < theirs:
		return ""
	var margin := mine - theirs
	var leads := _break_leads(res, me)
	if not leads.is_empty():
		var worst := 0
		var at := -1
		var best := 0
		for i in range(leads.size()):
			if int(leads[i]) < worst:
				worst = int(leads[i])
				at = i
			best = maxi(best, int(leads[i]))
		if -worst >= COMEBACK:
			return "From %d points down at %s." % [-worst, BREAKS[at]]
		if best >= BLOWN and margin <= CLOSE_WIN:
			return "We made that interesting."
	if margin <= CLOSE:
		return "Not much room to breathe."
	var us := str(res.get("home" if me == 0 else "away", ""))
	var them := str(res.get("away" if me == 0 else "home", ""))
	if is_rivalry(us, them):
		return "The neighbours heard that one."
	return ""


## Your lead (negative: behind) at quarter, half and three-quarter time, or []
## when the quarters don't add up to the final score.
static func _break_leads(res: Dictionary, me: int) -> Array:
	var q: Array = res.get("quarters", [])
	var s: Array = res.get("score", [0, 0])
	if q.size() != 4:
		return []
	var tot := [0, 0]
	var out := []
	for i in range(4):
		tot[0] += int(q[i][0])
		tot[1] += int(q[i][1])
		if i < 3:
			out.append(int(tot[me]) - int(tot[1 - me]))
	if int(tot[0]) != int(s[0]) or int(tot[1]) != int(s[1]):
		return []
	return out


static func is_rivalry(a: String, b: String) -> bool:
	for r in (Banners.data().get("rivalry", []) as Array):
		var pair: Array = (r as Dictionary).get("pair", [])
		if pair.size() == 2 and ((pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a)):
			return true
	return false
