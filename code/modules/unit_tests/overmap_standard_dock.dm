/// Station floor for the dock fixture without replacing a map's registered area.
/area/stationtrauma_space_site/unit_test_standard_dock
	area_flags_mapping = NONE

/// Native hull and berth fixtures for standard docks, with a one-tile vacuum gap along the wall.
/datum/unit_test/overmap_standard_dock
	abstract_type = /datum/unit_test/overmap_standard_dock
	/// Physical width of the fixture hull.
	var/hull_width = 7
	/// Physical length of the fixture hull.
	var/hull_length = 15
	/// Native ship class declared on the fixture hull.
	var/fixture_ship_class = "small"
	/// The ship's single certified hatch faces this direction before arrival.
	var/hatch_direction = EAST
	/// Offset north from the hull's southwest corner to its hatch.
	var/hatch_y = 3
	/// Empty private levels shared across these cases. Each fixture restores its changed cells.
	var/static/list/datum/space_level/test_levels
	/// Real overmap navigation with its periodic processing stopped during the test.
	var/datum/stationtrauma_overmap/space/navigation
	/// Real overmap mobile port on the southwest corner of the departure footprint.
	var/obj/docking_port/mobile/stationtrauma_space/unit_test_docking/ship
	/// The ship hatch that travels with the hull.
	var/obj/machinery/door/airlock/stationtrauma_docking/ship/hatch
	/// Mapped dock marker that defines the destination envelope.
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/bay
	/// Overmap destination represented by the dock marker.
	var/datum/stationtrauma_overmap_site/space/site
	/// Owned wall segments and any obstruction, removed before releasing their turfs.
	var/list/station_objects = list()
	/// Native registration keeps its ID counters after port deletion.
	var/list/stationary_ids
	/// Native registration keeps its ID counters after hull deletion.
	var/list/mobile_ids
	/// Original space areas for the cells temporarily used by the hull and dock.
	var/list/original_areas = list()

/datum/unit_test/overmap_standard_dock/New()
	..()
	stationary_ids = SSshuttle.assoc_stationary.Copy()
	mobile_ids = SSshuttle.assoc_mobile.Copy()
	if(!test_levels)
		test_levels = list(
			SSmapping.add_new_zlevel("Docking test flight", list(ZTRAIT_AWAY = TRUE)),
			SSmapping.add_new_zlevel("Docking test station", list(ZTRAIT_AWAY = TRUE)),
		)
	var/datum/space_level/flight_level = test_levels[1]
	var/datum/space_level/station_level = test_levels[2]
	TEST_ASSERT(world.maxx >= max(15, 4 + hull_width) && world.maxy >= 4 + hull_length, "The test map must fit the standard hull and wall")
	var/area/space/stationtrauma_space_home/exterior = new /area/space/stationtrauma_space_home/unit_test_docking
	var/area/shuttle/stationtrauma_space/hull_area = new /area/shuttle/stationtrauma_space/unit_test_docking
	var/area/stationtrauma_space_site/station_area = new /area/stationtrauma_space_site/unit_test_standard_dock
	allocated += list(exterior, hull_area, station_area)
	var/source_x = 4
	var/source_y = 4
	var/flight_z = flight_level.z_value
	var/station_z = station_level.z_value
	prepare_vacuum(locate(3, 3, flight_z), locate(source_x + hull_width, source_y + hull_length, flight_z), exterior)
	prepare_vacuum(locate(3, 3, station_z), locate(15, 19, station_z), exterior)
	var/last_x = source_x + hull_width - 1
	var/last_y = source_y + hull_length - 1
	for(var/turf/tile as anything in block(locate(source_x, source_y, flight_z), locate(last_x, last_y, flight_z)))
		// Each ship has a cutout while its four edges still span the full class envelope.
		if(tile.x == source_x + 2 && tile.y == (hatch_direction == EAST ? last_y : source_y))
			continue
		tile = tile.ChangeTurf(/turf/open/floor/plating)
		tile.change_area(get_area(tile), hull_area)
	var/turf/origin = locate(source_x, source_y, flight_z)
	ship = allocate(/obj/docking_port/mobile/stationtrauma_space/unit_test_docking, origin, list(hull_area))
	ship.ship_class = fixture_ship_class
	ship.calculate_docking_port_information()
	TEST_ASSERT_EQUAL(ship.width, hull_width, "The fixture hull must span the intended width")
	TEST_ASSERT_EQUAL(ship.height, hull_length, "The fixture hull must span the intended length")
	ship.register()
	for(var/turf/tile as anything in ship.return_turfs())
		if(get_area(tile) == hull_area)
			ship.underlying_areas_by_turf[tile] = exterior
	var/hatch_x = hatch_direction == EAST ? last_x : source_x
	hatch = allocate(/obj/machinery/door/airlock/stationtrauma_docking/ship, locate(hatch_x, source_y + hatch_y, flight_z))
	hatch.setDir(hatch_direction)
	navigation = allocate(/datum/stationtrauma_overmap/space, ship)
	ship.overmap = navigation
	STOP_PROCESSING(SSfastprocess, navigation)
	navigation.exterior = exterior
	navigation.preparing = FALSE
	var/turf/pad_corner = locate(4, 4, station_z)
	bay = allocate(/obj/docking_port/stationary/stationtrauma_space_station/standard_s, pad_corner)
	for(var/turf/tile as anything in block(locate(bay.x + 8, bay.y, station_z), locate(bay.x + 9, bay.y + 14, station_z)))
		tile = tile.ChangeTurf(/turf/open/floor/plating)
		tile.change_area(get_area(tile), station_area)
		if(tile.x == bay.x + 8)
			var/obj/machinery/door/airlock/stationtrauma_docking/wall/segment = allocate(/obj/machinery/door/airlock/stationtrauma_docking/wall, tile)
			segment.setDir(WEST)
			station_objects += segment
	site = allocate(/datum/stationtrauma_overmap_site/space)
	site.id = "unit_test_standard_dock"
	site.name = "Unit test standard S dock"
	site.physical_docking = TRUE
	site.berth = bay
	site.pos_x = navigation.pos_x
	site.pos_y = navigation.pos_y
	navigation.sites[site.id] = site

/// Use initialized vacuum on the private levels so map edges cannot relocate a fixture.
/datum/unit_test/overmap_standard_dock/proc/prepare_vacuum(turf/bottom_left, turf/top_right, area/exterior)
	for(var/turf/tile as anything in block(bottom_left, top_right))
		original_areas[tile] = get_area(tile)
		var/turf/open/space/vacuum = tile.ChangeTurf(/turf/open/space, /turf/open/space)
		vacuum.change_area(get_area(vacuum), exterior)
		vacuum.destination_x = 0
		vacuum.destination_y = 0
		vacuum.destination_z = 0

/datum/unit_test/overmap_standard_dock/Destroy()
	QDEL_NULL(navigation)
	if(ship)
		qdel(ship, force = TRUE)
		ship = null
	if(bay)
		qdel(bay, force = TRUE)
		bay = null
	QDEL_NULL(hatch)
	QDEL_LIST(station_objects)
	SSshuttle.assoc_stationary = stationary_ids
	SSshuttle.assoc_mobile = mobile_ids
	stationary_ids = mobile_ids = null
	site = null
	for(var/turf/tile as anything in original_areas)
		tile = tile.ChangeTurf(/turf/open/space, /turf/open/space)
		tile.change_area(get_area(tile), original_areas[tile])
	original_areas.Cut()
	return ..()

/// A real enclosed cell behind the selected door keeps pressure stable across the opening animations.
/datum/unit_test/overmap_standard_dock/proc/pressurize_endpoint(obj/machinery/door/airlock/stationtrauma_docking/endpoint)
	var/closed = endpoint.close()
	TEST_ASSERT(closed && endpoint.density && !endpoint.operating, "The pressure fixture must close its real endpoint before filling the isolated chamber")
	var/turf/open/floor/doorway = get_turf(endpoint)
	var/inward = REVERSE_DIR(endpoint.dir)
	var/turf/open/floor/inside = get_step(doorway, inward)
	TEST_ASSERT(istype(doorway) && istype(inside) && doorway.air && inside.air, "The pressure fixture needs a real floor on both sides of the chamber boundary")
	for(var/turf/tile as anything in list(get_step(inside, inward), get_step(inside, turn(inward, 90)), get_step(inside, turn(inward, -90))))
		tile.ChangeTurf(/turf/closed/wall)
	var/datum/gas_mixture/room_air = SSair.parse_gas_string(OPENTURF_DEFAULT_ATMOS, /datum/gas_mixture/turf)
	for(var/turf/open/floor/tile as anything in list(doorway, inside))
		tile.copy_air(room_air)
		tile.air_update_turf(TRUE, FALSE)
	qdel(room_air)
	return TRUE

