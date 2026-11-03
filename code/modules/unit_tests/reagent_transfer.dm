/// Tests transferring reagents between two reagents datums.
/datum/unit_test/reagent_transfer

/datum/unit_test/reagent_transfer/Run()
	var/datum/reagents/source_reagents = allocate(/datum/reagents, 100)
	var/datum/reagents/target_reagents = allocate(/datum/reagents, 100)

	// Quick test to make sure reagents add properly.
	source_reagents.add_reagent(/datum/reagent/water, 10)
	TEST_ASSERT_EQUAL(length(source_reagents.reagent_list), 1, "Source reagents has [length(source_reagents.reagent_list)] unique reagents (expected 1).")
	TEST_ASSERT_EQUAL(source_reagents.total_volume, 10, "Source reagents has incorrect total_volume [source_reagents.total_volume] (expected 10).")

	// Test to make sure the water reagent was added correctly.
	var/datum/reagent/water/water_reagent = source_reagents.reagent_list[1]
	TEST_ASSERT(istype(water_reagent), "Incorrect reagent type detected source reagents: [water_reagent.type] (expected /datum/reagent/water).")
	TEST_ASSERT_EQUAL(water_reagent.volume, 10, "Source reagents has [water_reagent.volume] reagent volume (expected 10).")

	// Test to make sure reagents transfer properly.
	source_reagents.trans_to(target_reagents, 10)
	TEST_ASSERT_EQUAL(length(source_reagents.reagent_list), 0, "Source reagents has [length(source_reagents.reagent_list)] unique reagents after transfer (expected 0, possible duplication?)")
	TEST_ASSERT_EQUAL(length(target_reagents.reagent_list), 1, "Target reagents has [length(target_reagents.reagent_list)] unique reagents after transfer (expected 1).")
	TEST_ASSERT_EQUAL(target_reagents.total_volume, 10, "Target reagents has incorrect total_volume [source_reagents.total_volume] (expected 10).")

	water_reagent = target_reagents.reagent_list[1]
	TEST_ASSERT(istype(water_reagent), "Incorrect reagent type detected in target reagents after transfer: [water_reagent.type] (should be /datum/reagent/water).")
	TEST_ASSERT_EQUAL(water_reagent.volume, 10, "Target reagents has [water_reagent.volume] reagent volume (expected 10)")

/// Blood packs pour into open containers without losing blood data or breaking IV attachment.
/datum/unit_test/blood_pack_pouring

/datum/unit_test/blood_pack_pouring/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/reagent_containers/blood/o_minus/blood_pack = allocate(/obj/item/reagent_containers/blood/o_minus)
	var/obj/item/reagent_containers/cup/glass/drinkingglass/glass = allocate(/obj/item/reagent_containers/cup/glass/drinkingglass)
	user.put_in_active_hand(blood_pack)

	click_wrapper(user, glass)
	TEST_ASSERT_EQUAL(glass.reagents.total_volume, 5, "Clicking a glass with a blood pack should pour 5 units.")
	TEST_ASSERT_EQUAL(blood_pack.reagents.total_volume, 195, "Pouring should remove the transferred blood from the pack.")
	var/datum/reagent/blood/transferred_blood = glass.reagents.has_reagent(/datum/reagent/blood)
	TEST_ASSERT_NOTNULL(transferred_blood, "The glass should contain blood.")
	TEST_ASSERT_EQUAL(transferred_blood.data[BLOOD_DATA_TYPE], get_blood_type(/datum/blood_type/human/o_minus), "Pouring should preserve the blood type.")

	glass.reagents.add_reagent(/datum/reagent/water, 45)
	click_wrapper(user, glass)
	TEST_ASSERT_EQUAL(blood_pack.reagents.total_volume, 195, "Pouring into a full glass should not consume blood.")

	var/obj/item/reagent_containers/cup/beaker/beaker = allocate(/obj/item/reagent_containers/cup/beaker)
	beaker.has_lid = TRUE
	click_wrapper(user, beaker)
	TEST_ASSERT_EQUAL(beaker.reagents.total_volume, 0, "Blood should not pass through a closed lid.")
	TEST_ASSERT_EQUAL(blood_pack.reagents.total_volume, 195, "A closed container should not consume blood.")

	var/obj/machinery/iv_drip/drip = allocate(/obj/machinery/iv_drip)
	click_wrapper(user, drip)
	TEST_ASSERT_EQUAL(drip.reagent_container, blood_pack, "Blood packs should still attach to an IV drip.")
