/** Two real hulls, airlocks and sector registrations on existing levels for voluntary docking regressions. */
/datum/unit_test/overmap_docking/ship_pair
	abstract_type = /datum/unit_test/overmap_docking/ship_pair
	/// Peer hull on the existing unit-test level.
	var/obj/docking_port/mobile/stationtrauma_space/unit_test_docking/host_ship
	/// Navigation of the peer hull; fast processing stays disabled in this fixture.
	var/datum/stationtrauma_overmap/space/host_navigation
	/// Shared real sector registry used by the voluntary docking checks.
	var/datum/stationtrauma_overmap_sector/space/ship_sector
	/// Borrowed turf -> original type, baseturfs, area, flags and space destinations.
	var/list/borrowed_turfs = list()

/datum/unit_test/overmap_docking/ship_pair/Destroy()
	UnregisterSignal(ship, COMSIG_ATOM_AFTER_SHUTTLE_MOVE)
	// Delete navigation first so teardown cannot start another asynchronous hull return.
	qdel(navigation)
	qdel(ship, force = TRUE)
	qdel(host_navigation)
	qdel(host_ship, force = TRUE)
	qdel(ship_sector)
	host_navigation = null
	host_ship = null
	ship_sector = null
	for(var/turf/tile as anything in borrowed_turfs)
		var/list/original = borrowed_turfs[tile]
		tile = tile.ChangeTurf(original[1], original[2])
		tile.change_area(get_area(tile), original[3])
		tile.turf_flags = original[4]
		if(isopenturf(tile))
			var/turf/open/open_tile = tile
			open_tile.destination_x = original[5]
			open_tile.destination_y = original[6]
			open_tile.destination_z = original[7]
	borrowed_turfs.Cut()
	return ..()

/datum/unit_test/overmap_docking/ship_pair/New()
	..()
	var/host_z = run_loc_floor_bottom_left.z
	TEST_ASSERT_NOTEQUAL(ship.z, host_z, "The two hulls must start on separate physical levels")
	var/host_x = run_loc_floor_bottom_left.x + 12
	var/host_y = run_loc_floor_bottom_left.y + 12
	var/area/space/stationtrauma_space_home/host_exterior = new /area/space/stationtrauma_space_home/unit_test_docking
	var/area/shuttle/stationtrauma_space/host_area = new /area/shuttle/stationtrauma_space/unit_test_docking
	allocated += host_exterior
	allocated += host_area
	// This patch lies outside the unit-test room, on its already allocated level.
	for(var/turf/tile as anything in block(locate(host_x - 4, host_y - 4, host_z), locate(host_x + 5, host_y + 6, host_z)))
		var/turf/open/open_tile = isopenturf(tile) ? tile : null
		borrowed_turfs[tile] = list(tile.type, islist(tile.baseturfs) ? tile.baseturfs.Copy() : tile.baseturfs, get_area(tile), tile.turf_flags, open_tile?.destination_x, open_tile?.destination_y, open_tile?.destination_z)
		tile = tile.ChangeTurf(/turf/open/space)
		tile.change_area(get_area(tile), host_exterior)
		open_tile = tile
		open_tile.destination_x = 0
		open_tile.destination_y = 0
		open_tile.destination_z = 0
	for(var/turf/tile as anything in block(locate(host_x, host_y, host_z), locate(host_x + 1, host_y + 2, host_z)))
		tile = tile.ChangeTurf(/turf/open/floor/plating)
		tile.change_area(get_area(tile), host_area)
	host_ship = allocate(/obj/docking_port/mobile/stationtrauma_space/unit_test_docking, locate(host_x, host_y, host_z), list(host_area))
	host_ship.register()
	for(var/turf/tile as anything in host_ship.return_turfs())
		host_ship.underlying_areas_by_turf[tile] = host_exterior
	host_navigation = allocate(/datum/stationtrauma_overmap/space, host_ship)
	host_ship.overmap = host_navigation
	STOP_PROCESSING(SSfastprocess, host_navigation)
	host_navigation.exterior = host_exterior
	host_navigation.preparing = FALSE
	// Opposing outer airlocks give the real placement search a flush pairing.
	allocate(/obj/machinery/door/airlock, locate(ship.x + 1, ship.y + 1, ship.z))
	allocate(/obj/machinery/door/airlock, locate(host_x, host_y + 1, host_z))
	navigation.sites.Cut()
	navigation.selected_destination = null
	navigation.prepared_site = null
	ship_sector = allocate(/datum/stationtrauma_overmap_sector/space)
	TEST_ASSERT(ship_sector.register(ship.shuttle_id, navigation), "The guest must join the real sector registry")
	TEST_ASSERT(ship_sector.register(host_ship.shuttle_id, host_navigation), "The host must join the same sector registry")
	TEST_ASSERT(navigation.set_engines_running(TRUE), "The guest's real engine must start before docking")
	TEST_ASSERT(navigation.can_join_ship(host_navigation), "The real voluntary docking checks must accept the two free hulls")

