class_name Awards
extends RefCounted
## Season awards, built from a running per-player tally (match results are
## slimmed when a career is saved, so the tally is what survives a reload).
##
##   Brownlow Medal   3-2-1 votes to the three most influential players in
##                    every home-and-away match (finals do not count)
##   Coleman Medal    most home-and-away goals
##   Rising Star      best votes-then-influence among the season's weekly
##                    nominees (one a round: the most influential player 21
##                    and under not yet nominated)
##   Best & fairest   5-4-3-2-1 within each side every match, finals included
##   All-Australian   the season's best 23 by position (12+ games)
##
## Influence is the best-on-ground measure the match screens already use
## (CoachReport.influence).

const AA_SLOTS := [["RUCK", 1], ["MID", 5], ["DEF", 6], ["FWD", 6]]
## The team is a match-day 23: 18 by position plus five on the bench
## (director, 2026-10-06, with ARD-M5-001).
const AA_BENCH := 5
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
					"goals_ha": 0, "disposals": 0, "distance_run": 0.0, "influence": 0.0, "votes": 0, "bf": 0,
					"polled": 0, "coaches": 0})
			t["club"] = codes[side]
			t["games"] = int(t["games"]) + 1
			t["goals"] = int(t["goals"]) + int(st.get("goals", 0))
			if regular:
				t["goals_ha"] = int(t["goals_ha"]) + int(st.get("goals", 0))
			t["disposals"] = int(t["disposals"]) + int(st.get("disposals", 0))
			t["distance_run"] = float(t.get("distance_run", 0.0)) + float(st.get("distance_run", 0.0))
			t["influence"] = float(t["influence"]) + inf
			# AFL Coaches Association-style award: each coach effectively names a top five;
			# the combined 10-8-6-4-2 scale preserves the same ordering without inventing
			# a second performance model. Home-and-away only, like the live season race.
			if not t.has("coaches"):
				t["coaches"] = 0
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
		# Ten coaches-award votes per match, 5-4-3-2-1 to the five best players.
		for i in range(mini(5, everyone.size())):
			var t: Dictionary = tally[str(everyone[i][0])]
			t["coaches"] = int(t.get("coaches", 0)) + (5 - i)


## The season's awards. `players` maps id -> player dict (role, age) for
## position and age; `year` labels the season. `nominees` is the season's
## Rising Star record ({"from": first round recorded, "rounds": [...]}); when
## it covers the whole season the winner comes from the nominees, as in the
## AFL. A season without a full record (an older save) keeps the old rule:
## the best of everyone young enough with 8 or more games.
static func season_awards(tally: Dictionary, players: Dictionary, year: int,
		nominees: Dictionary = {}) -> Dictionary:
	var rows := _rows(tally, players)
	var by_votes := rows.duplicate()
	by_votes.sort_custom(func(a, b):
		if int(a["votes"]) != int(b["votes"]):
			return int(a["votes"]) > int(b["votes"])
		return float(a["avg"]) > float(b["avg"]))
	var brownlow_winner := {}
	for r in by_votes:
		if bool(r.get("brownlow_eligible", true)):
			brownlow_winner = r
			break
	var by_coaches := rows.duplicate()
	by_coaches.sort_custom(func(a, b):
		if int(a["coaches"]) != int(b["coaches"]):
			return int(a["coaches"]) > int(b["coaches"])
		return float(a["avg"]) > float(b["avg"]))
	var by_goals := rows.duplicate()
	by_goals.sort_custom(func(a, b):
		if int(a["goals"]) != int(b["goals"]):
			return int(a["goals"]) > int(b["goals"])
		return int(a["games"]) < int(b["games"]))
	var rising := []
	var nominated := {}
	if int(nominees.get("from", 0)) == 1:
		for n in nominees.get("rounds", []):
			nominated[str(n.get("id", ""))] = true
	for r in by_votes:
		if not nominated.is_empty():
			if nominated.has(str(r["id"])):
				rising.append(r)
		elif float(r["age"]) <= RISING_STAR_AGE and int(r["games"]) >= 8:
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
		# The vote table stays in raw vote order so an ineligible player never
		# loses votes or disappears from history. Winner is selected separately.
		"brownlow": by_votes.slice(0, 10),
		"brownlow_winner": brownlow_winner,
		"coleman": by_goals.slice(0, 10),
		"coaches_award": by_coaches.slice(0, 10),
		"rising_star": rising.slice(0, 3),
		"best_and_fairest": bf,
		"all_australian": _all_australian(rows),
	}


