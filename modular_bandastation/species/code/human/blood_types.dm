/datum/blood_type/skrell
	name = "SK"
	color = BLOOD_COLOR_SKRELL
	compatible_types = list(
		/datum/blood_type/skrell,
	)

/obj/item/reagent_containers/blood/skrell
	blood_type = /datum/blood_type/skrell

/datum/blood_type/moth
	name = "M"
	color = BLOOD_COLOR_MOTH
	compatible_types = list(
		/datum/blood_type/moth,
	)

/obj/item/reagent_containers/blood/moth
	blood_type = /datum/blood_type/moth

/datum/blood_type/vox
	name = "VOX"
	color = BLOOD_COLOR_VOX
	compatible_types = list(
		/datum/blood_type/vox,
	)

/obj/item/reagent_containers/blood/vox
	blood_type = /datum/blood_type/vox

/// The purple blood of Resomi.
/datum/blood_type/resomi
	name = "RS"
	color = "#d514f7"
	compatible_types = list(
		/datum/blood_type/resomi,
	)

/// A blood pack for transfusions to Resomi.
/obj/item/reagent_containers/blood/resomi
	blood_type = /datum/blood_type/resomi

/datum/blood_type/drask
	name = "Cryoxadone"
	dna_string = "Drask DNA"
	color = /datum/reagent/medicine/cryoxadone::color
	reagent_type = /datum/reagent/medicine/cryoxadone
	restoration_chem = /datum/reagent/medicine/cryoxadone
