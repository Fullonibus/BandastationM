/// Preservation and death must freeze the actual Life-driven biology.
/datum/unit_test/phoenix_weaver_stasis/Run()
	var/mob/living/basic/phoenix_weaver/weaver = allocate(/mob/living/basic/phoenix_weaver)
	var/initial_nutrition = weaver.nutrition
	ADD_TRAIT(weaver, TRAIT_STASIS, PHOENIX_STASIS_SOURCE)
	weaver.Life(30)
	TEST_ASSERT_EQUAL(weaver.nutrition, initial_nutrition, "Stasis consumed food through Life.")
	TEST_ASSERT_EQUAL(weaver.breeding_seconds, 0, "Stasis advanced reproduction.")
	TEST_ASSERT_EQUAL(weaver.fiber_seconds, 0, "Stasis advanced fiber production.")
	REMOVE_TRAIT(weaver, TRAIT_STASIS, PHOENIX_STASIS_SOURCE)
	weaver.Life(1)
	TEST_ASSERT(weaver.nutrition < initial_nutrition, "Released weaver did not resume metabolism through Life.")
	weaver.death()
	TEST_ASSERT_EQUAL(weaver.icon_state, "weaver_dead", "A dead adult must use the weaver's native death sprite.")
	var/dead_nutrition = weaver.nutrition
	weaver.Life(30)
	TEST_ASSERT_EQUAL(weaver.nutrition, dead_nutrition, "Dead weaver consumed food.")

/// Ordinary medical stacks must not replace the project's treatment capsule on either click action.
/datum/unit_test/phoenix_weaver_capsule_only_treatment/Run()
	var/mob/living/basic/phoenix_weaver/weaver = allocate(/mob/living/basic/phoenix_weaver)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	weaver.apply_damage(20, BRUTE)
	var/health_before_treatment = weaver.health
	var/obj/item/stack/medical/bruise_pack/pack = allocate(/obj/item/stack/medical/bruise_pack)
	// Keep the real item and healing path while excluding an unrelated treatment delay.
	pack.other_delay = 0
	user.put_in_hands(pack)
	var/amount_before_treatment = pack.amount
	pack.melee_attack_chain(user, weaver)
	TEST_ASSERT_EQUAL(weaver.health, health_before_treatment, "A medical stack healed the weaver outside a treatment capsule.")
	TEST_ASSERT_EQUAL(pack.amount, amount_before_treatment, "Refused external treatment consumed medical material.")
	pack.melee_attack_chain(user, weaver, list(RIGHT_CLICK = "1"))
	TEST_ASSERT_EQUAL(weaver.health, health_before_treatment, "Secondary medical treatment bypassed the capsule requirement.")
	TEST_ASSERT_EQUAL(pack.amount, amount_before_treatment, "Refused secondary treatment consumed medical material.")

/// Feeding uses edible foodtypes, consumes the real item, and reports an allergenic meal.
/datum/unit_test/phoenix_weaver_feeding/Run()
	var/datum/phoenix_strain/profile = allocate(/datum/phoenix_strain, "dim", FALSE)
	profile.allergen = FRUIT
	var/mob/living/basic/phoenix_weaver/weaver = allocate(/mob/living/basic/phoenix_weaver, run_loc_floor_bottom_left, profile)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	weaver.process_biology(10)
	var/before_feeding = weaver.nutrition
	var/obj/item/food/breadslice/plain/bread = allocate(/obj/item/food/breadslice/plain)
	user.put_in_hands(bread)
	bread.melee_attack_chain(user, weaver)
	TEST_ASSERT(QDELETED(bread), "Accepted food was not consumed.")
	TEST_ASSERT(weaver.nutrition > before_feeding, "Food did not replenish the weaver.")
	weaver.process_biology(1)
	var/obj/item/food/grown/apple/apple = allocate(/obj/item/food/grown/apple)
	user.put_in_hands(apple)
	var/before_allergy = weaver.health
	apple.melee_attack_chain(user, weaver)
	TEST_ASSERT(QDELETED(apple), "The allergenic meal was not consumed through the real item click.")
	TEST_ASSERT(weaver.health < before_allergy, "Allergenic food did not harm the weaver.")
	var/list/render_list = list()
	SEND_SIGNAL(weaver, COMSIG_LIVING_HEALTHSCAN, render_list, FALSE, user, SCANNER_VERBOSE, FALSE)
	TEST_ASSERT(findtext(jointext(render_list, " "), "аллерг"), "Health scanner did not expose the observed allergic reaction.")
	weaver.set_nutrition(99)
	var/obj/item/food/breadslice/plain/filling_meal = allocate(/obj/item/food/breadslice/plain)
	user.put_in_hands(filling_meal)
	filling_meal.melee_attack_chain(user, weaver)
	TEST_ASSERT(QDELETED(filling_meal), "A nearly full weaver refused the real filling meal.")
	TEST_ASSERT_EQUAL(weaver.nutrition, PHOENIX_NUTRITION_MAX, "A real meal overshot the nutrition capacity.")
	var/obj/item/food/breadslice/plain/extra_meal = allocate(/obj/item/food/breadslice/plain)
	user.put_in_hands(extra_meal)
	extra_meal.melee_attack_chain(user, weaver)
	TEST_ASSERT(!QDELETED(extra_meal), "A full weaver consumed a second real meal.")
	weaver.Life(1)
	var/before_stasis_feeding = weaver.nutrition
	ADD_TRAIT(weaver, TRAIT_STASIS, PHOENIX_STASIS_SOURCE)
	extra_meal.melee_attack_chain(user, weaver)
	REMOVE_TRAIT(weaver, TRAIT_STASIS, PHOENIX_STASIS_SOURCE)
	TEST_ASSERT(!QDELETED(extra_meal), "A weaver below capacity consumed food while in stasis.")
	TEST_ASSERT_EQUAL(weaver.nutrition, before_stasis_feeding, "Feeding increased a stasis weaver's reserve.")

