
/client/proc/open_outfit_editor(datum/outfit/target, owns_draft = FALSE)
	var/datum/outfit_editor/ui = new(usr, target, owns_draft)
	ui.ui_interact(usr)

#define OUTFIT_EDITOR_NAME "Outfit-O-Tron 9000"
#define MAX_OUTFIT_SEARCH_RESULTS 250
/datum/outfit_editor
	var/client/owner

	var/dummy_key

	var/datum/outfit/drip
	/// The editor owns the supplied outfit until it is saved.
	var/owns_draft = FALSE
	/// Report for the last completed fitting.
	var/list/outfit_check_result
	/// Outfit configuration used to produce the report.
	var/outfit_check_snapshot
	/// Prevents a second fitting while a previous request is still in progress.
	var/checking_outfit = FALSE

	/// Outfit fields editable as a single item.
	var/static/list/equipment_slots = list(
		"head", "glasses", "ear_right", "ear_left", "neck", "mask",
		"uniform", "suit", "gloves", "suit_store", "back", "id",
		"belt", "l_hand", "r_hand", "shoes", "l_pocket", "r_pocket", "box", "accessory",
	)
	/// Appearance fields that select a registered clothing style.
	var/static/list/underclothing_slots = list("undershirt", "underwear", "socks")
	/// Outfit fields editable as a list of items and quantities.
	var/static/list/storage_slots = list("backpack_contents", "belt_contents", "box_contents")

/datum/outfit_editor/New(user, datum/outfit/target, owns_draft = FALSE)
	owner = CLIENT_FROM_VAR(user)
	src.owns_draft = owns_draft

	if(ispath(target))
		drip = new /datum/outfit
		drip.copy_from(new target)
	else if(istype(target))
		drip = target
	else
		drip = new /datum/outfit
		drip.name = "New Outfit"

/datum/outfit_editor/ui_state(mob/user)
	return ADMIN_STATE(R_NONE)

/datum/outfit_editor/ui_status(mob/user, datum/ui_state/state)
	if(QDELETED(drip))
		return UI_CLOSE
	return ..()

/datum/outfit_editor/Destroy()
	clear_human_dummy(dummy_key)
	if(owns_draft && !(drip in GLOB.custom_outfits))
		qdel(drip)
	drip = null
	owner = null
	return ..()

/datum/outfit_editor/ui_close(mob/user)
	qdel(src)

/datum/outfit_editor/proc/init_dummy()
	dummy_key = "outfit_editor_[REF(src)]"
	generate_dummy_lookalike(dummy_key, owner.mob)
	unset_busy_human_dummy(dummy_key)

/datum/outfit_editor/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "OutfitEditor", OUTFIT_EDITOR_NAME)
		if(!ui.open())
			qdel(ui)
			qdel(src)
			return
		ui.set_autoupdate(FALSE)

/datum/outfit_editor/proc/entry(data)
	if(ispath(data, /obj/item))
		var/obj/item/item = data
		var/item_icon = initial(item.icon)
		var/item_state = initial(item.icon_state)
		if(ispath(item, /obj/item/implant) && !icon_exists(item_icon, item_state))
			var/obj/item/implant/implant = item
			var/obj/item/implantcase/implant_case = /obj/item/implantcase
			item_icon = initial(implant_case.icon)
			item_state = "implantcase-[initial(implant.implant_color)]"
		return list(
			"path" = item,
			"name" = initial(item.name),
			"desc" = initial(item.desc),
			"sprite" = icon2base64(icon(item_icon, item_state, frame = 1)),
		)

	if(ispath(data, /datum/sprite_accessory/clothing))
		var/datum/sprite_accessory/clothing/style = data
		return list("path" = style, "name" = initial(style.name))

	return data

/datum/outfit_editor/proc/serialize_outfit()
	var/list/outfit_slots = drip.get_json_data()
	. = list()
	for(var/key in outfit_slots)
		if((key in storage_slots) || (key in list("implants", "organs", "prosthetics", "cyber_organs")))
			continue
		var/val = outfit_slots[key]
		. += list("[key]" = entry(val))

/// Groups plain item lists or item-to-quantity maps by type for editing and display.
/datum/outfit_editor/proc/count_items(list/items)
	. = list()
	for(var/item_type in items)
		if(!ispath(item_type, /obj/item))
			continue
		var/count = items[item_type]
		.[item_type] = isnum(count) ? count : (.[item_type] || 0) + 1

