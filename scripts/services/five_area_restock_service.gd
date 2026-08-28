class_name FiveAreaRestockService
extends RefCounted

## Stateless facade for hold-to-restock interactions. GameSessionStore owns the
## transaction so coins, inventory, partial hold progress, and save writes stay
## in one formal five-area state transition.

var _session: Node


func _init(session: Node) -> void:
	_session = session


func status(stock_id: StringName) -> Dictionary:
	if _session == null or not _session.has_method("five_area_restock_status"):
		return {"success": false, "reason": &"service_unavailable"}
	return Dictionary(_session.call("five_area_restock_status", stock_id))


func advance_hold(stock_id: StringName, delta: float) -> Dictionary:
	if _session == null or not _session.has_method("advance_five_area_restock_hold"):
		return {"success": false, "reason": &"service_unavailable"}
	return Dictionary(_session.call("advance_five_area_restock_hold", stock_id, maxf(delta, 0.0)))


func release(stock_id: StringName) -> Dictionary:
	# A committed unit stays in inventory, but the unfinished cycle is gesture
	# state. Releasing or moving away cancels that remainder without charging it.
	if _session != null and _session.has_method("cancel_five_area_restock_hold"):
		return Dictionary(_session.call("cancel_five_area_restock_hold", stock_id))
	return status(stock_id)
