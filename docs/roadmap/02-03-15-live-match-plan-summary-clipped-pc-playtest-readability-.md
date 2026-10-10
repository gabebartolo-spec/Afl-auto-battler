### Live-match plan summary clipped — PC playtest readability bug (2026-10-07)

- Screenshot: the “Your plan: Balanced · Harry Dean loose behind the ball · Jasper Alger on th…” summary truncates an assignment, making the plan unreadable/incomplete. Show the complete current tactical information in a compact readable layout: wrap appropriately or use clearly grouped short labels/cards rather than forcing all assignments into a single ellipsised line. Maintain sufficient space between the plan summary and match-event heading, avoid clipping and overlaps, and let the user read the full assignment without relying on hover. Check long player names, multiple active calls, desktop window sizes and display scaling in the exported PC build. Apply the same readable responsive behaviour to the expanded midfield/forward/backline priorities and main-ruck choices already requested; mobile may use compact expansion or necessary scrolling, but must retain access to complete text. This is a roadmap bug report for Claude, not a game-code change.


### Snap-for-goal vignette: floating football — PC playtest bug (2026-10-07)

- The director reports that the player is not actually holding the football in the snap-for-goal vignette: it hovers near his hands. Fix visible hand-to-ball contact throughout the held phase, then make the release into the snap animation coherent. Investigate the actual animation/attachment alignment rather than assuming the cause; check applicable player appearances, poses and camera angles so a single frame offset does not merely hide the problem. Verify the exported PC build in motion, not only a still image. Preserve the shot outcome and timing mechanics. Roadmap comment for Claude; no game code changed here.


