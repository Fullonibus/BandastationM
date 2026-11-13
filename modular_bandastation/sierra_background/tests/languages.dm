/// Explicit native-language expectations stay independent of the cultural catalog.
/datum/unit_test/sierra_background_fixture/proc/native_language_cases()
	return list(
		/datum/species/human = /datum/language/common,
		/datum/species/human/felinid = /datum/language/nekomimetic,
		/datum/species/human/cerulean = /datum/language/carptongue,
		/datum/species/lizard = /datum/language/draconic,
		/datum/species/skrell = /datum/language/qurvolious,
		/datum/species/plasmaman = /datum/language/calcic,
		/datum/species/moth = /datum/language/moffic,
		/datum/species/ethereal = /datum/language/voltaic,
		/datum/species/tajaran = /datum/language/siiktajr,
		/datum/species/vulpkanin = /datum/language/canilunzt,
		/datum/species/vox = /datum/language/vox,
		/datum/species/ipc = /datum/language/machine,
		/datum/species/pod = /datum/language/sylvan,
		/datum/species/jelly = /datum/language/slime,
		/datum/species/fly = /datum/language/buzzwords,
	)

/// Reproduce native language loss through the real roundstart preference application.
/datum/unit_test/sierra_background_language_native_regression
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_language_native_regression/Run()
	var/datum/preferences/preferences = make_preferences()
	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/species], "lizard"), "Could not select the native lizard species.")
	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/sierra_background/culture], "other"), "Could not select a culture without a Draconic grant.")
	var/mob/living/carbon/human/character = allocate(/mob/living/carbon/human/consistent)
	preferences.apply_prefs_to(character)
	TEST_ASSERT(is_species(character, /datum/species/lizard), "Roundstart preferences did not create a lizard.")
	TEST_ASSERT(character.has_language(/datum/language/draconic, SPOKEN_LANGUAGE), "Applying roundstart upbringing removed the lizard's native spoken Draconic.")
	TEST_ASSERT(character.has_language(/datum/language/draconic, UNDERSTOOD_LANGUAGE), "Applying roundstart upbringing removed the lizard's native Draconic understanding.")
	var/datum/language_holder/holder = character.get_language_holder()
	TEST_ASSERT(LANGUAGE_SPECIES in holder.spoken_languages[/datum/language/draconic], "Native spoken Draconic lost its species source.")
	TEST_ASSERT(LANGUAGE_SPECIES in holder.understood_languages[/datum/language/draconic], "Native Draconic understanding lost its species source.")

/// Upbringing adds learned languages without replacing the body's native languages.
/datum/unit_test/sierra_background_language_upbringing
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_language_upbringing/Run()
	var/list/species_types = native_language_cases()
	for(var/species_type in species_types)
		var/mob/living/carbon/human/character = allocate(/mob/living/carbon/human/consistent)
		character.set_species(species_type)
		character.apply_sierra_background_languages("other")
		TEST_ASSERT(character.has_language(/datum/language/common, UNDERSTOOD_LANGUAGE), "[species_type] lost the crew's shared language.")
		var/native_language = species_types[species_type]
		var/datum/language_holder/holder = character.get_language_holder()
		TEST_ASSERT(character.has_language(native_language, SPOKEN_LANGUAGE), "[species_type] lost its native spoken language after another upbringing.")
		TEST_ASSERT(character.has_language(native_language, UNDERSTOOD_LANGUAGE), "[species_type] lost its native language understanding after another upbringing.")
		TEST_ASSERT(LANGUAGE_SPECIES in holder.spoken_languages[native_language], "[species_type]'s native spoken language lost its species source.")
		TEST_ASSERT(LANGUAGE_SPECIES in holder.understood_languages[native_language], "[species_type]'s native language understanding lost its species source.")
		TEST_ASSERT(LANGUAGE_BACKGROUND in holder.spoken_languages[/datum/language/common], "[species_type] did not retain the cultural Common grant.")
		var/culture = get_sierra_background_default("culture", species_type)
		character.apply_sierra_background_languages(culture)
		var/list/profile = get_sierra_background_culture_profile(culture)
		for(var/language in profile["languages"])
			TEST_ASSERT(character.has_language(language, SPOKEN_LANGUAGE), "[species_type] did not learn to speak [language] from [culture].")
			TEST_ASSERT(character.has_language(language, UNDERSTOOD_LANGUAGE), "[species_type] did not learn [language] from [culture].")
			TEST_ASSERT(LANGUAGE_BACKGROUND in holder.spoken_languages[language], "[culture]'s spoken language lost its independently removable cultural source.")
			TEST_ASSERT(LANGUAGE_BACKGROUND in holder.understood_languages[language], "[culture]'s language understanding lost its cultural source.")
		character.apply_sierra_background_languages("other")
		TEST_ASSERT(LANGUAGE_SPECIES in holder.spoken_languages[native_language], "Removing [culture] also removed [species_type]'s native spoken source.")
		TEST_ASSERT(LANGUAGE_SPECIES in holder.understood_languages[native_language], "Removing [culture] also removed [species_type]'s native understanding source.")
		if(native_language != /datum/language/common)
			TEST_ASSERT(!(LANGUAGE_BACKGROUND in holder.understood_languages[native_language]), "Removing [culture] left its cultural native-language grant behind.")

