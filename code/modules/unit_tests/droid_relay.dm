/// Losing a body or returning it frees exactly one deployment slot without needing linked peripherals.
/datum/unit_test/droid_relay/Run()
	var/turf/home = run_loc_floor_bottom_left
	var/turf/pad = get_step(home, NORTH)
	var/obj/machinery/overmap_droid_relay/relay = allocate(/obj/machinery/overmap_droid_relay, home)
	TEST_ASSERT_NULL(relay.linked_ship(), "The relay fixture must run outside a ship.")
	TEST_ASSERT(!relay.can_operate(relay.operator), "An operator body without an administrator client must not authorize actions.")
	for(var/index in 1 to 4)
		var/obj/item/relay_chassis/stock = allocate(/obj/item/relay_chassis, relay)
		TEST_ASSERT(relay.launch(stock, pad, null, null), "A standalone relay can launch each of its first four printed chassis.")
		allocated += relay.droids[index]

	var/obj/item/relay_chassis/extra = allocate(/obj/item/relay_chassis, relay)
	TEST_ASSERT(!relay.launch(extra, pad, null, null), "The fifth launch must be rejected.")
	TEST_ASSERT_EQUAL(extra.loc, relay, "A failed launch must leave the stock in the relay.")
	var/mob/living/basic/relay_droid/recovered = relay.droids[1]
	TEST_ASSERT(relay.recover_unit(recovered, null), "A local return must work without a transport.")
	TEST_ASSERT_EQUAL(length(relay.droids), 3, "A successful return must release the slot.")
	TEST_ASSERT(istype(recovered.loc, /obj/item/relay_chassis), "A returned body is retained in a storage chassis.")
	var/obj/item/relay_chassis/returned = recovered.loc
	TEST_ASSERT(relay.launch(returned, pad, null, null), "A returned body can be redeployed.")
	TEST_ASSERT(recovered in relay.droids, "Redeployment must retain the original body.")
	recovered.death()
	TEST_ASSERT_EQUAL(length(relay.droids), 3, "Destruction must release the deployed slot.")
	var/mob/living/basic/relay_droid/stowed = relay.droids[1]
	TEST_ASSERT(stowed.ai_controller.get_expected_ai_status() != AI_STATUS_OFF, "An uninhabited deployed body must process without nearby clients.")
	TEST_ASSERT(relay.recover_unit(stowed, null), "The second body can return to the relay.")
	var/obj/item/relay_chassis/stowed_chassis = stowed.loc
	stowed.death()
	TEST_ASSERT(QDELETED(stowed_chassis), "A dead stored body must not become a fresh chassis.")

/// The admin scenario uses the native loader and links the actual mapped hardware.
/datum/unit_test/droid_relay_shuttle
	var/datum/map_template/stationtrauma_space/ship/droid_relay/template
	var/datum/stationtrauma_overmap_sector/space/sector
	var/list/original_ids

/datum/unit_test/droid_relay_shuttle/Run()
	original_ids = SSshuttle.assoc_mobile.Copy()
	var/exception/failure
	try
		check_shuttle()
	catch(var/exception/error)
		failure = error
	// Discarding the loaded map can yield, so finish it before the test is deleted.
	template?.discard_loaded_ship()
	QDEL_NULL(template)
	QDEL_NULL(sector)
	SSshuttle.assoc_mobile = original_ids
	original_ids = null
	if(failure)
		throw failure

/datum/unit_test/droid_relay_shuttle/proc/check_shuttle()
	template = new
	var/obj/docking_port/mobile/stationtrauma_space/droid_relay/ship = template.load_ship()
	TEST_ASSERT(istype(ship), "The relay shuttle must load through the orbital ship template.")
	ship.register()
	ship.linkup()
	sector = new
	TEST_ASSERT(sector.attach(ship), "The relay shuttle must attach to the sector with a valid hull and deck.")
	var/list/relays = list()
	for(var/area/ship_area as anything in ship.shuttle_areas)
		for(var/obj/machinery/overmap_droid_relay/relay in ship_area)
			if(ship.is_in_shuttle_bounds(relay))
				relays += relay
	TEST_ASSERT_EQUAL(length(relays), 1, "There must be one relay aboard the scenario shuttle.")
	var/obj/machinery/overmap_droid_relay/relay = relays[1]
	relay.connect_peripherals()
	TEST_ASSERT_EQUAL(relay.linked_ship(), ship, "The relay must locate its own hull.")
	TEST_ASSERT_NOTNULL(relay.board_ref?.resolve(), "The onboard computer must connect.")
	TEST_ASSERT_NOTNULL(relay.fabricator_ref?.resolve(), "The fabricator must connect.")
	TEST_ASSERT_EQUAL(length(relay.transport_refs), 2, "Both transports must connect independently.")
	TEST_ASSERT(length(ship.engine_list), "The native engines must register for flight.")
