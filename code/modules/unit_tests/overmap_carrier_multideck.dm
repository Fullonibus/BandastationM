/** Separate template areas expose ownership on both loaded decks without inheriting a station's mapping rules. */
/area/shuttle/stationtrauma_space/unit_test_carrier_multideck
	area_flags_mapping = NONE

/area/shuttle/stationtrauma_space/unit_test_carrier_multideck/lower
	name = "Carrier test lower deck"

/area/shuttle/stationtrauma_space/unit_test_carrier_multideck/upper
	name = "Carrier test upper deck"

/** Load one real two-deck hull and use its upper-deck berth through the normal guest docking path. */
/datum/unit_test/overmap_carrier_multideck
	parent_type = /datum/unit_test/overmap_carrier
	/// Actual upper-deck helm, bound by sector.attach rather than manually linked by the fixture.
	var/obj/machinery/computer/stationtrauma_space_navigation/upper_helm
	/// Loaded footprint restored to empty space during teardown.
	var/list/turf/loaded_turfs = list()
	/// Destination used by the real inter-sector jump completion.
	var/datum/stationtrauma_overmap_sector/space/destination_sector

/datum/unit_test/overmap_carrier_multideck/New()
	..()
	// Retain the existing independent guest fixture and its helpers, replacing the small synthetic carrier with the map loader.
	QDEL_NULL(host_navigation)
	qdel(host_ship, force = TRUE)
	host_ship = null
	qdel(bay, force = TRUE)
	bay = null
	QDEL_LIST(station_objects)
	QDEL_NULL(traffic)
	host_ship = load_stationtrauma_space_ship("_maps/templates/unit_tests/carrier_multideck.dmm")
	TEST_ASSERT_NOTNULL(host_ship, "The real ship loader must return the two-deck carrier")
	TEST_ASSERT_EQUAL(length(host_ship.owned_z_levels), 2, "The loader must retain both managed template levels")
	var/min_x = round((world.maxx - 11) / 2) + 1
	var/min_y = round((world.maxy - 15) / 2) + 1
	var/obj/machinery/computer/stationtrauma_dock_controller/controller
	var/mobile_count = 0
	for(var/deck in host_ship.owned_z_levels)
		for(var/turf/tile as anything in block(locate(min_x, min_y, deck), locate(min_x + 10, min_y + 14, deck)))
			loaded_turfs += tile
			for(var/obj/docking_port/mobile/loaded_ship in tile)
				mobile_count++
			for(var/obj/machinery/computer/stationtrauma_dock_controller/mapped_controller in tile)
				controller = mapped_controller
			for(var/obj/machinery/computer/stationtrauma_space_navigation/console in tile)
				upper_helm = console
			for(var/obj/machinery/computer/stationtrauma_station_traffic/console in tile)
				traffic = console
	TEST_ASSERT_EQUAL(mobile_count, 1, "Two template decks must create exactly one native mobile port")
	TEST_ASSERT_NOTNULL(controller, "The upper deck must contain its mapped dock controller")
	TEST_ASSERT_NOTNULL(upper_helm, "The upper deck must contain the mapped navigation console")
	TEST_ASSERT_NOTNULL(traffic, "The upper deck must contain the mapped command console")
	TEST_ASSERT(carrier_sector.attach(host_ship), "The real sector attachment must register the complete multi-deck hull")
	bay = controller.owned_slot
	TEST_ASSERT_NOTNULL(bay, "The upper deck controller must own a standard S berth after attaching")
	host_navigation = host_ship.overmap
	STOP_PROCESSING(SSfastprocess, host_navigation)
	empty_hull_air(host_ship)
	site = carrier_sector.sites[bay.site_id]
	TEST_ASSERT_NOTNULL(site, "Attachment must publish the berth on the carrier's other deck")
	operator.forceMove(get_step(traffic, NORTH))
	navigation.pos_x = host_navigation.pos_x
	navigation.pos_y = host_navigation.pos_y
	TEST_ASSERT(host_navigation.set_engines_running(TRUE), "Mapped engines must power the complete orbital carrier")

/datum/unit_test/overmap_carrier_multideck/Destroy()
	if(carrier_sector && SSstationtrauma_space_voyage.sectors[carrier_sector.id] == carrier_sector)
		SSstationtrauma_space_voyage.sectors -= carrier_sector.id
	if(destination_sector && SSstationtrauma_space_voyage.sectors[destination_sector.id] == destination_sector)
		SSstationtrauma_space_voyage.sectors -= destination_sector.id
	QDEL_NULL(navigation)
	if(ship)
		qdel(ship, force = TRUE)
		ship = null
	QDEL_NULL(host_navigation)
	if(host_ship)
		qdel(host_ship, force = TRUE)
		host_ship = null
	for(var/turf/tile as anything in loaded_turfs)
		for(var/atom/movable/content in tile)
			qdel(content, force = TRUE)
		tile = tile.ChangeTurf(/turf/open/space, /turf/open/space)
		tile.change_area(get_area(tile), GLOB.areas_by_type[/area/space])
	loaded_turfs.Cut()
	bay = null
	upper_helm = null
	destination_sector = null
	return ..()

