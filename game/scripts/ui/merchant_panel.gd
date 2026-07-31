extends PanelContainer
class_name MerchantPanel

signal buy_requested(offer_id: StringName)
signal sell_requested(offer_id: StringName)
signal close_requested

@onready var title_label: Label = %MerchantTitle
@onready var coins_label: Label = %MerchantCoins
@onready var offers_list: VBoxContainer = %MerchantOffers
@onready var status_label: Label = %MerchantStatus
@onready var close_button: Button = %MerchantClose

var _merchant: MerchantDefinition
var _merchant_service: MerchantService


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	visible = false


func show_shop(
	merchant: MerchantDefinition,
	merchant_service: MerchantService
) -> void:
	_merchant = merchant
	_merchant_service = merchant_service
	status_label.text = ""
	visible = true
	_refresh_view()
	close_button.grab_focus()


func refresh(message := "") -> void:
	if not visible:
		return
	if not message.is_empty():
		status_label.text = message
	_refresh_view()


func hide_shop() -> void:
	visible = false
	_merchant = null
	_merchant_service = null


func _refresh_view() -> void:
	if _merchant == null or _merchant_service == null:
		return

	title_label.text = _merchant.display_name
	coins_label.text = "Monedas: %d" % _merchant_service.balance()
	_clear_offers()

	for offer in _merchant_service.offers():
		_add_offer_row(offer)


func _add_offer_row(offer: MerchantOffer) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 42.0)
	row.add_theme_constant_override("separation", 8)
	offers_list.add_child(row)

	var description := Label.new()
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.text = _offer_description(offer)
	description.add_theme_font_size_override("font_size", 13)
	row.add_child(description)

	if offer.sell_price > 0:
		var buy_button := Button.new()
		buy_button.custom_minimum_size = Vector2(128.0, 34.0)
		buy_button.text = "Comprar · %d" % offer.sell_price
		buy_button.disabled = not _merchant_service.can_buy(offer)
		buy_button.tooltip_text = "Comprar %s" % offer.display_name()
		buy_button.pressed.connect(_on_buy_pressed.bind(offer.id))
		row.add_child(buy_button)

	if offer.buy_price > 0:
		var sell_button := Button.new()
		sell_button.custom_minimum_size = Vector2(128.0, 34.0)
		sell_button.text = "Vender · %d" % offer.buy_price
		sell_button.disabled = not _merchant_service.can_sell(offer)
		sell_button.tooltip_text = "Vender %s" % offer.display_name()
		sell_button.pressed.connect(_on_sell_pressed.bind(offer.id))
		row.add_child(sell_button)


func _offer_description(offer: MerchantOffer) -> String:
	var quantity_prefix := (
		"%d × " % offer.transaction_quantity
		if offer.transaction_quantity > 1
		else ""
	)
	return "%s%s" % [quantity_prefix, offer.display_name()]


func _clear_offers() -> void:
	for child in offers_list.get_children():
		offers_list.remove_child(child)
		child.queue_free()


func _on_buy_pressed(offer_id: StringName) -> void:
	buy_requested.emit(offer_id)


func _on_sell_pressed(offer_id: StringName) -> void:
	sell_requested.emit(offer_id)


func _on_close_pressed() -> void:
	close_requested.emit()
