# Putting a private test build on itch.io

For the director. You upload; nobody else needs your itch login or keys. The build is the browser
("HTML") version, single-threaded, so it needs no special server headers: SharedArrayBuffer is
not needed.

## 1. Get the zip

1. On GitHub, open Actions, then "Web build". Run it with "Run workflow" on main (it also runs on
   every push to main).
2. When it is green, open the run and download the artifact `aussie-rules-dynasties-web`.
3. Unzip it once. Inside is `index.html` at the top, next to `index.js`, `index.pck`,
   `index.wasm` and a few smaller files. The downloaded zip is already in the right shape for
   itch: if it has `index.html` at the top level of the zip, upload it as it is.
4. Size: about 25 MB zipped (38 MB game data, 39 MB engine, both compress well). The data is
   mostly the figure sheets and the music. (2026-10-18: the generated music was removed, so the data is smaller than this.)

## 2. Create the project on itch

1. itch.io, Dashboard, Create new project.
2. Kind of project: **HTML**.
3. Uploads: upload the zip, and tick **This file will be played in the browser**.
4. Embed options:
   - Viewport dimensions: 1280 x 720 (the desktop design size). Tick **Fullscreen button**.
   - **Mobile friendly**: tick it, and set the orientation to **Default** (the game follows the
     phone: portrait phone layout when held upright, wide layout when turned).
   - Leave "SharedArrayBuffer support" **off**. Leave "Automatically start on page load" off
     (itch then shows a Run game button; that tap is also what lets the browser play sound).
   - Tick **Click to launch in fullscreen** only if you want phones to start fullscreen.
5. Title, short description and a cover image as you like.

## 3. Keep it private

Visibility and access, at the bottom of the project's Edit page:

- Set it to **Restricted** and press Save. Then either:
  - **Password**: set one, and send testers the page link and the password; or
  - **Download keys / access list**: under Distribute, create keys and send each tester one.
- Do not set it to Public until you want it public. A Restricted page is not searchable.

## 4. Testers

- Open the link, press Run game, wait for the loading bar (the first load downloads about 25 MB;
  later visits are cached).
- Saves live in the browser (IndexedDB): they survive a refresh and a closed tab, but only on the
  same browser and device, and clearing site data erases them. Private/incognito windows lose them
  when closed. Tell testers.
- Desktop: Chrome, Edge or Firefox. Phone: Android Chrome and iOS Safari (iOS needs the tester to
  tap once before sound starts, as for any web game).

## First test on your phone

Do this once yourself before sending the link to testers (iOS Safari and real-device speed are
the two things nobody could check from a computer):

1. Open the itch page on your phone and tap Run game. Hold the phone upright first.
2. Wait for the loading bar. Note roughly how long it took on your connection.
3. Does the menu fill the screen with no page scrolling or zooming? (Pinch and double-tap should
   do nothing.)
4. Tap New career and play through to the draft, or load a career if you have one. Do taps land
   where your finger is, on every screen?
5. Play a live match: tap Ball it up, watch the oval, use a quarter-time break. Is it smooth, or
   does it stutter? Tell us the phone model if it does.
6. Is there sound after your first tap? (iOS needs that first tap; check the silent switch too.)
7. Turn the phone sideways and back. The layout should change with it and keep your place.
8. Use the phone's Back (Android gesture or browser Back). It should take you one screen back in
   the game and never leave the page. (Leaving the game from the main menu is the browser's own
   tab or home button.)
9. Save, close the tab, reopen the link: Continue should show your career. Private tabs won't.
10. Note anything cut off by the notch or the bottom bar.

Send back: phone model, browser (Chrome or Safari) and what felt wrong.

## Reporting a problem

Tell testers to send you four things, by whatever channel you choose (a message, an email, a form;
nothing about how to reach you is stored in the game or the repo):

1. **Build**: the small grey line at the bottom of the main menu, for example "Build 0.1.13 (a1b2c3d)".
   Settings shows the same line as the version. It says exactly which upload they played.
2. **Device and browser**: for example "Pixel 8, Chrome" or "iPhone 14, Safari" or "Windows, Edge".
3. **What happened**: what they tapped, what they expected, what they saw. A screenshot helps.
4. **Could it be repeated?** Once, or every time.

If the screen is black or stuck, also ask for the browser console text (desktop: F12, Console).

## 5. Updating the build

Upload the new zip, then delete the old upload so only one file is marked to play in the browser
(itch's own advice is to upload the new zip and delete the old one; its docs don't say more about
caching, so if a tester still sees the old build, ask them to hard-refresh (Ctrl+Shift+R, or on a
phone close the tab and reopen the link) and check the build label on the main menu). Testers get the new build on their next load. Saves from
the older build keep loading.

**Version number.** The version comes from `project.godot` `config/version` (the menu and Settings read it, and the Android and Windows exports use it); nothing else holds a copy, and `tools/check_version.py` fails CI if one appears. Bump it with `python3 -I tools/bump_version.py` in its own PR before a build. The butler `--userversion` is `<version>-<sha7>` (for example `0.1.13-60a1bd4`), and the devlog title is `Build <version> (<sha7>): ...`.

## Known issues

- Once in testing, after resizing the window and reloading, the menu drew zoomed in. A reload fixed it
  and it did not come back in about 30 further tries (resize then reload, and rotating without a
  reload, at pixel ratios 1 and 2). If a tester sees the screen zoomed in, ask them to
  reload the page, and tell you the build label and device.

## Notes

- Anything that is not in the zip is not online: there is no server, no account and no network use.
- If a tester sees a black screen, ask for the browser name and version and the browser console
  (F12) text. The game needs WebGL 2, which every current browser and phone has.
