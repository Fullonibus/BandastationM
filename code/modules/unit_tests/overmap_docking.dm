/// Pause the real native preflight at a deterministic point; retain all movement and occupancy checks.
/obj/docking_port/mobile/stationtrauma_space/unit_test_docking
	width = 2
	height = 3
	/// One-shot callback run inside the real native preflight, after its yield.
	var/datum/callback/preflight_action
	/// The ascent had already started when native cleanup first gained a chance to yield.
	var/launched_before_cleanup = FALSE

/obj/docking_port/mobile/stationtrauma_space/unit_test_docking/cleanup_runway(obj/docking_port/stationary/new_dock, list/old_turfs, list/new_turfs, list/areas_to_move, list/underlying_areas, list/moved_atoms, rotation, movement_direction, area/fallback_area, list/shuttle_depths)
	if(overmap?.planet_flight?.departing)
		launched_before_cleanup = !!overmap.planet_ascent?.liftoff
	return ..()

/obj/docking_port/mobile/stationtrauma_space/unit_test_docking/preflight_check(list/old_turfs, list/new_turfs, list/areas_to_move, list/underlying_areas, rotation)
	. = ..()
	if(. || !preflight_action)
		return
	var/datum/callback/action = preflight_action
	preflight_action = null
	sleep(0)
	action.Invoke()

/obj/docking_port/mobile/stationtrauma_space/unit_test_docking/Destroy(force)
	preflight_action = null
	return ..()

/// A small real shuttle and two physical berths, without loading a map template.
/area/space/stationtrauma_space_home/unit_test_docking
	area_flags_mapping = NONE

/// Hull area of the fixture shuttle.
/area/shuttle/stationtrauma_space/unit_test_docking
	area_flags_mapping = NONE

/// Shared fixture: a two-by-three shuttle with a real engine, a station bay and a docking site in reserved space.
/datum/unit_test/overmap_docking
	abstract_type = /datum/unit_test/overmap_docking
	/// Reserved space holding the fixture; released in Destroy().
	var/datum/turf_reservation/space
	/// The fixture shuttle.
	var/obj/docking_port/mobile/stationtrauma_space/unit_test_docking/ship
	/// Shared station bay the ship docks at.
	var/obj/docking_port/stationary/stationtrauma_space_station/bay
	/// Native evacuation home port on the same turf as the bay.
	var/obj/docking_port/stationary/home
	/// Overmap navigation of the fixture ship; its processing is stopped for determinism.
	var/datum/stationtrauma_overmap/space/navigation
	/// Docking site backed by the bay.
	var/datum/stationtrauma_overmap_site/space/site
	/// Flight-level exterior area covering the reservation.
	var/area/space/stationtrauma_space_home/exterior
	/// Area of the fixture hull tiles.
	var/area/shuttle/stationtrauma_space/hull_area
	/// Native stationary port ID counters, restored after the test.
	var/list/stationary_ids
	/// Native mobile port ID counters, restored after the test.
	var/list/mobile_ids
	/// Reserved turf -> its area before the fixture took it over.
	var/list/original_areas = list()

/datum/unit_test/overmap_docking/New()
	..()
	stationary_ids = SSshuttle.assoc_stationary.Copy()
	mobile_ids = SSshuttle.assoc_mobile.Copy()
	space = SSmapping.request_turf_block_reservation(18, 10)
	exterior = new /area/space/stationtrauma_space_home/unit_test_docking
	hull_area = new /area/shuttle/stationtrauma_space/unit_test_docking
	allocated += exterior
	allocated += hull_area
	for(var/turf/tile as anything in space.reserved_turfs)
		original_areas[tile] = get_area(tile)
		tile.change_area(get_area(tile), exterior)
	var/turf/corner = space.bottom_left_turfs[1]
	var/turf/anchor = locate(corner.x + 2, corner.y + 2, corner.z)
	for(var/turf/tile as anything in block(anchor, locate(anchor.x + 1, anchor.y + 2, anchor.z)))
		tile = tile.ChangeTurf(/turf/open/floor/plating)
		tile.change_area(get_area(tile), hull_area)
	anchor = locate(corner.x + 2, corner.y + 2, corner.z)
	ship = allocate(/obj/docking_port/mobile/stationtrauma_space/unit_test_docking, anchor, list(hull_area))
	ship.register()
	for(var/turf/tile as anything in ship.return_ordered_turfs(ship.x, ship.y, ship.z, ship.dir))
		TEST_ASSERT_EQUAL(get_area(tile), hull_area, "Every fixture hull tile must belong to the shuttle area")
		ship.underlying_areas_by_turf[tile] = exterior
	var/obj/machinery/power/shuttle_engine/engine = allocate(/obj/machinery/power/shuttle_engine, anchor)
	engine.anchored = TRUE
	engine.engine_state = initial(engine.engine_state)
	engine.connect_to_shuttle(TRUE, ship)
	navigation = allocate(/datum/stationtrauma_overmap/space, ship)
	ship.overmap = navigation
	STOP_PROCESSING(SSfastprocess, navigation)
	navigation.exterior = exterior
	navigation.preparing = FALSE
	var/turf/destination = locate(corner.x + 11, corner.y + 5, corner.z)
	bay = allocate(/obj/docking_port/stationary/stationtrauma_space_station, destination)
	bay.width = ship.width
	bay.height = ship.height
	bay.setDir(EAST)
	home = allocate(/obj/docking_port/stationary, destination)
	site = allocate(/datum/stationtrauma_overmap_site/space)
	site.id = "unit_test_dock"
	site.name = "Unit test bay"
	site.physical_docking = TRUE
	site.berth = bay
	site.pos_x = navigation.pos_x
	site.pos_y = navigation.pos_y
	navigation.sites[site.id] = site
	navigation.selected_destination = site.id
	navigation.prepared_site = site

