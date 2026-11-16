/// The gorilla's ID slot must equip real cards and release their access when emptied.
/datum/unit_test/cargorilla_id_slot/Run()
	var/mob/living/basic/gorilla/cargorilla/gorilla = allocate(/mob/living/basic/gorilla/cargorilla)
	gorilla.mock_client = allocate(/datum/client_interface)
	gorilla.set_hud_used(new gorilla.hud_type(gorilla))
	var/obj/item/card/id/advanced/card = allocate(/obj/item/card/id/advanced)
	card.set_access(list(ACCESS_HYDROPONICS), FORCE_ADD_ALL)
	TEST_ASSERT(gorilla.put_in_hands(card), "The gorilla could not pick up its ID.")
	gorilla.attack_ui(ITEM_SLOT_ID)
	TEST_ASSERT_EQUAL(gorilla.get_item_by_slot(ITEM_SLOT_ID), card, "Clicking the ID slot did not equip the card.")
	TEST_ASSERT(!gorilla.is_holding(card), "Equipping the ID did not free the gorilla's hand.")
	TEST_ASSERT_EQUAL(gorilla.get_idcard(), card, "The equipped ID was not recognized.")
	TEST_ASSERT(ACCESS_HYDROPONICS in gorilla.get_access(), "The equipped ID did not grant its access.")

	var/obj/item/card/id/advanced/other_card = allocate(/obj/item/card/id/advanced)
	TEST_ASSERT(gorilla.put_in_hands(other_card), "The gorilla could not pick up the second ID.")
	TEST_ASSERT(!gorilla.equip_to_slot_if_possible(other_card, ITEM_SLOT_ID, disable_warning = TRUE), "A second ID replaced the equipped card.")
	TEST_ASSERT_EQUAL(gorilla.get_item_by_slot(ITEM_SLOT_ID), card, "The original ID was lost on a rejected equip.")
	TEST_ASSERT(gorilla.is_holding(other_card), "The rejected second ID left the gorilla's hand.")
	TEST_ASSERT_EQUAL(gorilla.get_idcard(hand_first = TRUE), other_card, "Hand-first ID lookup ignored the held card.")
	TEST_ASSERT_EQUAL(gorilla.get_idcard(hand_first = FALSE), card, "Slot-first ID lookup ignored the equipped card.")
	gorilla.dropItemToGround(other_card)

	gorilla.attack_ui(ITEM_SLOT_ID)
	TEST_ASSERT_NULL(gorilla.get_item_by_slot(ITEM_SLOT_ID), "Clicking the occupied ID slot did not empty it.")
	TEST_ASSERT(gorilla.is_holding(card), "Removing the ID did not put it in the gorilla's hand.")
	gorilla.dropItemToGround(card)
	TEST_ASSERT(!(ACCESS_HYDROPONICS in gorilla.get_access()), "The gorilla retained access after dropping its ID.")

	var/obj/item/pen/pen = allocate(/obj/item/pen)
	TEST_ASSERT(gorilla.put_in_hands(pen), "The gorilla could not pick up the test item.")
	TEST_ASSERT(!gorilla.equip_to_slot_if_possible(pen, ITEM_SLOT_ID, disable_warning = TRUE), "The ID slot accepted an arbitrary item.")
	TEST_ASSERT(gorilla.is_holding(pen), "Rejecting a non-ID item removed it from the gorilla's hand.")
	gorilla.dropItemToGround(pen)

	TEST_ASSERT(gorilla.equip_to_slot_if_possible(card, ITEM_SLOT_ID), "The gorilla could not equip its ID again.")
	card.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_NULL(gorilla.get_item_by_slot(ITEM_SLOT_ID), "Moving the ID out of the gorilla left the slot occupied.")
	TEST_ASSERT_NULL(gorilla.get_idcard(), "Moving the ID out left a stale ID reference.")
	TEST_ASSERT(!(ACCESS_HYDROPONICS in gorilla.get_access()), "Moving the ID out did not revoke its access.")

	TEST_ASSERT(gorilla.equip_to_slot_if_possible(card, ITEM_SLOT_ID), "The emptied ID slot could not be reused.")
	qdel(card)
	TEST_ASSERT_NULL(gorilla.get_item_by_slot(ITEM_SLOT_ID), "Deleting the ID left the slot occupied.")
	TEST_ASSERT_NULL(gorilla.get_idcard(), "Deleting the ID left a stale ID reference.")
	TEST_ASSERT(!(ACCESS_HYDROPONICS in gorilla.get_access()), "Deleting the ID did not revoke its access.")

