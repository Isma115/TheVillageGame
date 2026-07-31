extends RefCounted
class_name DoctorService

var _wallet: WalletService
var _active_doctor: DoctorDefinition


func initialize(wallet: WalletService) -> void:
	_wallet = wallet
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
