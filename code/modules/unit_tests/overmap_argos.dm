/** Exercise the shipped Argos template through native map initialization and sector attachment. */
/datum/unit_test/overmap_argos
	/// Retain the loader's exact footprint for cleanup even if a check fails early.
	var/datum/map_template/stationtrauma_space/ship/template
	/// Actual loaded vessel, never replaced with a synthetic hull.
	var/obj/docking_port/mobile/stationtrauma_space/ship
	/// Isolated sector; no live round sector is changed.
	var/datum/stationtrauma_overmap_sector/space/sector
	/// Native berth used by this test, including before it is moved into the loaded deck.
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/bay
	/// Exterior created by attachment on this template's private level.
	var/area/space/stationtrauma_space_home/exterior
	/// Native registration counters survive port deletion and need restoring.
	var/list/mobile_ids
	/// Native stationary registration counters before this test.
	var/list/stationary_ids
	/// Sound-loop scheduling state before the bounded template-loading window.
	var/previous_sound_loops_can_fire
	/// Restore sound scheduling on teardown if loading exits before the normal restore.
	var/sound_loops_paused = FALSE

/datum/unit_test/overmap_argos/Run()
	try
		exercise_argos()
	catch(var/exception/failure)
		discard_test_ship()
		throw failure
	discard_test_ship()

