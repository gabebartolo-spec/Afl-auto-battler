class_name MatchRings
extends RefCounted
## Who gets a ring on the oval: the players of yours you have made a call on or
## promised a run. Pure rules, read from the live sim's tactics and your list;
## nothing here decides or changes anything in the match.
##
## The order is what survives the cap. The people with a story come first (a
## run you promised, Backing), then the calls: the player you play through,
## the tagger, the spare, the defenders on the forwards you matched up. Your
## own players only: a ring means one of yours that you have a say about, so
## the match-ups the sim sets up by itself, the calls your assistant makes for
## you (MatchSim.coach_call), and the man you tag, are not ringed.

## The most rings on the oval at once.
const MAX := 6


## Player ids, most important first, at most MAX. `side` is yours, `my_list`
## your list (for the runs) and `my_matchups` the match-ups you set before the
## bounce ({their forward id: your defender id}).
static func ids(sim: MatchSim, side: int, my_list: Array, my_matchups := {}) -> Array:
	var out := []
	for p in my_list:
		if Backing.is_active(p):
			_add(out, str(p["id"]))
	var t: Dictionary = sim.tactics[side]
	_add(out, str(t.get("focus_id", "")))
	for slot in MatchSim.FOCUS_SLOTS:
		_add(out, str(t.get(slot, "")))
	# The tagger is the midfielder who goes to the man you are tagging.
	if str(t.get("tag_id", "")) != "":
		var tagger = MatchSim.tagger_for((sim.squads[side] as Squad).ground)
		if tagger != null:
			_add(out, str(tagger["id"]))
	if sim.coach_call(side):
		_add(out, str(sim.interceptor[side]))
	# The forwards you made a call on, before the bounce or during the match;
	# whoever is on each now.
	var chosen := {}
	for fid in my_matchups:
		chosen[str(fid)] = true
	for ch in sim.duel_changes:
		if int(ch["side"]) == side and sim.coach_call(side, str(ch["fwd"])):
			chosen[str(ch["fwd"])] = true
	var duels: Dictionary = sim.duels[side]
	for fid in chosen:
		if duels.has(fid):
			_add(out, str(duels[fid]))
	return out.slice(0, MAX)


static func _add(out: Array, id: String) -> void:
	if id != "" and not out.has(id):
		out.append(id)
