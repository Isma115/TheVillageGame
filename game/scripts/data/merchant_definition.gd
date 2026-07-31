extends Resource
class_name MerchantDefinition

@export var id: StringName = &"merchant"
@export var display_name := "Mercader"
@export var offers: Array[MerchantOffer] = []


func offer_for(offer_id: StringName) -> MerchantOffer:
	for offer in offers:
		if offer != null and offer.id == offer_id:
			return offer
	return null


func valid_offers() -> Array[MerchantOffer]:
	var result: Array[MerchantOffer] = []
	for offer in offers:
		if offer != null:
			result.append(offer)
	return result


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if String(id).is_empty():
		errors.append("Un mercader no tiene id.")
	if display_name.strip_edges().is_empty():
		errors.append("El mercader '%s' no tiene nombre visible." % id)
	if offers.is_empty():
		errors.append("El mercader '%s' no tiene ofertas." % id)

	var seen_ids: Dictionary = {}
	for offer in valid_offers():
		errors.append_array(offer.validate())
		if seen_ids.has(offer.id):
			errors.append("La oferta '%s' está duplicada en el mercader." % offer.id)
		seen_ids[offer.id] = true
	return errors