/datum/unit_test/overmap_docking/Destroy()
	qdel(navigation)
	qdel(ship, force = TRUE)
	qdel(bay, force = TRUE)
	qdel(home, force = TRUE)
	// Native registration keeps counters after ports are deleted.
	SSshuttle.assoc_stationary = stationary_ids
	SSshuttle.assoc_mobile = mobile_ids
	stationary_ids = null
	mobile_ids = null
	navigation = null
	ship = null
	bay = null
	home = null
	site = null
	for(var/turf/tile as anything in original_areas)
		tile.change_area(get_area(tile), original_areas[tile])
	original_areas.Cut()
	qdel(space)
	space = null
	return ..()

/// An S/M hull moors at a free corner pad of a ruin through the ordinary docking order, leaving the ruin itself free.
/datum/unit_test/overmap_docking/ruin_pads
	/// The two corner pad slots, cleared before the fixture deletes the hull.
	var/list/slots = list()

/datum/unit_test/overmap_docking/ruin_pads/Destroy()
	for(var/obj/docking_port/stationary/stationtrauma_space_station/standard/ruin_pad/slot as anything in slots)
		slot.clear_berth()
	slots.Cut()
	return ..()

/datum/unit_test/overmap_docking/ruin_pads/Run()
	var/turf/corner = space.bottom_left_turfs[1]
	var/datum/stationtrauma_overmap_site/space/ruin = allocate(/datum/stationtrauma_overmap_site/space)
	ruin.id = "unit_test_ruin"
	ruin.name = "Unit test ruin"
	ruin.pos_x = navigation.pos_x
	ruin.pos_y = navigation.pos_y
	navigation.sites[ruin.id] = ruin
	for(var/index in 1 to 2)
		var/datum/stationtrauma_overmap_site/space/pad = allocate(/datum/stationtrauma_overmap_site/space)
		pad.id = "[ruin.id]:pad[index]"
		pad.name = ruin.name
		pad.discovered = TRUE
		pad.physical_docking = TRUE
		pad.pad_parent = ruin
		LAZYADD(ruin.pads, pad)
		navigation.sites[pad.id] = pad
		// The fixture hull is tiny, so the pads shrink to fit the reservation while staying open space.
		var/obj/docking_port/stationary/stationtrauma_space_station/standard/ruin_pad/slot = allocate(/obj/docking_port/stationary/stationtrauma_space_station/standard/ruin_pad, locate(corner.x + 2 + index * 4, corner.y + 1, corner.z))
		slot.width = 3
		slot.height = 4
		slots += slot
		pad.berth = slot
	var/datum/stationtrauma_overmap_site/space/taken = ruin.pads[1]
	var/datum/stationtrauma_overmap_site/space/free = ruin.pads[2]
	// Another hull already holds the first pad.
	taken.docking_owner = allocate(/datum)
	navigation.selected_destination = ruin.id
	navigation.prepared_site = ruin
	TEST_ASSERT_EQUAL(navigation.selected_docking_site(), free, "The ruin must offer its free corner pad, not the taken one or the seam")
	TEST_ASSERT(navigation.dock(instant = TRUE), "An S/M hull must moor at the ruin's free corner pad")
	TEST_ASSERT_EQUAL(navigation.docked, free, "The hull must be docked at the pad it took")
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/ruin_pad/free_slot = free.berth
	TEST_ASSERT(free_slot.active_berth && ship.get_docked() == free_slot.active_berth, "The hull must physically stand on the pad")
	TEST_ASSERT_NULL(ruin.docking_owner, "Mooring at a pad must leave the ruin free for another hull")
	var/obj/machinery/computer/stationtrauma_space_navigation/console = allocate(/obj/machinery/computer/stationtrauma_space_navigation, get_turf(ship))
	console.vessel = ship
	TEST_ASSERT_EQUAL(console.ui_data(null)["docked"], ruin.id, "The helm must read a pad mooring as docked at the ruin")
	taken.docking_owner = null

/// An emergency engine stop during native relocation keeps the committed arrival and blocks racing helm orders.
/datum/unit_test/overmap_docking/engine_stop
	/// Set once the stop ran inside preflight.
	var/interrupted = FALSE
	/// Helm revision right after the stop; arrival must not advance it.
	var/revision_after_stop

/datum/unit_test/overmap_docking/engine_stop/Run()
	TEST_ASSERT(navigation.set_engines_running(TRUE), "The real engine must start before docking")
	ship.preflight_action = CALLBACK(src, PROC_REF(stop_during_preflight))
	var/result = navigation.dock(instant = TRUE)
	TEST_ASSERT(interrupted, "The stop action must execute while native relocation is suspended")
	TEST_ASSERT(!ship.engines_running, "Emergency engine shutdown must remain effective during relocation")
	TEST_ASSERT_EQUAL(ship.get_docked(), bay, "Native docking must actually move the hull into the bay")
	TEST_ASSERT_EQUAL(navigation.docked, site, "A committed physical arrival must retain its dock state despite a newer helm revision")
	TEST_ASSERT_EQUAL(site.docking_owner, navigation, "The physically occupied site must remain owned")
	TEST_ASSERT(result, "Committed docking must report success")
	TEST_ASSERT_EQUAL(navigation.control_revision, revision_after_stop, "Arrival must not overwrite the stop action with another helm order")
	TEST_ASSERT(navigation.set_engines_running(TRUE), "The engine must be restartable after docking")
	TEST_ASSERT(navigation.depart(instant = TRUE), "Departure after the interrupted arrival must remain possible")
	TEST_ASSERT_EQUAL(ship.get_docked(), navigation.flight_berth, "Departure must physically return the hull to flight space")
	TEST_ASSERT_NULL(navigation.docked, "Departure must clear the virtual dock")
	TEST_ASSERT_NULL(site.docking_owner, "Departure must release site ownership")

