# A 3D animation plan for the match, learnt from AFL Live 2004

_Proposal of 2026-11-14, not a ruling. Director: "i dont want to use their anims, i want you to learn
how they did it though, so we can improve it"; then "im thinking of completely overhauling the visual
elements of the game ... how could we use these learnings to produce great animation for a full 3D
sim?" None of their motion data is used or shipped. Adopting this plan would reverse ARD-M8-007
("Do not introduce 3D player models"); that is the director's decision to record._

## 1. What AFL Live 2004 did (measured)

Sources: `GRAPHICS/ACTOR/ANIMATIONS/ANIMS_TEN_BIT.FLAT` (4.8 MB, every animation in one binary bank),
the player model `PLAYER_LOD_1.DFF` (RenderWare) and the clip paths in `AFL2004.exe`.

| Fact | Value |
|---|---|
| Clips | 310: 299 full body, 9 upper-body layers, 2 head layers |
| Skeleton | one, 31 bones, shared by every player and umpire |
| Key rate | 25 a second |
| Rotation | 32 bits: three 10-bit parts with the fourth rebuilt, ~0.16 degrees a step |
| Hips | position and rotation in full floats every frame |
| Still bones | no keys at all |
| Model detail levels | 6 per player |
| Longest clip | 12.3 s |

| Family | Clips | Pattern |
|---|---|---|
| Tackles | 75 | 5 approach directions × tackler and tackled × outcome (start, caught, shrugged off, spilled, disposed, taken to ground, recovery) |
| Getting around | 64 | stand, walk, jog, run, sprint, side-step, walk back, run back; with and without the ball |
| Marks | 38 | 7 speckies and 6 dropped versions; chest, dive, leading, turning 180 |
| Ruck and contests | 30 | taps three ways, grabs, jostles, wrestles |
| Idle, reactions, ceremony | 24 | 8 idles, fist pump, head shake, disappointment, coin toss, bench |
| Umpires | 23 | every signal, bounce, throw-up, ball-up |
| Kicks | 14 | quick, medium, long, torpedo, snap, banana, soccer, set-shot run-up |
| Gathers | 12 | standing and running, turning 90 and 180 |
| Handballs | 10 | quick, long, fake |
| Bumps and spoils | 10 | bump, falls front, back and side, punching the ball away |
| Player layers | 7 | reaching high and chest-high, square and side-on; trunk twist; head turn |

Their four ideas:

1. **A move is named by where it starts and ends.** 91 clips read `start_move_end`: a kick from a
   standstill and a kick on the run are different clips, so legs never pop between gaits.
2. **Turns plant and turn.** 32 clips turn the body 30, 90 or 180 degrees through a foot plant.
3. **Contests are pairs that branch on the result.** Both players start together, then play the
   outcome the match engine decided.
4. **Every mark has a miss.** A dropped mark looks like a drop.

What limited them was 2004 hardware: no warping, no runtime IK, baked layers. Everything they could
not do at runtime they covered with more clips. A modern engine does much of it live, so the
same quality needs fewer clips and fits the sim more exactly.

## 2. The plan

### 2.1 The sim owns where and when

MatchSim decides every event; the animation never changes a football outcome. Each event that reaches
the view carries **who, what, where, when and the result**: "Player 14, drop punt, at (x, y), contact
at t, ball to (x2, y2), result: goal". The view chooses a clip from the player's current gait. It then
**warps** the clip in time and space, so the contact marker lands on the sim's spot at the sim's moment.

- Every action clip carries markers: foot plants, ball contact, ball release, mark secured, tackle
  contact.
- Warping stretches the run-in, never the contact frames. A clip warped past its limits is the wrong
  clip, and the view chooses another one.
- Godot has no built-in motion warping; it is a custom root-motion correction (a `SkeletonModifier3D`
  plus root-motion scaling) and the first engineering risk in the proof (§2.10).

### 2.2 Getting around: a blend space plus starts, stops and turns

- A speed × direction blend space (`AnimationTree` `BlendSpace2D`). Cycles: walk, jog, run, sprint,
  backpedal and side-step, each with and without the ball. That is about 12 cycles, against their 64 clips.
- Start, stop and plant-and-turn clips (90 and 180) at walk, jog and run, entered on the right foot.
- Playback rate comes from the speed MatchMotion gives the player, so strides match the ground covered.
- Foot locking: a planted foot is pinned to the turf by IK until it lifts, so nothing slides.
- **Later, not now:** motion matching (searching a capture library every frame for the best next pose)
  gives the most natural movement, but it needs a large capture library and more CPU than a phone
  spares for 45 figures. Revisit after the proof.

### 2.3 Actions state their entry and exit

Every kick, handball, gather, bounce and mark is authored as `entry_move_exit` (stand or run in, stand
or run out) with its lead foot or hand recorded. The view chooses the version matching the player's gait
and the phase of his stride, so a run flows into a drop punt and out again. Right- and left-footers
are separate clips or a mirror that also swaps the kicking leg, never a mirror that gives a right-footer
his left foot.

### 2.4 Contests are pairs that branch on the result

