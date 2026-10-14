# 27. Director playtest and decisions, 2026-10-14 (evening)

Every comment the director made in his PC playtest of Adelaide v Melbourne and in the interview that evening, in his
words, with the owner and the PR. His order (18:37): "all these playtest comments im making, get them in the next patch
with the colour fix tonight". He also said (18:41): "getting tired of having to repeat myself, make sure you're ACTUALLY
committing all my comments to the roadmap". An item leaves this chapter only when its PR is merged AND it is on itch.

## A. Playtest comments (all for the itch patch of 2026-10-14)

| # | His words (quoted; paraphrase marked) | What it means | Owner / branch | Status |
|---|---|---|---|---|
| A1 | Tester feedback: "player names need colours to indicate what team they belong to, aka 'Josh Worrel is roaming the backline', 'Tom Stewart is your spare' ... tint the names in club colours"; "high priority"; "patch the colour fix to itch asap"; "ive told you to build it countless times over the past few days and you keep overlooking it". Second tester: hub names like "Mac Andrew" and "Luke Jackson" should be coloured | Every player name in running text in his club's colour, everywhere | clubnames: #743, then claude/club-colour-names-2 (card titles, press, call rows, best-player rows, draft/news, pre-match Key match-ups) | #743 in CI; -2 building |
| A2 | "tag going from middle left to full left when you click the taggee is heinous, awful UI design" | Break/pre-match panel sections never change column when "Who tags" opens | tagjump: claude/tag-panel-fixed-columns | building |
| A3 | "best so far pre bounce makes no sense" | Hide "Best so far" until a quarter is played | tagjump (same PR) | building |
| A4 | "spacing is horrible in that paragraph, why the wall of text? make it more concise and space it properly" (game plan description) | Plan description as short spaced lines, Gain/Cost rows, synergies split out | planblurb: claude/plan-blurb-tidy | building |
| A5 | Game plan, pep talk and rotations panes at the breaks: "empty space below, wall of text above. space it out properly, and put a record of decisions below too i.e: Q1: Demons: Defensive Press - Crows: Attack Corridor ... do the same for pep talk and rotations" | Spaced text plus a per-quarter record of both clubs' calls (opponent's only where the game reveals it) | planblurb (same PR) | building |
| A6 | "make the ruck selection compulsory pre bounce"; ruling: "Assistant names one, you can change it" | Remove "No main ruck"; assistant's pick preselected and marked; coach can change | breakfix: claude/main-ruck-and-order | building |
| A7 | "says forward, mid, back, but shows a mid, fwd, back, be consistent" | Play-through names in the label's order | breakfix (same PR) | building |
| A8 | "why did my tagger change without my consent? is fitzgerald even a good tagger? as i've said, if my tagger is Steele on Dawson, Steele wont go to the bench if Steele is on the ground, so the tag is set and permanent for the whole game" | A tag the coach sets persists all match, never swapped by the assistant; the tagger is never rotated to the bench while the tag is on; the assistant's own pick ranks real taggers | breakfix (same PR) | building |
| A9 | "why tell me Rankine is their best player if i cant do anything about it? let me tag him, Rankine is a mid/fwd so it should be fine for me to tag him" | Any opposition player with a midfield position (incl. mid/fwd) is a tag target; the break's named best is always offered | breakfix (same PR) | building |
| A10 | "when i click on defensive forward it should show how the matchup is going on the right, how many contests my guy beat their guy in, how many intercepts their guy has, player rating for both players" | "How it's going" block in the Defensive forward pane at breaks | dfduel: claude/df-duel-at-breaks | building |
| A11 | "crows and demons look the same basically. why is there no yellow for the crows? audit readability of all discs" ... "and all matchups" | Each club's disc carries its defining colours (Crows gold etc.); all 306 home/away pairings scored for distinctness, clash strip when too close; on-oval name labels never overlap | discaudit: claude/disc-readability | building |
| A14 | "post match stats screen is horrible / having to scroll down to see the stats part is bad / have these first two condensed into one page / third image, staging of this text and the numbers on the right is awful for the same reasons" | Full-time Stats: worm, quarters and team stats on one PC page without scrolling; "What your calls did" values beside their labels; call log grouped by quarter | rowgap: claude/row-gaps (same PR as A12) | building |
| A15 | "remove the team tint from these things. looks like random shapes without the colours" (training gear: cones, tackle bag, stopwatch drawn flat club-blue; his earlier ruling: props "Bigger, in real colours") | Gear shows its real colours everywhere | gearcolour: claude/gear-real-colours | building |
| A16 | "why cant i click on players and open their bio on the training screen? virtually every time you see a players name anywhere in the game i want to be able to click on it and open their bio" | Every player name opens his profile; Back returns. Phase 1 tonight: Training + every club-coloured name in text; phase 2: all other screens | biolinks: claude/player-name-links | building |
| A17 | "the stat guide is like 3 pages of text. condense it, keep only the essential info" | One short line per stat, grouped, about one PC screen; lead checks every line | statguide: claude/stat-guide-short | building |
| A18 | "post match interview screen is so small. needs to be bigger" (PC) | Press conference uses most of a landscape screen: picture left, question and answers right, bigger type | pressbig: claude/press-conference-big | building |
| A19 | Press answers on losing an injured player: answer 1 "not sure why the players would be felt left out to dry by that comment? im ok with the effects, but the wording should be harsher on the players"; answer 2 "fine"; answer 3 "how is this not taking accountability? make it more obvious" | Answer wording must clearly cause its effect; effects unchanged; audit every press question the same way | pressbig (same PR as A18) | building |
| A20 | League news overlay: "awful. make it look like website frontpage rather than a ticker feed" | A footy-site front page for the round: lead story, secondary stories, grouped briefs (first goals, injuries, MRO), your club's item marked; no "Difficulty" line | newsfront: claude/league-news-front-page | building |
| A13 | "what happened to my defensive press tint? was visible in the first quarter but disappeared since"; then "NOW IN Q4 the tint has randomly reappeared" | The oval's game-plan tint shows in every quarter and follows plan changes | trainrep: claude/plan-tint-every-quarter | building |
| A12 | "this looks horrible. so much space, i already told you that having all tis space between divorces the number from the source and harms readability" (match stats sheet on PC) | Numbers sit next to their names; fixed at the shared row component, audited on every screen at 1280 and wide | rowgap: claude/row-gaps | building |

