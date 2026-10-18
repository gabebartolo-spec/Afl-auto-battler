# Director decisions, 2026-10-18 morning

Interview by the question tool after the overnight run (25 merges, chapters 28 and 29 built). His picks are in
quotes where they were a labelled choice; rows 9 to 14 are his own words after the interview. Where a later decision of his differs, the later one wins. Nothing here
edits the bible.

| # | Question | His answer | What follows |
|---|---|---|---|
| 1 | Push the overnight build to itch and post the devlog | "Yes, ship it" | lead ships main at its green sha; devlog lead/devlog_2026-10-18.md |
| 2 | Scale the web canvas up on big monitors (a 1440p browser drew a 2560-unit canvas with 13 px text) | "Yes, scale it" | builder webcanvas: ScreenLayout rule so a wide browser gets the desktop's 1280x720-at-2x look; checks per window size |
| 3 | Melbourne's best and fairest: "Keith 'Bluey' Truscott Medal" or "Trophy" | "Medal" | data/bf_medals.json stays as merged in #780 |
| 4 | Culture has no effect yet: build its effects, move it off the hub, or leave it | "Build the effects" | builder culture, from lead/culture_effects_sheet.md; W7 review; calibration floors untouched; his playtest |
| 5 | P-74 "Not in this game" list: which candidates | Playable control; Microtransactions | the page carries those two. Multiplayer, 3D and spoken commentary were NOT picked: they are not promised absent |
| 6 | The merged looks (With us block, pick provenance, Doig Medal stage, stats on one PC page, list Shape scroll) | "All fine" | no changes |
| 7 | Lead ruling on inline name links (a name in a sentence taps at line height; buttons and Profile taps keep 44 px) | "Keep" | the sweep's "Inline name links" column stays non-gating |
| 8 | Ambition's patient/rebuilding side: an effect too, or win-now only | "Yes, small" | draftees and under-22s settle and develop a touch faster at a patient club (about 3%/5% by grade, his final sizes in playtest); veterans' re-sign asks not lower; one plain line on the Culture screen |
| 9 | (unprompted, after the interview) | "We should remove banner text from the game for now, replace with placeholder text, i will create original banner text movingforward - clearest AI tell in the game which cheapens the experience" | builder bannerclear: every rhyme in data/banners.json becomes the placeholder "{us}" (the day's name for ANZAC Day, ANZAC Eve and Dreamtime at the 'G); sets and keys kept so his originals drop in by set; the old file archived outside the repo (agent-handoffs/lead/banners_old_2026-10-18.json); the assets test checks structure, not rhyme count |
| 10 | (unprompted) | "remove the music too" | builder musicclear, PR #790: the four generated tracks deleted (not archived); MusicManager keeps its player, bus and playlist (now empty, assets/audio/music/README.md says where his tracks go); the Settings "Music" row is hidden while the playlist is empty; the next itch devlog says both removals and that his originals follow |
| 11 | Web canvas (#791): a browser on a big monitor draws the desktop's 1280x720 look at 2x; an iPad upright gets the phone layout, bigger | "Yes, merge it" | merged cd87f113; the critic's leftovers (club ink under 4.5:1 on tinted surfaces, 13-unit captions, empty right side of the hub at 2560) are desktop defects on the list |
| 12 | The itch push failed ("invalid target (bad user)"): butler login, upload by hand, or hold | "I'll run butler login" | the key was fine: the itch username had changed to aussierulesdynasties; target fixed, 0.1.0-54290c9 then 0.1.0-67185d8 pushed with devlogs 1713766 and 1713802 |
| 13 | (unprompted, on the posted devlog) | "dont mention the removals in the devlog" | the "Removed, for now" paragraph and the title's mention came out; rule in memory: devlogs say what players gain, never what was pulled |
| 14 | (unprompted, on the posted devlog) | "remove the melbourne potentials, they dont need to know that, reads as balance tampering" | the line came out; rule in memory: no hand-set ratings or balance notes about a named club in any devlog |

Also told him, no decision asked: AI clubs turn over about 9 players a year (median 9; 66% of club-years inside 8-12),
real clubs lose 4-7 to delistings and retirements plus trades (docs/research/LIST_CHURN_AUDIT_2026-10-18.md). Balance stays his.