/** Stop the engines and try racing orders while native relocation is suspended. */
/datum/unit_test/overmap_docking/engine_stop/proc/stop_during_preflight()
	TEST_ASSERT(navigation.relocating && navigation.preparing, "The callback must run within native docking")
	interrupted = TRUE
	TEST_ASSERT(navigation.set_engines_running(FALSE), "Emergency stop must be accepted during native docking")
	revision_after_stop = navigation.control_revision
	TEST_ASSERT(!navigation.dock(), "A repeated dock request cannot start another relocation")
	TEST_ASSERT(!navigation.sail(), "Departure cannot race an unfinished native relocation")
	TEST_ASSERT(!navigation.select_site("missing"), "Selection cannot change during native relocation")

/// A berth occupied during the yielding preflight rejects the arrival without moving the occupant.
/datum/unit_test/overmap_docking/blocked_preflight
	/// Item dropped on the bay during preflight.
	var/obj/item/blocker

/datum/unit_test/overmap_docking/blocked_preflight/Run()
	ship.preflight_action = CALLBACK(src, PROC_REF(block_during_preflight))
	var/result = navigation.dock(instant = TRUE)
	TEST_ASSERT_NOTNULL(blocker, "The blocking action must execute during real native preflight")
	TEST_ASSERT(!result, "A destination occupied during yielding preflight must reject the arrival")
	TEST_ASSERT_EQUAL(ship.get_docked(), navigation.flight_berth, "Rejected arrival must leave the physical hull at its old berth")
	TEST_ASSERT_NULL(navigation.docked, "Rejected arrival cannot publish a dock")
	TEST_ASSERT_NULL(site.docking_owner, "Rejected arrival must release its reservation")
	TEST_ASSERT_EQUAL(get_turf(blocker), get_turf(bay), "The late blocker must not be moved or crushed")

/** Occupy the bay while native preflight is suspended. */
/datum/unit_test/overmap_docking/blocked_preflight/proc/block_during_preflight()
	blocker = allocate(/obj/item, get_turf(bay))

/// A real landing orders engine thrust and aborts in flight space if the engines stop before touchdown.
/datum/unit_test/overmap_docking/powered_landing
	/// Whether the asynchronous docking call has returned.
	var/finished = FALSE
	/// Result of the real docking call.
	var/landed = FALSE

/datum/unit_test/overmap_docking/powered_landing/Run()
	site.landing = TRUE
	TEST_ASSERT(!navigation.can_dock(site, navigation.control_revision), "Landing must require running engines")
	TEST_ASSERT(navigation.set_engines_running(TRUE), "The landing fixture needs its real engine")
	INVOKE_ASYNC(src, PROC_REF(land))
	var/deadline = world.time + 5 SECONDS
	UNTIL(navigation.approach_started || finished || world.time >= deadline)
	var/thrust = navigation.commanded_thrust()
	var/obj/machinery/computer/stationtrauma_space_navigation/console = allocate(/obj/machinery/computer/stationtrauma_space_navigation, get_turf(ship))
	console.vessel = ship
	var/list/data = console.ui_data(null)
	navigation.set_engines_running(FALSE)
	deadline = world.time + 5 SECONDS
	UNTIL(finished || world.time >= deadline)
	TEST_ASSERT(finished, "Engine failure must end the landing without waiting for the full descent")
	TEST_ASSERT_EQUAL(thrust, 1, "The automatic descent must demand full thrust despite an idle manual lever")
	TEST_ASSERT_EQUAL(data["throttle"], 100, "The pilot must see the automatic descent thrust")
	TEST_ASSERT(!landed, "A landing without thrust must not commit")
	TEST_ASSERT_EQUAL(ship.get_docked(), navigation.flight_berth, "An interrupted descent must leave the hull in flight space")
	TEST_ASSERT_NULL(site.docking_owner, "An interrupted descent must release its surface reservation")
	TEST_ASSERT_EQUAL(navigation.commanded_thrust(), 0, "Cancelled automatic thrust must not remain latched")

/** Exercise the real asynchronous landing, including its waiting and final revalidation. */
/datum/unit_test/overmap_docking/powered_landing/proc/land()
	landed = navigation.dock()
	finished = TRUE

/// Shared timed departure check: the hull must leave early while automatic flight still locks the helm.
/datum/unit_test/overmap_docking/early_departure
	abstract_type = /datum/unit_test/overmap_docking/early_departure
	/// Whether this departure is an ascent from a planetary surface.
	var/planetary = FALSE
	/// Whether the asynchronous departure call has returned.
	var/finished = FALSE
	/// Result of the real departure call.
	var/departed = FALSE

