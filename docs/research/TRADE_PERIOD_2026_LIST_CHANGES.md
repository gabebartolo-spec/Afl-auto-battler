# 2026 trade period, free agency and list changes (1.1 patch)

Checked 2026-10-19, after the trade deadline (14 October 2026) and while delisted free agency is still to open. This updates the end-of-2026 real lists in [LISTS_2026_MANIFEST.md](LISTS_2026_MANIFEST.md), which were built on 9 October, before any trade was done.

## Counts

| | Count |
|---|---:|
| Trades | 23 (19 with players, 4 picks only) |
| Players traded | 23 |
| Free agents who changed club | 7 (5 unrestricted, 2 restricted) |
| **Players who changed club** | **30** |
| New to a list (not in the data before) | 2 (Dominic Bedendo, Ollie Purcell) |
| Retirements announced since 9 October | 1 (Will Brodie) |
| Delistings the data did not hold | 16 (15 announced 16 and 17 October, Jake Stringer on 24 August) |
| Delisted players now on a list | 1 (Bodie Ryan, traded to Melbourne) |
| Reported moves not yet done (left as they are) | 3 (see Unverified) |

Registered players: 806 in the 2026 manifest, 808 now (the two new signings).

## What the game does with this

- `data/club_moves_2026.csv` (new): 30 rows, one per player who changed club, with the club he played 2026 for (`from_club`), the club he joins (`to_club`), `traded` or `free_agent`, the date, sources. `players_2026.csv` and the enriched file are not touched: they are the 2026 season record, checked club by club against AFL Tables (`tools/validate_data.py`), and a traded player's 2026 games were played for his old club. A real-lists career moves each player when it opens (`GameState.begin_real_lists`), so he starts on his new club's list; his 2026 record still runs through 2026 at the old club (`data_club`). The new check `check_club_moves` in `validate_data.py` pins every row to the 2026 list.
- `data/departures_2026.csv`: 17 rows added, Bodie Ryan's removed (delisted, then traded).
- `data/list_additions_2026.csv` and `list_additions_stats.csv`: Dominic Bedendo (Fremantle) and Ollie Purcell (Hawthorn) added; Bedendo is rated on his 2022 season.
- Jersey numbers: a mover keeps his number when it is free on the new list; if not, the game gives the later of the two a free number from 41 (`GameState.unique_jumpers`, as it does for every real-lists start). No 2027 numbers are announced yet and none are invented here.

Not expressible in the data model, so not applied:

- **Draft picks.** 23 trades moved picks and the game's 2026 draft order is the reversed ladder with no pick ownership, so a pick traded for Blakey or Merrett changes nothing in the game. The picks are listed below for the day pick ownership exists.
- **Free-agent compensation picks.** Same reason.
- **Delisted free agency** opens in November (Wil Parker, Harry Cunningham and others); nothing there is final yet.

## Trades

