# ECHOES IN THE DARK — Episode 2: "The Housesit" (Godot 4 project)

Same Fears-to-Fathom DNA as Episode 1 (web), brand-new story: you are **Jamie, 17,
housesitting for the Millers** for one stormy night with their cat Biscuit. Then
"Daniel" knocks, claiming to be their son.

7 chapters (~60 min), 4 endings, zero binary assets — the house, characters and
every sound are generated in code.

## Import into Godot (2 minutes)

1. Install **Godot 4.3 or newer** (4.4/4.5+ fine) from https://godotengine.org.
2. Extract the ZIP **to a normal folder** (e.g. `Documents/Godot/Housesit/`).
   The folder must directly contain `project.godot` — not nested double.
3. Open Godot → **Project Manager → Import** → select the `project.godot` file
   → **Import & Edit**.
4. Press **F5** (▶). First import takes ~30 seconds (it builds the audio bank).

**Controls:** WASD move · mouse look · SHIFT sprint (loud!) · C crouch (quiet) ·
E interact (hold E for long tasks) · F flashlight · TAB phone (1/2/3 reply,
Q switch threads) · ESC pause.

## If a ZIP "couldn't be extracted" (the common AI-zip failure)

This package was built to avoid every known cause of that error:

- ✅ Relative paths only (`project.godot`, `scenes/...`) — no absolute paths,
  no `./` prefixes, no `__MACOSX`, no hidden files, verified with `unzip -t`.
- ✅ `project.godot` sits at the **root of the ZIP** — Godot imports it directly.
- ✅ Filenames are plain ASCII, standard `deflate` compression, no encryption.
- ✅ No `.godot/` cache folder inside — Godot rebuilds it on first import.

If your extractor still complains: don't "preview inside" the ZIP — **extract all
first** (right-click → Extract All / double-click on Mac), avoid non-English
characters in the folder path, and make sure the drive isn't full. As a fallback,
download this `godot/` folder straight from the repo instead of using the ZIP.

## Project map

```
project.godot      engine config + full input map (main.gd also re-adds any
                   missing action at runtime, so controls can't be lost)
icon.svg           project icon (referenced by project.godot)
scenes/main.tscn   Main → World / Player(+Camera+Ray+Flashlight) / Enemy / Audio / UI
shaders/vhs.gdshader  scanlines + grain + vignette overlay
scripts/
  config.gd    all tuning numbers
  world.gd     FLOORPLAN → walls+colliders, doors, furniture, lights, yard, rain
  door.gd      named door entity (hinge, swing, lock, dynamic collision)
  player.gd    FPS CharacterBody3D (stamina, crouch, noise)
  interact.gd  raycast registry (instant + hold-to-complete)
  phone.gd     text threads, timed scripts, replies
  story.gd     7-chapter state machine, objectives, scares, endings
  enemy.gd     stranger AI: perch → patrol/investigate/chase/search
  audio.gd     synthesized SFX bank (footsteps, knocks, stings, siren, loops)
  ui.gd        every screen built in code (menu/HUD/phone/dialog/pause/endings)
  save.gd      JSON saves in user://
```

**Design rules (same as Ep 1):** no random geometry — the labeled floorplan is the
single source of truth for walls AND collision; every door is a named entity;
every prompt does something; physics layers keep it clean
(1 World · 2 Doors · 3 Interact · 4 Player · 5 Enemy · 6 WindowBlock).

## New story, same mechanics

| System | Ep 1 (web, "Home Alone") | Ep 2 (Godot, "The Housesit") |
|---|---|---|
| Chores | groceries/trash/thermostat/homework | Biscuit/mail/trash/thermostat/essay |
| Dinner | pasta + couch + news | lasagna + couch + news |
| Knock | stranger at door | "Daniel, the Millers' son" |
| Blackout | flashlight + 3 breakers | flashlight + 3 breakers |
| Intruder | parents' window | master window (same latch!) |
| Escapes | neighbor / window / 911 | neighbor / window / 911 |
| Hiding | bed + 2 closets | bed + 2 closets |
| Notes | 8 | 8 (all-new text) |
| Endings | 4 | 4 (all-new text) |