/// A matching hatch preserves the hull's original orientation and joins the aligned wall section.
/datum/unit_test/overmap_standard_dock/preserve_orientation
	/// Item placed on the return berth during the native departure preflight.
	var/obj/item/late_flight_blocker
	/// Whether the bridge was vacuum when the return berth was blocked.
	var/bridge_vacuum_at_preflight
	/// Original bridge coordinates observed from the native first-turf movement signal.
	var/list/bridge_coordinates
	/// Tick when the bridge floor changed back to vacuum.
	var/bridge_retraction_time
	/// Tick when the first native hull turf moved.
	var/first_move_time
	/// Whether the bridge was already vacuum when the first native hull turf moved.
	var/bridge_retracted_at_takeoff

/datum/unit_test/overmap_standard_dock/preserve_orientation/Run()
	TEST_ASSERT_NOTNULL(site, "The real dock fixture must finish setup")
	var/turf/wall_tile = locate(bay.x + 8, bay.y + 3, bay.z)
	var/obj/machinery/door/airlock/stationtrauma_docking/wall/wall = locate() in wall_tile
	TEST_ASSERT_NOTNULL(wall, "The pressure fixture requires the aligned wall section")
	if(!pressurize_endpoint(hatch) || !pressurize_endpoint(wall))
		return
	var/obj/machinery/power/shuttle_engine/engine = allocate(/obj/machinery/power/shuttle_engine, locate(ship.x + 3, ship.y + 8, ship.z))
	engine.anchored = TRUE
	engine.engine_state = initial(engine.engine_state)
	engine.connect_to_shuttle(TRUE, ship)
	TEST_ASSERT(navigation.set_engines_running(TRUE), "The real propulsion fixture must be able to depart")
	TEST_ASSERT(navigation.select_site(site.id), "The registered standard dock must be selectable")
	TEST_ASSERT(navigation.dock(instant = TRUE), "The east-facing hatch should dock without turning. Status: [navigation.status]")
	TEST_ASSERT_EQUAL(ship.dir, NORTH, "The native move must preserve the compatible heading")
	TEST_ASSERT_EQUAL(get_turf(ship), get_turf(bay), "The full-width hull must use the southwest anchor")
	TEST_ASSERT_NOTEQUAL(ship.get_docked(), bay, "The native move must retain its separate arrival berth on the shared anchor tile")
	TEST_ASSERT_EQUAL(get_turf(hatch), locate(bay.x + 6, bay.y + 3, bay.z), "The hatch must reach the east edge aligned with its original row")
	TEST_ASSERT(!isspaceturf(locate(bay.x + 7, bay.y + 3, bay.z)), "Docking must fill the vacuum gap on the hatch's row")
	TEST_ASSERT(isspaceturf(locate(bay.x + 7, bay.y + 4, bay.z)), "The neighboring wall row must remain separate from the ship")
	TEST_ASSERT_EQUAL(navigation.docked, site, "Navigation must retain the selected dock while the ship is attached")
	// Both real doors animate in sequence. Wait for the actual result with a bounded deadline.
	var/deadline = world.time + 5 SECONDS
	UNTIL((!hatch.density && !hatch.operating && !wall.density && !wall.operating) || world.time >= deadline)
	TEST_ASSERT(!hatch.density && !wall.density, "The two endpoints must open after the sealed passage equalizes")
	var/turf/open/floor/bridge = locate(bay.x + 7, bay.y + 3, bay.z)
	TEST_ASSERT(istype(bridge) && bridge.air?.return_pressure() > HAZARD_LOW_PRESSURE, "The open bridge must have a pressurized floor")
	bridge_coordinates = list(bridge.x, bridge.y, bridge.z)
	RegisterSignal(bridge, COMSIG_TURF_CHANGE, PROC_REF(record_bridge_retraction))
	var/mob/living/carbon/human/consistent/traveller = allocate(/mob/living/carbon/human/consistent, bridge)
	var/obj/item/loose_item = allocate(/obj/item, bridge)
	station_objects += list(traveller, loose_item)
	var/obj/docking_port/stationary/moored_berth = ship.get_docked()
	var/turf/flight_anchor = get_turf(navigation.flight_berth)
	ship.preflight_action = CALLBACK(src, PROC_REF(block_flight_during_preflight), flight_anchor)
	var/departed = navigation.depart(instant = TRUE)
	TEST_ASSERT_NOTNULL(late_flight_blocker, "The obstruction must be added during the real native departure preflight")
	TEST_ASSERT(!departed, "A late obstruction at the flight berth must stop departure")
	TEST_ASSERT_EQUAL(ship.get_docked(), moored_berth, "A failed departure must leave the hull physically docked")
	TEST_ASSERT_EQUAL(navigation.docked, site, "A failed departure must preserve the selected dock")
	TEST_ASSERT_EQUAL(site.docking_owner, navigation, "A failed departure must preserve the dock reservation")
	TEST_ASSERT_EQUAL(get_turf(late_flight_blocker), flight_anchor, "The late obstruction must remain untouched")
	TEST_ASSERT(isfloorturf(bridge), "A failed departure must leave a floor under the traveller")
	TEST_ASSERT_NULL(bridge_retraction_time, "A failed departure must not replace the bridge with vacuum")
	TEST_ASSERT_EQUAL(get_turf(traveller), bridge, "A failed departure must leave the traveller on the bridge")
	TEST_ASSERT_EQUAL(get_turf(loose_item), bridge, "A failed departure must leave the item on the bridge")
	QDEL_NULL(late_flight_blocker)
	deadline = world.time + 5 SECONDS
	UNTIL((!hatch.density && !hatch.operating && !wall.density && !wall.operating) || world.time >= deadline)
	TEST_ASSERT(!hatch.density && !hatch.operating && !wall.density && !wall.operating, "A failed departure must reopen the bridge for the crew")
	ship.preflight_action = CALLBACK(src, PROC_REF(block_flight_during_preflight), flight_anchor)
	departed = navigation.depart()
	TEST_ASSERT_NOTNULL(late_flight_blocker, "The animated departure must reach native preflight")
	TEST_ASSERT(!departed, "A late obstruction must also stop the animated departure")
	TEST_ASSERT_NOTNULL(bridge_retraction_time, "The animated departure must fold the bridge before the rejection")
	TEST_ASSERT(bridge_vacuum_at_preflight, "The bridge must already be vacuum when animated departure reaches preflight")
	TEST_ASSERT_EQUAL(ship.get_docked(), moored_berth, "Rejected animated departure must leave the hull physically docked")
	TEST_ASSERT_EQUAL(site.docking_owner, navigation, "Rejected animated departure must keep ownership of the dock")
	bridge = TURF_FROM_COORDS_LIST(bridge_coordinates)
	TEST_ASSERT(istype(bridge, /turf/open/floor/plating/stationtrauma_dock_gangway), "Rejected animated departure must restore the bridge on its original tile")
	TEST_ASSERT_EQUAL(get_turf(traveller), bridge, "The restored bridge must still hold the traveller")
	TEST_ASSERT_EQUAL(get_turf(loose_item), bridge, "The restored bridge must still hold the loose item")
	QDEL_NULL(late_flight_blocker)
	deadline = world.time + 5 SECONDS
	UNTIL((!hatch.density && !hatch.operating && !wall.density && !wall.operating) || world.time >= deadline)
	TEST_ASSERT(!hatch.density && !hatch.operating && !wall.density && !wall.operating, "The restored bridge must reopen both doors")
	bridge_retraction_time = null
	var/turf/first_hull_turf = get_turf(ship)
	RegisterSignal(first_hull_turf, COMSIG_TURF_ON_SHUTTLE_MOVE, PROC_REF(check_bridge_at_takeoff))
	INVOKE_ASYNC(navigation, TYPE_PROC_REF(/datum/stationtrauma_overmap/space, depart))
	// Allow for the normal twenty-second mooring manoeuvre, then observe the actual construction effect.
	deadline = world.time + 30 SECONDS
	UNTIL((locate(/obj/effect/constructing_effect/stationtrauma_gangway) in bridge) || world.time >= deadline)
	TEST_ASSERT((locate(/obj/effect/constructing_effect/stationtrauma_gangway) in bridge), "Normal departure must show the bridge retraction effect")
	TEST_ASSERT(isfloorturf(bridge), "The bridge floor must remain while its retraction effect is playing")
	TEST_ASSERT(hatch.density && wall.density, "The endpoints must close before the bridge retraction effect")
	TEST_ASSERT_EQUAL(ship.get_docked(), moored_berth, "The hull must remain docked during the retraction effect")
	deadline = world.time + 8 SECONDS
	UNTIL(!navigation.docked || world.time >= deadline)
	UnregisterSignal(first_hull_turf, COMSIG_TURF_ON_SHUTTLE_MOVE)
	UnregisterSignal(bridge, COMSIG_TURF_CHANGE)
	TEST_ASSERT_NULL(navigation.docked, "Occupants on the bridge must not prevent departure")
	TEST_ASSERT_NOTNULL(bridge_retraction_time, "The bridge floor must emit its change to vacuum")
	TEST_ASSERT_NOTNULL(first_move_time, "The first hull turf must emit its native movement signal")
	TEST_ASSERT(bridge_retracted_at_takeoff, "The bridge must already be vacuum when the first hull turf moves")
	TEST_ASSERT(first_move_time - bridge_retraction_time >= 1 SECONDS, "The hull must wait at least one second after the bridge becomes vacuum")
	TEST_ASSERT_EQUAL(ship.get_docked(), navigation.flight_berth, "Departure must physically return the hull to its flight berth")
	var/turf/restored_vacuum = locate(bay.x + 7, bay.y + 3, bay.z)
	TEST_ASSERT(isspaceturf(restored_vacuum), "Departure must retract the bridge and restore vacuum")
	TEST_ASSERT_EQUAL(get_turf(traveller), restored_vacuum, "The traveller must remain in place when the bridge becomes vacuum")
	TEST_ASSERT_EQUAL(get_turf(loose_item), restored_vacuum, "The loose item must remain in place when the bridge becomes vacuum")
	TEST_ASSERT(hatch.density && wall.density, "Both endpoints must be closed after departure")

