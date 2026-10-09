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

## Checked so far (code and copy)

| Lever | Copy | Code | Verdict so far |
|---|---|---|---|
| Plan at the first bounce (old C1) | "The game plan you take in" | The call box seeds from `_current_plan(sim)`, the engine's plan (`MatchScene.gd:604-607`) | **Fixed** since the 2026-09-29 reality audit |
| Pep talks | `CoachReport.PEP_SUMMARY` (`CoachReport.gd:44-48`) | `_contest_pep` lifts the contest only while behind (`MatchSim.gd:1252`); `PEP_CALM` / `PEP_FIRE` (`MatchSim.gd:1259-1275`) | Copy matches the code; effect being measured. Resets to Composed at each break (`MatchScene.gd:611`), consistent with a one-quarter talk |
| Rotations | `ROTATION_POLICIES` text (`MatchSim.gd:3391-3398`) | Swap thresholds by energy (`MatchSim.gd:3678`) | Being measured. Ride the stars: see TIRED_CALL_AUDIT |
| Controlled tempo | "Asks nothing special of your list" (`CoachReport.gd:40`) | `PlanFit.LEAGUE` has no "controlled" entry, so its fit is 1.0 (`PlanFit.gd:135-138`) and the upside scale ignores the list. But `_press_on` holds off a press only as far as `plan_fit["controlled"]` allows (`MatchSim.gd:729`), and that is clamped to ≤ 1.0 and always 1.0 here. **Suspect:** the "poor ball users only partly hold it off" rule in the `_press_on` comment never applies | **Probable dead branch.** Verify that `plan_fit["controlled"]` is always 1.0 |
| Event cards: rest / play sore / heavy / recovery / open / closed / suspend / back / promise / patience | `ClubLife.gd:352-412` | Flags read by Ratings (rested, `:746`), Injuries (sore / heavy_legs / fresh, `:30-33`), MatchSim (`:327-329`), Workload (`:66-70`); board and morale numbers match `resolve_week_event` | Wired as written (numbers match) |

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
