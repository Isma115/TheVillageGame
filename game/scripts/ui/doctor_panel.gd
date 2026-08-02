extends PanelContainer
class_name DoctorPanel

signal close_requested
signal diagnosis_requested
signal bandage_purchase_requested

@onready var title_label: Label = %DoctorTitle
@onready var cost_label: Label = %DoctorCost
@onready var status_label: Label = %DoctorStatus
@onready var report_rows: VBoxContainer = %DoctorReportRows
@onready var health_status_label: Label = %DoctorHealthStatus
@onready var health_value_label: Label = %DoctorHealthValue
@onready var stamina_value_label: Label = %DoctorStaminaValue
@onready var balance_label: Label = %DoctorBalance
@onready var bandage_offer_label: Label = %DoctorBandageOffer
@onready var buy_bandage_button: Button = %DoctorBandageButton
@onready var diagnose_button: Button = %DiagnoseButton
@onready var close_button: Button = %DoctorClose

var _active_doctor: DoctorDefinition
var _doctor_service: DoctorService


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	diagnose_button.pressed.connect(_on_diagnose_pressed)
	buy_bandage_button.pressed.connect(_on_buy_bandage_pressed)
	visible = false


func show_doctor_menu(
	doctor: DoctorDefinition,
	doctor_service: DoctorService = null
) -> void:
	_active_doctor = doctor
	_doctor_service = doctor_service
	var service_name := (
		doctor.service_name
		if doctor != null
		else "Consulta médica"
	)
	var cost := (
		doctor.consultation_cost
		if doctor != null
		else 5
	)
	title_label.text = service_name
	cost_label.text = "Coste: %d monedas" % cost
	report_rows.visible = false
	diagnose_button.show()
	status_label.text = "¿Deseas que realice un diagnóstico de tu estado?"
	status_label.modulate = Color("#d9ec70")
	_refresh_bandage_offer()
	visible = true
	diagnose_button.grab_focus()


func show_consultation(doctor: DoctorDefinition, report: Dictionary) -> void:
	var service_name := (
		doctor.service_name
		if doctor != null
		else "Consulta médica"
	)
	var cost := int(report.get("cost", doctor.consultation_cost if doctor != null else 5))
	title_label.text = service_name
	cost_label.text = "Coste: %d monedas" % cost
	report_rows.visible = bool(report.get("paid", false))
	diagnose_button.hide()

	if report_rows.visible:
		status_label.text = "Consulta realizada. El informe queda registrado abajo."
		status_label.modulate = Color("#d9ec70")
		health_status_label.text = "ESTADO DE SALUD  ·  %s" % str(
			report.get("health_status", "Desconocido")
		).to_upper()
		health_value_label.text = "SALUD (HP)  ·  %d / %d" % [
			roundi(float(report.get("health", 0.0))),
			roundi(float(report.get("maximum_health", 0.0)))
		]
		stamina_value_label.text = "ESTAMINA MÁXIMA  ·  %d" % roundi(
			float(report.get("maximum_stamina", 0.0))
		)
		balance_label.text = "Monedas restantes  ·  %d" % int(
			report.get("balance", 0)
		)
	else:
		status_label.text = str(
			report.get("message", "No se pudo realizar la consulta.")
		)
		status_label.modulate = Color("#ff9d8d")

	_refresh_bandage_offer()
	visible = true
	close_button.grab_focus()


func show_bandage_purchase_result(result: Dictionary) -> void:
	status_label.text = str(result.get("message", "No se pudo completar la compra."))
	status_label.modulate = Color(
		"#d9ec70" if bool(result.get("success", false)) else "#ff9d8d"
	)
	_refresh_bandage_offer()
	visible = true


func _refresh_bandage_offer() -> void:
	if _active_doctor == null or _active_doctor.bandage_item == null:
		bandage_offer_label.text = "No hay vendas disponibles."
		buy_bandage_button.disabled = true
		return

	var item := _active_doctor.bandage_item
	bandage_offer_label.text = "%s  -  %d monedas" % [
		item.label,
		_active_doctor.bandage_cost
	]
	buy_bandage_button.tooltip_text = "Comprar %s" % item.label
	buy_bandage_button.disabled = (
		_doctor_service == null
		or not _doctor_service.can_buy_bandage()
	)


func hide_consultation() -> void:
	visible = false
	_active_doctor = null
	_doctor_service = null


func _on_diagnose_pressed() -> void:
	if _active_doctor != null:
		diagnosis_requested.emit()


func _on_buy_bandage_pressed() -> void:
	if _active_doctor != null:
		bandage_purchase_requested.emit()


func _on_close_pressed() -> void:
	close_requested.emit()
