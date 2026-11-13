// Field gear of the corps after the NT explorers of SierraBay: role lockers, anomaly suit,
// leader's machete.

// ===== Role lockers =====
// Only what the outfit and the wardrobe do not already give: field tools, a blade and the role's own kit.

/obj/structure/closet/secure_closet/expedition
	name = "шкафчик исследователя"
	icon_state = "mining"
	req_access = list(ACCESS_EXPLORER)
	/// The blade this locker holds.
	var/machete_type = /obj/item/hatchet/expedition_machete

/obj/structure/closet/secure_closet/expedition/PopulateContents()
	. = ..()
	generate_items_inside(list(
		/obj/item/radio = 1,
		/obj/item/analyzer = 1,
		/obj/item/binoculars = 1,
		/obj/item/stack/marker_beacon/ten = 1,
	), src)
	new machete_type(src)

/obj/structure/closet/secure_closet/expedition/leader
	name = "шкафчик главы экспедиционного корпуса"
	icon_state = "qm"
	req_access = list(ACCESS_EXPEDITION_LEADER)
	machete_type = /obj/item/hatchet/expedition_machete/deluxe

/obj/structure/closet/secure_closet/expedition/leader/PopulateContents()
	. = ..()
	generate_items_inside(list(
		/obj/item/taperecorder = 1,
		/obj/item/tape/random = 1,
		/obj/item/assembly/flash/handheld = 1,
		/obj/item/encryptionkey/expedition = 2,
	), src)

/obj/structure/closet/secure_closet/expedition/pilot
	name = "шкафчик пилота экспедиционного корпуса"

/obj/structure/closet/secure_closet/expedition/pilot/PopulateContents()
	. = ..()
	generate_items_inside(list(/obj/item/storage/belt/utility/full = 1), src)

/obj/structure/closet/secure_closet/expedition/medic
	name = "шкафчик полевого медика"
	icon_state = "med"

/obj/structure/closet/secure_closet/expedition/medic/PopulateContents()
	. = ..()
	generate_items_inside(list(
		/obj/item/healthanalyzer = 1,
		/obj/item/storage/medkit/advanced = 1,
	), src)

/obj/structure/closet/secure_closet/expedition/engineer
	name = "шкафчик полевого инженера"
	icon_state = "eng"

/obj/structure/closet/secure_closet/expedition/engineer/PopulateContents()
	. = ..()
	generate_items_inside(list(
		/obj/item/multitool = 1,
		/obj/item/flashlight/seclite = 1,
	), src)

// ===== Anomaly suit =====

/// Bio suit cut for work around anomalies and artifacts; its bio rating is what shields from them.
/obj/item/clothing/suit/bio_suit/expedition_anomaly
	name = "антианомальный костюм"
	desc = "Костюм, защищающий от экзотических инопланетных энергий и биологического заражения."
	icon = 'modular_bandastation/explorers/icons/gear.dmi'
	worn_icon = 'modular_bandastation/explorers/icons/gear_worn.dmi'
	lefthand_file = 'modular_bandastation/explorers/icons/gear_lefthand.dmi'
	righthand_file = 'modular_bandastation/explorers/icons/gear_righthand.dmi'
	icon_state = "bio_anom"
	inhand_icon_state = "bio_anom"
	supports_variations_flags = NONE
	bodyshapes_with_variations = NONE

/obj/item/clothing/head/bio_hood/expedition_anomaly
	name = "антианомальный капюшон"
	desc = "Капюшон, защищающий голову и лицо от экзотических инопланетных энергий и биологического заражения."
	icon = 'modular_bandastation/explorers/icons/gear.dmi'
	worn_icon = 'modular_bandastation/explorers/icons/gear_worn.dmi'
	lefthand_file = 'modular_bandastation/explorers/icons/gear_lefthand.dmi'
	righthand_file = 'modular_bandastation/explorers/icons/gear_righthand.dmi'
	icon_state = "bio_anom_hood"
	inhand_icon_state = "bio_anom_hood"
	dirt_state = null

/obj/structure/closet/l3closet/expedition
	name = "шкаф антианомальной защиты"
	icon_door = "bio_sci"

/obj/structure/closet/l3closet/expedition/PopulateContents()
	new /obj/item/clothing/suit/bio_suit/expedition_anomaly(src)
	new /obj/item/clothing/head/bio_hood/expedition_anomaly(src)
	new /obj/item/clothing/mask/breath(src)
	new /obj/item/tank/internals/oxygen(src)

// ===== Leader's machete =====

/obj/item/hatchet/expedition_machete/deluxe
	name = "парадное мачете главы корпуса"
	desc = "Отменное мачете с полированным клинком, деревянной рукоятью и кожаным темляком."
	icon_state = "machetedx"
