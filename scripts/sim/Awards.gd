class_name Awards
extends RefCounted
## Season awards, built from a running per-player tally (match results are
## slimmed when a career is saved, so the tally is what survives a reload).
##
##   Brownlow Medal   3-2-1 votes to the three most influential players in
##                    every home-and-away match (finals do not count)
##   Coleman Medal    most home-and-away goals
##   Rising Star      best votes-then-influence among players 21 and under
##   Best & fairest   5-4-3-2-1 within each side every match, finals included
##   All-Australian   the season's best 22 by position (12+ games)
##
## Influence is the best-on-ground measure the match screens already use
## (CoachReport.influence).

const AA_SLOTS := [["RUCK", 1], ["MID", 7], ["DEF", 5], ["FWD", 5]]
const AA_BENCH := 4
const AA_MIN_GAMES := 12
const RISING_STAR_AGE := 21.0


## Add one match to the tally. `regular` is false for finals.
static func tally_match(tally: Dictionary, res: Dictionary, regular: bool) -> void:
	var stats_all: Dictionary = res.get("players", {})
	var roster: Array = res.get("roster", [])
	var codes := [str(res.get("home", "")), str(res.get("away", ""))]
	var everyone := []
	for side in range(mini(2, roster.size())):
		var side_rows := []
		for r in roster[side]:
			var id := str(r["id"])
			var st: Dictionary = stats_all.get(id, {})
			var inf := CoachReport.influence(st)
			var t: Dictionary = tally.get(id, {"club": codes[side], "games": 0, "goals": 0,
					"goals_ha": 0, "disposals": 0, "influence": 0.0, "votes": 0, "bf": 0,
					"polled": 0})
			t["club"] = codes[side]
			t["games"] = int(t["games"]) + 1
			t["goals"] = int(t["goals"]) + int(st.get("goals", 0))
			if regular:
				t["goals_ha"] = int(t["goals_ha"]) + int(st.get("goals", 0))
			t["disposals"] = int(t["disposals"]) + int(st.get("disposals", 0))
			t["influence"] = float(t["influence"]) + inf
			tally[id] = t
			side_rows.append([id, inf])
			everyone.append([id, inf])
		side_rows.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
		for i in range(mini(5, side_rows.size())):
			var t: Dictionary = tally[str(side_rows[i][0])]
			t["bf"] = int(t["bf"]) + (5 - i)
	if regular:
		everyone.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
		for i in range(mini(3, everyone.size())):
			var t: Dictionary = tally[str(everyone[i][0])]
			t["votes"] = int(t["votes"]) + (3 - i)
			t["polled"] = int(t["polled"]) + 1


## The season's awards. `players` maps id -> player dict (role, age) for
## position and age; `year` labels the season.
static func season_awards(tally: Dictionary, players: Dictionary, year: int) -> Dictionary:
	var rows := []
	for id in tally:
		var t: Dictionary = tally[id]
		var p: Dictionary = players.get(id, {})
		rows.append({"id": str(id), "club": str(t["club"]), "games": int(t["games"]),
				"goals": int(t["goals_ha"]), "votes": int(t["votes"]), "bf": int(t["bf"]),
				"avg": float(t["influence"]) / float(maxi(1, int(t["games"]))),
				"role": str(p.get("role", "MID")), "age": float(p.get("age", 30.0))})
	var by_votes := rows.duplicate()
	by_votes.sort_custom(func(a, b):
		if int(a["votes"]) != int(b["votes"]):
			return int(a["votes"]) > int(b["votes"])
		return float(a["avg"]) > float(b["avg"]))
	var by_goals := rows.duplicate()
	by_goals.sort_custom(func(a, b):
		if int(a["goals"]) != int(b["goals"]):
			return int(a["goals"]) > int(b["goals"])
		return int(a["games"]) < int(b["games"]))
	var rising := []
	for r in by_votes:
		if float(r["age"]) <= RISING_STAR_AGE and int(r["games"]) >= 8:
			rising.append(r)
	var bf := {}
	var clubs := {}
	for r in rows:
		clubs[str(r["club"])] = true
	for code in clubs:
		var club_rows := []
		for r in rows:
			if str(r["club"]) == code:
				club_rows.append(r)
		club_rows.sort_custom(func(a, b):
			if int(a["bf"]) != int(b["bf"]):
				return int(a["bf"]) > int(b["bf"])
			return float(a["avg"]) > float(b["avg"]))
		bf[code] = club_rows.slice(0, 3)
	return {
		"year": year,
		"brownlow": by_votes.slice(0, 10),
		"coleman": by_goals.slice(0, 10),
		"rising_star": rising.slice(0, 3),
		"best_and_fairest": bf,
		"all_australian": _all_australian(rows),
	}


## The season's best 22 by natural position, then the best four left over.
static func _all_australian(rows: Array) -> Array:
	var eligible := []
	for r in rows:
		if int(r["games"]) >= AA_MIN_GAMES:
			eligible.append(r)
	# Votes speak loudest; average influence separates the rest.
	eligible.sort_custom(func(a, b):
		var sa := float(a["votes"]) * 1.5 + float(a["avg"])
		var sb := float(b["votes"]) * 1.5 + float(b["avg"])
		return sa > sb)
	var team := []
	var used := {}
	for slot in AA_SLOTS:
		var added := 0
		for r in eligible:
			if added >= int(slot[1]):
				break
			if str(r["role"]) == str(slot[0]) and not used.has(str(r["id"])):
				var pick: Dictionary = r.duplicate()
				pick["slot"] = str(slot[0])
				team.append(pick)
				used[str(r["id"])] = true
				added += 1
	var bench := 0
	for r in eligible:
		if bench >= AA_BENCH:
			break
		if not used.has(str(r["id"])):
			var pick: Dictionary = r.duplicate()
			pick["slot"] = "BENCH"
			team.append(pick)
			used[str(r["id"])] = true
			bench += 1
	return team


## League records across a career, updated when a season ends. Mutates and
## returns `records`.
static func update_records(records: Dictionary, awards: Dictionary, season_log: Array) -> Dictionary:
	var year := int(awards.get("year", 0))
	var coleman: Array = awards.get("coleman", [])
	if not coleman.is_empty() and int(coleman[0]["goals"]) > int((records.get("most_goals", {}) as Dictionary).get("value", -1)):
		records["most_goals"] = {"value": int(coleman[0]["goals"]), "id": str(coleman[0]["id"]),
				"club": str(coleman[0]["club"]), "year": year}
	var brownlow: Array = awards.get("brownlow", [])
	if not brownlow.is_empty() and int(brownlow[0]["votes"]) > int((records.get("most_votes", {}) as Dictionary).get("value", -1)):
		records["most_votes"] = {"value": int(brownlow[0]["votes"]), "id": str(brownlow[0]["id"]),
				"club": str(brownlow[0]["club"]), "year": year}
	for res in season_log:
		var s: Array = res.get("score", [0, 0])
		for side in range(2):
			var code := str(res["home"] if side == 0 else res["away"])
			var opp := str(res["away"] if side == 0 else res["home"])
			if int(s[side]) > int((records.get("highest_score", {}) as Dictionary).get("value", -1)):
				records["highest_score"] = {"value": int(s[side]), "club": code, "opp": opp, "year": year}
			var margin := int(s[side]) - int(s[1 - side])
			if margin > int((records.get("biggest_win", {}) as Dictionary).get("value", -1)):
				records["biggest_win"] = {"value": margin, "club": code, "opp": opp, "year": year}
	return records
