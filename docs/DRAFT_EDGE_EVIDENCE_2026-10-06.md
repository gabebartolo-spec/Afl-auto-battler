# League Draft edge: rival read error after the recruiter read (2026-10-06)

#228 narrows rival clubs' League Draft evaluation error (`Draft.AI_EVAL_SD`)
from 1–5 to 0–4 rating points, to trim the human's opening-draft edge
(`docs/COMPETITIVE_BALANCE.md`). That calibration assumed the human sees every
rating exactly. #222, merged later, replaced the exact board with the
recruiters' read (`Draft.user_view`, `USER_EVAL_SD` 3.0), so the two changes
correct the same edge twice.

**Decision (director, 2026-10-06): keep 1–5.** #228 no longer changes `Draft.AI_EVAL_SD`.

**Verdict: 0–4 on top of #222 overcorrects.** A human drafting off the
scouted board finishes the draft well below the median AI club. Recommendation:
keep `AI_EVAL_SD` at 1–5; #222 already does the job.

## Method

- A read-only checkout of #228 at `6433037`.
- The human's picks go through `Draft.board` → `_views` → `user_view` (the
  #222 recruiter read), confirmed in code. "Pre-#222" uses a local-only switch
  that sets the human's read error to 0 (exact board); it isn't committed.
- League Draft only, 8 seeds, 18 clubs, via `league_balance.make_draft`. Two
  humans: "best" takes the top of their own board, and "top5" picks at random
  among their board's top five (the harness's default human).
- Measured on the auto-selected side: strength rank among 18
  (`Squad.strength`), and the gap to the median AI club in strength and in
  best-22 OVR.

## Results

| human's board | rival error | "best": rank / strength vs median AI / best-22 OVR vs median | "top5": rank / strength / OVR |
|---|---|---|---|
| exact (pre-#222) | 1–5 | 1.9 / +3.57 / +3.26 | 5.0 / +1.67 / +2.23 |
| exact (pre-#222) | 0–4 | 4.0 / +3.17 / +2.72 | 6.0 / +1.27 / +1.84 |
| scouted (#222, main) | 1–5 | 7.9 / +0.48 / +1.24 | 9.4 / −0.26 / +0.33 |
| scouted + #228 | 0–4 | 12.4 / −1.48 / +0.14 | 14.3 / −2.34 / −0.22 |

Per-seed ranks for "best": exact 1–5 [1, 4, 1, 2, 1, 3, 2, 1]; scouted 1–5
[8, 5, 11, 8, 11, 4, 14, 2]; scouted 0–4 [14, 13, 8, 12, 17, 14, 14, 7].

## Reading

- On an exact board, #228's 0–4 trims the edge as intended (rank 1.9 → 4.0).
- #222 alone already moved the human from the top of the league to about the
  median (1.9 → 7.9), with a slightly better best-22.
- Together, a human who drafts sensibly off their recruiters' read is about
  bottom-six. That goes against the intent of the #222 director decision that
  good drafting still pays.
- Caveats: 8 seeds, so individual ranks are noisy, but every cell moves the same
  way. These are naive humans who sort by estimated OVR; one who weighs POT and
  list needs does somewhat better. Recruiting budget (`scouting_mult`) buys
  back accuracy by design.