/datum/unit_test/overmap_carrier_multideck/Run()
	TEST_ASSERT(host_ship.orbital_only && !host_ship.can_land && host_ship.ship_class == "capital", "A multi-deck hull must automatically be restricted to orbital flight")
	TEST_ASSERT_NOTEQUAL(bay.z, host_ship.z, "The berth must be on the deck above the only mobile marker")
	var/turf/lower_origin = get_turf(host_ship)
	var/turf/upper_origin = get_step_multiz(lower_origin, UP)
	TEST_ASSERT_NOTNULL(upper_origin, "The loader must link the actual two managed decks vertically")
	TEST_ASSERT_EQUAL(upper_origin.z, bay.z, "UP from the base deck must reach the managed upper deck")
	TEST_ASSERT_EQUAL(get_step_multiz(upper_origin, DOWN), lower_origin, "DOWN must return to the same base-deck coordinate")
	TEST_ASSERT(host_ship.contains_deck(bay.z) && host_ship.is_in_shuttle_bounds(upper_helm), "Native containment must recognize actual owned upper-deck cells")
	TEST_ASSERT_EQUAL(upper_helm.vessel, host_ship, "Attachment must bind the upper-deck helm to the only ship")
	TEST_ASSERT_EQUAL(stationtrauma_carrier_at(traffic), host_navigation, "The upper-deck command console must resolve the same carrier")
	TEST_ASSERT_EQUAL(length(host_ship.engine_list), 2, "The loader must connect engines on both decks")
	var/list/engine_decks = list()
	for(var/obj/machinery/power/shuttle_engine/engine as anything in host_ship.engine_list)
		engine_decks |= engine.z
	TEST_ASSERT_EQUAL(length(engine_decks), 2, "The connected engines must actually occupy two distinct decks")
	TEST_ASSERT(!host_ship.canMove() && !host_navigation.available_for_ship_docking(), "An orbital carrier cannot initiate native movement or a voluntary ship pair")
	var/datum/stationtrauma_overmap_site/space/forbidden_site = allocate(/datum/stationtrauma_overmap_site/space)
	TEST_ASSERT(!host_ship.permits_docking(forbidden_site), "An orbital carrier must reject even seamless outgoing docking")
	forbidden_site.landing = TRUE
	TEST_ASSERT(!host_ship.permits_docking(forbidden_site), "An orbital carrier must reject a planetary landing")
	var/turf/original_host = get_turf(host_ship)
	var/turf/original_helm = get_turf(upper_helm)
	var/turf/original_slot = get_turf(bay)
	var/turf/original_flight = get_turf(host_navigation.flight_berth)
	var/original_flight_direction = host_navigation.flight_berth.dir
	var/list/engine_positions = list()
	for(var/obj/machinery/power/shuttle_engine/engine as anything in host_ship.engine_list)
		engine_positions[engine] = get_turf(engine)
	var/obj/docking_port/stationary/target = position_carrier_target()
	var/relocated
	var/native_result
	try
		relocated = host_navigation.relocate(target)
		host_navigation.relocating = TRUE
		native_result = host_ship.initiate_docking(target, force = TRUE)
	catch(var/exception/failure)
		host_navigation.relocating = FALSE
		target.forceMove(original_flight)
		target.setDir(original_flight_direction)
		throw failure
	host_navigation.relocating = FALSE
	target.forceMove(original_flight)
	target.setDir(original_flight_direction)
	TEST_ASSERT(!relocated, "A multi-deck carrier must reject even its otherwise valid native return to its own flight berth")
	TEST_ASSERT(native_result != DOCKING_SUCCESS, "Forced native docking inside the relocation boundary must not move an orbital-only hull")
	TEST_ASSERT_EQUAL(get_turf(host_ship), original_host, "Rejected outgoing moves must retain the native marker on its original deck")
	TEST_ASSERT_EQUAL(get_turf(upper_helm), original_helm, "Rejected outgoing moves must retain upper-deck equipment")
	TEST_ASSERT_EQUAL(get_turf(bay), original_slot, "Rejected outgoing moves must retain the upper-deck berth")
	for(var/obj/machinery/power/shuttle_engine/engine as anything in engine_positions)
		TEST_ASSERT_EQUAL(get_turf(engine), engine_positions[engine], "Rejected outgoing moves must retain engines on both actual decks")
	navigation.observe_ships(navigation.sensor_range)
	TEST_ASSERT(approve_guest() && navigation.dock(instant = TRUE), "A normal single-deck guest must really dock at the upper-deck berth")
	TEST_ASSERT_EQUAL(ship.z, bay.z, "Native guest arrival must reach the deck without a carrier mobile marker")
	TEST_ASSERT_EQUAL(navigation.carrier_host(), host_navigation, "The upper-deck mooring must form the normal carrier relation")
	host_navigation.helm_engaged = TRUE
	host_navigation.throttle = 50
	host_navigation.last_update = world.time - 1 SECONDS
	var/previous_x = host_navigation.pos_x
	host_navigation.process(1)
	TEST_ASSERT_NOTEQUAL(host_navigation.pos_x, previous_x, "Orbital restriction must still allow actual virtual carrier motion")
	TEST_ASSERT_EQUAL(navigation.pos_x, host_navigation.pos_x, "The upper-deck guest must follow virtual host movement")
	host_navigation.stop()
	destination_sector = allocate(/datum/stationtrauma_overmap_sector/space)
	destination_sector.id = "unit_test_multideck_destination"
	destination_sector.ready = TRUE
	SSstationtrauma_space_voyage.sectors[carrier_sector.id] = carrier_sector
	SSstationtrauma_space_voyage.sectors[destination_sector.id] = destination_sector
	carrier_sector.jump_routes = list(destination_sector.id)
	TEST_ASSERT(host_navigation.request_jump(destination_sector.id), "The mapped drive must allow a moored multi-deck carrier to jump")
	deltimer(host_navigation.jump_timer)
	TEST_ASSERT(host_navigation.finish_jump(destination_sector.id, host_navigation.control_revision), "The real jump completion must transfer the upper-deck guest and hosted berth")
	TEST_ASSERT_EQUAL(navigation.sector, destination_sector, "The upper-deck guest must enter the carrier's new sector")
	TEST_ASSERT_EQUAL(destination_sector.sites[site.id], site, "The same upper-deck berth must follow the carrier across sectors")
	TEST_ASSERT_EQUAL(upper_helm.vessel, host_ship, "Sector transfer must retain the actual upper-deck console binding")
	TEST_ASSERT(navigation.depart(instant = TRUE), "The upper-deck guest must depart through normal native movement after the jump")
	TEST_ASSERT_EQUAL(ship.get_docked(), navigation.flight_berth, "Departure must return only the guest to its independent flight level")
	TEST_ASSERT_EQUAL(get_turf(host_ship), original_host, "Guest departure must leave all carrier decks physically in place")
	navigation.stop()
	navigation.observe_ships(navigation.sensor_range)
	TEST_ASSERT(approve_guest() && navigation.dock(instant = TRUE), "The guest must request and return to the upper-deck berth in the new sector")
	TEST_ASSERT_EQUAL(ship.get_docked(), bay.active_berth, "Returning must use the upper deck's actual native arrival marker")