## One row per tallied player: his season numbers, position and age.
static func _rows(tally: Dictionary, players: Dictionary) -> Array:
	var rows := []
	for id in tally:
		var t: Dictionary = tally[id]
		var p: Dictionary = players.get(id, {})
		rows.append({"id": str(id), "club": str(t["club"]), "games": int(t["games"]),
				"goals": int(t["goals_ha"]), "votes": int(t["votes"]), "coaches": int(t.get("coaches", 0)), "bf": int(t["bf"]),
				"avg": float(t["influence"]) / float(maxi(1, int(t["games"]))),
				"role": str(p.get("role", "MID")), "age": float(p.get("age", 30.0)),
				"brownlow_eligible": not bool(p.get("brownlow_ineligible", false))})
	return rows


## The games a player needs for the All-Australian team after `rounds` of the
## home-and-away season: the full-season minimum, scaled to the rounds played.
static func aa_min_games(rounds: int) -> int:
	return clampi(ceili(float(AA_MIN_GAMES) * float(rounds) / float(Season.REGULAR_ROUNDS)), 1, AA_MIN_GAMES)


## The All-Australian team if it were picked today, from the tally so far
## (Season stats > Awards). The same slots and bench as the real team, from
## players with `min_games` or more. It differs from the final selection in
## one way: the final team weighs Brownlow votes, but those stay sealed until
## the count, and a projection ranked by them would let the count leak. So
## average influence alone ranks the projected team.
static func projected_all_australian(tally: Dictionary, players: Dictionary, min_games: int) -> Array:
	return _all_australian(_rows(tally, players), min_games, false)


## The season's best 18 by natural position, then the best five left over.
static func _all_australian(rows: Array, min_games := AA_MIN_GAMES, use_votes := true) -> Array:
	var eligible := []
	for r in rows:
		if int(r["games"]) >= min_games:
			eligible.append(r)
	# Votes speak loudest; average influence separates the rest. Ties go to
	# the id so the same tally always names the same team.
	eligible.sort_custom(func(a, b):
		var sa := (float(a["votes"]) * 1.5 if use_votes else 0.0) + float(a["avg"])
		var sb := (float(b["votes"]) * 1.5 if use_votes else 0.0) + float(b["avg"])
		if sa != sb:
			return sa > sb
		return str(a["id"]) < str(b["id"]))
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


## The round's Rising Star nominee: the most influential player that round
## who is RISING_STAR_AGE or younger and not yet nominated this season (one
## nomination a season, as in the AFL). `ages` maps id -> age; `nominated`
## holds the ids already nominated. {} when nobody eligible played.
static func rising_star_nominee(results: Array, ages: Dictionary, nominated: Dictionary) -> Dictionary:
	var best := {}
	var best_inf := -INF
	for res in results:
		if res.has("tag"):
			continue  # a final
		var stats_all: Dictionary = res.get("players", {})
		var roster: Array = res.get("roster", [])
		var codes := [str(res.get("home", "")), str(res.get("away", ""))]
		for side in range(mini(2, roster.size())):
			for r in roster[side]:
				var id := str(r["id"])
				if nominated.has(id) or not ages.has(id) or float(ages[id]) > RISING_STAR_AGE:
					continue
				var inf := CoachReport.influence(stats_all.get(id, {}))
				if inf > best_inf or (inf == best_inf and id < str(best.get("id", ""))):
					best_inf = inf
					best = {"id": id, "club": codes[side]}
	return best


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
