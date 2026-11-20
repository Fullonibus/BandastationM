/**
 * # Outfit datums
 *
 * This is a clean system of applying outfits to mobs, if you need to equip someone in a uniform
 * this is the way to do it cleanly and properly.
 *
 * You can also specify an outfit datum on a job to have it auto equipped to the mob on join
 *
 * /mob/living/carbon/human/proc/equipOutfit(outfit) is the mob level proc to equip an outfit
 * and you pass it the relevant datum outfit
 *
 * outfits can also be saved as json blobs downloadable by a client and then can be uploaded
 * by that user to recreate the outfit, this is used by admins to allow for custom event outfits
 * that can be restored at a later date
 */
/datum/outfit
	///Name of the outfit (shows up in the equip admin verb)
	var/name = "Naked"

	/// Type path of item to go in the idcard slot
	var/id = null

	/// Type path of ID card trim associated with this outfit.
	var/id_trim = null

	/// Type path of item to go in uniform slot
	var/obj/item/uniform = null

	/// Type path of item to go in suit slot
	var/obj/item/suit = null

	/**
	  * Type path of item to go in suit storage slot
	  *
	  * (make sure it's valid for that suit)
	  */
	var/obj/item/suit_store = null

	/// Type path of item to go in back slot
	var/obj/item/back = null

	/**
	  * list of items that should go in the backpack of the user
	  *
	  * Format of this list should be: list(path=count,otherpath=count)
	  */
	var/list/backpack_contents = null

	/// Type path of item to go in belt slot
	var/obj/item/belt = null

	/**
	  * list of items that should go in the belt of the user
	  *
	  * Format of this list should be: list(path=count,otherpath=count)
	  */
	var/list/belt_contents = null

	// AI EDIT START - Dual ear slots
	// BANDASTATION EDIT START - Dual ear slots
	/// Type path of item to go in the right ear slot.
	var/ear_right = null
	/// Type path of item to go in the left ear slot.
	var/ear_left = null
	// BANDASTATION EDIT END
	// AI EDIT END

	/// Type path of item to go in the glasses slot
	var/glasses = null

	/// Type path of item to go in gloves slot
	var/gloves = null

	/// Type path of item to go in head slot
	var/head = null

	/// Type path of item to go in mask slot
	var/mask = null

	/// Type path of item to go in neck slot
	var/neck = null

	/// Type path of item to go in shoes slot
	var/shoes = null

	/// Type path of item for left pocket slot
	var/l_pocket = null

	/// Type path of item for right pocket slot
	var/r_pocket = null

	///Type path of item to go in the right hand
	var/l_hand = null

	//Type path of item to go in left hand
	var/r_hand = null

	/// Any clothing accessory item
	var/accessory = null

	/// Internals box. Placed in the backpack before other contents.
	var/box
	/// Extra contents of the box, as a list of item type paths mapped to quantities.
	var/list/box_contents

	/**
	  * extra types for chameleon outfit changes, mostly guns
	  *
	  * Valid values are a single typepath or list of typepaths
	  *
	  * These are all added and returns in the list for get_chamelon_diguise_info proc
	  */
	var/list/chameleon_extras

	/**
	  * Any implants the mob should start implanted with
	  *
	  * Format of this list is (typepath, typepath, typepath)
	  */
	var/list/implants = null

	///ID of the slot containing a gas tank
	var/internals_slot = null

	/**
	  * Any skillchips the mob should have in their brain.
	  *
	  * Format of this list is (typepath, typepath, typepath)
	  */
	var/list/skillchips = null

	///Should we preload some of this job's items?
	var/preload = FALSE

	/// Whether this outfit grants [TRAIT_MENTALLY_CONDITIONED] upon non-visual equip.
	var/mental_conditioning = FALSE

	/// Any undershirt. While on humans it is a string, here we use paths to stay consistent with the rest of the equips.
	var/datum/sprite_accessory/clothing/undershirt = null
	var/datum/sprite_accessory/clothing/underwear = null
	var/datum/sprite_accessory/clothing/socks = null

/**
 * Called at the start of the equip proc
 *
 * Override to change the value of the slots depending on client prefs, species and
 * other such sources of change
 *
 * Extra Arguments
 * * visuals_only true if this is only for display (in the character setup screen)
 *
 * If visuals_only is true, you can omit any work that doesn't visually appear on the character sprite
 */
