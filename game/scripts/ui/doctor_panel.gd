extends PanelContainer
class_name DoctorPanel

signal close_requested
signal diagnosis_requested

@onready var title_label: Label = %DoctorTitle
@onready var cost_label: Label = %DoctorCost
@onready var status_label: Label = %DoctorStatus
@onready var report_rows: VBoxContainer = %DoctorReportRows
@onready var health_status_label: Label = %DoctorHealthStatus
@onready var health_value_label: Label = %DoctorHealthValue
@onready var stamina_value_label: Label = %DoctorStaminaValue
@onready var balance_label: Label = %DoctorBalance
@onready var diagnose_button: Button = %DiagnoseButton
@onready var close_button: Button = %DoctorClose

var _active_doctor: DoctorDefinition


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	diagnose_button.pressed.connect(_on_diagnose_pressed)
	visible = false


func show_doctor_menu(doctor: DoctorDefinition) -> void:
	_active_doctor = doctor
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

	visible = true
	close_button.grab_focus()


func hide_consultation() -> void:
	visible = false


func _on_diagnose_pressed() -> void:
	if _active_doctor != null:
		diagnosis_requested.emit()


func _on_close_pressed() -> void:
	close_requested.emit()
