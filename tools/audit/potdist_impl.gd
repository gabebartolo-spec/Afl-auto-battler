extends RefCounted
## Potential inflation (director's PC playtest, 2026-10-07, P0): how common
## are 90+ ceilings in the pool a career starts from? Counts, by age band and
## position: true POT >= 90, your League Draft read's midpoint >= 90, and its
## upper bound >= 90; which source set each POT (age headroom, recent peak,
## draft pedigree, override); and the director's named examples.

const NAMES := ["Patrick Voss", "Josh Treacy", "Cody Walker", "Noah Anderson", "Jake Waterman",
		"Jack Viney", "Josh Worrell", "Tom Stewart", "Max Hall", "Sam Darcy", "Jagga Smith",
		"Cal Wilkie", "Luke Jackson", "Max Gawn", "Daniel McStay", "Nick Daicos", "Marcus Bontempelli"]


func run() -> void:
	var players: Array = GameDB.all_players_sorted() + GameDB.all_draftees_sorted()
	var draft := Draft.new(players, GameDB.active_clubs(2027).duplicate(), 12345)
	draft.start_for_user("COL")
	var bands := [[0, 20], [21, 23], [24, 26], [27, 29], [30, 40]]
	var rows := {}
	var src := {"headroom": 0, "peak": 0, "pedigree": 0, "draftee": 0}
	var n := 0
	var tp90 := 0
	var mid90 := 0
	var up90 := 0
	var pots := []
	for p in players:
		n += 1
		var pot := int(p.get("potential", p.get("overall", 0)))
		pots.append(pot)
		var v: Dictionary = draft.user_view(p)
		var age := int(p.get("age", 25))
		var role := str(p.get("role", "MID"))
		var key := "%s|%s" % [role, _band(bands, age)]
		if not rows.has(key):
			rows[key] = [0, 0, 0, 0]
		var r: Array = rows[key]
		r[0] += 1
		if pot >= 90:
			r[1] += 1
			tp90 += 1
		if int(v["potential_mid"]) >= 90:
			r[2] += 1
			mid90 += 1
		if int((v["potential"] as Array)[1]) >= 90:
			r[3] += 1
			up90 += 1
		if pot >= 90:
			src[_source(p)] += 1
	pots.sort()
	print("potdist: %d players. True POT >= 90: %d (%.0f%%); your read's midpoint >= 90: %d (%.0f%%); its upper bound >= 90: %d (%.0f%%)"
			% [n, tp90, 100.0 * tp90 / n, mid90, 100.0 * mid90 / n, up90, 100.0 * up90 / n])
	print("potdist: POT percentiles p10 %d, p25 %d, p50 %d, p75 %d, p90 %d, p99 %d" % [pots[n / 10], pots[n / 4], pots[n / 2],
			pots[n * 3 / 4], pots[n * 9 / 10], pots[n * 99 / 100]])
	print("potdist: where the 90+ came from: ", src)
	var keys := rows.keys()
	keys.sort()
	for k in keys:
		var r: Array = rows[k]
		print("potdist: %-12s n %3d  true90 %3d  mid90 %3d  upper90 %3d" % [k, r[0], r[1], r[2], r[3]])
	for p in players:
		var nm := "%s %s" % [str(p.get("first", "")), str(p.get("last", ""))]
		if NAMES.has(nm):
			var v: Dictionary = draft.user_view(p)
			print("potdist: %-20s age %2d %-4s OVR %2d POT %2d  read OVR %s POT %s  peak %.0f  pick %s  source %s" % [nm,
					int(p.get("age", 0)), str(p.get("role", "")), int(p.get("overall", 0)), int(p.get("potential", 0)),
					DraftScouting.range_text(v["overall"]), DraftScouting.range_text(v["potential"]),
					Potential.recent_peak(p), str(p.get("drafted_pick", "-")), _source(p)])


func _band(bands: Array, age: int) -> String:
	for b in bands:
		if age >= int(b[0]) and age <= int(b[1]):
			return "%02d-%02d" % [int(b[0]), int(b[1])]
	return "?"


## Which rule set this player's POT (the highest of them wins).
func _source(p: Dictionary) -> String:
	if bool(p.get("projected", false)):
		return "draftee"
	var pot := float(p.get("potential", 0))
	var peak := Potential.recent_peak(p)
	if peak > 0.0 and absf(roundf(peak) - pot) <= 0.5:
		return "peak"
	var head := float(p.get("overall", 0)) + Potential._headroom(float(p.get("age", 26.0)))
	if pot <= head + 3.5:
		return "headroom"
	return "pedigree"
