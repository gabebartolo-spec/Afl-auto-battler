# Open AFL Data Sources — Champion Data Replacement

This project abandoned Champion Data (paid, OAuth, Auth0, licence-restricted). Below is the full map of **free/open sources** found via GitHub, Reddit, R packages, and web search, with what they cover vs our wishlist.

## What we have vs wishlist

Base: `data/players_2026.csv` — 669 players, season totals only:
`gm,ki,mk,hb,di,gl,bh,ho,tk,rb,if50,cl,cg,ff,fa,br,cp,up,cm,mi,onepct,bo,ga,pctp`

Wishlist:
- Bio: DOB/age, height_cm, weight_kg, foot, debut/draft year/pick/type, real listed position DEF/MID/RUC/FWD, rookie/senior, contract years/free agency, injury list
- Advanced: CBA, CBA%, centre/stoppage clearances, metres gained, disposal efficiency %, intercepts, tackles i50, TOG%, pressure acts, spoils, kick-ins, xScore
- Per-match player stats
- Fantasy/SuperCoach positions/prices/scores
- Real 2026 fixture/results/crowds/venues/ladder, Brownlow per match, coaches votes, tips/predictions, head-to-head

---

## Tier 1 — Directly usable, free, no key (or free key)

### 1. Squiggle API — fixture, results, ladder, tips
- **URL:** `https://api.squiggle.com.au/?q=games;year=2026` etc
- **Docs:** `https://api.squiggle.com.au/`
- **Licence:** Public basic data (scores, fixture, ladder). ToS asks for descriptive User-Agent with contact email, cache aggressively, don't make browsers fetch directly.
- **Status:** ✅ LIVE (verified 2026-09-22 via fetch_page: 2026 Opening Round + 23 rounds returned)
- **Endpoints:**
  - `?q=games;year=2026` → id, round, roundname, date, venue, hteam/ateam, hscore/ascore, hgoals/abehinds, winnerteamid, complete%, is_final, is_grand_final, updated
  - `?q=standings;year=2026` → rank, pts, played, wins/losses/draws, for/against, percentage, goals_for/behinds_for etc
  - `?q=teams` → id, name, abbrev, logo, debut/retirement
  - `?q=tips;year=2026`, `?q=sources`, `?q=ladder;year=2026` → crowd-sourced tips/predictions
- **Covers:** ✅ real 2026 fixture/results/venues/ladder, ✅ tips/predictions
- **Does NOT:** advanced stats, bio, Fantasy prices
- **How to use:** `curl -A "AFL Auto Battler - you@example.com" "https://api.squiggle.com.au/?q=games;year=2026"`
- **Reddit note:** r/AFL recommends Squiggle as most reliable free fixture source.

### 2. AFL Tables — season totals + per-match + bio
- **URL:** `https://afltables.com/afl/stats/2026.html` (player stats), `.../alltime/adelaide.html` (All Time Player List with DOB, height, weight, debut), `.../teams/.../2026_gbg.html` (game-by-game)
- **Docs:** `https://afltables.com/afl/notes.html` — volunteer archive since 1999, unofficial, no claim 100% accuracy.
- **Licence:** Facts are not copyrightable; volunteer archive, non-commercial fan use with attribution is standard. No explicit API terms.
- **Status:** ✅ LIVE (verified via fetch_page)
- **Covers:**
  - ✅ season totals (already used)
  - ✅ per-match player stats via team gbg pages
  - ✅ DOB, debut, height, weight via All Time list
  - ✅ Brownlow per match (via match pages)
  - ✅ venue, attendance, umpires
- **Does NOT:** CBA, TOG%, Fantasy, contracts
- **How to use:** Existing `tools/scrape_afltables.py` (stdlib urllib + regex, polite 1s sleep). For bio, parse alltime pages: pattern `<a href=".../players/X/Name.html">Last, First</a> ... YYYY-MM-DD ...`
- **Edge:** This is what fitzRoy and akareen both scrape upstream.

