class_name RadioBuild
extends Node
## The radio progression, built from scavenged parts in stages: crude receiver
## -> better receiver -> weak transmitter -> hidden field station. Each stage
## consumes required components from the player's Inventory and unlocks
## receiving and/or transmitting. Transmitting carries the core risk: longer
## traffic is more likely to be understood but feeds enemy direction-finding.

## Default progression. Authorable richer via RadioStage resources later.
const STAGES := [
	{
		"id": "crude_receiver", "name": "Crude receiver",
		"required": ["headphones", "coil", "crystal", "scrap_metal"],
		"receive": true, "transmit": false, "range_km": 0.0, "antenna": false,
	},
	{
		"id": "better_receiver", "name": "Better receiver",
		"required": ["valve", "battery", "insulator"],
		"receive": true, "transmit": false, "range_km": 0.0, "antenna": false,
	},
	{
		"id": "weak_transmitter", "name": "Weak transmitter",
		"required": ["valve", "battery", "antenna_wire", "tools"],
		"receive": true, "transmit": true, "range_km": 8.0, "antenna": true,
	},
	{
		"id": "field_station", "name": "Hidden field station",
		"required": ["coil", "crystal", "antenna_wire", "insulator", "field_wire"],
		"receive": true, "transmit": true, "range_km": 60.0, "antenna": true,
	},
]

## Injected by the bootstrap (main) so building consumes real parts.
var inventory: Inventory
## Where the set transmits from, for direction-finding stimuli. Set by main to
## the radio/antenna location.
var transmit_origin: Vector3 = Vector3.ZERO

var stage_index: int = -1
var installed: Array[String] = []
var df_confidence: float = 0.0   ## running enemy direction-finding fix, 0..1


func current() -> Dictionary:
	return STAGES[stage_index] if stage_index >= 0 else {}


func next_stage() -> Dictionary:
	return STAGES[stage_index + 1] if stage_index + 1 < STAGES.size() else {}


func can_receive() -> bool:
	return stage_index >= 0 and STAGES[stage_index]["receive"]


func can_transmit() -> bool:
	return stage_index >= 0 and STAGES[stage_index]["transmit"]


func is_field_station() -> bool:
	return stage_index >= 0 and STAGES[stage_index]["id"] == "field_station"


## What the next stage needs and whether it can be built now. Returns
## { "stage": Dictionary, "missing": PackedStringArray, "ok": bool }.
func check_next() -> Dictionary:
	var stage := next_stage()
	if stage.is_empty():
		return {"stage": {}, "missing": PackedStringArray(), "ok": false}
	var missing := PackedStringArray()
	for part in stage["required"]:
		if inventory == null or not inventory.has(part):
			missing.append(part)
	return {"stage": stage, "missing": missing, "ok": missing.is_empty()}


## Build the next stage if its parts are present; consumes them. Returns true
## on success.
func build_next() -> bool:
	var check := check_next()
	if not check["ok"]:
		return false
	var stage: Dictionary = check["stage"]
	for part in stage["required"]:
		inventory.remove(part, 1)
		installed.append(part)
		EventBus.radio_component_installed.emit(part)
	stage_index += 1
	EventBus.radio_stage_changed.emit(stage["id"])
	return true


## Transmit `text` by auto-keying at the player's current hand steadiness.
## `carries_intel` marks this as the real reconnaissance report.
func transmit(text: String, steadiness: float, carries_intel: bool = false) -> Dictionary:
	if not can_transmit():
		return {}
	return report_transmission(MorseSystem.simulate_send(text, steadiness), carries_intel)


## Account for a finished transmission (auto-keyed or hand-keyed): advance the
## enemy's direction-finding fix by time on the air, and report on the bus.
## A `result` is { "text", "morse", "fidelity", "duration" } from MorseSystem
## or MorseKeyer.finish(). This is the "send too much and the enemy finds you"
## risk made concrete.
func report_transmission(result: Dictionary, carries_intel: bool = false) -> Dictionary:
	if result.is_empty():
		return result
	# Longer time on the air -> better DF fix. A raised antenna radiates more,
	# helping the enemy too.
	var exposure: float = result["duration"] / 30.0
	if not current().is_empty() and current()["antenna"]:
		exposure *= 1.25
	df_confidence = clampf(df_confidence + exposure * 0.2, 0.0, 1.0)

	# A transmission is itself a stimulus a DF team can take a bearing on.
	Stimulus.emit(Stimulus.Type.RADIO, transmit_origin, result["duration"] / 30.0, 60.0, self)

	EventBus.morse_message_sent.emit(result["text"], result["fidelity"], result["duration"])
	EventBus.direction_finding_progress.emit(df_confidence)
	if carries_intel and result["fidelity"] >= 0.6:
		GameState.sent_accurate_coordinates = true
	return result
