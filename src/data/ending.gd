class_name Ending
extends Resource
## A campaign outcome. The id matches what GameState.evaluate_ending() returns;
## this resource carries the presentation (title, epilogue) so endings can be
## authored and tuned without touching evaluation logic.

@export var id: String = ""
@export var title: String = ""
@export_multiline var epilogue: String = ""
## Short human description of when this ending fires, for documentation.
@export_multiline var condition_summary: String = ""
