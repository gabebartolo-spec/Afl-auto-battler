# Director decisions, 2026-10-25

Asked by the question tool as each came up; his picks are in quotes where they were a labelled choice. Where a later
decision of his differs, the later one wins. Nothing here edits the bible.

| # | Question | His answer | What follows |
|---|---|---|---|
| 1 | (unprompted) "make the afl game auto portrait mode in mobile" | his words | PR claude/mobile-portrait-default: a phone opens in portrait; the Screen setting keeps Portrait (default), Landscape and Follow the phone |
| 2 | (unprompted) "implement live trading of picks on draft night" | his words | rows 3 to 6 scope it; PR claude/draft-night-trades (register row 46) |
| 3 | On draft night, who can make pick trades? | "Everyone (Recommended)" | you offer at any time; rival clubs put offers to you as your pick nears; rivals deal among themselves and the board shows it |
| 4 | What can change hands on the night? | "Picks, this and next 2 drafts (Recommended)" | tonight's picks and the next two years' picks, the real AFL rule; players stay out, the lists are closed on draft night. The same three drafts are tradeable in the trade period (the code held two) |
| 5 | When can a deal be struck? | "Any time, no clock" | the night pauses while you deal; no timer |
| 6 | How do rival clubs decide whether to say yes? | "Same values as the trade period (Recommended)" | the existing pick-value and club-cycle rules; no night premium, no new balance knob |
| 7 | His look on the captures A-F (sheet, offers, deal, board strip, PC) | "it LOOKS fine, but the trades being offered are absurd?" (pick 45 + a 2029 second for pick 6) | look passed; offers fixed: a rival bids up to its own full value and only within a tenth of fair value by the consensus read (NIGHT_OFFER_FLOOR 0.9); sample after: pick 9 + a 2029 third for pick 6 |
| 8 | Merge #848 and #847 when CI is green? | "Yes, merge #848 and #847 when CI is green." | #847 merged bec3a4ed; #848 merges on green |
