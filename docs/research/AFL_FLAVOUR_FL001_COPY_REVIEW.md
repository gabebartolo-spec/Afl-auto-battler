# FL-001 copy review sheet

For the director. FL-001 (football voice and restrained humour, [roadmap §9.3](../roadmap/21-9-3-approved-flavour-and-culture-work-director-decisions.md#93-approved-flavour-and-culture-work--director-decisions-2026-10-06)) asks for natural, affectionate football language on optional captions, with plain action labels. The lead ruled that no copy beyond the two approved lines is written without your review, so **this sheet proposes no new wording for the game**. Every row is a question. Candidate lines come only from your approved samples ([AFL_FLAVOUR_WRITING_SAMPLES.md](AFL_FLAVOUR_WRITING_SAMPLES.md)); where there is no approved line, the row is blank for you.

Answer each row with **Keep** (leave the current words), **Use** (the approved candidate), **Edit** (write the line) or **Skip**.

## Director decisions after the copy audit — 2026-10-06

Use **“200 games. Take a bow, {display_name}.”** for the genuine 200-career-game banner. The director removed the first-goal flavour headline, vague defender headline and tape notice from the samples. These decisions supersede the affected earlier candidates. Preserve existing factual milestone reporting; no pre-match banner may anticipate a future goal. A defender headline should state the actual supported achievement.

## 1. Already on main (slice 1, PR #258)

| Surface | Words | Shown only when |
|---|---|---|
| Pre-match scene, first caption | **Finals footy. Here we go.** (instead of "Warming up") | the fixture's label says it is a final; never on a round |
| Pre-match scene, run-out caption | **Through the banner** (was "Running through the banner") | always |

Unchanged: "Warming up" for rounds, "Final instructions", the club banner.

## 2. Where plain optional copy exists today

These are the surfaces I found that carry optional words (not controls, not scores). The current text is quoted as it appears.

| # | Surface (code) | Current words | Truth available | Approved candidate | Decision |
|---|---|---|---|---|---|
| 1 | Hub, a bye week (`HubScene.gd` ~413) | "Bye" / "No game for you in Round 7. The rest of the league plays on." | the club has no fixture this round | none; already plain and warm | |
| 2 | Hub, knocked out of finals (`HubScene.gd` ~425) | "Knocked out" / "Your finals campaign is over. Sim the rest of the series to see who lifts the cup." | the club was eliminated | "The end of the road this year." (sample §2, only on actual elimination) | |
| 3 | Hub, missed the finals (`HubScene.gd` ~429) | "Season over for you" / "You missed the top 10. Sim the finals series to see who lifts the cup." | home-and-away ended outside the top ten | none | |
| 4 | Hub, season complete (`HubScene.gd` ~399) | "Season complete" / "Premiers: {club}" | the Grand Final is decided | "A year worth remembering." (sample §2; only beside specific true campaign beats) | |
| 5 | Full time (`MatchNotes.gd` ~78) | "Full time: {club} win by {n}" | the final score | none: the sample says keep the exact score and outcome easy to find, and neutral reporting is usually preferable to a joke | |
| 6 | Offseason empty states (`OffseasonScene.gd` ~186, ~400, ~501) | "Nobody is out of contract this year." / "No club has made an offer." / "No free agents right now. Rivals let players go when the season ends." | the list is actually empty | none | |
| 7 | Season Review, no achievements (`SeasonReviewScene.gd` ~429) | "Nothing unlocked yet - every club's achievement is a piece of its history." | none unlocked | none; already in voice | |
| 8 | Milestone news lines (`GameState._player_milestone_news`) | "{name} kicked his first AFL goal for {club}." / "{name} reached 100 career goals." | complete career on record (already required) | none; director removed the first-goal flavour candidate on 2026-10-06 | |
| 9 | Clubroom notices | no such surface exists | n/a | none; the samples only imagine one as a background art detail | |

## 3. What I found

- **Most of the approved lines belong to other FL items.** Rows 2, 4 and 8 are headlines (FL-006). Milestone and tenure banners are FL-002. Nicknames and interests are FL-005, and club memories FL-008. FL-001 is the voice on captions that have no FL item of their own: after slice 1, that is rows 1, 3, 6 and 7. All four are already plain, and rows 1 and 7 are already warm.
- **My recommendation:** treat FL-001 as complete after slice 1 unless you want specific rewrites of rows 1, 3, 6 or 7, and let FL-006 and FL-002 carry the headline and banner lines under their own gates. The roadmap says "silence is valid", and these surfaces are mostly silent already.
- **Row 3 and row 2 are state-coloured** (the "BAD" colour marks a genuine state). Softening them with a joke would blunt a real state; I would not.

## 4. Questions only you can answer

1. **How much humour, and where?** Suggested limits to approve or change: at most one flavour line per screen; none beside a loss, an injury, a sacking or a suspension; each joke line can be switched off and never repeats two weeks running.
2. **Is a loss ever flavoured?** The samples say neutral loss reporting is usually better. A yes needs a list of which losses.
3. **Fictive mode.** Every line uses the displayed name only, so a real identity can never leak through a line in fictive-name mode. Confirm.
4. **Ownership split.** Confirm that headline and banner lines go to FL-006 and FL-002 and not to FL-001, as in section 3.
5. **Clubroom notices** (row 9): do you want a place for them at all, or are they an art detail only?

Nothing here is built. Rows marked Use or Edit become small PRs, each with a truth predicate and a test of the predicate only (never of the static words), as FL-001's own validation rule says.
