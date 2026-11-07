class_name AwardsCount
extends RefCounted
## The votes each round really gave, kept for the awards-night count (T5.Q23b):
## the Brownlow's 3-2-1 match by match (home and away only), and your club's
## best-and-fairest points (finals included). Nothing here decides a vote:
## GameState._after_round takes a snapshot of the season tally before the
## round's matches are tallied (Awards.tally_match) and records the change
## after, so the rounds always add up to the season's tally, whatever rule
## gave the votes. A player plays once a round, so his change is his match.
##
## The record: {"year", "club", "from": the first round recorded,
##   "rounds": [{"round": n, "label": "Round 7", "final": false,
##     "matches": [{"home", "away", "votes": [[id, votes, club], ...]}],
##     "bf": [[id, points], ...], "vs": your club's opponent, "" on a bye}]}.
## A finals week is recorded only when your club played in it, for its count.


## A season's empty record. `from` is the first round it will see.
static func fresh(year: int, club: String, from := 1) -> Dictionary:
	return {"year": year, "club": club, "from": from, "rounds": []}


## Every player in the round's matches: [votes, bf] before they are tallied.
static func snapshot(tally: Dictionary, results: Array) -> Dictionary:
	var out := {}
	for res in results:
		if not (res is Dictionary):
			continue
		for side in (res as Dictionary).get("roster", []):
			for r in side:
				var id := str(r["id"])
				var t: Dictionary = tally.get(id, {})
				out[id] = [int(t.get("votes", 0)), int(t.get("bf", 0))]
	return out


## The round just tallied, as the change from `before` (snapshot). `order` is
## the round's fixture ([{home, away}]), so the matches read in its order.
static func record_round(record: Dictionary, before: Dictionary, tally: Dictionary,
		results: Array, club: String, order: Array = []) -> void:
	if results.is_empty() or not (results[0] is Dictionary):
		return
	var first: Dictionary = results[0]
	var rnd := int(first.get("round", 0))
	if not record.has("rounds"):
		record["rounds"] = []
	for e in record["rounds"]:
		if int(e.get("round", 0)) == rnd:
			return  # never twice
	var final := first.has("tag")
	var entry := {"round": rnd, "label": str(first.get("label", "Round %d" % rnd)),
			"final": final, "matches": [], "bf": [], "vs": ""}
	for res in results:
		var codes := [str(res.get("home", "")), str(res.get("away", ""))]
		var roster: Array = res.get("roster", [])
		var votes := []
		for side in range(mini(2, roster.size())):
			var mine: bool = str(codes[side]) == club and club != ""
			var points := []
			for r in roster[side]:
				var id := str(r["id"])
				var was: Array = before.get(id, [0, 0])
				var t: Dictionary = tally.get(id, {})
				var v := int(t.get("votes", 0)) - int(was[0])
				var b := int(t.get("bf", 0)) - int(was[1])
				if v > 0:
					votes.append([id, v, codes[side]])
				if mine and b > 0:
					points.append([id, b])
			if mine:
				points.sort_custom(func(a, c): return int(a[1]) > int(c[1]))
				entry["bf"] = points
				entry["vs"] = codes[1 - side]
				if final:
					entry["label"] = final_name(str(res.get("label", "")))
		if not final:
			votes.sort_custom(func(a, c): return int(a[1]) > int(c[1]))
			(entry["matches"] as Array).append({"home": codes[0], "away": codes[1], "votes": votes})
	if final and str(entry["vs"]) == "":
		return  # your club was not in this week's finals: nothing of its count
	if not order.is_empty():
		var at := {}
		for i in range(order.size()):
			at["%s|%s" % [order[i].get("home", ""), order[i].get("away", "")]] = i
		(entry["matches"] as Array).sort_custom(func(a, c):
			return int(at.get("%s|%s" % [a["home"], a["away"]], 99)) < int(at.get("%s|%s" % [c["home"], c["away"]], 99)))
	(record["rounds"] as Array).append(entry)


## "Qualifying Final 1" -> "Qualifying Final": the week's name for your final.
static func final_name(label: String) -> String:
	var words := label.split(" ")
	if words.size() > 1 and words[-1].is_valid_int():
		words.remove_at(words.size() - 1)
	return " ".join(words)


