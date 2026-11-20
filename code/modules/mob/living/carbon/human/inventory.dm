
/**
 * Used to return a list of equipped items on a human mob; does not by default include held items, see include_flags
 *
 * Argument(s):
 * * Optional - include_flags, (see obj.flags.dm) describes which optional things to include or not (pockets, accessories, held items)
 */

/mob/living/carbon/human/get_equipped_items(include_flags = NONE)
	var/list/items = ..()
	if(!(include_flags & INCLUDE_POCKETS))
		items -= list(l_store, r_store, s_store)
	if((include_flags & INCLUDE_ACCESSORIES) && istype(w_uniform, /obj/item/clothing/under))
		var/obj/item/clothing/under/worn_under = w_uniform
		items += worn_under.attached_accessories
	return items

/mob/living/carbon/human/can_equip(obj/item/equip_target, slot, disable_warning = FALSE, bypass_equip_delay_self = FALSE, ignore_equipped = FALSE, indirect_action = FALSE)
	// AI EDIT START - Validate multi-slot equip candidates before equip delays
	// BANDASTATION ADDITION START - Signal-based equip checks before and after equip delays
	if(QDELETED(src) || QDELETED(equip_target))
		return FALSE
	// BANDASTATION ADDITION END
	if(SEND_SIGNAL(src, COMSIG_HUMAN_EQUIPPING_ITEM, equip_target, slot) & COMPONENT_BLOCK_EQUIP)
		return inventory_rejected("Другая вещь блокирует этот слот.")
	// BANDASTATION ADDITION START - Let the candidate validate all required slots, even when dressing another mob.
	if(SEND_SIGNAL(equip_target, COMSIG_ITEM_EQUIP_CHECK, src, slot) & COMPONENT_BLOCK_EQUIP)
		return inventory_rejected("Предмет не может занять нужные ему слоты.")
	// BANDASTATION ADDITION END
	// AI EDIT END
	if(HAS_TRAIT(equip_target, TRAIT_NODROP) && is_holding(equip_target))
		if(!disable_warning)
			to_chat(src, span_warning("[equip_target] won't budge, it's impossible to put it on!"))
		return FALSE
	// AI EDIT START - Recheck equip requirements after possible delays
	// BANDASTATION EDIT START - Revalidate generic equip signals after the species' possible do_after.
	if(!dna.species.can_equip(equip_target, slot, disable_warning, src, bypass_equip_delay_self, ignore_equipped, indirect_action))
		return FALSE
	if(QDELETED(src) || QDELETED(equip_target))
		return FALSE
	if(SEND_SIGNAL(src, COMSIG_HUMAN_EQUIPPING_ITEM, equip_target, slot) & COMPONENT_BLOCK_EQUIP)
		return FALSE
	return !(SEND_SIGNAL(equip_target, COMSIG_ITEM_EQUIP_CHECK, src, slot) & COMPONENT_BLOCK_EQUIP)
	// BANDASTATION EDIT END
	// AI EDIT END

/mob/living/carbon/human/get_item_by_slot(slot_id)
	// AI EDIT START - Resolve items reserving secondary clothing slots
	// BANDASTATION ADDITION START - Clothing occupying multiple inventory slots
	var/obj/item/reserving_item = LAZYACCESS(occupied_clothing_slots, "[slot_id]")
	if(reserving_item)
		return reserving_item
	// BANDASTATION ADDITION END
	// AI EDIT END
	switch(slot_id)
		// BANDASTATION ADDITION START - Removable underclothing
		if(ITEM_SLOT_UNDERWEAR)
			return w_underwear
		if(ITEM_SLOT_UNDERSHIRT)
			return w_undershirt
		if(ITEM_SLOT_SOCKS)
			return w_socks
		// BANDASTATION ADDITION END
		if(ITEM_SLOT_BACK)
			return back
		if(ITEM_SLOT_BELT)
			return belt
		if(ITEM_SLOT_ID)
			return wear_id
		// AI EDIT START - Resolve the item in either ear slot
		// BANDASTATION EDIT START - Separate ear slots
		if(ITEM_SLOT_EAR_RIGHT)
			return ear_right
		if(ITEM_SLOT_EAR_LEFT)
			return ear_left
		// BANDASTATION EDIT END
		// AI EDIT END
		if(ITEM_SLOT_EYES)
			return glasses
		if(ITEM_SLOT_GLOVES)
			return gloves
		if(ITEM_SLOT_FEET)
			return shoes
		if(ITEM_SLOT_MASK)
			return wear_mask
		if(ITEM_SLOT_NECK)
			return wear_neck
		if(ITEM_SLOT_HEAD)
			return head
		if(ITEM_SLOT_OCLOTHING)
			return wear_suit
		if(ITEM_SLOT_ICLOTHING)
			return w_uniform
		if(ITEM_SLOT_LPOCKET)
			return l_store
		if(ITEM_SLOT_RPOCKET)
			return r_store
		if(ITEM_SLOT_SUITSTORE)
			return s_store

	return ..()

