/datum/outfit
	/// Default-slot organs from older outfit exports.
	var/list/organs
	/// Prosthetic item type by body zone.
	var/list/prosthetics
	/// Cybernetic organ type by its target organ slot.
	var/list/cyber_organs

/// The concrete types available in each outfit anatomy slot. No game objects are created for the picker.
/proc/outfit_cybernetics_catalog()
	var/static/list/catalog
	if(catalog)
		return catalog

	var/list/limb_choices = list()
	for(var/zone in GLOB.all_body_zones)
		limb_choices[zone] = list()
	for(var/obj/item/bodypart/limb as anything in subtypesof(/obj/item/bodypart))
		var/zone = initial(limb.body_zone)
		if(!(zone in limb_choices) || initial(limb.abstract_type) == limb || (initial(limb.bodypart_flags) & (BODYPART_ABSTRACT | BODYPART_STUMP)))
			continue
		if(initial(limb.bodytype) & (BODYTYPE_ROBOTIC | BODYTYPE_PEG))
			limb_choices[zone] += limb

	var/list/organ_choices = list()
	for(var/obj/item/organ/organ as anything in subtypesof(/obj/item/organ))
		var/slot = initial(organ.slot)
		if(!slot || initial(organ.abstract_type) == organ || !(initial(organ.organ_flags) & ORGAN_ROBOTIC))
			continue
		LAZYADD(organ_choices[slot], organ)
		if(ispath(organ, /obj/item/organ/cyberimp/arm))
			var/obj/item/organ/cyberimp/arm/arm_organ = organ
			if(initial(arm_organ.fixed_arm_side))
				continue
			if(slot == ORGAN_SLOT_RIGHT_ARM_AUG)
				LAZYADD(organ_choices[ORGAN_SLOT_LEFT_ARM_AUG], organ)
			else if(slot == ORGAN_SLOT_RIGHT_ARM_MUSCLE)
				LAZYADD(organ_choices[ORGAN_SLOT_LEFT_ARM_MUSCLE], organ)

	catalog = list("prosthetics" = limb_choices, "cyber_organs" = organ_choices)
	return catalog

/// Resolves the legacy default slots and gives precedence to the editor's explicit slot choices.
/datum/outfit/proc/get_outfit_organs()
	. = list()
	for(var/obj/item/organ/organ_type as anything in organs)
		if(ispath(organ_type, /obj/item/organ) && initial(organ_type.slot))
			.[initial(organ_type.slot)] = organ_type
	for(var/slot in cyber_organs)
		.[slot] = cyber_organs[slot]

/// Fits prosthetics first so later inventory checks use the resulting anatomy.
/datum/outfit/proc/equip_outfit_prosthetics(mob/living/carbon/human/user, mob/living/carbon/human/dummy/outfit_check/check)
	if(!length(prosthetics))
		return
	var/list/choices = outfit_cybernetics_catalog()["prosthetics"]
	for(var/zone in prosthetics)
		var/limb_type = prosthetics[zone]
		if(!(limb_type in choices[zone]))
			check?.add_outfit_issue("prosthetics:[zone]", limb_type, "Протез не подходит для этой части тела.")
			continue

		var/obj/item/bodypart/current_limb = user.get_bodypart(zone)
		if(current_limb?.type == limb_type)
			continue
		var/obj/item/bodypart/limb = new limb_type()
		if(!limb.replace_limb(user, drop_old_limb = FALSE))
			check?.add_outfit_issue("prosthetics:[zone]", limb_type, "Тело не принимает этот протез.")
			qdel(limb)
			continue
		if(HAS_TRAIT_FROM(limb, TRAIT_PARALYSIS, TRAIT_CYBERNETIC_REJECTION))
			check?.add_outfit_issue("prosthetics:[zone]", limb_type, "Протез установлен, но организм его отторгает.")

/// Installs the newly configured organs before equipping items.
/datum/outfit/proc/equip_outfit_organs(mob/living/carbon/human/user, mob/living/carbon/human/dummy/outfit_check/check)
	if(!length(cyber_organs))
		return
	var/list/choices = outfit_cybernetics_catalog()["cyber_organs"]
	var/list/selected = cyber_organs.Copy()
	var/brain_type = selected[ORGAN_SLOT_BRAIN]
	if(brain_type)
		// Positronic cores validate the other organs already installed in the body.
		selected -= ORGAN_SLOT_BRAIN
		selected[ORGAN_SLOT_BRAIN] = brain_type
	for(var/slot in selected)
		var/organ_type = selected[slot]
		if(!(organ_type in choices[slot]))
			check?.add_outfit_issue("cyber_organs:[slot]", organ_type, "Киберорган не подходит для этого слота.")
			continue
		install_outfit_organ(user, organ_type, slot, check)

/// Older outfits install their listed organs after clothing and equipment.
/datum/outfit/proc/equip_outfit_legacy_organs(mob/living/carbon/human/user, mob/living/carbon/human/dummy/outfit_check/check)
	for(var/obj/item/organ/organ_type as anything in organs)
		if(!ispath(organ_type, /obj/item/organ))
			continue
		var/slot = initial(organ_type.slot)
		if(slot && !cyber_organs?[slot])
			install_outfit_organ(user, organ_type, slot, check)

/// Applies the chosen side, checks compatibility and disposes failed installations.
/datum/outfit/proc/install_outfit_organ(mob/living/carbon/human/user, organ_type, slot, mob/living/carbon/human/dummy/outfit_check/check)
	var/obj/item/organ/current_organ = user.get_organ_slot(slot)
	if(current_organ?.type == organ_type)
		if(current_organ.cybernetic_rejection)
			check?.add_outfit_issue("cyber_organs:[slot]", organ_type, "Киберорган установлен, но организм его отторгает.")
		return
	var/obj/item/organ/organ = new organ_type()
	if(organ.slot != slot)
		// Mirrored arm implants use the same type on both sides.
		var/target_zone
		for(var/zone in organ.valid_zones)
			if(organ.valid_zones[zone] == slot)
				target_zone = zone
				break
		if(!target_zone)
			check?.add_outfit_issue("cyber_organs:[slot]", organ_type, "Киберорган не подходит для этого слота.")
			qdel(organ)
			return
		organ.swap_zone(target_zone)

	var/reason
	if(!user.get_bodypart(deprecise_zone(organ.zone)))
		reason = "Отсутствует часть тела, необходимая для установки."
	else if(!organ.Insert(user, special = TRUE, movement_flags = DELETE_IF_REPLACED | NO_ID_TRANSFER))
		reason = "Киберорган несовместим с организмом."
	if(reason)
		check?.add_outfit_issue("cyber_organs:[slot]", organ_type, reason)
		qdel(organ)
		return
	if(organ.cybernetic_rejection)
		check?.add_outfit_issue("cyber_organs:[slot]", organ_type, "Киберорган установлен, но организм его отторгает.")
