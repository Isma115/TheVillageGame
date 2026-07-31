extends RefCounted
class_name MerchantService

var _inventory: InventoryService
var _wallet: WalletService
var _tool_service: ToolService
var _active_merchant: MerchantDefinition


func initialize(
	inventory: InventoryService,
	wallet: WalletService,
	tool_service: ToolService
) -> void:
	_inventory = inventory
	_wallet = wallet
	_tool_service = tool_service
	_active_merchant = null


func open(merchant: MerchantDefinition) -> bool:
	if merchant == null or _inventory == null or _wallet == null:
		return false
	_active_merchant = merchant
	return true


func close() -> void:
	_active_merchant = null


func is_open() -> bool:
	return _active_merchant != null


func active_merchant() -> MerchantDefinition:
	return _active_merchant


func balance() -> int:
	return _wallet.balance() if _wallet != null else 0


func inventory_service() -> InventoryService:
	return _inventory


func offers() -> Array[MerchantOffer]:
	return _active_merchant.valid_offers() if is_open() else []


func offer_for(offer_id: StringName) -> MerchantOffer:
	return _active_merchant.offer_for(offer_id) if is_open() else null


func can_buy(offer: MerchantOffer) -> bool:
	if (
		offer == null
		or offer.sell_price <= 0
		or _wallet == null
		or not _wallet.can_afford(offer.sell_price)
	):
		return false

	if offer.item != null:
		return _inventory.space_for(offer.item.id) >= offer.transaction_quantity
	if offer.tool != null and _tool_service != null:
		return _tool_service.can_acquire_tool(offer.tool.id)
	return false


func can_sell(offer: MerchantOffer) -> bool:
	return (
		offer != null
		and offer.buy_price > 0
		and offer.item != null
		and _inventory != null
		and _inventory.has_item(offer.item.id, offer.transaction_quantity)
	)


func buy(offer_id: StringName) -> String:
	var offer := offer_for(offer_id)
	if offer == null or offer.sell_price <= 0:
		return "Ese artículo no está a la venta."
	if not can_buy(offer):
		return _buy_failure_message(offer)
	if not _wallet.spend(offer.sell_price):
		return "No tienes suficientes monedas."

	if offer.item != null:
		var added := _inventory.add_item(offer.item, offer.transaction_quantity)
		if added != offer.transaction_quantity:
			_wallet.earn(offer.sell_price)
			return "No tienes espacio para ese artículo."
	else:
		if not _tool_service.acquire_tool(offer.tool.id):
			_wallet.earn(offer.sell_price)
			return "No se pudo adquirir la herramienta."

	return "Has comprado %s por %d monedas." % [
		offer.display_name(),
		offer.sell_price
	]


func sell(offer_id: StringName) -> String:
	var offer := offer_for(offer_id)
	if offer == null or offer.buy_price <= 0 or offer.item == null:
		return "El mercader no compra ese artículo."
	if not can_sell(offer):
		return "No tienes suficiente %s para vender." % offer.display_name().to_lower()

	var removed := _inventory.remove_item(
		offer.item.id,
		offer.transaction_quantity
	)
	if removed != offer.transaction_quantity:
		return "No se pudo completar la venta."
	_wallet.earn(offer.buy_price)
	return "Has vendido %d × %s por %d monedas." % [
		offer.transaction_quantity,
		offer.display_name(),
		offer.buy_price
	]


func _buy_failure_message(offer: MerchantOffer) -> String:
	if _wallet == null or not _wallet.can_afford(offer.sell_price):
		return "No tienes suficientes monedas."
	if offer.item != null:
		return "No tienes espacio para ese artículo."
	if offer.tool != null and _tool_service != null:
		return "Ya tienes esa herramienta o no puede reemplazarse todavía."
	return "No puedes comprar ese artículo ahora."