/** A committed hatch-to-hatch arrival must retain both hulls when the engines stop during native movement. */
/datum/unit_test/overmap_docking/committed_ship_docking
	parent_type = /datum/unit_test/overmap_docking/ship_pair
	/// Ordinary item left in the vacated flight footprint during the native move.
	var/obj/item/flight_blocker
	/// Whether the shutdown executed inside the real native move.
	var/interrupted = FALSE

/datum/unit_test/overmap_docking/committed_ship_docking/Destroy()
	flight_blocker = null
	return ..()

/datum/unit_test/overmap_docking/committed_ship_docking/Run()
	var/host_z = host_ship.z
	RegisterSignal(ship, COMSIG_ATOM_AFTER_SHUTTLE_MOVE, PROC_REF(stop_after_native_move))
	var/datum/stationtrauma_ship_docking/link = allocate(/datum/stationtrauma_ship_docking, navigation, host_navigation)
	var/result = link.connect()
	TEST_ASSERT(interrupted, "The shutdown must occur during actual native movement")
	TEST_ASSERT(!ship.engines_running, "The newer engine shutdown must remain effective")
	TEST_ASSERT_EQUAL(ship.z, host_z, "The guest must physically reach the host's level before completion is checked")
	TEST_ASSERT(!QDELETED(flight_blocker) && get_turf(flight_blocker) == get_turf(navigation.flight_berth), "The flight footprint blocker must remain intact and unmoved")
	TEST_ASSERT(result && !QDELETED(link), "A committed flush arrival must retain its pair despite the newer engine shutdown")
	TEST_ASSERT(link.flush && ship.get_docked() == link.anchor, "The retained pair must describe the actual committed native dock")
	TEST_ASSERT_EQUAL(navigation.ship_docking, link, "The guest must retain its occupied docking link")
	TEST_ASSERT_EQUAL(host_navigation.ship_docking, link, "The host must retain the same occupied docking link")
	TEST_ASSERT(!navigation.preparing && !host_navigation.preparing, "A completed arrival must release both preparation locks")
	qdel(flight_blocker)
	flight_blocker = null
	TEST_ASSERT(navigation.set_engines_running(TRUE), "The stopped engine must be restartable after arrival")
	TEST_ASSERT(link.release(navigation, instant = TRUE), "The retained pair must still support normal native departure once its home is clear")
	TEST_ASSERT_EQUAL(ship.get_docked(), navigation.flight_berth, "Departure must physically return the guest to its flight berth")
	TEST_ASSERT_NULL(navigation.ship_docking, "Departure must release the guest's docking link")
	TEST_ASSERT_NULL(host_navigation.ship_docking, "Departure must release the host's docking link")

/** Reproduce an engineer's shutdown and an EVA item entering the footprint after the hull physically moved. */
/datum/unit_test/overmap_docking/committed_ship_docking/proc/stop_after_native_move(obj/docking_port/mobile/source, turf/old_tile)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_ATOM_AFTER_SHUTTLE_MOVE)
	interrupted = navigation.relocating && navigation.set_engines_running(FALSE)
	flight_blocker = allocate(/obj/item, old_tile)

/** The twenty-second release spools up while moored, then opens real distance with the helm still locked. */
/datum/unit_test/overmap_docking/ship_release_flight
	parent_type = /datum/unit_test/overmap_docking/ship_pair
	/// Whether the real asynchronous departure has returned.
	var/finished = FALSE
	/// Whether the whole departure completed successfully.
	var/departed = FALSE