/// Apply real roundstart preferences, including Vox and IPC choices outside the background catalog.
/datum/unit_test/sierra_background_language_native_preferences
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_language_native_preferences/Run()
	var/list/species_types = native_language_cases()
	for(var/datum/species/species_type as anything in species_types)
		var/datum/preferences/preferences = make_preferences()
		TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/species], initial(species_type.id)), "Could not select [species_type] through native roundstart preferences.")
		TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/sierra_background/culture], "other"), "Could not select neutral upbringing for [species_type].")
		var/mob/living/carbon/human/character = allocate(/mob/living/carbon/human/consistent)
		var/native_language = species_types[species_type]
		for(var/application in 1 to 2)
			preferences.apply_prefs_to(character)
			TEST_ASSERT_EQUAL(character.dna.species.type, species_type, "Preference application changed the selected body species.")
			var/datum/language_holder/holder = character.get_language_holder()
			TEST_ASSERT(character.has_language(native_language, SPOKEN_LANGUAGE), "[species_type] lost native speech on preference application [application].")
			TEST_ASSERT(character.has_language(native_language, UNDERSTOOD_LANGUAGE), "[species_type] lost native understanding on preference application [application].")
			TEST_ASSERT(LANGUAGE_SPECIES in holder.spoken_languages[native_language], "Preference application converted [species_type]'s speech into a cultural grant.")
			TEST_ASSERT(LANGUAGE_SPECIES in holder.understood_languages[native_language], "Preference application converted [species_type]'s understanding into a cultural grant.")
			TEST_ASSERT(character.can_speak_language(character.get_selected_language()), "Preference application left a stale or unusable selected language for [species_type].")

/// Repeated application must remove only upbringing sources, retaining independently acquired knowledge and blocks.
/datum/unit_test/sierra_background_language_sources
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_language_sources/Run()
	var/mob/living/carbon/human/character = allocate(/mob/living/carbon/human/consistent)
	// Use a human so removing imperial culture must really remove Qurvolious knowledge.
	character.grant_language(/datum/language/spinwarder, ALL, LANGUAGE_QUIRK)
	character.grant_language(/datum/language/codespeak, ALL, LANGUAGE_MIND)
	character.grant_language(/datum/language/terrum, ALL, "independent_training")
	character.add_blocked_language(/datum/language/qurvolious, SPOKEN_LANGUAGE, LANGUAGE_QUIRK)
	character.apply_sierra_background_languages("skrell_imperial")
	character.apply_sierra_background_languages("skrell_imperial")
	TEST_ASSERT(character.has_language(/datum/language/qurvolious, UNDERSTOOD_LANGUAGE), "Imperial upbringing did not teach its language.")
	TEST_ASSERT(!character.can_speak_language(/datum/language/qurvolious), "Upbringing bypassed an independent speech block.")
	var/datum/language_holder/holder = character.get_language_holder()
	var/list/common_sources = holder.understood_languages[/datum/language/common]
	TEST_ASSERT_EQUAL(length(common_sources & list(LANGUAGE_BACKGROUND)), 1, "Repeated application duplicated the background source.")
	character.apply_sierra_background_languages("other")
	TEST_ASSERT(!character.has_language(/datum/language/qurvolious, UNDERSTOOD_LANGUAGE), "Changing upbringing retained its former learned language.")
	TEST_ASSERT(LANGUAGE_QUIRK in holder.blocked_speaking[/datum/language/qurvolious], "Changing upbringing removed another source's speech block.")
	for(var/language in list(/datum/language/spinwarder, /datum/language/codespeak, /datum/language/terrum))
		TEST_ASSERT(character.has_language(language, SPOKEN_LANGUAGE), "Changing upbringing removed independent spoken [language].")
		TEST_ASSERT(character.has_language(language, UNDERSTOOD_LANGUAGE), "Changing upbringing removed independent understanding of [language].")
	character.apply_sierra_background_languages("kssp")
	character.apply_sierra_background_languages("other")
	TEST_ASSERT(character.has_language(/datum/language/spinwarder, SPOKEN_LANGUAGE), "Removing a shared background grant also removed independently learned speech.")
	TEST_ASSERT(character.has_language(/datum/language/spinwarder, UNDERSTOOD_LANGUAGE), "Removing a shared background grant also removed independently learned understanding.")

