/obj/item/clothing/under/expedition
	name = "форма экспедиционного корпуса"
	desc = "Практичная полевая форма экспедиционного корпуса Нанотрейзен."
	icon = 'modular_bandastation/explorers/icons/uniforms.dmi'
	worn_icon = 'modular_bandastation/explorers/icons/uniforms_worn.dmi'
	icon_state = "greyutility"
	worn_icon_state = "greyutility_s"
	inhand_icon_state = "gy_suit"
	can_adjust = FALSE

/obj/item/clothing/under/expedition/leader
	name = "форма главы экспедиционного корпуса"
	icon_state = "navycombat"
	worn_icon_state = "navycombat_s"

/obj/item/clothing/under/expedition/pilot
	name = "форма пилота экспедиционного корпуса"
	icon_state = "greenutility"
	worn_icon_state = "greenutility_s"

/obj/item/clothing/under/expedition/engineer
	name = "форма полевого инженера"
	icon_state = "tanutility"
	worn_icon_state = "tanutility_s"

/obj/item/clothing/shoes/jackboots/expedition
	name = "служебные ботинки экспедиционного корпуса"
	desc = "Начищенные служебные ботинки из синтетической кожи."
	icon = 'modular_bandastation/explorers/icons/shoes.dmi'
	worn_icon = 'modular_bandastation/explorers/icons/shoes_worn.dmi'
	icon_state = "duty"
	worn_icon_state = "duty"
	inhand_icon_state = "jackboots"

/obj/item/clothing/gloves/color/black/expedition
	name = "рабочие перчатки экспедиционного корпуса"
	desc = "Плотные чёрные перчатки для полевых работ."
	icon = 'modular_bandastation/explorers/icons/gloves.dmi'
	worn_icon = 'modular_bandastation/explorers/icons/gloves_worn.dmi'
	icon_state = "black"
	worn_icon_state = "bgloves"
	greyscale_config = null
	greyscale_config_worn = null

/obj/item/clothing/head/helmet/expedition_pilot
	name = "пилотский шлем экспедиционного корпуса"
	desc = "Корпоративный шлем для пилота экспедиционного корабля."
	icon = 'modular_bandastation/explorers/icons/head.dmi'
	worn_icon = 'modular_bandastation/explorers/icons/head_worn.dmi'
	icon_state = "pilotnt"
	worn_icon_state = "pilotnt"
	inhand_icon_state = "helmet"

/obj/item/clothing/suit/toggle/expedition
	name = "куртка экспедиционного корпуса"
	desc = "Удобная куртка с парой карманов для личных вещей."
	icon = 'modular_bandastation/explorers/icons/suits.dmi'
	worn_icon = 'modular_bandastation/explorers/icons/suits_worn.dmi'
	icon_state = "trackjacket"
	inhand_icon_state = "syndicate-black"
	body_parts_covered = CHEST|ARMS

/obj/item/clothing/suit/toggle/expedition/Initialize(mapload)
	. = ..()
	create_storage(max_slots = 2, max_specific_storage = WEIGHT_CLASS_SMALL, max_total_storage = WEIGHT_CLASS_SMALL * 2)

/obj/item/clothing/accessory/expedition_webbing
	name = "разгрузка экспедиционного корпуса"
	desc = "Прочная система ремней и четырёх небольших подсумков. Крепится к форме."
	icon = 'modular_bandastation/explorers/icons/accessories.dmi'
	worn_icon = 'modular_bandastation/explorers/icons/accessories_worn.dmi'
	icon_state = "webbing_large"
	minimize_when_attached = FALSE
	above_suit = FALSE

/obj/item/clothing/accessory/expedition_webbing/Initialize(mapload)
	. = ..()
	create_storage(max_slots = 4, max_specific_storage = WEIGHT_CLASS_SMALL, max_total_storage = WEIGHT_CLASS_SMALL * 4)

/obj/item/clothing/accessory/expedition_sheath
	name = "набедренные ножны экспедиционного корпуса"
	desc = "Синтетические кожаные ножны для полевого клинка. Крепятся к форме."
	icon = 'modular_bandastation/explorers/icons/accessories.dmi'
	worn_icon = 'modular_bandastation/explorers/icons/accessories_worn.dmi'
	icon_state = "holster_machete"
	worn_icon_state = "holster_machete"
	icon_state_is_worn = FALSE
	minimize_when_attached = FALSE
	above_suit = FALSE
	attachment_slot = GROIN

/obj/item/clothing/accessory/expedition_sheath/Initialize(mapload)
	. = ..()
	create_storage(max_slots = 1, max_specific_storage = WEIGHT_CLASS_NORMAL, max_total_storage = WEIGHT_CLASS_NORMAL, canhold = list(/obj/item/knife, /obj/item/hatchet))

/obj/item/clothing/accessory/expedition_sheath/update_icon_state()
	icon_state = "[initial(icon_state)][length(contents) ? "-full" : ""]"
	worn_icon_state = icon_state
	return ..()

// The uniform draws this sheath, so a blade going in or out has to redraw the uniform.
/obj/item/clothing/accessory/expedition_sheath/update_appearance(updates)
	. = ..()
	if(istype(loc, /obj/item/clothing/under))
		loc.update_appearance()

// The belt variant leaves the uniform's single accessory-storage slot free for webbing.
/obj/item/storage/belt/expedition_sheath
	name = "поясные ножны экспедиционного корпуса"
	desc = "Синтетические кожаные ножны для полевого клинка на собственном ремне."
	icon = 'modular_bandastation/explorers/icons/accessories.dmi'
	worn_icon = 'modular_bandastation/explorers/icons/accessories_worn.dmi'
	icon_state = "holster_machete"
	worn_icon_state = "holster_machete"
	inhand_icon_state = "utility"

/obj/item/storage/belt/expedition_sheath/Initialize(mapload)
	. = ..()
	create_storage(max_slots = 1, max_specific_storage = WEIGHT_CLASS_NORMAL, max_total_storage = WEIGHT_CLASS_NORMAL, canhold = list(/obj/item/knife, /obj/item/hatchet))
	AddElement(/datum/element/update_icon_updates_onmob, ITEM_SLOT_BELT)

/obj/item/storage/belt/expedition_sheath/update_icon_state()
	icon_state = "[initial(icon_state)][length(contents) ? "-full" : ""]"
	worn_icon_state = icon_state
	return ..()