/// Converts grouped item quantities to rows for TGUI.
/datum/outfit_editor/proc/item_rows(list/counts)
	. = list()
	for(var/item_type in counts)
		var/list/row = entry(item_type)
		row["count"] = counts[item_type]
		. += list(row)

/datum/outfit_editor/ui_data(mob/user)
	var/list/data = list()

	data["outfit"] = serialize_outfit()
	data["saveable"] = !GLOB.custom_outfits.Find(drip)
	data["implants"] = item_rows(count_items(drip.implants))
	data["max_item_count"] = MAX_OUTFIT_ITEM_COUNT
	data["outfit_check"] = (outfit_check_result && outfit_check_snapshot == json_encode(drip.get_json_data())) ? outfit_check_result : null

	var/list/storage = list()
	for(var/slot in storage_slots)
		storage[slot] = item_rows(count_items(drip.vars[slot]))
	data["storage"] = storage
	data["cybernetics"] = cybernetics_rows()

	if(!dummy_key)
		init_dummy()
	var/icon/dummysprite = get_flat_human_icon(null,
		dummy_key = dummy_key,
		showDirs = list(SOUTH),
		outfit_override = drip,
		no_anim = TRUE,
	)
	data["dummy64"] = icon2base64(dummysprite)

	return data


/// Fits the configured items on a disposable copy of the preview body and captures its appearance.
/datum/outfit_editor/proc/check_outfit(datum/tgui/ui)
	if(checking_outfit)
		return FALSE

	checking_outfit = TRUE
	outfit_check_result = null
	var/snapshot = json_encode(drip.get_json_data())
	var/datum/outfit/working_outfit = new
	working_outfit.copy_from(drip)

	var/mob/living/carbon/human/dummy/outfit_check/mannequin = new
	var/icon/fitted_icon
	var/list/issues = list()
	try
		generate_dummy_lookalike(null, ui.user, mannequin)
		working_outfit.equip_items(mannequin, TRUE, mannequin)
		mannequin.update_body()
		fitted_icon = get_flat_existing_human_icon(mannequin, list(SOUTH))
		for(var/key in mannequin.outfit_issues)
			issues += list(mannequin.outfit_issues[key])
	catch(var/exception/error)
		stack_trace("Unable to check outfit fitting: [error]")

	qdel(mannequin)
	qdel(working_outfit)
	checking_outfit = FALSE
	if(!can_edit(ui) || snapshot != json_encode(drip.get_json_data()))
		return FALSE
	if(!fitted_icon)
		to_chat(ui.user, span_warning("Не удалось закончить примерку аутфита."))
		return TRUE
	outfit_check_result = list("dummy64" = icon2base64(fitted_icon), "issues" = issues)
	outfit_check_snapshot = snapshot
	return TRUE

/// Checks the original editor session and current admin rights, including after a picker closes.
/datum/outfit_editor/proc/can_edit(datum/tgui/ui)
	return !QDELETED(src) && !QDELETED(ui) && ui.user?.client == owner && ui_status(ui.user, ui.state) == UI_INTERACTIVE

/datum/outfit_editor/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..() || !can_edit(ui))
		return
	. = TRUE

	var/slot = params["slot"]
	switch(action)
		if("check_outfit")
			return check_outfit(ui)
		if("cyber_choose", "cyber_clear")
			return edit_cybernetics(action, params["kind"], slot, ui)
		if("click", "ctrlClick", "clear")
			if(istext(slot) && (slot in underclothing_slots))
				return edit_underclothing(action, slot, ui)
			if(!istext(slot) || !(slot in equipment_slots))
				return FALSE
			var/previous_item = drip.vars[slot]
			if(action == "clear")
				drip.vars[slot] = null
				outfit_check_result = null
			else if(slot == "box")
				set_item(slot, pick_editor_item(/obj/item/storage/box, ui), previous_item, ui)
			else if(slot == "accessory")
				set_item(slot, pick_editor_item(/obj/item/clothing/accessory, ui), previous_item, ui)
			else if(action == "ctrlClick")
				choose_any_item(slot, previous_item, ui)
			else
				choose_item(slot, previous_item, ui)
		if("storage_add", "storage_count", "storage_remove")
			return edit_storage(action, slot, params, ui)
		if("implant_add")
			var/implant_type = pick_editor_item(/obj/item/implant, ui)
			if(!ispath(implant_type, /obj/item/implant) || !can_edit(ui) || (implant_type in drip.implants))
				return FALSE
			drip.implants = (drip.implants || list()) + implant_type
		if("implant_remove")
			var/implant_type = istext(params["path"]) ? text2path(params["path"]) : null
			if(!ispath(implant_type, /obj/item/implant) || !(implant_type in drip.implants))
				return FALSE
			var/list/implants = drip.implants.Copy()
			implants.RemoveAll(implant_type)
			drip.implants = implants

		if("rename")
			var/old_name = drip.name
			var/newname = tgui_input_text(owner, "What do you want to name this outfit?", OUTFIT_EDITOR_NAME, max_length = MAX_NAME_LEN, ui_state = state)
			if(newname && can_edit(ui) && drip.name == old_name)
				drip.name = newname
		if("save")
			GLOB.custom_outfits |= drip
			SStgui.update_user_uis(owner.mob)
		if("delete")
			GLOB.custom_outfits -= drip
			SStgui.update_user_uis(owner.mob)
		if("toggle_mental_conditioning")
			drip.mental_conditioning = !drip.mental_conditioning
		if("vv")
			owner.debug_variables(drip)

