# Lever-truth audit (WIP, paused 2026-10-09 for ARD-M5-016)

ROADMAP §0.4.1 item 2, "every gameplay lever must work and its copy must tell the
truth". **Work in progress: paused for the director's P0 (2026 real lists mode).**
Not a finished register. Do not cite as complete.

## Running when paused
Three runs of `tools/audit/levers_pair_impl.gd` (paired, seeded, 6 pairings × 100
seeds = 600 paired matches per arm; baseline Balanced, Stay composed, Normal
rotations, no tag, no loose defender):

| Run | Arms |
|---|---|
| 37920222585 | plan_attacking, plan_defensive, plan_contest, plan_controlled |
| 37920238206 | plan_through_stars, pep_fire_up, pep_calm, tag |
| 37920246938 | rot_hard, rot_stars, loose |

Local smoke test (12 matches, noise only):
- tag: target disposals −5.3 ± 1.3;
- ride the stars: stars' time on ground +16.6 ± 4.6 exertion units.

### Results (all three runs green; 600 paired matches per arm, mean ± SE of the paired difference)

| Arm | Home margin | What the copy names | Reading |
|---|---|---|---|
| plan_attacking | −1.7 ± 1.8 | clangers +5.9 ± 0.3 | Process moves; no margin edge on average |
| plan_defensive | +4.1 ± 1.8 | pressure acts +18.9 ± 1.0 | Works; the only plan with a margin edge past 2 SE |
| plan_contest | −2.2 ± 1.7 | clearances +2.3 ± 0.3 | Process moves |
| plan_controlled | +0.9 ± 1.7 | clangers −4.4 ± 0.3 | Process moves (see the dead-branch suspect below) |
| plan_through_stars | +1.6 ± 1.7 | stars' share of disposals +1.4 pts ± 0.1 | Real but small; check the copy does not promise more |
| pep_fire_up | −1.7 ± 1.7 | contested +0.3 ± 0.3; clangers +5.3 ± 0.3 | Whole-match average: the contest lift applies only while behind (copy says so). Needs a behind-only split before any verdict |
| pep_calm | +0.0 ± 1.7 | clangers −4.1 ± 0.3 | Process moves |
| tag | −1.0 ± 1.8 | target's disposals −3.9 ± 0.2 | Works as written |
| rot_hard | +1.5 ± 1.5 | stars' exertion +3.6 ± 0.5 | Process moves |
| rot_stars | +1.0 ± 1.3 | stars' exertion +16.1 ± 0.6 | Works as written |
| loose | −2.1 ± 1.6 | team intercepts +0.1 ± 0.4 | **Suspect.** Baseline home side has no loose man (no assistant), so the arm adds one; team intercepts do not move. Next: read the loose-man copy, then measure the nominated man's own intercepts and marks |

Only the defensive plan's margin edge clears 2 SE; every arm is within a goal of the baseline.

### Follow-ups (`tools/audit/levers_followup_impl.gd`, run locally, 100 seeds × 6 pairings)

**Loose defender: confirmed defect.** Copy: "He leaves his direct man to attack aerial balls. Another defender covers where possible; if he flies and loses, space opens behind him." The nominated man is the home side's best interceptor (`Matchups.interceptor_score`), the same man in both arms; 600 pairs.

| Measure | Loose arm mean | Paired difference |
|---|---|---|
| He is the loose man (result `interceptor`) | 1.0 | set in every match |
| His contests as the roamer | 2.2 | +2.16 ± 0.05 (won 1.3, lost 1.4) |
| His intercepts (possessions + marks) | 11.2 | **−1.41 ± 0.22** |
| His spoils | 4.1 | **−1.41 ± 0.13** |
| His marks | 7.4 | +0.00 ± 0.13 |
| Team intercepts | 62.7 | +0.11 ± 0.35 |
| Team spoils | 16.2 | −1.10 ± 0.21 |
| Points conceded | 82.1 | **+2.44 ± 0.95** |
| Margin | | −2.94 ± 1.59 |

He attacks fewer aerial balls than he did as a direct defender, not more. The roam reaches about two contests a game (`_roam_chance` × `ROAM_REACH` 0.2), but losing his direct man takes him out of the entries he used to meet. The team pays the copy's cost (more conceded) without its upside.

