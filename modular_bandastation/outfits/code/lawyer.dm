/datum/outfit/job/lawyer_formal
	name = "Lawyer Formal"
	jobtype = /datum/job/lawyer

	id_trim = /datum/id_trim/job/lawyer
	uniform = /obj/item/clothing/under/costume/buttondown/slacks/service
	suit = /obj/item/clothing/suit/toggle/lawyer/black
	belt = /obj/item/modular_computer/pda/crew/lawyer
	// AI EDIT START - Use the right ear slot for existing equipment
	ear_right = /obj/item/radio/headset/lawyer
	// AI EDIT END
	shoes = /obj/item/clothing/shoes/laceup
	neck = /obj/item/clothing/neck/tie/black/tied
	l_pocket = /obj/item/laser_pointer/red
	r_pocket = /obj/item/clothing/accessory/lawyers_badge
	l_hand = /obj/item/storage/briefcase/lawyer
	backpack_contents = list(/obj/item/telephone/mobile/lawyer = 1)

	chameleon_extras = /obj/item/stamp/law

	implants = list(/obj/item/implant/mindshield)