/** Exercise the map while retaining its exact loaded footprint for teardown after a failed check. */
/datum/unit_test/overmap_argos/proc/exercise_argos()
	mobile_ids = SSshuttle.assoc_mobile.Copy()
	stationary_ids = SSshuttle.assoc_stationary.Copy()
	template = allocate(/datum/map_template/stationtrauma_space/ship, "_maps/map_files/overmap_ships/argos.dmm", "Argos integration test")
	previous_sound_loops_can_fire = SSsound_loops.can_fire
	sound_loops_paused = TRUE
	SSsound_loops.can_fire = FALSE
	ship = template.load_ship()
	TEST_ASSERT_NOTNULL(ship, "The actual Argos map must load through the production template loader")
	// Generator audio client-time timers are unrelated to the native grid and movement contract.
	for(var/turf/tile as anything in ship.return_turfs())
		for(var/obj/machinery/power/port_gen/pacman/generator in tile)
			generator.soundloop.stop()
	SSsound_loops.can_fire = previous_sound_loops_can_fire
	sound_loops_paused = FALSE
	TEST_ASSERT_EQUAL(length(ship.owned_z_levels), 1, "Argos must own exactly its loaded deck")
	TEST_ASSERT_EQUAL(ship.width, 12, "Native hull bounds must include the entire twelve-tile-wide map")
	TEST_ASSERT_EQUAL(ship.height, 22, "Native hull bounds must include the added engineering compartment")
	sector = allocate(/datum/stationtrauma_overmap_sector/space)
	sector.id = "unit_test_argos"
	sector.ready = TRUE
	TEST_ASSERT(sector.attach(ship), "Sector attachment must accept the actual loaded Argos hull")
	var/datum/stationtrauma_overmap/space/navigation = ship.overmap
	exterior = navigation.exterior
	STOP_PROCESSING(SSfastprocess, navigation)
	bay = allocate(/obj/docking_port/stationary/stationtrauma_space_station/standard_m)
	TEST_ASSERT(bay.accepts(ship), "Native measured Argos bounds and class must fit a standard M berth")
	ship.initialize_docking_layers()
	var/list/hatches = list()
	var/list/helms = list()
	var/list/terminals = list()
	var/list/transponders = list()
	var/list/storage = list()
	var/list/generators = list()
	var/list/vents = list()
	var/list/scrubbers = list()
	var/list/tanks = list()
	var/list/regulators = list()
	for(var/turf/tile as anything in ship.return_turfs())
		for(var/obj/machinery/machine in tile)
			if(istype(machine, /obj/machinery/door/airlock/stationtrauma_docking/ship))
				hatches += machine
			if(istype(machine, /obj/machinery/computer/stationtrauma_space_navigation))
				helms += machine
			if(istype(machine, /obj/machinery/computer/stationtrauma_bluespace))
				terminals += machine
			if(istype(machine, /obj/machinery/computer/stationtrauma_transponder))
				transponders += machine
			if(istype(machine, /obj/machinery/power/smes))
				storage += machine
			if(istype(machine, /obj/machinery/power/port_gen/pacman))
				generators += machine
			if(istype(machine, /obj/machinery/atmospherics/components/unary/vent_pump))
				vents += machine
			if(istype(machine, /obj/machinery/atmospherics/components/unary/vent_scrubber))
				scrubbers += machine
			if(istype(machine, /obj/machinery/atmospherics/components/tank))
				tanks += machine
			if(istype(machine, /obj/machinery/atmospherics/components/binary/pump))
				regulators += machine
	TEST_ASSERT_EQUAL(length(hatches), 2, "Both side docking hatches must survive map initialization")
	for(var/obj/machinery/door/airlock/stationtrauma_docking/ship/hatch as anything in hatches)
		TEST_ASSERT(bay.hatch_available(ship, hatch), "Each mapped docking hatch needs unobstructed interior floor and clear space outside at [COORD(hatch)]")
	TEST_ASSERT_EQUAL(length(helms), 1, "The actual bridge needs one navigation console")
	var/obj/machinery/computer/stationtrauma_space_navigation/helm = helms[1]
	TEST_ASSERT_EQUAL(helm.vessel, ship, "Sector attachment must bind the mapped helm to Argos")
	var/turf/seat_tile = locate(template.loaded_min_x + 2, template.loaded_min_y + 19, ship.z)
	var/obj/structure/chair/pilot_seat = locate() in seat_tile
	TEST_ASSERT_NOTNULL(pilot_seat, "The bridge needs its mapped pilot seat")
	var/mob/living/carbon/human/consistent/pilot = allocate(/mob/living/carbon/human/consistent, get_step(seat_tile, SOUTH))
	TEST_ASSERT(pilot.Move(seat_tile, NORTH), "The pilot must be able to walk from the bridge aisle onto the seat")
	TEST_ASSERT(pilot_seat.user_buckle_mob(pilot, pilot) && pilot.Adjacent(helm), "The pilot must be able to buckle in within reach of the helm")
	qdel(pilot)
	TEST_ASSERT_EQUAL(length(terminals), 1, "The actual bridge needs one jump terminal")
	var/obj/machinery/computer/stationtrauma_bluespace/terminal = terminals[1]
	TEST_ASSERT_EQUAL(terminal.navigation(), navigation, "The mapped jump terminal must resolve its real containing hull")
	TEST_ASSERT_EQUAL(length(ship.engine_list), 8, "Native linkup must register all eight mapped propulsion engines")
	for(var/obj/machinery/power/shuttle_engine/engine as anything in ship.engine_list)
		TEST_ASSERT(istype(engine, /obj/machinery/power/shuttle_engine/propulsion/argos), "Every mapped nozzle must use the Argos bluespace drive")
		TEST_ASSERT_EQUAL(engine.connected_ship, ship, "Each actual propulsion engine must register with Argos")
	TEST_ASSERT(navigation.set_engines_running(TRUE), "The mapped Argos engines must respond to the real engine controls")
	TEST_ASSERT(ship.hull_mass > 0, "Thrust must be measured against the loaded hull mass")
	TEST_ASSERT_EQUAL(navigation.thrust_ratio(), 16 / ship.hull_mass, "Eight Argos nozzles must deliver sixteen units of thrust to the loaded hull")
	navigation.set_engines_running(FALSE)
	TEST_ASSERT_NOTNULL(navigation.jump_drive(), "The mapped charged drive must bind to the loaded hull and have power")
	TEST_ASSERT_EQUAL(length(transponders), 1, "The actual bridge needs one transponder")
	var/obj/machinery/computer/stationtrauma_transponder/transponder = transponders[1]
	TEST_ASSERT_EQUAL(transponder.vessel, ship, "Native linkup must bind the mapped transponder")
	var/list/identity = navigation.transponder_identity()
	TEST_ASSERT(identity && identity["callsign"] == "Argos" && identity["faction"] == "НТ", "The mapped board must actually answer hull identification queries")
	TEST_ASSERT_EQUAL(length(storage), 1, "Argos needs one initialized ship SMES")
	var/obj/machinery/power/smes/smes = storage[1]
	TEST_ASSERT_NOTNULL(smes.terminal?.powernet, "The mapped SMES input terminal must connect to a real powernet")
	TEST_ASSERT_NOTNULL(smes.powernet, "The mapped SMES output must connect to a real powernet")
	TEST_ASSERT_NOTEQUAL(smes.terminal.powernet, smes.powernet, "Input and output cables must not bypass the SMES")
	TEST_ASSERT(smes.ui_data()["charge"] > 0, "The initialized SMES must contain usable charge")
	var/previous_output = smes.powernet.newavail
	smes.process(1)
	TEST_ASSERT(smes.powernet.newavail > previous_output, "The mapped SMES must actually supply its output network")
	TEST_ASSERT_EQUAL(length(generators), 1, "Argos must load a single generator")
	var/obj/machinery/power/port_gen/pacman/ship/generator = generators[1]
	TEST_ASSERT(istype(generator), "Argos needs the ship plasma generator")
	TEST_ASSERT_EQUAL(generator.powernet, smes.terminal.powernet, "The generator must feed the SMES input network")
	TEST_ASSERT(generator.auto_mode && generator.anchored && generator.active && generator.HasFuel(), "The ship generator must start fueled and running in automatic mode")
	var/previous_input = smes.terminal.powernet.newavail
	generator.process(1)
	TEST_ASSERT(smes.terminal.powernet.newavail > previous_input, "The ship generator must deliver energy to the real SMES input network")
	for(var/area/compartment as anything in ship.shuttle_areas)
		if(!compartment.requires_power)
			continue
		var/obj/machinery/power/apc/apc = compartment.apc
		TEST_ASSERT_NOTNULL(apc, "Every powered Argos compartment needs its initialized APC: [compartment.type]")
		TEST_ASSERT_EQUAL(apc.terminal?.powernet, smes.powernet, "Every compartment APC must connect to the SMES output grid: [compartment.type]")
	TEST_ASSERT(length(vents) && length(scrubbers), "The real map must initialize supply and waste endpoints")
	var/datum/pipeline/supply
	for(var/obj/machinery/atmospherics/components/unary/vent_pump/vent as anything in vents)
		TEST_ASSERT_NOTNULL(vent.nodes[1], "Every supply vent must physically connect to mapped piping at [COORD(vent)]")
		var/datum/pipeline/network = vent.return_pipenet()
		TEST_ASSERT_NOTNULL(network, "The template loader must build each supply vent pipeline")
		supply ||= network
		TEST_ASSERT_EQUAL(network, supply, "Supply vents must share the finite air source network")
	var/datum/pipeline/waste
	for(var/obj/machinery/atmospherics/components/unary/vent_scrubber/scrubber as anything in scrubbers)
		TEST_ASSERT_NOTNULL(scrubber.nodes[1], "Every scrubber must physically connect to mapped piping at [COORD(scrubber)]")
		var/datum/pipeline/network = scrubber.return_pipenet()
		TEST_ASSERT_NOTNULL(network, "The template loader must build each waste pipeline")
		waste ||= network
		TEST_ASSERT_EQUAL(network, waste, "Scrubbers must share the waste collection network")
	TEST_ASSERT_NOTEQUAL(supply, waste, "Supply and waste piping must remain physically separate")
	TEST_ASSERT_EQUAL(length(regulators), 1, "The real supply needs one initialized regulator")
	var/obj/machinery/atmospherics/components/binary/pump/regulator = regulators[1]
	TEST_ASSERT(regulator.nodes[1] && regulator.nodes[2], "The mapped regulator must have real pipe connections on both sides")
	TEST_ASSERT_EQUAL(regulator.parents[2], supply, "The regulator output must physically feed the vent distribution pipeline")
	TEST_ASSERT_NOTNULL(regulator.parents[1], "The regulator must initialize its source pipeline")
	TEST_ASSERT_NOTEQUAL(regulator.parents[1], supply, "The regulator must separate the tank from its lower-pressure distribution network")
	var/source_connected = FALSE
	var/sink_connected = FALSE
	for(var/obj/machinery/atmospherics/components/tank/tank as anything in tanks)
		var/list/networks = tank.return_pipenets()
		if(regulator.parents[1] in networks)
			source_connected = tank.air_contents?.has_gas(/datum/gas/oxygen) && tank.air_contents?.has_gas(/datum/gas/nitrogen)
		if(waste in networks)
			sink_connected = TRUE
	TEST_ASSERT(source_connected, "The real supply pipeline must reach an initialized tank containing breathable reserve gas")
	TEST_ASSERT(sink_connected, "The real scrubber pipeline must reach a mapped collection tank")
	var/datum/pipeline/source = regulator.parents[1]
	source.reconcile_air()
	var/datum/gas_mixture/output_air = regulator.airs[2]
	// Model a consumer drawing the outlet, regardless of whether atmos ticked during attachment.
	var/datum/gas_mixture/drawn_air = output_air.remove_ratio(1)
	qdel(drawn_air)
	regulator.process_atmos()
	TEST_ASSERT(output_air.total_moles() > 0, "The initialized regulator must actually replenish its outlet from the connected reserve tank")
	// A single real wall endpoint exercises this hull's docking; the existing M controller test covers the complete station installation.
	var/slot_x = template.loaded_min_x + 15
	var/slot_y = template.loaded_min_y
	TEST_ASSERT(slot_x + 23 < world.maxx - TRANSITIONEDGE && slot_y + 24 < world.maxy - TRANSITIONEDGE, "The private loaded level must fit an M berth beside Argos")
	// Include the station and a possibly still-moored hull in production cleanup before changing any extra cells.
	template.width = slot_x + 23 - template.loaded_min_x + 1
	template.height = max(template.height, bay.height)
	bay.forceMove(locate(slot_x, slot_y, ship.z))
	bay.setDir(NORTH)
	var/area/station_area = new /area/stationtrauma_space_site/unit_test_standard_dock
	allocated += station_area
	for(var/wall_x in slot_x + 20 to slot_x + 22)
		var/turf/tile = locate(wall_x, slot_y + 4, ship.z)
		tile = tile.ChangeTurf(/turf/open/floor/plating, /turf/open/space)
		tile.change_area(get_area(tile), station_area)
	// Enclose the receiving chamber so this fixture does not vent Argos when the two endpoints open.
	for(var/turf/tile as anything in block(locate(slot_x + 20, slot_y + 3, ship.z), locate(slot_x + 23, slot_y + 5, ship.z)))
		if(tile.y == slot_y + 4 && tile.x < slot_x + 23)
			continue
		tile = tile.ChangeTurf(/turf/closed/wall, /turf/open/space)
		tile.change_area(get_area(tile), station_area)
	var/obj/machinery/door/airlock/stationtrauma_docking/wall/wall = allocate(/obj/machinery/door/airlock/stationtrauma_docking/wall, locate(slot_x + 20, slot_y + 4, ship.z))
	wall.setDir(WEST)
	var/datum/gas_mixture/station_air = SSair.parse_gas_string(OPENTURF_DEFAULT_ATMOS, /datum/gas_mixture/turf)
	for(var/turf/open/floor/tile in block(get_turf(wall), locate(slot_x + 22, slot_y + 4, ship.z)))
		tile.copy_air(station_air)
		tile.air_update_turf(TRUE, FALSE)
	qdel(station_air)
	var/datum/stationtrauma_overmap_site/space/dock_site = allocate(/datum/stationtrauma_overmap_site/space)
	dock_site.id = "unit_test_argos_berth"
	dock_site.physical_docking = TRUE
	dock_site.berth = bay
	dock_site.pos_x = navigation.pos_x
	dock_site.pos_y = navigation.pos_y
	sector.sites[dock_site.id] = dock_site
	var/turf/flight_anchor = get_turf(ship)
	TEST_ASSERT(navigation.set_engines_running(TRUE), "The mapped Argos engines must start before its real departure")
	TEST_ASSERT(navigation.select_site(dock_site.id), "Argos must select the physical M berth")
	TEST_ASSERT(navigation.dock(instant = TRUE, station_authorized = TRUE), "The actual Argos hull must physically dock at an M berth: [navigation.status]")
	var/obj/docking_port/stationary/stationtrauma_space_site/standard/arrival = ship.get_docked()
	TEST_ASSERT(istype(arrival) && arrival == bay.active_berth && length(arrival.gangways) == 1, "Argos must deploy a real gangway from its compatible side hatch")
	var/datum/stationtrauma_dock_gangway/gangway = arrival.gangways[1]
	var/turf/bridge = locate(slot_x + 19, slot_y + 4, ship.z)
	TEST_ASSERT(istype(bridge, /turf/open/floor/plating/stationtrauma_dock_gangway), "The actual mapped hatch must deploy its passage floor")
	var/deadline = world.time + 5 SECONDS
	UNTIL(!gangway.busy || world.time >= deadline)
	TEST_ASSERT(!gangway.busy, "The real Argos gangway must finish its arrival operation")
	TEST_ASSERT(gangway.open_passage(), "The real Argos gangway must open using its mapped atmosphere and the station fixture atmosphere")
	TEST_ASSERT(!gangway.ship.density && !gangway.wall.density, "Both actual Argos passage endpoints must be physically open")
	station_area.requires_power = TRUE
	station_area.power_environ = FALSE
	station_area.power_change()
	TEST_ASSERT(!wall.hasPower() && gangway.ship.hasPower(), "Only the station end of the open gangway must lose power")
	var/obj/item/hatch_obstruction = allocate(/obj/item, get_turf(gangway.ship))
	TEST_ASSERT(!navigation.depart(instant = TRUE), "Argos must stay docked while its hatch is blocked")
	TEST_ASSERT(navigation.docked == dock_site && !wall.density, "A blocked ship hatch must leave the unpowered wall open")
	qdel(hatch_obstruction)
	RegisterSignal(wall, COMSIG_AIRLOCK_CLOSE, PROC_REF(stop_during_wall_closure))
	var/departed = navigation.depart(instant = TRUE)
	UnregisterSignal(wall, COMSIG_AIRLOCK_CLOSE)
	TEST_ASSERT(!departed && navigation.docked == dock_site && wall.density, "Argos must stay moored if the departure is stopped during wall closure")
	deadline = world.time + 5 SECONDS
	UNTIL((!gangway.busy && !gangway.ship.density) || world.time >= deadline)
	TEST_ASSERT(!gangway.busy && !gangway.ship.density && wall.density && !wall.hasPower(), "The cancelled departure must reopen a way back aboard while the wall remains sealed")
	TEST_ASSERT(!gangway.open_passage() && !gangway.ship.density, "Requesting the full passage during the outage must leave the return hatch open")
	TEST_ASSERT(navigation.depart(instant = TRUE), "Argos must depart through native relocation even when the dock wall has lost power: [navigation.status]")
	TEST_ASSERT(wall.density && !wall.operating && !wall.hasPower(), "Departure must leave the unpowered wall closed")
	TEST_ASSERT_EQUAL(get_turf(ship), flight_anchor, "Departure must return the actual Argos hull to its original flight anchor")
	TEST_ASSERT_EQUAL(ship.get_docked(), navigation.flight_berth, "Argos must physically occupy its retained flight berth after departure")
	TEST_ASSERT(isspaceturf(bridge), "Argos departure must retract the actual gangway back to space")
	navigation.stop()

