class_name DraftNight
extends RefCounted
## Draft night's words (P-15, director 2026-10-18): the board's lines, the
## name read out on the stage, and the recruiter's one line on what the new
## man is. Presentation only: nothing here changes a pick.
##
## Every word comes from what anyone at the draft can see about a prospect:
## his height, his position, his age, where he played and his junior numbers
## (the production line on his card). Never his ratings, his potential or any
## other hidden figure, and never a grade, a rank or a verdict on the pick:
## the risk is the coach's, and the game does not mark his homework.

## Tall enough to play key position (RecruitMeeting.KEY_CM).
const KEY_CM := 192
## Small enough to be called small at his position.
const SMALL_FWD_CM := 180
const SMALL_DEF_CM := 182
## Tall enough that a recruiter says he will take time to grow into.
const TALL_CM := 194
## Fewer junior games than this and the recruiter says he was not seen much.
const THIN_GAMES := 8
## A year older than the bulk of the class.
const OVER_AGE := 19.0
const NUMBER_WORDS := ["", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]


## "Pick 12: Fremantle", the club on the clock on the board.
static func clock_line(pick_no: int, club: String) -> String:
	return "Pick %d: %s" % [pick_no, GameDB.club_name(club)]


## "Your pick: 14, two away", "Your pick: 14, next" or "You're on the clock";
## "" when you have no pick to come.
static func your_pick_line(yours: int, on_clock: int) -> String:
	if yours <= 0:
		return ""
	var gap := yours - on_clock
	if gap <= 0:
		return "You're on the clock"
	if gap == 1:
		return "Your pick: %d, next" % yours
	var away: String = NUMBER_WORDS[gap] if gap < NUMBER_WORDS.size() else str(gap)
	return "Your pick: %d, %s away" % [yours, away]


## Where he comes from, in words: "from the Sandringham Dragons", "from
## Claremont", "from Ireland" for a prospect from another country.
static func from_words(p: Dictionary) -> String:
	if InternationalProspects.is_international(p):
		var country := InternationalProspects.country_name(p)
		if country != "":
			return "from " + country
	var team := str(p.get("draft_team", p.get("club", ""))).strip_edges()
	if team == "":
		return ""
	return "from " + ("the " if _takes_the(team) else "") + team


## A junior side called by a plural nickname or an academy takes "the" (the
## Sandringham Dragons, the Suns Academy); a club by its place does not
## (Claremont, Swan Districts, Woodville-West Torrens).
static func _takes_the(team: String) -> bool:
	var words := team.split(" ")
	if words.size() < 2:
		return false
	var last := str(words[-1])
	if last in ["Academy", "Academies"]:
		return true
	return last.ends_with("s") and not last in ["Districts", "Torrens"]


## His position as a recruiter says it: "key forward", "small defender",
## "ruck", "midfielder". Height and listed position only.
static func position_words(p: Dictionary) -> String:
	var h := int(p.get("height_cm", 0))
	match str(p.get("role", "MID")):
		"RUCK":
			return "ruck-forward" if str(p.get("role2", "")) == "FWD" else "ruck"
		"FWD":
			if h >= KEY_CM:
				return "key forward"
			return "small forward" if h > 0 and h <= SMALL_FWD_CM else "forward"
		"DEF":
			if h >= KEY_CM:
				return "key defender"
			return "small defender" if h > 0 and h <= SMALL_DEF_CM else "defender"
	return "midfielder"


## The name read out: "Pick 14, Fremantle: Jed Walter, from the Sandringham
## Dragons, key forward".
static func announcement(pick_no: int, club: String, p: Dictionary) -> String:
	var parts: PackedStringArray = [GameDB.player_display_name(p)]
	var from := from_words(p)
	if from != "":
		parts.append(from)
	parts.append(position_words(p))
	return "Pick %d, %s: %s" % [pick_no, GameDB.club_name(club), ", ".join(parts)]


## The recruiter's one line: what kind of footballer he is, then the one
## thing to know about him, when there is one. `club` is the club taking him.
## "A key forward who kicks goals in bunches; key position players take time."
static func recruiter_line(p: Dictionary, club := "") -> String:
	var position := position_words(p)
	var article := "An" if position.left(1) in ["a", "e", "i", "o", "u"] else "A"
	var line := "%s %s %s" % [article, position, _what_he_does(p)]
	var more := _the_one_thing(p, club)
	if more != "":
		line += "; " + more
	return line + "."


## What he does, from his junior numbers per game (public on his card).
static func _what_he_does(p: Dictionary) -> String:
	var h := int(p.get("height_cm", 0))
	var goals := float(p.get("u18_gl", 0.0))
	var marks := float(p.get("u18_mk", 0.0))
	var touches := float(p.get("u18_di", 0.0))
	var tackles := float(p.get("u18_tk", 0.0))
	match str(p.get("role", "MID")):
		"FWD":
			if goals >= 2.0:
				return "who kicks goals in bunches"
			if goals >= 1.2:
				return "who finds the goals"
			if marks >= 5.0:
				return "who takes a strong mark"
			if h >= KEY_CM:
				return "who presents up the ground"
			return "who lives at ground level" if h > 0 and h <= SMALL_FWD_CM else "who works hard up the ground"
		"DEF":
			if h >= KEY_CM:
				return "who can go to a key forward"
			if marks >= 5.0:
				return "who reads it in the air"
			if touches >= 20.0:
				return "who runs it out of the back half"
			if tackles >= 4.0:
				return "who sticks to his man"
			return "who keeps it simple"
		"RUCK":
			if float(p.get("u18_ho", 0.0)) >= 20.0:
				return "who gives his midfielders first use"
			if marks >= 4.0:
				return "who marks around the ground"
			return "who is still learning the craft"
	if tackles >= 5.0 and touches >= 20.0:
		return "who wins his own ball and tackles hard"
	if tackles >= 5.0:
		return "who tackles hard"
	if touches >= 24.0:
		return "who finds plenty of the footy"
	if touches >= 18.0:
		return "who gets his hands on it"
	return "who runs both ways"


## The one thing to know, the most telling first: new to the game, barely
## seen, his tie to the club, older than the class, or a tall frame to fill.
static func _the_one_thing(p: Dictionary, club: String) -> String:
	if InternationalProspects.is_international(p):
		return "new to our game, so give him time"
	var games := int(p.get("u18_gm", 0))
	if games > 0 and games < THIN_GAMES:
		return "we only saw him a handful of times this year"
	if club != "" and str(p.get("tied_club", "")) == club:
		match str(p.get("tied_type", "")):
			"FS":
				return "his father played here"
			"NGA":
				return "he came through our academy"
	if _over_age(p):
		return "a year older than most of this class"
	if int(p.get("height_cm", 0)) >= TALL_CM and str(p.get("role", "")) in ["FWD", "DEF", "RUCK"]:
		return "key position players take time"
	return ""


## Older than the bulk of his own class: born a year earlier than an
## ordinary draftee of his draft year (a class drafted a year late is still
## measured against itself). No draft year or birth date: his age.
static func _over_age(p: Dictionary) -> bool:
	var dob := str(p.get("dob", ""))
	var year := int(p.get("draft_year", 0))
	if dob.length() >= 4 and dob.left(4).is_valid_int() and year > 0:
		return year - int(dob.left(4)) >= 19
	return float(p.get("age", 0.0)) >= OVER_AGE
