class_name SquadMember
extends Resource
## A fallen squadmate. Each haunts the game mechanically and emotionally:
## leaving equipment, knowledge, and a "voice" the SymptomSystem can use for
## its most convincing hallucinations.

@export var id: String = ""
@export var display_name: String = ""
@export var role: String = ""
## Component ids recoverable from their kit.
@export var leaves_components: PackedStringArray = []
@export_multiline var wound_notes: String = ""
## Lines the SymptomSystem may surface as whispers/commands — the sergeant's
## accusation, a friend's reassurance, the operator's call signs.
@export var voice_lines: PackedStringArray = []
## The scout's map marks may contradict the player's own observations.
@export var marks_may_contradict: bool = false
