class_name StatGuide
extends RefCounted
## The in-game stat guide: what every rated stat is built from, what it
## actually does in a match, and how ratings, potential, XP and training plans
## fit together. Numbers here are read straight from the engine
## (MatchSim.gd, Squad.gd, Ratings.gd): keep them in step if those change.

## key -> [short, built_from, in_matches, who_needs_it]
const STATS := {
	"disposal": [
		"Wins the ball in general play and lifts your midfield's contest.",
		"Disposals per game, plus contested possessions and clearances.",
		"Decides who gets the ball between the arcs (midfielders, rucks and defenders are picked in proportion to disposal, squared). Your midfield's average is 22% of team Contest.",
		"Midfielders first; rebounding defenders.",
	],
	"contested": [
		"Wins clearances and keeps the ball when tackled.",
		"Contested possessions, clearances and the contested share of a player's ball.",
		"Picks who wins the clearance at a stoppage, and a tackled player with high contested keeps the ball far more often (0.75x to 1.25x). Your midfield's average is 42% of team Contest - the single biggest input to winning stoppages.",
		"Inside midfielders.",
	],
	"marking": [
		"Marks kicks, and wins the big contested marks inside 50.",
		"Marks, contested marks and marks inside 50 per game.",
		"Raises the chance a kick is marked (0.75x to 1.25x) and makes a player kick rather than handball. Your forwards' average is 14% of Attack and decides forward-50 marking contests against the opposition's intercept.",
		"Key forwards and key defenders.",
	],
	"pressure": [
		"Tackles, and forces turnovers as a defensive unit.",
		"Tackles and one-percenters per game.",
		"Picks who makes the tackles. Your defenders' average is 50% of Defence and sets how often the opposition gets tackled (0.72x to 1.28x).",
		"Defenders, small forwards, inside midfielders.",
	],
	"intercept": [
		"Wins the ball back in defence and spoils forward entries.",
		"Rebound 50s, marks and one-percenters per game.",
		"Picks who gets the ball deep in your defence. Your defenders' average is 32% of Defence, contests marks inside 50 and sets the chance of a spoil (30% to 65%).",
		"Key defenders and interceptors.",
	],
	"carry": [
		"Gains ground with the ball and drives it inside 50.",
		"Inside 50s, bounces and disposals per game.",
		"Metres gained per possession (0.55x to 1.45x) and who carries the ball through the midfield. Your midfield's average is 26% of Attack.",
		"Outside midfielders and running defenders.",
	],
	"goalkicking": [
		"Gets the shots inside 50 and kicks goals from them.",
		"Goals and marks inside 50 per game.",
		"Picks the shooter inside 50 (weighted strongly toward the best kick), lifts the goal chance (0.80x to 1.20x) and scoring shots. Your forwards' average is 40% of Attack - the biggest input to scoring.",
		"Forwards, goal-kicking midfielders.",
	],
	"accuracy": [
		"Turns shots into goals rather than behinds.",
		"Goals as a share of scoring shots, with a small sample pulled toward average.",
		"Multiplies the shooter's goal chance (0.82x to 1.18x).",
		"Anyone who takes shots - forwards most.",
	],
	"creating": [
		"Sets up goals for others; the forward line's playmaking.",
		"Goal assists, inside 50s and marks inside 50 per game.",
		"Your forwards' average is 20% of Attack, which lifts every shot your side takes.",
		"Small and medium forwards.",
	],
	"ruck": [
		"Wins the hit-outs at every bounce and ball-up.",
		"Hit-outs, plus clearances and contested marks.",
		"Your starting ruck's rating decides your share of the hit-outs (15% to 85%) and is 24% of team Contest.",
		"Rucks only - but every side fields one.",
	],
	"discipline": [
		"Avoids clangers and free kicks against. Higher is cleaner.",
		"Clangers and free kicks against per game, inverted (fewer = higher).",
		"A low-discipline player is far more likely to be the one who gives away a clanger, and some clangers become free kicks and turnovers. The team average is 18% of Defence.",
		"Everyone; midfielders handle the ball most.",
	],
	"durability": [
		"Stays on the park: fewer injuries.",
		"Games played and time on ground.",
		"Every player who takes the field risks an injury; durability scales the chance from about half the base rate (99) to about 1.3x (low). Injured players miss 1 to 16 weeks. It is also 8% of the overall rating.",
		"Everyone - your stars most of all.",
	],
	"star": [
		"Match-winning class: the rating's biggest single piece.",
		"Brownlow votes per game, plus disposals.",
		"The average of your top five star ratings is 12% of team Contest. It is 22% of every player's overall, which drives selection, draft price and the Through stars game plan (82+ overall players get 12% more of the ball).",
		"Your best few players; it is how ratings climb fastest.",
	],
}