/** Obstruct the return berth after native docking has begun its departure preflight. */
/datum/unit_test/overmap_standard_dock/preserve_orientation/proc/block_flight_during_preflight(turf/flight_anchor)
	bridge_vacuum_at_preflight = isspaceturf(TURF_FROM_COORDS_LIST(bridge_coordinates))
	late_flight_blocker = allocate(/obj/item, flight_anchor)
	station_objects += late_flight_blocker

/datum/unit_test/overmap_standard_dock/preserve_orientation/proc/check_bridge_at_takeoff(turf/source)
	SIGNAL_HANDLER
	if(!isnull(first_move_time))
		return
	first_move_time = world.time
	bridge_retracted_at_takeoff = isspaceturf(TURF_FROM_COORDS_LIST(bridge_coordinates))

/datum/unit_test/overmap_standard_dock/preserve_orientation/proc/record_bridge_retraction(turf/source, new_turf_type)
	SIGNAL_HANDLER
	if(isnull(bridge_retraction_time) && ispath(new_turf_type, /turf/open/space))
		bridge_retraction_time = world.time

/// An opposite-side hatch requires a half-turn before moving the hull and building its passage.
/datum/unit_test/overmap_standard_dock/reverse_orientation
	hatch_direction = WEST
	hatch_y = 4

/datum/unit_test/overmap_standard_dock/reverse_orientation/Run()
	TEST_ASSERT_NOTNULL(site, "The real dock fixture must finish setup")
	TEST_ASSERT(navigation.select_site(site.id), "The registered standard dock must be selectable")
	TEST_ASSERT(navigation.dock(instant = TRUE), "A west-facing hatch should dock after a half-turn. Status: [navigation.status]")
	TEST_ASSERT_EQUAL(ship.dir, SOUTH, "The native move must turn the opposite-side hatch toward the wall")
	TEST_ASSERT_EQUAL(get_turf(ship), locate(bay.x + 6, bay.y + 14, bay.z), "After a half-turn the original southwest anchor must land at the northeast corner")
	TEST_ASSERT_EQUAL(get_turf(hatch), locate(bay.x + 6, bay.y + 10, bay.z), "The rotated hatch must line up with row ten of the dock")
	TEST_ASSERT(!isspaceturf(locate(bay.x + 7, bay.y + 10, bay.z)), "Docking must fill the gap at the rotated hatch")
	TEST_ASSERT(isspaceturf(locate(bay.x + 7, bay.y + 4, bay.z)), "The original row cannot receive the rotated passage")

/// A blocker outside the landing footprint must prevent arrival when it occupies the only possible passage.
/datum/unit_test/overmap_standard_dock/blocked_passage/Run()
	TEST_ASSERT_NOTNULL(site, "The real dock fixture must finish setup")
	var/turf/departure = get_turf(ship)
	var/turf/gap = locate(bay.x + 7, bay.y + 3, bay.z)
	var/obj/structure/girder/blocker = allocate(/obj/structure/girder, gap)
	station_objects += blocker
	TEST_ASSERT(navigation.select_site(site.id), "The dock remains selectable before the pilot attempts docking")
	TEST_ASSERT(!navigation.dock(instant = TRUE), "An obstructed gap must prevent docking even when the hull footprint is clear")
	TEST_ASSERT_EQUAL(get_turf(ship), departure, "The ship must remain at its departure point when the bridge is blocked")
	TEST_ASSERT_EQUAL(get_turf(blocker), gap, "A failed approach must leave the obstruction intact")
	TEST_ASSERT(isspaceturf(gap), "The failed approach must leave the gap as vacuum")
	TEST_ASSERT_NULL(site.docking_owner, "The aborted approach must release the site's reservation")

/// A passage blocked during the yielding native preflight must still stop the hull before movement.
/datum/unit_test/overmap_standard_dock/late_blocked_passage
	/// The obstruction built during native preflight, if that step was reached.
	var/obj/structure/girder/late_blocker

/datum/unit_test/overmap_standard_dock/late_blocked_passage/Run()
	TEST_ASSERT_NOTNULL(site, "The real dock fixture must finish setup")
	var/turf/departure = get_turf(ship)
	var/turf/gap = locate(bay.x + 7, bay.y + 3, bay.z)
	TEST_ASSERT(navigation.select_site(site.id), "The registered standard dock must be selectable")
	ship.preflight_action = CALLBACK(src, PROC_REF(block_passage), gap)
	var/arrived = navigation.dock(instant = TRUE)
	TEST_ASSERT_NOTNULL(late_blocker, "The real native preflight must run before the passage is blocked")
	TEST_ASSERT(!arrived, "The final check must reject the newly obstructed passage")
	TEST_ASSERT_EQUAL(get_turf(ship), departure, "Rejection during preflight must leave the hull at departure")
	TEST_ASSERT_EQUAL(get_turf(late_blocker), gap, "The last-minute obstruction must remain in place")
	TEST_ASSERT(isspaceturf(gap), "The obstructed gap must remain vacuum")
	TEST_ASSERT_NULL(site.docking_owner, "Rejection during preflight must release the site's reservation")

/datum/unit_test/overmap_standard_dock/late_blocked_passage/proc/block_passage(turf/gap)
	late_blocker = allocate(/obj/structure/girder, gap)
	station_objects += late_blocker

/// A real registered station berth requires a pilot clearance before accepting the hull.
/datum/unit_test/overmap_standard_dock/station_clearance
	/// Original sector restored after exercising the station console.
	var/datum/stationtrauma_overmap_sector/space/home/original_home
	/// The private fixture deck temporarily counts as part of the station.
	var/datum/space_level/traffic_level
	/// Previous value of the cached station trait.
	var/previous_station_cache
	/// Foreign berth owned by the fixture, even if an assertion fails.
	var/obj/docking_port/stationary/stationtrauma_space_station/standard_s/remote_berth
	/// Second local slot selectable by the dispatcher.
	var/obj/docking_port/stationary/stationtrauma_space_station/standard_m/alternate_berth

/datum/unit_test/overmap_standard_dock/station_clearance/Destroy()
	if(alternate_berth)
		qdel(alternate_berth, force = TRUE)
		alternate_berth = null
	if(remote_berth)
		qdel(remote_berth, force = TRUE)
		remote_berth = null
	if(traffic_level)
		SSstationtrauma_space_voyage.sectors["epsilon_eridani"] = original_home
		if(!original_home)
			SSstationtrauma_space_voyage.sectors -= "epsilon_eridani"
		traffic_level.traits -= ZTRAIT_STATION
		GLOB.station_levels_cache[traffic_level.z_value] = previous_station_cache
		traffic_level = null
	return ..()

