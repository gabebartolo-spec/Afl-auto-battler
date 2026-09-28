class_name Coaches
extends RefCounted
## The coaching world: six jobs at every club and one record per coach.
## Pure rules and the Round 1 2026 seed; GameState keeps the records.
##
## One canonical record per coach, in GameState.coaches[cid]. A club's staff
## is never stored: it is read from each record's club and job, so a coach
## can never exist twice (a save writes plain dictionaries by value, and a
## second copy would load as a second coach). Records use cid / skills / job,
## never the id + attr + role that CareerSave takes for a player.
##
##   cid              C_<slug> seeded, C_G<year>_<n> generated, C_P_<player id>
##                    for a future ex-player
##   real_name        the real person ("" for a generated coach)
##   generic_name     his fictional name (an ex-player keeps his player alias)
##   former_player_id the player he was, "" when he was not one of ours
##   skills           {teach, tactics, manage}, 55-92, never shown as numbers
##   spec             MID / RUCK / FWD / DEF / DEV, or "" for the whole game
##   status           club (in a job), free (available), away (working
##                    outside an AFL coaching job), out (unavailable)
##   club, job        where he coaches ("" when not at a club)
##   free_from        the first year an "out" coach is available
##   stints           [[club, job, from, to], ...]; to 0 = still there. A
##                    seeded stint starts at Round 1 2026: what came before
##                    is not claimed.
##   former_sc        he coached an AFL club before 2026
##   note             what an away or out coach is doing, in words
##   origin           seed / generated
##   played           the playing career of a future ex-player coach
##
## Skills do nothing yet: they are read only to describe a coach.

const SEED_CSV := "res://data/coaches_2026.csv"
const START_YEAR := 2026

const JOBS := ["SC", "SA", "MID", "FWD", "DEF", "DEV"]
const JOB_LABEL := {
	"SC": "Senior coach", "SA": "Senior assistant", "MID": "Midfield & ruck",
	"FWD": "Forwards", "DEF": "Defence", "DEV": "Development",
}
const SPEC_LABEL := {
	"MID": "Midfield", "RUCK": "Ruck", "FWD": "Forwards", "DEF": "Defence",
	"DEV": "Development", "": "Whole game",
}
const SKILLS := ["teach", "tactics", "manage"]
const SKILL_LABEL := {"teach": "Teaching", "tactics": "Tactics", "manage": "Man-management"}
## What a coach in each job is known for, as a noun ("a strong teacher").
const SKILL_NOUN := {"teach": "teacher", "tactics": "tactician", "manage": "man-manager"}
## The skill a job leans on most: the one a staff row mentions.
const JOB_SKILL := {"SC": "tactics", "SA": "manage", "MID": "teach", "FWD": "teach",
		"DEF": "teach", "DEV": "teach"}

## Grades, highest first. Provisional: tuned to the seeded spread (most
## coaches Good, a quarter Strong or better, a handful Elite).
const GRADES := [[86, "Elite"], [78, "Strong"], [68, "Good"], [0, "Fair"]]

## Role fit: how the three skills weigh in each job.
const FIT_WEIGHTS := {
	"SC": {"tactics": 0.45, "manage": 0.35, "teach": 0.20},
	"SA": {"tactics": 0.35, "manage": 0.35, "teach": 0.30},
	"MID": {"teach": 0.60, "tactics": 0.25, "manage": 0.15},
	"FWD": {"teach": 0.60, "tactics": 0.25, "manage": 0.15},
	"DEF": {"teach": 0.60, "tactics": 0.25, "manage": 0.15},
	"DEV": {"teach": 0.70, "manage": 0.30},
}
## The specialties each line job is built for, and what fit costs without.
const LINE_SPECS := {"MID": ["MID", "RUCK"], "FWD": ["FWD"], "DEF": ["DEF"]}
const LINE_MISMATCH := 8.0
const DEV_LINE_SPEC := 3.0
const DEV_WHOLE_GAME := 6.0

## Coaches' fictional first names: never one a player can have, so a coach
## and a player never share a name. Surnames come from GameDB's list.
const COACH_FIRST_NAMES := ["Alder", "Ansel", "Bastian", "Brannock", "Caddo", "Corvin",
		"Dallin", "Denholm", "Emrys", "Everard", "Faulk", "Garnet", "Harlow", "Ismay",
		"Jessop", "Keir", "Lorne", "Merrick", "Nevin", "Orrin", "Pell", "Quinlan", "Rook",
		"Soren", "Thane", "Ulick", "Vance", "Wyatt", "Yarrow", "Zeb", "Barnaby", "Cuthbert"]
const COACH_NAME_SEED := 51_2026