/datum/outfit/proc/pre_equip(mob/living/carbon/human/user, visuals_only = FALSE)
	//to be overridden for customization depending on client prefs,species etc
	return

/**
 * Called after the equip proc has finished
 *
 * All items are on the mob at this point, use this proc to toggle internals
 * fiddle with id bindings and accesses etc
 *
 * Extra Arguments
 * * visuals_only true if this is only for display (in the character setup screen)
 *
 * If visuals_only is true, you can omit any work that doesn't visually appear on the character sprite
 */
/datum/outfit/proc/post_equip(mob/living/carbon/human/user, visuals_only = FALSE)
	//to be overridden for toggling internals, id binding, access etc
	return

/**
 * Equips all defined types and paths to the mob passed in
 *
 * Extra Arguments
 * * visuals_only true if this is only for display (in the character setup screen)
 * * apply_mental_conditioning false if the antagonist role manages its own conditioning
 *
 * If visuals_only is true, you can omit any work that doesn't visually appear on the character sprite
 */
/datum/outfit/proc/equip(mob/living/carbon/human/user, visuals_only = FALSE, apply_mental_conditioning = TRUE)
	pre_equip(user, visuals_only)

	equip_items(user, visuals_only)

	post_equip(user, visuals_only)
	user.dna?.species?.post_equip_species_outfit(user, visuals_only)

	if(!visuals_only)
		apply_fingerprints(user)
		if(apply_mental_conditioning && mental_conditioning)
			ADD_TRAIT(user, TRAIT_MENTALLY_CONDITIONED, INNATE_TRAIT)
		if(internals_slot)
			if(internals_slot & ITEM_SLOT_HANDS)
				var/obj/item/tank/internals/internals = user.is_holding_item_of_type(/obj/item/tank/internals)
				if(internals)
					user.open_internals(internals)
			else
				user.open_internals(user.get_item_by_slot(internals_slot))
		if(implants)
			for(var/implant_type in implants)
				var/obj/item/implant/implanter = SSwardrobe.provide_type(implant_type, user)
				implanter.implant(user, null, TRUE)

		// Insert the skillchips associated with this outfit into the target.
		if(skillchips)
			for(var/skillchip_path in skillchips)
				var/obj/item/skillchip/skillchip_instance = SSwardrobe.provide_type(skillchip_path)
				var/implant_msg = user.implant_skillchip(skillchip_instance)
				if(implant_msg)
					stack_trace("Failed to implant [user] with [skillchip_instance], on job [src]. Failure message: [implant_msg]")
					qdel(skillchip_instance)
					return

				var/activate_msg = skillchip_instance.try_activate_skillchip(TRUE, TRUE)
				if(activate_msg)
					CRASH("Failed to activate [user]'s [skillchip_instance], on job [src]. Failure message: [activate_msg]")


	user.update_body()
	equip_outfit_legacy_organs(user)
	return TRUE

#define EQUIP_OUTFIT_ITEM(item_path, slot_name) if(##item_path) { \
	equip_outfit_item(user, ##item_path, ##slot_name, #item_path, visuals_only, check); \
}