/mob/living/carbon/human/get_slot_by_item(obj/item/looking_for)
	// BANDASTATION ADDITION START - Removable underclothing
	if(istype(looking_for, /obj/item/clothing/underwear) && get_item_by_slot(looking_for.slot_flags) == looking_for)
		return looking_for.slot_flags
	// BANDASTATION ADDITION END
	if(looking_for == back)
		return ITEM_SLOT_BACK

	if(looking_for == belt)
		return ITEM_SLOT_BELT

	if(looking_for == wear_id)
		return ITEM_SLOT_ID

	// AI EDIT START - Identify the equipped ear slot
	// BANDASTATION EDIT START - Separate ear slots
	if(looking_for == ear_right)
		return ITEM_SLOT_EAR_RIGHT
	if(looking_for == ear_left)
		return ITEM_SLOT_EAR_LEFT
	// BANDASTATION EDIT END
	// AI EDIT END

	if(looking_for == glasses)
		return ITEM_SLOT_EYES

	if(looking_for == gloves)
		return ITEM_SLOT_GLOVES

	if(looking_for == head)
		return ITEM_SLOT_HEAD

	if(looking_for == wear_mask)
		return ITEM_SLOT_MASK

	if(looking_for == wear_neck)
		return ITEM_SLOT_NECK

	if(looking_for == head)
		return ITEM_SLOT_HEAD

	if(looking_for == shoes)
		return ITEM_SLOT_FEET

	if(looking_for == wear_suit)
		return ITEM_SLOT_OCLOTHING

	if(looking_for == w_uniform)
		return ITEM_SLOT_ICLOTHING

	if(looking_for == r_store)
		return ITEM_SLOT_RPOCKET

	if(looking_for == l_store)
		return ITEM_SLOT_LPOCKET

	if(looking_for == s_store)
		return ITEM_SLOT_SUITSTORE

	return ..()

/mob/living/carbon/human/get_visible_items()
	var/list/visible_items = ..()
	// BANDASTATION ADDITION START - Removable underclothing
	for(var/obj/item/clothing/underwear/garment in visible_items.Copy())
		if(underclothing_hidden(garment.slot_flags))
			visible_items -= garment
	// BANDASTATION ADDITION END
	var/obj/item/clothing/under/under = w_uniform
	if(istype(under) && length(under.attached_accessories) && (under in visible_items))
		visible_items += under.attached_accessories
	return visible_items