/datum/unit_test/overmap_standard_dock/station_clearance/Run()
	TEST_ASSERT_NOTNULL(site, "The clearance test needs a real berth")
	var/datum/stationtrauma_overmap_sector/space/home/home = allocate(/datum/stationtrauma_overmap_sector/space/home)
	home.ready = TRUE
	original_home = SSstationtrauma_space_voyage.sectors[home.id]
	SSstationtrauma_space_voyage.sectors[home.id] = home
	traffic_level = SSmapping.get_level(bay.z)
	GLOB.station_levels_cache.len = max(length(GLOB.station_levels_cache), bay.z)
	previous_station_cache = GLOB.station_levels_cache[bay.z]
	traffic_level.traits[ZTRAIT_STATION] = TRUE
	GLOB.station_levels_cache[bay.z] = null
	navigation.sites -= site.id
	TEST_ASSERT(home.register(ship.shuttle_id, navigation), "The hull must be a member of the station sector")
	home.sites[site.id] = site
	home.register_docking_berth(site, "traffic:station", "Test station")
	var/target_id = site.docking_target.id
	alternate_berth = allocate(/obj/docking_port/stationary/stationtrauma_space_station/standard_m, locate(16, 4, bay.z))
	var/datum/stationtrauma_overmap_site/space/alternate_site = allocate(/datum/stationtrauma_overmap_site/space)
	alternate_site.id = "unit_test_alternate_berth"
	alternate_site.name = "Alternate M berth"
	alternate_site.physical_docking = TRUE
	alternate_site.berth = alternate_berth
	home.sites[alternate_site.id] = alternate_site
	home.register_docking_berth(alternate_site, target_id, "Test station")
	TEST_ASSERT(navigation.select_site(target_id), "The registered berth must be selectable")
	var/turf/flight_position = get_turf(ship)
	TEST_ASSERT(!navigation.dock(instant = TRUE), "Station docking must refuse an uncleared pilot even with the approach timer skipped")
	TEST_ASSERT_EQUAL(get_turf(ship), flight_position, "An uncleared request must leave the hull on its flight level")
	TEST_ASSERT_NULL(site.docking_owner, "An uncleared pilot must not reserve the berth")
	var/obj/machinery/computer/stationtrauma_space_navigation/helm = allocate(/obj/machinery/computer/stationtrauma_space_navigation, flight_position)
	helm.vessel = ship
	var/turf/corridor = locate(bay.x + 9, bay.y + 3, bay.z)
	var/turf/traffic_floor = get_step(corridor, EAST)
	traffic_floor = traffic_floor.ChangeTurf(/turf/open/floor/plating)
	traffic_floor.change_area(get_area(traffic_floor), get_area(corridor))
	var/obj/machinery/computer/stationtrauma_station_traffic/traffic = allocate(/obj/machinery/computer/stationtrauma_station_traffic, traffic_floor)
	var/mob/living/carbon/human/consistent/operator = allocate(/mob/living/carbon/human/consistent, corridor)
	TEST_ASSERT(!helm.navigation_command("request_station_dock", site.id), "A stale pilot command must reject a private berth ID")
	TEST_ASSERT(helm.navigation_command("request_station_dock", target_id), "The pilot must be able to request the selected station")
	TEST_ASSERT(!helm.navigation_command("request_station_dock", target_id), "A duplicate request must not replace a pending request")
	var/datum/stationtrauma_station_docking_request/request = home.station_docking_requests[ship.shuttle_id]
	TEST_ASSERT_NOTNULL(request, "The station must see the request from the pilot")
	TEST_ASSERT_NULL(site.docking_owner, "A pending request must not reserve the berth")
	var/stale_token = request.token
	TEST_ASSERT(!traffic.respond_to_request(operator, ship.shuttle_id, stale_token, TRUE, site.id), "An operator without command access must not approve a request")
	var/obj/item/card/id/advanced/command_card = allocate(/obj/item/card/id/advanced)
	command_card.set_access(list(ACCESS_COMMAND), FORCE_ADD_ALL)
	TEST_ASSERT(operator.put_in_active_hand(command_card), "The operator must be able to present a command card")
	TEST_ASSERT(traffic.allowed(operator), "The presented ID must grant command access")
	TEST_ASSERT(traffic.can_interact(operator), "The adjacent operator must be able to use the computer")
	TEST_ASSERT(traffic.can_operate(operator), "The powered station computer must accept the operator")
	TEST_ASSERT_EQUAL(traffic.traffic_sector(), home, "The command computer must resolve the live station sector")
	TEST_ASSERT(request.is_current(), "The request must belong to the active ship and selected station")
	var/list/traffic_data = traffic.ui_data(operator)
	var/list/requests = traffic_data["requests"]
	TEST_ASSERT_EQUAL(length(requests), 1, "The command console must display the pending request")
	var/list/pending = requests[1]
	var/list/compatible = pending["compatible_docks"]
	TEST_ASSERT(length(compatible) == 2 && (site.id in compatible) && (alternate_site.id in compatible), "A small ship must be offered both local compatible berths")
	TEST_ASSERT_NULL(pending["dock_id"], "The pilot request must arrive without a selected dock")
	TEST_ASSERT(traffic.respond_to_request(operator, ship.shuttle_id, stale_token, FALSE), "The dispatcher must be able to deny a pending request")

	// A different fixed installation can register a berth in the same sector.
	remote_berth = allocate(/obj/docking_port/stationary/stationtrauma_space_station/standard_s, locate(15, 19, flight_position.z))
	var/datum/stationtrauma_overmap_site/space/remote_site = allocate(/datum/stationtrauma_overmap_site/space)
	remote_site.id = "unit_test_remote_berth"
	remote_site.name = "Remote installation"
	remote_site.physical_docking = TRUE
	remote_site.berth = remote_berth
	home.sites[remote_site.id] = remote_site
	home.register_docking_berth(remote_site, "traffic:remote", "Remote installation")
	var/remote_target_id = remote_site.docking_target.id
	TEST_ASSERT(!is_station_level(remote_berth.z), "The foreign berth must be outside the station levels")
	TEST_ASSERT(navigation.select_site(remote_target_id), "The pilot must be able to select a berth at the other installation")
	TEST_ASSERT(helm.navigation_command("request_station_dock", remote_target_id), "The pilot must be able to request the foreign berth")
	var/datum/stationtrauma_station_docking_request/remote_request = home.station_docking_requests[ship.shuttle_id]
	TEST_ASSERT(remote_request?.is_current(), "The foreign request must be valid even though this console cannot manage it")
	var/list/local_data = traffic.ui_data(operator)
	var/foreign_denied = traffic.respond_to_request(operator, ship.shuttle_id, remote_request.token, FALSE)
	TEST_ASSERT(!foreign_denied, "The station console must not be able to deny the other installation's request")
	TEST_ASSERT_EQUAL(length(local_data["docks"]), 2, "The station console must only list its own berths")
	TEST_ASSERT_EQUAL(length(local_data["requests"]), 0, "The station console must hide the other installation's request")
	TEST_ASSERT(helm.navigation_command("cancel_station_dock", remote_target_id), "The pilot must still be able to cancel the foreign request")
	TEST_ASSERT(navigation.select_site(target_id), "The pilot must be able to target the station again")
	TEST_ASSERT(helm.navigation_command("request_station_dock", target_id), "The pilot can send a new request after denial")
	request = home.station_docking_requests[ship.shuttle_id]
	TEST_ASSERT(!traffic.respond_to_request(operator, ship.shuttle_id, stale_token, TRUE, site.id), "A stale dispatcher action must not approve a replacement")
	TEST_ASSERT(!traffic.respond_to_request(operator, ship.shuttle_id, request.token, TRUE, remote_site.id), "The station console must reject a berth from another installation")
	TEST_ASSERT(traffic.respond_to_request(operator, ship.shuttle_id, request.token, TRUE, alternate_site.id), "The dispatcher must be able to assign either compatible berth")
	TEST_ASSERT_EQUAL(navigation.selected_docking_site(), alternate_site, "The assigned M berth must resolve as the pilot's docking site")
	TEST_ASSERT_NULL(site.docking_owner, "The other berth must stay free")
	TEST_ASSERT(helm.navigation_command("cancel_station_dock", target_id), "The pilot must be able to release the alternate assignment")
	TEST_ASSERT_NULL(alternate_site.docking_owner, "Cancellation must release the exact assigned berth")
	TEST_ASSERT(helm.navigation_command("request_station_dock", target_id), "The pilot must be able to request again after releasing the assignment")
	request = home.station_docking_requests[ship.shuttle_id]
	TEST_ASSERT(traffic.respond_to_request(operator, ship.shuttle_id, request.token, TRUE, site.id), "The dispatcher must be able to assign the S berth to the new request")
	TEST_ASSERT_EQUAL(site.docking_owner, navigation, "Approval must reserve the selected berth for that ship")
	ship.preflight_action = CALLBACK(home, TYPE_PROC_REF(/datum/stationtrauma_overmap_sector/space/home, respond_station_docking), ship.shuttle_id, request.token, FALSE)
	TEST_ASSERT(!navigation.dock(instant = TRUE), "Revocation during native preflight must cancel the physical approach")
	TEST_ASSERT_EQUAL(get_turf(ship), flight_position, "A revoked ship must remain on its flight level")
	TEST_ASSERT_NULL(site.docking_owner, "Revocation must release the reservation")
	TEST_ASSERT(helm.navigation_command("request_station_dock", target_id), "The pilot can request again after revocation")
	request = home.station_docking_requests[ship.shuttle_id]
	TEST_ASSERT(traffic.respond_to_request(operator, ship.shuttle_id, request.token, TRUE, site.id), "The dispatcher must be able to issue a fresh grant")
	TEST_ASSERT(helm.navigation_command("dock", target_id), "The pilot must be able to begin the timed approach")
	var/cancel_deadline = world.time + 5 SECONDS
	UNTIL(navigation.approach_started || world.time >= cancel_deadline)
	TEST_ASSERT(navigation.approach_started, "The pilot must be in the timed approach before cancelling")
	TEST_ASSERT(helm.navigation_command("cancel_station_dock", target_id), "The pilot must be able to relinquish clearance during the approach")
	UNTIL(!navigation.preparing || world.time >= cancel_deadline)
	TEST_ASSERT(!navigation.preparing && !navigation.docked, "The cancelled approach must stop without waiting out the approach timer")
	TEST_ASSERT_NULL(site.docking_owner, "Pilot cancellation must release the reservation")
	TEST_ASSERT(helm.navigation_command("request_station_dock", target_id), "The pilot can request again after cancelling")
	request = home.station_docking_requests[ship.shuttle_id]
	TEST_ASSERT(traffic.respond_to_request(operator, ship.shuttle_id, request.token, TRUE, site.id), "The dispatcher must be able to grant clearance after the pilot cancels")
	TEST_ASSERT(helm.navigation_command("dock", target_id), "The pilot must be able to start the approved maneuver")
	var/deadline = world.time + 30 SECONDS
	UNTIL(navigation.docked == site || world.time >= deadline)
	TEST_ASSERT_EQUAL(navigation.docked, site, "The approved pilot command must complete the native docking maneuver")
	TEST_ASSERT_EQUAL(get_turf(ship), get_turf(bay), "The ship must physically arrive at the requested berth")
	TEST_ASSERT_NULL(home.station_docking_requests[ship.shuttle_id], "Successful docking must consume the clearance")
	TEST_ASSERT_EQUAL(site.docking_owner, navigation, "Physical occupancy must keep the berth reserved")

