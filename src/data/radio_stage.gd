class_name RadioStage
extends Resource
## One rung of the radio progression: crude receiver -> better receiver ->
## weak transmitter -> hidden field station. Each stage requires a set of
## component ids and unlocks receiving and/or transmitting capability.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## RadioComponent ids that must be installed to build this stage.
@export var required_components: PackedStringArray = []
@export var enables_receive: bool = false
@export var enables_transmit: bool = false
## Effective transmit range; the field station is the only one that reaches
## friendly forces.
@export var range_km: float = 0.0
## Transmitting needs a raised antenna, which improves range but is a visible
## stimulus enemy patrols can spot — the core risk trade-off.
@export var antenna_required: bool = false