/// Equips the configured items in their normal order, without outfit or species outfit hooks.
/datum/outfit/proc/equip_items(mob/living/carbon/human/user, visuals_only, mob/living/carbon/human/dummy/outfit_check/check)
	equip_outfit_prosthetics(user, check)
	// Normal visual previews reuse their dummy. Only fitting uses a disposable body for organs.
	if(!visuals_only || check)
		equip_outfit_organs(user, check)
	//Start with uniform,suit,backpack for additional slots
	if(uniform)
		EQUIP_OUTFIT_ITEM(uniform, ITEM_SLOT_ICLOTHING)
	if(suit)
		EQUIP_OUTFIT_ITEM(suit, ITEM_SLOT_OCLOTHING)
	if(belt)
		EQUIP_OUTFIT_ITEM(belt, ITEM_SLOT_BELT)
	if(gloves)
		EQUIP_OUTFIT_ITEM(gloves, ITEM_SLOT_GLOVES)
	if(shoes)
		EQUIP_OUTFIT_ITEM(shoes, ITEM_SLOT_FEET)
	if(head)
		EQUIP_OUTFIT_ITEM(head, ITEM_SLOT_HEAD)
	if(mask)
		EQUIP_OUTFIT_ITEM(mask, ITEM_SLOT_MASK)
	if(neck)
		EQUIP_OUTFIT_ITEM(neck, ITEM_SLOT_NECK)
	// AI EDIT START - Dual ear slots
	// BANDASTATION EDIT START - Dual ear slots
	if(ear_right)
		EQUIP_OUTFIT_ITEM(ear_right, ITEM_SLOT_EAR_RIGHT)
	if(ear_left)
		EQUIP_OUTFIT_ITEM(ear_left, ITEM_SLOT_EAR_LEFT)
	// BANDASTATION EDIT END
	// AI EDIT END
	if(glasses)
		EQUIP_OUTFIT_ITEM(glasses, ITEM_SLOT_EYES)
	if(back)
		EQUIP_OUTFIT_ITEM(back, ITEM_SLOT_BACK)
	if(id)
		EQUIP_OUTFIT_ITEM(id, ITEM_SLOT_ID)
	if(!visuals_only && id_trim && user.wear_id)
		var/obj/item/card/id/id_card = user.wear_id
		if(!istype(id_card)) //If an ID wasn't found in their ID slot, it's probably something holding their ID like a wallet or PDA
			id_card = locate() in user.wear_id

		if(istype(id_card)) //Make sure that we actually found an ID to modify, otherwise this runtimes and cancels equipping the outfit
			id_card.registered_age = user.age
			if(id_trim)
				if(!SSid_access.apply_trim_to_card(id_card, id_trim))
					WARNING("Unable to apply trim [id_trim] to [id_card] in outfit [name].")
				user.update_ID_card()

	if(suit_store)
		EQUIP_OUTFIT_ITEM(suit_store, ITEM_SLOT_SUITSTORE)

	if(undershirt)
		user.undershirt = initial(undershirt.name)

	if(underwear)
		user.underwear = initial(underwear.name)

	if(socks)
		user.socks = initial(socks.name)

	if(accessory)
		var/obj/item/clothing/under/U = user.w_uniform
		if(istype(U))
			if(!check || ispath(accessory, /obj/item))
				var/obj/item/accessory_item = provide_fitting_item(accessory, user, check)
				if(!U.attach_accessory(accessory_item) && check)
					check.add_outfit_issue("accessory", accessory, "Этот аксессуар нельзя прикрепить к выбранной форме.")
					qdel(accessory_item)
			else
				check.add_outfit_issue("accessory", accessory, "Не удалось найти тип аксессуара.")
		else if(check)
			check.add_outfit_issue("accessory", accessory, "Для аксессуара нужно надеть форму.")
		else if(!visuals_only)
			WARNING("Unable to equip accessory [accessory] in outfit [name]. No uniform present!")

	if(l_hand)
		equip_outfit_hand(user, l_hand, LEFT_HANDS, "l_hand", visuals_only, check)
	if(r_hand)
		equip_outfit_hand(user, r_hand, RIGHT_HANDS, "r_hand", visuals_only, check)

	if(!visuals_only || check)
		EQUIP_OUTFIT_ITEM(l_pocket, ITEM_SLOT_LPOCKET)
		EQUIP_OUTFIT_ITEM(r_pocket, ITEM_SLOT_RPOCKET)

		if(box || (check && length(box_contents)))
			equip_backpack_box(user, check)
		equip_storage_contents(user, backpack_contents, "backpack_contents", ITEM_SLOT_BACK, check = check)
		equip_storage_contents(user, belt_contents, "belt_contents", ITEM_SLOT_BELT, check = check)
	if(check)
		equip_outfit_legacy_organs(user, check)

#undef EQUIP_OUTFIT_ITEM

/// Fitting uses fresh objects so the mannequin cannot consume or change the wardrobe's stock.
/datum/outfit/proc/provide_fitting_item(item_path, mob/living/carbon/human/user, mob/living/carbon/human/dummy/outfit_check/check)
	if(check)
		return new item_path(user)
	return SSwardrobe.provide_type(item_path, user)

