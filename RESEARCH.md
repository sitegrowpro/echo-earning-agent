# How Fears to Fathom was actually built — research brief (and our build map)

11 screenshots viewed, engine + design + graphics researched Sept 2026.
This doc is the single source of truth for "what makes F2F *feel* like F2F".

## 1. How Rayll actually made it

- **Solo dev, Unity engine.** Fears to Fathom is made by Indian developer Mukul Negi
  ("Rayll"), episodic anthology of allegedly-real stories submitted by players.
  [3](https://en.wikipedia.org/wiki/Fears_to_Fathom)
- **Asset-driven workflow.** Small team/soloUnity horror = store-bought systems +
  custom content. The community has identified the VHS look as coming from a
  fullscreen-camera-effects asset (VHS Pro style: grain + chromatic aberration +
  lens distortion + tracking).
  [1](https://www.reddit.com/r/Unity3D/comments/13shhuh/fears_to_fathom_camera_effect/)
  [3](https://forums.unrealengine.com/t/how-i-can-create-an-atmosphere-in-the-style-of-fears-to-fathom/2105593)
- **Low-poly Blender models + low-res diffuse-only textures** (128px, point/no
  filtering), fog, desaturated color, low render resolution. No normal maps,
  no fancy materials — texture + lighting does all the work.
  [4](https://www.reddit.com/r/Unity3D/comments/123vw54/working_on_a_small_ps1_style_horror_game_what_do/)
  [5](https://www.reddit.com/r/Unity3D/comments/14xooku/how_do_i_make_a_game_look_like_a_ps1_game/)
- **"Based on a true story" framing** is part of the product: every episode opens
  claiming to be a real submitted story. The belief *is* a mechanic.

## 2. Mechanics anatomy (what the loop really is)

- **Mundane → dread → survive.** 60-70% of an episode is ordinary chores in an
  ordinary space (cook, clean, TV, texts). Horror comes from *recognition*, not
  monsters. Small choices and attention to detail determine survival; minimal UI.
  [1](https://gamarplay.com/fears-to-fathom/)
- **The phone is a second screen.** Story arrives as texts/calls/photos; the
  briefing, the scares, and the 911 call all live there. No quest markers.
- **Silence is a weapon.** Sudden absence of sound (rain stops, TV cuts, hum dies)
  scares more than stingers. Players navigate by hearing as much as sight.
  [2](https://crazygamesinfo.com/fears-to-fathom/)
- **Subtle environmental changes.** Doors you closed are open, objects moved,
  lights behaving wrong. The house gaslights you before the intruder arrives.
- **No combat, ever.** Vulnerability + resource pressure (flashlight battery, time,
  noise) + disempowerment. Research confirms anticipation, sound, lighting and
  scarcity beat jump scares every time.
  [4](https://www.ijcrt.org/papers/IJCRT25A5479.pdf)
- **Later episodes add:** driving, fishing, deeper NPC conversation, co-op with
  proximity voice chat, "player voice activity" (mic as input!).
  [3](https://the-indie-horror-game-world.fandom.com/wiki/Fears_to_Fathom_(2021))

## 3. Graphics recipe (from 11 reference screenshots)

1. **Near-black interiors**, isolated warm lamp pools (ceiling lamp, TV glow, lamp).
   Hallways navigated by slivers of light under doors.
2. **Blue-orange dusk outside every window/door** — interiors are warm-dark,
   exteriors cold-dusk. Maximum contrast at thresholds (open door = composed shot).
3. **Lit windows in distant dark houses**, fences, trees, wet ground catching light.
4. **Post:** heavy grain, chromatic aberration, lens distortion, tracking tears,
   vignette, timestamp. The camera is a camcorder, not an eye.
5. **Dialog = bottom subtitles + small-caps choice list**, NPC facing you, warm
   practicals. No centered RPG panels.
6. Clutter sells realism: ceiling fans, blinds, brick, framed family photos,
   curtains, mugs, remotes, papers.

## 4. Godot mapping (our implementation)

| F2F element | Status in our build |
|---|---|
| Unity low-poly + 128px point textures | HALF — models procedural ✓, textures flat colors → **procedural ImageTextures next** |
| VHS Pro (grain/CA/distortion/tracking) | HALF — overlay grain/track/vignette ✓ → **true screen-space shader next** |
| Dusk sky + dark interiors + bloom | DONE (visual pass 1: ProceduralSky, ACES, glow, SSAO, fog) |
| Phone-as-second-screen | DONE (3 threads, calls, photos, 911) |
| Chores → dread → survive + 4 endings | DONE (7 chapters, choices matter) |
| Mic-as-input (voice activity) | DONE (real mic stealth + mute) |
| Silence events | HALF — rain stops ✓ → **ticking clock that stops, hum death** |
| House gaslighting (moved objects) | TODO — **dread director micro-events** |
| Attention → survival | TODO — **notes-found rewards (back-window warning)** |
| True-story framing card | TODO — **intro card: "as told by Jamie K."** |
| Door light-seep | TODO — **emissive strips tied to room lights** |
| Bottom-subtitle dialog | TODO — **restyle dialog panel** |
| Geometry detail (fixtures/clutter) | TODO — **pass 2: lamps, baseboards, fans, curtains, distant houses** |

## 5. Build order (risk-managed, testable in slices)

- **P2a — True VHS:** move overlay under UI (layer 0), screen-sampling shader
  (barrel distortion + CA + roll-bar displacement + grain + scanlines + vignette).
- **P2b — Surfaces:** `tex.gd` procedural 64–128px textures (wood/tile/carpet/
  drywall/asphalt/grass/deck/ceiling), NEAREST filtering, uv1 tiling.
- **P2c — Dread systems:** light-seep door strips, ticking clock + stop event,
  dread-director micro-events (5 scripted object changes), notes→warning reward,
  true-story intro card, dialog restyle to bottom subtitles.
- **P2d — Geometry:** lamp fixtures, baseboards, ceiling fans, curtains + blinds,
  kitchen/bathroom/laundry dressing, distant houses with lit windows, wet streaks.