/// Both humans and cargorillas use the same passenger-initiated piggyback interaction.
/datum/unit_test/piggyback_shared/Run()
	for(var/carrier_type in list(/mob/living/carbon/human/consistent, /mob/living/basic/gorilla/cargorilla))
		var/mob/living/carrier = allocate(carrier_type)
		var/mob/living/carbon/human/consistent/rider = allocate(/mob/living/carbon/human/consistent)
		rider.mock_client = allocate(/datum/client_interface)
		TEST_ASSERT(carrier.start_pulling(rider), "[carrier_type] could not grab its passenger.")
		carrier.setGrabState(GRAB_AGGRESSIVE)

		var/mob/previous_usr = usr
		usr = rider // MouseDrop uses usr to identify the player dragging themselves.
		rider.MouseDrop(carrier)
		usr = previous_usr
		TEST_ASSERT_EQUAL(rider.buckled, carrier, "The passenger could not climb onto [carrier_type].")
		TEST_ASSERT_EQUAL(length(rider.get_empty_held_indexes()), 0, "The passenger's hands were not reserved while riding [carrier_type].")

		var/turf/destination = get_step(run_loc_floor_bottom_left, EAST)
		TEST_ASSERT(carrier.Move(destination), "[carrier_type] could not move while carrying its passenger.")
		TEST_ASSERT_EQUAL(get_turf(rider), destination, "Moving [carrier_type] left its passenger behind.")
		carrier.unbuckle_mob(rider)
		TEST_ASSERT_NULL(rider.buckled, "The passenger remained buckled after dismounting [carrier_type].")
		TEST_ASSERT_EQUAL(length(rider.get_empty_held_indexes()), 2, "Dismounting [carrier_type] did not free both passenger hands.")
		if(istype(carrier, /mob/living/basic/gorilla/cargorilla))
			TEST_ASSERT(carrier.start_pulling(rider), "The gorilla could not grab its passenger again.")
			carrier.setGrabState(GRAB_AGGRESSIVE)
			usr = rider
			rider.MouseDrop(carrier)
			usr = previous_usr
			TEST_ASSERT_EQUAL(rider.buckled, carrier, "The passenger could not remount the gorilla.")
			carrier.death()
			TEST_ASSERT_NULL(rider.buckled, "The passenger remained mounted on a dead gorilla.")
			TEST_ASSERT_EQUAL(length(rider.get_empty_held_indexes()), 2, "The gorilla's death did not free both passenger hands.")
		qdel(carrier)
		qdel(rider)

