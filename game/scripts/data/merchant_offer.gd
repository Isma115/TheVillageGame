extends Resource
class_name MerchantOffer

@export var id: StringName = &"offer"
@export var label := "Artículo"
@export var item: ItemDefinition
@export var tool: ToolDefinition
@export_range(0, 999999, 1) var sell_price := 0
@export_range(0, 999999, 1) var buy_price := 0
@export_range(1, 999999, 1) var transaction_quantity := 1


func target_id() -> StringName:
	if item != null:
		return item.id
	if tool != null:
		return tool.id
	return &""


func display_name() -> String:
	if not label.strip_edges().is_empty():
		return label
	if item != null:
		return item.label
	if tool != null:
		return tool.label
	return "Artículo"


func is_tool_offer() -> bool:
	return tool != null


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if String(id).is_empty():
		errors.append("Una oferta de mercader no tiene id.")
	if item == null and tool == null:
		errors.append("La oferta '%s' no tiene artículo ni herramienta." % id)
	if item != null and tool != null:
		errors.append("La oferta '%s' mezcla artículo y herramienta." % id)
	if sell_price <= 0 and buy_price <= 0:
		errors.append("La oferta '%s' no tiene ningún precio válido." % id)
	if transaction_quantity <= 0:
		errors.append("La oferta '%s' tiene una cantidad inválida." % id)
	if tool != null and transaction_quantity != 1:
		errors.append("La oferta de herramienta '%s' debe vender una unidad." % id)
	return errors