/// Learned cultural speech is available through an intact tongue without omnitongue.
/datum/unit_test/sierra_background_language_physiology
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_language_physiology/Run()
	var/datum/preferences/preferences = make_preferences()
	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/species], "human"), "Could not select a human to verify learned speech independently of native languages.")
	var/datum/preference/culture = GLOB.preference_entries[/datum/preference/choiced/sierra_background/culture]
	var/mob/living/carbon/human/character = allocate(/mob/living/carbon/human/consistent)
	character.grant_language(/datum/language/voltaic, ALL, LANGUAGE_QUIRK)
	TEST_ASSERT(!character.can_speak_language(/datum/language/voltaic), "Unrelated language knowledge received the cultural speech allowance.")
	character.remove_language(/datum/language/voltaic, ALL, LANGUAGE_QUIRK)

	var/list/culture_languages = list(
		"urlum_upbringing" = /datum/language/qurvolious,
		"mauna_b_upbringing" = /datum/language/qurvolious,
		"plasmaman_technocrat" = /datum/language/calcic,
		"ethereal_sprout" = /datum/language/voltaic,
	)
	for(var/culture_id in culture_languages)
		TEST_ASSERT(preferences.update_preference(culture, culture_id), "Could not select [culture_id] to verify learned speech.")
		preferences.apply_prefs_to(character)
		var/language_type = culture_languages[culture_id]
		TEST_ASSERT(character.has_language(language_type, UNDERSTOOD_LANGUAGE), "[culture_id] did not teach understanding of [language_type].")
		TEST_ASSERT(character.can_speak_language(language_type), "A human with [culture_id] cannot speak [language_type].")
		var/list/row = background_row(preferences, "culture")
		var/datum/language/language = GLOB.language_datum_instances[language_type]
		TEST_ASSERT(language.name in row["language_names"], "The UI does not preview [language_type] for [culture_id].")
	TEST_ASSERT(!character.get_language_holder().omnitongue, "Upbringing enabled omnitongue.")
	var/obj/item/organ/tongue/tongue = character.get_organ_slot(ORGAN_SLOT_TONGUE)
	TEST_ASSERT_NOTNULL(tongue, "Expected the human to have a tongue before removing it.")
	tongue.Remove(character, special = TRUE)
	qdel(tongue)
	TEST_ASSERT(character.has_language(/datum/language/voltaic, UNDERSTOOD_LANGUAGE), "Losing a tongue removed cultural understanding.")
	TEST_ASSERT(!character.can_speak_language(/datum/language/voltaic), "Cultural speech remained possible without a tongue.")

/// Species changes replace only species sources, leaving upbringing and independent grants intact.
/datum/unit_test/sierra_background_language_species_change
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_language_species_change/Run()
	var/mob/living/carbon/human/character = allocate(/mob/living/carbon/human/consistent)
	character.apply_sierra_background_languages("kssp")
	character.grant_language(/datum/language/canilunzt, ALL, LANGUAGE_QUIRK)
	var/list/species_types = native_language_cases()
	var/previous_native_language
	for(var/species_type in list(/datum/species/skrell, /datum/species/lizard, /datum/species/moth, /datum/species/vox, /datum/species/ipc, /datum/species/human))
		character.set_species(species_type)
		TEST_ASSERT(character.has_language(/datum/language/spinwarder, UNDERSTOOD_LANGUAGE), "[species_type] transformation erased the character's upbringing.")
		TEST_ASSERT(character.has_language(/datum/language/canilunzt, UNDERSTOOD_LANGUAGE), "[species_type] transformation erased independently learned knowledge.")
		var/native_language = species_types[species_type]
		var/datum/language_holder/holder = character.get_language_holder()
		TEST_ASSERT(character.has_language(native_language, SPOKEN_LANGUAGE), "Transformation into [species_type] lost its native speech.")
		TEST_ASSERT(character.has_language(native_language, UNDERSTOOD_LANGUAGE), "Transformation into [species_type] lost its native understanding.")
		TEST_ASSERT(LANGUAGE_SPECIES in holder.spoken_languages[native_language], "Transformation into [species_type] lost its native spoken source.")
		TEST_ASSERT(LANGUAGE_SPECIES in holder.understood_languages[native_language], "Transformation into [species_type] lost its native understanding source.")
		if(previous_native_language)
			TEST_ASSERT(!character.has_language(previous_native_language, SPOKEN_LANGUAGE), "Transformation retained the former body's native speech.")
			TEST_ASSERT(!character.has_language(previous_native_language, UNDERSTOOD_LANGUAGE), "Transformation retained the former body's native understanding.")
		previous_native_language = native_language
		TEST_ASSERT(character.has_language(/datum/language/common, UNDERSTOOD_LANGUAGE), "A transformation removed the crew's shared language.")

