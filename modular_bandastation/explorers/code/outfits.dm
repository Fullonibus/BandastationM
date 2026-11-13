/datum/outfit/job/explorer
	name = JOB_EXPLORER
	jobtype = /datum/job/explorer
	uniform = /obj/item/clothing/under/expedition
	gloves = /obj/item/clothing/gloves/color/black/expedition
	shoes = /obj/item/clothing/shoes/jackboots/expedition
	id_trim = /datum/id_trim/job/explorer
	ear_right = /obj/item/radio/headset/headset_cargo/explorer
	backpack = /obj/item/storage/backpack/explorer
	satchel = /obj/item/storage/backpack/satchel/explorer
	duffelbag = /obj/item/storage/backpack/duffelbag/explorer
	box = /obj/item/storage/box/survival/mining
	belt = /obj/item/modular_computer/pda/crew/explorer
	l_pocket = /obj/item/gps/expedition
	r_pocket = /obj/item/flashlight
	implants = list(/obj/item/implant/resonance)
	backpack_contents = list(
		/obj/item/stationtrauma_distress_beacon = 1,
		/obj/item/storage/box/stationtrauma_research = 1,
	)

/datum/outfit/job/explorer/leader
	name = JOB_EXPEDITION_LEADER
	jobtype = /datum/job/explorer/leader
	uniform = /obj/item/clothing/under/expedition/leader
	id = /obj/item/card/id/advanced/silver
	id_trim = /datum/id_trim/job/explorer/leader
	ear_right = /obj/item/radio/headset/headset_cargo/explorer/leader
	l_hand = /obj/item/clipboard

/datum/outfit/job/explorer/pilot
	name = JOB_EXPEDITION_PILOT
	jobtype = /datum/job/explorer/pilot
	uniform = /obj/item/clothing/under/expedition/pilot
	id_trim = /datum/id_trim/job/explorer/pilot
	head = /obj/item/clothing/head/helmet/expedition_pilot
	suit = /obj/item/clothing/suit/toggle/expedition

/datum/outfit/job/explorer/medic
	name = JOB_EXPEDITION_MEDIC
	jobtype = /datum/job/explorer/medic
	id_trim = /datum/id_trim/job/explorer/medic
	gloves = /obj/item/clothing/gloves/latex/nitrile
	glasses = /obj/item/clothing/glasses/hud/health
	belt = /obj/item/storage/belt/medical/paramedic
	l_pocket = /obj/item/modular_computer/pda/crew/explorer
	pda_slot = ITEM_SLOT_LPOCKET
	box = /obj/item/storage/box/survival/medical
	backpack_contents = list(
		/obj/item/stationtrauma_distress_beacon = 1,
		/obj/item/storage/medkit/regular = 1,
		/obj/item/emergency_bed = 1,
		/obj/item/gps/expedition = 1,
	)

/datum/outfit/job/explorer/engineer
	name = JOB_EXPEDITION_ENGINEER
	jobtype = /datum/job/explorer/engineer
	uniform = /obj/item/clothing/under/expedition/engineer
	id_trim = /datum/id_trim/job/explorer/engineer
	gloves = /obj/item/clothing/gloves/color/yellow
	head = /obj/item/clothing/head/utility/hardhat/welding/up
	belt = /obj/item/storage/belt/utility/full/engi
	l_pocket = /obj/item/modular_computer/pda/crew/explorer
	pda_slot = ITEM_SLOT_LPOCKET
	box = /obj/item/storage/box/survival/engineer
	skillchips = list(/obj/item/skillchip/job/engineer)
	backpack_contents = list(
		/obj/item/stationtrauma_distress_beacon = 1,
		/obj/item/stack/sheet/iron/fifty = 1,
		/obj/item/gps/expedition = 1,
	)

/datum/outfit/plasmaman/explorer
	name = "Explorer Plasmaman"
	head = /obj/item/clothing/head/helmet/space/plasmaman/cargo
	uniform = /obj/item/clothing/under/plasmaman/cargo
