## ARD-M6-005 — Options / settings
**Status:** `DONE` — core Settings merged in #86; light/dark appearance and the safe New career action merged in PR #205. _(reconciled 2026-10-05)_  
**Merged:** PR #86 as `ebc570d`; one Settings sheet serves the menu and career hub, with relevant current options and destructive-action confirmation.  
**Priority:** `P1`  
**Autonomy:** `SAFE`

### Follow-up (2026-10-02, PR #205)
- Dark / Light is now a real persisted shared-palette choice; changing it rebuilds the current screen immediately.
- Light mode uses warm neutral paper/ink colours while club colours and the football ground remain unchanged.
- Career Settings adds **New career**. It opens setup without deleting the existing save; the existing replacement confirmation remains the destructive gate, so backing out can still resume the save.
- Delete this career retains its explicit confirmation and uses the shared danger treatment.
- **Mute sounds** persists and mutes Godot's Master audio bus, so incoming music and SFX automatically honour it.
- UI scale and reduced motion remain out until they have real systems to control.

### Implementation record (2026-09-28, branch `claude/options`)
- **One Settings sheet** (`scripts/ui/OptionsSheet.gd`), opened from the main menu (Settings) and from a new top-right Settings on the hub. It holds:
  - player names;
  - confirm before simming a round;
  - match speed (new: 1x, 2x, 4x or 8x, the speed a watched match starts at, default 4x);
  - the version.
- **In a career it also has:**
  - Main menu (saves, then returns);
  - Delete this career. It asks first ("This deletes your saved career for good. It cannot be undone.", with Keep it / Delete career), then removes the save and returns to the menu.
  - Quit game stays on the menu's sheet (desktop only).
  - Back closes the sheet.
- **Originally left out:** light/dark, audio, UI scale and reduced motion. PR #205 now adds light/dark and the now-relevant global Mute sounds control; UI scale and reduced motion remain out until they have real systems to control.
- **Also fixed:** the hub's four-button bottom row cut "Sim round" short at 360 px. Below 380 px it uses 13 px type and tighter padding.
- **Tests:** `run_career_ui_tests.gd` covers:
  - Settings on the hub's top bar;
  - speed, main menu and version present;
  - speed remembered;
  - Keep it cancels;
  - delete asks first, removes the save and returns to the menu.
  - The existing menu Settings checks still pass.
- **Screens:** hub and Settings at 360 and 390 px reviewed.

Accessible top-right/main-hub Options.

Include as relevant:
- return to main menu,
- dark/light/system,
- visualisation speed/default mode,
- confirm-before-sim setting,
- audio once available,
- reduced motion,
- UI scale,
- help/about/version,
- New Game,
- Delete Save.

Destructive actions require clear confirmation.


**User-requested follow-up — TODO (2026-10-06):** For now, **real names are the default**, rather than generated/fictive aliases for real players, when no name-display preference exists. Keep fictive names opt-in and preserve saved choices. Generated future players keep their generated names; custom prospects keep their entered names. Verify fresh/default settings and save/load. The existing Settings foundation remains DONE. **Status (2026-10-06):** built in the real-names PR. `GameState.show_real_names` now defaults to true, both as the variable and in the settings read. The `real_names` key is written only when the player chooses, so no key means no choice; a saved choice of generated names is kept, and New Career's setup, Settings, the in-game help, the README and DESIGN all follow the new default. Generated players have no real name and keep theirs; custom prospects are not built yet. `test_league` covers a fresh game, a settings file with no name choice, a saved generated choice kept across a restart, choosing real again, and generated players keeping their names. The README had described fictional-by-default as a legal-presentation choice; it now says real by default "for now" and the legal side stays the director's.

---