/// A public dock answers after a delay and preserves one reservation at a time.
/datum/unit_test/overmap_standard_dock/automatic_clearance
	/// Second pilot's mobile port, kept apart from the main fixture's hull.
	var/obj/docking_port/mobile/stationtrauma_space/unit_test_docking/second_ship
	/// The second pilot's real sector navigation.
	var/datum/stationtrauma_overmap/space/second_navigation
	/// Larger free slot in the same endpoint, used only for the assignment tests.
	var/obj/docking_port/stationary/stationtrauma_space_station/standard_m/medium_bay

/datum/unit_test/overmap_standard_dock/automatic_clearance/Destroy()
	if(medium_bay)
		qdel(medium_bay, force = TRUE)
		medium_bay = null
	QDEL_NULL(second_navigation)
	if(second_ship)
		qdel(second_ship, force = TRUE)
		second_ship = null
	return ..()

/datum/unit_test/overmap_standard_dock/automatic_clearance/Run()
	var/datum/stationtrauma_overmap_sector/space/home/home = allocate(/datum/stationtrauma_overmap_sector/space/home)
	navigation.sites -= site.id
	TEST_ASSERT(home.register(ship.shuttle_id, navigation), "The first pilot must join the station sector")
	home.sites[site.id] = site
	bay.auto_approve_docking = TRUE
	medium_bay = allocate(/obj/docking_port/stationary/stationtrauma_space_station/standard_m, locate(16, 4, bay.z))
	medium_bay.auto_approve_docking = TRUE
	var/datum/stationtrauma_overmap_site/space/medium_site = allocate(/datum/stationtrauma_overmap_site/space)
	medium_site.id = "unit_test_public_medium_berth"
	medium_site.name = "Public M berth"
	medium_site.physical_docking = TRUE
	medium_site.berth = medium_bay
	home.sites[medium_site.id] = medium_site
	var/target_id = "traffic:public_fixture"
	// Register M first to test that an available S is preferred regardless of registration order.
	home.register_docking_berth(medium_site, target_id, "Test trading post")
	home.register_docking_berth(site, target_id, "Test trading post")

	var/turf/second_origin = locate(12, 4, ship.z)
	var/turf/second_corner = locate(13, 6, ship.z)
	var/area/shuttle/stationtrauma_space/second_area = new /area/shuttle/stationtrauma_space/unit_test_docking
	allocated += second_area
	prepare_vacuum(second_origin, second_corner, navigation.exterior)
	for(var/turf/tile as anything in block(second_origin, second_corner))
		tile = tile.ChangeTurf(/turf/open/floor/plating)
		tile.change_area(get_area(tile), second_area)
	second_ship = allocate(/obj/docking_port/mobile/stationtrauma_space/unit_test_docking, second_origin, list(second_area))
	second_ship.ship_class = fixture_ship_class
	second_ship.register()
	second_navigation = allocate(/datum/stationtrauma_overmap/space, second_ship)
	second_ship.overmap = second_navigation
	second_navigation.preparing = FALSE
	STOP_PROCESSING(SSfastprocess, second_navigation)
	TEST_ASSERT(home.register(second_ship.shuttle_id, second_navigation), "The second pilot must join the same sector")

	var/obj/machinery/computer/stationtrauma_space_navigation/helm = allocate(/obj/machinery/computer/stationtrauma_space_navigation, get_turf(ship))
	helm.vessel = ship
	var/obj/machinery/computer/stationtrauma_space_navigation/second_helm = allocate(/obj/machinery/computer/stationtrauma_space_navigation, second_origin)
	second_helm.vessel = second_ship
	TEST_ASSERT(navigation.select_site(target_id) && second_navigation.select_site(target_id), "Both pilots must be able to select the same dock")

	TEST_ASSERT(helm.navigation_command("request_station_dock", target_id), "A free public dock must accept the first request")
	TEST_ASSERT(!navigation.has_station_clearance(site), "A public dock must wait before granting clearance")
	TEST_ASSERT(helm.navigation_command("cancel_station_dock", target_id), "The first pilot must be able to cancel during the delay")
	TEST_ASSERT(second_helm.navigation_command("request_station_dock", target_id), "The second pilot must be able to request a free dock")
	var/deadline = world.time + 8 SECONDS
	UNTIL(second_navigation.has_station_clearance(site) || world.time >= deadline)
	TEST_ASSERT(second_navigation.has_station_clearance(site), "The automatic response must prefer the free S berth to the earlier registered M berth")
	TEST_ASSERT_NULL(navigation.get_station_docking_request(), "A cancelled request must not be restored by its timer")

	TEST_ASSERT(helm.navigation_command("request_station_dock", target_id), "A request can be submitted while another pilot holds clearance")
	deadline = world.time + 8 SECONDS
	UNTIL(navigation.has_station_clearance(medium_site) || world.time >= deadline)
	TEST_ASSERT_EQUAL(medium_site.docking_owner, navigation, "Automatic assignment must fall back to M when S is reserved")
	TEST_ASSERT_EQUAL(site.docking_owner, second_navigation, "The competing request must leave the existing S reservation intact")
	TEST_ASSERT(helm.navigation_command("cancel_station_dock", target_id), "The first pilot must be able to release the M assignment")
	TEST_ASSERT(second_helm.navigation_command("cancel_station_dock", target_id), "The second pilot must be able to release the S assignment")

	TEST_ASSERT(helm.navigation_command("request_station_dock", target_id), "The first pilot must be able to request again")
	var/requested_at = world.time
	deadline = requested_at + 8 SECONDS
	UNTIL(navigation.has_station_clearance(site) || world.time >= deadline)
	TEST_ASSERT(navigation.has_station_clearance(site), "The retry must grant clearance without a dispatcher")
	TEST_ASSERT(world.time >= requested_at + 3 SECONDS, "The automatic response must wait at least three seconds")
	TEST_ASSERT(navigation.dock(instant = TRUE), "Automatic clearance must permit the real docking maneuver")
	// Reserve the other berth for an approach to exercise the no-capacity response.
	medium_site.docking_owner = navigation
	TEST_ASSERT(second_helm.navigation_command("request_station_dock", target_id), "A request can be submitted while both berths are taken")
	deadline = world.time + 8 SECONDS
	UNTIL(!second_navigation.get_station_docking_request() || world.time >= deadline)
	TEST_ASSERT_NULL(second_navigation.get_station_docking_request(), "Automatic clearance must refuse when neither berth is free")
	medium_site.docking_owner = null
	TEST_ASSERT_EQUAL(site.docking_owner, navigation, "A refused request must leave the moored hull in control")

