# WhiteStatic — Design

> The core fantasy is not being a super soldier. It is being alone, freezing,
> hunted, traumatized, and barely holding together, but still trained well
> enough to observe, improvise, build, and transmit. The win condition is not
> killing the enemy. It is getting the truth out before the cold, the enemy, or
> your own mind finally breaks you.

This document captures the design vision the codebase implements toward. It is
the source of truth for *what the game is*; `ARCHITECTURE.md` covers *how the
code is organized*.

## Premise

Early WWII. A lone surviving Allied recon paratrooper is dropped behind enemy
lines in winter. The unit is ambushed during descent — fire, searchlights,
flak, patrols. Most of the squad dies before or shortly after landing. The
player loses their pack and lands with minimal kit; most supply containers and
packs are smashed, scattered, looted, or buried in snow. Alone, with little
ammunition, poor shelter, freezing weather, wounds, hunger, and thirst, and no
reliable way home.

## Three overlapping goals

The campaign is a collision of three goals the player pursues simultaneously:

1. **Survive** the cold, hunger, thirst, wounds, and the enemy.
2. **Build a working Morse radio** from scavenged and improvised parts.
3. **Complete the reconnaissance mission** and get accurate intelligence out.

The player may escape with incomplete intelligence, stay to finish the mission,
call for extraction, sabotage the enemy, mislead patrols with false traffic, or
risk everything transmitting accurate coordinates.

## Pillar 1 — Morse is the heart

- Listen to Morse through static; **copy** into the notebook; **decode**;
  **key** replies by hand.
- **Calm hands produce cleaner Morse.** Cold, injury, fear, anger, hunger,
  exhaustion, and trauma worsen timing (see *Hand steadiness*).
- Longer transmissions improve the chance of being understood but increase the
  risk of enemy **direction-finding**. Every message is a survival decision:
  too little and no one can help; too much and the enemy locates you.
- The radio is built in stages, not repaired whole:
  1. **Crude receiver** (primitive components).
  2. **Better receiver**.
  3. **Weak Morse transmitter** (scavenged military electrical parts, power,
     tuning, a proper antenna).
  4. **Hidden field station** capable of reaching friendly forces.
- Components are scavenged: batteries, headphones, coils, valves/tubes,
  crystals, antenna wire, insulators, field-telephone wire, scrap metal, and
  improvised tools, recovered from wreckage, dead squadmates, broken drops,
  damaged aircraft parts, and enemy radio gear.

## Pillar 2 — Reconnaissance, not combat

The protagonist was trained to **observe, remember, report, and stay calm**.
The best endings require accurate recon, not kills:

- Observe patrols, map routes, identify installations, count vehicles, locate
  radio stations, time search patterns, mark artillery positions, recover
  documents, report intelligence.
- The rifle is loud, slow, scarce, and dangerous — a hunting tool or emergency
  option, not a primary weapon. Fighting is a last resort.

## Pillar 3 — Survival is harsh and grounded

- **Cold is the main enemy.** It slows movement, blurs vision, shakes the
  hands, damages fingers, worsens Morse timing, and makes sleep dangerous.
- **Hunger and thirst** force hunting, trapping, scavenging rations, melting
  snow, and boiling water — at the risk of smoke from fires.
- **Wounds** bleed, infect, limit movement, cause fever, and can trigger
  hallucinations.
- **Camps** are temporary: hidden, warmed, defended, and abandoned when
  discovered.

## Pillar 4 — Psychological horror as a symptom system

After watching the unit die, the player is shell-shocked. This is **not a
sanity meter**; it is a system of symptoms — anxiety, anger, rage, fear,
numbness, hypervigilance, dissociation, exhaustion — that change behavior:

- **Involuntary actions:** driving a screwdriver into the table without knowing
  why, overtightening screws, snapping wires, misplacing parts, waking outside
  camp, chambering a round unmeant, spilling water, damaging low-value
  components, losing time.
- **Hallucinations attack the exact skills the player depends on:** squadmates
  in the tree line, parachutes where none hang, lanterns that become moonlight,
  patrols that vanish, footprints that stop suddenly, dead friends who walk.
  Sounds: Morse in the wind, boots in the snow, whispered commands, aircraft
  engines, rifle bolts, the player's own name through static.
- The radio is both hope and threat: some transmissions are friendly, some are
  enemy deception, and some may not be real at all.

## The notebook — interface and horror object

Holds maps, Morse transcripts, patrol notes, sketches, mission details, radio
diagrams, wound records, and personal observations. Under stress it becomes
**unreliable**: coordinates appear in the player's handwriting with no memory of
writing them; patrol markings shift; a dead squadmate's name appears in the
margin; a transcript includes an impossible phrase. The player must decide
whether their notes are accurate, altered, misremembered, or hallucinated.
*Truth and the player's record of truth are stored separately in code.*

## The dead squad

Each squadmate haunts the game mechanically and emotionally, leaving equipment,
skills, memories, or trauma:

- **Radio operator** — knowledge, call signs, damaged parts.
- **Medic** — supplies and wound notes.
- **Scout** — map markings that may contradict the player's own.
- **Sergeant** — a returning voice of discipline, command, or accusation.
- **Close friend** — the most convincing hallucination of all.

## The enemy — intelligent, not supernatural

Patrols **infer**, they do not magically know the player's location. They
investigate sound, smoke, tracks, lights, stolen supplies, cut wires, visible
antennas, repeated routes, and radio activity, using dogs, listening posts,
false Morse traffic, flares, search parties, and direction-finding teams. This
makes stealth, relocation, and restraint essential.

## Endings

Outcomes depend on **survival**, **radio success**, **mental state**, and
**recon accuracy**. Possible endings include: rescue, capture, freezing, false
rescue, failed intelligence, successful mission, revenge through sabotage or
artillery, and an ambiguous ending where the player's body is found beside a
dead radio while their call sign keeps transmitting for days.

## Hand steadiness (the connective system)

Hand steadiness is the mechanical bridge between every other system and the
Morse heart. It is a single `0..1` value derived from:

- cold (primary), wounds (bleeding/fever), hunger, exhaustion, and the active
  set of symptoms (fear/anger/exhaustion reduce it most).

It directly determines keying jitter and therefore the fidelity of every
message the player sends — so the cold, the wound, the fear, and the trauma all
ultimately express themselves through whether the message gets out clean.
