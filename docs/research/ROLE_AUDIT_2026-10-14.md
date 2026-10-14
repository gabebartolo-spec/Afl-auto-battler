# Role audit, 2026-10-14

Director (2026-10-14): Tom Green (GWS) wrongly a small defender, an elite inside midfielder; Tom Stewart (GEE) wrongly a small defender; the older register item 21 (Miers a forward, Uwland not key, Langford a wing). Method: `tools/audit/role_flags_impl.gd` prints every 2027-list player (669) with listed position, the game's first position and identity, and per-game clearances, contested possessions, disposals, rebounds, marks, inside 50s, tackles, goals and height. Flags were read against the listed position (afltables/club lists) and the per-game numbers. Real 2025 role and role names below are from the listed position and the numbers; I did not pull Champion Data centre-bounce attendances (not in the repo and not fetched), so "real role" for the flagged names is the listing plus football knowledge, not a sourced CBA count.

## Systematic errors found and fixed

| Rule | Evidence | Fix |
|---|---|---|
| Small defender chosen by carry + intercept alone | 94 defenders read "Small defender", heights 168-198 cm (median 185). Stewart (190 cm, 5.9 rebounds, 5.6 marks) is a ball-playing general defender. | Small defender only at 186 cm or under; taller or unrecorded is Defender. Result: Small 94 to 59 (all 168-186 cm), Defender 63 to 98, Key defender unchanged at 72. |
| Wing chosen by running percentile gap | Elite ball-winners read Wing: Errol Gulden (SYD, 4.6 clearances, 8.9 contested a game), Finn Callaghan (GWS, 4.4 / 8.3), Max Holmes (GEE, 4.2 / 9.1), Jordan Dawson (ADE, 4.1 / 9.1). | A midfielder with 3.5+ clearances or 8+ contested possessions a game (6+ games) is never a Wing. These four are Inside midfielders; Wings 72 to 68. |
| Listed players with no position guessed from height by a hash roll | 136 of 137 `list_additions_2026.csv` rows have a blank position, so `GameDB.listed_role` rolled DEF/FWD/MID. Tom Green (191 cm) rolled DEF. | Filled the position for 24 established players I am sure of (Green, Josh Kelly, Taylor Adams, Powell-Pepper, Harmes, Dow, Nic Martin, Draper: MID; May, Doedee, Bews, Blanck, Sholl: DEF; Himmelberg, Stengle, McAdam, Hill, Motlop, Sturt, Collard, King, Brockman: FWD; Campbell, Conway, Soldo: RUCK). |

## Still open (not fixed here)

- 112 list additions, mostly 2024-25 draftees and rookies, still take a height-rolled position. Their real positions need a sourced list (club sites, AFL.com.au); I did not guess them.
- Tom Green and every list addition has no senior numbers in the data, so he is rated as a mid-first-round prospect (draft rank 22-60), not the elite player he is. That is a rating, not a role, question; it needs the director or a stats source for 2025 and an OVR override (the ovrfix builder's data/ovr_overrides.csv is the place).
- Toby Greene is listed MID but his numbers make him a Forward (correct in real life; his listing is the soft one).

## Listed vs derived disagreements reviewed (all plausible, no change)

Listed MID, derived elsewhere (19): Toby Greene FWD, Sam Lalor FWD, Mark Blicavs RUCK, and 16 as DEF (Wagner, Cook, Wood, Retschko, Cumming, Wehr, Acres, Hollands, Tunstill, Kondogiannis, Murray, Jepson, Scott, Lukosius, Nairn); each shows under 2.5 clearances and 5.5 contested a game, rebounds and marks high for a back. Listed FWD/DEF, derived MID (6): Richards, Macdonald, Reid, Kennedy, McKercher, Scerri; small players with midfield-sized disposals. Left to the numbers as designed.

## Small defenders now (186 cm or less, 59)

Includes the genuine rebounders (Ash, Roberts, Milera, Florent, Houston, Clark, Bergman, McVee). James Sicily (186 cm, 7.1 marks) is borderline; left as the numbers read him.

## Match impact

Wing and Inside midfielder labels feed auto-selection of the two wing spots (Roles.mark_wings), and the identity shown. Paired-seed 400-match comparison of league scoring and clearances, main against this branch (`statint_impl`, AUDIT_SEED 7000): run 38535905841 (main) against 38535909603 (this branch), 400 matches each, same seeds: every STATINT line is identical (total score 178.84, clearances 37.81, contested possessions 88.28, tackles 59.05, goals 13.29). Expected: the labels do not enter the engine (wings are picked by centre_fit/wing_fit, not is_wing), and list additions are not in `club_list`. Zero sim effect. Balance is the director's call.