/** Interrupt a real departure after the wall has drawn its backup power. */
/datum/unit_test/overmap_argos/proc/stop_during_wall_closure()
	SIGNAL_HANDLER
	ship.overmap.stop()

/** The native loader sheds work across ticks, so clear its footprint before Destroy. */
/datum/unit_test/overmap_argos/proc/discard_test_ship()
	if(ship)
		qdel(ship.overmap)
		qdel(ship, force = TRUE)
		ship = null
	if(bay)
		qdel(bay, force = TRUE)
		bay = null
	if(template)
		var/list/loaded_levels = template.loaded_levels.Copy()
		template.discard_loaded_ship()
		// Attachment owns exterior cells outside the exact DMM rectangle as well.
		for(var/deck in loaded_levels)
			for(var/turf/tile as anything in block(locate(1, 1, deck), locate(world.maxx, world.maxy, deck)))
				if(get_area(tile) == exterior)
					tile.change_area(exterior, GLOB.areas_by_type[/area/space])

/datum/unit_test/overmap_argos/Destroy()
	QDEL_NULL(exterior)
	if(mobile_ids)
		SSshuttle.assoc_mobile = mobile_ids
	if(stationary_ids)
		SSshuttle.assoc_stationary = stationary_ids
	mobile_ids = stationary_ids = null
	template = null
	sector = null
	if(sound_loops_paused)
		SSsound_loops.can_fire = previous_sound_loops_can_fire
		sound_loops_paused = FALSE
	return ..()

