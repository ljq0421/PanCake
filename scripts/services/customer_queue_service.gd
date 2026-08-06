class_name CustomerQueueService
extends RefCounted

const ORDER_SERVICE_SCRIPT := preload("res://scripts/services/order_service.gd")
const DEFAULT_QUEUE_SIZE := 3
const CUSTOMER_IDS: Array[StringName] = [
	&"customer_01",
	&"customer_02",
	&"customer_03",
]

var _order_service: RefCounted
var _queue: Array[Dictionary] = []
var _customer_cursor := 0


func _init(next_order_service: RefCounted = null, queue_size: int = DEFAULT_QUEUE_SIZE) -> void:
	_order_service = next_order_service if next_order_service != null else ORDER_SERVICE_SCRIPT.new()
	for index in maxi(queue_size, 1):
		_queue.append(_create_customer())


func current_customer() -> Dictionary:
	if _queue.is_empty():
		_queue.append(_create_customer())
	return _queue.front().duplicate(true)


func waiting_customers() -> Array[Dictionary]:
	var waiting: Array[Dictionary] = []
	for index in range(1, _queue.size()):
		waiting.append(_queue[index].duplicate(true))
	return waiting


func advance_queue() -> Dictionary:
	if _queue.is_empty():
		_queue.append(_create_customer())
	_queue.pop_front()
	_queue.append(_create_customer())
	return current_customer()


func queue_snapshot() -> Array[Dictionary]:
	return _queue.duplicate(true)


## Continue-game restore uses the persisted formal order as the sole current
## customer.  Future customers are generated only after that order leaves the
## counter, so scene loading never advances the deterministic order stream.
func restore_active_customer(order: Dictionary, customer_id: StringName = &"customer_01") -> void:
	_queue.clear()
	_queue.append({"id": customer_id, "order": order.duplicate(true)})


func set_order_provider(next_order_service: RefCounted) -> void:
	_order_service = next_order_service


func _create_customer() -> Dictionary:
	var customer_id := CUSTOMER_IDS[_customer_cursor % CUSTOMER_IDS.size()]
	_customer_cursor += 1
	return {
		"id": customer_id,
		"order": _order_service.call("next_order"),
	}
