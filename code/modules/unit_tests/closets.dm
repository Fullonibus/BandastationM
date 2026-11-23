/// Checks that the length of the initial contents of a closet doesn't exceed its storage capacity.
/// Also checks that nothing inside that isn't immediate is a steal objective.
/datum/unit_test/closet_contents

/datum/unit_test/closet_contents/Run()
	var/list/all_closets = subtypesof(/obj/structure/closet)
	//Supply pods. They are sent, crashed, opened and never closed again. They also cause exceptions in nullspace.
	all_closets -= typesof(/obj/structure/closet/supplypod)
	/// these bitches spawn specially crafted humans with gear and moving organs being shuffled around through the whole process
	all_closets -= typesof(/obj/structure/closet/body_bag/lost_crew/with_body)

	for(var/closet_type in all_closets)
		var/obj/structure/closet/closet = allocate(closet_type)
		if(QDELETED(closet)) // this is here because the emcloset subtype has a chance of returning a qdel hint on initialize
			continue

		// Copy is necessary otherwise closet.contents - immediate_contents returns an empty list
		var/list/immediate_contents = closet.contents.Copy()
		closet.PopulateContents()
		var/contents_len = length(closet.contents)

		if(contents_len > closet.storage_capacity)
			TEST_FAIL("Initial Contents of [closet.type] ([contents_len]) exceed its storage capacity ([closet.storage_capacity]).")

		for (var/obj/item/item in closet.contents - immediate_contents)
			if (item.type in GLOB.steal_item_handler.objectives_by_path)
				TEST_FAIL("[closet_type] contains a steal objective [item.type] in PopulateContents(). Move it to populate_contents_immediate().")

/// Tests whether two closet subtypes(body_bag & crate) successfully perform their functions, and their parent's.
/datum/unit_test/closet_opening

/datum/unit_test/closet_opening/Run()
	var/mob/living/carbon/human/consistent/placer = EASY_ALLOCATE()
	var/obj/structure/closet/crate/secure/locked_crate = allocate(/obj/structure/closet/crate/secure, get_step(run_loc_floor_bottom_left, NORTH))
	var/obj/structure/closet/body_bag/corpse_bag = allocate(/obj/structure/closet/body_bag, get_step(run_loc_floor_bottom_left, EAST))
	var/obj/item/food/cookie/placing_tester = EASY_ALLOCATE()
	var/obj/item/card/id/advanced/gold/captains_spare/cool_card = EASY_ALLOCATE()

	placer.equip_to_slot(cool_card, ITEM_SLOT_ID)
	placer.put_in_active_hand(placing_tester)
	locked_crate.req_access = list(ACCESS_CAPTAIN)

	click_wrapper(placer, locked_crate)
	TEST_ASSERT_NOTNULL(placer.get_active_held_item(), "Successfully placed item in closed, locked crate")

	placer.cycle_hand()
	click_wrapper(placer, locked_crate)
	TEST_ASSERT(!locked_crate.locked, "Was unable to unlock locked crate despite adequate access")

	click_wrapper(placer, locked_crate)
	TEST_ASSERT(locked_crate.opened, "Was unable to open unlocked crate")

	placer.cycle_hand()
	click_wrapper(placer, locked_crate)
	TEST_ASSERT(placing_tester in locked_crate.loc, "Was unable to place item in open crate")

	click_wrapper(placer, locked_crate)
	TEST_ASSERT(placing_tester in locked_crate, "Closing a crate with an item on it did not move it within the crate")

	click_wrapper(placer, locked_crate, list(RIGHT_CLICK = TRUE, BUTTON = RIGHT_CLICK))
	TEST_ASSERT(locked_crate.locked, "Right-clicking a crate with adequate access did not lock it")

	// Begin bodybag

	click_wrapper(placer, corpse_bag)
	TEST_ASSERT(corpse_bag.opened, "Could not open a placed bodybag")

	placer.put_in_active_hand(placing_tester, TRUE)
	click_wrapper(placer, corpse_bag)
	TEST_ASSERT(placing_tester in corpse_bag.loc, "Could not place item on opened bodybag")

	click_wrapper(placer, corpse_bag)
	TEST_ASSERT(placing_tester in corpse_bag, "Closing a bodybag on an item did not move it within the bodybag")

