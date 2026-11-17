/// Use the real preferences constructor and JSON storage without touching player save directories.
/datum/preferences/sierra_background_test/load_path(ckey, filename = "preferences.json")
	path = "data/sierra_background_tests/[ckey]-[filename]"

/datum/preferences/sierra_background_test/Destroy(force)
	// Mock clients are allocated separately; release both sides before the garbage collector runs.
	if(parent?.prefs == src)
		parent.prefs = null
	parent = null
	return ..()

/datum/unit_test/sierra_background_fixture
	abstract_type = /datum/unit_test/sierra_background_fixture
	var/list/test_save_paths = list()
	var/list/original_species_choices
	var/species_choices_overridden = FALSE

/datum/unit_test/sierra_background_fixture/Destroy()
	. = ..()
	if(species_choices_overridden)
		var/datum/preference/choiced/species/preference = GLOB.preference_entries[/datum/preference/choiced/species]
		preference.cached_values = original_species_choices
	original_species_choices = null
	for(var/test_path in test_save_paths)
		fdel(test_path)
		fdel(PREFS_BACKUP_PATH(test_path))
	test_save_paths = null

/datum/unit_test/sierra_background_fixture/proc/make_preferences(datum/client_interface/mock_client)
	if(!species_choices_overridden)
		// CI has a human-only server config; fixture coverage must not depend on the local allowlist.
		var/datum/preference/choiced/species/preference = GLOB.preference_entries[/datum/preference/choiced/species]
		original_species_choices = preference.cached_values
		var/list/species_choices = preference.get_choices()
		preference.cached_values = species_choices.Copy()
		for(var/species_id in GLOB.species_list)
			preference.cached_values |= GLOB.species_list[species_id]
		species_choices_overridden = TRUE
	if(!mock_client)
		mock_client = allocate(/datum/client_interface)
		mock_client.donator_level = DONATOR_TIER_5
	var/datum/preferences/preferences = allocate(/datum/preferences/sierra_background_test, mock_client)
	test_save_paths |= preferences.path
	return preferences

/datum/unit_test/sierra_background_fixture/proc/background_types()
	return list(
		"culture" = /datum/preference/choiced/sierra_background/culture,
		"homeworld" = /datum/preference/choiced/sierra_background/homeworld,
		"faction" = /datum/preference/choiced/sierra_background/faction,
		"religion" = /datum/preference/choiced/sierra_background/religion,
	)

/datum/unit_test/sierra_background_fixture/proc/notes_types()
	return list(
		"culture" = /datum/preference/text/sierra_background_notes/culture,
		"homeworld" = /datum/preference/text/sierra_background_notes/homeworld,
		"faction" = /datum/preference/text/sierra_background_notes/faction,
		"religion" = /datum/preference/text/sierra_background_notes/religion,
	)

/datum/unit_test/sierra_background_fixture/proc/background_middleware(datum/preferences/preferences)
	for(var/datum/preference_middleware/sierra_background/middleware in preferences.middleware)
		return middleware
	return null

/datum/unit_test/premium_species_preferences
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/premium_species_preferences/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = make_preferences(mock_client)
	var/datum/preference/choiced/species/species_preference = GLOB.preference_entries[/datum/preference/choiced/species]
	var/list/species_choices = species_preference.get_choices()
	var/mob/living/carbon/human/character = allocate(/mob/living/carbon/human/consistent)

	var/list/required_tiers = list(
		SPECIES_FELINE = DONATOR_TIER_5,
		SPECIES_CERULEAN = DONATOR_TIER_5,
		SPECIES_RESOMI = DONATOR_TIER_4,
		SPECIES_DRASK = DONATOR_TIER_2,
	)
	for(var/species_id in required_tiers)
		var/required_tier = required_tiers[species_id]
		var/species_type = GLOB.species_list[species_id]
		mock_client.donator_level = required_tier
		TEST_ASSERT(preferences.update_preference(species_preference, species_id), "T[required_tier] could not choose [species_id].")
		TEST_ASSERT(preferences.save_character(), "Could not save the premium character.")
		preferences.apply_prefs_to(character)
		TEST_ASSERT_EQUAL(character.dna.species.type, species_type, "T[required_tier] did not get the selected [species_id] body.")

		mock_client.donator_level = required_tier - 1
		TEST_ASSERT_EQUAL(preferences.read_preference(species_preference.type), /datum/species/human, "Dropping below T[required_tier] did not lock the cached [species_id] species.")
		TEST_ASSERT(preferences.load_character(), "Could not reload the existing premium character.")
		TEST_ASSERT(!preferences.update_preference(species_preference, species_id), "A tier below T[required_tier] could choose [species_id].")
		TEST_ASSERT(!preferences.write_preference(species_preference, species_id), "A tier below T[required_tier] could write [species_id].")
		TEST_ASSERT_EQUAL(preferences.read_preference(species_preference.type), /datum/species/human, "A tier below T[required_tier] could read [species_id] as an effective preference.")
		preferences.apply_prefs_to(character)
		TEST_ASSERT_EQUAL(character.dna.species.type, /datum/species/human, "A tier below T[required_tier] could spawn as [species_id].")
		TEST_ASSERT(preferences.save_character(), "Could not save the character after dropping below T[required_tier].")
		var/list/save_data = preferences.get_save_data_for_savefile_identifier(PREFERENCE_CHARACTER)
		TEST_ASSERT_EQUAL(save_data[species_preference.savefile_key], species_id, "The temporary fallback replaced the saved species.")
		TEST_ASSERT_EQUAL(preferences.value_cache[species_preference.type], species_type, "The temporary fallback replaced the cached species.")

		species_preference.cached_values = list(species_type)
		TEST_ASSERT_EQUAL(species_preference.create_random_value(preferences), /datum/species/human, "A tier below T[required_tier] could roll [species_id].")
		mock_client.donator_level = required_tier
		TEST_ASSERT_EQUAL(species_preference.create_random_value(preferences), species_type, "T[required_tier] could not roll [species_id].")
		TEST_ASSERT_EQUAL(preferences.read_preference(species_preference.type), species_type, "Regaining T[required_tier] did not restore [species_id].")
		species_preference.cached_values = species_choices

	mock_client.donator_level = DONATOR_TIER_4
	TEST_ASSERT(preferences.update_preference(species_preference, SPECIES_LIZARD), "Tier 4 could not choose a free species.")
	TEST_ASSERT_EQUAL(preferences.read_preference(species_preference.type), /datum/species/lizard, "The free species was not effective.")

