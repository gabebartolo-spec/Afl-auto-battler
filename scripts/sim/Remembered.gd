class_name Remembered
extends RefCounted
## What the club remembers about a player of yours, in football words (P-37,
## director 2026-10-18). Reads what is already kept, writes nothing:
##   CareerFacts   injuries he came back from, jobs he learned, sit-downs and
##                 the game you promised him
##   Firsts        his debut and first goal for you
##   Backing       a run you promised him
##   with_us()     his best and fairest years and premierships
##
## Each fact has a tier (how much it matters) and a time (when it happened).
## The player sheet shows the three that matter most, newest first; the
## release confirm says the single one that matters most. Routine facts (an
## injury he came back from) are never lost, they only lose their place to a
## bigger one. A fact that would read as guilt (a run you broke) is on the
## sheet as a plain record and is never said at the release.

## The most the player sheet shows.
const SHOWN := 3

const TIER_FLAG := 0
const TIER_BF := 1
const TIER_DEBUT := 2
const TIER_KEPT := 2
const TIER_LATER := 3
const TIER_INJURY := 4


## Everything remembered about him, as {"t", "tier", "sheet", "said"}: `sheet`
## is the line for his sheet ("Debuted in Round 7, 2028."), `said` the same fact
## for the release confirm ("He debuted for you in Round 7, 2028."), "" when it
## is not to be said there. `club` is your club; `with_us` is GameState.with_us(p);
## `jobs` is GameState.LEARN_JOBS (the words for a learned job).
static func facts(p: Dictionary, store: Dictionary, club: String, with_us: Dictionary,
		jobs: Dictionary = {}) -> Array:
	var out := []
	if club == "":
		return out
	for y in with_us.get("flags", []):
		out.append(_f(int(y) * 1000 + 200, TIER_FLAG, "Premiership, %d." % int(y),
				"He was with you for the %d premiership." % int(y)))
	for y in with_us.get("bf", []):
		out.append(_f(int(y) * 1000 + 150, TIER_BF, "Best and fairest, %d." % int(y),
				"He won your best and fairest in %d." % int(y)))
	var d := Firsts.get_one(p, "debut")
	var g := Firsts.get_one(p, "goal")
	var same := not d.is_empty() and not g.is_empty() and int(d.get("year", 0)) == int(g.get("year", 0)) \
			and str(d.get("label", "")) == str(g.get("label", ""))
	if not d.is_empty():
		var on_run := ", on your say-so" if Backing.debuted_on_run(p) else ""
		var and_goal := ", and kicked his first goal" if same else ""
		out.append(_f(_time(int(d.get("year", 0)), str(d.get("label", ""))), TIER_DEBUT,
				"Debuted %s%s%s." % [Firsts.when_text(d), on_run, and_goal],
				"He debuted for you %s%s%s." % [Firsts.when_text(d), on_run, and_goal]))
	if not g.is_empty() and not same:
		out.append(_f(_time(int(g.get("year", 0)), str(g.get("label", ""))), TIER_LATER,
				"First goal %s." % Firsts.when_text(g),
				"He kicked his first goal for you %s." % Firsts.when_text(g)))
	for e in Backing.ledger(p):
		var made_at := str(e.get("club", ""))
		if made_at != "" and made_at != club:
			continue
		var year := int(e.get("year", 0))
		var played := int(e.get("played", 0))
		var games := int(e.get("games", Backing.RUN_GAMES))
		match str(e.get("state", "")):
			"done":
				# A run that gave him his debut is already in the debut line.
				if not bool(e.get("debut", false)):
					var run := MatchNotes.count_word(games)
					out.append(_f(year * 1000 + 90, TIER_KEPT, "Given a %s-game run in %d." % [run, year],
							"You gave him a %s-game run in %d." % [run, year]))
			"broken":
				out.append(_f(year * 1000 + 90, TIER_LATER, "Promised a run in %d, left out %s." % [year,
						"before he played a game of it" if played == 0
						else "after %s game%s" % [MatchNotes.count_word(played), "" if played == 1 else "s"]], ""))
			"lapsed":
				var left := games - played
				out.append(_f(year * 1000 + 90, TIER_LATER, "Promised a run in %d; the season ended with %s game%s to go." % [
						year, MatchNotes.count_word(left), "" if left == 1 else "s"], ""))
	var latest_injury := -1
	var rows := CareerFacts.of(store, str(p.get("id", "")))
	for i in range(rows.size()):
		if str(rows[i]["k"]) == "injury":
			latest_injury = i
	for i in range(rows.size()):
		var r: Dictionary = rows[i]
		if str(r["club"]) != club:
			continue
		var when := Firsts.when_text({"year": int(r["y"]), "label": str(r["at"])})
		var t := _time(int(r["y"]), str(r["at"]))
		match str(r["k"]):
			"injury":
				# Still hurt from this one: it is on his state line, not his past.
				if i == latest_injury and int(p.get("injury_weeks", 0)) > 0:
					continue
				var kind := str(r["out"])
				var what := "Injury" if kind == "" else ("Concussion" if kind == "concussion"
						else "%s injury" % kind.capitalize())
				var had := "an injury" if kind == "" else ("a concussion" if kind == "concussion"
						else "a %s injury" % kind)
				out.append(_f(t, TIER_INJURY, "%s %s; he came back." % [what, when],
						"He came back from %s %s." % [had, when]))
			"project":
				if str(r["out"]) != "learned":
					continue
				var word := str((jobs.get(str(r["d"]), {}) as Dictionary).get("word", ""))
				if word == "":
					continue
				out.append(_f(t, TIER_LATER, "Learned the %s job in %d." % [word, int(r["y"])],
						"He learned the %s job with you in %d." % [word, int(r["y"])]))
			"talk":
				if str(r["d"]).get_slice("|", 1) == "promise" and str(r["out"]) == "played":
					out.append(_f(t, TIER_KEPT, "Promised a game %s; he played." % when,
							"You promised him a game %s, and he played." % when))
	return out


