/// Cargo must pay for each fiber, consume sold batches and keep the contract price between shipments.
/datum/unit_test/phoenix_fiber_export
	/// Preserve unrelated market bonuses even if an assertion returns early.
	var/list/original_boosted_exports

/datum/unit_test/phoenix_fiber_export/Destroy()
	if(original_boosted_exports)
		SSeconomy.boosted_exports = original_boosted_exports
	return ..()

/datum/unit_test/phoenix_fiber_export/Run()
	original_boosted_exports = SSeconomy.boosted_exports
	SSeconomy.boosted_exports = list()
	var/obj/item/stack/phoenix_fiber/first = allocate(/obj/item/stack/phoenix_fiber, run_loc_floor_bottom_left, 3, "export-test")
	var/datum/export_report/preview = export_single_item(first, dry_run = TRUE)
	TEST_ASSERT_EQUAL(counterlist_sum(preview.total_value), 450, "The scanner must value all three fibers at the contract price.")
	TEST_ASSERT(!QDELETED(first), "Scanning an export must preserve the actual batch.")
	var/datum/export_report/first_sale = export_single_item(first)
	TEST_ASSERT_EQUAL(counterlist_sum(first_sale.total_value), 450, "Selling must pay for the whole stack.")
	TEST_ASSERT_EQUAL(counterlist_sum(first_sale.total_amount), 3, "The sale must report the number of fibers rather than one stack.")
	TEST_ASSERT(QDELETED(first), "Cargo must consume the sold batch.")
	var/obj/item/stack/phoenix_fiber/second = allocate(/obj/item/stack/phoenix_fiber, run_loc_floor_bottom_left, 4, "export-test")
	var/datum/export_report/second_sale = export_single_item(second)
	TEST_ASSERT_EQUAL(counterlist_sum(second_sale.total_value), 600, "A later shipment must retain the same contract price.")
	TEST_ASSERT(QDELETED(second), "The second shipment must also consume its material.")

/// The public recipe must consume its ingredients once and produce dressings used by the normal wound system.
/datum/unit_test/phoenix_biobandage_crafting/Destroy()
	// Unwind the fixture's attachments before the allocated patient destroys its limbs.
	for(var/obj/item/stack/medical/wrap/gauze/dressing in allocated)
		if(istype(dressing.loc, /obj/item/bodypart))
			dressing.forceMove(run_loc_floor_bottom_left)
	return ..()