/// Serializes the available limb and organ slots and their current items.
/datum/outfit_editor/proc/cybernetics_rows()
	var/list/catalog = outfit_cybernetics_catalog()
	var/list/organs = drip.get_outfit_organs()
	var/static/list/organ_labels = list(
		ORGAN_SLOT_EYES = "Глаза",
		ORGAN_SLOT_EARS = "Уши",
		ORGAN_SLOT_HEART = "Сердце",
		ORGAN_SLOT_LUNGS = "Лёгкие",
		ORGAN_SLOT_LIVER = "Печень",
		ORGAN_SLOT_STOMACH = "Желудок",
		ORGAN_SLOT_TONGUE = "Язык",
		ORGAN_SLOT_BRAIN = "Мозг",
		ORGAN_SLOT_BRAIN_CEREBELLUM = "Моторика",
		ORGAN_SLOT_BRAIN_CNS = "Нервная система",
		ORGAN_SLOT_BRAIN_HIPPOCAMPUS = "Память",
		ORGAN_SLOT_HUD = "Встроенный интерфейс",
		ORGAN_SLOT_VOICE = "Голосовые связки",
		ORGAN_SLOT_HEART_AID = "Поддержка сердца",
		ORGAN_SLOT_STOMACH_AID = "Поддержка желудка",
		ORGAN_SLOT_BREATHING_TUBE = "Дыхательная трубка",
		ORGAN_SLOT_THRUSTERS = "Двигатели",
		ORGAN_SLOT_LEFT_ARM_AUG = "Устройство левой руки",
		ORGAN_SLOT_RIGHT_ARM_AUG = "Устройство правой руки",
		ORGAN_SLOT_LEFT_ARM_MUSCLE = "Усилитель левой руки",
		ORGAN_SLOT_RIGHT_ARM_MUSCLE = "Усилитель правой руки",
	)
	var/list/limb_rows = list()
	var/list/limb_choices = catalog["prosthetics"]
	for(var/zone in limb_choices)
		limb_rows += list(list(
			"slot" = zone,
			"label" = capitalize(parse_zone(zone)),
			"item" = entry(drip.prosthetics?[zone]),
			"chooseable" = !!length(limb_choices[zone]),
		))
	var/list/organ_rows = list()
	var/list/choices = catalog["cyber_organs"]
	for(var/slot in (organ_labels | choices | organs))
		if(!(slot in choices) && !(slot in organs))
			continue
		organ_rows += list(list(
			"slot" = slot,
			"label" = organ_labels[slot] || capitalize(replacetext(slot, "_", " ")),
			"item" = entry(organs[slot]),
			"chooseable" = (slot in choices),
		))
	return list("prosthetics" = limb_rows, "cyber_organs" = organ_rows)

