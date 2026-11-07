extends RefCounted
## A whole season's awards-night record made by hand for the UI tests
## (awards_count, back_nav): every home-and-away round of the fixture voted
## 3-2-1, your club's 5-4-3-2-1 every game plus one final, and the season's
## stored awards to match, so a count is quick and the same every run. The
## numbers only have to add up; no vote rule is being tested here.

## The final your club played, last in its count.
const FINAL_LABEL := "Qualifying Final"
const FINAL_VS := "MEL"
## The Rising Star's nomination round.
const RISING_ROUND := 5


static func build(state: Node, club: String) -> void:
	var season = state.season
	var rec := {"year": int(state.season_year), "club": club, "from": 1, "rounds": []}
	var n := 0
	var votes := {}
	var points := {}
	var clubs := {}
	for i in range(season.fixture.size()):
		var entry := {"round": i + 1, "label": "Round %d" % (i + 1), "final": false,
				"matches": [], "bf": [], "vs": ""}
		var games: Array = season.fixture[i]
		for j in range(games.size()):
			var home := str(games[j]["home"])
			var away := str(games[j]["away"])
			var hl: Array = season.lists[home]
			var al: Array = season.lists[away]
			var got := [[str(hl[n % 3]["id"]), 3, home], [str(al[3 + (n + j) % 3]["id"]), 2, away],
					[str(hl[6 + j % 3]["id"]), 1, home]]
			for v in got:
				votes[v[0]] = int(votes.get(v[0], 0)) + int(v[1])
				clubs[v[0]] = v[2]
			(entry["matches"] as Array).append({"home": home, "away": away, "votes": got})
			if home == club or away == club:
				entry["bf"] = _points(season.lists[club], n, points)
				entry["vs"] = away if home == club else home
			n += 1
		(rec["rounds"] as Array).append(entry)
	(rec["rounds"] as Array).append({"round": season.fixture.size() + 1, "label": FINAL_LABEL,
			"final": true, "matches": [], "bf": _points(season.lists[club], n, points), "vs": FINAL_VS})
	state.award_counts = rec
	var ids := votes.keys()
	ids.sort_custom(func(a, c):
		if int(votes[a]) != int(votes[c]):
			return int(votes[a]) > int(votes[c])
		return str(a) < str(c))
	var brownlow := []
	for id in ids.slice(0, 10):
		brownlow.append(_row(id, clubs[id], {"votes": int(votes[id])}))
	var bf_ids := points.keys()
	bf_ids.sort_custom(func(a, c):
		if int(points[a]) != int(points[c]):
			return int(points[a]) > int(points[c])
		return str(a) < str(c))
	var bf := []
	for id in bf_ids:
		bf.append(_row(id, club, {"bf": int(points[id])}))
	var mine: Array = season.lists[club]
	var rival: Array = season.lists[FINAL_VS]
	var star := _row(str(rival[20]["id"]), FINAL_VS, {"age": 19.0})
	state.rising_star_noms = {"from": 1, "rounds": [{"round": RISING_ROUND, "id": star["id"], "club": FINAL_VS}]}
	var team := []
	for i in range(4):
		team.append(_row(str(mine[i]["id"]), club, {"slot": "MID"}))
	state.season_awards = {"year": int(state.season_year), "brownlow": brownlow, "brownlow_winner": brownlow[0],
			"coleman": [_row(str(rival[10]["id"]), FINAL_VS, {"goals": 71})],
			"rising_star": [star], "all_australian": team, "best_and_fairest": {club: bf}}


## A stored award row as Awards._rows makes it, with `with` over the top.
static func _row(id: String, club: String, with: Dictionary) -> Dictionary:
	var row := {"id": id, "club": club, "games": 22, "goals": 0, "votes": 0, "coaches": 0, "bf": 0,
			"avg": 0.0, "role": "MID", "age": 24.0, "brownlow_eligible": true}
	row.merge(with, true)
	return row


## Your club's 5-4-3-2-1 for its n-th game, kept in `points`.
static func _points(list: Array, n: int, points: Dictionary) -> Array:
	var out := []
	for k in range(5):
		var id := str(list[(n + k) % 8]["id"])
		out.append([id, 5 - k])
		points[id] = int(points.get(id, 0)) + 5 - k
	return out