/// Build a real airtight enclosure shared by the nutrition and natural lineage scenarios.
/datum/unit_test/proc/phoenix_weaver_habitat_fixture()
	var/turf/open/origin = get_step(run_loc_floor_bottom_left, NORTHEAST)
	var/list/room = block(origin, locate(origin.x + 2, origin.y + 2, origin.z))
	var/list/border = block(locate(origin.x - 1, origin.y - 1, origin.z), locate(origin.x + 3, origin.y + 3, origin.z)) - room
	for(var/turf/border_turf as anything in border)
		allocate(/obj/structure/window/reinforced/fulltile, border_turf)
	var/datum/gas_mixture/native_air = SSair.parse_gas_string("o2=20;n2=80;TEMP=295", /datum/gas_mixture/turf)
	allocated += native_air
	for(var/turf/open/room_turf as anything in room)
		room_turf.immediate_calculate_adjacent_turfs()
		room_turf.copy_air(native_air)
		allocate(/obj/structure/phoenix_substrate/grass, room_turf)
	return origin

/// All public reserve mutations, including the inherited full-heal path, use the weaver's percentage scale.
/datum/unit_test/phoenix_weaver_nutrition_limits/Run()
	var/mob/living/basic/phoenix_weaver/weaver = allocate(/mob/living/basic/phoenix_weaver)
	weaver.fully_heal(HEAL_ALL|HEAL_ADMIN)
	TEST_ASSERT_EQUAL(weaver.nutrition, PHOENIX_NUTRITION_MAX, "Full healing applied the generic mob nutrition scale to a weaver.")
	weaver.adjust_nutrition(-200)
	TEST_ASSERT_EQUAL(weaver.nutrition, 0, "Nutrition loss crossed the zero reserve boundary.")
	weaver.adjust_nutrition(200)
	TEST_ASSERT_EQUAL(weaver.nutrition, PHOENIX_NUTRITION_MAX, "External nutrition gain exceeded the reserve capacity.")
	weaver.set_nutrition(-200)
	TEST_ASSERT_EQUAL(weaver.nutrition, 0, "The public reserve setter allowed negative nutrition.")
	weaver.set_nutrition(200)
	TEST_ASSERT_EQUAL(weaver.nutrition, PHOENIX_NUTRITION_MAX, "The public reserve setter exceeded the reserve capacity.")

/// Growing and producing offspring must need real feeding before industrial-scale output.
/datum/unit_test/phoenix_weaver_nutrition/Run()
	var/turf/open/origin = phoenix_weaver_habitat_fixture()
	var/datum/phoenix_strain/profile = allocate(/datum/phoenix_strain, "dim", FALSE)
	// Isolate nutrition from lighting updates; the actual air, bedding and enclosure remain in use.
	profile.light = list(0, 1)
	var/mob/living/basic/phoenix_weaver/child = allocate(/mob/living/basic/phoenix_weaver, origin, profile, "nutrition-test", 1)
	child.Life(750)
	TEST_ASSERT_EQUAL(child.life_stage, PHOENIX_ADULT, "The supported offspring did not grow before its food reserve ran out.")
	var/obj/item/stack/phoenix_fiber/fiber = locate() in origin
	TEST_ASSERT_NOTNULL(fiber, "The nutrition scenario never reached actual adult production.")
	TEST_ASSERT_EQUAL(child.nutrition, 0, "Offspring can skip feeding until industrial-scale production; its starting reserve should already be exhausted.")
	var/production_before_starvation = child.fiber_seconds
	child.Life(10)
	TEST_ASSERT_EQUAL(child.fiber_seconds, production_before_starvation, "Starving offspring continued producing fiber.")
	TEST_ASSERT(child.stat != DEAD, "The short starvation check killed the feeding subject.")
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, origin)
	var/obj/item/food/breadslice/plain/bread = allocate(/obj/item/food/breadslice/plain, origin)
	user.put_in_hands(bread)
	bread.melee_attack_chain(user, child)
	TEST_ASSERT(QDELETED(bread), "The starving offspring did not consume a real held meal.")
	TEST_ASSERT(child.nutrition > 0, "The accepted meal did not restore a food reserve.")
	var/health_before_supported_life = child.health
	child.Life(1)
	TEST_ASSERT(child.fiber_seconds > production_before_starvation, "Feeding did not resume supported production through Life.")
	TEST_ASSERT_EQUAL(child.health, health_before_supported_life, "Supported feeding regenerated health outside a treatment capsule.")

