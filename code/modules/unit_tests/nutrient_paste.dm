/// Checks material accounting and the last-portion race through the player interactions.
/datum/unit_test/nutrient_paste/Run()
	var/concentrate_type = /datum/reagent/toxin/biomass_concentrate
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/nutrient_paste/processor/processor = allocate(/obj/machinery/nutrient_paste/processor)
	var/obj/machinery/nutrient_paste/dispenser/dispenser = allocate(/obj/machinery/nutrient_paste/dispenser)
	processor.set_is_operational(TRUE)
	dispenser.set_is_operational(TRUE)

	var/obj/item/reagent_containers/cup/beaker/large/beaker = allocate(/obj/item/reagent_containers/cup/beaker/large)
	TEST_ASSERT(user.put_in_hands(beaker), "The user must be holding the beaker.")
	processor.item_interaction(user, beaker, list())
	TEST_ASSERT_EQUAL(beaker.reagents.total_volume, 0, "The processor must start empty.")
	dispenser.interact(user)
	TEST_ASSERT_NULL(locate(/obj/item/food/nutrient_paste) in run_loc_floor_bottom_left, "The dispenser must start empty.")
	user.dropItemToGround(beaker)

	var/obj/item/apple = allocate(/obj/item/food/grown/apple)
	var/obj/item/heart = allocate(/obj/item/organ/heart)
	var/obj/item/cotton = allocate(/obj/item/grown/cotton)
	var/obj/item/stack/sheet/mineral/wood/wood = allocate(/obj/item/stack/sheet/mineral/wood, null, 25)
	for(var/obj/item/scrap in list(apple, heart, cotton, wood))
		TEST_ASSERT(user.put_in_hands(scrap), "The user must be holding the input.")
		TEST_ASSERT_EQUAL(processor.item_interaction(user, scrap, list()), ITEM_INTERACT_SUCCESS, "The processor must accept [scrap].")
	processor.interact(user)
	var/deadline = world.time + 15 SECONDS
	UNTIL(QDELETED(cotton) || world.time >= deadline)
	TEST_ASSERT(QDELETED(apple) && QDELETED(heart) && QDELETED(cotton), "The batch must consume edible and inedible harvests as well as the loose heart.")
	TEST_ASSERT_EQUAL(wood.get_amount(), 11, "Only fourteen boards fit in this batch.")

	TEST_ASSERT(user.put_in_hands(beaker), "The user must be holding the beaker to draw the concentrate.")
	processor.item_interaction(user, beaker, list())
	TEST_ASSERT_EQUAL(beaker.reagents.get_reagent_amount(concentrate_type), 80, "The batch must yield concentrate for exactly the material consumed.")
	var/mob/living/carbon/human/poisoned = allocate(/mob/living/carbon/human/consistent)
	beaker.reagents.trans_to(poisoned, 8, methods = INGEST)
	beaker.reagents.remove_reagent(concentrate_type, 64)
	beaker.reagents.add_reagent(/datum/reagent/water, 1)
	dispenser.item_interaction(user, beaker, list())
	TEST_ASSERT_EQUAL(beaker.reagents.total_volume, 9, "The dispenser must leave mixed liquid in the beaker.")
	beaker.reagents.remove_reagent(/datum/reagent/water, 1)
	dispenser.item_interaction(user, beaker, list())
	TEST_ASSERT_EQUAL(beaker.reagents.total_volume, 0, "The dispenser must accept pure concentrate.")

	dispenser.interact(user)
	dispenser.set_is_operational(FALSE)
	dispenser.set_is_operational(TRUE)
	deadline = world.time + 3 SECONDS
	UNTIL(world.time >= deadline)
	TEST_ASSERT_NULL(locate(/obj/item/food/nutrient_paste) in run_loc_floor_bottom_left, "A power interruption must cancel the pending serving.")
	dispenser.item_interaction_secondary(user, beaker, list())
	TEST_ASSERT_EQUAL(beaker.reagents.get_reagent_amount(concentrate_type), 8, "The interrupted serving must leave all concentrate available at the manual drain.")
	dispenser.item_interaction(user, beaker, list())

	dispenser.interact(user)
	dispenser.interact(user)
	deadline = world.time + 4 SECONDS
	UNTIL(world.time >= deadline)
	var/list/portions = list()
	for(var/obj/item/food/nutrient_paste/food in run_loc_floor_bottom_left)
		portions += food
	TEST_ASSERT_EQUAL(length(portions), 1, "Two requests with one serving left must yield exactly one portion.")
	var/obj/item/food/paste = portions[1]
	allocated += paste
	TEST_ASSERT_EQUAL(paste.reagents.total_volume, 7, "The portion must contain edible nourishment.")
	TEST_ASSERT_EQUAL(paste.reagents.get_reagent_amount(concentrate_type), 0, "Raw concentrate must never reach the portion.")

	deadline = world.time + 10 SECONDS
	UNTIL(poisoned.get_tox_loss() > 0 || world.time >= deadline)
	TEST_ASSERT(poisoned.get_tox_loss() > 0, "Drinking the untreated concentrate must cause toxin damage.")

	var/datum/component/edible/edible = paste.GetComponent(/datum/component/edible)
	edible.TakeBite(user, user)
	var/datum/mood_event/aftertaste = user.mob_mood.mood_events["nutrient_paste_aftertaste"]
	TEST_ASSERT_NOTNULL(aftertaste, "The first bite must apply the aftertaste effect.")
	TEST_ASSERT_EQUAL(aftertaste.mood_change, -2, "The aftertaste must have a mild mood penalty.")
