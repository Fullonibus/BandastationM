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

/// Exercise a catalog with different costs without registering a second production recipe.
/datum/droid_fabrication_design/test_glass
	name = "Glass chassis"
	droid_type = /mob/living/basic/relay_droid
	materials = list(/datum/material/glass = 2 * SHEET_MATERIAL_AMOUNT)
	build_time = 30 SECONDS

/obj/machinery/relay_fabricator/test_catalog
	design_types = list(/datum/droid_fabrication_design/basic, /datum/droid_fabrication_design/test_glass)

/// Simulate an authenticated operator without constructing a BYOND client.
/obj/machinery/overmap_droid_relay/test_operator/can_operate(mob/actor)
	return actor == operator && actor.loc == src

/// Verify selection, interruption, delayed output and recipe-specific payment.
/datum/unit_test/droid_relay_fabrication/Run()
	var/turf/tube_tile = get_step(run_loc_floor_bottom_left, NORTH)
	var/turf/pad = get_step(tube_tile, NORTH)
	var/obj/machinery/relay_resource_storage/storage = allocate(/obj/machinery/relay_resource_storage, run_loc_floor_bottom_left)
	storage.materials.insert_amount_mat(3 * SHEET_MATERIAL_AMOUNT, /datum/material/iron)
	var/obj/structure/relay_material_conduit/section = allocate(/obj/structure/relay_material_conduit, tube_tile)
	var/obj/machinery/relay_fabricator/factory = allocate(/obj/machinery/relay_fabricator/test_catalog, pad)
	var/turf/link_tile = get_step(pad, EAST)
	var/obj/structure/relay_material_conduit/link_section = allocate(/obj/structure/relay_material_conduit, link_tile)
	link_section.setDir(EAST)
	var/obj/machinery/overmap_droid_relay/relay = allocate(/obj/machinery/overmap_droid_relay/test_operator, get_step(link_tile, EAST))
	relay.refresh_device_links()
	TEST_ASSERT_EQUAL(relay.fabricator_ref?.resolve(), factory, "The relay must discover a newly wired fabricator.")
	var/datum/droid_fabrication_design/basic = factory.designs[1]
	var/datum/droid_fabrication_design/glass = factory.designs[2]
	section.setDir(EAST)
	TEST_ASSERT(!factory.print_chassis(basic, relay), "A pipe turned across the route must block production.")
	section.setDir(SOUTH)
	TEST_ASSERT(!factory.print_chassis(glass, relay), "Iron must not satisfy a glass recipe.")
	storage.materials.insert_amount_mat(SHEET_MATERIAL_AMOUNT, /datum/material/gold)
	var/list/catalog_data = factory.ui_data(relay.operator)
	var/list/resources = catalog_data["materials"]
	var/list/iron_resource = resources[REF(SSmaterials.get_material(/datum/material/iron))]
	var/list/glass_resource = resources[REF(SSmaterials.get_material(/datum/material/glass))]
	var/list/gold_resource = resources[REF(SSmaterials.get_material(/datum/material/gold))]
	TEST_ASSERT_EQUAL(iron_resource?["available"], 3, "The catalogue must report the actual number of iron sheets.")
	TEST_ASSERT(iron_resource?["icon"], "The iron stock must use its item sprite.")
	TEST_ASSERT_EQUAL(glass_resource?["available"], 0, "A missing recipe material must still be listed at zero.")
	TEST_ASSERT_EQUAL(gold_resource?["available"], 1, "Stored materials must appear even without a compatible recipe.")
	TEST_ASSERT_EQUAL(factory.print_duration(basic), 45 SECONDS, "The base model must run at nominal speed by default.")
	TEST_ASSERT(factory.print_chassis(basic, relay), "The available iron should start the basic print.")
	TEST_ASSERT_NULL(locate(/obj/item/relay_chassis) in relay, "Starting the job must not create a chassis.")
	TEST_ASSERT(!factory.print_chassis(basic, relay), "A second request cannot start while the printer is busy.")
	factory.set_machine_stat(factory.machine_stat | NOPOWER)
	factory.set_machine_stat(factory.machine_stat & ~NOPOWER)
	TEST_ASSERT_EQUAL(storage.materials.get_material_amount(/datum/material/iron), 3 * SHEET_MATERIAL_AMOUNT, "An interrupted print must leave the stock intact.")

	factory.productivity = 45
	TEST_ASSERT_EQUAL(factory.print_duration(basic), 1 SECONDS, "Increased productivity must shorten the build time.")
	TEST_ASSERT(factory.print_chassis(basic, relay), "The intact pipe must permit a new assembly.")
	section.set_anchored(FALSE)
	var/deadline = world.time + 4 SECONDS
	UNTIL(!factory.printing_design || world.time >= deadline)
	TEST_ASSERT_NULL(locate(/obj/item/relay_chassis) in relay, "Breaking the supply path during assembly must prevent delivery.")
	TEST_ASSERT_EQUAL(storage.materials.get_material_amount(/datum/material/iron), 3 * SHEET_MATERIAL_AMOUNT, "The broken path must prevent payment.")
	section.set_anchored(TRUE)

	TEST_ASSERT(!factory.can_interact(relay.operator), "The operator inside the relay must be outside normal hand interaction.")
	var/datum/tgui/catalog = allocate(/datum/tgui, relay.operator, factory, "DroidFabricator")
	catalog.process_status()
	TEST_ASSERT_EQUAL(catalog.status, UI_INTERACTIVE, "The linked operator's production UI must accept remote commands.")
	catalog.on_act_message("print", list("design" = REF(basic)), catalog.state)
	TEST_ASSERT_EQUAL(factory.printing_design, basic, "The relay operator's print action must start the selected design.")
	deadline = world.time + 4 SECONDS
	UNTIL(!factory.printing_design || world.time >= deadline)
	var/obj/item/relay_chassis/printed = locate(/obj/item/relay_chassis) in relay
	TEST_ASSERT_NOTNULL(printed, "The timer must deliver the completed body to the linked relay.")
	allocated += printed
	TEST_ASSERT_EQUAL(storage.materials.get_material_amount(/datum/material/iron), 0, "Exactly one finished print must consume the recipe.")
	TEST_ASSERT(!factory.print_chassis(basic, relay), "The same design must be denied after exhausting the stock.")

	storage.materials.insert_amount_mat(2 * SHEET_MATERIAL_AMOUNT, /datum/material/glass)
	TEST_ASSERT(factory.print_chassis(glass, relay), "The second design should now be printable without any iron.")
	link_section.set_anchored(FALSE)
	catalog.process_status()
	TEST_ASSERT_EQUAL(catalog.status, UI_CLOSE, "Disconnecting the factory must revoke the operator's production session.")
	deadline = world.time + 4 SECONDS
	UNTIL(!factory.printing_design || world.time >= deadline)
	var/obj/item/relay_chassis/ejected = locate(/obj/item/relay_chassis) in pad
	TEST_ASSERT_NOTNULL(ejected, "If the relay disconnects mid-print, the completed body must be ejected locally.")
	allocated += ejected
	TEST_ASSERT_EQUAL(storage.materials.get_material_amount(/datum/material/glass), 0, "The second design must consume its own material.")

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

