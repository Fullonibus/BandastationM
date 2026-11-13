/// Model numbers survive editing and a savefile round trip, while organic names retain their restrictions.
/datum/unit_test/ipc_numbered_names/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences, mock_client)
	var/datum/preference/name/real_name/name_preference = GLOB.preference_entries[/datum/preference/name/real_name]
	var/datum/preference/choiced/species/species_preference = GLOB.preference_entries[/datum/preference/choiced/species]
	preferences.value_cache[/datum/preference/choiced/species] = /datum/species/ipc
	TEST_ASSERT(preferences.update_preference(name_preference, "R2-D2"), "The preferences editor rejected an IPC model number.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/name/real_name), "R2-D2", "The preferences editor removed an IPC's model number.")
	var/list/save_data = list()
	TEST_ASSERT(name_preference.write(save_data, "R2-D2", preferences), "A valid IPC model name could not be saved.")
	TEST_ASSERT_EQUAL(save_data["real_name"], "R2-D2", "Serializing the IPC name removed its digits.")
	TEST_ASSERT_EQUAL(name_preference.read(save_data, preferences), "R2-D2", "Loading the IPC name removed its digits.")
	TEST_ASSERT(!name_preference.is_valid(list("R2-D2"), preferences), "An IPC name accepted non-text input.")
	TEST_ASSERT(!name_preference.is_valid("<b>R2-D2</b>", preferences), "An IPC name accepted markup without sanitization.")

	species_preference.post_write(/datum/species/human, preferences)
	var/organic_name = preferences.read_preference(/datum/preference/name/real_name)
	TEST_ASSERT(!findtext(organic_name, "2"), "Changing species retained the IPC model number in the cached name.")
	TEST_ASSERT(name_preference.is_valid(organic_name, preferences), "Changing species left an invalid organic name.")
	TEST_ASSERT(!name_preference.is_valid("R2-D2", preferences), "An organic name accepted IPC model digits.")
	TEST_ASSERT(name_preference.write(save_data, organic_name, preferences), "The normalized organic name could not be saved.")
	TEST_ASSERT_EQUAL(name_preference.read(save_data, preferences), organic_name, "The organic name changed during a savefile round trip.")

	var/datum/preference/name/backup_human/backup_preference = GLOB.preference_entries[/datum/preference/name/backup_human]
	TEST_ASSERT_EQUAL(backup_preference.deserialize("Unit 42", preferences), "Unit", "The backup human name inherited IPC naming rules.")
	species_preference.post_write(/datum/species/ipc, preferences)
	TEST_ASSERT(preferences.update_preference(name_preference, "Model 42"), "Changing back into an IPC did not restore numbered names.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/name/real_name), "Model 42", "The restored IPC lost its model number.")

/// IPC preferences reject every quirk, including stale selections and direct UI actions.
/datum/unit_test/ipc_quirk_preferences/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences, mock_client)
	preferences.value_cache[/datum/preference/choiced/species] = /datum/species/ipc
	preferences.all_quirks = list()
	var/datum/preference_middleware/quirks/middleware = locate() in preferences.middleware
	TEST_ASSERT_NOTNULL(middleware, "The preferences fixture had no quirk middleware.")
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	var/list/data = middleware.get_ui_data(ipc)
	var/list/disallowed = data["species_disallowed_quirks"]
	for(var/quirk_name in SSquirks.quirks)
		TEST_ASSERT(quirk_name in disallowed, "The preferences menu allowed an IPC to select [quirk_name].")

	var/vegetarian_name = /datum/quirk/vegetarian::name
	middleware.give_quirk(list("quirk" = vegetarian_name), ipc)
	TEST_ASSERT_EQUAL(length(preferences.all_quirks), 0, "A direct UI action added an IPC quirk.")
	preferences.all_quirks = list(vegetarian_name, /datum/quirk/monochromatic::name)
	mock_client.prefs = preferences
	SSquirks.AssignQuirks(ipc, mock_client)
	mock_client.prefs = null
	TEST_ASSERT_EQUAL(length(ipc.quirks), 0, "A stale saved selection applied quirks to an IPC at spawn.")
	preferences.validate_quirks()
	TEST_ASSERT_EQUAL(length(preferences.all_quirks), 0, "Loading an IPC's saved selection retained incompatible quirks.")

	preferences.value_cache[/datum/preference/choiced/species] = /datum/species/human
	middleware.post_set_preference(ipc, "species", /datum/species/human)
	middleware.give_quirk(list("quirk" = vegetarian_name), ipc)
	TEST_ASSERT(vegetarian_name in preferences.all_quirks, "Changing the selected species back to human did not restore quirk selection.")
	data = middleware.get_ui_data(ipc)
	disallowed = data["species_disallowed_quirks"]
	TEST_ASSERT(!(vegetarian_name in disallowed), "The preferences menu still blocked a normal human quirk.")
	preferences.validate_quirks()
	TEST_ASSERT(vegetarian_name in preferences.all_quirks, "Validation removed a compatible human quirk.")

/// Becoming an IPC removes quirk effects and processing without removing unrelated trait sources.
/datum/unit_test/ipc_quirk_lifecycle/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.mind_initialize()
	TEST_ASSERT(human.add_quirk(/datum/quirk/light_step, add_unique = FALSE, announce = FALSE), "The human control could not gain Light Step.")
	TEST_ASSERT(human.add_quirk(/datum/quirk/jolly, add_unique = FALSE, announce = FALSE), "The human control could not gain Jolly.")
	var/datum/quirk/light_step/light_step = human.get_quirk(/datum/quirk/light_step)
	var/datum/quirk/jolly/jolly = human.get_quirk(/datum/quirk/jolly)
	TEST_ASSERT(HAS_TRAIT_FROM(human, TRAIT_LIGHT_STEP, QUIRK_TRAIT), "The human quirk did not apply its trait.")
	TEST_ASSERT(jolly in SSquirks.processing, "The human processing quirk did not start processing.")
	ADD_TRAIT(human, TRAIT_LIGHT_STEP, TRAIT_SOURCE_UNIT_TESTS)
	human.set_species(/datum/species/ipc)
	TEST_ASSERT_EQUAL(length(human.quirks), 0, "The transformed IPC retained quirk datums.")
	TEST_ASSERT(QDELETED(light_step) && QDELETED(jolly), "The transformed IPC left its old quirks alive.")
	TEST_ASSERT(!(jolly in SSquirks.processing), "A removed IPC quirk kept processing.")
	TEST_ASSERT(!HAS_TRAIT_FROM(human, TRAIT_LIGHT_STEP, QUIRK_TRAIT), "The IPC retained its old quirk's trait source.")
	TEST_ASSERT(HAS_TRAIT_FROM(human, TRAIT_LIGHT_STEP, TRAIT_SOURCE_UNIT_TESTS), "Removing quirks also removed an unrelated trait source.")
	REMOVE_TRAIT(human, TRAIT_LIGHT_STEP, TRAIT_SOURCE_UNIT_TESTS)
	for(var/quirk_type in SSquirks.quirk_prototypes)
		TEST_ASSERT(!human.add_quirk(quirk_type, add_unique = FALSE, announce = FALSE), "An IPC accepted [quirk_type] through runtime assignment.")
	var/datum/quirk/light_step/direct = allocate(/datum/quirk/light_step)
	TEST_ASSERT(!direct.add_to_holder(human), "Direct quirk attachment bypassed the IPC restriction.")
	TEST_ASSERT_NULL(direct.quirk_holder, "A rejected quirk kept an IPC holder reference.")
	human.set_species(/datum/species/human)
	TEST_ASSERT(human.add_quirk(/datum/quirk/light_step, add_unique = FALSE, announce = FALSE), "Returning to human did not restore runtime quirk assignment.")

/// A rejected transfer must delete its detached datum while ordinary human transfers still work.
/datum/unit_test/ipc_quirk_transfer/Run()
	var/mob/living/carbon/human/source = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	TEST_ASSERT(source.add_quirk(/datum/quirk/light_step, add_unique = FALSE, announce = FALSE), "The transfer source could not gain its quirk.")
	var/datum/quirk/transferred = source.get_quirk(/datum/quirk/light_step)
	source.transfer_quirk_datums(ipc)
	TEST_ASSERT_EQUAL(length(source.quirks), 0, "A rejected transfer retained the quirk on its old holder.")
	TEST_ASSERT_EQUAL(length(ipc.quirks), 0, "A quirk transfer bypassed the IPC restriction.")
	TEST_ASSERT(QDELETED(transferred), "The rejected IPC transfer leaked a detached quirk datum.")
	TEST_ASSERT(!HAS_TRAIT(source, TRAIT_LIGHT_STEP) && !HAS_TRAIT(ipc, TRAIT_LIGHT_STEP), "A rejected transfer left a quirk effect behind.")

	var/mob/living/carbon/human/organic = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(source.add_quirk(/datum/quirk/light_step, add_unique = FALSE, announce = FALSE), "The organic transfer fixture could not regain its quirk.")
	transferred = source.get_quirk(/datum/quirk/light_step)
	source.transfer_quirk_datums(organic)
	TEST_ASSERT_EQUAL(length(source.quirks), 0, "An ordinary quirk transfer did not detach its old holder.")
	TEST_ASSERT_EQUAL(organic.get_quirk(/datum/quirk/light_step), transferred, "A human-to-human transfer lost its quirk datum.")
	TEST_ASSERT(HAS_TRAIT(organic, TRAIT_LIGHT_STEP), "The human recipient did not receive its transferred quirk effect.")

/// Restoring an organic profile must check its restored species rather than the body's previous IPC species.
/datum/unit_test/ipc_quirk_profile_restore/Run()
	var/mob/living/carbon/human/source = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(source.add_quirk(/datum/quirk/light_step, add_unique = FALSE, announce = FALSE), "The organic profile source could not gain its quirk.")
	var/datum/human_appearance_profile/profile = allocate(/datum/human_appearance_profile, source)
	allocated += profile.dna
	allocated += profile.quirks
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent)
	target.set_species(/datum/species/ipc)
	profile.apply_to(target)
	TEST_ASSERT(is_species(target, /datum/species/human), "The profile did not restore its organic species.")
	TEST_ASSERT(target.has_quirk(/datum/quirk/light_step), "Restoring a human profile into a former IPC lost its human quirk.")
	TEST_ASSERT(HAS_TRAIT_FROM(target, TRAIT_LIGHT_STEP, QUIRK_TRAIT), "The restored organic profile's quirk had no effect.")

