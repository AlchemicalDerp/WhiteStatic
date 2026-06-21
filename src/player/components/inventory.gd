class_name Inventory
extends Node
## Kit and scavenged radio components, as id -> count. RadioBuild reads parts
## from here. It also listens for involuntary actions: a dissociative or
## enraged episode really does misplace a part or snap a wire, so the symptom
## system has teeth in the inventory.

var items: Dictionary = {}   ## item_id -> count

## Ids treated as radio components, so episodes target them and RadioBuild can
## enumerate them. Extend as content grows.
const COMPONENT_IDS := [
	"battery", "headphones", "coil", "valve", "crystal",
	"antenna_wire", "insulator", "field_wire", "scrap_metal", "tools",
]


func _ready() -> void:
	EventBus.involuntary_action.connect(_on_involuntary)


func add(item_id: String, amount: int = 1) -> void:
	items[item_id] = count(item_id) + amount
	EventBus.item_gained.emit(item_id, amount)


func remove(item_id: String, amount: int = 1) -> bool:
	if count(item_id) < amount:
		return false
	items[item_id] = count(item_id) - amount
	if items[item_id] <= 0:
		items.erase(item_id)
	EventBus.item_lost.emit(item_id, amount)
	return true


func count(item_id: String) -> int:
	return items.get(item_id, 0)


func has(item_id: String, amount: int = 1) -> bool:
	return count(item_id) >= amount


## Component ids currently held (one entry per id present).
func components_held() -> PackedStringArray:
	var out := PackedStringArray()
	for id in COMPONENT_IDS:
		if has(id):
			out.append(id)
	return out


func _on_involuntary(action: int, _context: Dictionary) -> void:
	match action:
		SymptomSystem.Involuntary.MISPLACE_PART, \
		SymptomSystem.Involuntary.DAMAGE_COMPONENT, \
		SymptomSystem.Involuntary.SNAP_WIRE:
			_lose_random_component()


func _lose_random_component() -> void:
	var held := components_held()
	if held.is_empty():
		return
	remove(held[randi() % held.size()], 1)
