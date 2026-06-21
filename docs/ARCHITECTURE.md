# Architecture

WhiteStatic is built on a small set of deliberate conventions so that many
interacting systems (survival, Morse, psychology, recon, enemy AI) can grow
without becoming a tangle. Read this before adding code.

## Principles

1. **Decouple through the `EventBus`.** Systems do not hold references to each
   other where they can avoid it. They publish facts ("a wound was added", "a
   Morse message finished sending", "night fell") to the global `EventBus` and
   subscribe to the facts they care about. This keeps the cold system, the
   psychology system, and the radio system independently testable.
2. **Global *systems* are autoloads; player *state* lives on components.**
   Stateless or world-global logic (time, the Morse codec, audio, the notebook
   model, the symptom model) are autoload singletons. Things that belong to the
   protagonist's body (warmth, wounds, hand steadiness, inventory) are
   `Node` components under the player scene.
3. **Authorable content is `Resource` data, not hard-coded.** Morse messages,
   radio components, radio stages, squad members, and endings are
   `class_name`'d `Resource` types in `src/data/` so they can be created and
   tuned in the editor.
4. **The notebook and the senses can lie.** Any system that surfaces
   information to the player (notebook entries, audio cues, sighted figures)
   must route through a layer that the `SymptomSystem` is allowed to corrupt.
   Truth and the player's *record* of truth are stored separately.

## The autoload singletons

Loaded in this order (see `project.godot`); `EventBus` must be first.

| Singleton | Responsibility |
| --- | --- |
| `EventBus` | Typed signal hub. The single source of cross-system signals. Holds **no** state and **no** logic. |
| `GameClock` | Game time, day count, and day/night phase. Emits `minute/hour/day/phase` signals. Winter days are short. |
| `MorseSystem` | International Morse codec, WPM timing, keying-to-symbol classification, and fidelity scoring. Pure logic. |
| `AudioDirector` | Procedural static bed and Morse tone synthesis; one-shot diegetic and hallucinated sounds. |
| `Notebook` | The player's *record*: transcripts, map marks, recon notes, wounds. Exposes corruption hooks for the `SymptomSystem`. |
| `SymptomSystem` | The psychological model. Not a sanity meter — a set of symptoms that trigger involuntary actions, hallucinations, and notebook corruption, and that degrade hand steadiness. |
| `GameState` | Campaign goals, run metrics, ending evaluation, and save/load orchestration. |

## The player

`src/player/player.tscn` is a `CharacterBody3D` first-person controller. Its
survival state lives in child component nodes (`src/player/components/`):

- `Vitals` — warmth, hunger, thirst, exhaustion, and overall health. Decays
  over time and with activity/environment.
- `WoundSystem` — discrete wounds that bleed, infect, and cause fever.
- `HandSteadiness` — the keystone of the Morse loop. Aggregates cold, wounds,
  hunger, exhaustion, and active symptoms into a single `0..1` steadiness value
  that `MorseSystem` uses to jitter the player's keying.
- `Inventory` — kit and scavenged radio components.
- `Interactor` — a forward `RayCast3D` that focuses and triggers `Interactable`s.

## Domain modules

- `src/radio/` — `RadioBuild` (the receiver→transmitter→field-station
  progression and its part requirements), plus `MorseKeyer` (turns held input
  into timed symbols) and `MorseDecoder` (the player's manual decode buffer).
- `src/recon/` — `ReconLog` stores observations as *recorded vs. truth* pairs
  and scores accuracy, which feeds endings.
- `src/enemy/` — `PatrolAgent` with an inference-based `Suspicion` model that
  reacts to `Stimulus` events (sound, light, smoke, tracks, radio
  direction-finding). The enemy infers; it is never omniscient.
- `src/world/` — `Interactable` base type, `Camp`, and environmental traces
  (e.g. `Footprints`) that become enemy stimuli.
- `src/squad/` — the dead squad. Each `SquadMember` leaves equipment, knowledge,
  and a "voice" the `SymptomSystem` can use for its most convincing
  hallucinations.

## Data flow example: sending one Morse message

```
RadioUI (player keys)              MorseKeyer.feed(pressed, dt)
   -> emits symbol timings   ->    MorseSystem.classify_keying()
HandSteadiness.value         ->    MorseSystem.score_fidelity()
   -> fidelity + duration    ->    EventBus.morse_message_sent
GameState   (records best fidelity for endings)
RadioBuild  (only allowed past the transmitter stage)
Enemy DF    (longer duration -> EventBus.direction_finding_progress)
AudioDirector (sidetone playback while keying)
```

No system in that chain holds a direct reference to another; they meet at the
`EventBus`.

## Conventions

- GDScript, Godot 4.x. Static typing on declarations and function signatures.
- Autoload scripts have **no** `class_name` (they are referenced by their
  autoload name). Reusable, instanced types **do** get a `class_name`.
- Enums and signal argument types are documented with `##` doc comments.
- Anything not yet implemented is marked `# TODO:` with a short note on intent,
  never left as a silent empty function.