/datum/unit_test/donor_job_assigned_profile
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/donor_job_assigned_profile/Run()
	var/datum/preferences/preferences = make_preferences()
	var/datum/job/donor/waiter/job = allocate(/datum/job/donor/waiter)
	var/datum/preference/age = GLOB.preference_entries[/datum/preference/numeric/age]
	var/datum/preference/title = GLOB.preference_entries[/datum/preference/donor_job_titles]
	var/datum/preference/use_current_slot = GLOB.preference_entries[/datum/preference/toggle/late_join_always_current_slot]
	var/first_slot = preferences.default_slot
	var/assigned_slot = first_slot == 1 ? 2 : 1
	preferences.write_preference(age, 45)
	preferences.save_character()
	preferences.switch_to_slot(assigned_slot)
	preferences.write_preference(age, 23)
	preferences.write_preference(title, list(job.title = "Хост сервиса"))
	preferences.save_character()
	preferences.switch_to_slot(first_slot)
	preferences.job_assigned_profiles = list(job.title = assigned_slot)
	preferences.write_preference(use_current_slot, FALSE)
	job.required_character_age = 30

	var/datum/job_character_selection/selection = preferences.select_job_character(job, latejoin = TRUE)
	TEST_ASSERT_EQUAL(preferences.default_slot, first_slot, "Checking a job changed the selected profile.")
	TEST_ASSERT_EQUAL(selection.slot, assigned_slot, "Latejoin ignored the job's assigned profile.")
	TEST_ASSERT_EQUAL(selection.get_eligibility(job), JOB_UNAVAILABLE_AGE, "The active profile's age bypassed the assigned profile's restriction.")
	TEST_ASSERT_EQUAL(preferences.get_donor_job_title(job, selection.slot), "Хост сервиса", "The role variant was read from the wrong slot.")
	qdel(selection)

	preferences.write_preference(use_current_slot, TRUE)
	selection = preferences.select_job_character(job, latejoin = TRUE)
	TEST_ASSERT_EQUAL(selection.slot, first_slot, "Latejoin ignored the explicit current-slot preference.")
	TEST_ASSERT_EQUAL(selection.get_eligibility(job), JOB_AVAILABLE, "Latejoin checked a different profile while using the current slot.")
	qdel(selection)

