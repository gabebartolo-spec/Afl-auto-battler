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
	["Overall (OVR)", "A player's rating: mostly the stats his position relies on, then star power, with a little for durability. Defender, forward and ruck scales are stretched so the elite of every position reach the high 80s. It decides selection (the best by position take the field) and draft price. In a match it is the individual stats that count, not OVR."],
	["Team strengths", "Contest is who wins the stoppages: your inside midfielders first, then your ruck and midfield ball use, with a little from your top stars. Attack is your forwards' goalkicking first, then your midfield's carry and your forwards' creating and marking. Defence is your defenders' pressure first, then their intercept, with some from a disciplined side."],
	["Potential (POT)", "Where a player is projected to peak, from his age, his best recent season and his draft pick. It is a projection, not a limit, and it does not change. Each off-season, players 28 and under close part of the gap. Development gets harder near POT and much harder past it, for every club alike; now and then a player breaks out beyond it. A star coming back from an injury-shortened season gets a rehab year and closes most of the gap at once."],
	["Injuries", "After every game each player who took the field has a small chance of injury, lower with high durability. Most are 1-2 weeks, the odd one ends a season. Injured players sit out automatically (your selection's gaps are filled), and everyone heals over the off-season."],
	["Traits and synergies", "A player with a standout stat earns a trait (up to two, plus Hothead for poor discipline): Sharpshooter, Crumber, Contested bull, Interceptor and more, each with one match effect. Traits come and go with the stats, so training can unlock one - the player screen says how close he is. The right mix in a line switches on a synergy, such as the Engine room (four contested bulls) or a Tall-small forward line; the Team screen shows yours, and says when one is a single player short (\"Lockdown unit: 1 lockdown player short\")."],
	["Legs and rotations", "Players tire on the ground and recover on the bench; tired players win less ball and kick fewer goals, and a tired midfield loses stoppages. Durability sets how fast a player tires. Pick a rotation policy in the coach box: rotate hard, normal, or ride your stars."],
	["Match moments", "In a live match the game stops for your call: a set shot (take it, play on or bomb it long - with the odds), a star running on empty, a forward kicking a bag, a run of goals against, a tight last-quarter bounce. After each quarter, 'What your calls did' says what followed each call."],
	["The board and morale", "Each season the board sets a goal from where your list ranks, and every result moves its confidence. Miss the goal and confidence drops; end a season well short and you get a final warning - do it again and you are sacked. Players' morale rises with games and wins and falls when they are left out fit (stars most): it nudges their form a little, and an unhappy player asks for more to re-sign. Most weeks bring a decision on the hub - answer it, or it takes the default when the round is played."],
	["Weather", "Every match has a forecast, on the hub during the week: a perfect day, wet, windy or hot, from the ground and the time of year (the roofed stadium is always dry). Wet: fewer marks, more tackles, more turnovers, a little less accuracy; Win contest and the press get more from their plan, Attack corridor much less, Controlled tempo a little less. Windy: fewer marks and more turnovers, one end has the breeze (shots with it are a little easier, against it much harder) and the sides change ends each quarter; Controlled tempo gets more from its plan, the attacking plans less. Hot: freer, faster football and heavier legs late; the attacking plans get more, the press less. On a perfect day every plan plays as written."],
	["Team form", "Every club's last five results set its form, from Cold through Steady to Hot; the latest game counts most and the one before it a little less. Five straight wins is the cap, a sixth adds nothing, and one loss ends a five-game streak at Good. Form gives a small edge in composure (a few fewer clangers) and at stoppages (a slice of home-ground advantage): at the top, a side wins only a few more games in a hundred than it would at Steady. It resets every season. The hub shows yours and your next opponent's."],
	["Contracts", "Every player has a contract and a salary counted against the cap. After the Grand Final, Trades & Contracts opens: re-sign or release players whose deals are up, sign free agents, and offer trades. Rival clubs value trades by rating, potential and age, and pay more for positions they are short in."],
	["XP and cost", "Every player on your list earns XP each game: more for playing, more for a big game. A fit player left out of the 23 plays in the reserves and earns half a full senior game; injured or rested players earn only the squad share. A stat point costs more the higher the stat already is, up to half price while a player is well below his POT, dearer close to it, and steeply dearer for every point past it. 99 is the cap."],
	["Training plans", "Each player's plan is the kind of footballer he develops into, and it spends his XP after every game on what that job needs in a match. Position plan (the default, and what rival clubs use) trains what his position is judged on. The role plans lean him toward one job: inside or outside midfielder, key or small defender, key or small forward. Manual pauses his development - XP banks until you spend it by hand, and banked XP does not make him better. Change a plan at any time; banked XP is spent straight away. A player can also learn another position: 8 weeks training as, say, a key forward instead of in his own position (for the rest of that season, training in his own position can lift him only 2 more), and if he ends within 3 of his own rating there he can be picked there too - picked there whenever he is the better player for the spot. The season after, his training can lift him 1 more than usual, never past his POT. The job follows his size - key forward, key defender and ruck take height, small forwards and small defenders are small - and it takes POT 70 for a second position and 90 for a third. One a season per player, two at a time per club; rival clubs learn positions too, one player a season. A player who can play forward, midfield and back is a Unicorn."],
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
		cv.add_child(UiKit.lbl(str(row[1]), UiKit.NAME, UiKit.EMPH, true))
		cv.add_child(_para(str(info[0]), 13, UiKit.TEXT))
		cv.add_child(_para("In matches: " + str(info[2]), 12, UiKit.TEXT))
		cv.add_child(_para("Built from: " + str(info[1]), 12, UiKit.MUTED))
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
