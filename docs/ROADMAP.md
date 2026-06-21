# Roadmap

Status of the scaffold and the path forward. "Working" means real logic you can
exercise; "stubbed" means the interface and signals exist with a clearly marked
`# TODO`.

## Done in this scaffold

- Project config, autoload wiring, input map, physics layers (`project.godot`).
- `EventBus` — the full cross-system signal surface.
- `MorseSystem` — **working**: International Morse codec, WPM timing, keying
  classification, jitter from hand steadiness, and fidelity scoring.
- `Notebook` — **working** data model with corruption hooks.
- `SymptomSystem` — **working** symptom model: stressor inputs, episode roller,
  involuntary actions, hallucination requests, steadiness modifier.
- `GameClock` — **working** time/day/phase.
- `GameState` — goals + ending-evaluation matrix + save/load skeleton.
- `AudioDirector` — **working** procedural static bed and Morse tone synthesis.
- Player FPS controller + components (`Vitals`, `WoundSystem`, `HandSteadiness`,
  `Inventory`, `Interactor`) — survival decay and steadiness are functional.
- `RadioBuild` — **working** staged progression and part requirements.
- `ReconLog` — **working** recorded-vs-truth accuracy scoring.
- `PatrolAgent` + `Suspicion` — inference model and state machine (movement
  simplified).
- Authorable `Resource` data classes (`MorseMessage`, `RadioComponent`,
  `RadioStage`, `SquadMember`, `Ending`).
- Code-built `HUD`, `NotebookUI`, `RadioUI`.
- `main.gd` assembles a playable winter test field.

## Stubbed (interfaces exist, content/behavior to come)

- Enemy navigation (NavigationServer/agent pathing), dogs, listening posts,
  false-Morse traffic, flares, dedicated direction-finding teams.
- Hallucination *spawning* (the system requests them; the world must realize
  them as figures/sounds/false notebook entries).
- Full survival depth: hunting/trapping, fire & smoke, snow-melting, sleep,
  frostbite/finger damage, camp build/defend/abandon.
- Radio tuning minigame, antenna placement & its detection trade-off, power
  management.
- Scavenging variety, squad-equipment recovery flows, and squad memory beats.
- Art, audio assets, animation, real level geometry.

## Suggested next milestones

1. **Vertical slice of the Morse loop.** Flesh out `RadioUI` decode/keying into
   a satisfying receive→copy→decode→reply cycle with audible static and DF risk.
2. **First survival pressure.** Make cold→steadiness→Morse legible to the player
   so the systems visibly connect.
3. **One honest recon objective** with a truth model and a notebook that can be
   corrupted under stress.
4. **One enemy patrol that infers** from a single stimulus type (sound), then
   layer in tracks, smoke, light, and DF.
5. **Two endings** wired through `GameState.evaluate_ending()` to prove the
   ending matrix end-to-end.

## Optional tooling

- A GitHub Actions job running Godot headless `--check-only` over `src/` to
  catch GDScript parse errors on push. Left out of the scaffold by default to
  keep it dependency-free; add when CI is wanted.
