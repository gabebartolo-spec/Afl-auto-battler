# Event card audit, 2026-10-12

Open requirement row 34 (director, 2026-10-12). Audit only: no data file is changed. Method: a static pass over `data/stories/*.json` (65 cards, 133 choices) and the post-match press questions (`MediaConference.gd`); then 8 seeded careers of 10 seasons on CI (`tools/audit/cards_impl.gd`; 3 real lists and 3 redraft with real names on, 2 fictional-name controls); then a copy pass against CLAUDE.md. Tools: `tools/audit/card_audit_report.py` (the static flags and this sheet) and `tools/audit/card_copy_proposals.py` (the hand-written flags and copy lines). Cards are answered by a seeded random choice, so every choice and follow-up can come up. "Per 10 seasons" is the pooled count over the 6 real-names careers (52 seasons).

## Summary

| | Count |
|---|---|
| Story cards / choices | 65 / 133 |
| Press questions (older cards) / answers | 6 / 18 |
| Story choices with no effect at all | 0 |
| Story choices whose effects cancel out | 0 |
| Press answers with no effect (the middle answer of every question) | 6 (5 give nothing back; `big_win` sets up the Muckraker's later question) |
| Story choices that only nudge morale by 2 or less | 7 |
| Choices that lose to another on every lever (no trade-off) | 14, on 14 cards |
| Promises not kept (copy says it tells, shows or does something; the result does not) | 3, plus the time trial |
| Premises the trigger does not check | 8 cards |
| Costs a coach would know that no line states before the pick | 15 choices on 14 cards |
| Cards never seen in the real-names careers | 3 |
| Cards under 1 per 10 seasons (zero included) | 12 |
| Copy proposals | 62 lines on 39 cards |

## Findings that cut across cards

- How often a card comes up: about 39 one-off cards are open in an average week (real-names careers) and 0.75 cards are drawn a week, so each open one-off is drawn about 1.9 times in 100 open weeks. A card whose trigger is true in 10% of weeks comes up about 0.5 times in 10 seasons (the sheet's "trigger true" column explains every card under 1).
- No story choice is empty: 0 of 133 have no effect and none cancels out. The nothing-choices are the middle answer of every press question (6 of 18 answers; `big_win` sets up the Muckraker's later question, the other five set up nothing) and the cards where one choice loses to the other on every lever, so nobody would pick it (the sheet marks them NO-TRADE-OFF).
- What a choice does is not shown before the pick. Since #654 the hub card shows its title, text, one `stakes` line and bare button labels (`HubScene._event_card`); the generated button hint (`detail`) and every choice `note` are read by no screen. Only 16 of 65 cards carry a stakes line, and 10 choices carry a `note` that nobody sees (community_hospital_visit, contracts_wants_to_extend x2, family_newborn_no_sleep, health_pulled_up_sore, health_finals_light_week, training_extra_session, training_kid_pushing x2, training_seniors_day_off). Two of them hold the only statement of a cost (training_kid_pushing 'develop' misses the game; family_newborn_no_sleep says a cost that is false).
- 15 choices on 14 cards carry a cost the coach would know (heavy legs, a missed game, a sore body) with no stakes line and no word on the button. The sheet lists each as COST-UNSTATED / STAKES-MISSING. Money, promises and the odds of a breakdown are stated well where a stakes line exists.
- The board's mood is said twice in 8 results: the card's result names it and the engine adds 'The board liked/didn't like it' after (`StoryEngine.aftermath`). Dropping the board sentence from the result keeps one.
- Real names switch off the whole papers arc. `media_in_the_papers`, `media_papers_again` and `media_papers_fronts_group` are private, so they never pick a real-named player; with real names on the first needs a selected, fictional-named player with discipline 40 or less and the probe found none in any week, so the three cards are at 0.0 per 10 seasons (6.7, 4.0 and 0.7 with fictional names). The other private cards (family, the junior club fire) still come up.
- Triggers that claim a fact the game does not know: an away trip (`members_interstate_trip`, `community_foundation_dinner`, `family_baby_due`), an interstate home town (`family_dad_in_hospital`), a hurt young player (`health_veteran_rehab_mentor`), a turnaround (`health_veteran_load`), a fixture day ('Saturday'). The sheet lists each as PREMISE. They need a fact (away, origin, a long injury) or neutral copy.
- Promises the result does not keep: `board_sponsor_shoot` 'He needs the rest' (nothing rests him), `media_team_leak` 'Find the leak' (no one is found), `contracts_one_more_year` 'Tell him where he stands' (no answer given), and the known `training_time_trial`. Three more are only words with no follow-up in the game: `board_injury_list` 'Promise a review', `contracts_waited_manager_calls` 'a deal is coming', `family_partner_job_offer` 'the club will help'.
- Silence is the harsh option on `family_baby_due` (default 'play', trust -10) and the cautious one elsewhere (`board_wants_answers`, `contracts_wants_to_extend`, the two sore-player cards). Ignoring a card is therefore a decision the player may not know they are making.
- Two near-copies: `health_pulled_up_sore` and `health_knock_at_training` (a sore player, rest or play, silence plays him) differ only in a trust gain. One could become a different decision.
- Wording: 28 of 65 titles say 'want' or 'wants'; 'Not this week' is the button on four cards; the three selection talk cards share one title and the same three buttons. Natural AFL language is otherwise good (presser, the twos, match sim, main training, soft-tissue); no engine terms reach the player.

## Cards that never or rarely appear

Real-names careers (6, 52 seasons), under 1 per 10 seasons. The last column says why, from the card's own trigger.

| Card | Real names | Fictional names | Why |
|---|---|---|---|
| media_in_the_papers | 0.0 | 6.7 | trigger never true with real names (1303 weeks), true in 99% of weeks with fictional names; private card, so a real-named player is never picked (6.7 per 10 seasons with fictional names); cooldown 40 weeks |
| media_papers_again | 0.0 | 4.0 | trigger never true with real names (1303 weeks), true in 99% of weeks with fictional names; private card, so a real-named player is never picked (4.0 per 10 seasons with fictional names); follow-up of media_in_the_papers/back, taken 0 times with real names and 7 with fictional |
| media_papers_fronts_group | 0.0 | 0.7 | trigger true in 85% of weeks; private card, so a real-named player is never picked (0.7 per 10 seasons with fictional names); follow-up of media_in_the_papers/back, taken 0 times with real names and 7 with fictional |
| board_savings | 0.2 | 1.3 | trigger true in 5% of weeks |
| media_cameras_in_rooms | 0.4 | 0.0 | trigger true in 14% of weeks |
| selection_talk_back | 0.4 | 0.0 | trigger true in 7% of weeks; cooldown 6 weeks |
| board_wants_answers | 0.6 | 0.7 | trigger true in 7% of weeks; cooldown 6 weeks |
| board_billboards | 0.8 | 0.0 | trigger true in 9% of weeks |
| board_president_lunch | 0.8 | 0.7 | trigger true in 9% of weeks |
| leadership_players_meeting | 0.8 | 1.3 | trigger true in 12% of weeks |
| training_backed_kid_flying | 1.0 | 0.0 | trigger true in 96% of weeks; follow-up of training_kid_pushing/blood, taken 10 times with real names and 0 with fictional |
| training_backed_kid_struggling | 1.0 | 0.0 | trigger true in 94% of weeks; follow-up of training_kid_pushing/blood, taken 10 times with real names and 0 with fictional |

## Press questions (the older cards)

Every question offers the same three answers: accountable (board up, players down), tactical (neither moves) and protective (players up, board down). So the middle answer does nothing by design, and which question was asked changes only the wording. Counted per 10 seasons in all 8 careers (67 seasons), asked after the match and skipped by the autopilot.

| Key | Journalist | Question | Per 10 seasons |
|---|---|---|---|
| injury | Kev Pollard | Tough blow losing X. How much did that hurt you out there? | 7.0 |
| heavy_loss | Gary Haddon | X beat you by N. Was that acceptable? (Or, if you called your method the standard after a big win this season: where was it today?) | 4.3 |
| big_win | Trish Lomax | That was a clinic against X. Is this the best side in the competition? | 3.1 |
| close_game | Dev Mehta | A true number from the match, then: what went wrong, how, or what decided it? | 3.7 |
| star | Kev Pollard | X had a huge night. Is there a better player in the comp right now? | 1.8 |
| young_side | Margaret Ashby | N of your side today were 21 or younger. Is this the club you're building? | 3.3 |

## The sheet, card by card

Each card: id, title, appearances per 10 seasons (real names; fictional-name controls in brackets), how often its trigger was true, the choices taken in all careers, then flags and copy lines. A card with no lines under it has no defect found. `stakes`/`label`/`result`/`text`/`title` lines are "current" -> "better" (reason).

### Training (9)

- **training_extra_session** "The coaches want an extra session": 5.0 per 10 seasons (fictional names 3.3), trigger true 96% of weeks. Taken: heavy 16, recover 15.
  - flag: Title says an extra session; the choices are a heavy week or a freshen-up
  - title: "The coaches want an extra session" -> "Heavy week or a freshen-up?" (title matches the choice)
  - text: "A heavy week on the track, or a week to freshen up?" -> "The coaches are split on whether the legs need work or a rest." (says why it is a question)
- **training_kid_pushing** "{name} is pushing for games": 3.8 per 10 seasons (fictional names 2.0), trigger true 12% of weeks. Taken: blood 10, develop 13.
  - flag: develop: 'no game for him at all this week' is only in a note no screen shows
  - label:develop: "A week with the development coaches" -> "A week with the development coaches, no game" (the missed game is on the button)
- **training_extra_kicking** "{name} wants extra goalkicking after training": 3.8 per 10 seasons (fictional names 4.7), trigger true 90% of weeks. Taken: stay 15, home 12.
  - flag: STAKES-MISSING stay: heavy legs
  - title: "{name} wants extra goalkicking after training" -> "{name} is staying back to kick goals" (wants x28)
- **training_match_sim_heated** "Match sim got heated": 3.7 per 10 seasons (fictional names 3.3), trigger true 96% of weeks. Taken: leave 11, pull 13.
  - flag: board mood said in the result and again by the engine (leave)
  - result:leave: "It stays on the track. The board hears about it anyway." -> "It stays on the track." (the engine adds the board line)
- **training_seniors_day_off** "The senior players want a day off": 3.3 per 10 seasons (fictional names 2.7), trigger true 68% of weeks. Taken: give 9, train 12.
  - title: "The senior players want a day off" -> "The leaders have asked for Monday off" (wants x28)
  - result:give: "Monday off. Fresh legs on Saturday." -> "Monday off. Fresh legs on game day." (games run Thursday to Sunday)
- **training_time_trial** "The fitness staff want a time trial": 4.0 per 10 seasons (fictional names 4.0), trigger true 96% of weeks. Taken: run 17, skip 10.
  - flag: WEAK skip
  - flag: PROMISE run: 'It tells you who's fit' and 'honest answers', and the result names nobody (known; fix on claude/story-time-trial)
  - label:skip: "Not this week" -> "Skip it" (the label on four cards)
- **training_new_stoppage_setup** "The midfield coach wants a new stoppage set-up": 3.5 per 10 seasons (fictional names 4.7), trigger true 96% of weeks. Taken: drill 12, hold 13.
  - flag: STAKES-MISSING drill: heavy legs for the side
  - title: "The midfield coach wants a new stoppage set-up" -> "The midfield coach has a new stoppage set-up" (wants x28)
- **training_backed_kid_flying** "{name} has taken his chance": 1.0 per 10 seasons (fictional names 0.0), trigger true 96% of weeks. Taken: earned 4, grounded 1.
  - flag: GAP (static) morale 61 to 69: neither follow-up could fire (this one needs 70, the other 60 or less) and the arc would lapse silently. Not seen: all 10 kids backed in these careers got a follow-up
  - flag: 'He's grabbed it' is judged on morale, not on his games
- **training_backed_kid_struggling** "{name} is finding senior footy hard": 1.0 per 10 seasons (fictional names 0.0), trigger true 94% of weeks. Taken: again 4, twos 1.
  - flag: GAP (static) see training_backed_kid_flying; not seen in the runs

### Health (5)

- **health_pulled_up_sore** "{name} pulled up sore": 6.5 per 10 seasons (fictional names 6.0), trigger true 100% of weeks. Taken: rest 19, play 24.
  - flag: DUP of health_knock_at_training (a sore player: rest or play, default play)
- **health_veteran_load** "The fitness staff want to manage {name}'s load": 3.5 per 10 seasons (fictional names 3.3), trigger true 95% of weeks. Taken: rest 10, play 13.
  - flag: STAKES-MISSING play: heavy legs (said only after the pick)
  - flag: PREMISE 'a six-day break'
  - title: "The fitness staff want to manage {name}'s load" -> "{name} has {games} games in his legs" (wants x28)
  - text: "{games} games in his legs and a six-day break. They want him out of this one." -> "The fitness staff want him out of this one." (no turnaround fact is checked)
  - stakes: "(none)" -> "Play him and he carries heavy legs." (the cost of play)
- **health_knock_at_training** "{name} copped a knock at training": 4.2 per 10 seasons (fictional names 4.0), trigger true 100% of weeks. Taken: rest 17, play 11.
  - flag: DUP of health_pulled_up_sore
- **health_finals_light_week** "The physios want a light week": 1.3 per 10 seasons (fictional names 1.3), trigger true 4% of weeks. Taken: light 4, normal 5.
  - title: "The physios want a light week" -> "A light week before the final?" (the text already says what they want)
- **health_veteran_rehab_mentor** "{name} wants to help a young player through rehab": 3.5 per 10 seasons (fictional names 1.3), trigger true 96% of weeks. Taken: help 16, own 4.
  - flag: PREMISE 'One of the kids is facing months out': the trigger never checks for an injured player
  - flag: NO-TRADE-OFF 'own' loses on every lever
  - title: "{name} wants to help a young player through rehab" -> "{name} has offered to help in the rehab group" (wants x28; true whoever is injured)

### Family (7)

- **family_baby_due** "{first} could become a dad on game day": 2.7 per 10 seasons (fictional names 2.0), trigger true 60% of weeks. Taken: go 13, play 4.
  - flag: PREMISE 'we play away' and 'first flight home': the card also comes before a home game
  - flag: Voice 'we' (every other card is third person)
  - flag: Silence picks the harsh choice (default is play, trust -10)
  - flag: STAKES-MISSING go: he misses the game
  - text: "The baby's due on game day and we play away. He'll do whatever you ask, but you can see where his head is." -> "The baby's due on game day. He'll do whatever you ask, but you can see where his head is." (no away fact; third person)
  - result:play: "{first} plays. He's on the first flight home after the siren." -> "{first} plays. He's out of the rooms the moment the siren goes." (true home or away)
  - stakes: "(none)" -> "Tell him to be there and he misses the game." (the cost of go, said before the pick)
- **family_dad_in_hospital** "{name}'s dad is in hospital": 3.3 per 10 seasons (fictional names 2.7), trigger true 85% of weeks. Taken: go 11, stay 10.
  - flag: PREMISE 'He's from interstate': no origin fact is checked
  - flag: STAKES-MISSING go: he misses the game
  - text: "He's from interstate and wants to fly home this week." -> "He wants to be with his family this week." (no origin fact)
  - label:go: "Put him on the plane" -> "Send him home to his family" (fits the new text)
  - result:go: "{first} flies home. The club looks after the flights." -> "{first} heads home to his family. The club looks after the travel." (same)
  - stakes: "(none)" -> "Send him home and he misses the game." (the cost of go)
- **family_brothers_wedding** "{first}'s brother is getting married on game day": 3.3 per 10 seasons (fictional names 3.3), trigger true 85% of weeks. Taken: go 12, play 10.
  - flag: STAKES-MISSING go: he misses the game
- **family_partner_job_offer** "{name}'s partner has a job offer back home": 2.3 per 10 seasons (fictional names 3.3), trigger true 53% of weeks. Taken: help 8, footy 9.
  - flag: NO-TRADE-OFF 'footy' loses on every lever
  - flag: UNKEPT help: 'the club starts looking for work' is only words
- **family_newborn_no_sleep** "{name} isn't sleeping": 3.1 per 10 seasons (fictional names 3.3), trigger true 69% of weeks. Taken: light 7, normal 14.
  - flag: STAKES-FALSE a lighter week costs him development: no choice here carries any xp, so it costs none
  - flag: NO-TRADE-OFF 'normal' loses on every lever
  - stakes: "A lighter week costs him some development." -> "A lighter week keeps his legs fresh; training as normal on no sleep leaves them heavy." (says what the effects do)
  - note:light: "He'll miss some development." -> "(delete; false, and no screen shows notes)" (false)
- **family_partner_graduation** "{name}'s partner graduates on Thursday": 3.1 per 10 seasons (fictional names 4.0), trigger true 85% of weeks. Taken: go 16, train 6.
  - flag: NO-TRADE-OFF 'train' loses on every lever
- **family_house_settlement** "{name} settles on his first house on Thursday": 2.7 per 10 seasons (fictional names 3.3), trigger true 69% of weeks. Taken: go 11, train 8.
  - flag: NO-TRADE-OFF 'train' loses on every lever

### Media (8)

- **media_in_the_papers** "{name} is in the papers": 0.0 per 10 seasons (fictional names 6.7), trigger true 0% of weeks. Taken: suspend 3, back 7.
  - flag: Vague: 'An off-field incident' says nothing a coach could act on
  - flag: STAKES-MISSING suspend: he misses the game
  - flag: board mood said in the result and again by the engine (suspend, back)
  - text: "An off-field incident has made the back page. The board is watching how you handle it." -> "Photos from a night out have made the back page. The board is watching how you handle it." (a coach can picture it)
  - result:suspend: "{name} is stood down for a week. The board approves." -> "{name} is stood down for a week." (the engine adds the board line)
  - result:back: "You back {name}. The board is not impressed." -> "You back {name}." (same)
- **media_radio_spray** "Kev Pollard has sprayed you on radio": 1.3 per 10 seasons (fictional names 2.7), trigger true 23% of weeks. Taken: bite 4, ignore 7.
  - flag: board mood said in the result and again by the engine (bite)
  - result:bite: "You hit back. The players love it; the board winces." -> "You hit back, and the players love it." (the engine adds the board line)
- **media_newspaper_column** "{name} has been offered a newspaper column": 3.8 per 10 seasons (fictional names 4.0), trigger true 96% of weeks. Taken: yes 14, no 12.
- **media_young_feature** "Footy Tonight want a feature on {name}": 3.1 per 10 seasons (fictional names 3.3), trigger true 95% of weeks. Taken: yes 11, no 10.
- **media_team_leak** "The Siren has your side before it's announced": 4.0 per 10 seasons (fictional names 2.7), trigger true 96% of weeks. Taken: hunt 11, let 14.
  - flag: PROMISE hunt: 'Find the leak' and the result never says whether anyone was found
  - flag: board mood said in the result and again by the engine (let)
  - result:hunt: "You go looking. Everyone feels watched." -> "You go looking and nobody owns up. Everyone feels watched." (keeps to what happens)
  - result:let: "You let it go. The board isn't happy." -> "You let it go." (the engine adds the board line)
- **media_cameras_in_rooms** "Footy Tonight want cameras in the rooms": 0.4 per 10 seasons (fictional names 0.0), trigger true 14% of weeks. Taken: yes 0, no 2.
- **media_papers_fronts_group** "{name} wants to speak to the group": 0.0 per 10 seasons (fictional names 0.7), trigger true 85% of weeks. Taken: front 0, private 1.
  - flag: WEAK private
  - title: "{name} wants to speak to the group" -> "{name} wants to front the group" (says what he will do)
- **media_papers_again** "{name} is back in the papers": 0.0 per 10 seasons (fictional names 4.0), trigger true 0% of weeks. Taken: stand 2, down 4.
  - flag: board mood said in the result and again by the engine (stand)
  - result:stand: "You back {name} again. The board is furious." -> "You back {name} again." (the engine adds the board line)

### Contracts (6)

- **contracts_wants_to_extend** "{name} wants to talk contract": 5.6 per 10 seasons (fictional names 6.0), trigger true 44% of weeks. Taken: extend 22, wait 16.
  - title: "{name} wants to talk contract" -> "{name} is after a new deal" (wants x28)
- **contracts_rivals_circling** "Rival clubs are circling {name}": 4.0 per 10 seasons (fictional names 2.7), trigger true 93% of weeks. Taken: wanted 15, market 10.
  - flag: NO-TRADE-OFF 'market' loses morale and trust and gains nothing; the game keeps no 'he may leave' consequence
  - flag: PRIVATE-WATCH invents a manager's calls about a real player (business, not private; director to rule)
- **contracts_manager_noise** "{name}'s manager is talking him up": 4.0 per 10 seasons (fictional names 3.3), trigger true 91% of weeks. Taken: ring 12, ignore 14.
  - flag: PRIVATE-WATCH invents a radio quote from a real player's manager
  - flag: board mood said in the result and again by the engine (ignore)
  - result:ignore: "You leave it. The board doesn't like reading it." -> "You leave it." (the engine adds the board line)
- **contracts_one_more_year** "{name} wants to know about next year": 3.3 per 10 seasons (fictional names 5.3), trigger true 89% of weeks. Taken: honest 12, later 13.
  - flag: PROMISE honest: 'Tell him where he stands' and the result names no answer
  - title: "{name} wants to know about next year" -> "{name} is asking about next year" (wants x28)
  - result:honest: "You give {name} a straight answer." -> "You tell {name} where he stands. {kpi_or_need}" (puts the answer on the card (check the fact is filled for a veteran))
- **contracts_kid_wants_clarity** "{name} wants to know where he stands": 2.1 per 10 seasons (fictional names 0.0), trigger true 35% of weeks. Taken: plans 5, earn 6.
  - flag: NO-TRADE-OFF earn by plans
  - flag: PRIVATE-WATCH 'His family are asking questions' invents family on a card not marked private
  - title: "{name} wants to know where he stands" -> "{name} is asking where he stands" (wants x28)
  - text: "He's on a rookie deal and hasn't had a senior game. His family are asking questions." -> "He's on a rookie deal and hasn't had a senior game. He wants to know where he's headed." (family detail out)
- **contracts_waited_manager_calls** "{name}'s manager has called": 2.1 per 10 seasons (fictional names 3.3), trigger true 96% of weeks. Taken: coming 6, market 10.
  - flag: UNKEPT coming: 'a deal is coming at season's end' queues no deal
  - flag: NO-TRADE-OFF 'market' loses on every lever

### Leadership (5)

- **leadership_group_selection_say** "The leadership group want a say on selection": 4.2 per 10 seasons (fictional names 3.3), trigger true 96% of weeks. Taken: hear 9, no 18.
- **leadership_senior_runs_session** "{name} wants to take the young players for a session": 5.0 per 10 seasons (fictional names 4.0), trigger true 96% of weeks. Taken: yes 14, no 18.
  - flag: NO-TRADE-OFF 'no' loses on every lever
  - title: "{name} wants to take the young players for a session" -> "{name} has offered to run a session for the young players" (wants x28)
- **leadership_late_to_meeting** "Two players were late to the team meeting": 3.3 per 10 seasons (fictional names 3.3), trigger true 96% of weeks. Taken: example 8, quiet 14.
  - flag: PREMISE 'Not the first time this year' and two players: nobody is named or checked
- **leadership_players_meeting** "The players have called their own meeting": 0.8 per 10 seasons (fictional names 1.3), trigger true 12% of weeks. Taken: room 3, stay 3.
- **leadership_young_voice** "{name} spoke up in the review": 2.9 per 10 seasons (fictional names 4.7), trigger true 91% of weeks. Taken: back 10, pull 12.
  - flag: PRIVATE-WATCH invents dissent in front of the group for a real player

### Community (5)

- **community_hospital_visit** "The children's hospital has asked for a visit": 4.4 per 10 seasons (fictional names 2.7), trigger true 96% of weeks. Taken: go 9, train 18.
  - flag: DUP stakes and note say the same sentence (and the note is shown on no screen)
  - note:go: "It takes a session out of the week." -> "(delete; the stakes line has it)" (said twice)
- **community_country_clinic** "A country club wants {name} for a junior clinic": 3.8 per 10 seasons (fictional names 2.7), trigger true 96% of weeks. Taken: go 8, no 16.
  - flag: STAKES-MISSING go: heavy legs
  - flag: PREMISE 'his day off' (no day-off rule)
  - title: "A country club wants {name} for a junior clinic" -> "{name} has been asked to run a junior clinic" (wants x28)
  - label:no: "Not this week" -> "Pass on it" ('Not this week' is the label on four cards)
  - stakes: "(none)" -> "Three hours each way leaves him with heavy legs." (the cost of go)
- **community_foundation_dinner** "The Foundation wants players at a fundraiser": 4.0 per 10 seasons (fictional names 4.0), trigger true 96% of weeks. Taken: all 17, choose 10.
  - flag: PREMISE 'the night before the team leaves': the card also comes in home weeks
  - title: "The Foundation wants players at a fundraiser" -> "The Foundation has a fundraiser on Thursday" (wants x28)
  - text: "A Thursday night dinner, the night before the team leaves." -> "A Thursday night dinner in game week." (no away-trip fact is checked)
- **community_junior_club_fire** "{name}'s junior club has burnt down": 3.7 per 10 seasons (fictional names 4.0), trigger true 85% of weeks. Taken: go 11, jumper 14.
  - flag: WEAK jumper
  - flag: STAKES-MISSING go: heavy legs
  - flag: Title says the club burnt down, text says the rooms
  - title: "{name}'s junior club has burnt down" -> "{name}'s junior clubrooms have burnt down" (title and text agree)
- **community_school_visit** "A school has asked for {name}": 3.8 per 10 seasons (fictional names 3.3), trigger true 96% of weeks. Taken: go 13, no 12.
  - flag: WEAK no
  - flag: STAKES-MISSING go: heavy legs
  - label:no: "Not in a game week" -> "Send a video instead" (every week is a game week; the result is the video)

### Rivals (3)

- **rivals_coach_barb** "{opp}'s assistant has had a crack": 3.8 per 10 seasons (fictional names 4.7), trigger true 96% of weeks. Taken: fire 13, smile 14.
  - flag: Fixed day: 'It's on for Saturday' (games run Thursday to Sunday)
  - result:fire: "You fire back. It's on for Saturday." -> "You fire back. It's on this week." (any fixture day)
- **rivals_spy_at_training** "Someone from {opp} was spotted at your training": 4.0 per 10 seasons (fictional names 3.3), trigger true 96% of weeks. Taken: close 10, let 16.
- **rivals_mouthing_off** "{opp}'s players have been mouthing off": 4.2 per 10 seasons (fictional names 2.0), trigger true 96% of weeks. Taken: pin 13, calm 12.
  - flag: STAKES-MISSING pin: heavy legs for the side
  - stakes: "(none)" -> "A fierce week sharpens the side and leaves heavy legs on game day." (the cost of pin)

### Board (6)

- **board_wants_answers** "The board wants answers": 0.6 per 10 seasons (fictional names 0.7), trigger true 7% of weeks. Taken: promise 1, patience 3.
  - flag: board mood said in the result and again by the engine (patience)
- **board_president_lunch** "The president wants a lunch": 0.8 per 10 seasons (fictional names 0.7), trigger true 9% of weeks. Taken: go 3, no 2.
  - title: "The president wants a lunch" -> "The president has asked you to lunch" (28 of 65 titles say wants)
- **board_sponsor_shoot** "A sponsor wants {name} for an ad shoot": 3.3 per 10 seasons (fictional names 3.3), trigger true 96% of weeks. Taken: yes 11, no 11.
  - flag: PROMISE no: 'He needs the rest' and 'rests', but its only effect is the board -3; he is not rested (no fresh, no rest)
  - flag: STAKES-MISSING yes: heavy legs on game day
  - title: "A sponsor wants {name} for an ad shoot" -> "{name} has been asked to do a sponsor shoot" (wants x28)
  - label:no: "He needs the rest" -> "Turn it down" (the button promised a rest the result cannot give)
  - result:no: "{name} rests. The sponsor goes quiet." -> "{name} stays at the club. The sponsor goes quiet." (keeps to what happens (or give the choice a fresh effect))
  - stakes: "(none)" -> "Half a day in a studio in game week leaves him with heavy legs." (the cost of yes, said before the pick)
- **board_billboards** "The board's thrilled with the run": 0.8 per 10 seasons (fictional names 0.0), trigger true 9% of weeks. Taken: yes 1, no 3.
  - flag: NO-TRADE-OFF 'no' loses on every lever
- **board_savings** "The board wants savings": 0.2 per 10 seasons (fictional names 1.3), trigger true 5% of weeks. Taken: cut 1, fight 2.
  - flag: STAKES-MISSING cut: heavy legs for the whole list
  - flag: board mood said in the result and again by the engine (cut, fight)
  - result:cut: "The board likes the saving." -> "The saving goes through." (the engine adds 'The board liked it' after the result)
  - result:fight: "You fight for your people. The board notes it." -> "You fight for your people." (same)
  - stakes: "(none)" -> "Fewer recovery staff means heavy legs across the list on game day." (the cost of cutting)
- **board_injury_list** "The board's asking about the injury list": 2.1 per 10 seasons (fictional names 2.0), trigger true 44% of weeks. Taken: back 8, review 6.
  - flag: UNKEPT review: 'Promise a review' starts no review and the game keeps no promise

### Members (6)

- **members_open_training** "Members want an open training day": 4.4 per 10 seasons (fictional names 4.0), trigger true 96% of weeks. Taken: open 18, closed 11.
  - title: "Members want an open training day" -> "The members have asked for an open training day" (wants x28)
- **members_signing_session** "Members want a signing session after training": 3.7 per 10 seasons (fictional names 3.3), trigger true 96% of weeks. Taken: sign 12, no 12.
  - label:no: "Not this week" -> "Put it off" ('Not this week' is the label on four cards; the result says put off)
- **members_forum** "The members are letting the club know": 1.2 per 10 seasons (fictional names 1.3), trigger true 12% of weeks. Taken: front 4, results 4.
- **members_cheer_squad** "The cheer squad have asked for {name}": 3.5 per 10 seasons (fictional names 3.3), trigger true 96% of weeks. Taken: go 10, no 13.
  - flag: NO-TRADE-OFF 'no' loses on every lever
  - label:no: "Not this week" -> "Keep him at the club" (the label on four cards)
- **members_finals_tickets** "Members can't get finals tickets": 2.1 per 10 seasons (fictional names 1.3), trigger true 4% of weeks. Taken: front 9, ceo 4.
- **members_interstate_trip** "Members are travelling to see you play": 3.8 per 10 seasons (fictional names 4.7), trigger true 96% of weeks. Taken: meet 15, bubble 12.
  - flag: PREMISE away interstate and 'the hotel': no away fact is checked, so it comes up before home games

### Selection (5)

- **selection_talk_dropped** "{name} wants a word": 2.5 per 10 seasons (fictional names 2.0), trigger true 33% of weeks. Taken: explain 7, talk 2, call 7.
  - flag: NO-TRADE-OFF 'It's my call' loses to 'explain' on every lever
  - flag: Same title and buttons as the next two cards
  - title: "{name} wants a word" -> "{name} has been left out and wants a word" (the three talk cards read the same in a list)
- **selection_talk_back** "{name} wants a word": 0.4 per 10 seasons (fictional names 0.0), trigger true 7% of weeks. Taken: explain 0, talk 0, call 2.
  - flag: NO-TRADE-OFF 'It's my call' loses to 'explain'
  - title: "{name} wants a word" -> "{name} is back from injury and wants a word" (as above)
- **selection_talk_waiting** "{name} wants a word": 1.3 per 10 seasons (fictional names 1.3), trigger true 16% of weeks. Taken: explain 4, talk 0, call 5.
  - flag: NO-TRADE-OFF 'It's my call' loses to 'explain'
  - title: "{name} wants a word" -> "{name} is waiting on a game" (as above)
- **selection_unhappy** "{name} is unhappy": 4.4 per 10 seasons (fictional names 3.3), trigger true 88% of weeks. Taken: talk 14, earn 14.
- **selection_finals_experience** "{name} wants to play in the final": 2.1 per 10 seasons (fictional names 1.3), trigger true 4% of weeks. Taken: in 4, stick 9.

## Repeated phrasing

- 28 of 65 titles use "want" or "wants": training_extra_session, training_extra_kicking, training_seniors_day_off, training_time_trial, training_new_stoppage_setup, health_veteran_load, health_finals_light_week, health_veteran_rehab_mentor, media_young_feature, media_cameras_in_rooms, media_papers_fronts_group, contracts_wants_to_extend, contracts_one_more_year, contracts_kid_wants_clarity, leadership_group_selection_say, leadership_senior_runs_session, community_country_clinic, community_foundation_dinner, board_wants_answers, board_president_lunch, board_sponsor_shoot, board_savings, members_open_training, members_signing_session, selection_talk_dropped, selection_talk_back, selection_talk_waiting, selection_finals_experience.
- Button "not this week" is on 4 cards: training_time_trial, community_country_clinic, members_signing_session, members_cheer_squad.
- Button "he plays" is on 2 cards: health_veteran_load, family_brothers_wedding.
- Button "send him" is on 3 cards: community_country_clinic, community_school_visit, members_cheer_squad.
- Button "promise him a game this week" is on 3 cards: selection_talk_dropped, selection_talk_back, selection_talk_waiting.
- Button "it's my call" is on 3 cards: selection_talk_dropped, selection_talk_back, selection_talk_waiting.

## Not exercised

- Only the random-answer path ran. A player who ignores cards (silence settles to each card's default) was not run, so arcs started by silence were not counted.
- The captain cards (#671), culture (#665) and the time-trial fix are not on main; the 65 cards audited are main at 1657304c. Cards added later are not counted.
- Seed 42 (GEE, lists, real names) was sacked after 2 seasons because answers are random; it adds 2 seasons to the real-names pool, not 10. Two fictional-name controls (15 seasons in all) are too few for more than a contrast.
- 'Trigger true' ignores cooldowns, per-season limits, the category rule and arcs, so it is an upper bound on being open. Finals cards count only the weeks the club is still alive.
- Press questions are counted by key, not by answer, and the two `heavy_loss` wordings are one key. The autopilot skips the press, so what the answers did was not exercised.
- Nothing was read on a phone. Copy proposals are lines on a sheet, not captured in the hub, and effect sizes (morale, board, trust) were not judged: balance is the director's call.

## Runs

Branch `claude/card-audit`, `audit.yml` with `impl=cards_impl`, args `seed club seasons [lists] [real]`: 38234634188, 38234641942, 38234649836, 38234657974, 38234665453, 38234672998, 38234680313, 38234687621.