//This is an UNSAFE proc. Use mob_can_equip() before calling this one! Or rather use equip_to_slot_if_possible() or advanced_equip_to_slot_if_possible()
// Initial is used to indicate whether or not this is the initial equipment (job datums etc) or just a player doing it
/mob/living/carbon/human/equip_to_slot(obj/item/equipping, slot, initial = FALSE, redraw_mob = FALSE, indirect_action = FALSE)
	if(!..()) //a check failed or the item has already found its slot
		return

	var/not_handled = FALSE //Added in case we make this type path deeper one day
	switch(slot)
		// BANDASTATION ADDITION START - Removable underclothing
		if(ITEM_SLOT_UNDERWEAR, ITEM_SLOT_UNDERSHIRT, ITEM_SLOT_SOCKS)
			wear_underclothing(equipping)
		// BANDASTATION ADDITION END
		if(ITEM_SLOT_BACK)
			if(back)
				return
			back = equipping
			update_worn_back()
		if(ITEM_SLOT_BELT)
			if(belt)
				return
			belt = equipping
			update_worn_belt()
		if(ITEM_SLOT_ID)
			if(wear_id)
				return
			wear_id = equipping
			update_ID_card()
			update_worn_id()
		// AI EDIT START - Support independent left and right ear slots
		// BANDASTATION EDIT START - Separate ear slots
		if(ITEM_SLOT_EAR_RIGHT)
			if(ear_right)
				return
			ear_right = equipping
			update_worn_ears()
		if(ITEM_SLOT_EAR_LEFT)
			if(ear_left)
				return
			ear_left = equipping
			update_worn_ears()
		// BANDASTATION EDIT END
		// AI EDIT END
		if(ITEM_SLOT_EYES)
			if(glasses)
				return
			glasses = equipping
			update_worn_glasses()
		if(ITEM_SLOT_GLOVES)
			if(gloves)
				return
			gloves = equipping
			update_worn_gloves()
		if(ITEM_SLOT_FEET)
			if(shoes)
				return
			shoes = equipping
			update_worn_shoes()
		if(ITEM_SLOT_OCLOTHING)
			if(wear_suit)
				return
			wear_suit = equipping
			if(wear_suit.breakouttime) //when equipping a straightjacket
				ADD_TRAIT(src, TRAIT_RESTRAINED, SUIT_TRAIT)
				stop_pulling() //can't pull if restrained
				update_mob_action_buttons() //certain action buttons will no longer be usable.
			update_worn_oversuit()
		if(ITEM_SLOT_MASK)
			if(wear_mask)
				return
			wear_mask = equipping
			update_worn_mask()
		if(ITEM_SLOT_HEAD)
			if(head)
				return
			head = equipping
			update_worn_head()
		if(ITEM_SLOT_NECK)
			if(wear_neck)
				return
			wear_neck = equipping
			update_worn_neck(equipping)
		if(ITEM_SLOT_ICLOTHING)
			if(w_uniform)
				return
			w_uniform = equipping
			update_worn_undersuit()
		if(ITEM_SLOT_LPOCKET)
			l_store = equipping
			update_pockets()
		if(ITEM_SLOT_RPOCKET)
			r_store = equipping
			update_pockets()
		if(ITEM_SLOT_SUITSTORE)
			if(s_store)
				return
			s_store = equipping
			update_suit_storage()
		else
			to_chat(src, span_danger("Вы пытаетесь экипировать предмет в слот, который не поддерживется кодом игры. Сообщите кодерам!"))
			not_handled = TRUE

	//Item is handled and in slot, valid to call callback, for this proc should always be true
	if(!not_handled)
		has_equipped(equipping, slot, initial)

	return not_handled //For future deeper overrides

/mob/living/carbon/human/doUnEquip(obj/item/item_dropping, force, newloc, no_move, invdrop = TRUE, silent = FALSE)
	. = ..() //See mob.dm for an explanation on this and some rage about people copypasting instead of calling ..() like they should.
	if(!. || !item_dropping)
		return
	// BANDASTATION ADDITION START - Removable underclothing
	if(istype(item_dropping, /obj/item/clothing/underwear) && get_item_by_slot(item_dropping.slot_flags) == item_dropping)
		remove_underclothing(item_dropping)
	// BANDASTATION ADDITION END
	if(item_dropping == wear_suit)
		if(s_store && invdrop)
			dropItemToGround(s_store, TRUE) //It makes no sense for your suit storage to stay on you if you drop your suit.
		if(wear_suit.breakouttime) //when unequipping a straightjacket
			REMOVE_TRAIT(src, TRAIT_RESTRAINED, SUIT_TRAIT)
			drop_all_held_items() //suit is restraining
			update_mob_action_buttons() //certain action buttons may be usable again.
		wear_suit = null
		if(!QDELETED(src)) //no need to update we're getting deleted anyway
			update_worn_oversuit()
	else if(item_dropping == w_uniform)
		w_uniform = null
		if(!QDELETED(src))
			update_worn_undersuit()
		if(invdrop)
			if(r_store && !can_equip(r_store, ITEM_SLOT_RPOCKET, TRUE, ignore_equipped = TRUE))
				dropItemToGround(r_store, TRUE) //Again, makes sense for pockets to drop.
			if(l_store && !can_equip(l_store, ITEM_SLOT_LPOCKET, TRUE, ignore_equipped = TRUE))
				dropItemToGround(l_store, TRUE)
			if(wear_id && !can_equip(wear_id, ITEM_SLOT_ID, TRUE, ignore_equipped = TRUE))
				dropItemToGround(wear_id)
			if(belt && !can_equip(belt, ITEM_SLOT_BELT, TRUE, ignore_equipped = TRUE))
				dropItemToGround(belt)
	else if(item_dropping == back)
		back = null
		if(!QDELETED(src))
			update_worn_back()
	else if(item_dropping == head)
		head = null
		if(!QDELETED(src))
			update_worn_head()
	else if(item_dropping == wear_mask)
		wear_mask = null
		if(!QDELETED(src))
			update_worn_mask()
	else if(item_dropping == wear_neck)
		wear_neck = null
		if(!QDELETED(src))
			update_worn_neck(item_dropping)
	else if(item_dropping == gloves)
		gloves = null
		if(!QDELETED(src))
			update_worn_gloves()
	else if(item_dropping == glasses)
		glasses = null
		if(!QDELETED(src))
			update_worn_glasses()
	// AI EDIT START - Drop each ear item independently
	// BANDASTATION EDIT START - Separate ear slots
	else if(item_dropping == ear_right)
		ear_right = null
		if(!QDELETED(src))
			update_worn_ears()
	else if(item_dropping == ear_left)
		ear_left = null
		if(!QDELETED(src))
			update_worn_ears()
	// BANDASTATION EDIT END
	// AI EDIT END
	else if(item_dropping == shoes)
		shoes = null
		if(!QDELETED(src))
			update_worn_shoes()
	else if(item_dropping == belt)
		belt = null
		if(!QDELETED(src))
			update_worn_belt()
	else if(item_dropping == wear_id)
		wear_id = null
		update_ID_card()
		if(!QDELETED(src))
			update_worn_id()
	else if(item_dropping == r_store)
		r_store = null
		if(!QDELETED(src))
			update_pockets()
	else if(item_dropping == l_store)
		l_store = null
		if(!QDELETED(src))
			update_pockets()
	else if(item_dropping == s_store)
		s_store = null
		if(!QDELETED(src))
			update_suit_storage()