const TOPICS := [
	["Overall (OVR)", "A player's rating: 70% the stats his position relies on, 22% star power and 8% durability. Defender, forward and ruck scales are stretched so the elite of every position reach the high 80s. It decides selection (the best by position take the field) and draft price. The match itself rolls the individual stats, not OVR."],
	["Team strengths", "Contest (who wins stoppages): 42% midfield contested, 24% ruck, 22% midfield disposal, 12% top-five star. Attack: 40% forward goalkicking, 26% midfield carry, 20% forward creating, 14% forward marking. Defence: 50% defender pressure, 32% defender intercept, 18% team discipline."],
	["Potential (POT)", "The rating a player can grow into, from his age, his best recent season and his draft pick. Each off-season, players 28 and under close part of the gap. A star coming back from an injury-shortened season gets a rehab year and closes most of it at once."],
	["Injuries", "After every game each player who took the field has a small chance of injury, lower with high durability. Most are 1-2 weeks, the odd one ends a season. Injured players sit out automatically (your selection's gaps are filled), and everyone heals over the off-season."],
	["Traits and synergies", "A player with a standout stat earns a trait (up to two, plus Hothead for poor discipline): Sharpshooter, Crumber, Contested bull, Interceptor and more, each with one match effect. Traits come and go with the stats, so training can unlock one - the player screen says how close he is. The right mix in a line switches on a synergy, such as the Engine room (two contested bulls) or a Tall-small forward line; the Team screen shows yours and the nearest to finish."],
	["Legs and rotations", "Players tire on the ground and recover on the bench; tired players win less ball and kick fewer goals, and a tired midfield loses stoppages. Durability sets how fast a player tires. Pick a rotation policy in the coach box: rotate hard, normal, or ride your stars."],
	["Match moments", "In a live match the game stops for your call: a set shot (take it, play on or bomb it long - with the odds), a star running on empty, a forward kicking a bag, a run of goals against, a tight last-quarter bounce. After each quarter, 'What your calls did' shows the points each decision added or cost."],
	["The board and morale", "Each season the board sets a goal from where your list ranks, and every result moves its confidence. Miss the goal and confidence drops; end a season under 30% and you get a final warning - do it again and you are sacked. Players' morale rises with games and wins and falls when they are left out fit (stars most): it nudges their form a little, and an unhappy player asks 25% more to re-sign. Most weeks bring a decision on the hub - answer it, or it takes the default when the round is played."],
	["Contracts", "Every player has a contract and a salary counted against the cap. After the Grand Final, Trades & Contracts opens: re-sign or release players whose deals are up, sign free agents, and offer trades. Rival clubs value trades by rating, potential and age, and pay more for positions they are short in."],
	["XP and cost", "Every player on your list earns XP each game: more for playing, more for a big game. A stat point costs more the higher the stat already is, up to half price while a player is below his POT and 50% dearer once he is past it. 99 is the cap."],
	["Training plans", "Each player follows a plan that spends his XP automatically after every game. The club plan applies to anyone without his own. Position plan trains what his position needs (the same priorities rival clubs use); the role plans and single-stat focuses let you shape him; Manual banks XP for you to spend. Change a plan at any time - banked XP is spent straight away."],
]


static func short(key: String) -> String:
	return str((STATS.get(key, [""]) as Array)[0])


## Open the guide as a modal over `parent`. Returns the overlay so the scene
## can close it from the back button.
static func show(parent: Control) -> Control:
	var box := UiKit.modal_box(parent, 720.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "StatGuide"
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.heading("STAT GUIDE", 26))
	for topic in TOPICS:
		v.add_child(UiKit.lbl(str(topic[0]), 16, UiKit.GOLD, true))
		v.add_child(_para(str(topic[1]), 13, UiKit.TEXT))
	v.add_child(UiKit.spacer(6))
	v.add_child(UiKit.heading("THE 13 STATS", 22))
	for row in GameState.TRAIN_STATS:
		var key := str(row[0])
		var info: Array = STATS.get(key, [])
		if info.size() < 4:
			continue
		var card := UiKit.panel(UiKit.PANEL_ALT, 8, 6)
		card.name = "Guide_" + key
		var cv := UiKit.vbox(3)
		card.add_child(cv)
		cv.add_child(UiKit.lbl(str(row[1]), 16, UiKit.GOLD, true))
		cv.add_child(_para(str(info[0]), 13, UiKit.TEXT))
		cv.add_child(_para("In matches: " + str(info[2]), 12, UiKit.TEXT))
		cv.add_child(_para("Built from: " + str(info[1]), 12, UiKit.MUTED))
		cv.add_child(_para("Who needs it: " + str(info[3]), 12, UiKit.MUTED))
		v.add_child(card)
	var ok := UiKit.btn("Got it", 17, true)
	ok.name = "CloseStatGuide"
	ok.custom_minimum_size = Vector2(0, 44)
	ok.pressed.connect(func(): overlay.queue_free())
	box["footer"].add_child(ok)
	return overlay


static func _para(text: String, size: int, colour: Color) -> Label:
	var l := UiKit.lbl(text, size, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