/// Every native species needs four valid defaults without inheriting human-only lore.
/datum/unit_test/sierra_background_defaults
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_defaults/Run()
	var/datum/preferences/preferences = make_preferences()
	var/list/preference_types = background_types()
	var/list/species_types = list(/datum/species/human, /datum/species/human/felinid, /datum/species/human/cerulean, /datum/species/skrell, /datum/species/lizard, /datum/species/tajaran, /datum/species/vulpkanin, /datum/species/moth, /datum/species/plasmaman, /datum/species/ethereal)
	for(var/species_id in GLOB.species_list)
		species_types |= GLOB.species_list[species_id]
	var/list/native_cultures = list(
		"human" = "tsf_solar",
		"skrell" = "skrell_imperial",
		"lizard" = "moges_upbringing",
		"tajaran" = "adomai_upbringing",
		"vulpkanin" = "altam_upbringing",
		"felinid" = "felinid_community",
		"plasmaman" = "plasmaman_technocrat",
		"moth" = "nian_caravan",
		"ethereal" = "ethereal_sprout",
		"cerulean" = "other",
	)
	var/list/native_worlds = list(
		"human" = "Earth",
		"skrell" = "KverrBalakk",
		"lizard" = "Moges",
		"tajaran" = "Adomai",
		"vulpkanin" = "Altam",
		"plasmaman" = "Boron",
		"moth" = "Zuviyen",
		"ethereal" = "sprout",
	)
	var/list/human_only_worlds = list("Venus", "Earth", "Moon", "Mars", "Ganimed", "Europe", "Titan", "Pluto", "Tellurus", "Asteria")
	for(var/datum/species/species_type as anything in species_types)
		preferences.value_cache[/datum/preference/choiced/species] = species_type
		for(var/category in preference_types)
			var/datum/preference/choiced/sierra_background/preference = GLOB.preference_entries[preference_types[category]]
			var/list/choices = get_sierra_background_choices(category, species_type)
			TEST_ASSERT(length(choices), "[species_type] has no choices for [category].")
			var/list/unique_choices = list()
			unique_choices |= choices
			TEST_ASSERT_EQUAL(length(choices), length(unique_choices), "[species_type] offers a duplicate [category] option.")
			TEST_ASSERT_EQUAL(get_sierra_background_default(category, species_type), choices[1], "The first offered choice must be the native species default.")
			TEST_ASSERT_EQUAL(preference.create_informed_default_value(preferences), choices[1], "A missing preference did not get its species default.")
			TEST_ASSERT_EQUAL(preference.deserialize("removed-background-value", preferences), "removed-background-value", "An obsolete text ID was silently replaced during loading.")
			TEST_ASSERT(!preference.is_valid("removed-background-value", preferences), "Preserved historical text became interactively selectable.")
			TEST_ASSERT_EQUAL(preference.savefile_identifier, PREFERENCE_CHARACTER, "Background must be stored per character.")
			TEST_ASSERT(!preference.can_randomize, "Random appearance must not silently change background.")
			for(var/choice in choices)
				TEST_ASSERT(preference.is_valid(choice, preferences), "An offered [category] option is rejected for [species_type].")
				TEST_ASSERT_EQUAL(preference.deserialize(preference.serialize(choice), preferences), choice, "An allowed option was changed by serialization.")
		var/native_id = initial(species_type.id)
		TEST_ASSERT_EQUAL(get_sierra_background_species(species_type), native_id, "[species_type] was mapped to a foreign species profile.")
		var/expected_culture = native_cultures[native_id] || "other"
		TEST_ASSERT_EQUAL(get_sierra_background_default("culture", species_type), expected_culture, "[species_type] inherited another species' default upbringing.")
		var/expected_world = native_worlds[native_id] || "other"
		TEST_ASSERT_EQUAL(get_sierra_background_default("homeworld", species_type), expected_world, "[species_type] inherited another species' default residence.")
		TEST_ASSERT_EQUAL(get_sierra_background_default("faction", species_type), "none", "[species_type] was assigned a state or organization by default.")
		TEST_ASSERT_EQUAL(get_sierra_background_default("religion", species_type), "none", "[species_type] was assigned a religion by default.")
		var/list/homeworld_choices = get_sierra_background_choices("homeworld", species_type)
		var/list/faction_choices = get_sierra_background_choices("faction", species_type)
		var/list/culture_choices = get_sierra_background_choices("culture", species_type)
		var/is_native_human = species_type == /datum/species/human
		for(var/human_only_world in human_only_worlds)
			TEST_ASSERT_EQUAL((human_only_world in homeworld_choices), is_native_human, "[species_type] has incorrect access to human-only [human_only_world].")
		TEST_ASSERT_EQUAL(("Elysium" in faction_choices), is_native_human, "Human subtypes and other species must not inherit human-only Elysium affiliation.")
		TEST_ASSERT_EQUAL(("elysian" in culture_choices), is_native_human, "Human subtypes and other species must not inherit human-only Elysian upbringing.")
	TEST_ASSERT_NULL(get_sierra_background_species(/obj/item), "An invalid species path was treated as a human profile.")
	TEST_ASSERT_EQUAL(get_sierra_background_default("culture", /obj/item), "other", "An unknown native species must receive a neutral culture default.")
	TEST_ASSERT_EQUAL(get_sierra_background_default("homeworld", /obj/item), "other", "An unknown native species must receive a neutral residence default.")

