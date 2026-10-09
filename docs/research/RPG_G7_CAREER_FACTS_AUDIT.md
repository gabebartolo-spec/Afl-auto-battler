# G7 audit: where career facts live today

ROADMAP §9.4 prerequisite G7 asks for "one durable career-fact record". Facts are
player identity, date, event, the coach's decision and its consequence. Before any
new memory is added, the existing stores are reconciled. This is a read-only
inventory of `main` at `26f71953` (2026-10-09). No code changed.

Paths are relative to the repo root; `GS` means `scripts/state/GameState.gd`.

## How players and results are saved (the ground rules)

- **Player dicts are saved whole.** Every field except `rates` and `norm` is saved
  (`scripts/state/CareerSave.gd:29`, `:219-238`), so anything kept on `p[...]`
  survives save/load.
- **Results are slimmed** to `RESULT_KEYS` (`CareerSave.gd:30-32`, `:156-174`):
  - `season_log` loses rosters, box scores and events (`GS:466`).
  - Season and finals results keep a packed box (`GS:881-884`).
  - A fact that needs a roster or a box line must be taken from the full
    result, in the round it is played.
- **A trade or a signing moves the same dict** (`GS:_join`, `:4463-4472`). It sets
  `joined` and erases only `project`, `train_plan`, `released_by` and
  `comp_eligible`. Every other per-player fact moves with him.
- **A name change is cosmetic.** `nickname` (`GS:2759`) and the real/generic name
  toggle change only the display. Every store below is keyed by player `id`, so
  none is affected. Club-code renames are rewritten across the save by
  `CareerSave.migrate_club_codes` (`CareerSave.gd:294`).
- **Leaving the lists ends everything on `p`.** At retirement or an unclaimed
  delisting, `GS:_career_over` (`:7325`) is "the last moment the player is in
  hand". Only a player who goes into coaching keeps a snapshot
  (`scripts/sim/CoachPathway.gd:55` `snapshot`). Everyone else's per-player facts
  are gone, and later lines fall back to "a departed player" (`GS:5800`).

## Inventory

Columns:
- **S/L:** survives save/load.
- **Trade:** survives a trade.
- **Retire→coach:** carried into a former player's coaching record.
- **Slim:** safe from result slimming.

| Store | Key / owner | What it holds | S/L | Trade | Retire→coach | Slim |
|---|---|---|---|---|---|---|
| Firsts | `p["firsts"]`, `scripts/sim/Firsts.gd:30` | `{debut\|goal: {year, label}}`, written once after your match (`GS:6495-6498`) | yes | yes, but no club field | **no** | yes, taken from the full result |
| Career | `p["career"]`, `scripts/sim/Career.gd:35-98` | totals; `stints [club, from, to, games, goals]`; `lines` (season stat rows); `unknown` ranges; `through` guard | yes | yes (new stint) | yes (games, goals, stints, unknown) | yes, closed from the tally (`GS:3276`) |
| Backing ledger | `p["backed"]`, `scripts/sim/Backing.gd:65-91` | `{year, round, games, played, state, debut, ended{year,label}}`: **the coach's decision and its outcome** | yes | yes; a run left active at a trade only lapses at season end (`GS:1267`) | **no** | yes |
| Injury log | `p["injury_log"]`, `GS:3416-3423` | bare years, `[2027, 2028]`; no label, injury or club | yes | yes | **no** | yes |
| Retire talk | `p["retire_talk"]`, `scripts/sim/Retirement.gd:87` | `{year, stays, reason}`: **a decision and its consequence**; plus `play_on`, `talked_round` | yes | yes | **no** | yes |
| Projects | `p["project"]` (live), `p["project_year"]`, `role2`, `learned`, `learn_payback_year`; `GS:3058-3108` | only the live project. Its **verdict is not stored**: it goes to news, then `project` is erased (`GS:3097`). `role2`/`learned` keep the outcome without the decision or date. | live only | erased by `_join` | **no** | yes |
| Honour roll | `honour_roll`, `GS:62`, appended `GS:3282-3299` | one entry a season: premier, runner-up, top Brownlow/Coleman/Rising Star/Coaches (rows by **id**), your B&F, record, finals, AAs | yes | n/a (league) | read for coach honours (`CoachPathway.gd:84`) | yes |
| Season awards | `season_awards`, `GS:57`, `scripts/sim/Awards.gd:127-135` | the finished season's full tables; **overwritten** each year | yes | n/a | no | yes |
| League records | `records`, `GS:83`, `Awards.update_records` (`Awards.gd:242-246`) | best-ever values with player **id** | yes | n/a | no | yes |
| Achievements | `achievements`, `GS:87`, `:3356` | club achievements `{id: {year}}` | yes | n/a | n/a | yes |
| Board history | `board["history"]`, `GS:6887` | `{year, goal, met, position, confidence, verdict}` (the club, not a player) | yes | n/a | n/a | yes |
| Rivalry history | `rivalry_history`, `scripts/core/Rivalries.gd:57` | club-pair evidence from results | yes | n/a | n/a | recorded before slim (`GS:1933`) |
| Media / event memory | `media_memory` `GS:6839`, `event_memory` `GS:6914-6916` | de-dupe keys (`question → round`, `extension\|id`, `unhappy\|id`); **anti-repeat, not facts** | yes | yes (id keys) | no | yes |
| News feed | `news`, `GS:121` | prose lines, newest first | yes | n/a | n/a | yes |
| Coach records | `coaches` / `coach_archive`, `GS:65-67` | a former player's `played` snapshot: games, goals, stints, draft, positions, honours | yes | n/a | **the only carrier** | yes |
| Draft facts | `p["drafted_year"/"drafted_pick"/"drafted_type"]`, `draft.pick_history` (`GS:577`) | the pick and year | yes | yes | yes (snapshot `draft`) | yes |

