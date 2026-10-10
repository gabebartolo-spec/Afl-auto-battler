# Figure pipeline review: is MPFB right for us? (2026-10-10)

Director: "rigorously investigate whether MPFB is right for our project, so far it's proven to create
some pretty bizarre animations and aberrations", then the modular idea: player skeletons wearing
generated parts (jumpers, haircuts, faces, accessories, scars and tattoos, heights and builds), "a
makeup bag to create hundreds of unique players". Evidence: ANIMATION_PIPELINE_PROPOSAL.md (§4, §7),
art-qa-critic learnings, ART's style board (agent-handoffs/art/style/, 2026-10-10), the web sources below.

## Verdict
- **MPFB is not the cause of the bizarre motion.** MPFB supplies the body mesh and the `game_engine`
  rig. Every move is keyed by hand in our `poses.py` from written descriptions, with no motion
  capture. The six measured motion defects are pose and timing faults: hands 0.4 m above the ball,
  a flat-footed run, the walk shuffle, a hovering foot, 0.08 s ball drops, strides 2.7x the ground
  covered. So are the defects caught by eye: claw hands (stacked finger curls), an arm rooted in the
  torso (a retarget without the clavicle), and the floating chaired rider.
- **MPFB is a sound base for the skeleton and body.** It's CC0, so commercial and closed source is
  fine. It's parametric (age, build, height, face shape as shape keys), so outputs are deterministic
  and diverse. It's maintained (2.0.16, June 2026, with an expressions workflow and Rigify). Its 124
  pack assets were checked CC0 by ART.
- **What looks wrong is our finish, not MPFB.** Today's figures render with flat shading, no face, 5
  overlay hairstyles (16 defined), boots painted on, stiff open hands and tight shorts. ART's
  upgraded sample adds a face, skin detail and hair cards. At game scale it's still plain, and two
  defects are visible (floating hair cards, toes showing through the painted boot).

## The director's modular plan, mapped to our engine
It fits: the game already draws hair as overlay sheets rendered on the same poses as the body. The
"makeup bag" is that principle extended. Parts are rendered once on the shared rig, and players are
combined at draw time, so 20-30 parts give hundreds of distinct players.

| Part | Source | Notes |
|---|---|---|
| Skeleton, height, build | MPFB `game_engine` rig and modifiers | 3-4 builds plus height and musculature morphs |
| Face | MPFB face shape keys, skin, eyes, brows | deterministic, no generation defects; a head overlay per face set |
| Haircuts (11 missing), beards | Blender hair cards, or Tripo hair meshes fitted to the scalp | must sit on the scalp in every frame (today's sample floats) |
| Guernsey, shorts | modelled once, cloth folds | keeps per-club recolour masks; a Tripo jumper's baked texture can't be recoloured, so use Tripo for shape only |
| Boots | a boot mesh (Tripo or modelled) | replaces painted-on boots |
| Accessories: headband, tape, bandage, mouthguard | Tripo props, five-view inspected | small overlays |
| Tattoos, scars | texture decals in the shade pass | sleeve tattoos are common in the AFL |

Cost and risk: every overlay sheet adds GPU memory (the set was about 19.5 MB at #284), so measure it
and check on the director's phone. Every part must be rendered on the same poses and in the same
draw order (hair against a raised arm). Every generated part is inspected from five views. One
shading for all parts (one-style rule).

## Motion: the actual problem
Replace hand-keyed poses with reference motion, retargeted onto the frozen rig with the clavicle fix:
- **Locomotion** (run, jog, walk): Mixamo (free; commercial use inside a game; no raw-file
  redistribution) or CMU mocap (licence reported inconsistently: confirm before use; needs cleanup).
- **AFL moves** (drop punt, handball, mark, gather): our own two-angle phone video, with MediaPipe
  (Apache-2.0) for timing and keys. Text-to-motion failed (Tripo, 60 credits, empty hands).
- **Cleanup aid:** Cascadeur Indie (paid; under US$100k revenue). Its free tier is non-commercial,
  so it needs a spend decision.

## Alternatives checked
| Option | Licence | Fit |
|---|---|---|
| CharMorph | GPL code; CC0 or CC-BY models | fewer assets and rigs than MPFB; no gain |
| Blender Studio human base meshes | CC0, no rig | sculpt bases, not a pipeline |
| MetaHuman | free under US$1M revenue, any engine | far beyond sprite scale; heavy; the Blender DNA tool is beta |
| Character Creator 5 | paid; per-character game terms | spend plus licence review; not free |
| Human Generator | paid (~US$68-128) | Blender only; paid |
| Tripo whole people | paid credits | 3 of 7 rejected tonight (missing leg, mismatched eyes); cartoon style; no recolour masks |

## Recommendation
Keep MPFB as the skeleton and body. Build the director's modular kit on it: faces from MPFB, and
hair, boots, accessories and garment shapes from Tripo or modelling, all re-shaded in our pipeline.
Fix motion at its source with reference motion. First proof: three visibly different players (face,
hair, build, boots, one accessory) at game scale and 2x, beside today's, plus a reference-driven run
as a clip.

Sources: [MPFB on Blender extensions](https://extensions.blender.org/add-ons/mpfb/) ·
[CGChannel on MPFB 2](https://www.cgchannel.com/2025/03/check-out-open-source-blender-character-generation-plugin-mpfb-2) ·
[MetaHuman licence](https://www.metahuman.com/en-US/license) ·
[CharMorph docs](https://charmorph-docs.readthedocs.io/en/main/) ·
[Blender asset bundles](https://www.blender.org/download/demo-files/) ·
[Cascadeur licensing FAQ](https://cascadeur.com/blog/general/cascadeurs-new-licensing-structure-comprehensive-faq) ·
[Mixamo FAQ thread](https://community.adobe.com/questions-696/mixamo-faq-licensing-royalties-ownership-eula-and-tos-589400) ·
[Reallusion content EULA](https://reallusion.com/Content/EULA/EULA.htm) ·
[Tripo segmentation](https://help.scenario.com/articles/9861107995-tripo-segmentation-the-essentials).
