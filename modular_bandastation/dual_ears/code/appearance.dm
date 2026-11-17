// AI EDIT START - Resolve fitted worn assets using the state for the actual slot
/// Choose fitted art, item overrides, then the standard worn file for this inventory slot.
/obj/item/proc/get_worn_icon_for_slot(slot_id, species_id)
	return get_species_worn_icon(species_id, get_worn_icon_state(slot_id), slot_id) || worn_icon || get_default_icon_by_slot(slot_id)
// AI EDIT END
