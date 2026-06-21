# WhiteStatic

> You were trained to see what others missed. Now you see too much.

A first-person 3D **survival / psychological-horror** game set in early WWII.
You are the lone surviving Allied recon paratrooper of a drop gone wrong behind
enemy lines, in winter. You must **survive**, **build a working Morse radio from
scavenged parts**, and **complete the reconnaissance mission** — while cold,
hunger, wounds, the enemy, and your own unraveling mind work against you.

Morse code is not a side mechanic. It is the heart of the game: you listen
through static, copy messages into a notebook, decode them, and key replies by
hand. **Calm hands produce cleaner Morse.** Cold, fear, injury, and exhaustion
make your timing worse — and may make you doubt what you saw, what you wrote,
and whether the voice on the radio is even real.

---

## This repository

This is the **project scaffold**: a Godot 4 project with a clean folder
structure, an event-driven architecture, and core system stubs. The distinctive
systems — the Morse engine, the symptom / hand-steadiness model, the unreliable
notebook, the radio-build progression — are implemented as real, working logic.
The 3D world, art, enemy navigation, and full content are intentionally stubbed
with clear extension points.

See **[`docs/DESIGN.md`](docs/DESIGN.md)** for the full vision,
**[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)** for how the code is organized,
and **[`docs/ROADMAP.md`](docs/ROADMAP.md)** for what is done vs. stubbed and what
comes next.

## Requirements

- **Godot 4.4** or newer (standard build; no C#/Mono required).

## Running

1. Open Godot, choose **Import**, and select this folder's `project.godot`.
2. Press **F5** (Play). The boot scene `scenes/main.tscn` assembles a small
   winter test field with a radio workbench, a supply cache, a fallen
   squadmate, and an enemy patrol so the core loop is reachable from the start.

### Controls (test field)

| Action | Key |
| --- | --- |
| Move | `W` `A` `S` `D` |
| Look | Mouse |
| Sprint / Crouch | `Shift` / `Ctrl` |
| Jump | `Space` |
| Interact | `E` |
| Notebook | `Tab` |
| Use radio | `R` |
| Key Morse (in radio) | Left mouse / `K` |
| Release mouse / pause | `Esc` |

## Project layout

```
src/
  autoload/   Global singletons (EventBus, GameClock, MorseSystem, ...)
  player/     First-person controller + survival components
  radio/      Morse keying, decoding, and the build progression
  recon/      Observation logging and accuracy scoring
  enemy/      Inference-based patrol AI and stimuli
  world/      Interactables, camp, environmental traces
  squad/      The dead squad and their lingering effects
  data/       Authorable Resource classes (messages, parts, endings, ...)
  ui/         HUD, notebook, and radio interfaces (built in code)
scenes/       Boot scene + assembled test field
docs/         Design, architecture, and roadmap
```

## Status

Early scaffold. Not yet a complete game — it is the skeleton the game is meant
to be built on. Contributions should follow the conventions in
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) (decouple through `EventBus`,
keep survival state in player components, keep authorable content in `data/`).