/mob/living/carbon/human/item_coverage_changed(added_slots, removed_slots)
	. = ..()
	if((added_slots|removed_slots) & HIDEFACE)
		sec_hud_set_security_status()
		update_visible_name()

/mob/living/carbon/human/toggle_internals(obj/item/tank, is_external = FALSE)
	// Just close the tank if it's the one the mob already has open.
	var/obj/item/existing_tank = is_external ? external : internal
	if(tank == existing_tank)
		return toggle_close_internals(is_external)

	// Use breathing tube regardless of mask.
	if(can_breathe_tube())
		return toggle_open_internals(tank, is_external)

	// Use mask in absence of tube.
	if(can_breathe_mask())
		return toggle_open_internals(tank, is_external)
	// We have a valid mask but it's pulled down
	else if(isclothing(wear_mask))
		var/obj/item/clothing/mask = wear_mask
		if (mask.up && (mask.visor_flags & MASKINTERNALS) && !(mask.clothing_flags & INTERNALS_ADJUST_EXEMPT) && mask.adjust_visor(src))
			return toggle_open_internals(tank, is_external)

	// Use helmet in absence of tube or valid mask.
	if(can_breathe_helmet())
		return toggle_open_internals(tank, is_external)
	// We have a valid helmet but its visor is up
	else if(isclothing(head))
		var/obj/item/clothing/helmet = head
		if (helmet.up && (helmet.visor_flags & HEADINTERNALS) && !(helmet.clothing_flags & INTERNALS_ADJUST_EXEMPT) && helmet.adjust_visor(src))
			return toggle_open_internals(tank, is_external)

	// Notify user of missing valid breathing apparatus.
	if (wear_mask)
		// Invalid mask
		to_chat(src, span_warning("[capitalize(wear_mask.declent_ru(NOMINATIVE))] не может использовать [tank.declent_ru(ACCUSATIVE)]!"))
	else if (head)
		// Invalid headgear
		to_chat(src, span_warning("[capitalize(head.declent_ru(NOMINATIVE))] не герметична! Вам нужна маска!"))
	else
		// Not wearing any breathing apparatus.
		to_chat(src, span_warning("Вам нужна маска!"))

/// Returns TRUE if the tank successfully toggles open/closed. Opens the tank only if a breathing apparatus is found.
/mob/living/carbon/human/toggle_externals(obj/item/tank)
	return toggle_internals(tank, TRUE)