/** Argos crew credentials gate all three real presets and the transponder's server action. */
/datum/unit_test/overmap_argos_access
	/// Original test-cell area, restored before disposing of the temporary area.
	var/area/original_area
	/// Unmetered area isolates permission checks from the separate mapped-grid integration test.
	var/area/shuttle/stationtrauma_space/test_area

/datum/unit_test/overmap_argos_access/Run()
	original_area = get_area(run_loc_floor_bottom_left)
	test_area = new /area/shuttle/stationtrauma_space/unit_test_docking
	allocated += test_area
	run_loc_floor_bottom_left.change_area(original_area, test_area)
	var/mob/living/carbon/human/consistent/operator = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/under/color/grey/uniform = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(operator.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING), "The operator needs a uniform to wear credentials")
	var/obj/item/card/id/advanced/card = allocate(/obj/item/card/id/advanced)
	card.set_access(list(), FORCE_ADD_ALL)
	TEST_ASSERT(operator.equip_to_slot_if_possible(card, ITEM_SLOT_ID), "The operator must wear a real ID")
	for(var/preset in list(/obj/machinery/computer/stationtrauma_space_navigation/argos, /obj/machinery/computer/stationtrauma_bluespace/argos, /obj/machinery/computer/stationtrauma_transponder/argos))
		var/obj/machinery/computer/console = allocate(preset)
		TEST_ASSERT(!console.can_interact(operator), "An operator without Central Command access must be denied by [preset]")
		card.set_access(list(ACCESS_CENT_GENERAL), FORCE_ADD_ALL)
		TEST_ASSERT(console.can_interact(operator), "Central Command credentials must permit [preset]")
		card.set_access(list(), FORCE_ADD_ALL)
		if(!istype(console, /obj/machinery/computer/stationtrauma_transponder))
			continue
		var/obj/machinery/computer/stationtrauma_transponder/transponder = console
		var/datum/tgui/ui = allocate(/datum/tgui, operator, transponder, "ShipTransponder")
		ui.status = UI_INTERACTIVE
		TEST_ASSERT(!transponder.ui_act("toggle", list(), ui), "The server action must reject an unauthorized transmitter toggle")
		TEST_ASSERT(transponder.enabled, "A denied transmitter toggle must leave the transmitter enabled")
		card.set_access(list(ACCESS_CENT_GENERAL), FORCE_ADD_ALL)
		TEST_ASSERT(transponder.ui_act("toggle", list(), ui), "The server action must accept authorized transmitter control")
		TEST_ASSERT(!transponder.enabled, "An authorized toggle must actually disable transmission")

/datum/unit_test/overmap_argos_access/Destroy()
	if(original_area && test_area)
		run_loc_floor_bottom_left.change_area(test_area, original_area)
	original_area = null
	test_area = null
	return ..()
