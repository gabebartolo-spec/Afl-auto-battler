# The 2026 AFL rules the game depends on

A short sourced note (2026-10-06): the restart and squad rules, so the sim and the docs
can be checked against them. Every line has its source; nothing here is changed in the
sim or in other docs.

## The short answer on the goal square

- **After a behind, the kick-in is still taken from within the goal square.** The Laws of Australian Football (final, 13 February 2026) say that after a behind, "any player of the Defending Team may elect to Kick the football from within the Goal Square or play on by exiting the Goal Square within a reasonable time", and if he does neither "a field Umpire will call 'Play On'". [LAWS]
- **What did change about the goal square** is at the centre ball-up: the AFL "removed the requirement for a player to start in the goal square at centre ball-ups". [ESPN2]
- So the "goal-square requirement (none)" in the 2026 rules is about the centre ball-up, not the kick-in. A kick-in from the goal square, with the option to play on, is still the rule, which is what `MatchSim` and `docs/DESIGN.md` describe.

## Kick-ins

| Rule | What it says | Source |
|---|---|---|
| Where | From within the goal square, or play on by exiting it; the umpire calls "Play On" if he does neither within a reasonable time | [LAWS] |
| Time | Eight seconds to bring the ball back into play after a behind, down from 12 | [ESPN2] |
| Kick-ins and marks | From 2026 both kick-ins and marks or free kicks allow 8 seconds for play to resume | [FB] (a Facebook post, secondary) |
| Protected area | A player within five metres of a mark or free kick when it is paid must stand | [ESPN2] |

The sources do not describe a change to where the kicker stands, a different play-on
rule, or a protected zone around the kick-in itself. The five-metre protected area is
for marks and free kicks.

## The ball-up (the centre bounce is gone)

- The AFL Commission scrapped the centre bounce from 2026. "Umpires will no longer be required to bounce the ball to restart play at any stage in elite-level matches"; they throw it up. [ESPN1] The AFL's history of rule changes records "Removal of the Centre Bounce with all restarts to be a Centre Ball Up". [AFLH]
- A competing ruck cannot cross the centre circle line and engage with his opponent before contesting the ball. [ESPN2]
- No player has to start in the goal square at centre ball-ups. [ESPN2]

## The substitute (gone)

- "Clubs will now name 23 players in their match-day teams, including five on the interchange bench." The AFL's Swann: "Probably the strongest feedback on all the things that we spoke about was removing the sub, so we'll do that." [ESPN1]
- The AFL's history of rule changes records "Removal of the substitute player with all teams now allowed five (5) players on the" interchange bench. [AFLH]

## Other 2026 changes in the same sources

- **Last disposal out of bounds:** a free kick against the player with the last disposal before the ball crosses the boundary line between the 50 m arcs; the insufficient-intent rule stays inside the arcs. [ESPN2]
- **A shrug in a tackle** is now deemed prior opportunity. [ESPN2]
- The seven changes were designed to cut match length by about three minutes (AFL.com.au explainer: https://www.afl.com.au/news/1464391/explainer-the-seven-afl-rule-changes-coming-in-for-2026, whose body text could not be read, so only its headline is relied on).

## Sources

- [LAWS] Laws of Australian Football, final 13 February 2026, https://resources.afl.com.au/afl/document/2026/02/13/8676d880-481a-4211-a479-305f138ce8b6/Laws-of-Australian-Football-Final-13-February-2026-.pdf (the kick-in Law, quoted).
- [ESPN1] "Centre bounce, sub gone in AFL rules shake-up", ESPN, 1 October 2025, https://www.espn.com/afl/story/_/id/46442874/afl-centre-bounce-scrapped-substitute-rule-removed-changes
- [ESPN2] "AFL confirms more rule changes for 2026 season", ESPN, 29 October 2025, https://www.espn.com/afl/story/_/id/46763883/afl-rule-changes-2026-last-disposal-ruck-nominations-goal-square-protected-area
- [AFLH] History of Rule Changes, AFL.com.au, https://www.afl.com.au/about-afl/history/rule-changes
- [FB] "AFL announces 2026 rule changes to reduce dead time", Facebook, https://www.facebook.com/groups/707251608164681/posts/1141613118061859/