/mob/living/carbon/human/proc/equipOutfit(outfit, visuals_only = FALSE, apply_mental_conditioning = TRUE)
	var/datum/outfit/O = null

	if(ispath(outfit))
		O = new outfit
	else
		O = outfit
		if(!istype(O))
			return 0
	if(!O)
		return 0

	return O.equip(src, visuals_only, apply_mental_conditioning)


///A version of equipOutfit that overrides passed in outfits with their entry on the species' outfit override registry
/mob/living/carbon/human/proc/equip_species_outfit(outfit, visuals_only = FALSE, apply_mental_conditioning = TRUE)
	var/datum/outfit/outfit_to_equip

	var/override_outfit_path = dna?.species.outfit_override_registry[outfit]
	if(override_outfit_path)
		outfit_to_equip = new override_outfit_path
	else
		dna.species.give_important_for_life(src)
		outfit_to_equip = new outfit

	if(isnull(outfit_to_equip))
		return FALSE

	return outfit_to_equip.equip(src, visuals_only, apply_mental_conditioning)


//delete all equipment without dropping anything
/mob/living/carbon/human/proc/delete_equipment()
	for(var/slot in get_equipped_items(INCLUDE_POCKETS))//order matters, dependant slots go first
		qdel(slot)
	for(var/obj/item/held_item as anything in get_held_items())
		qdel(held_item)

/// take the most recent item out of a slot or place held item in a slot

/mob/living/carbon/human/proc/smart_equip_targeted(slot_type = ITEM_SLOT_BELT, slot_item_name = "пояса")
	if(incapacitated)
		return
	var/obj/item/thing = get_active_held_item()
	var/obj/item/equipped_item = get_item_by_slot(slot_type)
	var/thing_reject = NONE
	if(thing)
		thing_reject = SEND_SIGNAL(thing, COMSIG_HUMAN_NON_STORAGE_HOTKEY, src, equipped_item)
	if(!equipped_item) // We also let you equip an item like this
		if(!thing)
			to_chat(src, span_warning("У вас нет [slot_item_name], чтобы брать что-то оттуда!"))
			return
		if(equip_to_slot_if_possible(thing, slot_type))
			update_held_items()
		return
	var/datum/storage/storage = equipped_item.atom_storage
	if(!storage)
		if(!thing)
			equipped_item.attack_hand(src)
		else
			if(thing_reject & COMPONENT_STORAGE_HOTKEY_HANDLED)
				return
			to_chat(src, span_warning("Вы не можете поместить [thing.declent_ru(ACCUSATIVE)] в [equipped_item.ru_p_own(ACCUSATIVE)] [equipped_item.declent_ru(ACCUSATIVE)]!"))
		return
	if(!storage.supports_smart_equip)
		return
	if (equipped_item.atom_storage.locked) // Determines if container is locked before trying to put something in or take something out so we dont give out information on contents (or lack of)
		to_chat(src, span_warning("Замок на [equipped_item.declent_ru(PREPOSITIONAL)] закрыт!"))
		return
	if(thing) // put thing in storage item
		if(!equipped_item.atom_storage?.attempt_insert(thing, src))
			to_chat(src, span_warning("Вы не можете поместить [thing.declent_ru(ACCUSATIVE)] в [equipped_item.ru_p_own(ACCUSATIVE)] [equipped_item.declent_ru(ACCUSATIVE)]!"))
		return
	if(!storage.real_location.contents.len) // nothing to take out
		to_chat(src, span_warning("Нечего вытаскивать из [equipped_item.declent_ru(GENITIVE)]!"))
		return
	var/obj/item/stored = storage.real_location.contents[storage.real_location.contents.len]
	if(!stored || stored.on_found(src))
		return
	stored.attack_hand(src) // take out thing from item in storage slot
	return

/// Returns the helmet if an air tank compatible helmet is equipped.
/mob/living/carbon/human/proc/can_breathe_helmet()
	if (astype(head, /obj/item/clothing)?.clothing_flags & HEADINTERNALS)
		return head

/// Returns the mask if an air tank compatible mask is equipped.
/mob/living/carbon/human/proc/can_breathe_mask()
	if (astype(wear_mask, /obj/item/clothing)?.clothing_flags & MASKINTERNALS)
		return wear_mask

/// Returns the object that allows us to breathe internals - tube implant, mask or helmet
/mob/living/carbon/human/can_breathe_internals()
	return can_breathe_tube() || can_breathe_mask() || can_breathe_helmet()
