# Stretch Goals

## AFLW full implementation
**Status:** `DEFERRED`  
**Priority:** `P3`  
**Autonomy:** `SUPERVISED`

Long-term stretch goal: implement the AFLW as a fully playable competition, not a token side mode.

Scope should eventually include:
- full AFLW clubs, players, fixtures, ladder, finals, awards, records and history,
- AFLW-specific list management, drafting, contracts, development and competition rules,
- coaching, tactics, match simulation, presentation and long-save continuity,
- club and league history that can develop independently over decades,
- shared underlying systems with the AFL implementation where practical, without forcing AFL rules or data onto AFLW,
- AFLW-specific research and validation for rules, competition structure, list sizes, season format, venues, uniforms and historical context.

Guardrail: do not begin this until the core AFL game is stable and the shared systems are mature enough that AFLW can be implemented as a proper parallel competition rather than a shallow reskin.


## Player personality types
**Status:** `DEFERRED` (director, 2026-10-14 23:14: "stretch goal")  
**Priority:** `P3`  
**Autonomy:** `SUPERVISED`

Director: "stretch goal: personality types, for example 'egotistical', 'natural leader'", "each personality with
its own strengths and weaknesses".

Each player carries a personality, readable on his profile, that gives him strengths and weaknesses off the field
and in the story layer (for example, a natural leader steadies a young group but expects a say; an egotistical
star lifts in big games but sours the room when dropped or out-shone).

Before design: map it against what exists so it does not duplicate. Player traits and synergies, mood, trust,
promises, captaincy/leadership (ARD-M7-004) and the story cards already carry some of this. The design question is
whether personality replaces, groups or sits beside them. Rules stay transparent: what a personality does is
looked up exactly, never hidden. Not assigned; nothing starts until the director says so.