static func grade(v) -> String:
	for g in GRADES:
		if float(v) >= float(g[0]):
			return str(g[1])
	return "Fair"


static func skill(c: Dictionary, key: String) -> int:
	return int((c.get("skills", {}) as Dictionary).get(key, 0))


## How well he suits a job, on the skills' scale: the job's blend of his
## skills, less a penalty when his specialty is not the job's line.
static func role_fit(c: Dictionary, job: String) -> float:
	var w: Dictionary = FIT_WEIGHTS.get(job, {})
	var fit := 0.0
	for k in w:
		fit += float(w[k]) * float(skill(c, k))
	var spec := str(c.get("spec", ""))
	if LINE_SPECS.has(job) and not (LINE_SPECS[job] as Array).has(spec):
		fit -= LINE_MISMATCH
	elif job == "DEV" and spec != "DEV":
		fit -= DEV_WHOLE_GAME if spec == "" else DEV_LINE_SPEC
	return fit


## "Strong teacher": the grade of the skill his job leans on.
static func headline(c: Dictionary) -> String:
	var key := str(JOB_SKILL.get(str(c.get("job", "")), "teach"))
	return "%s %s" % [grade(skill(c, key)), SKILL_NOUN[key]]


## A club's staff: job -> cid, read from the records.
static func staff(coaches: Dictionary, club: String) -> Dictionary:
	var out := {}
	for cid in coaches:
		var c: Dictionary = coaches[cid]
		if str(c.get("status", "")) == "club" and str(c.get("club", "")) == club:
			out[str(c["job"])] = str(cid)
	return out


## Where he is now, in words: "Forwards coach, Carlton", "Available", ...
static func whereabouts(c: Dictionary) -> String:
	match str(c.get("status", "")):
		"club":
			var job := str(c.get("job", ""))
			var label := str(JOB_LABEL.get(job, job))
			if job != "SC" and job != "SA":
				label += " coach"
			return "%s, %s" % [label, GameDB.club_name(str(c.get("club", "")))]
		"free":
			return "Available"
		"out":
			return str(c.get("note", "")) if str(c.get("note", "")) != "" \
					else "Unavailable until %d" % int(c.get("free_from", 0))
		_:
			return str(c.get("note", "Working outside AFL coaching"))


## The Round 1 2026 coaching world for a career at `my_club`: every seeded
## coach, with that club's real senior coach moved out of the job you now
## hold. Deterministic: the same seed file gives the same records and names.
static func seed(my_club: String) -> Dictionary:
	var rows := _read_seed()
	var names := _alias_pool()
	var out := {}
	for i in range(rows.size()):
		var r: Dictionary = rows[i]
		var cid := str(r["cid"])
		var status := str(r["status"])
		var club := str(r["club"])
		var job := str(r["job"])
		var c := {
			"cid": cid,
			"real_name": str(r["name"]),
			"generic_name": str(names[i % names.size()]),
			"former_player_id": "",
			"skills": {"teach": int(r["teach"]), "tactics": int(r["tactics"]),
					"manage": int(r["manage"])},
			"spec": str(r["spec"]),
			"status": status,
			"club": club,
			"job": job,
			"free_from": int(r["free_from"]),
			"stints": [],
			"former_sc": int(r["former_sc"]) == 1,
			"note": str(r["note"]),
			"origin": str(r["origin"]),
			"played": {},
		}
		if status == "club":
			(c["stints"] as Array).append([club, job, START_YEAR, 0])
		# You are this club's senior coach: the real one is free to be hired.
		if status == "club" and club == my_club and job == "SC":
			c["status"] = "free"
			c["club"] = ""
			c["job"] = ""
			c["former_sc"] = true
			c["stints"] = [[club, "SC", START_YEAR, START_YEAR]]
			c["note"] = ""
		out[cid] = c
	return out


static func _read_seed() -> Array:
	var f := FileAccess.open(SEED_CSV, FileAccess.READ)
	if f == null:
		push_warning("Coaches: cannot read %s" % SEED_CSV)
		return []
	var header := f.get_csv_line()
	var out := []
	while not f.eof_reached():
		var cells := f.get_csv_line()
		if cells.size() < header.size():
			continue
		var r := {}
		for j in range(header.size()):
			r[str(header[j])] = cells[j]
		out.append(r)
	return out


## Every coach alias, in a fixed shuffled order: coach first names with the
## players' surnames. Fixed seed, so a seeded coach's alias never changes.
static func _alias_pool() -> Array:
	var pool := []
	for first in COACH_FIRST_NAMES:
		for last in GameDB.FICTIONAL_LAST_NAMES:
			pool.append("%s %s" % [first, last])
	var rng := RandomNumberGenerator.new()
	rng.seed = COACH_NAME_SEED
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	return pool
