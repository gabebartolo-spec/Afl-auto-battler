"""Hand-written judgements for the row 34 card audit (docs/research/event_card_audit_2026-10-12.md).

PROPOSALS maps a card id to:
  "flags": defects a person found (card_audit_report.py adds the ones it can compute)
  "copy":  [field, now, better, why], one line each; nothing here edits a data file.
Fields: title, text, stakes, label:<key>, result:<key>, note:<key>.
A flag starts with its kind: PROMISE (the copy says it will tell, show or do something and the
result does not), PREMISE (the copy states a fact the trigger does not check), STAKES-FALSE,
STAKES-MISSING (a cost the coach would know, not on the card), NO-TRADE-OFF (one choice loses on
every lever), UNKEPT (a promise the game never tracks), PRIVATE-WATCH (invents family, conduct or
a quote on a card not marked private), GAP (a follow-up cannot fire for some states), DUP (a
near-copy of another card).
"""

PROPOSALS = {
    "board_wants_answers": {"flags": [], "copy": []},
    "board_president_lunch": {"flags": [], "copy": [
        ["title", "The president wants a lunch", "The president has asked you to lunch", "28 of 65 titles say wants"]]},
    "board_sponsor_shoot": {"flags": [
        "PROMISE no: 'He needs the rest' and 'rests', but its only effect is the board -3; he is not rested (no fresh, no rest)",
        "STAKES-MISSING yes: heavy legs on game day"], "copy": [
        ["title", "A sponsor wants {name} for an ad shoot", "{name} has been asked to do a sponsor shoot", "wants x28"],
        ["label:no", "He needs the rest", "Turn it down", "the button promised a rest the result cannot give"],
        ["result:no", "{name} rests. The sponsor goes quiet.", "{name} stays at the club. The sponsor goes quiet.", "keeps to what happens (or give the choice a fresh effect)"],
        ["stakes", "(none)", "Half a day in a studio in game week leaves him with heavy legs.", "the cost of yes, said before the pick"]]},
    "board_billboards": {"flags": ["NO-TRADE-OFF 'no' loses on every lever"], "copy": []},
    "board_savings": {"flags": ["STAKES-MISSING cut: heavy legs for the whole list"], "copy": [
        ["result:cut", "The board likes the saving.", "The saving goes through.", "the engine adds 'The board liked it' after the result"],
        ["result:fight", "You fight for your people. The board notes it.", "You fight for your people.", "same"],
        ["stakes", "(none)", "Fewer recovery staff means heavy legs across the list on game day.", "the cost of cutting"]]},
    "board_injury_list": {"flags": ["UNKEPT review: 'Promise a review' starts no review and the game keeps no promise"], "copy": []},
    "community_hospital_visit": {"flags": ["DUP stakes and note say the same sentence (and the note is shown on no screen)"], "copy": [
        ["note:go", "It takes a session out of the week.", "(delete; the stakes line has it)", "said twice"]]},
    "community_country_clinic": {"flags": ["STAKES-MISSING go: heavy legs", "PREMISE 'his day off' (no day-off rule)"], "copy": [
        ["title", "A country club wants {name} for a junior clinic", "{name} has been asked to run a junior clinic", "wants x28"],
        ["label:no", "Not this week", "Pass on it", "'Not this week' is the label on four cards"],
        ["stakes", "(none)", "Three hours each way leaves him with heavy legs.", "the cost of go"]]},
    "community_foundation_dinner": {"flags": ["PREMISE 'the night before the team leaves': the card also comes in home weeks"], "copy": [
        ["title", "The Foundation wants players at a fundraiser", "The Foundation has a fundraiser on Thursday", "wants x28"],
        ["text", "A Thursday night dinner, the night before the team leaves.", "A Thursday night dinner in game week.", "no away-trip fact is checked"]]},
    "community_junior_club_fire": {"flags": ["STAKES-MISSING go: heavy legs", "Title says the club burnt down, text says the rooms"], "copy": [
        ["title", "{name}'s junior club has burnt down", "{name}'s junior clubrooms have burnt down", "title and text agree"]]},
    "community_school_visit": {"flags": ["STAKES-MISSING go: heavy legs"], "copy": [
        ["label:no", "Not in a game week", "Send a video instead", "every week is a game week; the result is the video"]]},
    "contracts_wants_to_extend": {"flags": [], "copy": [
        ["title", "{name} wants to talk contract", "{name} is after a new deal", "wants x28"]]},
    "contracts_rivals_circling": {"flags": ["NO-TRADE-OFF 'market' loses morale and trust and gains nothing; the game keeps no 'he may leave' consequence", "PRIVATE-WATCH invents a manager's calls about a real player (business, not private; director to rule)"], "copy": []},
    "contracts_manager_noise": {"flags": ["PRIVATE-WATCH invents a radio quote from a real player's manager"], "copy": [
        ["result:ignore", "You leave it. The board doesn't like reading it.", "You leave it.", "the engine adds the board line"]]},
    "contracts_one_more_year": {"flags": ["PROMISE honest: 'Tell him where he stands' and the result names no answer"], "copy": [
        ["title", "{name} wants to know about next year", "{name} is asking about next year", "wants x28"],
        ["result:honest", "You give {name} a straight answer.", "You tell {name} where he stands. {kpi_or_need}", "puts the answer on the card (check the fact is filled for a veteran)"]]},
    "contracts_kid_wants_clarity": {"flags": ["PRIVATE-WATCH 'His family are asking questions' invents family on a card not marked private"], "copy": [
        ["title", "{name} wants to know where he stands", "{name} is asking where he stands", "wants x28"],
        ["text", "He's on a rookie deal and hasn't had a senior game. His family are asking questions.", "He's on a rookie deal and hasn't had a senior game. He wants to know where he's headed.", "family detail out"]]},
    "contracts_waited_manager_calls": {"flags": ["UNKEPT coming: 'a deal is coming at season's end' queues no deal", "NO-TRADE-OFF 'market' loses on every lever"], "copy": []},
    "family_baby_due": {"flags": ["PREMISE 'we play away' and 'first flight home': the card also comes before a home game", "Voice 'we' (every other card is third person)", "Silence picks the harsh choice (default is play, trust -10)", "STAKES-MISSING go: he misses the game"], "copy": [
        ["text", "The baby's due on game day and we play away. He'll do whatever you ask, but you can see where his head is.", "The baby's due on game day. He'll do whatever you ask, but you can see where his head is.", "no away fact; third person"],
        ["result:play", "{first} plays. He's on the first flight home after the siren.", "{first} plays. He's out of the rooms the moment the siren goes.", "true home or away"],
        ["stakes", "(none)", "Tell him to be there and he misses the game.", "the cost of go, said before the pick"]]},
    "family_dad_in_hospital": {"flags": ["PREMISE 'He's from interstate': no origin fact is checked", "STAKES-MISSING go: he misses the game"], "copy": [
        ["text", "He's from interstate and wants to fly home this week.", "He wants to be with his family this week.", "no origin fact"],
        ["label:go", "Put him on the plane", "Send him home to his family", "fits the new text"],
        ["result:go", "{first} flies home. The club looks after the flights.", "{first} heads home to his family. The club looks after the travel.", "same"],
        ["stakes", "(none)", "Send him home and he misses the game.", "the cost of go"]]},
    "family_brothers_wedding": {"flags": ["STAKES-MISSING go: he misses the game"], "copy": []},
    "family_partner_job_offer": {"flags": ["NO-TRADE-OFF 'footy' loses on every lever", "UNKEPT help: 'the club starts looking for work' is only words"], "copy": []},
    "family_newborn_no_sleep": {"flags": ["STAKES-FALSE a lighter week costs him development: no choice here carries any xp, so it costs none", "NO-TRADE-OFF 'normal' loses on every lever"], "copy": [
        ["stakes", "A lighter week costs him some development.", "A lighter week keeps his legs fresh; training as normal on no sleep leaves them heavy.", "says what the effects do"],
        ["note:light", "He'll miss some development.", "(delete; false, and no screen shows notes)", "false"]]},
    "family_partner_graduation": {"flags": ["NO-TRADE-OFF 'train' loses on every lever"], "copy": []},
    "family_house_settlement": {"flags": ["NO-TRADE-OFF 'train' loses on every lever"], "copy": []},
    "health_pulled_up_sore": {"flags": ["DUP of health_knock_at_training (a sore player: rest or play, default play)"], "copy": []},
    "health_knock_at_training": {"flags": ["DUP of health_pulled_up_sore"], "copy": []},
    "health_veteran_load": {"flags": ["STAKES-MISSING play: heavy legs (said only after the pick)", "PREMISE 'a six-day break'"], "copy": [
        ["title", "The fitness staff want to manage {name}'s load", "{name} has {games} games in his legs", "wants x28"],
        ["text", "{games} games in his legs and a six-day break. They want him out of this one.", "The fitness staff want him out of this one.", "no turnaround fact is checked"],
        ["stakes", "(none)", "Play him and he carries heavy legs.", "the cost of play"]]},
    "health_finals_light_week": {"flags": [], "copy": [
        ["title", "The physios want a light week", "A light week before the final?", "the text already says what they want"]]},
    "health_veteran_rehab_mentor": {"flags": ["PREMISE 'One of the kids is facing months out': the trigger never checks for an injured player", "NO-TRADE-OFF 'own' loses on every lever"], "copy": [
        ["title", "{name} wants to help a young player through rehab", "{name} has offered to help in the rehab group", "wants x28; true whoever is injured"]]},
    "leadership_group_selection_say": {"flags": [], "copy": []},
    "leadership_senior_runs_session": {"flags": ["NO-TRADE-OFF 'no' loses on every lever"], "copy": [
        ["title", "{name} wants to take the young players for a session", "{name} has offered to run a session for the young players", "wants x28"]]},
    "leadership_late_to_meeting": {"flags": ["PREMISE 'Not the first time this year' and two players: nobody is named or checked"], "copy": []},
    "leadership_players_meeting": {"flags": [], "copy": []},
    "leadership_young_voice": {"flags": ["PRIVATE-WATCH invents dissent in front of the group for a real player"], "copy": []},
    "media_in_the_papers": {"flags": ["Vague: 'An off-field incident' says nothing a coach could act on", "STAKES-MISSING suspend: he misses the game"], "copy": [
        ["text", "An off-field incident has made the back page. The board is watching how you handle it.", "Photos from a night out have made the back page. The board is watching how you handle it.", "a coach can picture it"],
        ["result:suspend", "{name} is stood down for a week. The board approves.", "{name} is stood down for a week.", "the engine adds the board line"],
        ["result:back", "You back {name}. The board is not impressed.", "You back {name}.", "same"]]},
    "media_radio_spray": {"flags": [], "copy": [
        ["result:bite", "You hit back. The players love it; the board winces.", "You hit back, and the players love it.", "the engine adds the board line"]]},
    "media_newspaper_column": {"flags": [], "copy": []},
    "media_young_feature": {"flags": [], "copy": []},
    "media_team_leak": {"flags": ["PROMISE hunt: 'Find the leak' and the result never says whether anyone was found"], "copy": [
        ["result:hunt", "You go looking. Everyone feels watched.", "You go looking and nobody owns up. Everyone feels watched.", "keeps to what happens"],
        ["result:let", "You let it go. The board isn't happy.", "You let it go.", "the engine adds the board line"]]},
    "media_cameras_in_rooms": {"flags": [], "copy": []},
    "media_papers_fronts_group": {"flags": [], "copy": [
        ["title", "{name} wants to speak to the group", "{name} wants to front the group", "says what he will do"]]},
    "media_papers_again": {"flags": [], "copy": [
        ["result:stand", "You back {name} again. The board is furious.", "You back {name} again.", "the engine adds the board line"]]},
    "members_open_training": {"flags": [], "copy": [
        ["title", "Members want an open training day", "The members have asked for an open training day", "wants x28"]]},
    "members_signing_session": {"flags": [], "copy": [
        ["label:no", "Not this week", "Put it off", "'Not this week' is the label on four cards; the result says put off"]]},
    "members_forum": {"flags": [], "copy": []},
    "members_cheer_squad": {"flags": ["NO-TRADE-OFF 'no' loses on every lever"], "copy": [
        ["label:no", "Not this week", "Keep him at the club", "the label on four cards"]]},
    "members_finals_tickets": {"flags": [], "copy": []},
    "members_interstate_trip": {"flags": ["PREMISE away interstate and 'the hotel': no away fact is checked, so it comes up before home games"], "copy": []},
    "rivals_coach_barb": {"flags": ["Fixed day: 'It's on for Saturday' (games run Thursday to Sunday)"], "copy": [
        ["result:fire", "You fire back. It's on for Saturday.", "You fire back. It's on this week.", "any fixture day"]]},
    "rivals_spy_at_training": {"flags": [], "copy": []},
    "rivals_mouthing_off": {"flags": ["STAKES-MISSING pin: heavy legs for the side"], "copy": [
        ["stakes", "(none)", "A fierce week sharpens the side and leaves heavy legs on game day.", "the cost of pin"]]},
    "selection_talk_dropped": {"flags": ["NO-TRADE-OFF 'It's my call' loses to 'explain' on every lever", "Same title and buttons as the next two cards"], "copy": [
        ["title", "{name} wants a word", "{name} has been left out and wants a word", "the three talk cards read the same in a list"]]},
    "selection_talk_back": {"flags": ["NO-TRADE-OFF 'It's my call' loses to 'explain'"], "copy": [
        ["title", "{name} wants a word", "{name} is back from injury and wants a word", "as above"]]},
    "selection_talk_waiting": {"flags": ["NO-TRADE-OFF 'It's my call' loses to 'explain'"], "copy": [
        ["title", "{name} wants a word", "{name} is waiting on a game", "as above"]]},
    "selection_unhappy": {"flags": [], "copy": []},
    "selection_finals_experience": {"flags": [], "copy": []},
    "training_extra_session": {"flags": ["Title says an extra session; the choices are a heavy week or a freshen-up"], "copy": [
        ["title", "The coaches want an extra session", "Heavy week or a freshen-up?", "title matches the choice"],
        ["text", "A heavy week on the track, or a week to freshen up?", "The coaches are split on whether the legs need work or a rest.", "says why it is a question"]]},
    "training_kid_pushing": {"flags": ["develop: 'no game for him at all this week' is only in a note no screen shows"], "copy": [
        ["label:develop", "A week with the development coaches", "A week with the development coaches, no game", "the missed game is on the button"]]},
    "training_extra_kicking": {"flags": ["STAKES-MISSING stay: heavy legs"], "copy": [
        ["title", "{name} wants extra goalkicking after training", "{name} is staying back to kick goals", "wants x28"]]},
    "training_match_sim_heated": {"flags": [], "copy": [
        ["result:leave", "It stays on the track. The board hears about it anyway.", "It stays on the track.", "the engine adds the board line"]]},
    "training_seniors_day_off": {"flags": [], "copy": [
        ["title", "The senior players want a day off", "The leaders have asked for Monday off", "wants x28"],
        ["result:give", "Monday off. Fresh legs on Saturday.", "Monday off. Fresh legs on game day.", "games run Thursday to Sunday"]]},
    "training_time_trial": {"flags": ["PROMISE run: 'It tells you who's fit' and 'honest answers', and the result names nobody (known; fix on claude/story-time-trial)"], "copy": [
        ["label:skip", "Not this week", "Skip it", "the label on four cards"]]},
    "training_new_stoppage_setup": {"flags": ["STAKES-MISSING drill: heavy legs for the side"], "copy": [
        ["title", "The midfield coach wants a new stoppage set-up", "The midfield coach has a new stoppage set-up", "wants x28"]]},
    "training_backed_kid_flying": {"flags": ["GAP morale 61 to 69: neither follow-up fires (this one needs 70, the other 60 or less), so the arc lapses silently", "'He's grabbed it' is judged on morale, not on his games"], "copy": []},
    "training_backed_kid_struggling": {"flags": ["GAP see training_backed_kid_flying"], "copy": []},
}


CROSS = []
NOT_EXERCISED = []
