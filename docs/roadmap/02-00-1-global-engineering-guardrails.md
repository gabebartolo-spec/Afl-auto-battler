# 1. Global Engineering Guardrails

These apply to every milestone.

## 1.1 MatchSim is the football authority

- Watched matches and skipped/simulated matches must derive from the same football simulation authority.
- Presentation must not invent a second set of match outcomes.
- Visualisation may interpolate movement, but goals, disposals, frees, injuries, stats and decisions must reconcile with simulation state.
- Preserve deterministic seeded behaviour wherever the sim currently guarantees it.

## 1.2 Stats must come from football events

Do not generate player-facing statistics independently merely to make box scores look realistic.

A stat should be credited because the corresponding football event occurred:
- inside 50 from an actual entry,
- metres gained from actual territory advanced,
- effective disposal from the disposal outcome,
- intercept possession from an actual interception,
- score involvement from an actual scoring chain,
- CBA from actual centre-bounce participation.

Avoid double-crediting and avoid "random stat garnish".

## 1.3 Football roles are tendencies, not hard rails

- Position should strongly influence where/how a player participates.
- Normal AFL actions should remain structurally possible unless the laws or match context genuinely prevent them.
- Do not solve role identity by making ordinary actions impossible for whole position groups.
- If a role gate creates absurd behaviour, treat it as a sanity bug first and a balance problem second.

## 1.4 AI parity

**The human player gets no hidden mechanical advantage over AI-controlled clubs.** Difficulty should come from making better decisions within the same football world, not from rules, buffs or development opportunities that secretly favour the user's club.

Unless a feature is explicitly player-only UX:
- Human and AI clubs obey the same underlying football, list-management, development and competition rules.
- Any mechanic that can improve the human club's players, list or match outcomes must have an equivalent route available to AI clubs under the same underlying rules. This includes training/development, POT and breakout behaviour, form/morale effects, injuries/recovery, contracts, drafting, trading, selection and tactical effects.
- Do not give the human club hidden rating boosts, favourable RNG, easier development ceilings, protected outcomes, cheaper costs, extra information or other mechanical assistance that an AI club cannot receive in the equivalent situation.
- AI clubs obey the same availability, salary-cap, suspension, concussion, selection and match rules.
- AI should be able to make equivalent tactical choices.
- Never give the player a rule loophole unavailable to AI, or vice versa, without documenting why.
- Player-only **interface conveniences** are allowed when they help the human operate the game but do not change the underlying simulation outcome. If an intentional difficulty/accessibility setting ever breaks parity, it must be explicit to the player rather than hidden.
- When implementing or auditing a system that affects competitive outcomes, explicitly check human/AI parity. A mechanic that works only for the user's club is a correctness problem unless the roadmap deliberately documents it as an explicit asymmetric mode.
- **AI must never be psychic.** An AI club may react only to information it could plausibly know at that moment: public match state, observed behaviour, scouting/known tendencies, and other information deliberately exposed to both sides.
- AI must not inspect or counter hidden player-only choices merely because the simulation has access to them. This includes an unobserved game plan, a private moment-card choice, a future player decision, or other concealed UI/state unless that information has become observable or an explicit symmetric scouting mechanic provides it.
- Stronger AI should come from better inference, preparation and reactions to evidence, not omniscience. If an AI advantage only works because it reads hidden state, redesign the behaviour rather than preserving the advantage.