/datum/unit_test/overmap_docking/early_departure/Run()
	site.landing = planetary
	TEST_ASSERT(navigation.set_engines_running(TRUE), "The departure fixture needs its real engine")
	TEST_ASSERT(navigation.dock(instant = TRUE), "Place the hull at its real starting berth")
	INVOKE_ASYNC(src, PROC_REF(depart))
	TEST_ASSERT_EQUAL(hull_area.parallax_movedir, NONE, "Spooling up at the old berth must keep the parallax still")
	var/deadline = world.time + 12 SECONDS
	UNTIL(isnull(navigation.docked) || finished || world.time >= deadline)
	var/left_early = isnull(navigation.docked) && ship.get_docked() == navigation.flight_berth
	var/in_flight = left_early && navigation.approach_started && !finished
	var/thrust = navigation.commanded_thrust()
	var/locked = navigation.preparing && !navigation.sail()
	var/moving_parallax = hull_area.parallax_movedir == ship.preferred_direction
	var/departure_x = navigation.pos_x
	var/departure_y = navigation.pos_y
	var/duration = navigation.approach_duration
	sleep(2 SECONDS)
	var/opening_distance = navigation.pos_x != departure_x || navigation.pos_y != departure_y
	if(planetary || !left_early)
		navigation.set_engines_running(FALSE)
	deadline = world.time + 25 SECONDS
	UNTIL(finished || world.time >= deadline)
	TEST_ASSERT(finished, "The departure coroutine must finish or safely abort")
	TEST_ASSERT(left_early, "The native hull must already be in flight space before the departure timer ends")
	TEST_ASSERT(in_flight && locked, "Automatic flight must continue after the berth is freed, without allowing racing helm orders")
	TEST_ASSERT_EQUAL(thrust, planetary ? 1 : 0.5, "Automatic thrust must continue after docked is cleared")
	TEST_ASSERT_EQUAL(duration, planetary ? 1 MINUTES : 20 SECONDS, "The full manoeuvre must retain its agreed duration")
	TEST_ASSERT(opening_distance, "The ship must physically open overmap distance while the remaining departure still locks the helm")
	TEST_ASSERT(moving_parallax, "Only the released hull's flight phase starts the moving parallax")
	TEST_ASSERT_NULL(navigation.docked, "The old virtual dock must stay released")
	TEST_ASSERT_NULL(site.docking_owner, "Another ship must be able to reserve the freed berth")
	TEST_ASSERT_EQUAL(ship.get_docked(), navigation.flight_berth, "Neither completion nor engine failure may return the hull to the old berth")
	TEST_ASSERT(!navigation.approach_started && !navigation.preparing, "Completion must release the manoeuvre lock")
	TEST_ASSERT_EQUAL(departed, !planetary, "The powered departure completes; the ascent interrupted in space does not")

/** Run the normal departure rather than bypassing the timing with the admin instant path. */
/datum/unit_test/overmap_docking/early_departure/proc/depart()
	departed = navigation.depart()
	finished = TRUE

/// A station departure completes its remaining manoeuvre in flight space before engaging the helm.
/datum/unit_test/overmap_docking/early_departure/station

/// Losing engines after takeoff leaves the hull in space and safely cancels the remaining climb.
/datum/unit_test/overmap_docking/early_departure/planet
	planetary = TRUE

/// A newer stop after native departure commits must not be overwritten by automatic outward flight.
/datum/unit_test/overmap_docking/stop_after_departure_move
	/// Whether the stop executed inside the real native movement.
	var/interrupted = FALSE

/datum/unit_test/overmap_docking/stop_after_departure_move/Destroy()
	UnregisterSignal(ship, COMSIG_ATOM_AFTER_SHUTTLE_MOVE)
	return ..()

/datum/unit_test/overmap_docking/stop_after_departure_move/Run()
	TEST_ASSERT(navigation.set_engines_running(TRUE), "The departure fixture needs its real engine")
	TEST_ASSERT(navigation.dock(instant = TRUE), "The fixture must first be physically moored")
	var/origin_x = navigation.pos_x
	var/origin_y = navigation.pos_y
	RegisterSignal(ship, COMSIG_ATOM_AFTER_SHUTTLE_MOVE, PROC_REF(stop_after_move))
	TEST_ASSERT(!navigation.depart(), "A newer stop must cancel automatic flight after the committed native release")
	TEST_ASSERT(interrupted, "The stop must run during real relocation")
	TEST_ASSERT_EQUAL(ship.get_docked(), navigation.flight_berth, "The stop must retain the already committed physical departure")
	TEST_ASSERT_NULL(navigation.docked, "The physically vacated berth must stay released")
	TEST_ASSERT(!navigation.helm_engaged && !navigation.preparing && !navigation.approach_started, "Automatic flight must not relaunch a stopped hull")
	TEST_ASSERT_EQUAL(navigation.pos_x, origin_x, "The old departure must not move the stopped hull east or west")
	TEST_ASSERT_EQUAL(navigation.pos_y, origin_y, "The old departure must not move the stopped hull north or south")
	TEST_ASSERT_EQUAL(hull_area.parallax_movedir, NONE, "The stopped hull must retain stationary parallax")

/** Stop with the engines still lit, after relocation committed but before the old departure starts flight. */
/datum/unit_test/overmap_docking/stop_after_departure_move/proc/stop_after_move(obj/docking_port/mobile/source, turf/old_tile)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_ATOM_AFTER_SHUTTLE_MOVE)
	interrupted = navigation.relocating
	navigation.stop("Departure interrupted by the engineer")

/// Evacuation frees the shared bay even when the old flight footprint is occupied, harming nobody left outside.
/datum/unit_test/overmap_docking/evacuation

