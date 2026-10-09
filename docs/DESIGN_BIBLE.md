# Aussie Rules Dynasties: Design Bible

_Director's decisions, brainstorm of 2026-10-09. Session record:
[brainstorms/2026-10-09-design-bible.md](brainstorms/2026-10-09-design-bible.md)._

## What this document is

The bible holds the ultimate truth for Aussie Rules Dynasties. It is a philosophy
that informs all development, not a roadmap, and it schedules no work.

- Where CLAUDE.md, the roadmap or any other document disagrees with the bible,
  the bible wins and the other document is corrected.
- The bible changes only with the director's explicit consent for each
  individual update. No agent edits it on its own judgement.
- Everything in it was said or chosen by the director.

## The vision

A simulation that feels like a story, a legacy, a dynasty.

**The defining moment.** A player you took with a risky draft pick wins the
Brownlow. The satisfaction is that your vision and your faith paid off.

**The other side of it.** The same pick fails. The player feels disappointed, but
understands the risk was theirs to take. Risks can pay off and risks can fail. It
is up to the player, and the game is objective about it.

## The core pillar: player agency

Player agency is the core pillar. It is what sets this game apart from simulators
that lean toward the uninteractive.

- This is not a spreadsheet simulator.
- Setup and observation are fine, but the game has active participation as well.
- The game is designed for a player who plays most matches and sims the odd one.
  Playing hands-off is the gamer's call, and the risk of it is theirs.

## The principles

One ethos runs through every decision in the game: the player knows the risk, the
risk is theirs to take, and the results are explained clearly and objectively.

1. **The risk belongs to the player.** The game does not soften a failure or take
   the decision away.
2. **Decisions move the odds, never the certainty.** Perfect coaching with a
   weaker list maximises your chances but guarantees nothing. In AFL you can
   never take a result for granted; a poor team can knock off an unprepared
   opponent.
3. **The game shows what each decision led to.** Some outcomes are obvious: you
   decide to shoot, and it scores or it doesn't. Others need clear UI and
   deliberate copy: what the roaming interceptor did, whether the switched
   defender halted the forward's run. The player assesses whether it met their
   expectations.
4. **Reading the game is the skill.** Success comes from taking clearly presented
   information and making informed strategic decisions, in list management and in
   the match. The exact science stays clouded by intuition and observable trends.
5. **No number vomit, no excessive UI.** The player should not feel they will
   develop arthritis from clicking. Obtuse stats and maths are described in
   football terms whenever possible.

## The coach

The player is a coach, and every decision is roleplaying: event calls, in-game
moments (defend now, or attack now?), answers in press conferences, the look of
Forge creations, the list management strategy.

**What can affect the sim.** What the coach says or decides can affect the sim.
How the club looks or sounds never does. Weather is the one exception: it should
matter.

**Press conferences.** Answers affect the sim: player morale, board expectations
and relationships with the press. Journalists have personalities.

- An answer is a dice roll based on logic. The gamer should know that a comment
  carries risk.
- The press conference tests media literacy, relationship management and board
  compliance.
- The effect is visible afterwards. Criticise a young player and his morale may
  drop, or his resolve may tighten. The gamer sees their words had an impact, for
  better or worse, and adjusts or carries on.

## Match day and the visual sim

Match day is the culmination of list management and decisions made for this
specific match. Matchup changes, game plan adjustments and in-game decisions all
give the player agency over the result.

The visual sim is the closest the game comes to its target feel. It is real
footy: a visual simulation of the obtuse stats that sit behind every sports sim.

| Kind of move | Examples | How the player sees it |
| --- | --- | --- |
| Structural | Game plan, flooding the backline, stacking the contest | The visual sim changes greatly |
| Individual | A matchup, a positional switch | The matchup shows on the ground; the game feed and post-quarter and post-match copy explain how effective it was |

## Immersion and the art standard

Immersion is a believable world that responds to the coach. It breaks when:

- coaching moves do not change the game
- player ratings do not reflect reality
- the visual sim does not update to a change in strategy
- the art is wrong: bad anatomy, awkward staging, or a misunderstanding of what
  sets AFL apart, including the dimensions and conventions of an AFL field

**The art standard.** Art goes through an internal QA process before the
director's final verdict. Obvious aberrations and ugly errors are picked up by
the agent, without the director babysitting. Known faults that must never reach
the director:

- skin showing through a jumper
- an animation that looks bizarre
- a ball that hovers, or acts independently of the player using it

## The feature test

A feature must be justifiable based on its intent. It does not need to pass every
question below, but it must answer to at least the intent it claims.

- Does it enhance the core philosophy of the game?
- Does it increase immersion?
- Does it create better roleplaying opportunities?
- Does it deepen player agency?
- Does it feel and look beautiful and fun to play?
- Is it understandable, not obtuse or opaquely implemented?

**Who decides.** The agent assesses whether a feature deserves to exist and says
so. The director's say is final.

## Balance

Balance is settled when two things are both true: testing shows numbers similar
to real AFL, and the director's playtest passes the vibe check.

Player ratings that reflect reality are part of this work, not a separate goal.
Balance is still settling.

## Current focus

Polish is the gap. There are two big tickets, and one priority above both.

**The single biggest improvement to game feel:** players in the visual sim really
react to your coaching moves.

1. **Player agency fine-tuning.** In-match decisions and in-match and pre-game
   coaching moves, such as matchups and rotation changes. Each decision should
   feel like it has a real in-match impact and be easily measurable.
2. **Visual polish.** It should not look like an app. It should feel clean and
   crisp like a great app does, but also personal, like a hand-crafted game.

## Open questions for the director

- What will this game deliberately not have? Left open in the session.
- How does weather affect a match? It is decided that it matters; the system is
  not designed.
- Does the Current focus section belong in the bible? It was placed here on an
  assumption, not a stated decision.
- Pre-timeskip survey (a roadmap item): a full survey, or the simpler version
  where the sim follows the club's existing instructions and asks only about what
  nothing else covers?