Derived, with no store of their own (they read the rows above):
- **Milestones:** `GS:2314` `milestone_notes`, from Career games.
- **FL-002 banner milestones and farewells:** `GS:2453`, from Career, stints and `retiring`.
- **FL-008 pennants:** `GS:2372`, from `honour_roll`.
- **"With us":** `GS:2505-2545`, which combines Career stints, Firsts, Backing and `honour_roll`.
- **Retirement persuasion:** `Retirement.recent_injuries`, `scripts/sim/Retirement.gd:61`, from `injury_log`.

"Season-story ledger": no store exists on `main`. The live feed's story line
(`MatchNotes.story_feed_line`, see `GS:2555`) is computed from the match, not kept.

## Findings

1. **Four stores carry dated player events, and each has its own shape.**
   - Firsts: `{year, label}` under a key.
   - Backing: a list with `{year, round}` and `ended{year, label}`.
   - injury_log: bare years.
   - retire_talk: a single `{year, ...}`.
   - None records the club, even though Firsts means "for your club".
2. **Only two record the coach's decision and its consequence:** Backing (a promise, then
   done, broken or lapsed) and retire_talk (asked, then stays or goes, with the reason).
   Project verdicts, the third decision the game already makes, are thrown away
   after the news line.
3. **Retirement is the gap that matters.**
   - A former player who goes into coaching keeps Career and honours only.
   - Everyone else keeps nothing but ids inside `honour_roll` and `records`, which
     may not resolve to a name once he is off every list (`GameDB.gd:329-338`).
   - G7's "former-player coaching continuity" check fails today for firsts,
     backing, injuries, retirement talks and projects.
4. **Slimming is handled.** Every fact is written from the full result in its own
   round (`GS:6478-6498`, `:6753`, `:3411`, `:1933`) or from the season tally. No
   current fact depends on data the save discards. New writers must follow the
   same rule.
5. **The overlaps are composition, not duplication.**
   - "With us" and the banners re-derive from Career plus `honour_roll`. That is
     fine, because both are the durable source.
   - The one true duplicate is `role2`/`learned` against a project verdict that is
     never written.
6. **Club-level history (honour roll, records, achievements, board, rivalries) is
   already durable and well keyed.** It does not need to move.

## Smallest reconciliation proposal

**One shape**, for player events only:

```
{y: year, at: label or "" (e.g. "Round 7", "Off-season"), k: kind, club: code at the time,
 d: the coach's decision or "" (e.g. "backed 3", "asked to play on", "project ruck"),
 out: the consequence or "" (e.g. "done", "broken", "stays", "learned")}
```

- **Kinds:** `debut`, `first_goal`, `backed`, `injury`, `retire_talk`, `project`.
- **Where it lives:** a career-level dictionary, `career_facts: {player id: [fact, ...]}`
  on GameState, saved with the other career state (`GS:477-505`, `:622-650`). Facts
  then outlive the player dict, a trade and retirement, and are read by id.

**Order of moves:**
1. **Add `scripts/sim/CareerFacts.gd`**, pure, with `add(store, id, fact)` and
   `of(store, id, kind := "")`. Write each new fact there in the same place it is
   written today. Keep the old per-player keys as they are for one release, so no
   reader breaks.
2. **Move `injury_log` first.** It is the lossiest store (bare years) and has one
   reader (`Retirement.recent_injuries`). Point the reader at `CareerFacts`. Old
   saves migrate as `{y, k: "injury"}` facts with no label, which is honest.
3. **Start recording project verdicts** (`GS:3083`) as `project` facts. This is a
   new write, not a move. It is the decision the game currently throws away.
4. **Move `retire_talk` and Backing**, then Firsts. Their helpers keep their
   signatures and read from `CareerFacts`. Backing's live run (`state: "active"`)
   can stay on `p` until it ends, then be written as one fact.

**What stays where it is:**
- Career: aggregate statistics, not events.
- `honour_roll`, `records`, `achievements`, `board.history`, `rivalry_history`: club
  and league level, already durable and keyed by id.
- `media_memory` and `event_memory`: anti-repeat state, not facts.
- Coach records: they keep their snapshot, which can later point at
  `career_facts` by player id instead of copying it.

**Also fix:** at `GS:_career_over`, keep a name for every departed id
(`{id: display name}` alongside `career_facts`). Then honour-roll and record lines
can still name a retired player who never coached.

**Checks for the implementing PR (from G7):**
- Each fact kind survives save and reload, and a trade.
- A nickname change does not touch any fact.
- A retired-then-coaching former player still shows his firsts and backing.
- A plain retiree is still named on the honour roll.
- An old save migrates with nothing invented.
- The lifecycle review (W7) applies: this changes the save schema.