/// Upbringing follows the mind, while each body retains its native species sources.
/datum/unit_test/sierra_background_language_mind_transfer
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_language_mind_transfer/Run()
	var/mob/living/carbon/human/original = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent)
	original.set_species(/datum/species/skrell)
	original.apply_sierra_background_languages("skrell_imperial")
	original.mind_initialize()
	recipient.set_species(/datum/species/moth)
	recipient.grant_language(/datum/language/spinwarder, ALL, LANGUAGE_QUIRK)
	original.mind.transfer_to(recipient)
	var/datum/language_holder/original_holder = original.get_language_holder()
	var/datum/language_holder/recipient_holder = recipient.get_language_holder()
	TEST_ASSERT(original.has_language(/datum/language/qurvolious, UNDERSTOOD_LANGUAGE), "The vacated Skrell body lost its native language.")
	TEST_ASSERT(LANGUAGE_SPECIES in original_holder.understood_languages[/datum/language/qurvolious], "The vacated body's native source moved with the mind.")
	TEST_ASSERT(!(LANGUAGE_BACKGROUND in original_holder.understood_languages[/datum/language/qurvolious]), "The vacated body retained the transferred cultural source.")
	TEST_ASSERT(recipient.has_language(/datum/language/qurvolious, UNDERSTOOD_LANGUAGE), "The mind lost its learned language in the new body.")
	TEST_ASSERT(LANGUAGE_BACKGROUND in recipient_holder.understood_languages[/datum/language/qurvolious], "The learned language lost its removable cultural source in transfer.")
	TEST_ASSERT(recipient.has_language(/datum/language/moffic, UNDERSTOOD_LANGUAGE), "Transferring a mind removed the recipient Moth's native language.")
	TEST_ASSERT(LANGUAGE_SPECIES in recipient_holder.understood_languages[/datum/language/moffic], "The recipient Moth's native source was replaced by upbringing.")
	TEST_ASSERT(recipient.has_language(/datum/language/spinwarder, UNDERSTOOD_LANGUAGE), "Background transfer removed an independent recipient grant.")
	recipient.apply_sierra_background_languages("other")
	TEST_ASSERT(!recipient.has_language(/datum/language/qurvolious, UNDERSTOOD_LANGUAGE), "Transferred background knowledge lost its removable source.")
	TEST_ASSERT(recipient.has_language(/datum/language/moffic, UNDERSTOOD_LANGUAGE), "Removing transferred upbringing removed the recipient body's native language.")

	var/mob/living/carbon/human/first = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/second = allocate(/mob/living/carbon/human/consistent)
	first.set_species(/datum/species/skrell)
	second.set_species(/datum/species/moth)
	first.apply_sierra_background_languages("skrell_imperial")
	second.apply_sierra_background_languages("nian_caravan")
	first.mind_initialize()
	second.mind_initialize()
	var/datum/mind/first_mind = first.mind
	var/datum/mind/second_mind = second.mind
	first_mind.transfer_to(second)
	second_mind.transfer_to(first)
	TEST_ASSERT(first.has_language(/datum/language/moffic, UNDERSTOOD_LANGUAGE), "A mind swap lost the second character's upbringing.")
	TEST_ASSERT(first.has_language(/datum/language/qurvolious, UNDERSTOOD_LANGUAGE), "A mind swap removed the Skrell body's native language.")
	TEST_ASSERT(second.has_language(/datum/language/qurvolious, UNDERSTOOD_LANGUAGE), "A mind swap lost the first character's upbringing.")
	TEST_ASSERT(second.has_language(/datum/language/moffic, UNDERSTOOD_LANGUAGE), "A mind swap removed the Moth body's native language.")
	var/datum/language_holder/first_holder = first.get_language_holder()
	var/datum/language_holder/second_holder = second.get_language_holder()
	TEST_ASSERT(LANGUAGE_BACKGROUND in first_holder.understood_languages[/datum/language/moffic], "The swapped Moth upbringing lost its cultural source.")
	TEST_ASSERT(LANGUAGE_SPECIES in first_holder.understood_languages[/datum/language/qurvolious], "The Skrell body's native language moved with its mind.")
	TEST_ASSERT(LANGUAGE_BACKGROUND in second_holder.understood_languages[/datum/language/qurvolious], "The swapped Skrell upbringing lost its cultural source.")
	TEST_ASSERT(LANGUAGE_SPECIES in second_holder.understood_languages[/datum/language/moffic], "The Moth body's native language moved with its mind.")
	first.apply_sierra_background_languages("other")
	second.apply_sierra_background_languages("other")
	TEST_ASSERT(!first.has_language(/datum/language/moffic, UNDERSTOOD_LANGUAGE), "Removing the swapped upbringing retained its former learned language.")
	TEST_ASSERT(!second.has_language(/datum/language/qurvolious, UNDERSTOOD_LANGUAGE), "Removing the swapped upbringing retained its former learned language.")
	TEST_ASSERT(first.has_language(/datum/language/qurvolious, UNDERSTOOD_LANGUAGE) && second.has_language(/datum/language/moffic, UNDERSTOOD_LANGUAGE), "Removing swapped upbringing also removed a body's native knowledge.")