/// Changes one validated anatomy slot, including replacing a default-slot legacy organ.
/datum/outfit_editor/proc/edit_cybernetics(action, kind, slot, datum/tgui/ui)
	if(!istext(kind) || !istext(slot) || !can_edit(ui))
		return FALSE
	var/list/catalog = outfit_cybernetics_catalog()
	if(!(kind in catalog))
		return FALSE
	var/list/choices = catalog[kind]
	var/list/selected = (kind == "prosthetics" ? drip.prosthetics : drip.get_outfit_organs())
	var/previous = selected?[slot]
	if(!(slot in choices) && !previous)
		return FALSE

	var/picked
	if(action == "cyber_choose")
		var/list/options = list()
		for(var/obj/item/item_type as anything in choices[slot])
			options["[initial(item_type.name)] ([item_type])"] = item_type
		if(!length(options))
			return FALSE
		var/choice = tgui_input_list(owner, "Выберите замену для слота", OUTFIT_EDITOR_NAME, sort_list(options), ui_state = ui.state)
		if(!choice || !can_edit(ui))
			return FALSE
		selected = (kind == "prosthetics" ? drip.prosthetics : drip.get_outfit_organs())
		picked = options[choice]
		if(!picked || selected?[slot] != previous)
			return FALSE
	else if(!previous)
		return FALSE

	var/list/current_replacements = drip.vars[kind]
	var/list/replacements = current_replacements?.Copy() || list()
	if(picked)
		replacements[slot] = picked
	else
		replacements -= slot
	drip.vars[kind] = length(replacements) ? replacements : null

	if(kind == "cyber_organs")
		for(var/obj/item/organ/legacy_type as anything in drip.organs?.Copy())
			if(initial(legacy_type.slot) == slot)
				drip.organs.RemoveAll(legacy_type)

	outfit_check_result = null
	return TRUE

/// Selects an appearance style from the same catalog as character preferences.
/datum/outfit_editor/proc/edit_underclothing(action, slot, datum/tgui/ui)
	if(!can_edit(ui))
		return FALSE
	if(action == "clear")
		drip.vars[slot] = null
		outfit_check_result = null
		return TRUE

	var/list/styles
	switch(slot)
		if("undershirt")
			styles = SSaccessories.undershirt_list
		if("underwear")
			styles = SSaccessories.underwear_list
		if("socks")
			styles = SSaccessories.socks_list
	var/previous = drip.vars[slot]
	var/choice = tgui_input_list(owner, "Choose a clothing style", OUTFIT_EDITOR_NAME, sort_list(styles), ui_state = ui.state)
	if(!choice || !can_edit(ui) || drip.vars[slot] != previous)
		return FALSE
	var/datum/sprite_accessory/clothing/style = styles[choice]
	if(!istype(style))
		return FALSE
	drip.vars[slot] = style.type
	outfit_check_result = null
	return TRUE

/// Adds, removes, or changes the quantity of an item in an editable container.
/datum/outfit_editor/proc/edit_storage(action, slot, list/params, datum/tgui/ui)
	if(!istext(slot) || !(slot in storage_slots))
		return FALSE
	var/item_type = action == "storage_add" ? pick_editor_item(/obj/item, ui) : (istext(params["path"]) ? text2path(params["path"]) : null)
	if(!ispath(item_type, /obj/item) || !can_edit(ui))
		return FALSE

	var/list/contents = count_items(drip.vars[slot])
	var/current_count = contents[item_type]
	switch(action)
		if("storage_add")
			if(current_count >= MAX_OUTFIT_ITEM_COUNT)
				to_chat(owner, span_warning("This item is already at the quantity limit."))
				return FALSE
			contents[item_type] = (current_count || 0) + 1
		if("storage_count")
			var/count = params["count"]
			if(isnull(current_count) || !isnum(count) || !IS_FINITE__UNSAFE(count) || count != round(count) || count < 1 || count > max(MAX_OUTFIT_ITEM_COUNT, current_count))
				return FALSE
			contents[item_type] = count
		if("storage_remove")
			if(!contents.Remove(item_type))
				return FALSE

	drip.vars[slot] = length(contents) ? contents : null
	outfit_check_result = null
	return TRUE

