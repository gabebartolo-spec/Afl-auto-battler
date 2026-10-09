# 2026 club lists: completeness manifest (ARD-M5-016)

The 2026 real lists game mode needs every club's real end-of-2026 list. `data/players_2026.csv` has the 669 players who played a senior game in 2026. Clubs also had registered players who never played a senior game; they are listed here and in `data/list_additions_2026.csv`. No fictional fillers. Checked 2026-10-09.

## Counts

**806 registered, 669 in the game, 137 missing.** 806 − 669 = 137 exactly, and every one of our 669 is on a registered list.

| Club | Registered (senior / rookie / Cat B) | Ours | Missing |
|---|---|---|---|
| ADE | 42 (37 / 5 / 0) | 38 | 4 |
| BRL | 43 (37 / 5 / 1) | 35 | 8 |
| CAR | 46 (36 / 8 / 2) | 39 | 7 |
| COL | 46 (36 / 9 / 1) | 35 | 11 |
| ESS | 46 (36 / 8 / 2) | 41 | 5 |
| FRE | 44 (36 / 6 / 2) | 32 | 12 |
| GCS | 44 (37 / 5 / 2) | 36 | 8 |
| GEE | 44 (38 / 4 / 2) | 32 | 12 |
| GWS | 44 (38 / 3 / 3) | 37 | 7 |
| HAW | 44 (38 / 4 / 2) | 40 | 4 |
| MEL | 47 (36 / 10 / 1) | 37 | 10 |
| NTH | 44 (38 / 6 / 0) | 36 | 8 |
| PAD | 46 (36 / 8 / 2) | 39 | 7 |
| RIC | 44 (38 / 5 / 1) | 41 | 3 |
| STK | 43 (38 / 3 / 2) | 36 | 7 |
| SYD | 44 (37 / 5 / 2) | 36 | 8 |
| WBD | 44 (38 / 6 / 0) | 39 | 5 |
| WCE | 51 (38 / 11 / 2) | 40 | 11 |
| **All** | **806** | **669** | **137** |

## Sources and method

- **The register:** [Draftguru, AFL club lists 2026](https://www.draftguru.com.au/lists/2026), one page per club (`/lists/2026/<club>`). It gives the number, the list (senior, rookie, Category B), the name, date of birth and height.
- **Zero senior games:** [AFL Tables, 2026 player statistics](https://afltables.com/afl/stats/2026.html) lists exactly 669 players with a 2026 senior game, the same 669 the game has.
  - Every listed player not in our data was checked by full name against it.
  - The one hit, Sydney's Max King, is a namesake: AFL Tables' Max King is St Kilda's, who is in the game.
  - Five near-collisions on surname and initial were confirmed by full first name: Sid Draper (not Sam), Bobby Hill, Logan Smith, Max King (SYD) and Noah Long.
- **Second source:** Wikipedia's club squad templates (`Template:<Club> AFL personnel`), read at their last revision on or before 30 September 2026, after the Grand Final and before the trade period.
  - They agree with Draftguru, except that Wikipedia had already taken off players whose retirement or delisting was announced at season's end (e.g. Scott Pendlebury, Steele Sidebottom, Taylor Walker, Dion Prestia). Those players were still registered for 2026.
  - **36 of the 137** are among them, marked `on_wikipedia_2026_09_30 = no`.
  - Today's Wikipedia templates already show 2026 trade-period moves, so they are 2027 lists and were not used for counts.
- **Not used:** club and afl.com.au list pages now show 2027 lists, mid-trade period.

## The file

`data/list_additions_2026.csv` (keep importer). Columns:

`first, last, dob (YYYY-MM-DD), club, position, height_cm, list (senior | rookie | cat_b), on_wikipedia_2026_09_30, source_url, checked`

**Position is blank for all 137.** Neither source gives one, and most of these players have no Wikipedia infobox. A position is not guessed: the mode can derive a role from the prospect model as it does for draftees, or positions can be sourced per player from club profile pages later.

## Who is missing, by club

- **ADE** (4): Sid Draper, Tyler Welsh (r)†, Mitchell Marsh, Lachlan Sholl†
- **BRL** (8): Tom Doedee, Luke Beecken (r), Luke Lloyd, Koby Evans, Henry Smith, Reece Torrent, Jack Payne, Tai Hayes
- **CAR** (7): Jesse Motlop†, Ben Camporeale†, Lucas Camporeale†, Harry O'Farrell, Harry Charleson (r)†, Rob Monahan (B)†, Matt Duffy (B)†
- **COL** (11): Harry Demattia, Tyan Prindable, Tew Jiath, Iliro Smit (r)†, Bobby Hill†, Jakob Ryan†, Reef McInnes, Joel Cochran†, Zac McCarthy, Jai Saxena (r), Harrison Coe (r)
- **ESS** (5): Lewis Hayes, Kayle Gerreyn, Nic Martin, Cillian Bourke (B), Liam McMahon (r)†
- **FRE** (12): Sam Sturt†, Hugh Davies, Adam Sweid, Leon Kickett (r), Charlie Nicholls, Toby Whan (B), Cooper Simpson, Ollie Murphy†, Josh Draper, Jaren Carr, Ryda Luke (B)†, Aiden Riddle (r)
- **GCS** (8): Elliot Himmelberg, Cooper Bell, Zak Evans (B), Max Knobel (r), Avery Thomas, Asher Eastham (r), Koby Coulson, Caleb Graham
- **GEE** (12): Toby Conway, Tyson Stengle†, Jacob Molier, Hunter Holmes, Lennox Hofmann, Jed Bews, Jesse Mellor (B), Harley Barker, Nick Driscoll (r), Keighton Matofai-Forbes (r), Joe Pike (r), Cillian Burke (B)
- **GWS** (7): Darcy Jones, Tom Green, Josh Kelly, Oskar Taylor, Logan Smith, Nathan Wardius (r), Finnegan Davis
- **HAW** (4): Matthew LeRay, Cody Anderson†, James Blanck†, Jaime Uhr-Henry (B)†
- **MEL** (10): Steven May†, Thomas Matthews, Shane McAdam†, Jed Adams, Tom Campbell†, Kalani White (r), Ricky Mentha (B)†, Riley Onley (r), Jack Henderson (r), Max Mapley (r)
- **NTH** (8): Luke Urquhart, Blake Thredgold†, Hugo Mikunda, Brayden George, Jackson Archer†, River Stevens, Oliver Griffin (r), Robert Hansen (r)†
- **PAD** (7): Sam Powell-Pepper, Josh Sinn, Ivan Soldo†, Benny Barrett (B)†, Jacob Moss (B)†, Xavier Walsh (r)†, Mani Liddy (r)†
- **RIC** (3): Josh Smillie, Tom Sims, Kaleb Smith†
- **STK** (7): Lance Collard, Paddy Dow, James Barrat, Alex Dodson, Patrick Said (r), Kye Fincher, Eamonn Armstrong (B)
- **SYD** (8): Taylor Adams†, Jevan Phillipou, Riak Andrew, Ned Bowman, Max King, Liam Hetherton (B), Patrick Snell, Noah Chamberlain (B)
- **WBD** (5): Will Darcy, Caleb May (r), Riley Garcia, Zac Walker (r), James Harmes†
- **WCE** (11): Tyler Brockman, Sam Allen, Noah Long†, Clay Hall, Harry Barnett, Lucca Grego, Tylah Williams, Fred Rodriguez (r), Tyrell Dewar, Finlay Macrae (r), Jake Miles-Wrency (B)

(r) rookie list; (B) Category B rookie; † off Wikipedia's list by 30 September (an end-of-season retirement or delisting).
