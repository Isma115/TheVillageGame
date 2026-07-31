extends RefCounted
class_name WalletService

signal balance_changed(balance: int)

var _balance := 0


func initialize(starting_balance: int) -> void:
	_balance = maxi(starting_balance, 0)


func balance() -> int:
	return _balance


func can_afford(amount: int) -> bool:
	return amount >= 0 and _balance >= amount


func earn(amount: int) -> int:
	if amount <= 0:
		return _balance
	_balance += amount
	balance_changed.emit(_balance)
	return _balance


func spend(amount: int) -> bool:
	if amount <= 0 or _balance < amount:
		return false
	_balance -= amount
	balance_changed.emit(_balance)
	return true


func set_balance(value: int) -> void:
	_balance = maxi(value, 0)
	balance_changed.emit(_balance)


func snapshot() -> Dictionary:
	return {"balance": _balance}


func restore(snapshot_data: Dictionary) -> void:
	if not snapshot_data.has("balance"):
		return
	_balance = maxi(int(snapshot_data.get("balance", _balance)), 0)
	balance_changed.emit(_balance)
