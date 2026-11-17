/// Species preference
/datum/preference/choiced/species
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "species"
	priority = PREFERENCE_PRIORITY_SPECIES
	randomize_by_default = FALSE

/datum/preference/choiced/species/deserialize(input, datum/preferences/preferences)
	return GLOB.species_list[sanitize_inlist(input, get_choices_serialized(), SPECIES_HUMAN)]

/datum/preference/choiced/species/serialize(input)
	var/datum/species/species = input
	return initial(species.id)

/datum/preference/choiced/species/create_default_value()
	return /datum/species/human

/datum/preference/choiced/species/is_valid(value, datum/preferences/preferences)
	return ..() && preferences.can_select_character_species(value)

/datum/preference/choiced/species/create_random_value(datum/preferences/preferences)
	var/list/available_species = list()
	for (var/species_type in get_choices())
		if (preferences.can_select_character_species(species_type))
			available_species += species_type
	return length(available_species) ? pick(available_species) : create_default_value()

/datum/preference/choiced/species/init_possible_values()
	var/list/values = list()

	for (var/species_id in get_selectable_species())
		values += GLOB.species_list[species_id]

	return values

/datum/preference/choiced/species/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	target.set_species(value, icon_update = FALSE, pref_load = TRUE)

/datum/preference/choiced/species/compile_constant_data()
	var/list/data = list()

	for (var/species_id in get_selectable_species())
		var/species_type = GLOB.species_list[species_id]
		var/datum/species/species = GLOB.species_prototypes[species_type]

		data[species_id] = list()
		data[species_id]["name"] = species.name
		data[species_id]["desc"] = species.get_species_description()
		data[species_id]["lore"] = species.get_species_lore()
		data[species_id]["icon"] = sanitize_css_class_name(species.name)
		data[species_id]["use_skintones"] = (TRAIT_USES_SKINTONES in species.inherent_traits)
		data[species_id]["sexes"] = species.sexes
		data[species_id]["enabled_features"] = species.get_features()
		data[species_id]["perks"] = species.get_species_perks()
		data[species_id]["diet"] =  species.get_species_diet()
		data[species_id]["required_donator_level"] = species.required_donator_level

	return data

/// Checks the current account tier for a species in the character preferences catalog.
/datum/preferences/proc/can_select_character_species(datum/species/species_type)
	var/required_level = initial(species_type.required_donator_level)
	return !required_level || parent?.get_donator_level() >= required_level
