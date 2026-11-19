#define HERETIC_MOODLET_PRESENT (1<<0)
#define TRAITOR_MOODLET_PRESENT (1<<1)

#define HAS_HERETIC_MOODLET(result) (result & HERETIC_MOODLET_PRESENT)
#define HAS_TRAITOR_MOODLET(result) (result & TRAITOR_MOODLET_PRESENT)

/datum/unit_test/antag_moodlets
	// Saving the typepaths for each type of moodlet we give out here, for ease of access
	var/heretic_moodlet
	var/traitor_moodlet

/datum/unit_test/antag_moodlets/Run()
	var/mob/living/carbon/human/bad_man = allocate(/mob/living/carbon/human/consistent)
	var/datum/antagonist/antag_heretic = /datum/antagonist/heretic
	var/datum/antagonist/antag_traitor = /datum/antagonist/traitor
	heretic_moodlet = initial(antag_heretic.antag_moodlet)
	traitor_moodlet = initial(antag_traitor.antag_moodlet)
	TEST_ASSERT_NOTEQUAL(heretic_moodlet, traitor_moodlet, "Antag moodlets test was ran with two identical moodlets, they should be different types.")

	bad_man.mind_initialize()
	bad_man.mind.add_antag_datum(antag_heretic)

	var/list/mob_mood_list = bad_man.mob_mood.mood_events
	var/result = NONE

	// Check for heretic moodlet
	result = check_moodlets(mob_mood_list)
	TEST_ASSERT(HAS_HERETIC_MOODLET(result), "Upon becoming a heretic, the dummy had no heretic antag moodlet.")
	TEST_ASSERT(!HAS_TRAITOR_MOODLET(result), "Upon becoming a heretic, the dummy had a tratior antag moodlet when it shouldn't have.")

	// Check for heretic and traitor moodlet
	bad_man.mind.add_antag_datum(antag_traitor)
	result = check_moodlets(mob_mood_list)
	TEST_ASSERT(HAS_HERETIC_MOODLET(result), "Upon becoming a traitor-heretic, the dummy had no heretic antag moodlet.")
	TEST_ASSERT(HAS_TRAITOR_MOODLET(result), "Upon becoming a traitor-heretic, the dummy had no traitor antag moodlet.")

	// Remove heretic, we should still have the traitor moodlet
	bad_man.mind.remove_antag_datum(antag_heretic)
	result = check_moodlets(mob_mood_list)
	TEST_ASSERT(!HAS_HERETIC_MOODLET(result), "Upon losing heretic, the dummy had the heretic antag moodlet still.")
	TEST_ASSERT(HAS_TRAITOR_MOODLET(result), "Upon losing heretic, the dummy also lost their traitor antag moodlet, when it should have remained.")

	// Remove traitor, nothing left
	bad_man.mind.remove_antag_datum(antag_traitor)
	result = check_moodlets(mob_mood_list)
	TEST_ASSERT(!HAS_HERETIC_MOODLET(result), "After removing all antag datums, the dummy still had their heretic moodlet.")
	TEST_ASSERT(!HAS_TRAITOR_MOODLET(result), "After removing all antag datums, the dummy still had their traitor moodlet.")

/datum/unit_test/antag_moodlets/proc/check_moodlets(list/in_mood_list)
	var/results = NONE
	for(var/category in in_mood_list)
		var/datum/mood_event/moodie = in_mood_list[category]
		if(istype(moodie, heretic_moodlet))
			results |= HERETIC_MOODLET_PRESENT
		if(istype(moodie, traitor_moodlet))
			results |= TRAITOR_MOODLET_PRESENT

	return results

#undef HERETIC_MOODLET_PRESENT
#undef TRAITOR_MOODLET_PRESENT

#undef HAS_HERETIC_MOODLET
#undef HAS_TRAITOR_MOODLET

/// A standard ERT outfit must not leave role conditioning on the previous body.
/datum/unit_test/ert_mental_conditioning/Run()
	var/mob/living/carbon/human/original = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/replacement = allocate(/mob/living/carbon/human/consistent)
	original.mind_initialize()
	var/datum/mind/ert_mind = original.mind
	var/datum/antagonist/ert/security/ert_antag = allocate(/datum/antagonist/ert/security)
	ert_antag.random_names = FALSE
	ert_mind.add_antag_datum(ert_antag)
	TEST_ASSERT(HAS_TRAIT(original, TRAIT_MENTALLY_CONDITIONED), "The ERT member did not receive conditioning.")

	ert_mind.transfer_to(replacement)
	TEST_ASSERT(!HAS_TRAIT(original, TRAIT_MENTALLY_CONDITIONED), "The ERT outfit left conditioning on the previous body.")
	TEST_ASSERT(HAS_TRAIT(replacement, TRAIT_MENTALLY_CONDITIONED), "Conditioning did not follow the ERT member's mind.")
	ert_mind.remove_antag_datum(ert_antag.type)
	TEST_ASSERT(!HAS_TRAIT(replacement, TRAIT_MENTALLY_CONDITIONED), "The replacement body kept conditioning after removal of the ERT role.")

	replacement.equipOutfit(/datum/outfit/centcom/ert/security)
	TEST_ASSERT(HAS_TRAIT(replacement, TRAIT_MENTALLY_CONDITIONED), "Equipping an ERT outfit separately did not grant conditioning.")