## Up to `limit` lines for his sheet: the ones that matter most, shown newest
## first.
static func sheet_lines(p: Dictionary, store: Dictionary, club: String, with_us: Dictionary,
		jobs: Dictionary = {}, limit := SHOWN) -> Array:
	var all := facts(p, store, club, with_us, jobs)
	all.sort_custom(_more_important)
	var top := all.slice(0, limit)
	top.sort_custom(func(a, b): return int(a["t"]) > int(b["t"]))
	return top.map(func(f): return str(f["sheet"]))


## The one fact the release confirm says, or "": the biggest, newest first among
## equals, leaving out anything that would read as guilt.
static func release_line(p: Dictionary, store: Dictionary, club: String, with_us: Dictionary,
		jobs: Dictionary = {}) -> String:
	var all := facts(p, store, club, with_us, jobs).filter(func(f): return str(f["said"]) != "")
	if all.is_empty():
		return ""
	all.sort_custom(_more_important)
	return str(all[0]["said"])


## "Since 2028: 59 games, 20 goals." - the totals above the remembered facts.
static func head(with_us: Dictionary) -> String:
	var g := int(with_us.get("games", 0))
	if g <= 0:
		return ""
	var gl := int(with_us.get("goals", 0))
	return "Since %d: %d game%s, %s." % [int(with_us.get("since", 0)), g, "" if g == 1 else "s",
			"no goals" if gl == 0 else "%d goal%s" % [gl, "" if gl == 1 else "s"]]


static func _more_important(a: Dictionary, b: Dictionary) -> bool:
	if int(a["tier"]) != int(b["tier"]):
		return int(a["tier"]) < int(b["tier"])
	return int(a["t"]) > int(b["t"])


static func _f(t: int, tier: int, sheet: String, said: String) -> Dictionary:
	return {"t": t, "tier": tier, "sheet": sheet, "said": said}


## A sortable moment: the season, then the match in it ("Round 7" is 7, a final
## 101 and up, a fact the record never dated 0).
static func _time(year: int, label: String) -> int:
	var within := 0
	if label.begins_with("Round"):
		within = int(label.get_slice(" ", 1))
	elif label != "":
		var stage := label.rstrip("0123456789 ")
		within = 101 if stage in ["Qualifying Final", "Elimination Final"] \
				else (102 if stage == "Semi Final" else (103 if stage == "Preliminary Final"
				else (104 if stage == "Grand Final" else 105)))
	return year * 1000 + within