/// Languages are derived from the native saved culture, without their own duplicated save data.
/datum/unit_test/sierra_background_language_slots
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_language_slots/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = make_preferences(mock_client)
	var/datum/preference/species = GLOB.preference_entries[/datum/preference/choiced/species]
	var/datum/preference/culture = GLOB.preference_entries[/datum/preference/choiced/sierra_background/culture]
	TEST_ASSERT(preferences.update_preference(species, "skrell"), "Could not prepare the language test's first slot.")
	TEST_ASSERT(preferences.update_preference(culture, "kssp"), "Could not save a Skrell's independently learned upbringing.")
	TEST_ASSERT(preferences.save_character(), "Could not save the first language slot.")
	preferences.switch_to_slot(2)
	TEST_ASSERT(preferences.update_preference(species, "skrell"), "Could not prepare the language test's second slot.")
	TEST_ASSERT(preferences.update_preference(culture, "skrell_imperial"), "Could not save the second slot's imperial upbringing.")
	TEST_ASSERT(preferences.save_character(), "Could not save the second language slot.")
	TEST_ASSERT(preferences.save_preferences(), "Could not flush language slots through native JSON.")
	var/datum/preferences/reloaded = make_preferences(mock_client)
	var/mob/living/carbon/human/character = allocate(/mob/living/carbon/human/consistent)
	reloaded.apply_prefs_to(character)
	TEST_ASSERT(character.has_language(/datum/language/qurvolious, UNDERSTOOD_LANGUAGE), "Reloading the imperial slot did not derive its learned language.")
	TEST_ASSERT(!character.has_language(/datum/language/spinwarder, UNDERSTOOD_LANGUAGE), "Reloading a slot inherited the other slot's language.")
	reloaded.switch_to_slot(1)
	reloaded.apply_prefs_to(character)
	TEST_ASSERT(character.has_language(/datum/language/spinwarder, UNDERSTOOD_LANGUAGE), "Reloading the Soviet slot did not derive its learned language.")
	TEST_ASSERT(character.has_language(/datum/language/qurvolious, UNDERSTOOD_LANGUAGE), "Reapplying the first slot removed the Skrell body's native language.")
	var/datum/language_holder/holder = character.get_language_holder()
	TEST_ASSERT(LANGUAGE_SPECIES in holder.understood_languages[/datum/language/qurvolious], "Switching slots removed the native species source.")
	TEST_ASSERT(!(LANGUAGE_BACKGROUND in holder.understood_languages[/datum/language/qurvolious]), "Switching slots retained the second slot's cultural Qurvolious source.")

