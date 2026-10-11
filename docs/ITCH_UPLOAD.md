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
   mostly the figure sheets and the music.

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

## 5. Updating the build

Upload the new zip over the old one (same project, same file slot) or push it with butler if you
use it; testers get the new build on their next load. Saves from the older build keep loading.

## Notes

- Anything that is not in the zip is not online: there is no server, no account and no network use.
- If a tester sees a black screen, ask for the browser name and version and the browser console
  (F12) text. The game needs WebGL 2, which every current browser and phone has.