(The table's intercept rows add `intercept_marks` to `intercepts`, which already includes them; the corrected runs below count `intercepts` alone.)

**Mechanism** (240 pairs; one-on-one contests from the duel log):
- In 83% of matches the best interceptor is on one of their key forwards (`Matchups.defaults`). Named loose, he gives up 5.3 one-on-one contests a game and roams to 2.2.
- His forward is always picked up by another defender and kicks +0.29 ± 0.09 goals and takes +0.70 ± 0.17 marks. That is the copy's cost, and it works.
- The upside is the gap. A roaming arrival *replaces* the defender who would have met the ball (`resolve_forward50`, `_general_aerial_contest`). It never adds a second body. Its only edge is `roam_shift`, which is at most −0.10 on the mark (about −0.04 for a typical loose man) and only applies at entries.

**Tuning variants tried** (local, not committed; 600 pairs unless marked):

| Variant | His intercepts | His roam contests | Team intercepts | Conceded | Margin |
|---|---|---|---|---|---|
| main (`ROAM_REACH` 0.2) | −2.3 (90 pairs) | 2.2 | ±0 | +2.4 ± 0.9 | −2.9 ± 1.6 |
| `ROAM_REACH` 0.5 | −0.3 ± 0.2 | 4.4 | −0.2 ± 0.3 | +1.4 ± 1.0 | +0.2 ± 1.7 |
| 0.5 + `roam_shift` up to −0.20 | −0.3 ± 0.2 | 4.3 | ±0 | +0.9 ± 1.0 | +1.1 ± 1.7 |
| `ROAM_REACH` 0.7 (240 pairs) | +0.7 ± 0.3 (11.2 a game) | 5.7 | −0.2 ± 0.4 | +0.8 ± 1.6 | +1.6 ± 2.8 |

No reach gives the team a gain, because a roam swaps one defender for another. A reach that gives him more intercepts than his direct job (0.7, 11.2 a game) breaks the director's #462 calibration ("bring him to ~8"). As a direct key back he already intercepts about 10.4. **This is a design conflict, not a constant to tune.** It goes to the lead before any fix PR.

**Fire them up while behind:** 338 paired quarters (Q2–Q4 the home side began behind in both arms). Clearances +0.35 ± 0.20 a quarter, share +0.7 pts ± 0.8, contested possessions +0.25 ± 0.23, clangers **+1.17 ± 0.20**, points +0.8 ± 0.7. The lift is real in the code (+0.018 at the contest) but hard to see; the cost is clear. Copy is true but the trade is lopsided: a candidate for the director, not a defect.

## Checked so far (code and copy)

| Lever | Copy | Code | Verdict so far |
|---|---|---|---|
| Plan at the first bounce (old C1) | "The game plan you take in" | The call box seeds from `_current_plan(sim)`, the engine's plan (`MatchScene.gd:604-607`) | **Fixed** since the 2026-09-29 reality audit |
| Pep talks | `CoachReport.PEP_SUMMARY` (`CoachReport.gd:44-48`) | `_contest_pep` lifts the contest only while behind (`MatchSim.gd:1252`); `PEP_CALM` / `PEP_FIRE` (`MatchSim.gd:1259-1275`) | Copy matches the code; effect being measured. Resets to Composed at each break (`MatchScene.gd:611`), consistent with a one-quarter talk |
| Rotations | `ROTATION_POLICIES` text (`MatchSim.gd:3391-3398`) | Swap thresholds by energy (`MatchSim.gd:3678`) | Being measured. Ride the stars: see TIRED_CALL_AUDIT |
| Controlled tempo | "Asks nothing special of your list" (`CoachReport.gd:40`) | `PlanFit.LEAGUE` has no "controlled" entry, so its fit is 1.0 (`PlanFit.gd:135-138`) and the upside scale ignores the list. But `_press_on` holds off a press only as far as `plan_fit["controlled"]` allows (`MatchSim.gd:729`), and that is clamped to ≤ 1.0 and always 1.0 here. **Suspect:** the "poor ball users only partly hold it off" rule in the `_press_on` comment never applies | **Probable dead branch.** Verify that `plan_fit["controlled"]` is always 1.0 |
| Event cards: rest / play sore / heavy / recovery / open / closed / suspend / back / promise / patience | `ClubLife.gd:352-412` | Flags read by Ratings (rested, `:746`), Injuries (sore / heavy_legs / fresh, `:30-33`), MatchSim (`:327-329`), Workload (`:66-70`); board and morale numbers match `resolve_week_event` | Wired as written (numbers match) |

### Option 1 built: the loose man as an extra body (claude/loose-extra-body @ 594f6e7a, WIP)

AFL BOSS picked option 1. The spare no longer replaces the defender who met the ball. That defender stays in the contest; the spare makes the mark harder (`_roam_mark_shift`), has his own fist at a ball the defender missed (`LOOSE_EXTRA` 0.35, scaled by his air game), and takes the ball when he is there. General-play contests work the same way.

**New evidence: who he stops meeting.** A second arm, `loose_free`, names the best interceptor who minds no key forward at the bounce. He still loses about 6 one-on-one contests and 4.5 rebounds a game. Key forwards are handed to free defenders during the match (interchanges and rematches), and a loose man is never handed one. So any loose man gives up most of his entry work, and the reach has to give it back.

| Variant (600 pairs unless marked) | Arm | His roam contests | His intercepts | Team intercepts | Conceded | Margin |
|---|---|---|---|---|---|---|
| Extra body, reach 0.2 (240 pairs) | best interceptor | 2.3 | −1.5 | −0.1 ± 0.4 | +0.8 ± 1.5 | −1.2 ± 2.5 |
| Extra body, reach 0.2 (240 pairs) | free defender | 1.8 | −4.0 | ±0 | −1.2 ± 1.4 | −1.3 ± 2.4 |
| Extra body, reach 0.7, mark edge ≤ 0.12 | best interceptor | 7.6 | **+1.7** (12.3 a game) | −0.4 ± 0.3 | +1.7 ± 1.1 | −2.2 ± 1.7 |
| Extra body, reach 0.7, mark edge ≤ 0.12 | free defender | 6.1 | −1.7 (8.8 a game) | −0.2 ± 0.3 | −0.8 ± 1.0 | +0.5 ± 1.7 |
| Extra body, reach 0.7, mark edge ≤ 0.25 (sensitivity) | best interceptor | 7.5 | +1.6 | −0.2 ± 0.3 | +0.0 ± 1.0 | −0.7 ± 1.7 |

**Why the team never moves.** On the best interceptor, his arrivals save about 1.5 marks a game, and the key forward he leaves takes about 1 mark and 0.36 goals more. They cancel, even with a mark edge twice as strong. On a free defender nobody is left alone and the sign turns slightly in your favour (conceded −0.8 ± 1.0), but that is within noise.

**This is a design question for the director, not a tuning one.** The engine resolves entries on line averages, so one extra defender is worth at most a point a game either way. Choices:
- (a) Accept a small, honest trade, and tell the player in the copy: freeing your key back frees their key forward.
- (b) Give the third man a decisive edge. That goes beyond what the sensitivity run shows is needed to move anything, so it would be a new rule, not a fix.
- (c) Measure the AI side's loose man against you: it uses the same rules at every club.

### Dual ruck (`levers_followup_impl.gd dual`, 600 pairs; both arms make the call explicitly)

Copy: "Dual ruck on: Auto-pick names a second ruck on the bench" (`SelectionScene.gd:97`).

| Measure | Dual-on mean | Paired difference |
|---|---|---|
| Rucks in the 23 | 2.00 | +0.67 ± 0.02 (some sides carry one anyway) |
| Team hit-outs | 41.6 | +1.10 ± 0.25 |
| Starting ruck's hit-outs | 35.4 | +0.18 ± 0.25 |
| Second ruck's hit-outs | 6.0 | +4.09 ± 0.26 |
| Starting ruck's exertion | 111.1 | +3.23 ± 0.25 |
| Clearances | 40.4 | +0.09 ± 0.22 |
| Margin | | +0.10 ± 1.28 |

**Verdict: works as written.** The copy promises a name on the bench, nothing more. The second ruck takes about 4 hit-outs a game that non-rucks took while the starter rested, which is one more hit-out for the team. There is no measurable effect at the clearance or on the scoreboard.

(A first pass read the "starting ruck" after the match, after interchanges had changed the ground, and showed a false +6.8 hit-outs for him. Fixed: he is now read before the first bounce.)

### Key match-ups (`levers_followup_impl.gd matchup`, 600 pairs)

Arm: their best key forward (`Matchups.key_forwards`, first) on your weakest aerial defender (`set_matchup`). Baseline: the default, your best key defender on him (`Matchups.defaults`).

| Measure | Arm mean | Paired difference |
|---|---|---|
| Their key forward's goals | 2.26 | **+0.72 ± 0.07** |
| His marks | 6.48 | +1.92 ± 0.12 |
| His contested marks | 4.50 | +1.77 ± 0.10 |
| Points conceded | 83.1 | **+3.45 ± 0.87** |
| Margin | | −3.57 ± 1.44 |

**Verdict: works.** Who minds whom is one of the biggest single calls measured here, about a goal-and-a-half swing in conceded points. That agrees with `docs/KEY_MATCHUPS_AUDIT_2026-10-06.md` (an elite forward marks 76% on an average defender, 57% on an elite one).

### Backing, the media conference, the board (code and copy)

| Lever | Copy | Code | Verdict |
|---|---|---|---|
| Back him for three games (`ClubLife._young_gun`) | "he is thrilled (morale +5) ... expects to be picked for the next three games. Leave him out while he is fit and the promise breaks (-10)" | +`THRILL` 5 (`GameState.gd:7211`); auto-pick names him (`Ratings.select_22` promised); broken: −`STING` 10 × (1 − man-manager softening) (`GameState.gd:6807`); a senior game earns `XP_SELECTED` + `XP_NAMED` + performance, more than reserves | **Works.** Small imprecision: "(-10)" is the most it costs; a good man-manager softens it (`CoachEffects.softened`), and the copy doesn't say so |
| Media conference answers (`MediaConference._q`) | The button shows only the answer's words (`HubScene._show_media_conference`) | Accountable: board +1, every listed player's morale −1. Tactical: nothing. Protective: board −1, morale +1 (`resolve_media_conference`) | **Hidden effect.** The player can't see that an answer moves board confidence (±1 of 100) and the whole list's morale (±1). The board's "why" line names the comments afterwards. A "no hidden modifiers" question for the director: show the effect, or keep the press flavour-only. The effects are tiny either way |
| Board goal and confidence (`_board_season_end`) | Goal text, confidence, warning, sacking | Met or missed, then `ClubLife.after_season`; a warning below `WARN_LINE`, the sack on a second miss | Wired as written (state is shown in the board panel) |

### Development projects, the payback (`tools/audit/projpair_impl.gd` on audit.yml; seeds 301–306, 3 seasons; each project player paired with his no-project self)

| Club (run) | Projects / learned | OVR vs self, project season | OVR vs self, two seasons on | Extra weeks played out of his line |
|---|---|---|---|---|
| MEL (37928374658) | 41 / 34 | −0.20 ± 0.08 | +0.42 ± 0.21 | +1.6 ± 1.1 |
| GEE (37928378497) | 39 / 38 | −0.26 ± 0.08 | +0.54 ± 0.21 | +0.2 ± 0.2 |
| COL (37928382115) | 38 / 30 | −0.24 ± 0.09 | +0.56 ± 0.18 | +1.4 ± 1.0 |

**Verdict: works as written.** The stated price (a lower training limit in the project season) costs about 0.2 OVR. The payback (limit +1 the season after) more than repays it two seasons on, and POT never moves. The auto-pick's use of a learned position is real but small and club-dependent. The ROADMAP's 0.8 OVR cost figure came from `devproj_impl`, which compares against team-mates, not against the same player. The self-paired cost is smaller.

### Department budget (code and copy; `ClubBudget.gd`)

| Area | Copy (`benefit_text`) | Code | Verdict |
|---|---|---|---|
| Recruiting | Prospect scouting uncertainty ±25/20/35% | `DraftScouting.pot_read(..., scouting_mult)` (`GameState.gd:2761`, `:3794`) | Wired; numbers match |
| Development | Players 22 and under earn ±10/10/15% XP | `_xp` gain × `development_mult`, your club only, age ≤ `YOUNG_AGE` (`GameState.gd:2867`) | Wired; numbers match |
| High performance | Weekly workload recovery ±10/10/20% | `Workload.advance_week(..., recovery_mults)` (`GameState.gd:3243`) | Wired; numbers match |
| Football department | "Gameplan execution is 5% lower / 5% / 8% higher" | × `tactics_exec`, which scales only a plan's *upside* keys (`MatchSim._pv`, `PLAN_UPSIDE`) | **Copy gap.** On Balanced (no upside keys) it does nothing. On another plan it moves the upside by 5–8% of itself (Attacking's goal edge 1.05 → about 1.054). True, but the copy does not say it needs a plan other than Balanced. Not measured: the effect is a fraction of the plan arms above, which are already near noise on the margin |

## Prior evidence to cite (verify still current)
- `docs/SYSTEM_REALITY_AUDIT.md` (2026-09-29): moment cards, tagging, Through stars, morale, form.
- `docs/LEVERS_EVIDENCE_2026-10-05.md`: plan calls.
- `docs/TIRED_CALL_AUDIT_2026-10-05.md`: the tired-star card barely matters, and its copy omits the auto-return.
- `docs/FOCUS_EVIDENCE_2026-10-07.md`: Play through works on the man; team score is flat.
- `docs/KEY_MATCHUPS_AUDIT_2026-10-06.md`, `docs/research/INTERCEPT_EVIDENCE.md`, `docs/research/SET_SHOT_EVIDENCE.md`.
- `docs/SYNERGY_EVIDENCE_2026-10-06.md`, `docs/research/RPG006_STAFF_IDENTITY_AUDIT.md` (staff; teaching was fixed on claude/rpg006-teaching).

## Not yet started
- Selection: best 23, dual ruck, match-ups, interchange.
- Training plans and projects (`tools/audit/projpair_impl.gd` exists).
- Department budget, difficulty.
- Contracts, trades, draft and scouting.
- Backing, the media conference, the board.
- Synergies UI.
- The settings sweep (cosmetic check).
