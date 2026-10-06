# Intercept possessions by position: what the public record says (2026-10-06)

For the director's "any player can intercept" decision. Research only, no code. The
short answer: **the public pages give a few solid anchors but not the full table by
position or the defensive-half against forward-half split.** The full table is one
download away (below).

## What was found

An intercept possession is Champion Data's name for winning the ball from an
opponent's disposal in the air or on the ground (definition on the AFL's
[stats glossary](https://www.afl.com.au/news/144837/stats-glossary-every-stat-explained)).

**Per game, by player and role (Champion Data, via Fox Sports, April 2026):**

| Player | Role | Intercept possessions per game | Champion Data's comparison |
|---|---|---|---|
| Luke Parker (Sydney) | general defender (moved behind the ball) | 5.8 | elite for general defenders |
| Matt Carroll (Carlton) | half-back line | 4.8 | elite among midfielders |
| Harrison Petty (Melbourne) | key defender | 3.6 | below average for key defenders |

Source: [Fox Sports, "Every AFL club's improver and slider" (16 April 2026)](https://www.foxsports.com.au/afl/afl-2026-every-clubs-improver-and-slider-champion-data-analysis-column-trade-and-free-agency-recruits-performance-this-season-latest-news/news-story/b5b0e5f407868cfc2e1551db4b23bcda).
Read: **an elite general defender is about 6 a game, an elite key defender is well
under that (a key defender at 3.6 is below the average for his position), and 4.8 is
enough to be called elite among midfielders.** That puts the position average for
midfielders under 4.8 and for key defenders a little above 3.6, but the exact
averages are not published on these pages.

**Career-best examples (older, for the top end):** Nick Vlastuin averaged 7.5 a game
in a season (Wikipedia, [Nick Vlastuin](https://en.wikipedia.org/wiki/Nick_Vlastuin));
the AFL's All-Star stats team had an AFLW player at 7.2 (AFL.com.au, AFLW, not
comparable to AFL).

**Intercepts at the team level (Champion Data, April 2026, via Fox Sports):** Geelong
and Gold Coast lead the league for forward-half intercepts and points from them;
Hawthorn ranks first for intercept-to-score, Fremantle converts 24 per cent of its
intercepts into a score, Port Adelaide 23 per cent. Source: [Fox Sports, "Stats state of play for every club" (21 April 2026)](https://www.foxsports.com.au/afl/afl-2026-stats-state-of-play-for-every-club-strengths-and-weaknesses-champion-data-analysis-column/news-story/3a30d3d8e1b68b449ba774fa956e652a).
Read: **forward-half intercepts are a real, separately tracked thing and a few sides
are built on them**, so intercepting is not only a defender's job.

**Share in the forward half (2017, older):** the league average was **24.2
forward-half intercepts per team per game** (North Melbourne led with 29), from a
Champion Data piece republished by [North Melbourne](https://www.nmfc.com.au/news/257936/afl-the-good-stats).
The matching total per team per game was not on the page, so the share can't be
worked out from it.

**Intercept marks (ESPN, July 2025):** Sam Taylor (GWS) led with 58 intercept marks,
29 of them contested. Source: [ESPN, "The AFL's best at everything"](https://www.espn.com/afl/story/_/id/45546603/afl-best-players-61-different-skills-top-traits-stats-2025).

## By position (Champion Data via Wheelo Ratings)

Source: [wheeloratings.com](https://www.wheeloratings.com/afl_stats.html), the site's own data download for the 2025 and 2026 AFL seasons, fetched 2026-10-06 and saved in `docs/research/wheelo/`. The numbers are Champion Data's, and the position is Champion Data's. Players with 10 or more games; averages are weighted by games played. Rebuild with `python tools/balance/intercept_by_position.py`.

The 2026 season and 2025 are close to each other, so the shape is stable: a key defender averages about **5.5** intercepts a game and an average general defender about **4.5**, a midfielder about **2.5**, a ruck about 2, a general forward 1.2 to 1.4 and a key forward about 1. The best in the league is about 8 a game. Defenders make up roughly **55 per cent of all intercepts**, midfielders about a quarter, and forwards, mid-forwards and rucks the last fifth.

The Fox Sports figures above fit: Harrison Petty at 3.6 is well under the key-defender average of 5.5, and Luke Parker's 5.8 is high for a general defender (4.5).

### 2025 (462 players with 10+ games)

| Position | Players | Intercepts a game (average) | Median | Top 10% | Best | Intercept marks a game | Share of all intercepts |
|---|---:|---:|---:|---:|---:|---:|---:|
| Key Defender | 50 | 5.8 | 5.6 | 7.5 | 8.4 | 2.17 | 20% |
| Gen. Defender | 103 | 4.5 | 4.5 | 5.8 | 8.0 | 1.15 | 37% |
| Midfielder | 124 | 2.5 | 2.4 | 3.5 | 4.9 | 0.34 | 23% |
| Mid-Forward | 28 | 2.1 | 2.0 | 2.9 | 3.4 | 0.24 | 4% |
| Gen. Forward | 85 | 1.2 | 1.2 | 1.7 | 2.6 | 0.13 | 8% |
| Key Forward | 49 | 0.9 | 0.8 | 1.5 | 2.2 | 0.18 | 3% |
| Ruck | 23 | 2.2 | 2.0 | 3.0 | 4.9 | 0.95 | 4% |

Where each position wins its possessions (all possessions, not intercepts; share of the position's possessions):

| Position | Own defensive 50 | Defensive midfield | Attacking midfield | Forward 50 | Intercepts per 100 possessions |
|---|---:|---:|---:|---:|---:|
| Key Defender | 50% | 33% | 15% | 2% | 49 |
| Gen. Defender | 36% | 39% | 23% | 2% | 28 |
| Midfielder | 15% | 39% | 36% | 10% | 12 |
| Mid-Forward | 13% | 34% | 37% | 16% | 11 |
| Gen. Forward | 6% | 26% | 38% | 30% | 10 |
| Key Forward | 3% | 21% | 32% | 44% | 8 |
| Ruck | 15% | 37% | 36% | 12% | 15 |

Top ten interceptors:

| Player | Club | Position | Games | Intercepts a game |
|---|---|---|---:|---:|
| Sam Taylor | Greater Western Sydney | Key Defender | 20 | 8.4 |
| Sam Collins | Gold Coast | Key Defender | 22 | 8.1 |
| Josh Worrell | Adelaide | Gen. Defender | 25 | 8.0 |
| Mark Keane | Adelaide | Key Defender | 25 | 7.8 |
| Harris Andrews | Brisbane | Key Defender | 27 | 7.6 |
| Aliir Aliir | Port Adelaide | Key Defender | 22 | 7.5 |
| Nick Vlastuin | Richmond | Gen. Defender | 22 | 7.5 |
| James Sicily | Hawthorn | Gen. Defender | 23 | 7.4 |
| Jacob Weitering | Carlton | Key Defender | 23 | 7.3 |
| Darcy Moore | Collingwood | Key Defender | 22 | 7.2 |

### 2026 (472 players with 10+ games)

| Position | Players | Intercepts a game (average) | Median | Top 10% | Best | Intercept marks a game | Share of all intercepts |
|---|---:|---:|---:|---:|---:|---:|---:|
| Key Defender | 57 | 5.5 | 5.3 | 7.8 | 8.4 | 1.85 | 21% |
| Gen. Defender | 100 | 4.5 | 4.4 | 5.9 | 7.8 | 1.06 | 34% |
| Midfielder | 126 | 2.7 | 2.6 | 3.6 | 4.5 | 0.36 | 25% |
| Mid-Forward | 30 | 2.0 | 1.9 | 2.5 | 3.7 | 0.18 | 4% |
| Gen. Forward | 77 | 1.4 | 1.4 | 2.0 | 2.7 | 0.12 | 8% |
| Key Forward | 54 | 1.0 | 0.8 | 1.6 | 3.0 | 0.21 | 4% |
| Ruck | 28 | 2.1 | 1.9 | 3.1 | 4.0 | 0.82 | 4% |

Where each position wins its possessions (all possessions, not intercepts; share of the position's possessions):

| Position | Own defensive 50 | Defensive midfield | Attacking midfield | Forward 50 | Intercepts per 100 possessions |
|---|---:|---:|---:|---:|---:|
| Key Defender | 50% | 33% | 15% | 2% | 45 |
| Gen. Defender | 37% | 39% | 22% | 2% | 27 |
| Midfielder | 16% | 39% | 35% | 10% | 13 |
| Mid-Forward | 12% | 34% | 37% | 17% | 11 |
| Gen. Forward | 7% | 26% | 38% | 29% | 11 |
| Key Forward | 3% | 20% | 31% | 46% | 9 |
| Ruck | 15% | 34% | 36% | 14% | 16 |

Top ten interceptors:

| Player | Club | Position | Games | Intercepts a game |
|---|---|---|---:|---:|
| James Sicily | Hawthorn | Key Defender | 24 | 8.4 |
| Callum Wilkie | St Kilda | Key Defender | 23 | 8.2 |
| Sam Collins | Gold Coast | Key Defender | 21 | 8.0 |
| Aliir Aliir | Port Adelaide | Key Defender | 22 | 8.0 |
| Tom McCartin | Sydney | Key Defender | 22 | 8.0 |
| Tom Stewart | Geelong | Gen. Defender | 23 | 7.8 |
| Reuben Ginbey | West Coast | Key Defender | 13 | 7.8 |
| Josh Worrell | Adelaide | Gen. Defender | 24 | 7.5 |
| Mac Andrew | Gold Coast | Key Defender | 23 | 7.1 |
| Harris Andrews | Brisbane | Key Defender | 24 | 7.1 |



**Reading the zone table.** The four zone columns are where each position wins *all* of its possessions, not its intercepts. A key defender wins half of his possessions in his own defensive 50, a key forward 46 per cent in the forward 50. A key defender's intercepts are about 45 per cent of his possessions (27 for a general defender, 13 for a midfielder, 9 to 11 for a forward), so for a defender the intercept is the job and for a forward it is a small part of it.

## What is still missing

- The share of intercepts won in the **defensive half against the forward half**. Champion Data tracks forward-half intercepts for teams (see above; the 2017 league average was 24.2 per team per game), but the player download has intercepts only as one total, and the zone fields are for all possessions.