/// Common Second Language retains its configured partial understanding across upbringing and body changes.
/datum/unit_test/sierra_background_language_csl
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_language_csl/Run()
	for(var/strength in list(75, 50, 90))
		var/mob/living/carbon/human/character = allocate(/mob/living/carbon/human/consistent)
		var/datum/client_interface/mock_client
		if(strength != 90)
			mock_client = allocate(/datum/client_interface)
			var/datum/preferences/preferences = make_preferences(mock_client)
			mock_client.prefs = preferences
			preferences.all_quirks |= /datum/quirk/csl::name
			TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/choiced/csl_strength], "[strength]%"), "Could not set the native CSL partial understanding preference.")
		character.apply_sierra_background_languages("kssp")
		TEST_ASSERT(character.add_quirk(/datum/quirk/csl, mock_client), "Could not add the real CSL quirk.")
		TEST_ASSERT(!character.has_language(/datum/language/common, UNDERSTOOD_LANGUAGE), "Background Common bypassed CSL at [strength]%.")
		TEST_ASSERT_EQUAL(character.has_partial_language(/datum/language/common), strength, "CSL lost its configured partial understanding or null-client fallback.")
		var/datum/language_holder/csl_holder = character.get_language_holder()
		TEST_ASSERT(LANGUAGE_BACKGROUND in csl_holder.spoken_languages[/datum/language/common], "CSL removed cultural Common speech together with understanding.")
		TEST_ASSERT(character.has_language(/datum/language/common, SPOKEN_LANGUAGE), "CSL incorrectly removed the ability to speak Common.")
		character.apply_sierra_background_languages("skrell_imperial")
		TEST_ASSERT(!character.has_language(/datum/language/common, UNDERSTOOD_LANGUAGE), "Reapplying upbringing restored full Common despite CSL.")
		TEST_ASSERT_EQUAL(character.has_partial_language(/datum/language/common), strength, "Reapplying upbringing changed the selected CSL strength.")
		var/datum/quirk/csl/quirk = character.get_quirk(/datum/quirk/csl)
		if(character.mob_mood)
			character.mob_mood.sanity = 50
		var/list/say_args = list()
		say_args.len = SPEECH_MODS
		say_args[SPEECH_MESSAGE] = "Background language test"
		say_args[SPEECH_FORCED] = FALSE
		say_args[SPEECH_MODS] = list()
		say_args[SPEECH_LANGUAGE] = /datum/language/common
		quirk.translate_parts(character, say_args)
		TEST_ASSERT_EQUAL(say_args[SPEECH_LANGUAGE], /datum/language/qurvolious, "CSL kept the former upbringing cached as its native language.")
		character.set_species(/datum/species/moth)
		TEST_ASSERT(!character.has_language(/datum/language/common, UNDERSTOOD_LANGUAGE), "Species change bypassed CSL's understanding limit.")
		TEST_ASSERT_EQUAL(character.has_partial_language(/datum/language/common), strength, "Species change changed CSL partial understanding.")
		TEST_ASSERT(character.has_language(/datum/language/moffic, SPOKEN_LANGUAGE), "CSL removed the new Moth body's native speech.")
		TEST_ASSERT(character.has_language(/datum/language/moffic, UNDERSTOOD_LANGUAGE), "CSL removed the new Moth body's native understanding.")
		TEST_ASSERT(LANGUAGE_SPECIES in csl_holder.spoken_languages[/datum/language/moffic], "CSL replaced native Moffic speech with another source.")
		TEST_ASSERT(LANGUAGE_SPECIES in csl_holder.understood_languages[/datum/language/moffic], "CSL replaced native Moffic understanding with another source.")
		character.remove_quirk(/datum/quirk/csl)
		TEST_ASSERT(character.has_language(/datum/language/common, UNDERSTOOD_LANGUAGE), "Removing CSL did not restore full Common understanding.")
		var/datum/language_holder/holder = character.get_language_holder()
		TEST_ASSERT(LANGUAGE_BACKGROUND in holder.understood_languages[/datum/language/common], "Removing CSL did not restore the background's own source.")
		TEST_ASSERT(LANGUAGE_SPECIES in holder.understood_languages[/datum/language/common], "Removing CSL did not restore the current body's native Common source.")

	var/mob/living/carbon/human/independent = allocate(/mob/living/carbon/human/consistent)
	independent.apply_sierra_background_languages("kssp")
	independent.grant_language(/datum/language/common, UNDERSTOOD_LANGUAGE, LANGUAGE_MIND)
	TEST_ASSERT(independent.add_quirk(/datum/quirk/csl), "Could not prepare CSL alongside an independent mind grant.")
	independent.apply_sierra_background_languages("other")
	TEST_ASSERT(independent.has_language(/datum/language/common, UNDERSTOOD_LANGUAGE), "CSL integration removed an independent mind source that native CSL preserves.")
	var/datum/language_holder/independent_holder = independent.get_language_holder()
	TEST_ASSERT(LANGUAGE_MIND in independent_holder.understood_languages[/datum/language/common], "Reapplying upbringing changed the source of independent knowledge.")