/datum/unit_test/phoenix_biobandage_crafting/Run()
	var/datum/crafting_recipe/recipe
	for(var/datum/crafting_recipe/candidate as anything in GLOB.crafting_recipes_default)
		if(candidate.name == "Гемостатические биоповязки")
			recipe = candidate
			break
	TEST_ASSERT_NOTNULL(recipe, "The bio-bandage recipe must be available without learning a research recipe.")
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/datum/component/personal_crafting/crafting = user.GetComponent(/datum/component/personal_crafting)
	crafting.ignored_flags |= CRAFT_IGNORE_DO_AFTER
	var/obj/item/stack/phoenix_fiber/fiber = allocate(/obj/item/stack/phoenix_fiber, run_loc_floor_bottom_left, 3, "crafting-test")
	var/obj/item/reagent_containers/cup/beaker/beaker = allocate(/obj/item/reagent_containers/cup/beaker, run_loc_floor_bottom_left)
	beaker.reagents.add_reagent(/datum/reagent/space_cleaner/sterilizine, 4)
	TEST_ASSERT(istext(crafting.construct_item(user, recipe)), "Insufficient sterilizine must prevent crafting.")
	TEST_ASSERT_EQUAL(fiber.amount, 3, "A failed craft must preserve the fiber.")
	TEST_ASSERT_EQUAL(beaker.reagents.get_reagent_amount(/datum/reagent/space_cleaner/sterilizine), 4, "A failed craft must preserve its sterilizine.")
	beaker.reagents.add_reagent(/datum/reagent/space_cleaner/sterilizine, 2)
	var/result = crafting.construct_item(user, recipe)
	TEST_ASSERT(istype(result, /obj/item/stack/medical/wrap/gauze), "The successful recipe must create a usable medical dressing.")
	var/obj/item/stack/medical/wrap/gauze/biobandages = result
	allocated |= biobandages
	TEST_ASSERT_EQUAL(biobandages.amount, 6, "One preparation must make six dressings.")
	TEST_ASSERT_EQUAL(fiber.amount, 1, "One preparation must consume two units of fiber.")
	TEST_ASSERT_EQUAL(beaker.reagents.get_reagent_amount(/datum/reagent/space_cleaner/sterilizine), 1, "One preparation must consume five units of sterilizine.")
	TEST_ASSERT(istext(crafting.construct_item(user, recipe)), "A repeated craft without another batch of ingredients must fail.")
	TEST_ASSERT_EQUAL(biobandages.amount, 6, "A rejected repeat must not add dressings to the existing stack.")
	var/obj/item/stack/medical/wrap/gauze/ordinary = allocate(/obj/item/stack/medical/wrap/gauze, run_loc_floor_bottom_left, 1, FALSE)
	TEST_ASSERT(!biobandages.can_merge(ordinary), "Ordinary gauze must not merge into premium bio-bandages.")
	var/obj/item/bodypart/bio_arm = user.get_bodypart(BODY_ZONE_R_ARM)
	var/obj/item/bodypart/ordinary_arm = user.get_bodypart(BODY_ZONE_L_ARM)
	var/datum/wound/slash/flesh/moderate/bio_cut = allocate(/datum/wound/slash/flesh/moderate)
	var/datum/wound/slash/flesh/moderate/ordinary_cut = allocate(/datum/wound/slash/flesh/moderate)
	bio_cut.apply_wound(bio_arm)
	ordinary_cut.apply_wound(ordinary_arm)
	var/obj/item/stack/medical/wrap/gauze/applied_bio = biobandages.split_stack(1)
	allocated |= applied_bio
	TEST_ASSERT(bio_arm.apply_item(applied_bio, LIMB_ITEM_GAUZE), "A bio-bandage must attach using the normal limb dressing slot.")
	TEST_ASSERT(ordinary_arm.apply_item(ordinary, LIMB_ITEM_GAUZE), "The control dressing must attach to its wound.")
	bio_cut.handle_process(1)
	ordinary_cut.handle_process(1)
	TEST_ASSERT(bio_cut.blood_flow < ordinary_cut.blood_flow, "The bio-bandage must reduce bleeding faster than ordinary gauze.")
	bio_arm.seep_gauze(6)
	ordinary_arm.seep_gauze(6)
	TEST_ASSERT(applied_bio.absorption_capacity > 0, "A bio-bandage must remain effective after an exposure that exhausts ordinary gauze.")
	TEST_ASSERT(ordinary.absorption_capacity <= 0, "The same exposure must exhaust the control dressing.")

/// Finishing a wash must exchange the entire batch once and leave the result in the drum.
/datum/unit_test/phoenix_fiber_washing/Run()
	var/obj/machinery/washing_machine/washer = allocate(/obj/machinery/washing_machine, run_loc_floor_bottom_left)
	var/initial_contents = length(washer.contents)
	var/obj/item/stack/phoenix_fiber/raw_fiber = allocate(/obj/item/stack/phoenix_fiber, washer, 9, "washing-test")
	washer.wash_cycle(null)
	TEST_ASSERT(QDELETED(raw_fiber), "The completed wash must consume the raw biofiber.")
	var/obj/item/stack/phoenix_refined_fiber/clean_fiber = locate() in washer
	TEST_ASSERT_NOTNULL(clean_fiber, "The cleaned fiber must remain in the drum.")
	allocated |= clean_fiber
	TEST_ASSERT_EQUAL(clean_fiber.amount, 9, "Washing must preserve the entire stack quantity.")
	washer.wash_cycle(null)
	TEST_ASSERT(!QDELETED(clean_fiber) && clean_fiber.loc == washer, "A second wash must preserve the cleaned batch.")
	TEST_ASSERT_EQUAL(length(washer.contents), initial_contents + 1, "A second wash must not duplicate the batch.")
	TEST_ASSERT_EQUAL(clean_fiber.amount, 9, "A second wash must not add more fiber to the stack.")
