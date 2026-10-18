class_name Features
extends RefCounted
## Feature switches (director, 2026-10-14: "Fixes as they land, features at
## 0.2.0"). A feature that is merged but not finished stays hidden from
## players behind one named switch here until its patch is ready and he has
## played it. With a switch off the game behaves exactly as it did before
## the feature existed, and writes none of its state.
##
## A switch is ON when any of these says so, in this order:
##   1. code forced it (set_on): the feature's own tests, capture tools and
##      audits turn it on for themselves;
##   2. the command line names it after "--": a dev run,
##        godot --path . -- --features preseason
##      (several: --features preseason,other);
##   3. the project setting features/<name> is true (project.godot). This is
##      what an exported build reads, and it ships FALSE.
## Otherwise it is OFF: every exported build, every test suite that does not
## ask for it, and a plain editor run.
##
## Switches:
##   preseason   the eight-week pre-season between the wrap and Round 1
##               (PreSeason.gd, PreSeasonScene), and everything built on it
##               for patch 0.2.0 (the pre-season match comes next).
##   speccy_front   the low, tight front-on speccy shot that freezes on the grab
##               (BroadcastVignette). Off, a spectacular mark plays the earlier shot.
##   international_prospects   one or two prospects from Ireland, New Zealand, the USA
##               and Africa in each generated draft class (InternationalProspects.gd),
##               and their story beats. Off, generated classes are exactly as before.
##   training_report   the report after every fourth round: who improved, who
##               fell back, and who can learn a new position (TrainingReport.gd).
##   expansion_package   how a new club builds its list (director, 2026-10-14):
##               state-league signings, early draft picks, one out-of-contract
##               player per rival club, and Canberra as a career choice
##               (ExpansionBuild). Off, a new club arrives with the 36
##               generated players it always did and Canberra always joins.

const KNOWN := ["preseason", "speccy_front", "training_report", "international_prospects", "expansion_package"]

static var _forced := {}
static var _from_args := {}
static var _args_read := false


static func on(feature: String) -> bool:
	if _forced.has(feature):
		return bool(_forced[feature])
	if not _args_read:
		_read_args()
	if _from_args.has(feature):
		return true
	return bool(ProjectSettings.get_setting("features/" + feature, false))


## Force a switch for this run (tests, capture tools, audits).
static func set_on(feature: String, value: bool) -> void:
	_forced[feature] = value


## Back to what the command line and the project setting say.
static func clear(feature: String) -> void:
	_forced.erase(feature)


static func _read_args() -> void:
	_args_read = true
	var a := OS.get_cmdline_user_args()
	for i in range(a.size()):
		var names := ""
		if str(a[i]) == "--features" and i + 1 < a.size():
			names = str(a[i + 1])
		elif str(a[i]).begins_with("--features="):
			names = str(a[i]).substr(11)
		for n in names.split(",", false):
			if KNOWN.has(n.strip_edges()):
				_from_args[n.strip_edges()] = true
