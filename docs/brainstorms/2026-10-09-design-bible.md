# Brainstorm: design bible (2026-10-09, big)

Project: Aussie Rules Dynasties. Tested against the philosophy in CLAUDE.md.
ROADMAP.md, docs/DESIGN.md and several core scripts were not readable in this
session, so roadmap and scope checks are incomplete.

## The idea (director's words)

"I am happy with progress so far but lets get a consistent vision so development
can continue with renewed focus and clear goals."

"The bible is not a development roadmap, its a philosophy that informs all
development processes." "Bible holds the ultimate truth."

## The moment in play

"A player you took with a risky draft pick wins the Brownlow, the satisfaction
that your vision and faith paid off."

The flip side, when the pick fails: "They should feel disappointed, but
understand that the risk was theirs to make... risks can still pay off, they can
still fail, its up to the player. The game should be objective about it."

## Decided

- Core pillar is player agency: it sets the game apart from simulators that
  "lean toward the uninteractive side". Setup and observation are fine, but the
  game has active participation as well.
- Not a spreadsheet simulator: no detailed number vomit, no excessive UI or
  clicking; obtuse stats and maths are described in football terms whenever
  possible.
- The result is "a simulation that feels like a story, a legacy, a dynasty".
- The ethos of every decision: the player knows the risk, it is theirs to make,
  and the results are clearly explained, objectively.
- Match day is a culmination of list management and match-specific decisions:
  matchup changes, game plan adjustments and in-game decisions all give the
  player agency over the result.
- Decisions move the odds, never the certainty: perfect coaching with a weaker
  list maximises your chances but guarantees nothing. "In AFL you can never take
  a result for granted."
- The game shows what each decision led to; the player judges whether it met
  expectations. Some outcomes are obvious (a shot scores or not); others are
  shown through clear UI and deliberate copy (the roaming interceptor's stats,
  whether a switched defender halted a forward's run).
- The core skill is taking clearly presented information and making informed
  strategic decisions, macro (list management) and micro (match decisions). The
  exact science stays "clouded by intuition and observable trends".
- The player is a coach and every decision is roleplaying: event calls, in-game
  moments, press conference answers, Forge creations, list strategy.
- Press conference answers affect the sim: player morale, board expectations,
  relationships with the press. They are dice rolls based on logic; the gamer
  should know a comment carries risk. The press conference tests media literacy,
  relationship management and board compliance. The effect is visible afterwards
  (morale drops, or resolve tightens), for better or worse.
- Coach words and decisions can affect the sim; how the club looks and sounds
  never does. Weather is the one exception and should matter.
- Feature test: does it enhance the core philosophy, increase immersion, create
  roleplaying opportunities, deepen agency, look and feel beautiful and fun, and
  is it understandable? A feature does not need to pass all of these; it must be
  justifiable based on intent.
- The agent assesses whether a feature deserves to exist; the director's say is
  final.
- Immersion breaks when: coaching moves do not change the game, player ratings
  do not reflect reality, the visual sim does not update to changes in strategy,
  or the art is wrong (bad anatomy, awkward staging, AFL conventions missed, skin
  showing through a jumper, bizarre animation, a ball hovering or acting
  independently of the player using it).
- Art goes through an internal QA process before the director's final verdict;
  obvious aberrations are picked up by the agent "without my constant
  babysitting".
- Designed for a player who plays most matches and sims the odd one. Hands-off
  play is the gamer's call and the gamer's risk.
- Current polish goal 1: player agency fine-tuning, particularly in-match
  decisions and in-match/pre-game coaching moves (matchups, rotations). Each
  decision should have a real in-match impact and be easily measurable.
- Current polish goal 2: visual polish. Clean and crisp like a great app, but it
  should not look like an app; personal, like a hand-crafted game.
- The visual sim is the closest thing to the target feel. Making players on the
  simulation react to coaching moves is "the single biggest thing to improve the
  game feel".
- Structural moves (game plan, flooding the backline, stacking the contest)
  should change the visual sim greatly. Individual moves (a matchup) show as the
  matchup on the ground, with the game feed and post-quarter/match copy
  explaining effectiveness.
- Balance is settled when testing shows numbers similar to real AFL and the
  director's playtest passes the vibe check. Ratings that reflect reality are
  part of this work, not a separate goal.
- The bible is the ultimate truth. It is updated only with the director's
  explicit consent for each update.
- The pre-timeskip survey (the player tells the sim how to manage the club
  before a timeskip) goes on the roadmap, not in the bible.

## Rejected and why

- Splitting the feature test into "reasons" (need one) and "standards" (need
  all): assistant's suggestion. The director chose "justifiable based on intent"
  instead.
- "Ratings reflect reality" as a third goal: the director placed it inside the
  balance work, which is still settling.

## Open questions for the director

- What will this game deliberately not have? Asked three ways; left open.
- How does weather affect a match? Decided that it matters; the system is not
  designed.
- Where do the two current polish goals live? Assumed: a "current focus" section
  in the bible, rewritten with consent as they are met. Not confirmed.
- Pre-timeskip survey: full survey, or the simpler version (the sim follows the
  club's existing instructions and asks only about what nothing else covers)?
- Do morale, board expectations and press relationships exist in the sim today,
  or are they new systems? Not visible in this session.
- How tightly is the visual sim tied to what the match sim actually did? The
  director's objectivity rule requires that the ground shows what happened.

## For the decision log

Ready to paste for whoever owns each file.

CLAUDE.md:
- The design bible is the ultimate truth for design. Where this file disagrees
  with it, the bible wins. The bible is edited only with the director's explicit
  consent for each update.
- Weather is no longer flavour only. Director decision 2026-10-09: weather
  should matter to the match. Remove "weather look" from the zero-gameplay-effect
  list once the weather system is designed.
- Flavour rule restated: what the coach says or decides can affect the sim; how
  the club looks or sounds never does (weather excepted).
- Before building a feature, assess whether it deserves to exist against the
  bible and say so. The director's say is final.
- Art: run an internal QA pass before showing the director. Do not ask for
  approval on work with visible faults (skin through fabric, broken anatomy,
  bizarre animation, a ball detached from the player using it).
- Balance is not finished until calibration numbers are close to real AFL and
  the director's playtest passes. An agent cannot declare balance done.

ROADMAP.md:
- Add: pre-timeskip survey. The player sets how the sim manages their club
  before a timeskip. Ethos: the player knows the risk, it is theirs to take, the
  results are explained objectively. Unassigned.
- Add: weather affects the match. Needs design. Unassigned.
- Note: press conference answers affect morale, board expectations and press
  relationships as dice rolls with logic (journalist personalities already
  planned).
- Priority note: visible reaction of the visual sim to coaching moves is the
  director's single biggest game-feel improvement.

## Corrections after the audit (2026-10-09)

Written before the roadmap and design documents were readable. The audit
(`docs/BIBLE_AUDIT_2026-10-09.md`) found:

- Weather already affects play (ARD-M4-016, director decisions 2026-10-06), and
  its look already has zero result effect. The CLAUDE.md line above about
  removing "weather look" from a zero-effect list is withdrawn; nothing needed
  changing.
- Morale and board effects from press answers already exist (ARD-M6-008), and
  journalist personalities are specified (RPG-002).
- The visual sim is bound to what the match sim did (`docs/MATCH_VIEW.md`).