// BANDASTATION ADDITION START - Multi-tile objects must not fit inside ordinary crates.
/// Closing a crate collects single-tile cargo without swallowing larger objects; special delivery stays unrestricted.
/datum/unit_test/closet_multitile_contents/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z)
	var/obj/structure/closet/crate/crate = allocate(__IMPLIED_TYPE__, origin)
	TEST_ASSERT(crate.open(), "The test crate could not be opened before loading.")
	var/list/single_tile_objects = list()
	for(var/dense in list(FALSE, TRUE))
		var/obj/ordinary = allocate(/obj, origin)
		ordinary.density = dense
		ordinary.anchored = FALSE
		single_tile_objects += ordinary
	var/obj/item/flashlight/item = allocate(__IMPLIED_TYPE__, origin)
	var/list/oversized_objects = list()
	for(var/list/bounds as anything in list(list(64, 64), list(96, 32), list(32, 96)))
		for(var/dense in list(FALSE, TRUE))
			var/obj/oversized = allocate(/obj, origin)
			oversized.name = "[bounds[1]]x[bounds[2]] object with density [dense]"
			oversized.bound_width = bounds[1]
			oversized.bound_height = bounds[2]
			oversized.density = dense
			oversized.anchored = FALSE
			oversized_objects += oversized
	TEST_ASSERT(crate.close(), "A crate could not close while oversized objects remained outside it.")
	for(var/obj/ordinary as anything in single_tile_objects)
		TEST_ASSERT_EQUAL(ordinary.loc, crate, "Closing a crate failed to collect a single-tile object with density [ordinary.density].")
	TEST_ASSERT_EQUAL(item.loc, crate, "Closing a crate failed to collect an ordinary item.")
	for(var/obj/oversized as anything in oversized_objects)
		TEST_ASSERT_EQUAL(oversized.loc, origin, "Closing an ordinary crate swallowed [oversized.name].")
		TEST_ASSERT(!crate.insert(oversized), "Explicit crate insertion accepted [oversized.name].")
		TEST_ASSERT_EQUAL(oversized.loc, origin, "Rejected insertion moved [oversized.name] away from its original turf.")
	TEST_ASSERT(crate.open(), "The crate could not reopen after rejecting oversized cargo.")
	for(var/obj/ordinary as anything in single_tile_objects)
		TEST_ASSERT_EQUAL(ordinary.loc, origin, "Reopening the crate failed to release an ordinary object.")
	TEST_ASSERT_EQUAL(item.loc, origin, "Reopening the crate failed to release the original item.")

	var/obj/structure/closet/supplypod/supply = allocate(__IMPLIED_TYPE__, get_step(origin, WEST))
	supply.reverse_option_list = supply.reverse_option_list.Copy()
	supply.reverse_option_list["Unanchored"] = TRUE
	var/obj/special_cargo = oversized_objects[1]
	TEST_ASSERT(supply.insertion_allowed(special_cargo), "Special supplypod extraction rejected permitted multi-tile cargo.")
	supply.insert(special_cargo, supply)
	TEST_ASSERT_EQUAL(special_cargo.loc, supply, "The native supplypod insertion path did not move the permitted cargo into its holder.")
// BANDASTATION ADDITION END

/// Wall storage must remain passable after closing and respect its smaller capacity.
/datum/unit_test/wall_locker
	/// Adjacent tile temporarily replaced with a supporting wall.
	var/turf/support
	/// Original floor type.
	var/original_support_type
	/// Original floor's baseturf stack.
	var/original_support_baseturfs

/datum/unit_test/wall_locker/Destroy()
	if(support && support.type != original_support_type)
		support.ChangeTurf(original_support_type, original_support_baseturfs)
	support = null
	original_support_baseturfs = null
	return ..()

/datum/unit_test/wall_locker/Run()
	var/turf/position = locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z)
	support = get_step(position, NORTH)
	original_support_type = support.type
	original_support_baseturfs = support.baseturfs
	support = support.ChangeTurf(/turf/closed/wall)
	var/obj/structure/closet/wall/locker = allocate(/obj/structure/closet/wall/botany/directional/north, position)
	TEST_ASSERT(locker.find_and_mount_on_atom(), "The directional locker must attach to its wall")
	TEST_ASSERT(!locker.density, "The closed wall locker must leave the tile passable")
	TEST_ASSERT(locker.open(), "The wall locker must open")
	TEST_ASSERT_EQUAL(locker.door_obj.dir, NORTH, "The animated door must follow the wall locker's direction")

	var/mob/living/carbon/human/consistent/person = allocate(/mob/living/carbon/human/consistent, position)
	var/mob/living/basic/mouse/mouse = allocate(/mob/living/basic/mouse, position)
	TEST_ASSERT(locker.close(), "The wall locker must close while a person stands in front of it")
	TEST_ASSERT_EQUAL(person.loc, position, "A human must stay outside the wall locker")
	TEST_ASSERT_EQUAL(mouse.loc, locker, "A tiny creature must fit inside the wall locker")
	TEST_ASSERT(!locker.density, "Closing the wall locker must leave the tile passable")
	TEST_ASSERT(locker.open(), "Reopening the wall locker must release its contents")
	mouse.forceMove(get_step(position, EAST))

	for(var/index in 1 to locker.storage_capacity)
		allocate(/obj/item/pen, position)
	var/obj/item/pen/overflow = allocate(/obj/item/pen, get_step(position, EAST))
	TEST_ASSERT(locker.close(), "The wall locker must accept an ordinary load")
	TEST_ASSERT_EQUAL(length(locker.contents), 15, "The wall locker must hold fifteen items")
	locker.insert(overflow)
	TEST_ASSERT_EQUAL(overflow.loc, get_step(position, EAST), "The sixteenth item must remain outside")

	support = support.ChangeTurf(original_support_type, original_support_baseturfs)
	TEST_ASSERT(QDELETED(locker), "Removing the supporting wall must dislodge the locker")