/// Interactive input is validated, while obsolete saved text is retained for explicit owner correction.
/datum/unit_test/sierra_background_validation
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_validation/Run()
	var/datum/preferences/preferences = make_preferences()
	preferences.value_cache[/datum/preference/choiced/species] = /datum/species/human
	var/datum/preference_middleware/sierra_background/middleware = background_middleware(preferences)
	TEST_ASSERT_NOTNULL(middleware, "Background middleware was not registered.")
	var/list/preference_types = background_types()
	var/list/invalid_values = list(null, 0, 123, list("forged"), "unknown-background", "<script>forged</script>")
	for(var/category in preference_types)
		var/datum/preference/choiced/sierra_background/preference = GLOB.preference_entries[preference_types[category]]
		var/list/choices = get_sierra_background_choices(category, /datum/species/human, preferences.sierra_background_context(category))
		TEST_ASSERT(preferences.update_preference(preference, choices[1]), "Could not prepare a valid baseline before hostile UI input.")
		for(var/invalid_value in invalid_values)
			TEST_ASSERT(!preference.is_valid(invalid_value, preferences), "[category] accepted malformed input.")
			var/normalized = preference.deserialize(invalid_value, preferences)
			if(istext(invalid_value))
				TEST_ASSERT_EQUAL(normalized, invalid_value, "Loading an obsolete text ID destroyed historical background.")
				TEST_ASSERT(!preferences.update_preference(preference, invalid_value), "An invalid text ID escaped direct preference validation.")
			else
				TEST_ASSERT(normalized in choices, "Malformed non-text JSON did not receive a valid default.")
			TEST_ASSERT(middleware.pre_set_preference(null, preference.savefile_key, invalid_value), "The owner UI did not intercept malformed input.")
			TEST_ASSERT(preferences.read_preference(preference.type) in choices, "Rejecting invalid UI input damaged the previous valid choice.")
		var/valid_value = choices[length(choices)]
		TEST_ASSERT(preferences.update_preference(preference, valid_value), "The normal preference update rejected [category].")
		TEST_ASSERT_EQUAL(preferences.read_preference(preference.type), valid_value, "The normal preference update lost a legal [category] choice.")
		TEST_ASSERT(middleware.pre_set_preference(null, preference.savefile_key, "unknown-background"), "The UI middleware did not intercept a forged choice.")
		TEST_ASSERT_EQUAL(preferences.read_preference(preference.type), valid_value, "A forged UI request replaced the previous valid choice.")
		var/list/alien_choices = get_sierra_background_choices(category, /datum/species/skrell)
		for(var/alien_choice in alien_choices)
			if(alien_choice in choices)
				continue
			TEST_ASSERT(!preference.is_valid(alien_choice, preferences), "Human preferences accepted a Skrell-only [category] value.")
			TEST_ASSERT_EQUAL(preference.deserialize(alien_choice, preferences), alien_choice, "Loading formerly legal foreign background destroyed the historical ID.")
			break
	var/list/legacy_values = list(
		list("culture", "Earther", "tsf_solar"),
		list("culture", "OtherCulture", "other"),
		list("culture", "Other Culture", "other"),
		list("faction", "Nano" + "Trasen", "Nanotrasen"),
		list("religion", "Christianity", "Christianity"),
	)
	for(var/list/legacy_value as anything in legacy_values)
		var/datum/preference/choiced/sierra_background/preference = GLOB.preference_entries[preference_types[legacy_value[1]]]
		TEST_ASSERT_EQUAL(preference.deserialize(legacy_value[2], preferences), legacy_value[3], "A supported old preference was not migrated into the own catalogue.")
	preferences.value_cache[/datum/preference/choiced/species] = /datum/species/skrell
	var/datum/preference/choiced/sierra_background/culture/culture = GLOB.preference_entries[/datum/preference/choiced/sierra_background/culture]
	TEST_ASSERT_EQUAL(culture.deserialize("Earther", preferences), "tsf_solar", "Legacy upbringing must remain independent from Skrell genetics.")
	TEST_ASSERT_EQUAL(culture.deserialize("earth_upbringing", preferences), "earth_upbringing", "Loading forbidden historical upbringing silently assigned a new biography.")
	preferences.value_cache[/datum/preference/choiced/species] = /datum/species/human
	var/datum/client_interface/legacy_client = allocate(/datum/client_interface)
	var/datum/preferences/legacy_preferences = make_preferences(legacy_client)
	TEST_ASSERT(legacy_preferences.save_character(), "Could not create the legacy background character tree.")
	var/list/save_data = legacy_preferences.savefile.get_entry("character1")
	save_data["species"] = "human"
	save_data["sierra_culture"] = "Earther"
	save_data["sierra_faction"] = "Nano" + "Trasen"
	save_data["sierra_religion"] = "Christianity"
	TEST_ASSERT(legacy_preferences.save_preferences(), "Could not write legacy background JSON.")
	var/datum/preferences/reloaded = make_preferences(legacy_client)
	TEST_ASSERT_EQUAL(reloaded.read_preference(/datum/preference/choiced/sierra_background/culture), "tsf_solar", "Native JSON loading lost the Earther migration.")
	TEST_ASSERT_EQUAL(reloaded.read_preference(/datum/preference/choiced/sierra_background/faction), "Nanotrasen", "Native JSON loading lost the legacy Nanotrasen migration.")
	TEST_ASSERT_EQUAL(reloaded.read_preference(/datum/preference/choiced/sierra_background/religion), "Christianity", "Native loading silently deleted historical religion.")
	var/list/historical_faith = background_row(reloaded, "religion")
	TEST_ASSERT(historical_faith["invalid_reason"], "Preserving unsupported historical faith did not warn its owner.")
	TEST_ASSERT(reloaded.save_character(), "Could not save the migrated background character.")
	TEST_ASSERT(reloaded.save_preferences(), "Could not flush migrated background JSON.")
	var/datum/preferences/reopened = make_preferences(legacy_client)
	var/list/migrated_data = reopened.savefile.get_entry("character1")
	TEST_ASSERT_EQUAL(migrated_data["sierra_culture"], "tsf_solar", "Resaving retained the old serialized culture ID.")
	TEST_ASSERT_EQUAL(migrated_data["sierra_faction"], "Nanotrasen", "Resaving retained the old serialized faction ID.")
	TEST_ASSERT_EQUAL(migrated_data["sierra_religion"], "Christianity", "Resaving silently replaced historical faith.")