/// Native Cerulean knowledge and the physical fish-organ bonus remain independent language sources.
/datum/unit_test/sierra_background_language_fish_organs
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_language_fish_organs/Run()
	var/mob/living/carbon/human/cerulean = allocate(/mob/living/carbon/human/consistent)
	cerulean.set_species(/datum/species/human/cerulean)
	cerulean.apply_sierra_background_languages("other")
	var/datum/language_holder/cerulean_holder = cerulean.get_language_holder()
	TEST_ASSERT(cerulean.has_language(/datum/language/carptongue, SPOKEN_LANGUAGE), "Another upbringing removed native Cerulean Carptongue speech.")
	TEST_ASSERT(cerulean.has_language(/datum/language/carptongue, UNDERSTOOD_LANGUAGE), "Another upbringing removed native Cerulean Carptongue understanding.")
	TEST_ASSERT(LANGUAGE_SPECIES in cerulean_holder.spoken_languages[/datum/language/carptongue], "Native Cerulean speech depends only on its temporary fish-organ bonus.")
	TEST_ASSERT(LANGUAGE_SPECIES in cerulean_holder.understood_languages[/datum/language/carptongue], "Native Cerulean understanding depends only on its temporary fish-organ bonus.")
	TEST_ASSERT(cerulean.could_speak_language(/datum/language/carptongue), "Native Cerulean organs cannot articulate their language.")
	var/list/organs = list(
		cerulean.get_organ_by_type(/obj/item/organ/tongue/fish),
		cerulean.get_organ_by_type(/obj/item/organ/liver/fish),
		cerulean.get_organ_by_type(/obj/item/organ/stomach/fish),
	)
	for(var/obj/item/organ/organ as anything in organs)
		TEST_ASSERT_NOTNULL(organ, "Cerulean is missing a native fish organ used by this regression.")
		organ.Remove(cerulean, special = TRUE)
	var/datum/status_effect/organ_set_bonus/fish/fish_bonus = cerulean.has_status_effect(/datum/status_effect/organ_set_bonus/fish)
	TEST_ASSERT(!fish_bonus?.bonus_active, "Removing three native fish organs did not deactivate the set bonus.")
	TEST_ASSERT(LANGUAGE_SPECIES in cerulean_holder.spoken_languages[/datum/language/carptongue], "Losing a physical organ bonus also removed native speech knowledge.")
	TEST_ASSERT(LANGUAGE_SPECIES in cerulean_holder.understood_languages[/datum/language/carptongue], "Losing a physical organ bonus also removed native language understanding.")
	TEST_ASSERT(!(/datum/status_effect/organ_set_bonus/fish in cerulean_holder.understood_languages[/datum/language/carptongue]), "Deactivating the fish-organ bonus retained its temporary language source.")
	for(var/obj/item/organ/organ as anything in organs)
		organ.Insert(cerulean, special = TRUE, movement_flags = DELETE_IF_REPLACED)
	fish_bonus = cerulean.has_status_effect(/datum/status_effect/organ_set_bonus/fish)
	TEST_ASSERT(fish_bonus?.bonus_active, "Reinserting native fish organs did not reactivate the set bonus.")
	TEST_ASSERT(cerulean.has_language(/datum/language/carptongue, UNDERSTOOD_LANGUAGE), "Reactivating native fish anatomy removed existing Carptongue knowledge.")
	TEST_ASSERT(/datum/status_effect/organ_set_bonus/fish in cerulean_holder.understood_languages[/datum/language/carptongue], "Reactivating the fish-organ bonus did not restore its independent language source.")
	TEST_ASSERT(cerulean.could_speak_language(/datum/language/carptongue), "Reinserted Cerulean organs lost their articulation.")
	cerulean.grant_language(/datum/language/carptongue, ALL, LANGUAGE_QUIRK)
	cerulean.apply_sierra_background_languages("other")
	TEST_ASSERT(cerulean.has_language(/datum/language/carptongue, UNDERSTOOD_LANGUAGE), "Reapplying upbringing removed Carptongue knowledge.")
	TEST_ASSERT(LANGUAGE_QUIRK in cerulean_holder.understood_languages[/datum/language/carptongue], "Reapplying upbringing removed independently learned Carptongue.")
	TEST_ASSERT(LANGUAGE_SPECIES in cerulean_holder.understood_languages[/datum/language/carptongue], "Reapplying upbringing removed native Cerulean Carptongue.")

	var/mob/living/carbon/human/infused = allocate(/mob/living/carbon/human/consistent)
	infused.apply_sierra_background_languages("other")
	for(var/organ_type in list(/obj/item/organ/tongue/fish, /obj/item/organ/liver/fish, /obj/item/organ/stomach/fish))
		var/obj/item/organ/organ = allocate(organ_type)
		organ.Insert(infused, special = TRUE, movement_flags = DELETE_IF_REPLACED)
	TEST_ASSERT(infused.has_language(/datum/language/carptongue, UNDERSTOOD_LANGUAGE), "An acquired fish infusion lost its native language bonus.")
	infused.apply_sierra_background_languages("other")
	TEST_ASSERT(infused.has_language(/datum/language/carptongue, SPOKEN_LANGUAGE), "Reapplying upbringing removed acquired fish-infusion speech.")
	TEST_ASSERT(infused.has_language(/datum/language/carptongue, UNDERSTOOD_LANGUAGE), "Reapplying upbringing removed an acquired non-Cerulean fish infusion's grant.")
	var/datum/language_holder/infused_holder = infused.get_language_holder()
	TEST_ASSERT(/datum/status_effect/organ_set_bonus/fish in infused_holder.understood_languages[/datum/language/carptongue], "An acquired fish infusion's grant lost its own source.")

