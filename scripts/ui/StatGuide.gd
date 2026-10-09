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
		"The better the disposal, the more of the ball a player gets between the arcs. A midfield full of good users wins more of the contest for your side.",
		"Midfielders first; small defenders.",
	],
	"contested": [
		"Wins clearances and keeps the ball when tackled.",
		"Contested possessions, clearances and the contested share of a player's ball.",
		"Wins the clearance at a stoppage, and a tackled player with high contested keeps the ball far more often. Your inside midfielders are what win or lose the stoppages.",
		"Inside midfielders.",
	],
	"marking": [
		"Marks kicks, and wins the big contested marks inside 50.",
		"Marks, contested marks and marks inside 50 per game.",
		"More of his kicks are marked, and he is more willing to kick than handball. Your forwards' marking decides the marking contests inside 50 against the other side's intercept defenders.",
		"Key forwards and key defenders.",
	],
	"pressure": [
		"Tackles, and forces turnovers as a defensive unit.",
		"Tackles and one-percenters per game.",
		"He lays the tackles. Pressure from your defenders is the biggest part of how well you defend, and it decides how often the other side is tackled.",
		"Defenders, small forwards, inside midfielders.",
	],
	"intercept": [
		"Wins the ball back in defence and spoils forward entries.",
		"Rebound 50s, marks and one-percenters per game.",
		"He gets the ball deep in your defence, takes on the marking contests inside 50 and decides how often a spoil comes off.",
		"Key defenders and interceptors.",
	],
	"carry": [
		"Gains ground with the ball and drives it inside 50.",
		"Inside 50s, bounces and disposals per game.",
		"How much ground a possession gains, and who runs the ball through the midfield. Good carriers in your midfield feed your attack.",
		"Outside midfielders and running defenders.",
	],
	"goalkicking": [
		"Gets the shots inside 50 and kicks goals from them.",
		"Goals and marks inside 50 per game.",
		"The best kicks get the shots inside 50, and they kick more goals from them. Your forwards' goalkicking is the biggest part of how well you score.",
		"Forwards, goal-kicking midfielders.",
	],
	"accuracy": [
		"Turns shots into goals rather than behinds.",
		"Goals as a share of scoring shots, with a small sample pulled toward average.",
		"A better kick turns more shots into goals instead of behinds.",
		"Anyone who takes shots - forwards most.",
	],
	"creating": [
		"Sets up goals for others; the forward line's playmaking.",
		"Goal assists, inside 50s and marks inside 50 per game.",
		"Good creators across your forward line make better shots for everyone.",
		"Small and medium forwards.",
	],
	"ruck": [
		"Wins the hit-outs at every centre ball-up and stoppage.",
		"Hit-outs, plus clearances and contested marks.",
		"Your starting ruck decides how many hit-outs you win, and it is a big part of how you go at the stoppages.",
		"Rucks only - but every side fields one.",
	],
	"discipline": [
		"Avoids clangers and free kicks against. Higher is cleaner.",
		"Clangers and free kicks against per game, inverted (fewer = higher).",
		"A low-discipline player is far more likely to give away a clanger, and some become free kicks and turnovers against you. A clean team defends better.",
		"Everyone; midfielders handle the ball most.",
	],
	"durability": [
		"Stays on the park: fewer injuries.",
		"Games played and time on ground.",
		"Every player risks an injury when he takes the field. A durable player gets hurt about half as often as an average one, a fragile one more. Injured players miss anything from a week to most of a season.",
		"Everyone - your stars most of all.",
	],
	"star": [
		"Match-winning class: the rating's biggest single piece.",
		"Brownlow votes per game, plus disposals.",
		"Your best five stars lift your side at the stoppages. It is also a big part of every player's overall, which drives selection and draft price, and the Through stars game plan goes through your best three.",
		"Your best few players; it is how ratings climb fastest.",
	],
}