/datum/unit_test/droid_relay_shuttle/proc/transport_coupling(obj/structure/relay_material_conduit/pipe)
	for(var/mutable_appearance/overlay as anything in pipe.overlays)
		if(overlay.icon_state == "coupling_[EAST]")
			return overlay
	return null

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
	var/obj/machinery/relay_fabricator/fabricator = relay.fabricator_ref.resolve()
	var/obj/machinery/relay_resource_storage/storage = fabricator.connected_storage()
	TEST_ASSERT_NOTNULL(storage, "The mapped cargo pipe must connect the factory to the resource silo.")
	TEST_ASSERT_EQUAL(storage.materials.get_material_amount(/datum/material/iron), 12 * SHEET_MATERIAL_AMOUNT, "The scenario's initial iron must be in the silo.")
	TEST_ASSERT_EQUAL(length(relay.transport_refs), 2, "Both transports must connect independently.")
	for(var/datum/weakref/transport_ref as anything in relay.transport_refs)
		var/obj/machinery/relay_transport/transport = transport_ref.resolve()
		var/turf/port_tile = get_step(transport, WEST)
		var/obj/structure/relay_material_conduit/transport_pipe = port_tile.relay_conduit()
		TEST_ASSERT_NOTNULL(transport_pipe, "Each transport must have a pipe at its west port.")
		var/mutable_appearance/coupling = transport_coupling(transport_pipe)
		TEST_ASSERT_NOTNULL(coupling, "Each transport must have a coupling facing east from the pipe end.")
		TEST_ASSERT_EQUAL(coupling.pixel_x, ICON_SIZE_X, "The coupling must bridge the gap on the machine's tile.")
		transport.set_anchored(FALSE)
		TEST_ASSERT_NULL(transport_coupling(transport_pipe), "Unanchoring the transport must remove the coupling.")
		transport.set_anchored(TRUE)
		TEST_ASSERT_NOTNULL(transport_coupling(transport_pipe), "Reanchoring the transport must restore the coupling.")
		var/turf/transport_tile = transport.loc
		transport.abstract_move(get_step(transport, EAST))
		TEST_ASSERT_NULL(transport_coupling(transport_pipe), "Moving the transport away must remove the coupling.")
		transport.abstract_move(transport_tile)
		TEST_ASSERT_NOTNULL(transport_coupling(transport_pipe), "Returning the transport must restore the coupling.")
	var/turf/glazed_floor = get_step(relay, NORTH)
	TEST_ASSERT(is_safe_turf(glazed_floor, dense_atoms = TRUE), "The former local-deployment check accepted the floor beneath the window.")
	TEST_ASSERT(!relay.local_deployment_turf(glazed_floor), "Local deployment must reject the shuttle's full-tile window.")
	TEST_ASSERT(relay.local_deployment_turf(get_step(relay, SOUTH)), "The open deck in front of the relay should remain available.")
	var/turf/trunk = get_step(get_step(relay, SOUTH), SOUTH)
	var/obj/structure/relay_material_conduit/section = trunk.relay_conduit()
	TEST_ASSERT_NOTNULL(section, "The bridge and production deck must be connected through the door tile.")
	section.set_anchored(FALSE)
	relay.refresh_device_links()
	TEST_ASSERT_NULL(relay.fabricator_ref, "Breaking the trunk must remove access to the fabrication deck.")
	TEST_ASSERT_EQUAL(length(relay.transport_refs), 0, "Both transports are behind the broken trunk.")
	TEST_ASSERT_NOTNULL(relay.board_ref?.resolve(), "The upstream computer must remain connected.")
	TEST_ASSERT_EQUAL(fabricator.connected_storage(), storage, "Local material delivery must remain possible on the isolated branch.")
	section.set_anchored(TRUE)
	relay.refresh_device_links()
	TEST_ASSERT_EQUAL(relay.fabricator_ref?.resolve(), fabricator, "Repairing the trunk must restore the factory automatically.")
	TEST_ASSERT(length(ship.engine_list), "The native engines must register for flight.")