/// A newly built controller must publish a real slot without claiming another controller's envelope.
/datum/unit_test/overmap_standard_dock/runtime_controller
	/// The two independently placed controllers claim adjacent, overlapping positions.
	var/obj/machinery/computer/stationtrauma_dock_controller/first_controller
	var/obj/machinery/computer/stationtrauma_dock_controller/second_controller
	/// Private test level temporarily marked as a station for controller publication.
	var/datum/space_level/controller_level
	/// Cached station classification to restore on teardown.
	var/previous_station_cache
	/// Temporary home sector when the running test map has no overmap of its own.
	var/datum/stationtrauma_overmap_sector/space/home/temporary_home

/datum/unit_test/overmap_standard_dock/runtime_controller/Destroy()
	QDEL_NULL(first_controller)
	QDEL_NULL(second_controller)
	if(temporary_home)
		SSstationtrauma_space_voyage.sectors -= temporary_home.id
		QDEL_NULL(temporary_home)
	if(controller_level)
		controller_level.traits -= ZTRAIT_STATION
		GLOB.station_levels_cache[controller_level.z_value] = previous_station_cache
		controller_level = null
	return ..()

/datum/unit_test/overmap_standard_dock/runtime_controller/Run()
	TEST_ASSERT_NOTNULL(bay, "The controller fixture needs the original dock geometry")
	var/level = bay.z
	var/anchor_x = max(bay.x + 12, TRANSITIONEDGE + 1)
	var/anchor_y = TRANSITIONEDGE + 1
	TEST_ASSERT(anchor_x + 9 < world.maxx - TRANSITIONEDGE && anchor_y + 15 < world.maxy - TRANSITIONEDGE, "The test map must fit both runtime envelopes inside its transition border")
	var/turf/first_anchor = locate(anchor_x, anchor_y, level)
	var/area/station_area = get_area(locate(bay.x + 9, bay.y, level))
	prepare_vacuum(first_anchor, locate(anchor_x + 10, anchor_y + 15, level), get_area(bay))
	var/datum/stationtrauma_overmap_sector/space/home/home_sector = prepare_controller_sector(level)
	// Sixteen rows cover the fifteen-row envelopes at both offsets.
	for(var/row in anchor_y to anchor_y + 15)
		var/turf/wall_floor = lay_controller_floor(locate(anchor_x + 8, row, level), station_area)
		var/obj/machinery/door/airlock/stationtrauma_docking/wall/segment = allocate(/obj/machinery/door/airlock/stationtrauma_docking/wall, wall_floor)
		segment.setDir(WEST)
		station_objects += segment
		lay_controller_floor(locate(anchor_x + 9, row, level), station_area)
	var/turf/first_floor = lay_controller_floor(locate(anchor_x + 10, anchor_y, level), station_area)
	var/turf/second_floor = lay_controller_floor(get_step(first_floor, NORTH), station_area)
	first_controller = allocate(/obj/machinery/computer/stationtrauma_dock_controller, first_floor)
	first_controller.setDir(NORTH)
	second_controller = allocate(/obj/machinery/computer/stationtrauma_dock_controller, second_floor)
	second_controller.setDir(NORTH)
	var/initial_layout = second_controller.layout_key()
	TEST_ASSERT(!second_controller.configure_offset(-1), "An offset cannot precede the first row")
	TEST_ASSERT(!second_controller.configure_offset(second_controller.slot_height), "An offset cannot pass the last row")
	TEST_ASSERT(!second_controller.configure_offset(1.5), "Offsets must use whole tiles")
	TEST_ASSERT(!second_controller.configure_offset("1"), "An offset must arrive as a number")
	second_controller.site_id = "mapped_test_dock"
	TEST_ASSERT(!second_controller.configure_offset(1), "A mapped dock must retain its configured offset")
	second_controller.site_id = null
	TEST_ASSERT(second_controller.configure_offset(1), "A built controller must support shifting along the wall")
	TEST_ASSERT(second_controller.layout_key() != initial_layout, "The previous layout key must stop accepting UI actions after the offset changes")
	TEST_ASSERT_EQUAL(second_controller.proposed_anchor(), first_anchor, "The same angle and a one-tile offset must preserve the footprint")
	first_controller.dock_name = "Причал Сигнал"
	var/activation_error = first_controller.publish_slot()
	TEST_ASSERT_NULL(activation_error, "A built controller must publish a complete free envelope")
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/first_slot = first_controller.owned_slot
	TEST_ASSERT_NOTNULL(first_slot, "The controller must own a real native slot")
	TEST_ASSERT_EQUAL(get_turf(first_slot), first_anchor, "The slot must use the anchor projected from the controller")
	var/datum/stationtrauma_overmap_site/space/first_site = first_slot.published_site
	TEST_ASSERT_NOTNULL(first_site, "Activation must publish an overmap destination")
	TEST_ASSERT_EQUAL(first_site.name, "Причал Сигнал", "Publication must use the custom controller name")
	var/first_id = first_site.id
	TEST_ASSERT_EQUAL(home_sector.sites[first_id], first_site, "The registered overmap sector must list the new port")
	TEST_ASSERT(second_controller.publish_slot(), "A second valid envelope must be rejected while it overlaps the first")
	TEST_ASSERT_NULL(second_controller.owned_slot, "An overlap must not leave a second native slot")
	TEST_ASSERT_EQUAL(home_sector.sites[first_id], first_site, "An overlap rejection must retain the original destination")
	QDEL_NULL(first_controller)
	TEST_ASSERT(QDELETED(first_slot), "Removing an empty controller must remove its native slot")
	TEST_ASSERT_NULL(home_sector.sites[first_id], "Removing an empty controller must unpublish its destination")
	activation_error = second_controller.publish_slot()
	TEST_ASSERT_NULL(activation_error, "The previously overlapping controller must succeed after the first is removed")
	TEST_ASSERT_EQUAL(get_turf(second_controller.owned_slot), first_anchor, "Publication must use the player's offset")
	TEST_ASSERT(!second_controller.configure_offset(0), "A registered controller must keep its offset until it retires")
	var/datum/stationtrauma_overmap_site/space/second_site = second_controller.owned_slot?.published_site
	TEST_ASSERT_NOTNULL(second_site, "The newly freed envelope must publish an actual destination")
	var/second_id = second_site.id
	TEST_ASSERT_EQUAL(home_sector.sites[second_id], second_site, "The sector must list the second destination")
	QDEL_NULL(second_controller)
	TEST_ASSERT_NULL(home_sector.sites[second_id], "Removing the second controller must also unpublish its destination")

/** Permit real runtime publication on the private test deck. */
/datum/unit_test/overmap_standard_dock/runtime_controller/proc/prepare_controller_sector(level)
	controller_level = SSmapping.get_level(level)
	GLOB.station_levels_cache.len = max(GLOB.station_levels_cache.len, level)
	previous_station_cache = GLOB.station_levels_cache[level]
	controller_level.traits[ZTRAIT_STATION] = TRUE
	GLOB.station_levels_cache[level] = null
	var/datum/stationtrauma_overmap_sector/space/home/home_sector = SSstationtrauma_space_voyage.sectors["epsilon_eridani"]
	if(!home_sector)
		temporary_home = new
		temporary_home.ready = TRUE
		SSstationtrauma_space_voyage.sectors[temporary_home.id] = temporary_home
		home_sector = temporary_home
	return home_sector