/datum/unit_test/overmap_docking/evacuation/Run()
	TEST_ASSERT(navigation.dock(instant = TRUE), "The expedition ship must first physically dock at the shared bay")
	var/turf/old_flight_anchor = get_turf(navigation.flight_berth)
	var/obj/item/blocker = allocate(/obj/item, old_flight_anchor)
	var/mob/living/carbon/human/consistent/eva = allocate(/mob/living/carbon/human/consistent, old_flight_anchor)
	ADD_TRAIT(eva, TRAIT_GODMODE, TRAIT_GENERIC)
	var/old_health = eva.health
	var/old_maxz = world.maxz
	TEST_ASSERT(!ship.check_dock(navigation.flight_berth, TRUE), "The abandoned flight footprint must actually block native return")
	TEST_ASSERT_EQUAL(SSshuttle.emergency.canDock(home), SHUTTLE_SOMEONE_ELSE_DOCKED, "The emergency shuttle must not crush the expedition hull")
	SSshuttle.emergency.clear_stationtrauma_bay(home)
	var/deadline = world.time + 10 SECONDS
	UNTIL((!navigation.relocating && !navigation.preparing) || world.time >= deadline)
	TEST_ASSERT(!navigation.relocating && !navigation.preparing, "Service departure must finish within its bounded search")
	TEST_ASSERT_NULL(home.get_docked(), "Evacuation must clear the shared bay even when the old flight footprint is occupied")
	TEST_ASSERT_EQUAL(SSshuttle.emergency.canDock(home), SHUTTLE_CAN_DOCK, "The evacuation shuttle must be allowed to arrive after the service departure")
	TEST_ASSERT_EQUAL(ship.get_docked(), navigation.flight_berth, "Service departure must move the hull to its retained flight berth")
	TEST_ASSERT_EQUAL(world.maxz, old_maxz, "An available berth on the existing flight level must not allocate another z-level")
	TEST_ASSERT_NULL(navigation.docked, "Service departure must release the virtual dock")
	TEST_ASSERT_NULL(site.docking_owner, "Service departure must release site ownership")
	TEST_ASSERT_NULL(navigation.selected_destination, "Service departure must clear the old arrival order")
	TEST_ASSERT(!QDELETED(eva) && get_turf(eva) == old_flight_anchor && eva.health == old_health, "The stranded EVA occupant must remain alive and unmoved")
	TEST_ASSERT(!QDELETED(blocker) && get_turf(blocker) == old_flight_anchor, "The item left outside must remain intact and unmoved")
	SSshuttle.emergency.clear_stationtrauma_bay(home)
	TEST_ASSERT_EQUAL(world.maxz, old_maxz, "Repeated evacuation attempts must not allocate new space")

/// With every flight berth blocked, evacuation keeps the hull at the bay and moves nothing.
/datum/unit_test/overmap_docking/no_safe_berth

/datum/unit_test/overmap_docking/no_safe_berth/Run()
	TEST_ASSERT(navigation.dock(instant = TRUE), "The expedition ship must first dock at the shared bay")
	var/turf/original_position = get_turf(navigation.flight_berth)
	var/old_maxz = world.maxz
	var/list/blockers = list()
	for(var/turf/tile as anything in space.reserved_turfs)
		if(get_area(tile) == exterior)
			var/obj/item/blocker = allocate(/obj/item, tile)
			blockers[blocker] = tile
	SSshuttle.emergency.clear_stationtrauma_bay(home)
	var/deadline = world.time + 10 SECONDS
	UNTIL((!navigation.relocating && !navigation.preparing) || world.time >= deadline)
	TEST_ASSERT(!navigation.relocating && !navigation.preparing, "An exhausted search must release its preparation lock")
	TEST_ASSERT_EQUAL(home.get_docked(), ship, "With no safe destination the expedition hull must stay at the bay")
	TEST_ASSERT_EQUAL(get_turf(navigation.flight_berth), original_position, "An exhausted search must restore the old flight marker")
	TEST_ASSERT_EQUAL(site.docking_owner, navigation, "A failed departure cannot release the occupied site")
	TEST_ASSERT_EQUAL(world.maxz, old_maxz, "An exhausted search must not grow world.maxz on retries")
	for(var/obj/item/blocker as anything in blockers)
		TEST_ASSERT(!QDELETED(blocker) && get_turf(blocker) == blockers[blocker], "Searching for a berth must preserve every blocking object")

/// A service departure whose new berth is occupied during preflight keeps the hull and its dock state.
/datum/unit_test/overmap_docking/service_preflight_blocked
	/// Item dropped on the alternative berth during preflight.
	var/obj/item/late_blocker
	/// Alternative berth found by the service departure.
	var/turf/rejected_position

/datum/unit_test/overmap_docking/service_preflight_blocked/Run()
	TEST_ASSERT(navigation.dock(instant = TRUE), "The expedition ship must first dock at the shared bay")
	var/turf/original_position = get_turf(navigation.flight_berth)
	allocate(/obj/item, original_position)
	ship.preflight_action = CALLBACK(src, PROC_REF(block_service_departure))
	SSshuttle.emergency.clear_stationtrauma_bay(home)
	var/deadline = world.time + 10 SECONDS
	UNTIL((!navigation.relocating && !navigation.preparing) || world.time >= deadline)
	TEST_ASSERT(!navigation.relocating && !navigation.preparing, "A rejected service departure must release its preparation lock")
	TEST_ASSERT_NOTNULL(late_blocker, "The new service berth must reach native yielding preflight")
	TEST_ASSERT_NOTEQUAL(rejected_position, original_position, "The service departure must have found an alternative berth")
	TEST_ASSERT_EQUAL(home.get_docked(), ship, "A late blocker must keep the hull at the original bay")
	TEST_ASSERT_EQUAL(get_turf(navigation.flight_berth), original_position, "Failed physical relocation must restore the old flight marker")
	TEST_ASSERT_EQUAL(navigation.docked, site, "A failed service departure must retain its dock state")
	TEST_ASSERT_EQUAL(site.docking_owner, navigation, "A failed service departure must retain ownership")
	TEST_ASSERT(!QDELETED(late_blocker) && get_turf(late_blocker) == rejected_position, "Late occupants must not be crushed or moved")