/// Places an item in the requested slot and observes the result when fitting on a mannequin.
/datum/outfit/proc/equip_outfit_item(mob/living/carbon/human/user, item_path, slot, destination, visuals_only, mob/living/carbon/human/dummy/outfit_check/check)
	var/obj/item/previous_item
	if(check)
		if(!ispath(item_path, /obj/item))
			check.add_outfit_issue(destination, item_path, "Не удалось найти тип предмета.")
			return
		check.rejection_reason = null
		previous_item = user.get_item_by_slot(slot)
	user.equip_to_slot_or_del(provide_fitting_item(item_path, user, check), slot, TRUE, indirect_action = TRUE)
	var/obj/item/outfit_item = user.get_item_by_slot(slot)
	// Some randomized types equip their replacement during initialization.
	if(check && (!outfit_item || outfit_item == previous_item))
		check.add_outfit_issue(destination, item_path, check.rejection_reason || "Предмет не остался в выбранном слоте.")
		return
	if(outfit_item && outfit_item.type == item_path)
		outfit_item.on_outfit_equip(user, visuals_only, slot)

/// Places an item in a hand using the normal pickup and equipment checks.
/datum/outfit/proc/equip_outfit_hand(mob/living/carbon/human/user, item_path, side, destination, visuals_only, mob/living/carbon/human/dummy/outfit_check/check)
	if(check && !ispath(item_path, /obj/item))
		check.add_outfit_issue(destination, item_path, "Не удалось найти тип предмета.")
		return
	var/obj/item/item = provide_fitting_item(item_path, user, check)
	var/hand_index = user.get_empty_held_index_for_side(side)
	if(check && QDELETED(item))
		check.add_outfit_issue(destination, item_path, "Предмет не удалось создать.")
		return
	if(user.put_in_hand(item, hand_index, visuals_only = visuals_only) || !check)
		return
	check.add_outfit_issue(destination, item_path, hand_index ? "Манекен не может удержать этот предмет." : "Нет свободной руки с этой стороны.")
	qdel(item)

/// Inserts configured contents through the normal storage path for a worn container or nested box.
/datum/outfit/proc/equip_storage_contents(mob/living/carbon/human/user, list/contents, destination, slot, datum/storage/box_storage, mob/living/carbon/human/dummy/outfit_check/check)
	if(!slot && !box_storage && !check)
		return
	for(var/item_path in contents)
		var/count = contents[item_path]
		if(!isnum(count))
			count = 1
		if(count < 1)
			continue
		if(check)
			if(!ispath(item_path, /obj/item))
				check.add_outfit_issue(destination, item_path, "Не удалось найти тип предмета.", count)
				continue
			if(!slot && !box_storage)
				check.add_outfit_issue(destination, item_path, "Коробка недоступна в рюкзаке.", count)
				continue
		var/box_limit = box_storage ? box_storage.max_slots : count
		var/attempt_count = check ? min(count, MAX_OUTFIT_ITEM_COUNT) : min(count, box_limit)
		for(var/i in 1 to attempt_count)
			var/obj/item/item = provide_fitting_item(item_path, user, check)
			if(check)
				check.rejection_reason = null
				if(QDELETED(item))
					check.add_outfit_issue(destination, item_path, "Предмет не удалось создать.")
					continue
			var/inserted
			if(slot)
				inserted = user.equip_to_storage(item, slot, indirect_action = TRUE, del_on_fail = TRUE)
			else
				if(check && i > box_limit)
					// Issuing an outfit caps copies per box. Ask the storage why any skipped copy wouldn't fit.
					if(box_storage.can_insert(item, user, messages = FALSE, force = STORAGE_SOFT_LOCKED))
						check.rejection_reason = "При выдаче достигнут предел количества копий одного предмета в коробке."
				else
					inserted = box_storage.attempt_insert(item, user, override = TRUE, force = STORAGE_SOFT_LOCKED, messages = FALSE)
				if(!inserted)
					qdel(item)
			if(check && !inserted)
				check.add_outfit_issue(destination, item_path, check.rejection_reason || "Хранилище не приняло предмет.")
		if(check && count > attempt_count)
			check.add_outfit_issue(destination, item_path, "Количество превышает лимит одной примерки.", count - attempt_count)