/// Static definitions preserve the catalog, while live rows always describe the current native preference cache.
/datum/unit_test/sierra_background_catalog_and_ui
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_catalog_and_ui/Run()
	var/datum/preferences/preferences = make_preferences()
	preferences.value_cache[/datum/preference/choiced/species] = /datum/species/human
	var/datum/preference_middleware/sierra_background/middleware = background_middleware(preferences)
	TEST_ASSERT_NOTNULL(middleware, "Background middleware was not registered.")
	var/list/catalog = get_sierra_background_catalog()
	var/list/preference_types = background_types()
	var/list/notes_preference_types = notes_types()
	TEST_ASSERT_EQUAL(length(catalog), 6, "The own catalogue must include four original categories, subdivisions and social membership.")
	for(var/category in preference_types)
		var/list/definitions = catalog[category]
		TEST_ASSERT(length(definitions), "The own catalogue has no [category] definitions.")
		for(var/choice in definitions)
			var/list/definition = definitions[choice]
			TEST_ASSERT(istext(choice), "The own catalogue's stable IDs must be strings.")
			TEST_ASSERT(istext(definition["name"]) && length(definition["name"]), "A [category] option is missing its display name.")
			TEST_ASSERT(istext(definition["description"]) && length(definition["description"]), "A [category] option is missing its description.")
	var/list/own_entries = list("culture" = "tsf_solar", "homeworld" = "Earth", "faction" = "Nanotrasen", "religion" = "neochristianity")
	var/list/donor_entries = list("culture" = "Earther", "homeworld" = "Gaia", "faction" = "Sol Central Government", "religion" = "Christianity")
	for(var/category in preference_types)
		var/list/definitions = catalog[category]
		TEST_ASSERT(own_entries[category] in definitions, "The own [category] catalogue was not loaded.")
		TEST_ASSERT(!(donor_entries[category] in definitions), "The raw donor [category] catalogue is still exposed at runtime.")
	var/list/constant_data = middleware.get_constant_data()
	TEST_ASSERT_EQUAL(length(constant_data), length(catalog), "The preferences asset is missing a catalogue category.")
	for(var/category in preference_types)
		var/list/definitions = catalog[category]
		var/list/static_definitions = constant_data[category]
		TEST_ASSERT_EQUAL(length(static_definitions), length(definitions), "The preferences asset is missing [category] definitions.")
		for(var/choice in definitions)
			var/list/definition = definitions[choice]
			var/list/static_definition = static_definitions[choice]
			TEST_ASSERT(islist(static_definition), "The preferences asset omitted [category]/[choice].")
			TEST_ASSERT_EQUAL(length(static_definition), 3, "The preferences asset exposed backend metadata for [category]/[choice].")
			for(var/field in list("name", "description", "extra"))
				TEST_ASSERT(field in static_definition, "The preferences asset omitted [field] for [category]/[choice].")
				TEST_ASSERT_EQUAL(static_definition[field], definition[field], "The preferences asset changed the full [field] for [category]/[choice].")
	var/list/ui_data = middleware.get_ui_data(null)
	var/list/rows = ui_data["sierra_background"]
	TEST_ASSERT_EQUAL(length(rows), 5, "Human UI must have four original categories plus optional subdivisions, without an invented social block.")
	var/list/expected_order = list("faction", "subfaction", "homeworld", "culture", "religion")
	for(var/index in 1 to length(expected_order))
		var/list/row = rows[index]
		TEST_ASSERT_EQUAL(row["category"], expected_order[index], "The background UI categories are not in the requested order.")
	var/list/seen_categories = list()
	for(var/list/row as anything in rows)
		var/category = row["category"]
		TEST_ASSERT((category in preference_types) || category == "subfaction", "The background UI returned an unknown category.")
		if(category == "subfaction")
			TEST_ASSERT_EQUAL(row["preference"], "sierra_subfaction", "Subdivision UI uses an incompatible save key.")
			TEST_ASSERT(!("notes_preference" in row), "Subdivision invented an additional biography editor.")
			continue
		TEST_ASSERT(!(category in seen_categories), "The background UI duplicated a category.")
		seen_categories += category
		var/datum/preference/preference = GLOB.preference_entries[preference_types[category]]
		TEST_ASSERT_EQUAL(row["preference"], preference.savefile_key, "A UI row uses the wrong native preference key.")
		TEST_ASSERT_EQUAL(row["value"], preferences.read_preference(preference.type), "A UI row disagrees with the current character preference.")
		var/datum/preference/text/sierra_background_notes/notes_preference = GLOB.preference_entries[notes_preference_types[category]]
		TEST_ASSERT_EQUAL(row["notes_preference"], notes_preference.savefile_key, "A UI row uses the wrong personal details preference key.")
		TEST_ASSERT_EQUAL(row["notes"], "", "A new character's personal details must start empty.")
		TEST_ASSERT_EQUAL(row["notes_max_length"], 4000, "The UI advertises an incorrect personal details limit.")
		TEST_ASSERT(istext(row["notes_prompt"]) && length(row["notes_prompt"]), "A personal details field is missing its writing prompt.")
		var/list/choices = get_sierra_background_choices(category, /datum/species/human, preferences.sierra_background_context(category))
		TEST_ASSERT_EQUAL(json_encode(row["choices"]), json_encode(choices), "A UI row advertises an incorrect set of species choices.")
		TEST_ASSERT(preferences.update_preference(preference, choices[length(choices)]), "Could not change the choice for the UI refresh check.")
		TEST_ASSERT(preferences.update_preference(notes_preference, "Личные подробности: [category]\nВторая строка."), "Could not change personal details for the UI refresh check.")
	ui_data = middleware.get_ui_data(null)
	rows = ui_data["sierra_background"]
	for(var/list/row as anything in rows)
		var/category = row["category"]
		if(category == "subfaction")
			continue
		TEST_ASSERT_EQUAL(row["value"], preferences.read_preference(preference_types[category]), "The UI kept a stale native value after changing [category].")
		TEST_ASSERT_EQUAL(row["notes"], "Личные подробности: [category]\nВторая строка.", "The UI kept stale personal details after changing [category].")

