# Club-life stories: director decisions

One line per decision, newest last. The questions are the ones put to the director; the answers are his.

| Date | Question | Director | Where it shows |
|---|---|---|---|
| 2026-10-11 | Is Leadership a number or words only? | A number, like the other ratings. | Leadership row on the player profile (#658) |
| 2026-10-11 | Can an AI club take the captaincy off its captain mid-season? | Yes, rarely, as league news: an invented captain only, never an invented scandal for a real-named player. | Captaincy.AI_STRIP_CHANCE, `_captaincy_week` (#662) |
| 2026-10-12 | In a redraft or custom career, should your club start with a captain already named? | Yes, named by rule (the same rule as the rivals: highest Leadership is captain, next two are vice-captains). The coach can change him on the Captaincy page. Real-lists careers keep the real captain. | `_captaincy_refresh` (#671). Replaces the P2-2 spec line "Your own club stays empty until you name someone": that holds only after the first appointment, so a captain who leaves, or one you took off, leaves the spot open. A save from before this is named once, by the rule, at the first round after it loads. |
| 2026-10-12 | When your captain retires or leaves, should a vice-captain step up, or does the spot stay open? | Yes: a vice-captain steps up by the same rule as the AI clubs (the best-rated vice-captain; the highest Leadership on the list if none is left), with a short note to the coach, and the coach can change it on the Captaincy page. If the coach took the captain off himself, that choice stays: no auto-fill for a spot the coach emptied on purpose. | `_captaincy_refresh` (the slump follow-up). Replaces "a captain who leaves leaves the spot open". A spot is only filled when there was a captain to lose. |