/// Places the selected box in the backpack and fills it using normal storage restrictions.
/datum/outfit/proc/equip_backpack_box(mob/living/carbon/human/user, mob/living/carbon/human/dummy/outfit_check/check)
	var/datum/storage/box_storage
	if(box)
		if(check && !ispath(box, /obj/item))
			check.add_outfit_issue("box", box, "Не удалось найти тип коробки.")
		else
			var/obj/item/outfit_box = provide_fitting_item(box, user, check)
			if(check)
				check.rejection_reason = null
			if(user.equip_to_storage(outfit_box, ITEM_SLOT_BACK, indirect_action = TRUE, del_on_fail = TRUE))
				box_storage = outfit_box?.atom_storage
			else if(check)
				check.add_outfit_issue("box", box, check.rejection_reason || "Рюкзак не принял коробку.")
	equip_storage_contents(user, box_contents, "box_contents", box_storage = box_storage, check = check)

/**
 * Apply a fingerprint from the passed in human to all items in the outfit
 *
 * Used for forensics setup when the mob is first equipped at roundstart
 * essentially calls add_fingerprint to every defined item on the human
 *
 */
/datum/outfit/proc/apply_fingerprints(mob/living/carbon/human/user)
	if(!istype(user))
		return
	if(user.back)
		user.back.add_fingerprint(user, ignoregloves = TRUE)
		for(var/obj/item/item in user.back.contents)
			item.add_fingerprint(user, ignoregloves = TRUE)
	if(user.wear_id)
		user.wear_id.add_fingerprint(user, ignoregloves = TRUE)
	if(user.w_uniform)
		user.w_uniform.add_fingerprint(user, ignoregloves = TRUE)
	if(user.wear_suit)
		user.wear_suit.add_fingerprint(user, ignoregloves = TRUE)
	if(user.wear_mask)
		user.wear_mask.add_fingerprint(user, ignoregloves = TRUE)
	if(user.wear_neck)
		user.wear_neck.add_fingerprint(user, ignoregloves = TRUE)
	if(user.head)
		user.head.add_fingerprint(user, ignoregloves = TRUE)
	if(user.shoes)
		user.shoes.add_fingerprint(user, ignoregloves = TRUE)
	if(user.gloves)
		user.gloves.add_fingerprint(user, ignoregloves = TRUE)
	// AI EDIT START - Dual ear slots
	// BANDASTATION EDIT START - Dual ear slots
	if(user.ear_right)
		user.ear_right.add_fingerprint(user, ignoregloves = TRUE)
	if(user.ear_left)
		user.ear_left.add_fingerprint(user, ignoregloves = TRUE)
	// BANDASTATION EDIT END
	// AI EDIT END
	if(user.glasses)
		user.glasses.add_fingerprint(user, ignoregloves = TRUE)
	if(user.belt)
		user.belt.add_fingerprint(user, ignoregloves = TRUE)
		for(var/obj/item/item in user.belt.contents)
			item.add_fingerprint(user, ignoregloves = TRUE)
	if(user.s_store)
		user.s_store.add_fingerprint(user, ignoregloves = TRUE)
	if(user.l_store)
		user.l_store.add_fingerprint(user, ignoregloves = TRUE)
	if(user.r_store)
		user.r_store.add_fingerprint(user, ignoregloves = TRUE)
	for(var/obj/item/item as anything in user.get_held_items())
		item.add_fingerprint(user, ignoregloves = TRUE)
	return TRUE

/// Return a list of all the types that are required to disguise as this outfit type
/datum/outfit/proc/get_chameleon_disguise_info()
	// AI EDIT START - Dual ear slots
	var/list/types = list(uniform, suit, back, belt, gloves, shoes, head, mask, neck, ear_right, ear_left, glasses, id, l_pocket, r_pocket, suit_store, r_hand, l_hand) // BANDASTATION EDIT - Dual ear slots
	// AI EDIT END
	types += chameleon_extras
	types += skillchips
	list_clear_nulls(types)
	return types