/** Extend the same powered station area for both construction footprints. */
/datum/unit_test/overmap_standard_dock/runtime_controller/proc/lay_controller_floor(turf/tile, area/station_area)
	tile = tile.ChangeTurf(/turf/open/floor/plating)
	tile.change_area(get_area(tile), station_area)
	return tile

/// A complete player-built M dock must take a full-size M hull and deploy all aligned hatches.
/datum/unit_test/overmap_standard_dock/runtime_controller/medium
	hull_width = 19
	hull_length = 25
	fixture_ship_class = "medium"

/datum/unit_test/overmap_standard_dock/runtime_controller/medium/Run()
	TEST_ASSERT_NOTNULL(bay, "The M fixture needs the existing S berth for class rejection")
	var/turf/flight_anchor = get_turf(ship)
	TEST_ASSERT(navigation.select_site(site.id), "The S berth must be selectable")
	TEST_ASSERT(!navigation.dock(instant = TRUE), "An M hull must not enter an S berth")
	TEST_ASSERT_EQUAL(get_turf(ship), flight_anchor, "S berth rejection must leave the M hull in flight")

	var/level = bay.z
	var/anchor_x = max(bay.x + 12, TRANSITIONEDGE + 1)
	var/anchor_y = TRANSITIONEDGE + 1
	TEST_ASSERT(anchor_x + 21 < world.maxx - TRANSITIONEDGE && anchor_y + 24 < world.maxy - TRANSITIONEDGE, "The test map must fit an M installation inside its transition border")
	var/turf/anchor = locate(anchor_x, anchor_y, level)
	var/area/station_area = get_area(locate(bay.x + 9, bay.y, level))
	prepare_vacuum(anchor, locate(anchor_x + 22, anchor_y + 24, level), get_area(bay))
	var/datum/stationtrauma_overmap_sector/space/home/home_sector = prepare_controller_sector(level)
	var/obj/machinery/door/airlock/stationtrauma_docking/wall/last_segment
	for(var/row in anchor_y to anchor_y + 24)
		var/turf/wall_floor = lay_controller_floor(locate(anchor_x + 20, row, level), station_area)
		var/obj/machinery/door/airlock/stationtrauma_docking/wall/segment = allocate(/obj/machinery/door/airlock/stationtrauma_docking/wall, wall_floor)
		segment.setDir(WEST)
		station_objects += segment
		lay_controller_floor(locate(anchor_x + 21, row, level), station_area)
		last_segment = segment
	var/turf/controller_floor = lay_controller_floor(locate(anchor_x + 22, anchor_y, level), station_area)
	first_controller = allocate(/obj/machinery/computer/stationtrauma_dock_controller/medium, controller_floor)
	first_controller.setDir(NORTH)
	// The twenty-fifth section belongs to the M profile and must be mandatory.
	last_segment.setDir(EAST)
	TEST_ASSERT(first_controller.publish_slot(), "A wrong-facing final M wall section must prevent registration")
	TEST_ASSERT_NULL(first_controller.owned_slot, "An incomplete M dock must not leave a native marker")
	last_segment.setDir(WEST)
	var/activation_error = first_controller.publish_slot()
	TEST_ASSERT_NULL(activation_error, "A complete M dock must register")
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/slot = first_controller.owned_slot
	TEST_ASSERT_NOTNULL(slot, "Registration must create a native M slot")
	TEST_ASSERT_EQUAL(get_turf(slot), anchor, "The controller must use the M setback to locate the slot")
	TEST_ASSERT_EQUAL(slot.width, 19, "A runtime M slot must reserve 19 tiles of width")
	TEST_ASSERT_EQUAL(slot.height, 25, "A runtime M slot must reserve 25 tiles of length")
	TEST_ASSERT_EQUAL(slot.dock_class, "M", "The runtime slot must advertise M")
	TEST_ASSERT_EQUAL(slot.accepted_ship_class, "medium", "The runtime slot must accept the medium ship class")

	var/turf/repair_tile = get_turf(last_segment)
	qdel(last_segment)
	var/mob/living/carbon/human/builder = allocate(/mob/living/carbon/human/consistent, get_step(repair_tile, WEST))
	var/obj/item/stationtrauma_docking_kit/wall/repair_kit = allocate(/obj/item/stationtrauma_docking_kit/wall)
	TEST_ASSERT(builder.put_in_active_hand(repair_kit), "The builder must hold the wall kit")
	TEST_ASSERT_EQUAL(repair_kit.interact_with_atom(repair_tile, builder, list()), ITEM_INTERACT_SUCCESS, "The wall kit must mount from the dock side")
	qdel(builder)
	var/obj/machinery/door/airlock/stationtrauma_docking/wall/replacement = locate() in repair_tile
	TEST_ASSERT_NOTNULL(replacement, "Installation must replace the missing wall section")
	station_objects += replacement
	TEST_ASSERT_EQUAL(replacement.dir, WEST, "The repaired M wall must face the slot regardless of where the builder stood")
	var/datum/stationtrauma_overmap_site/space/medium_site = slot.published_site
	TEST_ASSERT_NOTNULL(medium_site, "The M dock must publish a navigation destination")
	var/medium_id = medium_site.id
	TEST_ASSERT_EQUAL(home_sector.sites[medium_id], medium_site, "The M destination must be visible in the home sector")
	navigation.sites -= site.id
	TEST_ASSERT(home_sector.register(ship.shuttle_id, navigation), "The real ship must join the published destination's sector")
	navigation.pos_x = medium_site.pos_x
	navigation.pos_y = medium_site.pos_y
	TEST_ASSERT(navigation.select_site(medium_id), "The runtime M berth must be selectable")
	var/area/hull_area = get_area(flight_anchor)
	var/turf/extension = locate(ship.x + 19, ship.y + 1, ship.z)
	extension = extension.ChangeTurf(/turf/open/floor/plating)
	extension.change_area(get_area(extension), hull_area)
	ship.calculate_docking_port_information()
	TEST_ASSERT_EQUAL(ship.width, 20, "The extended hull must actually be one tile too wide")
	TEST_ASSERT(!slot.accepts(ship), "A medium hull one tile too wide must be rejected")
	extension = extension.ChangeTurf(/turf/open/space, /turf/open/space)
	extension.change_area(get_area(extension), navigation.exterior)
	ship.calculate_docking_port_information()
	TEST_ASSERT_EQUAL(ship.width, 19, "Removing the extension must restore the valid M hull")
	var/obj/machinery/door/airlock/stationtrauma_docking/ship/second_hatch = allocate(/obj/machinery/door/airlock/stationtrauma_docking/ship, locate(ship.x + 18, ship.y + 8, ship.z))
	second_hatch.setDir(EAST)
	var/obj/machinery/door/airlock/stationtrauma_docking/ship/opposite_hatch = allocate(/obj/machinery/door/airlock/stationtrauma_docking/ship, locate(ship.x, ship.y + 5, ship.z))
	opposite_hatch.setDir(WEST)
	station_objects += list(second_hatch, opposite_hatch)
	var/obj/machinery/power/shuttle_engine/engine = allocate(/obj/machinery/power/shuttle_engine, locate(ship.x + 3, ship.y + 8, ship.z))
	engine.anchored = TRUE
	engine.engine_state = initial(engine.engine_state)
	engine.connect_to_shuttle(TRUE, ship)
	TEST_ASSERT(navigation.set_engines_running(TRUE), "The M hull must have real propulsion for the departure check")
	TEST_ASSERT(navigation.dock(instant = TRUE, station_authorized = TRUE), "A full M hull must dock at the registered runtime M berth")
	TEST_ASSERT_EQUAL(ship.dir, NORTH, "The original orientation must preserve both east-facing hatches")
	TEST_ASSERT_EQUAL(get_turf(ship), anchor, "The full M hull must move into the real destination")
	var/obj/docking_port/stationary/stationtrauma_space_site/standard/berth = ship.get_docked()
	TEST_ASSERT(istype(berth) && length(berth.gangways) == 2, "Both compatible hatches must have independent gangways")
	var/turf/first_bridge = locate(anchor_x + 19, anchor_y + 3, level)
	var/turf/second_bridge = locate(anchor_x + 19, anchor_y + 8, level)
	TEST_ASSERT(istype(first_bridge, /turf/open/floor/plating/stationtrauma_dock_gangway), "The first hatch must deploy its real floor")
	TEST_ASSERT(istype(second_bridge, /turf/open/floor/plating/stationtrauma_dock_gangway), "The second hatch must deploy its real floor")
	TEST_ASSERT_NOTNULL(hatch.gangway, "The first hatch must own a gangway")
	TEST_ASSERT_NOTNULL(second_hatch.gangway, "The second hatch must own a gangway")
	TEST_ASSERT_NULL(opposite_hatch.gangway, "The opposite-facing hatch must remain separate")
	var/deadline = world.time + 5 SECONDS
	UNTIL((!hatch.gangway.busy && !second_hatch.gangway.busy) || world.time >= deadline)
	TEST_ASSERT(!hatch.gangway.busy && !second_hatch.gangway.busy, "Both gangways must finish their arrival operations")
	var/obj/machinery/door/airlock/stationtrauma_docking/wall/first_wall = hatch.gangway.wall
	var/obj/machinery/door/airlock/stationtrauma_docking/wall/second_wall = second_hatch.gangway.wall
	if(!pressurize_endpoint(hatch) || !pressurize_endpoint(first_wall) || !pressurize_endpoint(second_hatch) || !pressurize_endpoint(second_wall))
		return
	TEST_ASSERT(hatch.gangway.open_passage() && second_hatch.gangway.open_passage(), "Both pressurized M passages must open")
	TEST_ASSERT(!hatch.density && !first_wall.density && !second_hatch.density && !second_wall.density, "Both M airlock pairs must open physically")
	var/turf/second_doorway = get_turf(second_wall)
	var/obj/item/door_blocker = allocate(/obj/item, second_doorway)
	station_objects += door_blocker
	TEST_ASSERT(!navigation.depart(instant = TRUE), "An item blocking the second doorway must stop the whole departure")
	TEST_ASSERT_EQUAL(get_turf(ship), anchor, "A blocked M departure must leave the hull at the dock")
	TEST_ASSERT(isfloorturf(first_bridge) && isfloorturf(second_bridge), "Neither bridge floor may retract if one doorway cannot close")
	TEST_ASSERT_EQUAL(get_turf(door_blocker), second_doorway, "A failed departure must leave the doorway item untouched")
	qdel(door_blocker)
	deadline = world.time + 5 SECONDS
	UNTIL((!hatch.gangway.busy && !second_hatch.gangway.busy && !hatch.density && !first_wall.density && !second_hatch.density && !second_wall.density) || world.time >= deadline)
	TEST_ASSERT(!hatch.gangway.busy && !second_hatch.gangway.busy && !hatch.density && !first_wall.density && !second_hatch.density && !second_wall.density, "Both passages must reopen after the blocked departure")
	TEST_ASSERT(navigation.depart(instant = TRUE), "The M hull must depart with both gangways attached")
	TEST_ASSERT_EQUAL(get_turf(ship), flight_anchor, "Departure must physically return the M hull to flight")
	TEST_ASSERT(isspaceturf(first_bridge) && isspaceturf(second_bridge), "Departure must retract both gangways to vacuum")
	QDEL_NULL(first_controller)
	TEST_ASSERT_NULL(home_sector.sites[medium_id], "Removing the empty M controller must unpublish its destination")