/** Occupy the alternative berth and retry evacuation while the service departure is suspended. */
/datum/unit_test/overmap_docking/service_preflight_blocked/proc/block_service_departure()
	TEST_ASSERT(navigation.relocating && navigation.preparing, "The callback must run during the service departure")
	rejected_position = get_turf(navigation.flight_berth)
	late_blocker = allocate(/obj/item, rejected_position)
	SSshuttle.emergency.clear_stationtrauma_bay(home)
	TEST_ASSERT_EQUAL(home.get_docked(), ship, "Repeated evacuation cannot start a second relocation during preflight")

/// A service departure must leave the ship able to visit a virtual site through a real map seam.
/datum/unit_test/overmap_docking/evacuation_then_virtual_dock
	/// Borrowed turf -> list(type, baseturfs, area, turf_flags, destination x/y/z) to restore.
	var/list/borrowed_turfs = list()
	/// Berth of the virtual site on another level.
	var/obj/docking_port/stationary/virtual_berth

/datum/unit_test/overmap_docking/evacuation_then_virtual_dock/Destroy()
	// Remove passages and the moved hull before restoring their borrowed coordinates.
	qdel(navigation)
	qdel(ship, force = TRUE)
	qdel(virtual_berth, force = TRUE)
	virtual_berth = null
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

/** Record a turf for restoration and turn it into plain space, optionally inside the flight exterior. */
/datum/unit_test/overmap_docking/evacuation_then_virtual_dock/proc/borrow_space(turf/tile, add_to_exterior = FALSE)
	var/turf/open/open_tile = isopenturf(tile) ? tile : null
	if(!borrowed_turfs[tile])
		borrowed_turfs[tile] = list(tile.type, islist(tile.baseturfs) ? tile.baseturfs.Copy() : tile.baseturfs, get_area(tile), tile.turf_flags, open_tile?.destination_x, open_tile?.destination_y, open_tile?.destination_z)
	if(!isspaceturf(tile))
		tile = tile.ChangeTurf(/turf/open/space)
	open_tile = tile
	open_tile.destination_x = 0
	open_tile.destination_y = 0
	open_tile.destination_z = 0
	if(add_to_exterior)
		tile.change_area(get_area(tile), exterior)

/datum/unit_test/overmap_docking/evacuation_then_virtual_dock/Run()
	TEST_ASSERT(navigation.dock(instant = TRUE), "The expedition hull must first dock at the shared bay")
	var/turf/original_flight = get_turf(navigation.flight_berth)
	var/obj/item/blocker = allocate(/obj/item, original_flight)
	// Restrict this test's exterior to two real positions, with the world-edge candidate first.
	for(var/turf/tile as anything in space.reserved_turfs)
		if(get_area(tile) == exterior)
			tile.change_area(exterior, original_areas[tile])
	var/flight_z = original_flight.z
	var/remote_z = run_loc_floor_bottom_left.z
	TEST_ASSERT_NOTEQUAL(flight_z, remote_z, "A virtual site must be on another physical level")
	// x < SHUTTLE_TRANSIT_BORDER is outside every reservation, so these cells have no other owner.
	for(var/anchor_x in list(1, 12))
		for(var/turf/tile as anything in block(locate(anchor_x, 32, flight_z), locate(anchor_x + 1, 34, flight_z)))
			TEST_ASSERT_NULL(SSmapping.used_turfs[tile], "Borrowed flight cells must not belong to another reservation")
			borrow_space(tile, TRUE)
	// Native seams span the entire level. Prepare and later restore both real gate/landing columns.
	for(var/gate_z in list(flight_z, remote_z))
		for(var/turf/tile as anything in block(locate(10, 1, gate_z), locate(11, world.maxy, gate_z)))
			borrow_space(tile)
	virtual_berth = allocate(/obj/docking_port/stationary/stationtrauma_space_site, locate(10, 32, remote_z))
	var/datum/stationtrauma_overmap_site/space/virtual_site = allocate(/datum/stationtrauma_overmap_site/space)
	virtual_site.id = "unit_test_virtual_dock"
	virtual_site.name = "Unit test virtual site"
	virtual_site.berth = virtual_berth
	virtual_site.pos_x = navigation.pos_x
	virtual_site.pos_y = navigation.pos_y
	navigation.sites[virtual_site.id] = virtual_site
	SSshuttle.emergency.clear_stationtrauma_bay(home)
	var/deadline = world.time + 10 SECONDS
	UNTIL((!navigation.relocating && !navigation.preparing) || world.time >= deadline)
	TEST_ASSERT(!navigation.relocating && !navigation.preparing, "Service departure must complete")
	TEST_ASSERT_NULL(home.get_docked(), "The shared bay must be physically vacated")
	TEST_ASSERT(!QDELETED(blocker) && get_turf(blocker) == original_flight, "The original flight blocker must stay intact")
	TEST_ASSERT(navigation.select_site(virtual_site.id), "The crew must be able to select a virtual destination after evacuation")
	TEST_ASSERT(navigation.dock(instant = TRUE), "The post-evacuation hull position must permit a real virtual-site seam")
	TEST_ASSERT(navigation.connection.active, "The post-evacuation seam must publish its passages")
	var/obj/item/coin/traveller = allocate(/obj/item/coin, locate(11, 32, flight_z))
	TEST_ASSERT(traveller.Move(locate(10, 32, flight_z)), "The traveller must enter the actual ship-side passage")
	deadline = world.time + 5 SECONDS
	UNTIL(traveller.z == remote_z || world.time >= deadline)
	TEST_ASSERT_EQUAL(get_turf(traveller), locate(10, 32, remote_z), "The published seam must transport the traveller to the virtual site")