/** Rejecting two mobile markers must remove the loaded hardware while preserving all preexisting native registrations. */
/datum/unit_test/overmap_carrier_invalid_template/Run()
	var/previous_max_z = world.maxz
	var/list/previous_mobiles = SSshuttle.mobile_docking_ports.Copy()
	var/list/previous_stations = SSshuttle.stationary_docking_ports.Copy()
	var/list/previous_mobile_ids = SSshuttle.assoc_mobile.Copy()
	var/list/previous_station_ids = SSshuttle.assoc_stationary.Copy()
	var/obj/docking_port/mobile/stationtrauma_space/invalid_ship = load_stationtrauma_space_ship("_maps/templates/unit_tests/carrier_invalid_multideck.dmm")
	TEST_ASSERT_NULL(invalid_ship, "A real two-deck template with two mobile ports must be rejected")
	TEST_ASSERT_EQUAL(world.maxz - previous_max_z, 2, "The malformed template must exercise cleanup of both newly reserved physical decks")
	var/footprint_is_space = TRUE
	var/footprint_is_empty = TRUE
	var/center_x = round((world.maxx - 1) / 2) + 1
	var/center_y = round((world.maxy - 1) / 2) + 1
	for(var/deck in previous_max_z + 1 to world.maxz)
		var/turf/tile = locate(center_x, center_y, deck)
		if(!isspaceturf(tile))
			footprint_is_space = FALSE
		if((locate(/obj/docking_port/mobile) in tile) || (locate(/obj/machinery) in tile))
			footprint_is_empty = FALSE
	TEST_ASSERT(footprint_is_space, "Rejected template cleanup must restore the exact loaded footprint on both decks to space")
	TEST_ASSERT(footprint_is_empty, "Rejected template cleanup must remove both mobile ports and the mapped engine")
	TEST_ASSERT(!length(SSshuttle.mobile_docking_ports - previous_mobiles) && !length(previous_mobiles - SSshuttle.mobile_docking_ports), "Rejected loading must preserve the native mobile-port registry")
	TEST_ASSERT(!length(SSshuttle.stationary_docking_ports - previous_stations) && !length(previous_stations - SSshuttle.stationary_docking_ports), "Rejected loading must preserve the native stationary-port registry")
	var/mobile_ids_unchanged = length(SSshuttle.assoc_mobile) == length(previous_mobile_ids)
	for(var/id in previous_mobile_ids)
		if(SSshuttle.assoc_mobile[id] != previous_mobile_ids[id])
			mobile_ids_unchanged = FALSE
	var/station_ids_unchanged = length(SSshuttle.assoc_stationary) == length(previous_station_ids)
	for(var/id in previous_station_ids)
		if(SSshuttle.assoc_stationary[id] != previous_station_ids[id])
			station_ids_unchanged = FALSE
	TEST_ASSERT(mobile_ids_unchanged && station_ids_unchanged, "Rejected loading must preserve every preexisting native port ID association")