/datum/unit_test/overmap_docking/ship_release_flight/Run()
	var/datum/stationtrauma_ship_docking/link = allocate(/datum/stationtrauma_ship_docking, navigation, host_navigation)
	TEST_ASSERT(link.connect() && link.flush, "The fixture must form a real hatch-to-hatch pair")
	var/obj/machinery/computer/stationtrauma_space_navigation/console = allocate(/obj/machinery/computer/stationtrauma_space_navigation, get_turf(ship))
	console.vessel = ship
	var/started = world.time
	INVOKE_ASYNC(src, PROC_REF(cast_off))
	sleep(1 SECONDS)
	var/early_thrust = navigation.commanded_thrust()
	var/still_moored = ship.get_docked() == link.anchor && hull_area.parallax_movedir == NONE
	sleep(2 SECONDS)
	var/thrust_increased = navigation.commanded_thrust() > early_thrust && early_thrust > 0
	var/deadline = started + 12 SECONDS
	UNTIL(ship.get_docked() == navigation.flight_berth || finished || world.time >= deadline)
	var/in_flight = !finished && navigation.preparing && navigation.approach_departing && ship.get_docked() == navigation.flight_berth
	var/list/data = console.ui_data(null)
	var/flight_x = navigation.pos_x
	var/flight_y = navigation.pos_y
	sleep(2 SECONDS)
	var/opening_distance = navigation.pos_x != flight_x || navigation.pos_y != flight_y
	var/moving_parallax = hull_area.parallax_movedir == ship.preferred_direction
	deadline = started + 30 SECONDS
	UNTIL(finished || world.time >= deadline)
	TEST_ASSERT(finished && departed, "The complete release must finish normally")
	TEST_ASSERT(still_moored && thrust_increased, "Engine demand must rise while the physically coupled hull and its parallax remain still")
	TEST_ASSERT(in_flight && opening_distance && moving_parallax, "Physical release must precede the remaining automatic outward flight")
	TEST_ASSERT_EQUAL(data["approach"]?["duration"], 20, "The paired ship's pilot must see the complete twenty-second manoeuvre")
	TEST_ASSERT_EQUAL(data["approach"]?["site"], host_ship.name, "The departure display must identify the peer after physical separation")
	TEST_ASSERT(world.time - started >= 20 SECONDS, "Early physical release must not shorten the complete departure")
	TEST_ASSERT_NULL(navigation.ship_docking, "Completion must clear the departing hull's pair")
	TEST_ASSERT_NULL(host_navigation.ship_docking, "Completion must clear the peer's pair")
	TEST_ASSERT(!navigation.preparing && !navigation.approach_started, "Completion must unlock the helm")

/** Exercise the player departure path, including the shared link's timed release and final helm handover. */
/datum/unit_test/overmap_docking/ship_release_flight/proc/cast_off()
	departed = navigation.depart()
	finished = TRUE

/** Declining or superseding a docking request cannot bypass the sender's notification cooldown. */
/datum/unit_test/overmap_docking/ship_request_cooldown
	parent_type = /datum/unit_test/overmap_docking/ship_pair

/datum/unit_test/overmap_docking/ship_request_cooldown/Run()
	navigation.record_ship_observation(host_ship.shuttle_id, host_navigation, "signal")
	var/list/contact = navigation.ship_observations[host_ship.shuttle_id]
	TEST_ASSERT_NOTNULL(contact, "A real sensor observation must supply the crew-local recipient number")
	var/obj/machinery/computer/stationtrauma_space_navigation/console = allocate(/obj/machinery/computer/stationtrauma_space_navigation, get_turf(ship))
	console.vessel = ship
	TEST_ASSERT(console.navigation_command("ship_dock", contact["id"]), "The sender's first real docking request must be accepted")
	var/token = host_navigation.docking_request_sequence
	TEST_ASSERT(host_navigation.respond_ship_docking(token, FALSE), "The recipient must decline the actual pending request")
	TEST_ASSERT(!console.navigation_command("ship_dock", contact["id"]), "Declining a request must not permit an immediate notification repeat")
	TEST_ASSERT_EQUAL(host_navigation.docking_request_sequence, token, "A cooldown rejection must not publish another recipient token")
	TEST_ASSERT(console.navigation_command("turn", 15), "The sender must be able to change its helm revision")
	TEST_ASSERT(!console.navigation_command("ship_dock", contact["id"]), "A manual turn must not reset the sender's docking request cooldown")
	TEST_ASSERT_EQUAL(host_navigation.docking_request_sequence, token, "A turn followed by a rejected request must leave the token unchanged")
	// The elapsed interval is the notification rate contract, not an arbitrary scheduling delay.
	sleep(30 SECONDS)
	TEST_ASSERT(console.navigation_command("ship_dock", contact["id"]), "One new docking request must be permitted after the full cooldown")
	TEST_ASSERT_EQUAL(host_navigation.docking_request_sequence, token + 1, "The allowed request must publish exactly one new response token")
	TEST_ASSERT(host_navigation.respond_ship_docking(token + 1, FALSE), "The new real request must remain answerable")
	TEST_ASSERT(!console.navigation_command("ship_dock", contact["id"]), "The allowed request must start the next cooldown")
	TEST_ASSERT_EQUAL(host_navigation.docking_request_sequence, token + 1, "A second immediate repeat must not publish another token")
