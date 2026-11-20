/datum/outfit/get_json_data()
	. = ..()
	.["organs"] = organs
	.["prosthetics"] = prosthetics
	.["cyber_organs"] = cyber_organs

/datum/outfit/copy_from(datum/outfit/target)
	. = ..()
	organs = target.organs?.Copy()
	prosthetics = target.prosthetics?.Copy()
	cyber_organs = target.cyber_organs?.Copy()

/datum/outfit/load_from(list/outfit_data)
	. = ..()
	if(!.)
		return
	organs = null
	var/list/organ_text_paths = outfit_data["organs"]
	if(islist(organ_text_paths))
		for(var/path in organ_text_paths)
			var/organ_type = istext(path) ? text2path(path) : null
			if(ispath(organ_type, /obj/item/organ))
				LAZYADD(organs, organ_type)
	prosthetics = load_outfit_cybernetics(outfit_data["prosthetics"], "prosthetics")
	cyber_organs = load_outfit_cybernetics(outfit_data["cyber_organs"], "cyber_organs")
	return TRUE

/// Accepts only concrete types that belong to the saved body or organ slot.
/datum/outfit/proc/load_outfit_cybernetics(list/saved_slots, kind)
	if(!islist(saved_slots))
		return null
	var/list/choices = outfit_cybernetics_catalog()[kind]
	var/list/loaded
	for(var/slot in choices)
		var/path = saved_slots[slot]
		if(!istext(path))
			continue
		var/item_type = text2path(path)
		if(item_type in choices[slot])
			LAZYSET(loaded, slot, item_type)
	return loaded
