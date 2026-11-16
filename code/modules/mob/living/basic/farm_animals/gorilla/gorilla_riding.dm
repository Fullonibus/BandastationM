/mob/living/basic/gorilla/cargorilla/mouse_buckle_handling(mob/living/passenger, mob/living/user)
	if(user != passenger || !can_piggyback(passenger))
		return FALSE
	piggyback(passenger)
	return TRUE

/mob/living/basic/gorilla/cargorilla/is_buckle_possible(mob/living/target, force, check_loc)
	if(buckled || !force || !HAS_TRAIT(target, TRAIT_CAN_MOUNT_HUMANS))
		return FALSE
	return ..()

/// Human piggyback rules with the passenger positioned for the gorilla's two poses.
/datum/component/riding/creature/human/gorilla

/datum/component/riding/creature/human/gorilla/RegisterWithParent()
	. = ..()
	RegisterSignal(parent, COMSIG_MOB_UPDATE_HELD_ITEMS, PROC_REF(vehicle_moved))

/datum/component/riding/creature/human/gorilla/get_rider_offsets_and_layers(pass_index, mob/offsetter)
	var/mob/living/basic/gorilla/gorilla = parent
	var/height = gorilla.is_standing() ? 16 : 8
	return list(
		TEXT_NORTH = list(0, height, MOB_ABOVE_PIGGYBACK_LAYER),
		TEXT_SOUTH = list(0, height, MOB_BELOW_PIGGYBACK_LAYER),
		TEXT_EAST = list(-6, height, MOB_BELOW_PIGGYBACK_LAYER),
		TEXT_WEST = list(6, height, MOB_BELOW_PIGGYBACK_LAYER),
	)