/// Both medical HUDs reject IPCs across initialization, sensor changes, health updates and transformations.
/datum/unit_test/ipc_medical_hud_exclusion/Run()
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left, /datum/species/ipc)
	var/datum/atom_hud/basic_hud = GLOB.huds[DATA_HUD_MEDICAL_BASIC]
	var/datum/atom_hud/advanced_hud = GLOB.huds[DATA_HUD_MEDICAL_ADVANCED]
	var/datum/atom_hud/diagnostic_hud = GLOB.huds[DATA_HUD_DIAGNOSTIC]
	var/datum/atom_hud/security_hud = GLOB.huds[DATA_HUD_SECURITY_ADVANCED]
	TEST_ASSERT(!basic_hud.hud_atoms_all_z_levels[ipc], "A newly initialized IPC appeared in the basic medical HUD.")
	TEST_ASSERT(!advanced_hud.hud_atoms_all_z_levels[ipc], "A newly initialized IPC appeared in the advanced medical HUD.")
	TEST_ASSERT(diagnostic_hud.hud_atoms_all_z_levels[ipc], "Medical HUD exclusion hid the IPC from diagnostics.")
	TEST_ASSERT(security_hud.hud_atoms_all_z_levels[ipc], "Medical HUD exclusion hid the IPC from security.")

	ADD_TRAIT(ipc, TRAIT_BASIC_HEALTH_HUD_VISIBLE, TRAIT_SOURCE_UNIT_TESTS)
	ipc.prepare_data_huds()
	ipc.adjust_brute_loss(10)
	ipc.med_hud_set_health()
	ipc.med_hud_set_status()
	TEST_ASSERT(!basic_hud.hud_atoms_all_z_levels[ipc], "Suit sensors or HUD preparation re-added an IPC to the basic medical HUD.")
	TEST_ASSERT(!advanced_hud.hud_atoms_all_z_levels[ipc], "Health updates re-added an IPC to the advanced medical HUD.")

	ipc.set_species(/datum/species/human)
	TEST_ASSERT(basic_hud.hud_atoms_all_z_levels[ipc], "Changing back to a human did not restore the basic medical HUD.")
	TEST_ASSERT(advanced_hud.hud_atoms_all_z_levels[ipc], "Changing back to a human did not restore the advanced medical HUD.")
	ipc.set_species(/datum/species/ipc)
	TEST_ASSERT(!basic_hud.hud_atoms_all_z_levels[ipc], "A second IPC transformation retained the basic medical HUD.")
	TEST_ASSERT(!advanced_hud.hud_atoms_all_z_levels[ipc], "A second IPC transformation retained the advanced medical HUD.")
	REMOVE_TRAIT(ipc, TRAIT_BASIC_HEALTH_HUD_VISIBLE, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(ipc, TRAIT_BASIC_HEALTH_HUD_VISIBLE, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!basic_hud.hud_atoms_all_z_levels[ipc], "Toggling suit sensors made an IPC visible to the basic medical HUD.")