/// Natural eggs and both immature stages retain project provenance and an independently adapted profile.
/datum/unit_test/phoenix_weaver_lineage/Run()
	var/turf/open/origin = phoenix_weaver_habitat_fixture()
	var/datum/phoenix_strain/profile = allocate(/datum/phoenix_strain, "dim", FALSE)
	// Isolate lifecycle from lighting updates; light classification has its own focused test.
	profile.light = list(0, 1)
	var/mob/living/basic/phoenix_weaver/founder = allocate(/mob/living/basic/phoenix_weaver, origin, profile, "lineage-test")
	founder.Life(PHOENIX_BREED_SECONDS)
	var/obj/item/phoenix_egg/egg = locate() in origin
	TEST_ASSERT_NOTNULL(egg, "A fed founder in a real supported habitat did not lay an egg through Life.")
	allocated += egg
	TEST_ASSERT_NOTEQUAL(egg.strain, founder.strain, "The natural egg shares its parent's mutable strain.")
	TEST_ASSERT(egg.strain.adapt("yield"), "An egg could not use its inherited adaptation allowance.")
	TEST_ASSERT_EQUAL(founder.strain.adaptations, 0, "Adapting a natural egg altered the adult parent.")
	egg.process(PHOENIX_EGG_SECONDS)
	TEST_ASSERT(QDELETED(egg), "A supported egg did not hatch through its processing entry point.")
	var/mob/living/basic/phoenix_weaver/child
	for(var/mob/living/basic/phoenix_weaver/candidate in origin)
		if(candidate != founder)
			child = candidate
			break
	TEST_ASSERT_NOTNULL(child, "Hatching did not produce a real weaver.")
	allocated += child
	TEST_ASSERT_EQUAL(child.project_id, "lineage-test", "Hatching lost project provenance.")
	TEST_ASSERT_EQUAL(child.generation, 1, "Natural offspring did not increment generation.")
	TEST_ASSERT_EQUAL(child.strain.adaptations, 1, "Hatching lost the egg's adaptation.")
	TEST_ASSERT_EQUAL(child.life_stage, PHOENIX_LARVA, "A natural egg skipped larval development.")
	TEST_ASSERT_EQUAL(child.icon_state, "weaver_larva", "Hatching must show the distinct larval sprite.")
	var/datum/phoenix_strain/inherited_profile = child.strain
	child.Life(PHOENIX_LARVA_SECONDS)
	TEST_ASSERT_EQUAL(child.life_stage, PHOENIX_COCOON, "Supported larva did not become a cocoon through Life.")
	TEST_ASSERT_EQUAL(child.icon_state, "weaver_cocoon", "Pupation must replace the moving larva with a silk cocoon.")
	TEST_ASSERT(HAS_TRAIT(child, TRAIT_IMMOBILIZED), "Cocoon did not immobilize the existing mob.")
	child.death()
	TEST_ASSERT_EQUAL(child.icon_state, "weaver_cocoon_dead", "A dead cocoon must retain its stage instead of reverting to the adult sprite.")
	child.revive(HEAL_ALL|HEAL_ADMIN)
	TEST_ASSERT_EQUAL(child.icon_state, "weaver_cocoon", "Revival must restore the living cocoon sprite.")
	child.Life(PHOENIX_COCOON_SECONDS)
	TEST_ASSERT_EQUAL(child.life_stage, PHOENIX_ADULT, "Supported cocoon did not emerge as an adult.")
	TEST_ASSERT_EQUAL(child.icon_state, "weaver", "Emergence must restore the adult weaver sprite.")
	TEST_ASSERT_EQUAL(child.strain, inherited_profile, "Stage progression replaced the inherited profile.")
	TEST_ASSERT(!HAS_TRAIT(child, TRAIT_IMMOBILIZED), "Emerged adult retained cocoon immobility.")
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, origin)
	for(var/cycle in 1 to PHOENIX_MAX_POPULATION)
		if(founder.nutrition < 25)
			var/obj/item/food/breadslice/plain/bread = allocate(/obj/item/food/breadslice/plain, origin)
			user.put_in_hands(bread)
			bread.melee_attack_chain(user, founder)
			TEST_ASSERT(QDELETED(bread), "The cap fixture failed to provide real food to the breeding founder.")
		founder.Life(PHOENIX_BREED_SECONDS)
	TEST_ASSERT_EQUAL(phoenix_population_count("lineage-test"), PHOENIX_MAX_POPULATION, "Natural breeding did not stop at the finite project population, including eggs.")