/// Free text preserves Cyrillic and line breaks, strips markup and bounds characters rather than UTF-8 bytes.
/datum/unit_test/sierra_background_notes
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_notes/Run()
	var/datum/preferences/preferences = make_preferences()
	var/list/preference_types = notes_types()
	var/multiline_text = "Родился на станции.\nСохраняю семейные традиции."
	var/long_text = repeat_string(4000, "Я")
	var/over_limit_text = "[long_text]Лишнее"
	for(var/category in preference_types)
		var/datum/preference/text/sierra_background_notes/preference = GLOB.preference_entries[preference_types[category]]
		TEST_ASSERT_EQUAL(preferences.read_preference(preference.type), "", "A new character has unexpected [category] personal details.")
		TEST_ASSERT_EQUAL(preference.savefile_identifier, PREFERENCE_CHARACTER, "Personal details must be saved per character.")
		TEST_ASSERT(!preference.can_randomize, "Random appearance must not rewrite personal details.")
		TEST_ASSERT(preferences.update_preference(preference, multiline_text), "The editor rejected multiline Cyrillic personal details.")
		TEST_ASSERT_EQUAL(preferences.read_preference(preference.type), multiline_text, "Personal details lost Cyrillic characters or line breaks.")
		TEST_ASSERT_EQUAL(preference.deserialize("<b>Традиции</b>\n<i>Дом</i>", preferences), "Традиции\nДом", "Personal details retained HTML markup.")
		TEST_ASSERT_EQUAL(preference.deserialize(list("forged"), preferences), "", "Malformed personal details did not become an empty string.")
		TEST_ASSERT_EQUAL(preference.deserialize(123, preferences), "", "Numeric personal details did not become an empty string.")
		TEST_ASSERT(!preference.is_valid(list("forged"), preferences), "The personal details validator accepted a list.")
		TEST_ASSERT(preference.is_valid(long_text, preferences), "A valid 4000-character Cyrillic text was rejected because of its UTF-8 byte length.")
		TEST_ASSERT(!preference.is_valid(over_limit_text, preferences), "The personal details validator accepted more than 4000 characters.")
		TEST_ASSERT_EQUAL(preference.deserialize(over_limit_text, preferences), long_text, "An oversized Cyrillic text was not safely truncated at 4000 characters.")
		TEST_ASSERT(preferences.update_preference(preference, over_limit_text), "The normal preference path failed to normalize oversized personal details.")
		TEST_ASSERT_EQUAL(preferences.read_preference(preference.type), long_text, "The personal details cache contains an incorrectly truncated value.")

/// Changing species must normalize the cache immediately, before saving or applying it.
/datum/unit_test/sierra_background_species_change
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_species_change/Run()
	var/datum/preferences/preferences = make_preferences()
	var/datum/preference_middleware/sierra_background/middleware = background_middleware(preferences)
	TEST_ASSERT_NOTNULL(middleware, "Background middleware was not registered.")
	var/list/preference_types = background_types()
	for(var/species_id in list("human", "skrell", "lizard", "moth", "human"))
		TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/species], species_id), "Could not select [species_id].")
		middleware.post_set_preference(null, "species", species_id)
		var/species_type = preferences.read_preference(/datum/preference/choiced/species)
		for(var/category in preference_types)
			var/datum/preference/choiced/sierra_background/preference = GLOB.preference_entries[preference_types[category]]
			var/list/choices = get_sierra_background_choices(category, species_type)
			var/current_value = preferences.read_preference(preference.type)
			TEST_ASSERT(current_value in choices, "Changing to [species_id] left a forbidden [category] cached.")
			TEST_ASSERT(preferences.update_preference(preference, choices[length(choices)]), "Could not choose an offered [category] after changing species.")
			TEST_ASSERT(preference.type in preferences.recently_updated_keys, "Species normalization will not be saved through the native preference path.")