/// Return a list of types to pregenerate for later equipping
/// This should not be things that do unique stuff in Initialize() based off their location, since we'll be storing them for a while
/datum/outfit/proc/get_types_to_preload()
	var/list/preload = list()
	preload += id
	preload += uniform
	preload += suit
	preload += suit_store
	preload += back
	for(var/list/contents as anything in list(backpack_contents, belt_contents, box_contents))
		for(var/type_to_load in contents)
			var/num_to_load = contents[type_to_load]
			if(!isnum(num_to_load))
				num_to_load = 1
			for(var/i in 1 to num_to_load)
				preload += type_to_load
	preload += belt
	// AI EDIT START - Dual ear slots
	// BANDASTATION EDIT START - Dual ear slots
	preload += ear_right
	preload += ear_left
	// BANDASTATION EDIT END
	// AI EDIT END
	preload += glasses
	preload += gloves
	preload += head
	preload += mask
	preload += neck
	preload += shoes
	preload += l_pocket
	preload += r_pocket
	preload += l_hand
	preload += r_hand
	preload += accessory
	preload += box
	for(var/implant_type in implants)
		preload += implant_type
	for(var/skillpath in skillchips)
		preload += skillpath

	return preload

/// Return a json list of this outfit
/datum/outfit/proc/get_json_data()
	. = list()
	.["outfit_type"] = type
	.["name"] = name
	.["uniform"] = uniform
	.["suit"] = suit
	.["back"] = back
	.["belt"] = belt
	.["gloves"] = gloves
	.["shoes"] = shoes
	.["head"] = head
	.["mask"] = mask
	.["neck"] = neck
	// AI EDIT START - Dual ear slots
	// BANDASTATION EDIT START - Dual ear slots
	.["ear_right"] = ear_right
	.["ear_left"] = ear_left
	// BANDASTATION EDIT END
	// AI EDIT END
	.["glasses"] = glasses
	.["id"] = id
	.["id_trim"] = id_trim
	.["l_pocket"] = l_pocket
	.["r_pocket"] = r_pocket
	.["suit_store"] = suit_store
	.["r_hand"] = r_hand
	.["l_hand"] = l_hand
	.["internals_slot"] = internals_slot
	.["backpack_contents"] = backpack_contents
	.["belt_contents"] = belt_contents
	.["box"] = box
	.["box_contents"] = box_contents
	.["implants"] = implants
	.["accessory"] = accessory
	.["mental_conditioning"] = mental_conditioning
	.["undershirt"] = undershirt
	.["underwear"] = underwear
	.["socks"] = socks

/// Creates an independent draft from a saved outfit, preserving its subtype.
/datum/outfit/proc/duplicate()
	var/datum/outfit/draft = new type
	draft.copy_from(src)
	var/suffix = " (copy)"
	var/base_name = copytext_char(name, 1, MAX_NAME_LEN - length_char(suffix) + 1)
	draft.name = "[base_name][suffix]"
	return draft

/// Copies the common outfit settings and their mutable lists.
/datum/outfit/proc/copy_from(datum/outfit/target)
	name = target.name
	uniform = target.uniform
	suit = target.suit
	back = target.back
	belt = target.belt
	gloves = target.gloves
	shoes = target.shoes
	head = target.head
	mask = target.mask
	neck = target.neck
	// AI EDIT START - Dual ear slots
	// BANDASTATION EDIT START - Dual ear slots
	ear_right = target.ear_right
	ear_left = target.ear_left
	// BANDASTATION EDIT END
	// AI EDIT END
	glasses = target.glasses
	id = target.id
	id_trim = target.id_trim
	l_pocket = target.l_pocket
	r_pocket = target.r_pocket
	suit_store = target.suit_store
	r_hand = target.r_hand
	l_hand = target.l_hand
	internals_slot = target.internals_slot
	backpack_contents = target.backpack_contents?.Copy()
	belt_contents = target.belt_contents?.Copy()
	box = target.box
	box_contents = target.box_contents?.Copy()
	implants = target.implants?.Copy()
	accessory = target.accessory
	mental_conditioning = target.mental_conditioning
	chameleon_extras = islist(target.chameleon_extras) ? target.chameleon_extras.Copy() : target.chameleon_extras
	skillchips = target.skillchips?.Copy()
	preload = target.preload
	undershirt = target.undershirt
	underwear = target.underwear
	socks = target.socks

/// Prompt the passed in mob client to download this outfit as a json blob
/datum/outfit/proc/save_to_file(mob/admin)
	var/stored_data = get_json_data()
	var/json = json_encode(stored_data)
	//Kinda annoying but as far as i can tell you need to make actual file.
	var/f = file("data/TempOutfitUpload")
	fdel(f)
	WRITE_FILE(f,json)
	admin << ftp(f,"[name].json")