/// Native DNA reconstruction and subsequent mind transfer preserve body and cultural language sources.
/datum/unit_test/sierra_background_language_dna_copy
	parent_type = /datum/unit_test/sierra_background_fixture

/datum/unit_test/sierra_background_language_dna_copy/Run()
	var/list/species_types = native_language_cases()
	for(var/species_type in list(/datum/species/lizard, /datum/species/skrell, /datum/species/moth, /datum/species/vox, /datum/species/ipc))
		var/mob/living/carbon/human/original = allocate(/mob/living/carbon/human/consistent)
		original.set_species(species_type)
		original.apply_sierra_background_languages("kssp")
		original.mind_initialize()
		var/mob/living/carbon/human/reconstructed = allocate(/mob/living/carbon/human/consistent)
		reconstructed.apply_sierra_background_languages("other")
		// Use the native cloning/body-reconstruction primitive, without polling ghosts or running machinery RNG.
		original.dna.copy_dna(reconstructed.dna, COPY_DNA_SE | COPY_DNA_SPECIES)
		TEST_ASSERT_EQUAL(reconstructed.dna.species.type, species_type, "Native DNA copying did not reconstruct the source species.")
		var/native_language = species_types[species_type]
		var/datum/language_holder/holder = reconstructed.get_language_holder()
		TEST_ASSERT(reconstructed.has_language(native_language, SPOKEN_LANGUAGE), "DNA reconstruction removed [species_type]'s native speech.")
		TEST_ASSERT(reconstructed.has_language(native_language, UNDERSTOOD_LANGUAGE), "DNA reconstruction removed [species_type]'s native understanding.")
		TEST_ASSERT(LANGUAGE_SPECIES in holder.spoken_languages[native_language], "The reconstructed body's speech lost its native species source.")
		TEST_ASSERT(LANGUAGE_SPECIES in holder.understood_languages[native_language], "The reconstructed body's understanding lost its native species source.")
		original.mind.transfer_to(reconstructed)
		TEST_ASSERT(reconstructed.has_language(native_language, SPOKEN_LANGUAGE), "Moving the mind into the reconstructed body removed native speech.")
		TEST_ASSERT(reconstructed.has_language(native_language, UNDERSTOOD_LANGUAGE), "Moving the mind into the reconstructed body removed native understanding.")
		TEST_ASSERT(LANGUAGE_SPECIES in holder.understood_languages[native_language], "Mind transfer replaced the reconstructed body's native source.")
		TEST_ASSERT(LANGUAGE_BACKGROUND in holder.understood_languages[/datum/language/spinwarder], "Mind transfer into the reconstructed body lost upbringing knowledge.")
		reconstructed.apply_sierra_background_languages("other")
		TEST_ASSERT(!reconstructed.has_language(/datum/language/spinwarder, UNDERSTOOD_LANGUAGE), "Replacing reconstructed upbringing retained its former learned language.")
		TEST_ASSERT(reconstructed.has_language(native_language, UNDERSTOOD_LANGUAGE), "Replacing reconstructed upbringing also removed the body's native knowledge.")