/// Residence is independent of upbringing, main affiliation and personal beliefs.
/datum/unit_test/sierra_background_homeworld_dependencies
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_homeworld_dependencies/Run()
	var/datum/preferences/preferences = make_preferences()
	preferences.value_cache[/datum/preference/choiced/species] = /datum/species/human
	var/datum/preference_middleware/sierra_background/middleware = background_middleware(preferences)
	TEST_ASSERT_NOTNULL(middleware, "Background middleware was not registered.")
	var/datum/preference/homeworld = GLOB.preference_entries[/datum/preference/choiced/sierra_background/homeworld]
	var/datum/preference/culture = GLOB.preference_entries[/datum/preference/choiced/sierra_background/culture]
	var/datum/preference/faction = GLOB.preference_entries[/datum/preference/choiced/sierra_background/faction]
	var/datum/preference/religion = GLOB.preference_entries[/datum/preference/choiced/sierra_background/religion]
	TEST_ASSERT(preferences.update_preference(culture, "tsf_altair"), "Could not prepare independent upbringing.")
	TEST_ASSERT(preferences.update_preference(faction, "Nanotrasen"), "Could not prepare independent corporate affiliation.")
	TEST_ASSERT(preferences.update_preference(religion, "atheism"), "Could not prepare independent personal beliefs.")
	var/list/homeworld_choices = get_sierra_background_choices("homeworld", /datum/species/human)
	for(var/homeworld_id in homeworld_choices)
		TEST_ASSERT(preferences.update_preference(homeworld, homeworld_id), "Could not select an offered residence.")
		middleware.post_set_preference(null, "sierra_homeworld", homeworld_id)
		TEST_ASSERT_EQUAL(preferences.read_preference(culture.type), "tsf_altair", "Residence [homeworld_id] overwrote independent upbringing.")
		TEST_ASSERT_EQUAL(preferences.read_preference(faction.type), "Nanotrasen", "Residence [homeworld_id] overwrote independent main affiliation.")
		TEST_ASSERT_EQUAL(preferences.read_preference(religion.type), "atheism", "Residence [homeworld_id] overwrote independent personal beliefs.")

/// Exercise native save/slot/load constructors and actual JSON disk IO, not a separate mock save implementation.
/datum/unit_test/sierra_background_slots_and_reload
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_slots_and_reload/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = make_preferences(mock_client)
	var/list/preference_types = background_types()
	var/list/notes_preference_types = notes_types()
	var/list/slot_one = list()
	preferences.value_cache[/datum/preference/choiced/species] = /datum/species/human
	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/species], "human"), "Could not prepare the first slot's species.")
	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/name/real_name], "Background Tester"), "Could not set the first slot's name.")
	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/numeric/age], 35), "Could not set the first slot's age.")
	for(var/category in preference_types)
		var/list/choices = get_sierra_background_choices(category, /datum/species/human, preferences.sierra_background_context(category))
		var/choice = choices[length(choices)]
		var/datum/preference/preference = GLOB.preference_entries[preference_types[category]]
		TEST_ASSERT(preferences.update_preference(preference, choice), "Could not set slot one's [category].")
		slot_one[category] = choice
		TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[notes_preference_types[category]], "Первый слот: [category]\nЛичные подробности."), "Could not set slot one's [category] personal details.")
	TEST_ASSERT(preferences.save_character(), "Could not save the first character slot.")
	preferences.switch_to_slot(2)
	TEST_ASSERT_EQUAL(preferences.default_slot, 2, "The native slot switch did not select slot two.")
	var/second_species = preferences.read_preference(/datum/preference/choiced/species)
	for(var/category in preference_types)
		TEST_ASSERT_EQUAL(preferences.read_preference(preference_types[category]), get_sierra_background_default(category, second_species), "A fresh slot inherited [category] from the previous character.")
		TEST_ASSERT_EQUAL(preferences.read_preference(notes_preference_types[category]), "", "A fresh slot inherited [category] personal details from the previous character.")
	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/species], "skrell"), "Could not prepare the second slot's species.")
	var/datum/preference_middleware/sierra_background/middleware = background_middleware(preferences)
	middleware.post_set_preference(null, "species", "skrell")
	var/list/slot_two = list()
	for(var/category in preference_types)
		var/list/choices = get_sierra_background_choices(category, /datum/species/skrell)
		var/choice = choices[1]
		TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[preference_types[category]], choice), "Could not set slot two's [category].")
		slot_two[category] = choice
		TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[notes_preference_types[category]], "Второй слот: [category]\nДругая история."), "Could not set slot two's [category] personal details.")
	TEST_ASSERT(preferences.save_character(), "Could not save the second character slot.")
	preferences.switch_to_slot(1)
	for(var/category in preference_types)
		TEST_ASSERT_EQUAL(preferences.read_preference(preference_types[category]), slot_one[category], "Switching back lost slot one's [category].")
		TEST_ASSERT_EQUAL(preferences.read_preference(notes_preference_types[category]), "Первый слот: [category]\nЛичные подробности.", "Switching back lost slot one's [category] personal details.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/name/real_name), "Background Tester", "Background slot changes damaged the character name.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/numeric/age), 35, "Background slot changes damaged the character age.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/species), /datum/species/human, "Background slot changes damaged the character species.")
	preferences.switch_to_slot(2)
	TEST_ASSERT(preferences.save_preferences(), "Could not flush the native preferences file to disk.")
	TEST_ASSERT(fexists(preferences.path), "The preferences JSON file was not created.")
	var/datum/preferences/reloaded = make_preferences(mock_client)
	TEST_ASSERT_EQUAL(reloaded.default_slot, 2, "A new preferences datum did not restore the active slot.")
	TEST_ASSERT_EQUAL(reloaded.read_preference(/datum/preference/choiced/species), /datum/species/skrell, "A new preferences datum lost slot two's species.")
	for(var/category in preference_types)
		TEST_ASSERT_EQUAL(reloaded.read_preference(preference_types[category]), slot_two[category], "Reopening the JSON file lost slot two's [category].")
		TEST_ASSERT_EQUAL(reloaded.read_preference(notes_preference_types[category]), "Второй слот: [category]\nДругая история.", "Reopening the JSON file lost slot two's [category] personal details.")
	reloaded.switch_to_slot(1)
	for(var/category in preference_types)
		TEST_ASSERT_EQUAL(reloaded.read_preference(preference_types[category]), slot_one[category], "Reopening the JSON file lost slot one's [category].")
		TEST_ASSERT_EQUAL(reloaded.read_preference(notes_preference_types[category]), "Первый слот: [category]\nЛичные подробности.", "Reopening the JSON file lost slot one's [category] personal details.")