## B. Interview rulings (17:40-18:22)

| # | Decision | Owner / PR | Status |
|---|---|---|---|
| B1 | Plan familiarity wording: "Plan fluency: high / medium / low"; sizes stay 1.00 / 0.95 / 0.90 until his playtest | pre2: #740 | merging on green (behind "preseason") |
| B2 | Training report (tester's idea): approved; "+77 XP" replaced with plain words | trainrep: #741 | syncing (behind "training_report") |
| B3 | Upright oval on phones: approved | #724 | MERGED |
| B4 | Finals cards: all 16 approved with fixes (captain's last word no morale change when they won't listen; Grand Final cards say "Saturday" not "next final"; the old-rival card names the real GF opponent; finals buttons fit a phone) | finals: #709 | fixes done; merging on green |
| B5 | Draft night Pass / Pick for me buttons: approved | #732 | syncing with main |
| B6 | Best players at the breaks and full time: "show the actual coaches votes" (5-4-3-2-1 from each coach, out of 10) | not assigned yet | open: after A1-2 and A10 land (same screen) |
| B7 | Expansion clubs do not get first call on cap-squeezed stars: "No, he goes to free agency" | expansion: #745 | W7 approved (switch off) with 2 defects being fixed |

## C. New features asked for the evening (behind switches until 0.2.0)

| # | His words | Owner / branch | Status |
|---|---|---|---|
| C1 | "we should have international players in the generated drafts, not many, but 1-2 each draft like, USA, African countries, New Zealand, Ireland"; "their names must make sense for their origin countries" | intl: claude/international-prospects (switch international_prospects) | building |
| C2 | "bespoke events and story beats for international players" | intl: claude/international-stories (second PR) | after C1 |
| C3 | Pre-season slice 3: one practice match against another club ("Trial players and plans, no ladder", ch. 26) | practice: #747 | look-gated; CI running |

## D. Parked by the director (recorded, not to be built yet)

| # | His words | Status |
|---|---|---|
| D1 | "\"wet\", could be replaced with an icon, unique icon for each weather condition (not high priority, dont build it now)" (match header "Away · Engie Stadium · Wet") | parked; not assigned |