Tackles, bumps, ruck contests and one-on-one marks are captured with two people in one shared space.

1. **Align:** in the last few frames before contact, both players are warped onto the pair's starting
   spacing.
2. **Angle:** 3 approach directions (front, side, behind) are captured. Warping covers the angles
   between, where they needed 5.
3. **Branch:** the pair shares its start and splits at contact into the result MatchSim decided:
   holding the ball, held to a ball-up, fended off, stepped out of it, ball knocked loose.

### 2.5 Every success has its failure

A specky has its spill, a chest mark its fumble, a gather its knock-on, a kick its shank, a handball
its fumble. The design bible asks that the game shows what each decision led to; a dropped mark has to
look like a drop.

### 2.6 Live layers and IK replace baked variants

- **Look:** the head and eyes track the ball (a look-at modifier on the neck and head).
- **Reach:** the upper body reaches for the ball as a masked layer over the running legs (blend with
  a bone filter).
- **Hands and boot:** two-bone IK puts the palms on the ball and the boot through it in the final
  centimetres.
- **The ball:** attached to the hand bones from gather to release and to the boot at contact, then
  handed to the sim's flight. It never hovers.

### 2.7 Everyone on the ground is alive

36 players and 9 umpires (3 field, 4 boundary, 2 goal). At least 6 idle variants with different start
times; reactions after goals, frees and dropped marks; the umpire's full signal set; set-ups at every
stoppage. Nobody stands identically to the player next to him.

### 2.8 Phone budget and detail levels

An Android phone in portrait is the reference. 45 skinned figures is the main performance risk.

| Distance on screen | Model | Animation |
|---|---|---|
| Near (the ball's contest) | full | full rate, IK, layers, warping |
| Middle | reduced | every second frame, no IK or layers |
| Far | lowest | animation baked into a texture and played by the shader, no skeleton |

The frame-time budget is set from measurement in the proof, not guessed.

### 2.9 The clip list and where it comes from

| Family | Clips (estimate) | Source |
|---|---|---|
| Getting around (cycles, starts, stops, turns) | 40 | a licensed library, retargeted |
| Kicks (drop punt, snap, torpedo, grubber, set shot, each run and stand) | 20 | our own capture |
| Handballs and bounce on the run | 12 | our own capture |
| Gathers and pick-ups | 12 | our own capture |
| Marks and their drops | 24 | our own capture |
| Tackle, bump and spoil pairs, with branches | 30 | our own capture, two people |
| Ruck contests | 12 | our own capture |
| Idles and reactions | 16 | a library plus capture |
| Umpires | 20 | our own capture against the umpiring rules |
| **Total** | **about 186** | |

AFL moves have no library source: text-to-motion fails on them, and generic libraries carry soccer
kicks. They come from capture of real footballers, cleaned in Cascadeur (its spend is a yes), and every
clip is checked frame by frame against real footage before the director sees it.

### 2.10 The proof first

One full-team passage on the 3D oval: centre bounce (or throw-up), ruck tap, gather, handball, kick,
contested mark, with all 36 players and the umpires alive.

It passes when:
- it holds a steady frame rate on the reference Android phone, measured, with the frame-time split
  between animation, skinning and drawing;
- every contact lands on MatchSim's spot and time (logged positions against the sim's event log);
- no foot slides, no ball hovers, and no limb clips through a body or a jumper, checked frame by frame;
- the director watches it at game speed and says it reads as footy.

The phone frame time is measured first, with the mock's 36 bodies on jog, idle and carry, before any
action clip is made: it sets the budget for IK and layers. If the phone cannot hold it, the plan changes before any more art is made.

### 2.11 Engine notes from the 3D oval mock

Found while building the mock in the 3d view 1 session (2026-11-14):

- **Blender export.** Bake each action with NLA off (`use_nla = False`): an earlier strip corrupts key 0.
  Turn NLA back on for the GLB export, and check that a cycle's first key equals its last.
- **AnimationPlayer in manual mode** needs `advance(1e-4)`, not `advance(0)`, to apply the first pose.
- **Kit colours.** The guernsey regions go in vertex COLOR and the hair in UV2.x, thresholded at 0.5 with
  `fwidth`; one material per side.
- **Shadows.** Soft shadows at default quality stipple the limbs; SOFT_HIGH with a 4096 atlas fixes it on
  PC. Its phone cost is part of the frame-time measurement.

The contract between the two sessions: the MPFB game_engine rig from `player_average.glb` with its bone names
unchanged; one GLB action per clip; `Oval3D.anim_for(token_index, event)` is the hook the animation
controller replaces. The 3d view 1 session decides when it is called and where each player stands.

## 3. The director's decisions (2026-11-14, rule 2.74)

1. Reverse ARD-M8-007 and move the match view to 3D players: "Yes, prove it first".
2. The proof in §2.10 comes before anything else in the overhaul; the two sessions work on it together
   ("Work hand in hand with 3d view 1").
3. Capture: "Free mocap service", a markerless tool that turns our own video into 3D motion. He creates
   the account; footage of real matches is for study only.
