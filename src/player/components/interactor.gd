class_name Interactor
extends RayCast3D
## Forward ray from the camera that focuses and triggers world Interactables.
## Anything it hits that has an `interact(player)` method is interactable;
## focus/unfocus go on the EventBus so the HUD can show a prompt.

## Injected by Player so interactions know who is acting.
var player: Node

var _focused: Node


func _physics_process(_delta: float) -> void:
	var hit := get_collider() if is_colliding() else null
	if hit != null and not _is_interactable(hit):
		hit = null
	if hit == _focused:
		return
	if _focused != null:
		EventBus.interactable_unfocused.emit(_focused)
	_focused = hit
	if _focused != null:
		EventBus.interactable_focused.emit(_focused)


## Called by Player on the "interact" action.
func try_interact() -> void:
	if _focused == null:
		return
	_focused.call("interact", player)
	EventBus.interacted.emit(_focused)


func focused() -> Node:
	return _focused


func prompt() -> String:
	if _focused == null:
		return ""
	if _focused.has_method("get_prompt"):
		return _focused.call("get_prompt")
	return "Use"


func _is_interactable(node: Object) -> bool:
	return node is Node and node.has_method("interact")
