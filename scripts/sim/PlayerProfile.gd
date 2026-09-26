class_name PlayerProfile
extends RefCounted
## A footballer in words, for inspecting him before a pick: what kind of
## player he is, what he is good at, and what he has produced. Read-only -
## nothing here changes a player, a draft or any random stream.
##
## Strengths come from the attributes the match engine rewards in his role
## (Ratings.ROLE_WEIGHTS, the same core OVR is built from), graded against
## 2026 players of that role. His type is the training archetype
## (GameState.TRAIN_PLANS) his strengths fit best, so the draft and the
## Training screen speak the same language.

## Grades against 2026 players of the same role: [share from the top, word].
const GRADES := [[0.10, "Elite"], [0.30, "Strong"], [0.55, "Good"]]
const WEAK_SHARE := 0.25          # bottom quarter of his role: a weakness
## Only attributes carrying at least this share of the role core count as a
## strength: a midfielder's goalkicking (5%) is not what he is picked for.
const MIN_WEIGHT := 0.10

const ATTR_LABELS := {
	"disposal": "Disposal", "contested": "Contested ball", "marking": "Marking",
	"pressure": "Pressure", "intercept": "Intercepting", "carry": "Carry",
	"goalkicking": "Goalkicking", "accuracy": "Accuracy", "creating": "Creating",
	"ruck": "Ruck work", "discipline": "Discipline", "durability": "Durability",
	"star": "Star power",
}

static var _sorted := {}          # "ROLE|attr" -> sorted 2026 values


## 2026 players of this role (the scale every rating is anchored to).
static func _values(role: String, key: String) -> Array:
	var k := role + "|" + key
	if not _sorted.has(k):
		var vals := []
		var db: Node = Engine.get_main_loop().root.get_node("GameDB")
		for p in db.players:
			if str(p.get("role", "")) == role:
				vals.append(float((p["attr"] as Dictionary).get(key, 0)))
		vals.sort()
		_sorted[k] = vals
	return _sorted[k]


## Share of 2026 players of his role he is at least as good as (0..1).
static func percentile(p: Dictionary, key: String) -> float:
	var vals := _values(str(p.get("role", "MID")), key)
	if vals.is_empty():
		return 0.5
	var v := float((p.get("attr", {}) as Dictionary).get(key, 0))
	var below := vals.bsearch(v, true)
	return float(below) / float(vals.size())


static func grade(pct: float) -> String:
	for g in GRADES:
		if pct >= 1.0 - float(g[0]):
			return str(g[1])
	return ""


## Up to three strengths among what his role is judged on, best first:
## [{"key", "label", "grade"}]. Empty when nothing stands out.
static func strengths(p: Dictionary, limit := 3) -> Array:
	var core: Dictionary = Ratings.ROLE_WEIGHTS.get(str(p.get("role", "MID")), {})
	var rows := []
	for key in core:
		if float(core[key]) < MIN_WEIGHT:
			continue
		var pct := percentile(p, key)
		var g := grade(pct)
		if g != "":
			rows.append({"key": key, "label": str(ATTR_LABELS.get(key, key)), "grade": g, "pct": pct,
					"w": float(core[key])})
	# Best first; level grades go to what matters more to the role.
	rows.sort_custom(func(a, b):
		if str(a["grade"]) != str(b["grade"]):
			return float(a["pct"]) > float(b["pct"])
		return float(a["w"]) > float(b["w"]))
	return rows.slice(0, limit)


## The one thing his role needs that he lacks most, or {}: only the
## attributes that carry real weight in his role (a fifth of the core or
## more), and only if he sits in the bottom quarter of his role.
static func weakness(p: Dictionary) -> Dictionary:
	var core: Dictionary = Ratings.ROLE_WEIGHTS.get(str(p.get("role", "MID")), {})
	var worst := {}
	for key in core:
		if float(core[key]) < 0.2:
			continue
		var pct := percentile(p, key)
		if pct < WEAK_SHARE and (worst.is_empty() or pct < float(worst["pct"])):
			worst = {"key": key, "label": str(ATTR_LABELS.get(key, key)), "pct": pct}
	return worst


