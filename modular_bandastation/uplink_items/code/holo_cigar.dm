/// A Syndicate cigar that removes the extra spread from firing two guns while smoked.
/obj/item/cigarette/holo_cigar
	name = "holo-cigar"
	desc = "Голографическая сигара из Солнечной системы. Пока она зажжена и находится во рту, стрельба с двух рук не добавляет разброса."
	// Sprites from Paradise-SS220 (CC BY-SA 3.0).
	// https://github.com/ss220club/Paradise-SS220/tree/0fffca1f1f29a63aff49d9b56524813eedf82c6d
	icon = 'modular_bandastation/uplink_items/icons/holo_cigar.dmi'
	worn_icon = 'modular_bandastation/uplink_items/icons/holo_cigar_mask.dmi'
	lefthand_file = 'modular_bandastation/uplink_items/icons/holo_cigar_lefthand.dmi'
	righthand_file = 'modular_bandastation/uplink_items/icons/holo_cigar_righthand.dmi'
	icon_state = "holo_cigar"
	inhand_icon_state = "holo_cigar"
	icon_on = "holo_cigar_on"
	icon_off = "holo_cigar"
	inhand_icon_on = "holo_cigar_on"
	inhand_icon_off = "holo_cigar"

/datum/uplink_item/badass/holo_cigar
	name = "Голо-сигара"
	desc = "Зажгите сигару и возьмите её в рот, чтобы стрелять с двух рук без дополнительного разброса."
	item = /obj/item/cigarette/holo_cigar
	cost = 1
	purchasable_from = UPLINK_TRAITORS