/// All four preferences reach the spawned character through the existing apply API.
/datum/unit_test/sierra_background_apply
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_apply/Run()
	var/datum/preferences/preferences = make_preferences()
	preferences.value_cache[/datum/preference/choiced/species] = /datum/species/human
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/original_name = human.real_name
	var/original_species = human.dna.species.type
	human.dna.features["sierra_background_test_sentinel"] = "preserved"
	var/list/preference_types = background_types()
	var/list/notes_preference_types = notes_types()
	for(var/category in preference_types)
		var/datum/preference/choiced/sierra_background/preference = GLOB.preference_entries[preference_types[category]]
		var/list/choices = get_sierra_background_choices(category, /datum/species/human, preferences.sierra_background_context(category))
		var/choice = choices[length(choices)]
		TEST_ASSERT(preferences.update_preference(preference, choice), "Could not prepare a background choice for full preference application.")
		preference.apply_to_human(human, choice, preferences)
		TEST_ASSERT_EQUAL(human.dna.features[preference.savefile_key], choice, "Applying character preferences did not preserve [category] metadata.")
		var/datum/preference/notes_preference = GLOB.preference_entries[notes_preference_types[category]]
		TEST_ASSERT(preferences.update_preference(notes_preference, "Личная история: [category]"), "Could not prepare personal details for full preference application.")
		notes_preference.apply_to_human(human, preferences.read_preference(notes_preference.type), preferences)
		TEST_ASSERT_EQUAL(human.dna.features[notes_preference.savefile_key], "Личная история: [category]", "Applying character preferences did not preserve [category] personal details.")
	TEST_ASSERT_EQUAL(human.real_name, original_name, "Applying background changed the character's name.")
	TEST_ASSERT_EQUAL(human.dna.species.type, original_species, "Applying background changed the character's species.")
	TEST_ASSERT_EQUAL(human.dna.features["sierra_background_test_sentinel"], "preserved", "Applying background replaced unrelated DNA features.")
	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/name/real_name], "Background Tester"), "Could not prepare the normal name preference.")
	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/numeric/age], 35), "Could not prepare the normal age preference.")
	preferences.apply_prefs_to(human)
	for(var/category in preference_types)
		var/datum/preference/preference = GLOB.preference_entries[preference_types[category]]
		TEST_ASSERT_EQUAL(human.dna.features[preference.savefile_key], preferences.read_preference(preference.type), "The full native preference application lost [category].")
		var/datum/preference/notes_preference = GLOB.preference_entries[notes_preference_types[category]]
		TEST_ASSERT_EQUAL(human.dna.features[notes_preference.savefile_key], "Личная история: [category]", "The full native preference application lost [category] personal details.")
	TEST_ASSERT_EQUAL(human.real_name, "Background Tester", "The full preference application damaged the normal name preference.")
	TEST_ASSERT_EQUAL(human.age, 35, "The full preference application damaged the normal age preference.")