## "Inside midfielder", "Key forward", "Ruck"...: the training archetype of
## his role his attributes fit best.
static func player_type(p: Dictionary) -> String:
	var role := str(p.get("role", "MID"))
	if role == "RUCK":
		return "Ruck"
	var best := ""
	var best_score := -1.0
	for row in GameState.TRAIN_PLANS:
		if not row.has("weights") or not (row["roles"] as Array).has(role):
			continue
		var w: Dictionary = row["weights"]
		var total := 0.0
		var score := 0.0
		for key in w:
			score += float(w[key]) * percentile(p, key)
			total += float(w[key])
		score /= maxf(0.001, total)
		# A small forward stays small: a strong mark reads as a key forward.
		if str(row["key"]) == "small_fwd" and int((p["attr"] as Dictionary).get("marking", 0)) >= 52:
			score -= 0.15
		if score > best_score:
			best_score = score
			best = str(row["label"])
	return best if best != "" else role_word(role)


static func role_word(role: String) -> String:
	return {"MID": "Midfielder", "DEF": "Defender", "FWD": "Forward", "RUCK": "Ruck"}.get(role, "Player")


## The few numbers that say what he has done, per game, for his role.
## Established players: his real season. Prospects: his U18 / state-league
## season. Returns {"title", "line"}; line is "" when there is nothing to show.
static func production(p: Dictionary) -> Dictionary:
	var role := str(p.get("role", "MID"))
	if bool(p.get("projected", false)):
		var gm := int(p.get("u18_gm", 0))
		var bits: PackedStringArray = []
		var order := {
			"MID": [["u18_di", "disposals"], ["u18_tk", "tackles"], ["u18_mk", "marks"], ["u18_gl", "goals"]],
			"DEF": [["u18_di", "disposals"], ["u18_mk", "marks"], ["u18_tk", "tackles"]],
			"FWD": [["u18_gl", "goals"], ["u18_mk", "marks"], ["u18_di", "disposals"], ["u18_tk", "tackles"]],
			"RUCK": [["u18_ho", "hit-outs"], ["u18_di", "disposals"], ["u18_mk", "marks"]],
		}
		for pair in order.get(role, order["MID"]):
			var v := float(p.get(pair[0], 0.0))
			if v > 0.0:
				bits.append("%.1f %s" % [v, pair[1]])
		var where := str(p.get("draft_league", ""))
		var title := "%s season" % (where if where != "" else "U18")
		if gm > 0:
			title += ", %d %s" % [gm, "game" if gm == 1 else "games"]
		return {"title": title, "line": " · ".join(bits) + (" a game" if not bits.is_empty() else "")}
	var games := maxf(1.0, float(p.get("gm", 0)))
	var per := func(key: String) -> float:
		return float(p.get(key, 0)) / games
	var items := {
		"MID": [["di", "disposals"], ["cl", "clearances"], ["cp", "contested poss."], ["tk", "tackles"]],
		"DEF": [["di", "disposals"], ["rb", "rebound 50s"], ["onepct", "one percenters"], ["mk", "marks"]],
		"FWD": [["gl", "goals"], ["mi", "marks inside 50"], ["ga", "goal assists"], ["di", "disposals"]],
		"RUCK": [["ho", "hit-outs"], ["cl", "clearances"], ["di", "disposals"]],
	}
	var parts: PackedStringArray = []
	for pair in items.get(role, items["MID"]):
		var v: float = per.call(pair[0])
		if v >= 0.05:
			parts.append("%.1f %s" % [v, pair[1]])
	var year := str(p.get("src", "2026"))
	var title := "%s season, %d %s" % [year, int(p.get("gm", 0)), "game" if int(p.get("gm", 0)) == 1 else "games"]
	var line := " · ".join(parts) + (" a game" if not parts.is_empty() else "")
	if int(p.get("br", 0)) > 0:
		line += "  ·  %d Brownlow votes" % int(p["br"])
	return {"title": title, "line": line}


## Where a prospect comes from, in one line: "Ranked #4 · Sandringham
## Dragons (Talent League), VIC · 192 cm". "" for established players.
static func pedigree(p: Dictionary) -> String:
	if not bool(p.get("projected", false)):
		return ""
	var bits: PackedStringArray = []
	if int(p.get("draft_rank", 0)) > 0:
		bits.append("Ranked #%d in the %d class" % [int(p["draft_rank"]), int(p.get("draft_year", 2026))])
	var team := str(p.get("draft_team", ""))
	if team != "":
		var league := str(p.get("draft_league", ""))
		bits.append(team + (" (%s)" % league if league != "" else ""))
	if str(p.get("draft_state", "")) != "":
		bits.append(str(p["draft_state"]))
	if float(p.get("height_cm", 0.0)) > 0.0:
		bits.append("%d cm" % int(p["height_cm"]))
	return " · ".join(bits)
