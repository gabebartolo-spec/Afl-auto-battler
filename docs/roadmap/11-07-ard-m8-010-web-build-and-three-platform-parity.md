## ARD-M8-010 — Web build and three-platform parity
**Status:** `TODO` — director request 2026-10-10, not started, not assigned. Scheduling: the director.  
**Priority:** `P1`  
**Autonomy:** `SUPERVISED` — the boss plans; the open question below is confirmed with the director when scheduled.

### Director's words (2026-10-10)
"Implement fully functional web build of the game. Ensure the game is synchronised across all 3: Android, PC, web."

### Requirement
- A web export that runs the full game (every screen, match, save/load) in a browser, phone and desktop widths.
- One codebase and one content set across Android, PC and web; a release ships all three from the same commit.
- The phone-first and PC-is-not-a-big-phone rules apply to web at both widths: portrait layout at phone width, landscape layout at desktop width, no hover-only information.

### Open question (confirm with the director when scheduled)
"Synchronised" means which of these:
1. Feature and version parity: one codebase, same content, platform-appropriate input and layout.
2. Saves carried between devices: cloud sync, or export/import of a save file.
Both are possible; 2 adds a service or a file-transfer flow and is the larger job.

### Facts
- `export_presets.cfg` has Android Debug and Windows Desktop only; a Web preset is new.
- Godot 4.7 web export needs threads (the host must send the SharedArrayBuffer headers: COOP/COEP) or a single-threaded build; audio, `user://` saves in IndexedDB.
- Native phone numbers (item 31) remain separate; a web build adds its own frame-time and loading checks.

### Acceptance
- The web build is playable through a full season in Chrome on Android and on desktop, with saves surviving a reload.
- Android, Windows and web builds from one commit show the same content and version string.
- The synchronised definition chosen by the director is met and recorded here with the PR.

---
