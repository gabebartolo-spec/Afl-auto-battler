# G1 audit: how often the game asks the coach for something

ROADMAP §9.4 prerequisite G1: before RPG-002 (journalists), RPG-003 (private
conversations), RPG-008 (story beats) or RPG-009 (living characters) surface
anything, define one pacing rule. The roadmap says not to invent a numeric cap
before reviewing a representative season. This is that review, on `main` at
`fa84f7be` (2026-10-09), and a proposed rule for the director.

## Method

`tools/audit/interrupt_impl.gd` plays an autopilot career with every default left
alone and every ask left unanswered (as a coach who skips them would). After each
round it records what is waiting before the next match:

- **card:** the week's event card (`ClubLife.pick_event`, `EVENT_CHANCE` 0.7);
- **press:** a post-match press question (`MediaConference.pick`);
- **tribunal:** a sanction that can still be challenged (`pending_mro_challenges`).

It also counts the news items each round adds (the passive feed). Two careers,
three seasons each, 29 weeks a season including finals:

```
godot --headless --path . --script tools/audit/run_audit.gd -- interrupt_impl 1 MEL 3
godot --headless --path . --script tools/audit/run_audit.gd -- interrupt_impl 2 WCE 3
```

## What a season asks today

| | Melbourne (seed 1) | West Coast (seed 2) |
|---|---|---|
| Weeks | 87 | 87 |
| Weeks with no ask | 26 (30%) | 31 (36%) |
| Weeks with one | 39 (45%) | 41 (47%) |
| Weeks with two or more | 22 (25%) | 15 (17%) |
| Asks per season | 35, 31, 19 | 32, 21, 19 |
| Cards / press / tribunal (3 seasons) | 53 / 18 / 14 | 51 / 14 / 7 |
| Most common collision | card + press (12) | card + press (11) |
| Weeks in a 3+ losing streak with an ask | 12 of 13 | 8 of 20 |
| News items per round | 12.3 (max 47) | 12.3 (max 52) |

Cards by kind (both careers): sore star 19, unhappy 19, fans 19, media 16,
training 15, young gun 10, extension 4, board pressure 2.

## Findings

1. **About one ask a week already.** A third of weeks are quiet; a fifth carry two
   or more. The weekly card is 60% of all asks.
2. **Card and press collide most** (23 of 37 collisions). Both are optional; neither
   has a deadline.
3. **A losing run is not quiet.** Melbourne was asked something in 12 of 13 slump
   weeks: unhappy players, board pressure and the sore star stack up exactly when
   the coach least needs more prompts.
4. **The only urgent asks are rare.** A tribunal challenge (expires at the next
   match) came 7-14 times in three seasons; an extension card (a window) 4 times.
   Nothing urgent is ever crowded out today, because nothing defers.
5. **The news feed is a firehose** (12 items a round), so "move flavour to the
   feed" only works if the feed shows your club's items first.

## Proposed rule (for the director to set the numbers)

**Categories, in priority order:**
1. **Urgent:** a decision with a deadline: tribunal challenge, contract window,
   retirement persuasion. Always shown.
2. **Coaching choice:** the weekly card.
3. **Flavour:** press question, and later a journalist follow-up (RPG-002), a
   private conversation (RPG-003), a story beat (RPG-008), a character moment
   (RPG-009).

**The budget, measured against today:**
- **One flavour slot a week, at most.** New RPG surfaces share it with the press
  question rather than adding to it: a journalist's follow-up *is* that week's press
  question; a private conversation takes the slot instead.
- **Flavour waits for a quiet week.** If an urgent ask is up, flavour defers; if it
  has waited two weeks it goes to your club's section of the feed (or is dropped if
  it no longer holds). It never blocks Play.
- **Keep about a third of weeks quiet**, as today. New features must not lower the
  share of no-ask weeks; the audit re-runs on each RPG PR and says so.
- **A losing run thins flavour:** during a 3+ losing streak, only urgent asks and
  the card; no flavour.
- **Skipping is free.** Skipping flavour never costs a management action; an
  unanswered card keeps its existing default.

**Checks for the first PR that applies it:** collisions resolved by priority, a
losing season under the slump rule, late-season urgent asks never deferred, and a
coach who skips everything (this audit's policy) sees no lost decision.

## Questions for the director

- One flavour slot a week, shared with the press question: right size?
- During a losing run, no flavour at all, or just fewer?
