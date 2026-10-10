## ARD-M8-008 — Cross-platform app identity and icon redesign
**Status:** `PARTIAL` — Android identity foundation merged in PR #173; installed name/icon still needs verification. **New all-platform icon redesign: TODO (director request, 2026-10-06).**  
**Priority:** `P1` — follows urgent P0 usability repairs.  
**Autonomy:** `SUPERVISED` — art agent leads; director approves the final icon.

### Goal
Every supported platform's packaged application/executable and launcher icon must use a coherent **Aussie Rules Dynasties** identity. Replace the existing placeholder/icon treatment with a purpose-built icon in the director's supplied logo style.

### Director's visual reference — 2026-10-06
Reference image: `codex-clipboard-cafc14a1-721a-458a-bc79-c0000e778e1f.png`. Match its recognisable visual language: bold condensed cream/off-white block lettering, energetic red brush-script accent, and very dark background. Adapt that identity for an icon rather than squeezing the wide title artwork into a square.

- Prefer the full title only where it is genuinely readable. **“ARD” is explicitly authorised as the compact icon lettering if the full name will not fit/read well.** Abbreviation affects the icon artwork, not the installed app's full name.
- Make icon-scale variants from one coherent master treatment. Simplify texture/detail as needed so the letters remain recognisable at small launcher/taskbar sizes and within platform masks/crops.
- Cover all supported exports: Windows EXE/file/shortcut/taskbar icon, macOS app/Dock icon, Linux launcher icon, Android launcher/adaptive icon, iOS app icon and web favicon/install icon where those builds are supported. Update actual export/package metadata and platform assets, not just the in-game title image or project editor preview.
- Reuse the established logo/style and usable fonts/assets; do not redesign the full in-game title or introduce a competing branding system. Preserve the existing save location/project identity when updating visible branding.

### Acceptance and validation
- Installed app name remains **Aussie Rules Dynasties**; remove remaining visible legacy **AFL Auto-Battler** branding where applicable.
- The redesigned icon is visibly related to the supplied reference, readable at native small sizes, and consistently used by packaged builds across supported platforms.
- Inspect the built Windows EXE plus shortcut/taskbar and available installed platform builds, not only source assets. Check small/large sizes, dark/light launcher surfaces and adaptive rounded/circular crops; handle OS icon caching during verification.
- Provide icon-scale previews of full-title versus ARD candidates to the director. Art-agent direction and final director approval are required before marking the redesign DONE.
- Keep the existing Android name/launcher verification open until an installed phone build confirms it.

---

