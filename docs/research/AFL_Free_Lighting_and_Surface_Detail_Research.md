# Free lighting and surface-detail options for AFL art

Research: 6 October 2026. Documentation and source inspection only; no assets regenerated, software installed or visual treatment implemented. This extends ARD-M8-007's existing art and scene-dressing work. It preserves the 2D/2.5D game, art-agent direction and director's final appearance gate.

## Existing pipeline and limitations

The inspected local ard-asset-pipeline uses MPFB/Blender bodies, EEVEE renders and packed sprite sheets. The shade pass already differentiates roughness: boots 0.35, skin 0.55 and other regions 0.75. Lighting uses a flat grey world and a camera-relative sun. Cast sun shadows are explicitly disabled because grazing limbs produced shadow acne. The exact Blender version and active art branch must be verified before implementing API/settings changes.

The game shader consumes figures_shade.R as a single lighting multiplier, with the remaining channels and accompanying masks/design maps carrying semantic data. This is not a conventional diffuse/PBR texture set. Adding colourful albedo files, HDRI colour or a normal map will not automatically integrate correctly. StoppageVignette already draws a flattened ground shadow that responds to lift: improve or reuse it where needed, rather than claiming contact shadows are entirely absent.

## Recommended order

1. Compare improved offline lighting with the current result on a small representative sprite/scene set.
2. Add restrained, region-specific material detail that survives phone-scale rendering.
3. Improve environmental materials and coherent contact/scene lighting.
4. Evaluate runtime normal/specular lighting only if the cheaper baked approach leaves a meaningful gap.

### 1. Better offline lighting, with Blender already in the pipeline

Prototype a softer key/fill setup and, separately, a free HDRI-assisted setup. Aim for clearer body volume, believable fabric/skin/boot separation and consistent actor/background illumination. Keep contrast usable for dark and light guernseys, skin tones and the ball. Compare EEVEE with a small Cycles reference where useful; a slower offline reference may help diagnose quality without requiring a new runtime renderer.

A baked improvement primarily spends asset-production time, but atlas count/size and runtime handling still need measurement. Do not assume it is costless. Keep the current colour/data-pass conventions intact, and isolate any proposed colour-management change from mask or coordinate data.

Blender supports environment-image lighting and bump detail. Retrieved official manual excerpts explain the mechanism; full page opens were unavailable during this pass, so exact installed-version settings require local verification. [Environment lighting](https://docs.blender.org/manual/en/3.6/render/lights/world.html), [Bump node](https://docs.blender.org/manual/en/latest/render/shader_nodes/displacement/bump.html).

### 2. Surface detail that follows the asset

Use Blender's existing procedural nodes first: subtle fabric relief/roughness variation, boot finish, restrained skin variation and hair separation. Do not apply uniform grain to all materials. At small scale, seams, broad folds, controlled highlights and contact shading may communicate more than tiny pores or weave.

Texture coordinates must follow the body or garment, not screen position. Inspect a full moving cycle for swimming patterns, aliasing, shimmer and seams. Skin detail must not alter a player's curated identity. Preserve club recolouring, guernsey patterns and numbers.

Because the current shade channel is grayscale, baked colour variation requires deliberate handling in region-aware shader colour or a separately specified map. Do not overwrite mask/data channels or multiply already-baked shadows again. Produce a material/channel contract before changing the atlas format.

### 3. Free sources and authoring tools

| Option | Useful role | Cost/constraint |
|---|---|---|
| Blender, already used | Procedural material nodes, lighting and offline renders | Start here; no additional tool required |
| Poly Haven | HDRIs and material maps for fabric, ground and furnishings | Asset downloads are CC0, including commercial use; paid conveniences are unnecessary |
| ambientCG | Material maps for cloth, wood, concrete, flooring and ground | Downloadable assets are CC0; select and simplify to fit the approved style |
| Material Maker | Optional repeatable procedural material recipes | Official itch.io release is name-your-own-price, allowing a zero-cost download; export static textures for the existing pipeline |
| Krita, optional | Authored texture/height detail and hand-painted normal maps | Useful where artistic control is preferable to automatically inferred relief |

Sources: [Poly Haven licence](https://polyhaven.com/license), [ambientCG licence](https://docs.ambientcg.com/license/), [Material Maker official download](https://rodzilla.itch.io/material-maker), [Krita normal-map painting](https://docs.krita.org/en/reference_manual/brushes/brush_engines/tangen_normal_brush_engine.html).

Use individual free downloads, with a source/asset-ID/license record and chosen scale/settings. Neither a paid library subscription nor a paid integration is needed. Check community-material licences individually; Material Maker's software being open source does not make every third-party material automatically CC0. Retain procedural recipes and source files, not only flattened exports.

### 4. Environment surfaces and lighting

Extend the existing scene-dressing owner: grass/soil, curtains, tables, chairs, walls, flooring and relevant foreground props. Build a small consistent material set rather than photorealistic textures everywhere. Align light direction, contrast, shadow softness and exposure between characters and their setting. Include restrained table/foot contact shading and depth cues around furniture where they improve grounding.

For code-drawn scenery, use modest reusable textures or carefully controlled procedural detail only where beneficial. An offline rendered background/prop plate is another option. These are alternatives to compare, not a requirement to replace every drawing primitive or introduce live 3D rooms.

### 5. Runtime 2D lighting: optional experiment

Godot supports 2D normal/specular lighting and CanvasTexture, including relevant Control-node paths. Additive light sprites are a cheaper alternative for some effects. The existing custom packed-data shader needs a deliberate adapter or separate rendering path; it is not enough to assign an ordinary material texture. Avoid double lighting the baked shade pass. Check light isolation from text/UI, flips/facings, frame alignment and actual mobile-renderer behaviour. [Godot lighting documentation](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html).

Prefer geometry-derived per-frame normals if accurate moving-figure relighting is necessary. Automatically estimating height from colour can mistake a dark guernsey stripe for a groove; masks and packed coordinate channels are unsuitable colour inputs. Adding normal/specular atlases increases memory and production complexity, so measure before expanding.

**Free-tool correction:** Godot's documentation still links Laigter as a free/open-source helper, but the current developer page states that its binaries are paid. Do not make those binaries a dependency. Source compilation is an optional engineering task, not a frictionless free download; Blender/Krita/manual maps remain alternatives. [Current Laigter page](https://azagaya.itch.io/laigter).

## Smallest reviewable prototype

Use one standing and one moving footballer, multiple facings, a light and dark club kit, representative skin/hair tones, plus one existing outdoor and one awards/press setting. Preserve the baseline. Change lighting first, detail second, then show the combined result so the director can attribute improvements.

Capture fixed-state before/after phone-scale stills and short motion at the existing 320/360/430-width gates. Record loaded assets and channel layout. Examine silhouette, club/number legibility, ball/action/UI clarity, contact shadows, compression and animation shimmer. Record offline build time, atlas dimensions/count, estimated or measured decoded texture memory, load time, draw calls and representative real-time frame time. PNG file size alone is not texture memory; a smooth offline film does not prove phone performance.

The art agent should recommend the restrained treatment and present the comparison to the director. No whole-roster regeneration or global rollout before a representative approved result. Reuse existing capture/check infrastructure. Final appearance, validation and main-merge evidence are necessary before marking implementation DONE.
