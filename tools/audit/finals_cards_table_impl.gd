extends RefCounted
## The finals and Grand Final cards as the coach reads them: title, text, and for each choice its label,
## its Gain and Cost lines and its result line, as markdown rows for the PR. No args.
## Measurement only: it never changes a rule.

const IDS := ["finals_in", "finals_gone", "finals_last_season", "finals_first_final", "finals_week_off",
		"finals_second_chance", "finals_fitness_test", "finals_family_tickets", "finals_club_greats",
		"finals_captain_last_word", "gf_the_opponent", "gf_last_game", "gf_debut_year", "gf_racing_the_clock",
		"gf_milestone", "gf_week"]


func run() -> void:
	GameState.reset()
	GameState.career_seed = 7
	GameState.replay_seed = 7
	GameState.start_season("FRE", GameDB.club_list("FRE"))
	var p: Dictionary = GameState.my_list[4]
	p["career"] = {"games": 199, "goals": 3, "stints": [["FRE", 2018, 2026, 199, 3]], "through": 2026, "unknown": []}
	var overs := {
		"finals_week_off": {"finals_bye": true, "finals_week": 3},
		"gf_the_opponent": {"gf_run": 1, "gf_again": "", "rival": false, "opp": "Collingwood", "finals_week": 5},
	}
	for id in IDS:
		var t := StoryDeck.by_id(StoryDeck.all(), id)
		var ctx: Dictionary = ClubStories.context(GameState)
		var club: Dictionary = (ctx["club"] as Dictionary).duplicate()
		club.merge(overs.get(id, {}), true)
		club["finals_week"] = int(club.get("finals_week", 0))
		var subj := {"kind": "club"}
		if str((t["subject"] as Dictionary).get("kind", "")) == "player":
			subj = ClubStories.player_fact(GameState, p, true, {}, 2, 0, 2)
			subj["games"] = 250
			subj["milestone_next"] = 200
			subj["delegate_holds"] = true
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var card := StoryEngine.build(StoryDeck.all(), t, subj, club, rng, 100)
		print("CARD %s | %s | %s" % [id, card["title"], card["text"]])
		for o in card["options"]:
			var lines := StoryEngine.stakes_lines(o["effects"], card["facts"])
			var result := str(o["result"])
			if result == "":
				result = "(by the group)"
			print("  OPT %s | %s | %s" % [o["label"], " / ".join(lines), result])
