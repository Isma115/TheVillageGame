extends RefCounted
class_name DoctorService

var _wallet: WalletService
var _inventory: InventoryService
var _active_doctor: DoctorDefinition


func initialize(
	wallet: WalletService,
	inventory: InventoryService = null
) -> void:
	_wallet = wallet
	_inventory = inventory
	_active_doctor = null


func open(doctor: DoctorDefinition) -> bool:
	if doctor == null or _wallet == null:
		return false
	_active_doctor = doctor
	return true


func close() -> void:
	_active_doctor = null


func is_open() -> bool:
	return _active_doctor != null


func active_doctor() -> DoctorDefinition:
	return _active_doctor


func bandage_item() -> ItemDefinition:
	return _active_doctor.bandage_item if is_open() else null


func bandage_cost() -> int:
	return _active_doctor.bandage_cost if is_open() else 0


func bandage_quantity() -> int:
	return _active_doctor.bandage_quantity if is_open() else 0


func can_buy_bandage() -> bool:
	var item := bandage_item()
	return (
		item != null
		and _inventory != null
		and _wallet != null
		and _inventory.space_for(item.id) >= bandage_quantity()
		and _wallet.can_afford(bandage_cost())
	)


func buy_bandage() -> Dictionary:
	var item := bandage_item()
	if item == null or _inventory == null or _wallet == null:
		return _failed_purchase("El medico no tiene vendas disponibles.")
	if not _wallet.can_afford(bandage_cost()):
		return _failed_purchase("No tienes suficientes monedas para comprar la venda.")
	if _inventory.space_for(item.id) < bandage_quantity():
		return _failed_purchase("No tienes espacio para guardar la venda.")
	if not _wallet.spend(bandage_cost()):
		return _failed_purchase("No se pudo completar la compra.")

	var added := _inventory.add_item(item, bandage_quantity())
	if added != bandage_quantity():
		_wallet.earn(bandage_cost())
		return _failed_purchase("No se pudo guardar la venda en el inventario.")

	return {
		"success": true,
		"message": "Has comprado %d %s por %d monedas." % [
			bandage_quantity(),
			item.label.to_lower(),
			bandage_cost()
		],
		"balance": _wallet.balance()
	}


func consult(player: PlayerActor) -> Dictionary:
	if not is_open():
		return _failed_report("No hay ninguna consulta médica abierta.")
	if player == null:
		return _failed_report("No se pudo leer el estado del personaje.")

	var cost := _active_doctor.consultation_cost
	if not _wallet.can_afford(cost) or not _wallet.spend(cost):
		return _failed_report(
			"Necesitas %d monedas para consultar al médico." % cost
		)

	return {
		"paid": true,
		"cost": cost,
		"balance": _wallet.balance(),
		"health": player.health,
		"maximum_health": player.maximum_health,
		"maximum_stamina": player.maximum_stamina,
		"health_status": health_status(player.health_ratio())
	}


func health_status(ratio: float) -> String:
	if ratio >= 0.8:
		return "Saludable"
	if ratio > 0.35:
		return "Herido"
	if ratio > 0.0:
		return "Crítico"
	return "Sin vida"


func _failed_report(message: String) -> Dictionary:
	return {
		"paid": false,
		"cost": (
			_active_doctor.consultation_cost
			if _active_doctor != null
			else 0
		),
		"balance": _wallet.balance() if _wallet != null else 0,
		"message": message
	}


func _failed_purchase(message: String) -> Dictionary:
	return {
		"success": false,
		"message": message,
		"balance": _wallet.balance() if _wallet != null else 0
	}