const TOPICS := [
	["Overall (OVR)", "A player's rating, built mostly from the stats his position relies on. It decides selection and draft price. In a match it is the individual stats that count."],
	["Team strengths", "Contest is who wins the stoppages. Attack is your forwards' goalkicking and your midfield's carry. Defence is your defenders' pressure and intercept."],
	["Potential (POT)", "Where a player is projected to peak. It is a projection, not a limit, and it never changes. Players 28 and under close part of the gap each off-season."],
	["Injuries", "Anyone who takes the field can get hurt, less often with high durability. Most miss a week or two. Gaps in your side are filled for you, and everyone heals in the off-season."],
	["Traits and synergies", "A standout stat earns a trait with one match effect. The right mix in a line switches on a synergy, like Engine room. The Team screen says when one is a single player short ('Lockdown unit: 1 lockdown player short')."],
	["Legs and rotations", "Players tire on the ground and recover on the bench. Tired players win less ball and kick fewer goals. Set your rotation policy in the coach box."],
	["Match moments", "The game stops for your call at big moments: a set shot, a tired star, a forward kicking a bag. After each quarter, 'What your calls did' says what followed."],
	["The board and morale", "The board sets a goal each season and judges every result; miss it badly twice and you are sacked. Morale rises with games and wins and falls when a fit player is left out. It nudges form and re-signing."],
	["Weather", "Each match has a forecast on the hub. Wet: fewer marks, more turnovers; Win contest and the press gain, Attack corridor loses. Windy: one end has the breeze. Hot: faster football, heavier legs late."],
	["Team form", "A club's last five results set its form, Cold to Hot, the latest game counting most. It gives a small edge at the stoppages and in composure, and resets each season."],
	["Contracts", "Every player has a contract counted against the cap. After the Grand Final you re-sign or release, sign free agents and trade."],
	["XP and cost", "Players earn XP each game, more for playing and for a big game. A fit player left out earns half in the reserves. Stat points cost more the higher the stat, and 99 is the cap."],
	["Training plans", "A plan is the kind of footballer a player develops into, and it spends his XP on what that job needs. Position plan is the default; Manual banks XP until you spend it. He can also spend 8 weeks learning another position, and is picked there if he ends within 3 of his own rating."],
]


static func short(key: String) -> String:
	return str((STATS.get(key, [""]) as Array)[0])


## Open the guide as a modal over `parent`. Returns the overlay so the scene
## can close it from the back button.
static func show(parent: Control) -> Control:
	var box := UiKit.modal_box(parent, 720.0, 0.0)
	var overlay: Control = box["overlay"]
	overlay.name = "StatGuide"
	UiKit.close_on_outside_tap(box)
	var v: VBoxContainer = box["body"]
	v.add_child(UiKit.heading("Stat guide", UiKit.H1))
	for topic in TOPICS:
		v.add_child(UiKit.lbl(str(topic[0]), UiKit.NAME, UiKit.EMPH, true))
		v.add_child(_para(str(topic[1]), 13, UiKit.TEXT))
	v.add_child(UiKit.spacer(6))
	v.add_child(UiKit.heading("The 13 stats", UiKit.H1))
	for row in GameState.TRAIN_STATS:
		var key := str(row[0])
		var info: Array = STATS.get(key, [])
		if info.size() < 4:
			continue
		var card := UiKit.panel(UiKit.PANEL_ALT, 8, 6)
		card.name = "Guide_" + key
		var cv := UiKit.vbox(3)
		card.add_child(cv)
		cv.add_child(UiKit.lbl(str(row[1]), UiKit.NAME, UiKit.EMPH, true))
		cv.add_child(_para(str(info[0]), 13, UiKit.TEXT))
		# What it is and who needs it: the rest (what it is built from, how it
		# plays out in a match) stays in STATS for the places that want it.
		cv.add_child(_para("Who needs it: " + str(info[3]), 12, UiKit.MUTED))
		v.add_child(card)
	var ok := UiKit.btn("Got it", UiKit.NAME, true)
	ok.name = "CloseStatGuide"
	ok.custom_minimum_size = Vector2(0, 44)
	ok.pressed.connect(func(): overlay.queue_free())
	box["footer"].add_child(ok)
	return overlay


static func _para(text: String, size: int, colour: Color) -> Label:
	var l := UiKit.lbl(text, size, colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