/// Reject occupied hands and a grab which is released during the actual boarding action.
/datum/unit_test/cargorilla_piggyback_rejected/Run()
	var/mob/living/basic/gorilla/cargorilla/gorilla = allocate(/mob/living/basic/gorilla/cargorilla)
	var/mob/living/carbon/human/consistent/rider = allocate(/mob/living/carbon/human/consistent)
	rider.mock_client = allocate(/datum/client_interface)
	var/mob/previous_usr = usr
	usr = rider
	rider.MouseDrop(gorilla)
	usr = previous_usr
	TEST_ASSERT_NULL(rider.buckled, "A passenger boarded the gorilla without being grabbed.")

	var/obj/item/pen/held_item = allocate(/obj/item/pen)
	// An aggressive grab drops ordinary items; a stuck item keeps one hand occupied.
	ADD_TRAIT(held_item, TRAIT_NODROP, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(rider.put_in_hands(held_item), "Could not occupy one passenger hand.")
	TEST_ASSERT(gorilla.start_pulling(rider), "The gorilla could not grab its passenger.")
	gorilla.setGrabState(GRAB_AGGRESSIVE)
	TEST_ASSERT(rider.is_holding(held_item), "The passenger lost the stuck item before boarding.")
	usr = rider
	rider.MouseDrop(gorilla)
	usr = previous_usr
	TEST_ASSERT_NULL(rider.buckled, "A passenger with one occupied hand boarded the gorilla.")
	TEST_ASSERT(rider.is_holding(held_item), "Failed boarding removed the passenger's item.")
	TEST_ASSERT_EQUAL(length(rider.get_empty_held_indexes()), 1, "Failed boarding left a riding item in the passenger's free hand.")
	REMOVE_TRAIT(held_item, TRAIT_NODROP, TRAIT_SOURCE_UNIT_TESTS)
	rider.dropItemToGround(held_item)

	RegisterSignal(rider, COMSIG_DO_AFTER_BEGAN, PROC_REF(release_grab))
	usr = rider
	rider.MouseDrop(gorilla)
	usr = previous_usr
	UnregisterSignal(rider, COMSIG_DO_AFTER_BEGAN)
	TEST_ASSERT_NULL(gorilla.pulling, "Boarding did not reach the timed action which releases the grab.")
	TEST_ASSERT_NULL(rider.buckled, "The passenger boarded after the gorilla released its grab.")
	TEST_ASSERT_EQUAL(length(rider.get_empty_held_indexes()), 2, "Cancelled boarding left a riding item in the passenger's hands.")

/// Invalidate the grab after boarding has entered do_after, without replacing the timed action.
/datum/unit_test/cargorilla_piggyback_rejected/proc/release_grab(mob/living/source)
	SIGNAL_HANDLER
	source.pulledby?.stop_pulling()

/// Crate interactions must keep the gorilla's pose, carried contents and passenger in sync.
/datum/unit_test/cargorilla_crate_carry/Run()
	var/mob/living/basic/gorilla/cargorilla/gorilla = allocate(/mob/living/basic/gorilla/cargorilla)
	var/datum/component/crate_carrier/carrier = gorilla.GetComponent(/datum/component/crate_carrier)
	var/obj/structure/closet/crate/first_crate = allocate(/obj/structure/closet/crate)
	var/obj/structure/closet/crate/second_crate = allocate(/obj/structure/closet/crate/wooden)
	TEST_ASSERT_NOTNULL(carrier, "The cargorilla has no crate carrier component.")
	TEST_ASSERT_EQUAL(gorilla.icon_state, "crawling", "An empty-handed gorilla should crawl.")

	gorilla.UnarmedAttack(first_crate, proximity_flag = TRUE)
	TEST_ASSERT_EQUAL(first_crate.loc, gorilla, "Picking up the first crate did not move it inside the gorilla.")
	TEST_ASSERT_EQUAL(gorilla.icon_state, "standing", "Picking up a crate did not make the gorilla stand.")
	gorilla.UnarmedAttack(second_crate, proximity_flag = TRUE)
	TEST_ASSERT_EQUAL(second_crate.loc, gorilla, "The gorilla could not carry a second crate.")
	TEST_ASSERT_EQUAL(length(carrier.crates_in_hand), 2, "Carrying two crates did not track both crates.")
	TEST_ASSERT_EQUAL(carrier.crates_in_hand[1], first_crate, "Picking up another crate replaced the first carried crate.")

	first_crate.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(length(carrier.crates_in_hand), 1, "Moving a carried crate away left it in the carrier list.")
	TEST_ASSERT_EQUAL(carrier.crates_in_hand[1], second_crate, "Removing the first crate did not select the remaining crate.")
	TEST_ASSERT_EQUAL(gorilla.icon_state, "standing", "Removing one of two crates made the gorilla crawl.")
	qdel(second_crate)
	TEST_ASSERT_EQUAL(length(carrier.crates_in_hand), 0, "Deleting the last crate left a stale carrier reference.")
	TEST_ASSERT_EQUAL(gorilla.icon_state, "crawling", "Deleting the last crate did not return the gorilla to crawling.")

	var/obj/structure/closet/crate/replacement_crate = allocate(/obj/structure/closet/crate/wooden)
	gorilla.UnarmedAttack(first_crate, proximity_flag = TRUE)
	gorilla.UnarmedAttack(replacement_crate, proximity_flag = TRUE)
	var/obj/item/pen/held_item = allocate(/obj/item/pen)
	TEST_ASSERT(gorilla.put_in_inactive_hand(held_item), "The gorilla could not hold an item while carrying crates.")
	gorilla.UnarmedAttack(run_loc_floor_bottom_left, proximity_flag = TRUE)
	TEST_ASSERT_EQUAL(first_crate.loc, run_loc_floor_bottom_left, "Clicking the floor did not drop the first crate.")
	TEST_ASSERT_EQUAL(replacement_crate.loc, run_loc_floor_bottom_left, "Dropping multiple crates skipped the second crate.")
	TEST_ASSERT_EQUAL(length(carrier.crates_in_hand), 0, "Dropped crates remained in the carrier list.")
	TEST_ASSERT_EQUAL(gorilla.icon_state, "standing", "Dropping the crates ignored the item still held in a hand.")
	gorilla.dropItemToGround(held_item)
	TEST_ASSERT_EQUAL(gorilla.icon_state, "crawling", "Dropping the last held item did not return the gorilla to crawling.")

	var/mob/living/carbon/human/consistent/rider = allocate(/mob/living/carbon/human/consistent)
	rider.mock_client = allocate(/datum/client_interface)
	TEST_ASSERT(gorilla.start_pulling(rider), "The gorilla could not grab its passenger.")
	gorilla.setGrabState(GRAB_AGGRESSIVE)
	var/mob/previous_usr = usr
	usr = rider
	rider.MouseDrop(gorilla)
	usr = previous_usr
	TEST_ASSERT_EQUAL(rider.buckled, gorilla, "The passenger could not climb onto the gorilla.")
	var/crawling_rider_height = rider.pixel_z

	gorilla.UnarmedAttack(first_crate, proximity_flag = TRUE)
	TEST_ASSERT_EQUAL(first_crate.loc, gorilla, "The gorilla could not pick up a crate with a passenger aboard.")
	TEST_ASSERT_EQUAL(gorilla.icon_state, "standing", "Picking up a crate with a passenger did not change the gorilla's pose.")
	TEST_ASSERT(rider.pixel_z > crawling_rider_height, "Picking up a crate did not lift the passenger with the standing gorilla.")
	gorilla.UnarmedAttack(run_loc_floor_bottom_left, proximity_flag = TRUE)
	TEST_ASSERT_EQUAL(rider.pixel_z, crawling_rider_height, "Dropping the crate did not restore the passenger's crawling height.")
	TEST_ASSERT_EQUAL(rider.buckled, gorilla, "Changing the gorilla's pose unexpectedly dismounted the passenger.")

	gorilla.UnarmedAttack(first_crate, proximity_flag = TRUE)
	gorilla.death()
	TEST_ASSERT_EQUAL(first_crate.loc, run_loc_floor_bottom_left, "The dead gorilla retained its crate.")
	TEST_ASSERT_EQUAL(length(carrier.crates_in_hand), 0, "Death left a crate in the carrier list.")
	TEST_ASSERT_EQUAL(gorilla.icon_state, gorilla.icon_dead, "Dropping crates during death replaced the dead sprite with a living pose.")
	TEST_ASSERT_NULL(rider.buckled, "The passenger remained mounted on the dead gorilla.")
	TEST_ASSERT_EQUAL(length(rider.get_empty_held_indexes()), 2, "The gorilla's death left riding items in the passenger's hands.")
