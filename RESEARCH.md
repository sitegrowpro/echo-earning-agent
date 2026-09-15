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
| Unity low-poly + 128px point textures | DONE — tex.gd: 9 procedural surfaces, NEAREST, world-triplanar |
| VHS Pro (grain/CA/distortion/tracking) | DONE — true screen-space shader (barrel + CA + roll-bar displacement) |
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
| Camera zoom + look-at on NPC talk | TODO — recreation code shows talk = zoom camera + IK look-at + typewriter |
| Subliminal glimpse scares | TODO — black figure at frame edge for a fraction of a second |
| Checkpoint-only autosave | DIFFERS — F2F has no manual saves; death → checkpoint. Consider aligning |

## 6. How it was coded (dev process + code architecture)

### The developer
- Mukul Negi / Rayll: gamedev since age 13 (2015), lo-fi art lover, solo in his
  bedroom — "there is no team (yet)". Only other credit: composer Nathan Hall.
  [4](https://www.sportskeeda.com/esports/news-rayll-creating-fears-fathom-series)
- Almost shelved episode 1; believes devs can't judge their own games → playtest.
  Stayed motivated watching YouTube let's-plays.
  [1](https://in.ign.com/fears-to-fathom-home-alone/197767/news/games-made-in-india-rayll-studios-founder-talks-about-fears-to-fathom-the-hit-horror-video-game)
- Stories crowdsourced via an email address ON THE TITLE SCREEN (132 submissions;
  ep1 inspired by Mr. Nightmare's real-horror channel). Relatability = the hook:
  "home invasion is such a common fear that can happen to anyone."
  [3](https://www.inverse.com/input/gaming/mukul-negi-rayll-fears-to-fathom-home-alone-norwood-hitchhike)

### His stated design rules (direct quotes, Sportskeeda interview)
- **Never monsters:** "I doubt you'll ever see some monsters chasing you in a
  Fears to Fathom game, as I feel it breaks the reality factor." Human threat only.
- **Subliminal glimpses:** the core scare is "a black human figure at the corner
  of the frame" for a fraction of a second — "something I wasn't meant to see."
- **VHS = liminal feeling:** "mostly subliminal... it really resonated with the
  liminal feeling I wanted it to give off."
- **Future = more isolation** (+ a co-op episode, which became Scratch Creek).

### The interaction/dialog code pattern (from a real recreation project)
The community's F2F recreation codes every NPC talk the same way — this is the
canonical shape, and ours already matches it except the camera zoom:
[repo](https://github.com/BATPANn/FearsToFathom-DialogSystem-Part-5)
1. Per-frame raycast from camera center (~5m) → tag check → prompt text ("Talk To Him")
2. `E` → disable FPS controller, enable NPC zoom camera, NPC look-at IK at player
3. Typewriter subtitle lines + talk sound, click/E to advance
4. Choice buttons → one coroutine per choice → restore controller/camera
- General consensus: raycast + `IInteractable` interface (Interact/Select/Deselect),
  interactables on their own collision channel; big objects may use trigger volumes.
  [2](https://www.reddit.com/r/unity/comments/1hav9wc/handle_interactions_between_playerobjects/)

### Objective/event architecture (standard pattern behind these games)
- Central **Quest/Objective manager** (singleton): AddQuest / UpdateObjective /
  CompleteQuest; trigger volumes, pickups and dialogue call into it; UI listens
  to its update events. Quest state kept as plain data, not objects.
  [1](https://medium.com/object-oriented-worlds/implementing-quest-systems-in-ue5-blueprints-47ea0ac00599)
- Our `main.gd` (chapter machine + `story` flags + triggers calling in) is exactly
  this pattern in Godot form. No re-architecture needed.

### Choice → ending design (Scratch Creek + ep1/ep2 guides)
- **Navigation choices → safe alternate endings** (follow GPS vs flipped sign).
- **Dialogue choices → NPC disposition → death branches** ("be socially aware of
  your answers towards NPCs").
- **Brutally specific survival rules**, fair-if-attentive: hide under the bed,
  NOT the wardrobe (intruder checks wardrobe first); don't open the bathroom door;
  coffin room, not church; unhook the trailer or the car dies.
  [2](https://fearstofathomscratchcreek.com/completion/fears-to-fathom-scratch-creek-all-endings)
  [5](https://steamcommunity.com/sharedfiles/filedetails/?id=3018507801)
- **Trigger-gated progression:** police won't arrive until you trigger the door;
  sirens = safe; serene music = win state. Event flags, not timers.
- **The killer hears your real microphone** (ep2 motel) — mic-as-input is canon F2F.
- **Co-op rules** (Scratch Creek): screen darkening + audio cues when apart;
  simultaneous interactions; voted choices with a default on disagreement.

### Saves: checkpoint autosave only, no manual saves
- Early episodes: death = restart from the beginning. Later episodes: checkpoint
  autosave, still no manual save, ~1–2 hour single-sitting episodes.
  [1](https://www.reddit.com/r/FearsToFathom/comments/1ounnkz/can_you_really_not_save_in_fears_to_fathom/)
  [2](https://steamcommunity.com/app/2506160/discussions/0/3884977132832256161/)
- Implication for us: chapter-boundary autosave + death → checkpoint is the
  authentic structure; manual save-anywhere softens stakes (keep as accessibility
  option, default to F2F rules).

## 5. Build order (risk-managed, testable in slices)

- **P2a — True VHS:** move overlay under UI (layer 0), screen-sampling shader
  (barrel distortion + CA + roll-bar displacement + grain + scanlines + vignette).
- **P2b — Surfaces:** `tex.gd` procedural 64–128px textures (wood/tile/carpet/
  drywall/asphalt/grass/deck/ceiling), NEAREST filtering, uv1 tiling.
- **P2c — Dread systems:** light-seep door strips, ticking clock + stop event,
  dread-director micro-events (5 scripted object changes + subliminal frame-edge
  glimpses), camera zoom on NPC talk, notes→warning reward,
  true-story intro card, dialog restyle to bottom subtitles.
- **P2d — Geometry:** lamp fixtures, baseboards, ceiling fans, curtains + blinds,
  kitchen/bathroom/laundry dressing, distant houses with lit windows, wet streaks.
