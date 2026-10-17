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


## Established list additions rated on their record (A28)

Cause of the Tom Green rating: the 137 players in data/list_additions_2026.csv played no senior game in 2026, so the game rated every one as a draft prospect (OVR 41-59 from a draft-rank formula) even with a long career. tools/build_addition_stats.py now matches each to AFL Tables season pages (2025 back to 2021: most recent season of 6+ games, else most recent with any), checks birth year on his AFL Tables page (rejects namesakes such as the 2007 Sydney Max King), and writes data/list_additions_stats.csv (54 players). GameDB._load_list_additions rates them through Ratings.derive_all(established, players) (league rates and scaling come from the main pool, which is not changed), then Potential.assign. A position the list gives overrides the stat-derived first position. The other 83 stay prospects. Positions: tools/fill_addition_positions.py filled 79 from Footywire's team player pages (first listed position); 48 players not on their club's current page keep the earlier fill or the height roll.

Before and after (OVR, first position, POT, games and season used; from tools/audit/additions_ovr_impl.gd; sorted by new OVR; older seasons are not age-adjusted):

```
GWS Tom Green              MID->MID  OVR 54->86 POT 54->86 gm23 src2025
MEL Steven May             DEF->DEF  OVR 51->80 POT 51->80 gm16 src2025
ESS Nic Martin             MID->DEF  OVR 52->78 POT 55->81 gm16 src2025
GEE Tyson Stengle          FWD->FWD  OVR 55->69 POT 55->69 gm24 src2025
BRL Jack Payne             DEF->DEF  OVR 56->66 POT 56->66 gm13 src2025
GCS Caleb Graham           FWD->DEF  OVR 56->62 POT 58->64 gm15 src2022
MEL Shane McAdam           FWD->FWD  OVR 52->62 POT 52->62 gm7 src2023
PAD Sam Powell-Pepper      MID->FWD  OVR 52->62 POT 52->62 gm16 src2025
BRL Tom Doedee             DEF->DEF  OVR 53->61 POT 53->61 gm11 src2023
GWS Josh Kelly             MID->MID  OVR 52->61 POT 52->61 gm15 src2025
ADE Lachlan Sholl          DEF->DEF  OVR 53->60 POT 53->60 gm20 src2024
PAD Ivan Soldo             RUCK->RUCK  OVR 52->60 POT 52->60 gm8 src2024
SYD Taylor Adams           MID->MID  OVR 55->60 POT 55->60 gm19 src2024
FRE Sam Sturt              FWD->FWD  OVR 53->59 POT 55->61 gm13 src2024
COL Bobby Hill             FWD->FWD  OVR 52->58 POT 52->58 gm14 src2025
STK Paddy Dow              MID->MID  OVR 55->58 POT 55->58 gm10 src2024
CAR Harry O'Farrell        FWD->DEF  OVR 56->57 POT 70->70 gm6 src2025
GWS Darcy Jones            DEF->MID  OVR 53->57 POT 60->64 gm23 src2025
WCE Clay Hall              MID->MID  OVR 51->57 POT 63->69 gm13 src2025
GEE Toby Conway            RUCK->RUCK  OVR 52->56 POT 60->64 gm5 src2024
HAW James Blanck           DEF->DEF  OVR 55->55 POT 57->57 gm15 src2023
MEL Jed Adams              DEF->DEF  OVR 53->55 POT 61->63 gm1 src2025
WBD Riley Garcia           FWD->MID  OVR 52->55 POT 54->57 gm8 src2025
WBD James Harmes           MID->MID  OVR 52->55 POT 52->55 gm13 src2025
COL Reef McInnes           FWD->FWD  OVR 50->54 POT 56->60 gm9 src2024
FRE Josh Draper            FWD->DEF  OVR 53->54 POT 63->64 gm11 src2025
NTH Jackson Archer         MID->DEF  OVR 51->54 POT 60->63 gm15 src2024
BRL Henry Smith            RUCK->FWD  OVR 55->53 POT 60->58 gm2 src2025
CAR Jesse Motlop           FWD->FWD  OVR 56->53 POT 66->63 gm23 src2025
ESS Liam McMahon           FWD->FWD  OVR 51->53 POT 54->56 gm7 src2025
FRE Hugh Davies            DEF->DEF  OVR 53->53 POT 61->61 gm2 src2024
PAD Josh Sinn              MID->DEF  OVR 52->53 POT 58->59 gm20 src2025
WCE Tyler Brockman         FWD->FWD  OVR 49->52 POT 54->57 gm20 src2025
WCE Lucca Grego            MID->MID  OVR 59->52 POT 72->62 gm1 src2025
CAR Lucas Camporeale       DEF->MID  OVR 57->51 POT 70->64 gm3 src2025
COL Tew Jiath              DEF->MID  OVR 52->51 POT 63->62 gm1 src2024
ESS Lewis Hayes            FWD->MID  OVR 54->51 POT 62->59 gm1 src2025
FRE Cooper Simpson         DEF->DEF  OVR 54->51 POT 62->59 gm3 src2025
MEL Tom Campbell           RUCK->RUCK  OVR 52->51 POT 52->51 gm9 src2021
RIC Kaleb Smith            FWD->DEF  OVR 50->51 POT 58->59 gm8 src2025
COL Jakob Ryan             DEF->MID  OVR 49->50 POT 55->56 gm1 src2023
GEE Jed Bews               DEF->DEF  OVR 51->50 POT 51->50 gm15 src2023
MEL Jack Henderson         MID->MID  OVR 48->50 POT 48->50 gm5 src2025
STK Alex Dodson            RUCK->MID  OVR 54->50 POT 66->63 gm1 src2025
WCE Harry Barnett          RUCK->MID  OVR 53->50 POT 62->59 gm1 src2024
BRL Luke Beecken           MID->MID  OVR 51->49 POT 56->54 gm1 src2025
WCE Tyrell Dewar           MID->DEF  OVR 49->49 POT 60->60 gm16 src2025
WCE Finlay Macrae          MID->MID  OVR 54->48 POT 61->55 gm9 src2024
PAD Mani Liddy             MID->MID  OVR 53->47 POT 59->53 gm9 src2025
RIC Tom Sims               FWD->MID  OVR 54->46 POT 65->59 gm11 src2025
STK Lance Collard          FWD->FWD  OVR 49->45 POT 64->60 gm12 src2025
WCE Noah Long              FWD->MID  OVR 54->43 POT 61->50 gm10 src2025
ADE Sid Draper             MID->MID  OVR 53->42 POT 63->54 gm10 src2025
NTH Robert Hansen          MID->MID  OVR 53->41 POT 64->52 gm12 src2025
```

Caveats: players with one to three games in their season (Grego, Hayes) are rated on a very small sample, shrunk toward the league average by the usual rule. Seasons 2021-2023 (Campbell, Doedee, Bews, Blanck, McAdam, Graham) are old records. The table is from the run before two later changes, so a few roles and OVRs will differ in the merged build: a listed position now becomes his first position (Powell-Pepper, Sinn, Archer, Nic Martin follow the list), and 79 positions came from Footywire after the table. No local Godot ran after that; CI is the check.