Receiving club first. Picks are 2026 draft picks unless a year is given. Date is the date of the AFL House approval or the AFL.com.au report. The trade-by-trade AFL.com.au URLs are the ones cited by Wikipedia's [2026 AFL draft](https://en.wikipedia.org/wiki/2026_AFL_draft) page (revision of 17 October); I opened [the Bodie Ryan](https://www.afl.com.au/news/1632195/melbourne-demons-swoop-on-hawthorn-hawks-defender-bodie-ryan-in-dying-minute-of-trade-period) and [the Blakey](https://www.afl.com.au/news/1629721/north-melbourne-kangaroos-land-sydney-swans-star-nick-blakey-in-blockbuster-move) pieces and they agree. Every trade also appears on [Draftguru 2026](https://www.draftguru.com.au/years/2026) and [Zero Hanger's tracker](https://www.zerohanger.com/every-completed-move-in-the-2026-afl-free-agency-and-trade-period-183376/).

| # | Date | Player and clubs | Picks and other assets | Source |
|---|---|---|---|---|
| 1 | 2026-10-05 | Jesse Hogan, GWS to Collingwood | GWS gets pick 75 | [AFL.com.au](https://www.afl.com.au/news/1627079/collingwood-magpies-complete-deal-with-greater-western-sydney-giants-for-former-coleman-medal-winner-jesse-hogan) |
| 2 | 2026-10-05 | Scott Pendlebury, Collingwood to Gold Coast | Collingwood gets pick 65 | [AFL.com.au](https://www.afl.com.au/news/1626426/trade-agreed-for-games-record-holder-scott-pendlebury-gold-coast-suns-compo-pick-still-intact) |
| 3 | 2026-10-05 | Zach Merrett, Essendon to Hawthorn | Essendon gets picks 15 and 25 and Hawthorn's 2028 round 2 | [AFL.com.au](https://www.afl.com.au/news/1628685/zach-merrett-gets-long-held-wish-after-hawthorn-hawks-up-offer-to-essendon-bombers) |
| 4 | 2026-10-06 | Nathan O'Driscoll, Fremantle to Richmond | Fremantle gets pick 61 | [AFL.com.au](https://www.afl.com.au/news/1628864/fremantle-dockers-winger-nathan-odriscoll-traded-to-richmond-tigers) |
| 5 | 2026-10-07 | Jordan Ridley, Essendon to Geelong; Jack Bowes, Geelong to Essendon | Geelong also gets pick 60 and Essendon's 2028 round 4; Essendon also gets Geelong's 2027 round 1 and 2028 round 2 | [AFL.com.au](https://www.afl.com.au/news/1628710/geelong-cats-secure-defender-jordan-ridley-essendon-bombers-land-utility-jack-bowes-in-trade) |
| 6 | 2026-10-08 | Rowan Marshall, St Kilda to Geelong | Geelong also gets St Kilda's 2028 round 3; St Kilda gets pick 14 | [AFL.com.au](https://www.afl.com.au/news/1628930/rowan-marshall-gets-trade-wish-as-st-kilda-saints-land-top-draft-pick-from-geelong-cats) |
| 7 | 2026-10-09 | Five clubs: Finn Maginness, Hawthorn to Western Bulldogs; Hudson O'Keeffe, Carlton to Western Bulldogs | Bulldogs also get picks 81 and 87, Port Adelaide's 2027 round 2 and 4 and 2028 round 2 and 3, Gold Coast's 2027 round 3 (from Melbourne), Melbourne's 2028 round 4. Port Adelaide gets picks 6 and 10, Melbourne's 2027 round 1 and the Bulldogs' first-round pick (Wikipedia says 2027, Draftguru and Zero Hanger say 2028). Melbourne gets picks 4, 12, 31 and 46. Hawthorn gets Port Adelaide's 2027 round 3. Carlton gets Port Adelaide's 2028 round 4 | [AFL.com.au](https://www.afl.com.au/news/1629042/five-club-mega-deal-lands-as-dogs-land-duo-power-load-up) |
| 8 | 2026-10-09 | Sam Marshall, Brisbane to St Kilda | St Kilda also gets pick 39; Brisbane gets St Kilda's 2027 round 1 | [AFL.com.au](https://www.afl.com.au/news/1628961/disgruntled-flag-brisbane-lion-sam-marshall-secures-move-to-st-kilda-saints-in-victoria) |
| 9 | 2026-10-09 | Picks only: Hawthorn and Western Bulldogs | Bulldogs get Hawthorn's 2028 round 3; Hawthorn gets Gold Coast's 2027 round 3 | [AFL House post, as cited by Wikipedia](https://en.wikipedia.org/wiki/2026_AFL_draft) |
| 10 | 2026-10-12 | Sam Butler and Aidan Schubert, Hawthorn to Gold Coast | Gold Coast also gets its own 2027 round 3 back and Hawthorn's 2028 round 1; Hawthorn gets Gold Coast's 2027 round 2 and 2028 round 1 and 2 | [AFL.com.au](https://www.afl.com.au/news/1629329/gold-coast-suns-seal-deal-for-hawthorn-hawks-duo-aidan-schubert-sam-butler-in-attacking-boost) |
| 11 | 2026-10-13 (agreed 12 October) | Nick Blakey, Sydney to North Melbourne | North Melbourne also gets pick 52 and Sydney's 2028 round 2; Sydney gets picks 6 and 47, North's 2027 round 2 and 2028 round 1 and 2 | [AFL.com.au](https://www.afl.com.au/news/1629721/north-melbourne-kangaroos-land-sydney-swans-star-nick-blakey-in-blockbuster-move) |
| 12 | 2026-10-13 | Flynn Riley, Carlton to Collingwood | Carlton gets Collingwood's 2028 round 3 | [AFL.com.au](https://www.afl.com.au/news/1631431/big-carlton-blue-flynn-riley-gets-his-move-to-arch-rivals-collingwood-magpies) |
| 13 | 2026-10-13 | Zane Duursma, North Melbourne to Melbourne | Melbourne also gets pick 52; North gets picks 33 and 49 | [AFL.com.au](https://www.afl.com.au/news/1628959/zane-duursma-gets-trade-wish-three-picks-change-hands-between-melbourne-demons-and-north-melbourne-kangaroos) |
| 14 | 2026-10-13 | Lachie Whitfield, GWS to Carlton | Carlton also gets picks 31 and 50; GWS gets picks 25 and 26 and Carlton's 2028 round 3 | [AFL.com.au](https://www.afl.com.au/news/1628958/greater-western-giant-lachie-whitfield-secures-move-to-carlton-blues-five-picks-change-hands-in-trade) |
| 15 | 2026-10-14 | Picks only: Richmond and Port Adelaide | Richmond gets pick 5; Port Adelaide gets pick 22 and Richmond's 2027 round 1, 2 and 4 | [AFL House post, as cited by Wikipedia](https://en.wikipedia.org/wiki/2026_AFL_draft) |
| 16 | 2026-10-14 | Picks only: GWS and Brisbane | GWS gets picks 20 and 59 (Wikipedia prints 58; the AFL House text and Draftguru say 59); Brisbane gets picks 25 and 28 | [AFL House post, as cited by Wikipedia](https://en.wikipedia.org/wiki/2026_AFL_draft) |
| 17 | 2026-10-14 | Picks only: Western Bulldogs and Brisbane | Brisbane gets the Bulldogs' 2027 round 2; the Bulldogs get picks 42 and 53 (Wikipedia's table prints the directions the wrong way round; the AFL House text, Draftguru and Zero Hanger agree with this) | [AFL House post, as cited by Wikipedia](https://en.wikipedia.org/wiki/2026_AFL_draft) |
| 18 | 2026-10-14 | Trent Rivers and Jack Viney, Melbourne to West Coast | West Coast also gets Melbourne's 2028 round 2; Melbourne gets pick 45 and West Coast's 2027 round 2 and 4 and 2028 round 2 | [AFL.com.au](https://www.afl.com.au/news/1631429/west-coast-eagles-agree-deal-for-melbourne-demons-duo-trent-rivers-jack-viney-in-big-boost) |
| 19 | 2026-10-14 | Will McLachlan, Brisbane to Melbourne | Melbourne also gets Brisbane's 2027 round 2; Brisbane gets pick 45 and Melbourne's 2027 round 2 | [AFL.com.au](https://www.afl.com.au/news/1629752/melbourne-demons-boost-firepower-with-deal-done-for-brisbane-lions-forward-will-mclachlan) |
| 20 | 2026-10-14 | Josh Goater, North Melbourne to Hawthorn | North gets Port Adelaide's 2027 round 3 | [AFL.com.au](https://www.afl.com.au/news/1629743/hawthorn-hawks-busy-off-season-continues-as-north-melbourne-kangaroos-defender-josh-goater-joins) |
| 21 | 2026-10-14 | Keidean Coleman, Brisbane to Essendon | Essendon also gets pick 25; Brisbane gets picks 21 and 27 | [AFL.com.au](https://www.afl.com.au/news/1631430/bombers-boost-essendon-completes-deal-for-classy-brisbane-lion-keidean-coleman) |
| 22 | 2026-10-14 | Luke Pedlar, Adelaide to Port Adelaide | Port Adelaide also gets pick 34 (to Adelaide: pick 32 and Richmond's 2027 round 4) | [AFL.com.au](https://www.afl.com.au/news/1628711/adelaide-crows-forward-luke-pedlar-traded-to-arch-rival-port-adelaide-power) |
| 23 | 2026-10-14 | Bodie Ryan, Hawthorn to Melbourne (delisted by Hawthorn on 24 September, traded after) | Hawthorn gets pick 107 | [AFL.com.au](https://www.afl.com.au/news/1632195/melbourne-demons-swoop-on-hawthorn-hawks-defender-bodie-ryan-in-dying-minute-of-trade-period) |

Other sources for the whole table: [AFLRATINGS completed trades](https://aflratings.com.au/2026-afl-completed-trades/) (who went where, by day), [SEN trade verdict, 15 October](https://www.sen.com.au/news/2026/10/15/afl-trade-period-verdict-every-club-s-moves-rated-and-what-they-must-deliver-in-2027), [AFL.com.au club-by-club wrap](https://www.afl.com.au/news/1631700/your-clubs-trade-period-every-player-every-draft-pick-full-analysis). Where a source disagreed it is noted in the row. Pick numbers in the Zero Hanger tracker repeat (pick 25 in four deals, pick 45 and pick 52 twice) because it reports picks as they were traded on; the table above follows Wikipedia's per-trade split and Draftguru.

## Free agency

| Date | Player | Type | From | To | Compensation | Source |
|---|---|---|---|---|---|---|
| 2026-10-02 | Joel Amartey | Unrestricted | Sydney | Carlton | Second round | [AFL.com.au](https://www.afl.com.au/news/1625737/new-blue-tall-forward-joel-amartey-joins-carlton-from-sydney-swans) |
| 2026-10-02 | Toby Greene | Unrestricted | GWS | Geelong | Second round | [AFL.com.au](https://www.afl.com.au/news/1625751/greater-western-sydney-giants-star-toby-greene-completes-move-to-geelong-cats-as-free-agent) |
| 2026-10-02 | Kieren Briggs | Unrestricted | GWS | Richmond | Third round | [AFL.com.au](https://www.afl.com.au/news/1625735/richmond-tigers-land-greater-western-sydney-giant-kieren-briggs-to-bolster-ruck-stocks) |
| 2026-10-02 | Lachie Neale | Unrestricted | Brisbane | Collingwood | Second round | [AFL.com.au](https://www.afl.com.au/news/1625750/brisbane-lions-champion-lachie-neale-joins-third-club-with-collingwood-magpies-move) |
| 2026-10-03 | Jordon Butts | Unrestricted | Adelaide | Western Bulldogs | Second round | [AFL.com.au](https://www.afl.com.au/news/1625817/western-bulldogs-boost-defensive-stocks-by-adding-adelaide-crows-free-agent-jordon-butts) |
| 2026-10-09 (bid lodged 6 October) | Ben King | Restricted | Gold Coast | Hawthorn | First round | [AFL.com.au](https://www.afl.com.au/news/1626399/all-eyes-on-gold-coast-suns-after-hawthorn-hawks-lodge-ben-king-paperwork) |
| 2026-10-09 | Zak Butters | Restricted | Port Adelaide | Western Bulldogs | First round | [Bulldogs](https://www.westernbulldogs.com.au/news/2148605/butters-officially-a-bulldog) |
| 2026-10-07 | Dominic Bedendo | Delisted (VFL, Port Melbourne; delisted by the Bulldogs after 2024) | not on an AFL list | Fremantle | none | [Fremantle](https://www.fremantlefc.com.au/news/2148184/fremantle-sign-delisted-free-agent-dominic-bedendo), [AFL.com.au](https://www.afl.com.au/news/1628913/fremantle-dockers-sign-ex-western-bulldogs-forward-dom-bedendo-after-strong-vfl-form) |

The seven club-changing rows are in the game's `club_moves_2026.csv` and are also on [Draftguru 2026](https://www.draftguru.com.au/years/2026), [Wikipedia](https://en.wikipedia.org/wiki/2026_AFL_draft) and [AFLRATINGS](https://aflratings.com.au/2026-afl-completed-trades/). Compensation pick numbers are not given because the sources disagree on them and they move with the order. Bedendo is a new list addition (two senior games, both in 2022; born 9 July 2002 per [Draftguru](https://www.draftguru.com.au/players/dominic_bedendo/1), [AFL Tables](https://afltables.com/afl/stats/players/D/Dominic_Bedendo.html) and [Wikipedia](https://en.wikipedia.org/wiki/Dominic_Bedendo); height 191 cm per AFL Tables and Wikipedia, Draftguru has 188 cm; no position is set, as for the other additions).

## New to a list

| Player | Club | List | Source and note |
|---|---|---|---|
| Dominic Bedendo | Fremantle | Senior, two-year deal | See above. Date 7 October |
| Ollie Purcell | Hawthorn | Category B rookie (water polo goalkeeper, 195 cm, 21 years old, announced 4 and 5 October) | [Draftguru](https://www.draftguru.com.au/players/ollie_purcell/1), [Zero Hanger](https://www.zerohanger.com/hawthorn-confirms-cat-b-rookie-signing-183466/), [AFL.com.au](https://www.afl.com.au/news/1628172/hawks-shark-water-polo-international-oliver-purcell-as-category-b-rookie). SEN says 190 cm. No source gives his date of birth, so it is left blank rather than guessed (the game takes him as 21) |

## Retirements since 9 October

| Date | Player | Club | Source |
|---|---|---|---|
| 2026-10-16 | Will Brodie | Port Adelaide | [Draftguru retirements and delistings](https://www.draftguru.com.au/years/2026/retirements-delistings), [AFL.com.au](https://www.afl.com.au/news/1632353/former-top-10-pick-will-brodie-calls-time-port-adelaide-power-forward-pair-ollie-lord-and-tom-anastasopoulos-delisted) |

No other retirement has been announced since 9 October. Dion Prestia ("keen to play on" after his August announcement) is still listed as retired by Draftguru and Wikipedia.

## Delistings the data did not hold

All 16 are on [Draftguru's 2026 retirements and delistings](https://www.draftguru.com.au/years/2026/retirements-delistings) and in Wikipedia's delistings table; the AFL.com.au articles are the ones Wikipedia cites.

| Date | Player | Club | AFL.com.au |
|---|---|---|---|
| 2026-08-24 | Jake Stringer | GWS | [report](https://www.afl.com.au/news/1594990/time-was-right-forward-jake-stringers-departure-from-greater-western-sydney-giants-confirmed) (missed in the 9 October build) |
| 2026-10-16 | Max Ramsden | Hawthorn | [report](https://www.afl.com.au/news/1632328/hawthorn-hawks-farewell-duo-max-ramsden-and-flynn-perez-but-leave-door-open-for-summer-lifeline) (offered a chance to train on for a spot in the supplemental selection period) |
| 2026-10-16 | Flynn Perez | Hawthorn | same report |
| 2026-10-16 | Ryan Gardner | Western Bulldogs | [report](https://www.afl.com.au/news/1632352/western-bulldogs-delist-trio-as-off-season-overhaul-rolls-on) |
| 2026-10-16 | Nick Coffield | Western Bulldogs | same report |
| 2026-10-16 | Lachlan McNeil | Western Bulldogs | same report |
| 2026-10-16 | Tom Anastasopoulos | Port Adelaide | [report](https://www.afl.com.au/news/1632353/former-top-10-pick-will-brodie-calls-time-port-adelaide-power-forward-pair-ollie-lord-and-tom-anastasopoulos-delisted) |
| 2026-10-16 | Ollie Lord | Port Adelaide | same report |
| 2026-10-16 | Oliver Hayes-Brown | Richmond | [report](https://www.afl.com.au/news/1632356/richmond-tigers-cuts-pair-steely-green-oliver-hayes-brown-after-making-latest-calls-on-2027-list) |
| 2026-10-16 | Steely Green | Richmond | same report |
| 2026-10-16 | Jack Williams | West Coast | [report](https://www.afl.com.au/news/1632361/west-coast-eagles-continue-off-season-changes-with-clay-hall-harry-schoenberg-and-jack-williams-delisted) |
| 2026-10-16 | Harry Schoenberg | West Coast | same report |
| 2026-10-16 | Clay Hall | West Coast | same report |
| 2026-10-17 | Nik Cox | Essendon | [report](https://www.afl.com.au/news/1632599/former-top-10-pick-nik-cox-among-three-essendon-bombers-delisted) |
| 2026-10-17 | Tom Edwards | Essendon | same report |
| 2026-10-17 | Kayle Gerreyn | Essendon | same report |

Clay Hall and Kayle Gerreyn were already in `list_additions_2026.csv`; they are now delisted free agents like the others. With these the departures file holds 22 retirements and 86 delistings, the same totals as Draftguru's page (22 retirements, 86 delistings).

## Unverified

Left as they are in the data (still delisted free agents), because the move is reported but not done or the sources disagree:

- **Wil Parker (Collingwood delisted, to Carlton).** [Draftguru](https://www.draftguru.com.au/years/2026) lists him as a delisted free agent signing at Carlton, and [Zero Hanger](https://www.zerohanger.com/delisted-collingwood-defender-to-join-unique-pies-to-blues-club-183351/) and [AFLRATINGS](https://aflratings.com.au/2026-afl-list-changes/) report a two-year deal from 2 November, but the delisted free agency window has not opened and neither club has announced it. Wikipedia (revision of 17 October) does not list it.
- **Harry Cunningham (Sydney delisted, to Adelaide).** Draftguru lists a free agent signing; AFL.com.au (9 October) and Wikipedia say he will be drafted by Adelaide in the rookie draft, and SEN lists him as an Adelaide "in". It is not a done signing, and the sources disagree on the route.
- **Alex Mirkov (to GWS, delisted free agent from Williamstown).** SEN lists him as an arrival but its own text says GWS has only been "linked". Not added.
- **Samson Ryan (Richmond delisted).** AFL.com.au reports clubs interested ([report](https://afl.com.au/news/1632350/frontrunner-emerges-as-clubs-eye-delisted-richmond-tigers-ruck-samson-ryan)); nothing signed.
- Ollie Purcell's date of birth (above) and Dominic Bedendo's height (188 or 191 cm; 191 used).

Out of scope: the eight players Tasmania has signed ([AFLRATINGS list changes](https://aflratings.com.au/2026-afl-list-changes/)): the club joins the league in 2028 and its list is built in the expansion data, not here.

## Method and what was opened

- Read in full: [Draftguru years/2026](https://www.draftguru.com.au/years/2026) (free agency and trades by player), [Draftguru trades, all time](https://www.draftguru.com.au/trades) (the 2026 trades with picks), [Draftguru retirements and delistings](https://www.draftguru.com.au/years/2026/retirements-delistings) (22 and 86 rows), Wikipedia's [2026 AFL draft](https://en.wikipedia.org/wiki/2026_AFL_draft) wikitext (revision 17 October 2026), [Zero Hanger's tracker](https://www.zerohanger.com/every-completed-move-in-the-2026-afl-free-agency-and-trade-period-183376/) (14 October), [AFLRATINGS completed trades](https://aflratings.com.au/2026-afl-completed-trades/) and [list changes](https://aflratings.com.au/2026-afl-list-changes/), the [SEN verdict](https://www.sen.com.au/news/2026/10/15/afl-trade-period-verdict-every-club-s-moves-rated-and-what-they-must-deliver-in-2027), the [AFL.com.au club-by-club page](https://www.afl.com.au/news/1631700/your-clubs-trade-period-every-player-every-draft-pick-full-analysis), and the player pages named above.
- Draftguru's trades page for 2026 (`/years/2026/trades`) was empty when read; its all-time trades page and its `/years/2026` page carry the same trades.
- A change is applied only where Draftguru and at least one more source (Wikipedia, AFLRATINGS, Zero Hanger, SEN) agree.
