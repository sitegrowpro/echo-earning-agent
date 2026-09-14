# ECHOES IN THE DARK — Episode 2: "The Housesit" (Godot 4 project)

Same Fears-to-Fathom DNA as Episode 1 (web), brand-new story: you are **Jamie, 17,
housesitting for the Millers** for one stormy night with their cat Biscuit. Then
"Daniel" knocks, claiming to be their son.

7 chapters (~60 min), 4 endings, zero binary assets — the house, characters and
every sound are generated in code.

## Import into Godot (2 minutes)

1. Install **Godot 4.7 (latest stable, 4.7.2+)** from https://godotengine.org/download
   (4.3+ works too, but 4.7 is recommended — and it will **not** open in Godot 3.x,
   that's a whole different engine generation).
2. Extract the ZIP **to a normal folder** (e.g. `Documents/Godot/Housesit/`).
   The folder must directly contain `project.godot` — not nested double.
3. Open Godot → **Project Manager → Import** → select the `project.godot` file
   → **Import & Edit**.
4. Press **F5** (▶). First import takes ~30 seconds (it builds the audio bank).

**Controls:** WASD move · mouse look · SHIFT sprint (loud!) · C crouch (quiet) ·
E interact (hold E for long tasks) · F flashlight · TAB phone (1/2/3 reply,
Q switch threads) · M mute mic · ESC pause.

## v1.1 — what's new

- 🎙 **Microphone stealth.** With a mic connected, hiding is real: cough, talk or
  laugh and he hears you. Live level meter on the HUD, sensitivity slider in
  Settings, **M** mutes anytime. No mic? The game falls back to movement noise.
  (Desktop builds may ask for mic permission once — that's the OS, not us.)
- 🛒 **FreshMart errand.** Mid-shift you walk to the supermarket for Dana's list:
  6 items, scanner beeps, fluorescent hum, PA announcements, a chatty cashier —
  and two men by the dairy case. One of them is wearing a suit. His friend is
  looking for a dog.
- 👔 **A John Williams homage.** Talk to JOHN. You know what to ask about. Probably.
- 🎩 **An MJ easter egg.** Martin's record shelf. The 1982 pressing. Hee-hee.
  (2 eggs total — your ending stats count them.)
- 🐈 **Biscuit is real now.** He wanders, meows, takes chin scratches — and his
  fur stands up when the stranger is close. Trust the cat.
- ⛈ **Living storm.** Lightning with delayed thunder, surface footsteps
  (wood/tile/carpet/concrete/grass), sprint FOV kick, dying-flashlight flicker,
  9 readable notes.

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
  player.gd    FPS CharacterBody3D (stamina, crouch, noise, surfaces, FOV kick)
  interact.gd  raycast registry (instant + hold-to-complete, dynamic add/remove)
  phone.gd     text threads, timed scripts, replies
  story.gd     7-chapter state machine, market errand, eggs, scares, endings
  enemy.gd     stranger AI: perch → patrol/investigate/chase/search + mic hearing
  audio.gd     synthesized SFX bank (no files: steps, knocks, stings, cat, funk…)
  mic.gd       real-microphone capture (silent bus + level/loud-streak detection)
  market.gd    FreshMart interior: aisles, dairy, checkout, NPCs
  cat.gd       Biscuit: wander, meow, petting, hiss early-warning
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
| Errand | — | 🛒 FreshMart supermarket trip |
| Dinner | pasta + couch + news | lasagna + couch + news |
| Knock | stranger at door | "Daniel, the Millers' son" |
| Blackout | flashlight + 3 breakers | flashlight + 3 breakers |
| Intruder | parents' window | master window (same latch!) |
| Escapes | neighbor / window / 911 | neighbor / window / 911 |
| Hiding | bed + 2 closets | bed + 2 closets + 🎙 mic stealth |
| Notes | 8 | 9 (all-new text) |
| Easter eggs | — | 🥚 2 (Keanu + MJ) |
| Endings | 4 | 4 (all-new text) |
