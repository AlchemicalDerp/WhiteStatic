extends Node
## Central, global signal hub. The single place cross-system signals are
## declared. Holds NO state and NO logic: systems publish facts here and
## subscribe to the facts they care about, so they never need direct references
## to one another. See docs/ARCHITECTURE.md.
##
## Autoloaded FIRST (see project.godot) because everything else depends on it.

# --- Time ----------------------------------------------------------------
signal minute_passed(total_minutes: int)
signal hour_passed(hour: int, day: int)
signal day_passed(day: int)
## phase is one of GameClock.Phase (DAWN/DAY/DUSK/NIGHT).
signal phase_changed(phase: int)

# --- Vitals / survival ---------------------------------------------------
signal warmth_changed(value: float)        ## 0 (frozen) .. 1 (warm)
signal hunger_changed(value: float)        ## 0 (fed) .. 1 (starving)
signal thirst_changed(value: float)        ## 0 (hydrated) .. 1 (parched)
signal exhaustion_changed(value: float)    ## 0 (rested) .. 1 (spent)
signal health_changed(value: float)        ## 0 (dead) .. 1 (whole)
signal player_died(cause: String)

# --- Wounds --------------------------------------------------------------
signal wound_added(wound: Dictionary)
signal wound_changed(wound: Dictionary)
signal wound_healed(wound: Dictionary)

# --- Hand steadiness (the bridge to Morse) -------------------------------
signal steadiness_changed(value: float)    ## 0 (shaking) .. 1 (steady)

# --- Psychology / symptoms ----------------------------------------------
## symptom is one of SymptomSystem.Symptom.
signal symptom_onset(symptom: int, intensity: float)
signal symptom_intensity_changed(symptom: int, intensity: float)
signal symptom_cleared(symptom: int)
## action is one of SymptomSystem.Involuntary; context carries details.
signal involuntary_action(action: int, context: Dictionary)
## A hallucination the world is asked to realize (see SymptomSystem).
signal hallucination_requested(hallucination: Dictionary)

# --- Morse / radio -------------------------------------------------------
## An incoming message has begun playing (data: see MorseMessage).
signal morse_incoming(message: Dictionary)
## A single keyed/played symbol, for live UI: "." "-" or "" (gap).
signal morse_symbol(symbol: String, is_keyed: bool)
## The player finished sending. fidelity 0..1, duration in game-seconds.
signal morse_message_sent(text: String, fidelity: float, duration: float)
## Enemy direction-finding confidence on the transmitter, 0..1.
signal direction_finding_progress(value: float)
signal radio_stage_changed(stage_id: String)
signal radio_component_installed(component_id: String)

# --- Reconnaissance ------------------------------------------------------
signal observation_logged(entry: Dictionary)
signal recon_accuracy_changed(value: float) ## 0 .. 1

# --- Enemy ---------------------------------------------------------------
signal stimulus_emitted(stimulus: Dictionary)
## level is one of Suspicion.Level.
signal enemy_alerted(agent: Node, level: int)
signal enemy_state_changed(agent: Node, state: int)
signal player_spotted(agent: Node)

# --- Notebook ------------------------------------------------------------
signal notebook_entry_added(entry: Dictionary)
## kind is one of Notebook.Corruption.
signal notebook_corrupted(entry: Dictionary, kind: int)
signal notebook_opened()
signal notebook_closed()

# --- Interaction ---------------------------------------------------------
signal interactable_focused(node: Node)
signal interactable_unfocused(node: Node)
signal interacted(node: Node)

# --- Inventory / scavenging ---------------------------------------------
signal item_gained(item_id: String, amount: int)
signal item_lost(item_id: String, amount: int)

# --- Game / campaign -----------------------------------------------------
signal game_started()
signal game_paused(paused: bool)
signal goal_updated(goal_id: String, progress: float)
signal ending_reached(ending_id: String)
