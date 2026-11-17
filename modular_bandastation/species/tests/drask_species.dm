/datum/unit_test/drask_species/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(!human.has_language(/datum/language/orluum, SPOKEN_LANGUAGE), "A human starts with Orluum.")
	human.set_species(/datum/species/drask, pref_load = TRUE)
	var/datum/species/drask/drask = human.dna.species
	TEST_ASSERT(istype(drask), "Failed to become a Drask.")
	TEST_ASSERT(human.has_language(/datum/language/common, SPOKEN_LANGUAGE), "A Drask should retain Common.")
	TEST_ASSERT(human.can_speak_language(/datum/language/orluum), "A Drask should speak Orluum.")
	var/datum/language/orluum/orluum = GLOB.language_datum_instances[/datum/language/orluum]
	TEST_ASSERT_EQUAL(length(splittext(orluum.get_random_name(), "-")), 3, "A Drask name should have three parts.")
	TEST_ASSERT_EQUAL(human.get_bloodtype().type, /datum/blood_type/drask, "A Drask has the wrong blood type.")
	var/obj/item/organ/heart/heart = human.get_organ_slot(ORGAN_SLOT_HEART)
	TEST_ASSERT_EQUAL(heart?.zone, BODY_ZONE_HEAD, "A Drask heart must be in the head.")
	TEST_ASSERT_EQUAL(drask.thermal_efficiency(human), 1, "A healthy Drask should have full temperature regulation.")

	var/obj/item/organ/thermal_spine/left_spine = human.get_organ_slot(ORGAN_SLOT_ARM_SPINES_L)
	var/obj/item/organ/thermal_spine/right_spine = human.get_organ_slot(ORGAN_SLOT_ARM_SPINES_R)
	TEST_ASSERT_NOTNULL(left_spine.bodypart_overlay, "The left spine has no overlay.")
	TEST_ASSERT_NOTNULL(right_spine.bodypart_overlay, "The right spine has no overlay.")
	TEST_ASSERT(left_spine.icon_state != right_spine.icon_state, "Spine items must use the correct side.")
	left_spine.set_organ_damage(left_spine.maxHealth / 2)
	var/damaged_efficiency = drask.thermal_efficiency(human)
	TEST_ASSERT(damaged_efficiency < 1, "Damaging the spine should reduce regulation.")
	left_spine.Remove(human)
	TEST_ASSERT(drask.thermal_efficiency(human) < damaged_efficiency, "Losing the spine should reduce regulation further.")
	left_spine.Insert(human)
	left_spine.set_organ_damage(0)
	TEST_ASSERT_EQUAL(drask.thermal_efficiency(human), 1, "Healing and replacing the spine should restore regulation.")

	var/datum/preference/choiced/drask_skin_tone/skin_tone = GLOB.preference_entries[/datum/preference/choiced/drask_skin_tone]
	skin_tone.apply_to_human(human, "drask_dark")
	human.update_body(is_creating = TRUE)
	var/obj/item/bodypart/head/head = human.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT_EQUAL(head.draw_color, get_drask_tone_color("drask_dark"), "The Drask palette should tint the limbs.")
	TEST_ASSERT_NULL(human.color, "The Drask palette must not tint the whole mob.")

	human.set_species(/datum/species/human)
	TEST_ASSERT(!human.has_language(/datum/language/orluum, SPOKEN_LANGUAGE), "Changing species left the Drask language behind.")
	TEST_ASSERT_NULL(human.get_organ_slot(ORGAN_SLOT_ARM_SPINES_L), "Changing species left a spine behind.")

/// A fresh character must receive the selected skin tone through the normal preference order.
/datum/unit_test/drask_skin_tone_preferences/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	mock_client.donator_level = DONATOR_TIER_2
	var/datum/preferences/preferences = allocate(/datum/preferences, mock_client)
	mock_client.prefs = preferences
	preferences.value_cache[/datum/preference/choiced/species] = /datum/species/drask
	preferences.value_cache[/datum/preference/choiced/drask_skin_tone] = "drask_dark"
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	preferences.apply_prefs_to(human)
	mock_client.prefs = null
	TEST_ASSERT(istype(human.dna.species, /datum/species/drask), "The preference pipeline did not select a Drask.")
	TEST_ASSERT_EQUAL(human.dna.features[FEATURE_DRASK_SKIN_TONE], "drask_dark", "The preference pipeline lost the selected Drask skin tone.")
	var/obj/item/bodypart/head/head = human.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT_EQUAL(head.draw_color, get_drask_tone_color("drask_dark"), "The preference pipeline did not tint the Drask's limbs.")