### 3. Wheelo Ratings — 60+ advanced stats, CSV download
- **URL:** `https://www.wheeloratings.com/afl_stats.html?comp=afl&season=2026`
- **About:** `https://www.wheeloratings.com/about.html` — data sourced from fitzRoy R package with permission.
- **Licence:** Personal non-commercial use, attribution to Wheelo Ratings + fitzRoy/AFL Tables/Footywire. Not for redistribution as-is but derived ratings ok.
- **Status:** ✅ LIVE (JS-rendered table, but CSV download works in browser)
- **Stats (60+):**
  - General: Player Rating (official AFL Ratings), Supercoach, Fantasy, Coaches Votes total/avg/matches polled, B&F, TOG%, TOG
  - Disposals: Kicks, HBs, Disposals, Kick%, Inside50s, Rebound50s, Metres Gained, Metres Gained per disposal, Assisted/Net/Retained/Kick/Handball metres, Clangers, Turnovers, Disposal Retention%, I50 Retention%, xThreat/kick, Threat Rating, xRetain/kick, Retention Rating
  - Equity: Pre-clearance, Post-clearance, Ball Winning, Ball Use (Wheelo's impl of AFL Player Ratings)
  - Possessions: Contested/Uncontested/Total, CP%, Intercept Possessions, Ground Ball Gets (F50/D50), Hard/Loose Ball Gets, Post-Clearance CP/GBG, Gathers from Hitout, Crumbing, Handball Receives, Possession location chart (D50/DefMid/AttMid/F50)
  - Clearances: CBA, CBA%, Centre Clearances, Centre Clearances per CBA, Stoppage Clearances, Total Clearances, First Possessions, First Poss to Clearance%
  - Marks: Marks, Contested Marks, Marks Inside F50, Intercept Marks, Marks on Lead
  - Scoring: Goals total/avg, Behinds, Shots at Goal, Goal Assists, Score Assists, Scoreboard Impact, Goal Accuracy, Score Involvements, Score Involvement%, Score Launches, Offensive One-on-One contests/win%
  - Expected: Total Shots, xScore/Shot, Rating/Shot, Set Shots vs General Play splits
  - Defence: Defensive One-on-One contests/loss%, Tackles, Tackles Inside F50, Pressure Acts, Defensive Half Pressure Acts, Spoils
  - Ruck: Ruck Contests, Ruck Contest%, Hitouts avg/total, Hitout Win%, Hitouts to Advantage/%, Ruck Hard Ball Gets, Hitout to First Poss/ Clearance%
  - Other: Frees For/Against/Diff, Kick-Ins, Kick-In%, Kick-In Play On%, Bounces, One Percenters
  - Match stats: `https://www.wheeloratings.com/afl_match_stats.html?ID=20260801`
- **Covers:** ✅ CBA, centre/stoppage clearances, metres gained, disposal efficiency (via Eff%), intercepts, tackles i50, TOG%, pressure acts, spoils, kick-ins, xScore, coaches votes, expected scores — **the full advanced wishlist**
- **How to use:** Manual CSV download in browser → `Download as CSV`. Automated: need Playwright or inspect XHR — table is JS-rendered from JSON endpoint. `akaifu/afl-squad-data/convert_wheelo_csv.py` shows pattern for team lists CSV.
- **Reddit:** r/AFL top recommendation for "best site for AFL stats" — "Wheelo is one I found the other week and its got a lot of champion data stuff" [1](https://www.reddit.com/r/AFL/comments/1kxzh2m/best_site_for_afl_stats/)

### 4. fitzRoy (R) + fitzroy_data (parquet cache) — the upstream truth
- **Repo:** `https://github.com/jimmyday12/fitzRoy` — MIT, 153 stars, 1,138 commits, CRAN package
- **Data repo:** `https://github.com/jimmyday12/fitzroy_data` — release tag `data` with `afltables_player_stats.parquet` (12,382,880 bytes, 81 columns) and `footywire_player_stats.parquet`
- **Licence:** MIT
- **Functions:**
  - `fetch_player_details(team, source="AFL"/"footywire"/"afltables")` → DOB, debut, height, weight, draft pick/year/type, position, age
  - `fetch_player_stats(season, round, source)` → per-match: K, HB, D, CP, UP, ED, DE%, CM, MI5, 1%, BO, TOG, AF, SC, CCL, SCL, SI, MG, TO, ITC, T5 etc
  - `fetch_fixture(season, source="AFL"/"afltables"/"squiggle")` → date, venue, round, attendance
  - `fetch_ladder`, `fetch_results`, `fetch_lineup`
- **Parquet schema (AFL Tables):** Season, Round, Date, Venue, Player, Team, Opponent, K, HB, D, M, G, B, HO, T, RB, IF, CL, CG, FF, FA, BR, CP, UP, CM, MI, 1%, BO, GA, Age, DOB, Career.Games, Brownlow.Votes, Time.on.Ground %, Umpires, Attendance etc (81 cols)
- **Status:** ✅ ACTIVE (last commit Aug 2026)
- **Covers:** ✅ DOB/age, height/weight, debut, draft, real pos, per-match stats, advanced (CP, UP, ED, DE%, CM, MI5, 1%, BO, TOG, AF, SC, CCL, SCL, SI, MG, TO, ITC, T5), fixture/venue/crowds/ladder, Brownlow per match
- **How to use in this repo (no R):** Use `gh api repos/jimmyday12/fitzroy_data/releases/tags/data --jq .assets` to list, or parse R helpers `R/helpers-afl.R`, `helpers-footywire-playerdetails.R` for scraping patterns. Parquet can be read with `duckdb` or `polars` if env allows.

### 5. fitzRoy-ts (TypeScript port)
- **Repo:** `https://github.com/jackemcpherson/fitzRoy-ts` — MIT, npm `fitzroy`
- **Value:** Shows typed client for AFL.com.au CFS API without R: `TOKEN_URL https://api.afl.com.au/cfs/afl/WMCTok`, `API_BASE https://aflapi.afl.com.au/afl/v2`, `CFS_BASE https://api.afl.com.au/cfs/afl`, UA `fitzroy/2`, Zod schemas `MatchItemListSchema`, `PlayerStatsListSchema`, `CfsPlayerInnerSchema` with playerId/givenName/surname/jumperNumber/position, Player interface with dateOfBirth/heightCm/weightKg/draftYear/Position/Type/debutYear
- **Status:** ✅ MIT, good reference for how to mint token
- **Covers:** Same as R version, but shows exact endpoint paths

---

## Tier 2 — Open but requires manual download or daily scraper

### 6. Kali AFL Stats API (currently OFFLINE, archive safe)
- **URL:** `https://kaliaflstats.com/` — docs at `/docs` now shows "back in 2027. the api and site are offline. all data is archived safely." [verified 2026-09-22]
- **GitHub:** `https://github.com/MFergie121/kali-afl-stats` — FREE, open source, 27 seasons 2000-now, 5,321 matches, 2,865 players, 236k stat records, 36 venues
- **Licence:** Open source, free 1,000 req/day when live, no credit card
- **Endpoints (when live):** `/teams`, `/players`, `/players/:id/career`, `/matches`, `/player-stats` (17 cats: kicks, handballs, disposals, marks, goals, behinds, tackles, hitouts, goal_assists, inside_50s, clearances, clangers, rebound_50s, frees_for/against, afl_fantasy_pts, supercoach_pts), `/player-stats-advanced` (17 cats: contested_possessions, uncontested, effective_disposals, disposal_efficiency_pct, contested_marks, marks_inside_50, one_percenters, bounces, centre_clearances, stoppage_clearances, score_involvements, metres_gained, turnovers, intercepts, tackles_inside_50, time_on_ground_pct), `/player-team-assignments`, `/leaderboards`, `/head-to-head`, `/venues`, `/standings`, `/fixture` (public), `/predictions`, `/tips`
- **Covers:** ✅ advanced metrics wishlist, ✅ Fantasy/SuperCoach points, ✅ fixture/venues/ladder, ✅ head-to-head, ✅ per-match
- **How to use now:** Clone repo, run `npm run db:up`, `npm run db:seed:dev` to pull production data locally. Or use archived data in repo.
- **Reddit/GitHub:** Frequently cited as "the AFL API that should've existed"

### 7. akaifu/afl-squad-data — daily live squad + ages + contracts
- **Repo:** `https://github.com/akaifu/afl-squad-data` — 0 stars, 135 commits, daily GitHub Action
- **Files:** `squads.json` (generatedAt, clubs[id]{name,short,color,sourceUrl,players[{num,name,pos,playerId,profileUrl}]}), `ages.json` (2.1MB, generatedAt, note, leagueAverageAge 85.27, clubs[club][{name,birthYear,birthMonth,birthDay,age,source?}]), `contracts.json` (603 bytes), `ages_cache.json`
- **Scrapers:** `scrape_squads.py` (club official sites: afc.com.au/teams/afl etc, regex `(\d{1,2})\s+Name\s+(Key Forward|Key Defender|Defender|Forward|Midfielder|Ruck)` → DEF/MID/RUC/FWD), `scrape_ages.py` (AFL Tables alltime pages), `scrape_contracts.py`, `scrape_draftguru.py`, `convert_wheelo_csv.py`
- **Licence:** MIT-ish (no explicit licence file, but public repo)
- **Status:** ✅ LIVE (last update 16h ago 2026-09-21)
- **Covers:** ✅ real listed position DEF/MID/RUC/FWD from official club sites, ✅ DOB/age from AFL Tables + DraftGuru gapfill for non-debuted draftees, ✅ contracts (if maintained)
- **How to use:** `https://raw.githubusercontent.com/akaifu/afl-squad-data/main/squads.json` raw URL. Already cloned to `/tmp/squad-data/` in this workspace.
- **Gap:** 55 unresolvedPlayers with no age (very recent signings): Archer May, Bailey J. Williams, Ben Murphy, Benny Barrett, etc.

### 8. akareen/AFL-Data-Analysis — 5,700+ players, 682k rows, MIT
- **Repo:** `https://github.com/akareen/AFL-Data-Analysis` — MIT, personal CSVs
- **Data:** `data/players/*_personal_details.csv` → first_name, last_name, born_date (YYYY-MM-DD), debut_date (DD-MM-YYYY), height (cm), weight (kg); `*_performance_details.csv` → Team, Year, Games Played, Opponent, Round, Result, Jersey Num, Kicks, Marks, Handballs, Disposals, Goals, Behinds, Hit Outs, Tackles, Rebound 50s, Inside 50s, Clearances, Clangers, Free Kicks For/Against, Brownlow Votes, Contested Possessions, Uncontested, Contested Marks, Marks Inside 50, One Percenters, Bounces, Goal Assist, % game played
- **Matches:** `data/matches/matches_1897.csv` ... 2025 with Year, Round, Venue, Date, Home/Away Team, Q-by-Q goals/behinds, Totals, Winning Team, Margin
- **Status:** ✅ MIT, local clone at `/tmp/afldata/`
- **Covers:** ✅ DOB/age, height/weight, debut, per-match stats, historic matches
- **How to use:** Match on `last,first` + `dob` → personal_details.csv. Already used to fill 145 missing heights in enriched CSV.

### 9. DFS Australia — Fantasy/SuperCoach positions/prices/scores + CBA, kick-ins, TOG
- **URL:** `https://dfsaustralia.com/afl-stats-download/` (current season CSV), `/downloads/` (2023-2026 AFL Fantasy XLSX and 2024-2026 SuperCoach XLSX)
- **Content:** Disposals, marks, tackles, goals plus CBA, kick-ins (KI), TOG%, Fantasy Points (FP), SuperCoach (SC), POS (Fantasy position), SAL (salary/price), CBA%, PO%, etc
- **Status:** ⚠️ Partially blocked — HTML fetch works, but XLSX download fails `ECONNRESET TLS` in this env, and WP JSON lists files. Requires manual browser download.
- **Covers:** ✅ Fantasy/SuperCoach positions/prices/scores, ✅ CBA, kick-ins, TOG%
- **How to use:** Manual download → `data/raw/dfs_2026.csv`. Then merge on player name.

### 10. JustPlausible/AFL-api — endpoint catalogue for AFL.com.au public/CFS/StatsPro
- **Repo:** `https://github.com/JustPlausible/AFL-api`
- **Docs:** `docs/public_afl_metadata.md`, `scraper_source_inventory.md`, `statspro.md`, `ENDPOINT_CATALOG.md`, `afl_json/client.py`, `statspro.py`, `player_stats.py`
- **Endpoints documented:**
  - Public: `https://aflapi.afl.com.au/afl/v2/competitions`, `/compseasons/{id}/rounds`, `/teams?compSeasonId`, `/matches`, `/players/idmap`
  - CFS: `https://api.afl.com.au/cfs/afl/WMCTok` (POST to mint token → x-media-mis-token), `/players?seasonId`, `/playerStats/match/{matchId}` (homeTeamPlayerStats/awayTeamPlayerStats), `/matchRosters/round/{roundId}`, `/rosters/match/{matchId}`
  - StatsPro: `/statspro/playersStats/seasons/{seasonId}` (players[].totals{kicks,ratingPoints,...}) and `/rounds/{roundId}` (playerStats[]), `statspro_season_total_2025.json`, `statspro_round_07_2026.json`
- **Semantics:** SEASON_TOTAL finals-inclusive, zero-game players retained, totals vs averages separate, idmap maps CFS id ↔ public id
- **Status:** ✅ Catalogue is live, endpoints require token
- **Covers:** ✅ per-match player stats, ✅ advanced (ratingPoints etc), ✅ fixture, rosters, ✅ real positions
- **How to use:** See `fitzRoy-ts/src/sources/afl-api.ts` for token flow.

### 11. DanielTomaro13/AFL-Modelling — anonymous token flow example
- **Repo:** `https://github.com/DanielTomaro13/AFL-Modelling` — MIT
- **Files:** `src/afl_api.py` (WMCTok mint `POST /cfs/afl/WMCTok` → `x-media-mis-token`, `_live_get` with UA, throttle 0.35s, cache `data/raw`), `src/ingest.py` (targets disposals/goals/kicks/handballs/marks/tackles/behinds/clearances/hitouts/dreamTeamPoints + 40 extra totals, fixture_map from matchRosters)
- **Status:** ✅ MIT, shows working anonymous auth without official key
- **Covers:** ✅ per-match stats, ✅ Fantasy points, ✅ fixture mapping
- **Note:** Same CFS flow as JustPlausible, but with concrete Python implementation.

---

## Tier 3 — Kaggle / other open datasets

### 12. Kaggle stoney71/aflstats — ODbL, 2012-2025 game-by-game
- **URL:** `https://www.kaggle.com/datasets/stoney71/aflstats`
- **Licence:** ODbL
- **Content:** PlayerId, GameId keys, from afltables+footywire, game-by-game player stats
- **Covers:** ✅ per-match, ✅ historical

### 13. DraftGuru — draft pick/year/type
- **URL:** `https://www.draftguru.com.au/`
- **Content:** Draft order, pick, year, type (national, rookie, pre-season, etc), plus DOB for gapfill
- **How used:** akaifu `scrape_draftguru.py` gap-fills ages.json for players with no AFL Tables record (marked source:'draftguru_gapfill')
- **Covers:** ✅ draft year/pick/type, ✅ DOB for non-debuted

### 14. Footywire — contracts, injuries, bio (behind Cloudflare)
- **URL:** `https://www.footywire.com/afl/footy/player_search`, `/injury_list`, `/afl/footy/out_of_contract_players`
- **Status:** ⚠️ Behind Cloudflare Turnstile "Checking your Browser… Verify you are human" — scraping blocked without browser; use cached fitzroy_data or Kali
- **Content (when accessible):** Height/weight/position/DOB/draft/contract/injury list, out-of-contract status
- **Covers:** ✅ height/weight, ✅ contract years/free agency, ✅ injury list, ✅ draft

---

## What to use for this auto-battler (recommended stack)

**No Champion Data, no paid key, all free, attribution-friendly:**

1. **AFL Tables** (`tools/scrape_afltables.py` already) — base season totals, per-match, Brownlow per match, venue/attendance
2. **akaifu/afl-squad-data** (`squads.json` + `ages.json`) — real listed position DEF/MID/RUC/FWD from official club sites + DOB/age with DraftGuru gapfill
3. **akareen/AFL-Data-Analysis** (`*_personal_details.csv`) — height_cm, weight_kg, debut_date to fill missing bio (covers 145 gaps in current enriched CSV)
4. **Wheelo Ratings** (manual CSV download) — 60+ advanced metrics: CBA/CBA%, centre/stoppage clearances, metres gained, disposal efficiency %, intercepts, tackles i50, TOG%, pressure acts, spoils, kick-ins, xScore, coaches votes, Player Rating, Equity, Threat/Retention Ratings
5. **Squiggle API** — real 2026 fixture/results/venues/ladder/tips/predictions (live, free, no key, just UA)
6. **fitzRoy MIT** — reference implementation for how to parse AFL Tables + FootyWire + Squiggle consistently, and for schema of 81-column parquet (Age, DOB, Career.Games, Brownlow.Votes, Time.on.Ground)
7. **DFS Australia** (manual XLSX) — Fantasy/SuperCoach real POS and SAL and CBA/KI/TOG%/FP for personal analysis

**Legal safest for redistribution:** AFL Tables (facts) + Squiggle (public) + fitzRoy/fitzroy_data (MIT, with permission from AFL Tables/Footywire) + akaifu/akareen (MIT/public). Avoid direct CFS scraping (`api.afl.com.au/cfs/afl/WMCTok`) for shipped data — use it only for personal cache, as AFL.com.au ToS prohibits robots/spiders per `afl.enterprises/terms-of-use`. Wheelo allows personal non-commercial with attribution.

---

## Immediate next steps for this repo

- [x] Base `players_2026.csv` 669 players from AFL Tables
- [x] Enriched `players_enriched_2026.csv` with real_pos, dob, age, height_cm, weight_kg, debut (from squad-data + afldata)
- [x] Fill 100% height via `data/afltables_bio_cache.json` — 145 entries fetched from `afltables.com/afl/stats/players/X/Name.html` using fetch_page (only viable fetcher in sandbox, no proxy, curl TLS EOF). Pattern: `/<FirstInitial>/<First>_<Last>.html` underscore, hyphen kept, first letter of first name (Callum Ah Chee -> /C/). Final 4 WBD: Michael Sellwood 186, Will Lewis 194, Luke Kennedy 181, Louis Emmett 200. Result 669/669 heights (was 524 base). Weight 0kg common for 2026 debutants indicates incomplete bio but height present. Tool `tools/enrich_from_open_sources.py` now loads cache as primary.
- [x] Import Squiggle fixture → `data/raw/fixtures_2026.json` (218 games, 2026-03-05 to Grand Final 2026-09-26), `data/raw/standings_2026.json` (ladder, Fremantle 1st 76pts 19-4, Sydney 2nd), `data/raw/teams_squiggle.json` saved via fetch_page 13 chunks (TLS EOF for urllib, fetch_page only viable)
- [x] Update `scripts/core/GameDB.gd` to prefer `players_enriched_2026.csv` if present, fallback to `players_2026.csv`, and expose optional bio fields with defaults so Ratings.gd stays backward-compatible
- [ ] Add optional columns to `players_enriched_2026.csv`: `draft_year,draft_pick,draft_type,foot,contract_until,rookie_status` from DraftGuru/Footywire
- [x] Ship the 2026 national-draft class for the end-of-season intake draft → `data/draftees_2026.csv` (56 prospects). Compiled 2026-09-22 via `fetch_page` from **Rookie Me Central** "AFL Draft Power Rankings: August 2026 Top 50" (rank, club, position, height, DOB, U18 averages, NGA/FS tags) and **Reading the Play** "Rolling 2026 Draft Power Rankings" April edition (six unranked names with heights/positions). Ratings are projections from those ranks (see `docs/DESIGN.md`); no AFL stats exist for these players yet. Regenerate/extend the file by editing the CSV directly - the columns mirror what the two sources publish. The game's label policy applies: these are public draft facts (name, height, age, listed position), used the same way as the AFL Tables season data. Fictional mode shows a generated name; real-name mode shows this name on its own.
- [x] Generated intake classes for years beyond the shipped data → `Prospects.generate_class(year)` (deterministic per year, fictional names, same projection pipeline)
- [ ] Import Wheelo advanced CSV → new file `data/players_advanced_2026.csv` with `cba,cba_pct,centre_clearances,stoppage_clearances,metres_gained,disposal_eff_pct,intercepts,tackles_i50,tog_pct,pressure_acts,spoils,kick_ins,xscore,coaches_votes,player_rating` (requires manual browser download, JS-rendered)
- [ ] Document attribution in `README.md` and `docs/DESIGN.md`

## Completion report — heights

- Base `players_2026.csv`: 524/669 heights (78.3%)
- After akareen personal_details: ~609/669 (91%)
- After afltables_bio_cache.json batches:
  - 77->85: Lachlan Blakiston 203/100, Lachlan Carmichael 184, Lachlan Gulbin 187/81, Lachlan Smith 203, Lachy Dovaston 178, Latrelle Pickett 182, Leo Lombard 179/74, Liam Puncher 195 (missing 68->60)
  - 85->93: Roan Steele 183/78, Sam Swadling 189, Oscar Steene 201, Sullivan Robey 192, Max Kondogiannis 191, Zak Johnson 185/76, Sam De Koning 200/85, Mitchell Edwards 206 (missing 52)
  - 93->101: Oliver Wiltshire 180/67, Mitch Podhajski 191, Noah Howes 196, Vigo Visentini 203/99, Rhys Unwin 179/74, Tobyn Murray 180, Zeke Uwland 179, Oscar Adams 197/83 (missing 44, 625/669)
  - 101->109: Phoenix Gothard 179, Nick Madden 204/112, Riley Hamilton 189, Oliver Hannaford 180, Noah Mraz 198, Ollie Greeves 192, Will McCabe 197, Max Beattie 174 (pending)
  - 109->117: Matt Hill 187, Paddy Cross 181, Max Heath 204/97, Xavier Taylor 192, Lukas Cooke 196, Luker Kentfield 194, Tom Blamires 181, Zac Banch 175/74 (missing 36, 633/669)
  - 117->125: Matt Whitlock 198/94, Taylor Goad 207, Xavier Bamert 185, Tom Anastasopoulos 176, Mitch Zadow 180, Patrick Retschko 186, Sam Grlj 182, Sam Cumming 184 (pending ~641/669)
  - 125->133: Taj Hotton 182/79 2006-06-17, Oliver Hayes-Brown 208 2000-04-28, Tom Burton 178 2007-01-09, Noah Roberts-Thomson 181 2007-03-29, Zane Peucker 180 2007-12-04, Tom De Koning 203/97 1999-07-16, Will Edwards 197 2003-05-08, Will Green 204 2005-09-08 (missing 12, 657/669)
  - 133->141: Tom McCarthy 188/89 2000-07-12, Willem Duursma 193 2007-06-21, Milan Murdock 180 2000-06-30, Marcus Herbert 181 2002-08-13, Oliver Francou 184 2006-02-27, Malakai Champion 172/69 2006-05-17, Sandy Brock 198/90 2002-12-14, Tom Gross 181/70 2006-09-15 (missing 4)
  - 141->145: Michael Sellwood 186 2003-10-02, Will Lewis 194 1999-05-05, Luke Kennedy 181 2006-10-11, Louis Emmett 200 2007-03-23 (missing 0, 669/669 100%)
- Final: `data/players_enriched_2026.csv` 669 rows, `height_source=afltables_player_page` for cache entries, `data/afltables_bio_cache.json` 145 entries
- Validation: `python3 -c \"import csv; rows=list(csv.DictReader(open('data/players_enriched_2026.csv'))); print(sum(1 for r in rows if r['height_cm']))\"` → 669

---

## Appendix — Search queries used

- `AFL data API open source GitHub`
- `AFL scraper player stats Footywire`
- `Reddit best AFL API Squiggle fitzRoy`
- `unofficial aflapi.afl.com.au v2`
- `open datasets advanced metrics`
- `AFL Fantasy JSON positions prices 2026`
- `Wheelo Ratings CSV`
- `Footywire contracts/injuries`
- `DraftGuru`
- `Kali AFL Stats API`
- `fitzRoy R package player details`

## Appendix — Why Kali is offline

`https://kaliaflstats.com/docs` now returns:
> back in 2027. the api and site are offline. all data is archived safely.
> [github](https://github.com/MFergie121/kali-afl-stats)

The GitHub repo remains open source with DB seed scripts (`npm run db:up`, `npm run db:seed:dev`). If it returns in 2027, it would again be the best single replacement (1000 req/day free, advanced + Fantasy + head-to-head).