## True when the record holds the whole home-and-away season of `year` for
## `club`, Round 1 to `rounds`: only then can the night be counted round by
## round. A save that began recording part way through is not counted.
static func complete(record: Dictionary, year: int, club: String, rounds: int) -> bool:
	if record.is_empty() or int(record.get("from", 0)) != 1 or int(record.get("year", 0)) != year \
			or str(record.get("club", "")) != club or rounds <= 0:
		return false
	var seen := {}
	for e in record.get("rounds", []):
		if not bool(e.get("final", false)):
			seen[int(e.get("round", 0))] = true
	for n in range(1, rounds + 1):
		if not seen.has(n):
			return false
	return true


## The Brownlow count: the home-and-away rounds in order, each a list of
## matches, each its votes [[id, votes, club]].
static func brownlow_steps(record: Dictionary) -> Array:
	var out := []
	for e in record.get("rounds", []):
		if not bool(e.get("final", false)):
			out.append({"round": int(e["round"]), "label": str(e["label"]), "final": false,
					"matches": e.get("matches", [])})
	out.sort_custom(func(a, c): return int(a["round"]) < int(c["round"]))
	return out


## Your club's count: the games it played, finals included, in order, each
## one "match" of its best-and-fairest points [[id, points, club]].
static func club_steps(record: Dictionary) -> Array:
	var club := str(record.get("club", ""))
	var out := []
	for e in record.get("rounds", []):
		if str(e.get("vs", "")) == "":
			continue  # a bye, or a finals week without you
		var pts := []
		for b in e.get("bf", []):
			pts.append([str(b[0]), int(b[1]), club])
		out.append({"round": int(e["round"]), "label": str(e["label"]), "final": bool(e.get("final", false)),
				"matches": [{"home": club, "away": str(e["vs"]), "votes": pts}]})
	out.sort_custom(func(a, c): return int(a["round"]) < int(c["round"]))
	return out


## The totals from the revealed part of a count only: every match of the
## first `rounds` steps, then the first `matches` of the next.
## Returns {id: {"total", "club", "last"}}, where "last" is what the step
## being read gave him.
static func totals(steps: Array, rounds: int, matches: int) -> Dictionary:
	var out := {}
	for i in range(mini(rounds + 1, steps.size())):
		var ms: Array = steps[i]["matches"]
		var upto := ms.size() if i < rounds else mini(matches, ms.size())
		for j in range(upto):
			for v in ms[j]["votes"]:
				var id := str(v[0])
				var row: Dictionary = out.get(id, {"total": 0, "club": str(v[2]), "last": 0})
				row["total"] = int(row["total"]) + int(v[1])
				row["club"] = str(v[2])
				out[id] = row
	# What the round being read, or the one just read, gave each player.
	var at := rounds if matches > 0 else rounds - 1
	if at >= 0 and at < steps.size():
		var ms: Array = steps[at]["matches"]
		var upto := ms.size() if at < rounds else mini(matches, ms.size())
		for j in range(upto):
			for v in ms[j]["votes"]:
				out[str(v[0])]["last"] = int(out[str(v[0])].get("last", 0)) + int(v[1])
	return out


## The board: [{id, club, total, last, rank}] by total, level totals sharing a
## rank. `order` ([ids]) settles who is listed first among level players (the
## stored final placings), then the id, so a board never shuffles.
static func board(steps: Array, rounds: int, matches: int, order: Array = []) -> Array:
	var t := totals(steps, rounds, matches)
	var first := {}
	for i in range(order.size()):
		first[str(order[i])] = i
	var rows := []
	for id in t:
		var r: Dictionary = t[id]
		rows.append({"id": str(id), "club": str(r["club"]), "total": int(r["total"]), "last": int(r["last"])})
	rows.sort_custom(func(a, c):
		if int(a["total"]) != int(c["total"]):
			return int(a["total"]) > int(c["total"])
		var fa := int(first.get(a["id"], 9999))
		var fc := int(first.get(c["id"], 9999))
		if fa != fc:
			return fa < fc
		return str(a["id"]) < str(c["id"]))
	var rank := 0
	for i in range(rows.size()):
		if i == 0 or int(rows[i]["total"]) != int(rows[i - 1]["total"]):
			rank = i + 1
		rows[i]["rank"] = rank
	for i in range(rows.size()):
		var shared := (i > 0 and int(rows[i - 1]["rank"]) == int(rows[i]["rank"])) \
				or (i + 1 < rows.size() and int(rows[i + 1]["rank"]) == int(rows[i]["rank"]))
		rows[i]["shared"] = shared
	return rows