/// Create an outfit datum from a list of json data
/datum/outfit/proc/load_from(list/outfit_data)
	//This could probably use more strict validation
	name = outfit_data["name"]
	uniform = text2path(outfit_data["uniform"])
	suit = text2path(outfit_data["suit"])
	back = text2path(outfit_data["back"])
	belt = text2path(outfit_data["belt"])
	gloves = text2path(outfit_data["gloves"])
	shoes = text2path(outfit_data["shoes"])
	head = text2path(outfit_data["head"])
	mask = text2path(outfit_data["mask"])
	neck = text2path(outfit_data["neck"])
	// AI EDIT START - Dual ear slots, preserve legacy outfit uploads
	// BANDASTATION EDIT START - Dual ear slots, preserve legacy outfit uploads
	ear_right = text2path(("ear_right" in outfit_data) ? outfit_data["ear_right"] : outfit_data["ears"])
	ear_left = text2path(outfit_data["ear_left"])
	// BANDASTATION EDIT END
	// AI EDIT END
	glasses = text2path(outfit_data["glasses"])
	id = text2path(outfit_data["id"])
	id_trim = text2path(outfit_data["id_trim"])
	l_pocket = text2path(outfit_data["l_pocket"])
	r_pocket = text2path(outfit_data["r_pocket"])
	suit_store = text2path(outfit_data["suit_store"])
	r_hand = text2path(outfit_data["r_hand"])
	l_hand = text2path(outfit_data["l_hand"])
	internals_slot = outfit_data["internals_slot"]
	backpack_contents = load_storage_contents(outfit_data["backpack_contents"])
	belt_contents = load_storage_contents(outfit_data["belt_contents"])
	box = text2path(outfit_data["box"])
	box_contents = load_storage_contents(outfit_data["box_contents"], MAX_OUTFIT_ITEM_COUNT)
	// Older equips wrote the selected box into the first backpack entry before exporting.
	if(!("box_contents" in outfit_data) && box && length(backpack_contents) && backpack_contents[1] == box && backpack_contents[box] == 1)
		backpack_contents.Remove(box)
	var/list/saved_implants = outfit_data["implants"]
	implants = list()
	if(islist(saved_implants))
		for(var/path in saved_implants)
			var/implant_type = istext(path) ? text2path(path) : null
			if(ispath(implant_type, /obj/item/implant))
				implants += implant_type
	accessory = text2path(outfit_data["accessory"])
	mental_conditioning = outfit_data["mental_conditioning"] == TRUE
	undershirt = load_underclothing_style(outfit_data["undershirt"], /datum/sprite_accessory/clothing/undershirt)
	underwear = load_underclothing_style(outfit_data["underwear"], /datum/sprite_accessory/clothing/underwear)
	socks = load_underclothing_style(outfit_data["socks"], /datum/sprite_accessory/clothing/socks)
	return TRUE

/// Resolves a saved underwear style only within the matching appearance slot.
/datum/outfit/proc/load_underclothing_style(path, family)
	var/style = istext(path) ? text2path(path) : null
	return ispath(style, family) && style != family ? style : null

/// Decodes an item-to-quantity map or a legacy array of item paths (one item per element).
/datum/outfit/proc/load_storage_contents(list/saved_contents, count_limit = INFINITY)
	if(!islist(saved_contents))
		return
	. = list()
	for(var/path in saved_contents)
		var/item_type = istext(path) ? text2path(path) : null
		if(!ispath(item_type, /obj/item))
			continue
		var/count = saved_contents[path]
		if(!isnum(count))
			.[item_type] = min((.[item_type] || 0) + 1, count_limit)
		else if(IS_FINITE__UNSAFE(count) && count >= 1)
			.[item_type] = min(round(count), count_limit)

/datum/outfit/vv_get_dropdown()
	. = ..()
	VV_DROPDOWN_OPTION("", "--- /outfit ---")
	VV_DROPDOWN_OPTION(VV_HK_TO_OUTFIT_EDITOR, "Outfit Editor")

/datum/outfit/vv_do_topic(list/href_list)
	. = ..()

	if(!.)
		return

	if(href_list[VV_HK_TO_OUTFIT_EDITOR])
		usr.client.open_outfit_editor(src)