/// A small hull must move into a larger standard slot and join its wall without resizing.
/datum/unit_test/overmap_standard_dock/small_in_medium/Run()
	TEST_ASSERT_NOTNULL(site, "The real dock fixture must finish setup")
	var/level = bay.z
	var/anchor_x = max(bay.x + 12, TRANSITIONEDGE + 1)
	var/anchor_y = TRANSITIONEDGE + 1
	TEST_ASSERT(anchor_x + 21 < world.maxx - TRANSITIONEDGE && anchor_y + 24 < world.maxy - TRANSITIONEDGE, "The test map must fit the M berth inside its transition border")
	var/turf/anchor = locate(anchor_x, anchor_y, level)
	var/area/station_area = get_area(locate(bay.x + 9, bay.y, level))
	prepare_vacuum(anchor, locate(anchor_x + 21, anchor_y + 24, level), get_area(bay))
	qdel(bay, force = TRUE)
	bay = allocate(/obj/docking_port/stationary/stationtrauma_space_station/standard_m, anchor)
	site.berth = bay
	var/turf/wall_tile = locate(anchor_x + bay.width + 1, anchor_y + hatch_y, level)
	for(var/turf/tile as anything in list(wall_tile, get_step(wall_tile, EAST)))
		tile = tile.ChangeTurf(/turf/open/floor/plating)
		tile.change_area(get_area(tile), station_area)
	var/obj/machinery/door/airlock/stationtrauma_docking/wall/wall = allocate(/obj/machinery/door/airlock/stationtrauma_docking/wall, wall_tile)
	wall.setDir(WEST)
	station_objects += wall
	TEST_ASSERT(navigation.select_site(site.id), "The mapped M berth must be selectable")
	TEST_ASSERT(navigation.dock(instant = TRUE), "A small hull must physically dock at the M berth. Status: [navigation.status]")
	TEST_ASSERT_EQUAL(ship.get_docked(), bay.active_berth, "Native movement must finish at the technical M berth")
	TEST_ASSERT_EQUAL(ship.width, hull_width, "The native berth must keep the small hull's width")
	TEST_ASSERT_EQUAL(hatch.gangway?.wall, wall, "The small hull must deploy a gangway to the M wall")
/// The prepared station M dock must be available when the live sector has finished loading.
/datum/unit_test/overmap_controller_roundstart
	test_flags = UNIT_TEST_MAP_TEST

/datum/unit_test/overmap_controller_roundstart/Run()
	if(SSmapping.current_map.space_overmap?["station_id"] != "cyberiad")
		return
	var/datum/stationtrauma_overmap_sector/space/home = SSstationtrauma_space_voyage.sectors["epsilon_eridani"]
	TEST_ASSERT(home?.ready, "Cyberiad Overmap must start with a ready home sector")
	var/datum/stationtrauma_overmap_site/space/station_site = home.sites["cyberiad"]
	var/obj/docking_port/stationary/stationtrauma_space_station/service_berth = station_site?.berth
	TEST_ASSERT(istype(service_berth), "The station controller must publish the native service berth before guests are placed")
	var/obj/docking_port/stationary/evacuation = SSshuttle.getDock("emergency_home")
	TEST_ASSERT_NOTNULL(evacuation, "The native evacuation port must remain present")
	TEST_ASSERT_EQUAL(get_turf(service_berth), get_turf(evacuation), "The service and evacuation berths must still share the same anchor")
	TEST_ASSERT(service_berth.width == 21 && service_berth.height == 32 && service_berth.dir == NORTH && service_berth.dwidth == 0 && service_berth.dheight == 16, "The service berth must preserve the original native docking geometry")
	var/datum/stationtrauma_overmap_site/space/site = home.sites["cyberiad_m_dock"]
	TEST_ASSERT_NOTNULL(site, "Cyberiad's prepared M dock must be available immediately after startup")
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/berth = site.berth
	TEST_ASSERT(istype(berth), "The destination must be a controller-owned native berth")
	var/obj/machinery/computer/stationtrauma_dock_controller/medium/controller = berth.controller_ref?.resolve()
	TEST_ASSERT(istype(controller) && controller.owned_slot == berth, "The mapped controller must own the only berth")
	TEST_ASSERT_EQUAL(berth.x, 49, "The M berth must keep its existing X coordinate")
	TEST_ASSERT_EQUAL(berth.y, 99, "The M berth must keep its existing Y coordinate")
	var/datum/stationtrauma_overmap_site/space/industrial = home.sites["trade_industrial_m"]
	TEST_ASSERT_NOTNULL(industrial, "The converted trade controller must publish the previous berth ID")
	TEST_ASSERT(industrial.docking_target?.automatic, "The trade outpost must still handle docking requests automatically")
	TEST_ASSERT_EQUAL(industrial.pos_x, -1300, "The trade outpost must retain its chart position")
	TEST_ASSERT(berth.controller_valid(), "The mapped station controller must be ready for arrivals")
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/trade_berth = industrial.berth
	TEST_ASSERT(istype(trade_berth) && trade_berth.controller_valid(), "The converted trade controller must accept arrivals with real power")
	if(SSmapping.current_map.map_name == "Cyberiad Overmap + Trurl")
		var/datum/stationtrauma_overmap_site/space/carrier_site = home.sites["trurl_m1"]
		var/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/carrier_berth = carrier_site?.berth
		TEST_ASSERT(istype(carrier_berth) && carrier_berth.controller_valid(), "Trurl's converted controller must operate on its own deck")
		TEST_ASSERT_EQUAL(carrier_site.host?.vessel.shuttle_id, "overmap_trurl", "The mapped controller must belong to its carrier")