/datum/unit_test/overmap_docking/console_sessions/Run()
	var/turf/console_turf = get_turf(ship)
	var/obj/machinery/computer/stationtrauma_space_navigation/console = allocate(/obj/machinery/computer/stationtrauma_space_navigation, console_turf)
	console.vessel = ship
	var/mob/living/carbon/human/consistent/pilot = allocate(/mob/living/carbon/human/consistent, get_step(console_turf, NORTH))
	ADD_TRAIT(pilot, TRAIT_PRESERVE_UI_WITHOUT_CLIENT, TRAIT_SOURCE_UNIT_TESTS)
	var/datum/tgui/pilot_window = allocate(/datum/tgui, pilot, console, "SpaceNavigation")
	pilot_window.process_status()
	TEST_ASSERT_EQUAL(pilot_window.status, UI_INTERACTIVE, "A pilot adjacent to the helm should be able to operate it")

	pilot.forceMove(locate(console_turf.x, console_turf.y + 2, console_turf.z))
	console.ui_interact(pilot, pilot_window)
	TEST_ASSERT(pilot_window.closing, "Refreshing the helm after the pilot steps away should close the existing window")

	var/mob/dead/observer/observer = allocate(/mob/dead/observer)
	observer.mock_client = allocate(/datum/client_interface)
	observer.forceMove(get_step(console_turf, NORTH))
	var/datum/tgui/observer_window = allocate(/datum/tgui, observer, console, "SpaceNavigation")
	observer_window.process_status()
	TEST_ASSERT_EQUAL(observer_window.status, UI_UPDATE, "An observer nearby should receive helm updates without control")
	TEST_ASSERT(console.ui_act("interface_click", list(), observer_window, observer_window.state), "The UI action should be consumed by the read-only check")

	observer.forceMove(console_turf.z == 1 ? locate(console_turf.x, console_turf.y, 2) : locate(console_turf.x, console_turf.y, 1))
	observer_window.process_status()
	TEST_ASSERT_EQUAL(observer_window.status, UI_CLOSE, "An observer on a different deck should not keep a helm window open")

