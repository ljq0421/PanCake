class_name PaymentCoinModel
extends RefCounted

signal changed

const DENOMINATIONS: Array[int] = [20, 10, 5, 2, 1]

var pending_total := 0
var pending_denominations: Array[int] = []


static func decompose(amount: int) -> Array[int]:
	var remaining := maxi(amount, 0)
	var coins: Array[int] = []
	for denomination in DENOMINATIONS:
		while remaining >= denomination:
			coins.append(denomination)
			remaining -= denomination
	return coins


func add_payment(amount: int) -> Array[int]:
	var coins := decompose(amount)
	if coins.is_empty():
		return coins
	pending_total += maxi(amount, 0)
	pending_denominations.append_array(coins)
	changed.emit()
	return coins


func has_pending() -> bool:
	return pending_total > 0 and not pending_denominations.is_empty()


func collect_all() -> int:
	var collected := pending_total
	pending_total = 0
	pending_denominations.clear()
	if collected > 0:
		changed.emit()
	return collected
