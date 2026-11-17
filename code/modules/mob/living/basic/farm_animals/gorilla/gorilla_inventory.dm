/// Cargorillas use the usual ID slot alongside their dextrous hand HUD.
/datum/hud/dextrous/cargorilla
	default_inventory_slots = list(/datum/inventory_slot/human/id)

/mob/living/basic/gorilla/cargorilla/Destroy()
	QDEL_NULL(wear_id)
	return ..()

/mob/living/basic/gorilla/cargorilla/gib(drop_bitflags = DROP_BRAIN)
	dropItemToGround(wear_id, force = TRUE)
	return ..()

/mob/living/basic/gorilla/cargorilla/get_idcard(hand_first = TRUE)
	. = ..()
	if (. && hand_first)
		return
	return wear_id || .

/mob/living/basic/gorilla/cargorilla/can_equip(obj/item/equipping, slot, disable_warning = FALSE, bypass_equip_delay_self = FALSE, ignore_equipped = FALSE, indirect_action = FALSE)
	if (slot == ITEM_SLOT_ID)
		return isidcard(equipping) && (ignore_equipped || isnull(wear_id))
	return ..()

/mob/living/basic/gorilla/cargorilla/get_item_by_slot(slot_id)
	if (slot_id == ITEM_SLOT_ID)
		return wear_id
	return ..()

/mob/living/basic/gorilla/cargorilla/get_slot_by_item(obj/item/looking_for)
	if (looking_for && looking_for == wear_id)
		return ITEM_SLOT_ID
	return ..()

/mob/living/basic/gorilla/cargorilla/equip_to_slot(obj/item/equipping, slot, initial = FALSE, redraw_mob = FALSE, indirect_action = FALSE)
	if (slot != ITEM_SLOT_ID)
		return ..()
	var/held_index = get_held_index_of_item(equipping)
	if (held_index)
		held_items[held_index] = null
		update_held_items()
	if (equipping.pulledby)
		equipping.pulledby.stop_pulling()
	equipping.forceMove(src)
	SET_PLANE_EXPLICIT(equipping, ABOVE_HUD_PLANE, src)
	wear_id = equipping
	hud_used?.update_inventory_slot(ITEM_SLOT_ID)
	has_equipped(equipping, slot, initial)

/mob/living/basic/gorilla/cargorilla/doUnEquip(obj/item/item_dropping, force, newloc, no_move, invdrop = TRUE, silent = FALSE)
	. = ..()
	if (. && item_dropping && item_dropping == wear_id)
		wear_id = null
		hud_used?.update_inventory_slot(ITEM_SLOT_ID)

/mob/living/basic/gorilla/cargorilla/Exited(atom/movable/gone, direction)
	. = ..()
	// Forced movement must also remove the card's access and inventory references.
	if (gone == wear_id && (wear_id.item_flags & IN_INVENTORY))
		temporarilyRemoveItemFromInventory(wear_id, force = TRUE, newloc = gone.loc)