/// Shows a searchable picker constrained to the requested item family.
/datum/outfit_editor/proc/pick_editor_item(item_family, datum/tgui/ui)
	var/search
	if(item_family == /obj/item)
		search = trim(tgui_input_text(owner, "Search by item name or type path.", OUTFIT_EDITOR_NAME, max_length = 160, encode = FALSE, ui_state = ui.state))
		if(!search || !can_edit(ui))
			return

	var/list/options = list()
	for(var/obj/item/item_type as anything in typesof(item_family))
		if(item_type == /obj/item || item_type == /obj/item/implant)
			continue
		if(item_family != /obj/item/implant && (initial(item_type.item_flags) & ABSTRACT))
			continue
		var/item_name = initial(item_type.name)
		var/path = "[item_type]"
		if(search && !findtext(item_name, search) && !findtext(path, search))
			continue
		options["[item_name] ([path])"] = item_type
		if(search && length(options) > MAX_OUTFIT_SEARCH_RESULTS)
			to_chat(owner, span_warning("Too many matches. Search for a more specific name or type path."))
			return

	if(!length(options))
		to_chat(owner, span_warning("No matching items found."))
		return
	var/selection = tgui_input_list(owner, "Choose an item", OUTFIT_EDITOR_NAME, sort_list(options), ui_state = ui.state)
	return selection ? options[selection] : null

/datum/outfit_editor/proc/set_item(slot, obj/item/choice, previous_item, datum/tgui/ui, obj/item/required_suit)
	if(!ispath(choice, /obj/item) || !can_edit(ui))
		return
	if(isnull(initial(choice.icon_state)))
		var/msg = "Warning: This item's icon_state is null, indicating it is very probably not actually a usable item."
		if(tgui_alert(owner, msg, OUTFIT_EDITOR_NAME, list("Use it anyway", "Cancel")) != "Use it anyway")
			return

	if(can_edit(ui) && drip.vars[slot] == previous_item && (!required_suit || drip.suit == required_suit))
		drip.vars[slot] = choice
		outfit_check_result = null

/datum/outfit_editor/proc/choose_any_item(slot, previous_item, datum/tgui/ui)
	var/obj/item/choice = pick_closest_path(FALSE)
	set_item(slot, choice, previous_item, ui)

//this proc will try to give a good selection of items that the user can choose from
//it does *not* give a selection of all items that can fit in a slot because lag;
//most notably the hand and pocket slots because they accept pretty much anything
//also stuff that fits in the belt and back slots are scattered pretty much all over the place
/datum/outfit_editor/proc/choose_item(slot, previous_item, datum/tgui/ui)
	var/list/options = list()
	var/obj/item/suit_type

	switch(slot)
		if("head")
			options = typesof(/obj/item/clothing/head)
		if("glasses")
			options = typesof(/obj/item/clothing/glasses)
		// AI EDIT START - Support independent left and right ear slots
		if("ear_right", "ear_left") // BANDASTATION EDIT - Dual ear slots
		// AI EDIT END
			options = typesof(/obj/item/radio/headset)

		if("neck")
			options = typesof(/obj/item/clothing/neck)
		if("mask")
			options = typesof(/obj/item/clothing/mask)

		if("uniform")
			options = typesof(/obj/item/clothing/under)
		if("suit")
			options = typesof(/obj/item/clothing/suit)
		if("gloves")
			options = typesof(/obj/item/clothing/gloves)

		if("suit_store")
			suit_type = drip.suit
			if(suit_type)
				var/obj/item/clothing/suit/suit = new suit_type // initial() doesn't support lists.
				options = suit.allowed?.Copy()
				qdel(suit)
			if(!length(options)) //nothing will happen, but don't let the user think it's broken
				to_chat(owner, span_warning("No options available for the current suit."))

		if("belt")
			options = typesof(/obj/item/storage/belt)
		if("id")
			options = typesof(/obj/item/card/id)

		if("l_hand")
			choose_any_item(slot, previous_item, ui)
		if("back")
			options = typesof(/obj/item/storage/backpack)
			for(var/obj/item/mod/control/pre_equipped/potential_mod as anything in subtypesof(/obj/item/mod/control/pre_equipped))
				if(!(initial(potential_mod.slot_flags) == ITEM_SLOT_BACK))
					continue
				options |= potential_mod
		if("r_hand")
			choose_any_item(slot, previous_item, ui)

		if("l_pocket")
			choose_any_item(slot, previous_item, ui)
		if("shoes")
			options = typesof(/obj/item/clothing/shoes)
		if("r_pocket")
			choose_any_item(slot, previous_item, ui)

	if(!length(options))
		return
	var/option = tgui_input_list(owner, "Choose an item", OUTFIT_EDITOR_NAME, options, ui_state = ui.state)
	set_item(slot, option, previous_item, ui, suit_type)


#undef MAX_OUTFIT_SEARCH_RESULTS
#undef OUTFIT_EDITOR_NAME
