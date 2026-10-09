# PC UI audit, 2026-10-10

Director, 2026-10-09/10:
- "season stats page is very ugly, please setup a UI pass over ALL screens to update to our new style achieved on gameday"
- "it looks like we are using a mobile UI on a PC game currently. Setup a pass which scans every UI element in the game on PC which look designed for mobile"
- "the oval is way too zoomed in on PC"
- "watch out for empty space like on the left there, no point in having that"

## How it was captured

- **Tool and run:** `capture_screens_light --mode dark --size 3840x2160` on CI (run 37943070993), plus the per-screen tools.
- **Canvas size:** a 3840x2160 window is the director's fullscreen canvas, 1280x720 UI units. His screen runs at 300% Windows scaling (288 dpi), so a 1920x1080 window there is only 640x360 units. The "TV" screen size is about 800x450.
- **Two targets:** every PC layout has to work from about 760 units wide up to 1280, as well as on the 390-unit portrait phone.

## The rules the pass applies (memory: pc-is-not-a-big-phone)

1. **No tap-to-reveal when there's room.** No "More ..." toggles on a wide screen.
2. **Columns that balance.** No column ending early beside a long one, and no full-width empty panels.
3. **Actions sit together, sized to their words, near what they act on.** No full-width bars on PC.
4. **The gameday style on every club screen.**
   - Your club's colour behind the page (ClubBackdrop).
   - One hero element per screen, in the scoreboard face where it is a headline fact.
   - Your club marked in your colour wherever it appears in a list.
5. **Desktop words on desktop.** Click, not long-press. Phone gestures are described only on a phone.

## Screen by screen (PC, 1280x720 canvas)

| Screen | Phone-style or empty on PC | Gameday gap | Fix | Status |
|---|---|---|---|---|
| Match, break | "More calls" hid half the calls; one 640-unit column | had the club band | Wide sheet: 2 or 3 balanced columns, actions right; the match-ups sit under the report | claude/pc-match-layout |
| Match, live | Follow-cam zoomed in; the feed panel right of the oval is mostly empty early in a match | done | The whole ground on PC (done). Feed panel: use it (quarter-by-quarter scores and the key match-ups live) or narrow it | oval done; panel open |
| Season stats | Three rows of tabs and filters over the table; no headline | none | Backdrop, hero (your ladder spot), one tab row, your row in colour | claude/stats-gameday (pilot) |
| Hub | A bottom bar of 4 full-width buttons; your standing card is cut off behind it | done (poster, backdrop) | Nav as a compact row or rail; the standing card fully visible | open |
| Coaching | One column stretched across 1280 units: "Aerial power ... Elite" spans the screen; a full-width "My list" bar; long scroll | backdrop added | Two columns: How we play + strengths / board, cap, staff, recent games | done, claude/stats-gameday |
| Training | The right panel is empty ("Choose a player from the list"); "Long-press a player to select several" on PC | backdrop added | Wide: open the first player (or a squad development summary) in the panel; desktop copy: Ctrl/Shift-click | done, claude/stats-gameday |
| My list | Fine: oval + list side by side. "INTERCHANGE" is a caps label | backdrop added | Sentence case | minor |
| Team selection | Mostly landscape already. The interchange row is cut off at the bottom; the summary panel's right side is empty | backdrop added | Fit the interchange; tighten the summary | done, claude/stats-gameday |
| Staff | One stretched column of six names; the right two-thirds empty; the "Another club's staff" bar at full width | backdrop added | A grid of staff cards (3 across), the action sized to its words | done, claude/stats-gameday |
| Off-season | Every player row carries a full-width "Talk contract" / "Ask him to go around again" bar | backdrop added | Compact rows: the facts left, the actions right; two columns of rows on PC | done, claude/stats-gameday |
| Ladder (LadderScene) | The numbers are pushed to the far right, a 1300-unit gap after the club name; your row isn't marked. It also answers the same question as Season stats > Ladder | backdrop added | Either route Ladder to Season stats (one screen per job, a director call) or narrow it to its columns and mark your row | open, director call |
| League draft | Landscape already. No club colour (on club select there is no club yet) | none | Backdrop once a club is chosen | open |
| Club Forge, Main, Options | Not captured in this run | | Next capture pass | open |

## Split

- **Lead:** Coaching, Staff and Off-season. These have the same fix: column layout and compact action rows.
- **Helper, after the loose-man fix:** Training (fill the empty panel, desktop copy), Team selection (interchange fit).
- **Director calls, asked once he is back:**
  - the Ladder screen (keep it or route it to Season stats);
  - the hub nav bar;
  - the look of all of this as one before/after set.
