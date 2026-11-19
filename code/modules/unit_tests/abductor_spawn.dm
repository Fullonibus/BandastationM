/// A ghost role must not inherit crew augmentations or remove them from saved preferences.
/datum/unit_test/abductor_spawn_preferences/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences, mock_client)
	mock_client.prefs = preferences
	preferences.randomise = list()
	preferences.value_cache[/datum/preference/choiced/species] = /datum/species/human
	preferences.value_cache[/datum/preference/name/real_name] = "Augment Tester"
	var/list/augmentations = list(
		"robotic_tongue" = list(),
		"cybernetic_brain" = list(),
		"left_arm_prosthesis" = list("selected_manufacturer" = "General"),
	)
	preferences.value_cache[/datum/preference/body_modifications] = augmentations
	var/original_preferences = json_encode(augmentations)

	var/mob/living/carbon/human/abductor_body = allocate(/mob/living/carbon/human/consistent)
	abductor_body.mock_client = mock_client
	mock_client.mob = abductor_body
	var/datum/dynamic_ruleset/midround/from_ghosts/abductors/ruleset = allocate(/datum/dynamic_ruleset/midround/from_ghosts/abductors)
	TEST_ASSERT(ruleset.apply_prefs_to_body(abductor_body), "The abductor role did not apply character preferences.")
	TEST_ASSERT_EQUAL(abductor_body.real_name, "Augment Tester", "Filtering augmentations also discarded unrelated preferences.")
	TEST_ASSERT(!istype(abductor_body.get_organ_slot(ORGAN_SLOT_TONGUE), /obj/item/organ/tongue/robot), "The abductor inherited the crew's robotic tongue.")
	TEST_ASSERT(!istype(abductor_body.get_organ_slot(ORGAN_SLOT_BRAIN), /obj/item/organ/brain/cybernetic), "The abductor inherited the crew's cybernetic brain.")
	TEST_ASSERT(!IS_ROBOTIC_LIMB(abductor_body.get_bodypart(BODY_ZONE_L_ARM)), "The abductor inherited the crew's prosthetic arm.")
	abductor_body.set_species(/datum/species/abductor)
	TEST_ASSERT(istype(abductor_body.get_organ_slot(ORGAN_SLOT_BRAIN), /obj/item/organ/brain/abductor), "The abductor did not receive a grey brain.")
	TEST_ASSERT(HAS_TRAIT(abductor_body, TRAIT_ABDUCTOR_KNOWLEDGE), "The abductor lost access to its own technology.")
	abductor_body.mock_client = null

	var/mob/living/carbon/human/crew_body = allocate(/mob/living/carbon/human/consistent)
	crew_body.mock_client = mock_client
	mock_client.mob = crew_body
	var/datum/dynamic_ruleset/midround/from_ghosts/ordinary_ruleset = allocate(/datum/dynamic_ruleset/midround/from_ghosts)
	ordinary_ruleset.apply_prefs_to_body(crew_body)
	TEST_ASSERT(istype(crew_body.get_organ_slot(ORGAN_SLOT_TONGUE), /obj/item/organ/tongue/robot), "The default role path stopped applying the robotic tongue preference.")
	TEST_ASSERT(istype(crew_body.get_organ_slot(ORGAN_SLOT_BRAIN), /obj/item/organ/brain/cybernetic), "The default role path stopped applying the cybernetic brain preference.")
	TEST_ASSERT(IS_ROBOTIC_LIMB(crew_body.get_bodypart(BODY_ZONE_L_ARM)), "The default role path stopped applying the prosthetic arm preference.")
	TEST_ASSERT_EQUAL(json_encode(preferences.read_preference(/datum/preference/body_modifications)), original_preferences, "Spawning an abductor modified the saved augmentation choices.")
	crew_body.mock_client = null
	mock_client.mob = null

/// Finalizing any abductor role must handle a replaced or missing tongue and finish the spawn.
/datum/unit_test/abductor_spawn_tongue/Run()
	var/datum/team/abductor_team/team = allocate(/datum/team/abductor_team)
	team.team_number = -1
	for(var/role_path in list(/datum/antagonist/abductor/agent, /datum/antagonist/abductor/scientist, /datum/antagonist/abductor/scientist/onemanteam))
		var/datum/antagonist/abductor/role = allocate(role_path)
		role.team = team
		var/obj/effect/landmark/abductor/spawn_point = allocate(role.landmark_type)
		spawn_point.team_number = team.team_number
		for(var/tongue_path in list(/obj/item/organ/tongue/abductor, /obj/item/organ/tongue/robot, null))
			var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
			body.set_species(/datum/species/abductor)
			body.mind_initialize()
			var/datum/mind/original_mind = body.mind
			var/obj/item/organ/tongue/original_tongue = body.get_organ_slot(ORGAN_SLOT_TONGUE)
			if(isnull(tongue_path))
				original_tongue.Remove(body, special = TRUE)
				qdel(original_tongue)
			else
				original_tongue = new tongue_path()
				original_tongue.replace_into(body)
			role.owner = body.mind
			body.moveToNullspace()
			role.finalize_abductor()
			var/obj/item/organ/tongue/abductor/tongue = body.get_organ_slot(ORGAN_SLOT_TONGUE)
			TEST_ASSERT(istype(tongue), "[role_path] kept an incompatible tongue: [tongue_path].")
			TEST_ASSERT_EQUAL(tongue.mothership, team.name, "[role_path] did not attune the tongue to its team.")
			TEST_ASSERT_EQUAL(get_turf(body), get_turf(spawn_point), "[role_path] did not reach its spawn point after finalization.")
			TEST_ASSERT_NOTNULL(body.get_item_by_slot(ITEM_SLOT_ICLOTHING), "[role_path] did not receive its uniform.")
			TEST_ASSERT_EQUAL(body.mind, original_mind, "[role_path] changed the player's mind during organ replacement.")
			if(tongue_path == /obj/item/organ/tongue/abductor)
				TEST_ASSERT_EQUAL(tongue, original_tongue, "[role_path] unnecessarily replaced a valid abductor tongue.")

		if(role_path == /datum/antagonist/abductor/agent)
			var/mob/living/carbon/human/headless_body = allocate(/mob/living/carbon/human/consistent)
			var/obj/item/bodypart/head = headless_body.get_bodypart(BODY_ZONE_HEAD)
			head.drop_limb()
			headless_body.mind_initialize()
			role.owner = headless_body.mind
			headless_body.moveToNullspace()
			role.finalize_abductor()
			TEST_ASSERT_NULL(headless_body.get_organ_slot(ORGAN_SLOT_TONGUE), "Finalization implanted a tongue without a head to hold it.")
			TEST_ASSERT_EQUAL(get_turf(headless_body), get_turf(spawn_point), "A headless abductor did not reach the spawn point.")
		role.owner = null
		qdel(spawn_point)
