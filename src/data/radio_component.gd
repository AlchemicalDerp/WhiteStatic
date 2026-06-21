class_name RadioComponent
extends Resource
## A scavenged or improvised part used to build the radio: batteries,
## headphones, coils, valves/tubes, crystals, antenna wire, insulators,
## field-telephone wire, scrap metal, improvised tools. Authorable in the
## editor; RadioBuild ships sensible defaults so content is optional early.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Where it tends to be found (wreckage, a dead squadmate, a broken drop,
## enemy gear). Flavor + scavenge hints.
@export var source: String = ""
## Fragile parts (valves, crystals) are the ones a shaking hand or a rage
## episode can destroy.
@export var fragile: bool = false