/// Exercise one landing and launch at a cardinally rotated berth through native movement.
/datum/unit_test/overmap_docking/planet_flight_picture/Run()
	var/datum/landing_view_piece/sample = allocate(/datum/landing_view_piece)
	sample.scale.mark(0, 1).mark(10, 1).mark(11, 2)
	sample.sample_animation(0)
	var/list/frames = sample.animation_steps
	TEST_ASSERT_EQUAL(length(frames), 1, "A still interval should be stored as one hold")
	var/list/frame = frames[1]
	TEST_ASSERT_EQUAL(frame[3], 10, "Sharing keyframes must preserve the full hold before motion")
	sample.sample_animation(0)
	TEST_ASSERT(sample.animation_steps == frames, "Every image started in the same tick must reuse the sampled frames")
	sample.sample_animation(11)
	TEST_ASSERT_EQUAL(sample.animation_start[1], 2, "An image starting later must start at the current scale")

	var/turf/corner = space.bottom_left_turfs[1]
	for(var/turf/tile as anything in block(locate(corner.x + 8, corner.y + 1, corner.z), locate(corner.x + 16, corner.y + 8, corner.z)))
		tile.ChangeTurf(/turf/open/floor/plating)
	var/list/berth_tiles = ship.return_ordered_turfs(bay.x, bay.y, bay.z, bay.dir)
	var/turf/marked_ground = berth_tiles[1]
	var/ground_tint = "#6c85a2"
	marked_ground.color = ground_tint
	site.landing = TRUE
	var/datum/stationtrauma_overmap_site/space/planet/lava/planet = allocate(/datum/stationtrauma_overmap_site/space/planet/lava)
	site.pad_parent = planet
	TEST_ASSERT(navigation.set_engines_running(TRUE), "The fixture needs main propulsion to land")
	navigation.pos_x = site.pos_x + 150
	TEST_ASSERT(navigation.can_dock(site, navigation.control_revision), "A landing must be available on the helm ring")
	navigation.pos_x++
	TEST_ASSERT(!navigation.can_dock(site, navigation.control_revision), "A landing past the helm ring must be out of range")
	navigation.pos_x = site.pos_x

	// A generated planet supplies a clearing, then fits a separate native port for the ship.
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/planet_pad/clearing = allocate(/obj/docking_port/stationary/stationtrauma_space_station/standard/planet_pad, locate(corner.x + 9, corner.y + 2, corner.z))
	clearing.width = 7
	clearing.height = 7
	site.berth = null
	site.loading_map = TRUE
	navigation.begin_approach(site, 2 MINUTES)
	var/datum/stationtrauma_planet_flight/flight = navigation.planet_flight
	TEST_ASSERT_NOTNULL(navigation.planet_hover, "The disk must already be visible when the map is still loading")
	TEST_ASSERT(!flight.descent && !navigation.entry_heat(), "Atmospheric entry must wait for the terrain")
	var/initial_scale = navigation.planet_hover.size.at(navigation.planet_hover.size.end_time())
	TEST_ASSERT(initial_scale < 0.7, "First generation must keep the opening zoom small")
	navigation.approach_started -= 2 MINUTES
	flight.next_zoom = 0
	TEST_ASSERT(!flight.update(), "Passing the estimated load time cannot start atmosphere against an unbuilt planet")
	TEST_ASSERT(navigation.planet_hover.size.at(navigation.planet_hover.size.end_time()) > initial_scale, "The orbit must continue to zoom during a late generation")
	site.berth = clearing
	site.loading_map = FALSE
	flight.update()
	TEST_ASSERT_NOTNULL(clearing.active_berth, "The first approach must fit the real ship into the generated clearing")
	TEST_ASSERT_EQUAL(flight.berth, clearing.active_berth, "The picture must use the physical port under the ship")
	navigation.end_approach()
	clearing.clear_berth()
	site.berth = bay

	navigation.begin_approach(site, 2 MINUTES)
	var/datum/landing_animation/descent = navigation.planet_flight?.descent
	TEST_ASSERT_NOTNULL(descent?.inside_view, "A planetary descent must use the full inside view")
	TEST_ASSERT_EQUAL(descent.inside_view.palette.heat, "#ff8a3c", "A lava planet must use the imported volcanic palette")
	descent.start(12 SECONDS, navigation.take_planet_hover())
	descent.show_shadow()
	descent.show_proxies()
	var/obj/effect/abstract/landing_proxy/cancelled = descent.proxy
	TEST_ASSERT_NOTNULL(cancelled, "A descent must have a proxy visible from the ground")
	TEST_ASSERT_NOTNULL(descent.shadow, "A descent must cast a blurred shadow on the berth")
	TEST_ASSERT(!cancelled.density && cancelled.mouse_opacity == MOUSE_OPACITY_TRANSPARENT, "The picture cannot obstruct or intercept gameplay")
	var/datum/landing_view/descent/cancelled_view = descent.inside_view
	navigation.end_approach()
	TEST_ASSERT(QDELETED(cancelled) && cancelled_view.ended, "Cancelling must clear the ground picture and fade the crew's view")
	var/deadline = world.time + 3 SECONDS
	UNTIL(QDELETED(cancelled_view) || world.time >= deadline)
	TEST_ASSERT(QDELETED(cancelled_view), "A cancelled descent must release its view after fading")

	navigation.begin_approach(site, 2 MINUTES)
	descent = navigation.planet_flight?.descent
	TEST_ASSERT_NOTNULL(descent, "A second approach needs its own scene")
	deadline = world.time + 8 SECONDS
	UNTIL(!descent.inside_view.ground_jobs || world.time >= deadline)
	TEST_ASSERT(!descent.inside_view.ground_jobs, "Atmospheric entry must have its complete view ready")
	navigation.approach_started -= 14 SECONDS
	TEST_ASSERT(!navigation.planet_flight.update() && descent.touchdown_time > world.time, "Readiness must start the atmospheric sequence before allowing the move")
	TEST_ASSERT(!navigation.entry_heat(), "The hull must stay calm before the entry sparks")
	var/touchdown = descent.touchdown_time
	descent.touchdown_time = world.time + 12 SECONDS
	TEST_ASSERT(navigation.entry_heat() > 0, "The hull shakes in the donor's entry interval")
	descent.touchdown_time = touchdown
	descent.show_proxies()
	TEST_ASSERT(navigation.dock(instant = TRUE), "The pictures must permit the same native landing")
	TEST_ASSERT_EQUAL(ship.get_docked(), bay, "The real hull must land at the photographed berth")
	TEST_ASSERT(descent.frozen && descent.landed && QDELETED(descent.inside_view), "Touchdown must hand the view over to the real world")
	deadline = world.time + 4 SECONDS
	UNTIL(QDELETED(descent) || world.time >= deadline)
	TEST_ASSERT(QDELETED(descent), "The landing proxy must finish fading after touchdown")

	navigation.begin_approach(site, 1 MINUTES, departing = TRUE)
	var/datum/landing_view/ascent/ascent = navigation.planet_ascent
	TEST_ASSERT_NOTNULL(ascent, "Ascent must prepare the real terrain beside the hull")
	var/turf/covered = ascent.berth_turfs[1]
	TEST_ASSERT(isfloorturf(covered) && ship.docking_surfaces[covered], "The rotated berth must conceal real ground beneath the hull")
	deadline = world.time + 8 SECONDS
	UNTIL(!ascent.ground_jobs || world.time >= deadline)
	TEST_ASSERT(!ascent.ground_jobs, "The full launch picture must be ready while the hull is still on the ground")
	TEST_ASSERT(navigation.relocate(navigation.flight_berth), "The real hull must be able to depart the photographed berth")
	TEST_ASSERT_EQUAL(ship.get_docked(), navigation.flight_berth, "The native departure must reach the flight berth")
	TEST_ASSERT(ship.launched_before_cleanup, "The new view must attach before native docking cleanup can expose a frame of empty space")
	TEST_ASSERT(ascent.liftoff && length(ascent.close.parts), "The ascent must switch to the original ground in the move tick")
	var/turf/revealed = locate(covered.x, covered.y, covered.z)
	TEST_ASSERT_EQUAL(revealed.color, ground_tint, "The original ground beneath the hull must now be exposed")
	var/found_under_hull = FALSE
	for(var/list/part as anything in ascent.close.parts)
		var/mutable_appearance/group = part[1]
		for(var/mutable_appearance/tile_picture as anything in group.overlays)
			if(tile_picture.color == ground_tint)
				found_under_hull = TRUE
	TEST_ASSERT(found_under_hull, "The close-up picture must contain the exact tile that the hull concealed")
	navigation.end_approach()
	TEST_ASSERT(!QDELETED(ascent) && isnull(navigation.planet_flight), "Completing the manoeuvre must allow the ascent to finish playing")
	ascent.finish()
	deadline = world.time + 3 SECONDS
	UNTIL(QDELETED(ascent) || world.time >= deadline)
	TEST_ASSERT(QDELETED(ascent), "Ascent must release its flight pictures after the animation")
	TEST_ASSERT(isnull(navigation.planet_ascent), "The completed animation must clear its navigation reference")
