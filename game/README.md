# ECHES IN THE DARK — Episode 1: “Home Alone”

A complete, professional, Fears-to-Fathom-style episodic horror game that runs in the
browser. First-person, story-driven, ~60 minutes, 4 endings, zero external assets
(all geometry + audio is procedural).

## Play it

```bash
cd game
python3 -m http.server 8080 --bind 0.0.0.0
# open http://localhost:8080
```

Desktop + mouse + headphones recommended. Click the game to lock the mouse.

**Controls:** WASD move · mouse look · SHIFT sprint (loud!) · C crouch (quiet) ·
E interact (hold E for long tasks) · F flashlight · TAB phone (1/2/3 to reply) ·
ESC pause.

## The night (7 chapters, ~60 min)

| # | Chapter | Time | What happens |
|---|---------|------|--------------|
| 0 | Arrival | 8:12 PM | Porch, Mom's texts, get inside, deadbolt the door |
| 1 | Chores | 8:40 PM | Groceries, trash, thermostat, 3 pages of homework, Mom calls |
| 2 | Dinner & Static | 9:35 PM | Heat pasta (75 s), eat on couch, watch the news, Mason's warning |
| 3 | Knock Knock | 10:20 PM | The stranger at the door — peephole, dialogue choices, Mom's photo |
| 4 | Blackout | 10:58 PM | Power cut, find flashlight, reset 3 breakers, unknown caller |
| 5 | He's Inside | 11:24 PM | Back-window break-in, real hunter AI, hide, find keys |
| 6 | Run | 11:52 PM | 3 escape routes → **4 endings** (neighbor / window / 911 / taken) |

Systems: sprint/stamina, crouch stealth, noise propagation, animated doors with
locks, per-room lights + fuse power grid, flashlight battery, hiding (bed/closets),
sitting, hold-to-complete tasks, phone threads + replies + calls, 8 readable notes,
VHS HUD clock, autosave per chapter, endings gallery, settings.

---

## How Fears to Fathom was actually made (research)

Method: web research on the series, its developer, engine, and episode structure.

- **Solo-dev Unity project.** The series is created by Indian developer Mukul Negi
  ("Rayll"), who built Episode 1 largely alone — design, code, art — before
  expanding to a tiny team; the games are made in the **Unity engine**. [1](https://grokipedia.com/page/Fears_to_Fathom) [2](https://steamcommunity.com/app/1671340/discussions/0/4849904631720061418/)
- **Episodic anthology of "true" stories.** Each episode is a standalone,
  survivor-narrated first-person account (Home Alone, Norwood Hitchhike, Carson
  House, Ironbark Lookout, Woodbury Getaway…), typically **1–3 hours** long,
  crowdsourced in part from fan-submitted creepy encounters. [3](https://grokipedia.com/page/Fears_to_Fathom)
- **Mundane-first pacing.** ~Half of Home Alone is routine: dinner, homework,
  texting. Horror comes from familiar spaces made wrong — a photo from Mom
  reframes every window as a vulnerability. No monsters needed. [4](https://www.demagaga.com/2026/07/02/fears-to-fathom-home-alone-review-real-horror-doesnt-need-monsters/)
- **Simple mechanics, deep immersion.** Interact with household objects, answer
  texts, make timing/awareness choices (hide, wait, run). Choices branch into
  **multiple endings**. Later episodes add driving + conversation systems and a
  VHS aesthetic. [5](https://playgamor.com/fears-to-fathom-home-alone/)
- **Audio as architecture.** Long stretches of household silence make every
  unexpected sound (knock, glass, siren) land. Practical lighting only — TV glow,
  lamps — so darkness is never absolute and players doubt what they saw.

## How THIS game was built (same recipe, web tech)

1. **Locked the story first** — 7-chapter beat sheet with timestamps, like an F2F
   episode script, before writing any code (`story.js` is that script, executable).
2. **Floorplan-first worldbuilding** — the #1 anti-"random walls" rule: the house
   was drawn as a labeled plan (rooms, doors, arches, windows with purposes),
   then walls were generated from that plan with door/window holes, and
   **colliders derive from the same wall data** — visuals and collision cannot
   disagree. Every door is a named entity (hinge, swing direction, lock, sound).
3. **One system per file, zero placeholders** — `world / player / interact /
   phone / story / enemy / audio / save / main`. No stubs: everything referenced
   in the UI exists and works.
4. **F2F's signature mechanics, faithfully:** real-time phone threads that turn
   hostile, peephole, "don't open the door" choice with a real consequence,
   microwave waiting, TV news you must sit through, hiding under the bed while
   something breathes beside it, and branching endings.
5. **Procedural everything** — Three.js geometry + WebAudio synthesis means no
   binary assets, instant load, and the whole game is reviewable code.
6. **Playtested loop** — autosave per chapter, pause menu with live objectives,
   settings (sensitivity/volume/subtitles/grain/head-bob), and a mercy rewind
   after the bad end.

## Architecture (for contributors)

```
game/
  index.html        all UI: menu, HUD, phone, dialog, notes, peephole, pause, endings
  css/style.css     horror treatment: scanlines, grain, vignette, VHS stamp
  js/config.js      every tuning number (speeds, timers, AI) in one place
  js/world.js       FLOORPLAN → walls+colliders, doors, furniture, lights, yard, rain
  js/player.js      FPS controller: look/move/sprint/stamina/crouch/AABB collision
  js/interact.js    raycast registry: instant + hold-to-complete interactions
  js/phone.js       text threads, timed scripts, replies, incoming calls
  js/story.js       7-chapter state machine, objectives, scares, power, endings
  js/enemy.js       stranger: scripted perches → patrol/investigate/chase/search AI
  js/audio.js       synthesized ambience, rain, steps, creaks, knocks, stings, siren
  js/save.js        localStorage: chapter autosaves, endings gallery, settings
  js/main.js        renderer, UI wiring, menus, HUD loop, pause, boot
```

**Design rules enforced in code:** no random geometry (plan → walls → colliders
single source of truth); no dead interactions (every prompt has an effect);
no unwinnable states (objectives always achievable in-chapter; rewind after death).
