/// Real gas networks supplying interchangeable nozzles on the existing isolated hull fixture.
/datum/unit_test/overmap_standard_dock/nozzles
	abstract_type = /datum/unit_test/overmap_standard_dock/nozzles
	/// Standard nozzle size under test.
	var/obj/machinery/power/shuttle_engine/nozzle_type = /obj/machinery/power/shuttle_engine/propulsion/standard
	/// Actual nozzle, registered through the native construction hook.
	var/obj/machinery/power/shuttle_engine/nozzle
	/// Actual core producing helium for the fusion converter cases.
	var/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/reactor
	/// Current replaceable converter.
	var/obj/machinery/atmospherics/components/unary/ship_engine_heater/feed
	/// Native inlet and outlet pipes shared across converter replacements.
	var/obj/machinery/atmospherics/pipe/smart/inlet
	var/obj/machinery/atmospherics/pipe/smart/outlet
	/// Remove the gas installation before the parent restores its fixture turfs.
	var/list/installation = list()

/datum/unit_test/overmap_standard_dock/nozzles/New()
	..()
	var/nozzle_y = ship.y + 7 - initial(nozzle_type.bound_height) / ICON_SIZE_Y
	nozzle = allocate(nozzle_type, locate(ship.x + 3, nozzle_y, ship.z))
	nozzle.anchored = TRUE
	nozzle.on_construction()
	nozzle.engine_state = initial(nozzle.engine_state)
	nozzle.alter_engine_power(nozzle.engine_power)
	reactor = allocate(/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core, locate(ship.x + 3, ship.y + 10, ship.z))
	STOP_PROCESSING(SSmachines, reactor)
	inlet = allocate(/obj/machinery/atmospherics/pipe/smart, locate(reactor.x, reactor.y + 2, reactor.z))
	outlet = allocate(/obj/machinery/atmospherics/pipe/smart, locate(reactor.x, reactor.y - 2, reactor.z))
	installation += list(nozzle, reactor, inlet, outlet)
	reactor.connect_to_shuttle(FALSE, ship)
	reactor.auto = FALSE
	navigation.helm_engaged = TRUE
	navigation.throttle = 100
	ship.engines_running = TRUE

/datum/unit_test/overmap_standard_dock/nozzles/Destroy()
	QDEL_LIST(installation)
	nozzle = null
	reactor = null
	feed = null
	inlet = null
	outlet = null
	return ..()

/// Replace a real converter and rebuild its native pipenet, without assigning fake nodes or parents.
/datum/unit_test/overmap_standard_dock/nozzles/proc/replace_feed(feed_type)
	if(feed)
		qdel(feed)
	var/datum/pipeline/old_network = outlet.return_pipenet()
	if(old_network)
		qdel(old_network)
	feed = allocate(feed_type, locate(reactor.x, reactor.y - 3, reactor.z))
	installation += feed
	SSair.stop_processing_machine(feed)
	// Runtime rebuilds may run across yields; finish node discovery before queuing the complete installation.
	var/list/parts = list(reactor, inlet, outlet, feed)
	for(var/obj/machinery/atmospherics/part as anything in parts)
		part.atmos_init()
		SSair.add_to_rebuild_queue(part)
	var/deadline = world.time + 5 SECONDS
	UNTIL((reactor.parents[1] && reactor.parents[2] && feed.parents[1] && !reactor.parents[1].building && !reactor.parents[2].building && !feed.parents[1].building) || world.time >= deadline)
	TEST_ASSERT(reactor.parents[1] && reactor.parents[2] && feed.parents[1], "The native runtime rebuild must connect the complete installation")
	reactor.bind_converters()
	ship.bind_plasma_heaters()

/datum/unit_test/overmap_standard_dock/nozzles/Run()
	TEST_ASSERT_EQUAL(navigation.engine_output(nozzle), 0, "An unfed standard nozzle must not provide free thrust")
	var/list/converters = list(
		/obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma = 1,
		/obj/machinery/atmospherics/components/unary/ship_engine_heater = 2,
		/obj/machinery/atmospherics/components/unary/ship_engine_heater/large = 8,
	)
	for(var/feed_type in converters)
		replace_feed(feed_type)
		TEST_ASSERT_EQUAL(nozzle.combustion_feed?.resolve(), feed, "The real replacement converter did not bind to [nozzle.type]")
		TEST_ASSERT(feed.parents[1] && feed.nodes[1], "The replacement converter needs a real pipe connection")
		var/is_plasma = istype(feed, /obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma)
		for(var/datum/gas_mixture/parcel as anything in feed.parents[1].return_air())
			var/datum/gas_mixture/discarded = parcel.remove(parcel.total_moles())
			qdel(discarded)
		var/datum/gas_mixture/pipe_gas = feed.parents[1].air
		if(is_plasma)
			reactor.active = FALSE
			pipe_gas.temperature = T20C
			pipe_gas.adjust_gas(/datum/gas/plasma, 100)
		else
			reactor.active = TRUE
			var/datum/gas_mixture/fuel = reactor.airs[1]
			fuel.adjust_gas(/datum/gas/tritium, 10)
			// Fill the native buffer before measuring a one-second exhaust pulse.
			reactor.process(2)
			TEST_ASSERT(reactor.output > 0, "The fusion case needs an actual tritium reaction")
		feed.parents[1].reconcile_air()
		feed.process_atmos(1)
		var/delivered_power = nozzle.engine_power * navigation.engine_output(nozzle)
		TEST_ASSERT(delivered_power > 0, "[feed_type] did not deliver actual gas-powered thrust")
		var/power_limit = min(converters[feed_type], nozzle.engine_power)
		TEST_ASSERT(delivered_power <= power_limit, "A larger nozzle must not create power missing from its converter")
		if(!is_plasma)
			TEST_ASSERT_EQUAL(delivered_power, power_limit, "Adequate fusion supply must reach the lower of converter and nozzle ratings")
			reactor.overdrive = TRUE
			TEST_ASSERT_EQUAL(nozzle.engine_power * navigation.engine_output(nozzle), power_limit * 1.5, "The shared source hook must preserve the existing fusion afterburner gain")
			reactor.overdrive = FALSE
		navigation.refresh_engine_exhaust()
		TEST_ASSERT(nozzle.exhaust, "The fed nozzle must display an actual exhaust emitter")
		TEST_ASSERT_EQUAL(nozzle.last_exhaust_gradient, feed.exhaust_gradient, "Changing the converter must change the same nozzle's plume palette")
		if(is_plasma)
			var/area/hull_area = get_area(feed)
			hull_area.requires_power = TRUE
			hull_area.power_equip = FALSE
			hull_area.power_environ = FALSE
			feed.power_change()
			var/remaining_gas = feed.airs[1].total_moles()
			feed.process_atmos(1)
			TEST_ASSERT_EQUAL(navigation.engine_output(nozzle), 0, "The plasma converter must lose thrust during a real equipment-power failure")
			TEST_ASSERT_EQUAL(feed.airs[1].total_moles(), remaining_gas, "An unpowered converter must stop consuming propellant")
			hull_area.requires_power = FALSE
			feed.power_change()
		qdel(feed)
		feed = null
		TEST_ASSERT_EQUAL(navigation.engine_output(nozzle), 0, "Removing a converter must immediately remove its delivered thrust")
		navigation.refresh_engine_exhaust()
		TEST_ASSERT_NULL(nozzle.exhaust, "An unfed nozzle must stop its exhaust emitter")
	rebuild_nozzle()

/// Dismantle the actual nozzle and rebuild it with its dropped board and parts through native frame/tool entry points.
/datum/unit_test/overmap_standard_dock/nozzles/proc/rebuild_nozzle()
	var/turf/mount = get_turf(nozzle)
	var/mob/living/carbon/human/builder = allocate(/mob/living/carbon/human/consistent, get_step(mount, WEST))
	ADD_TRAIT(builder, TRAIT_NOBREATH, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(builder, TRAIT_RESISTLOWPRESSURE, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(builder, TRAIT_RESISTCOLD, TRAIT_SOURCE_UNIT_TESTS)
	var/obj/item/screwdriver/screwdriver = allocate(/obj/item/screwdriver)
	var/obj/item/weldingtool/experimental/welder = allocate(/obj/item/weldingtool/experimental)
	// Tool duration is unrelated to the board and registration contract.
	welder.toolspeed = 0
	nozzle.deconstruct(TRUE)
	nozzle = null
	var/obj/structure/frame/machine/frame = locate() in mount
	TEST_ASSERT(frame, "Dismantling a standard nozzle must leave a rebuildable machine frame")
	installation += frame
	var/obj/item/circuitboard/machine/board = locate() in mount
	TEST_ASSERT(board, "Dismantling the nozzle must preserve its circuit board")
	builder.put_in_hands(board)
	TEST_ASSERT(frame.install_board(builder, board), "The dropped standard board must fit back in the native frame")
	for(var/obj/item/stock_parts/part in mount.contents.Copy())
		builder.put_in_hands(part)
		part.melee_attack_chain(builder, frame, list())
	builder.put_in_hands(screwdriver)
	screwdriver.melee_attack_chain(builder, frame, list())
	nozzle = locate(nozzle_type) in mount
	TEST_ASSERT(nozzle, "Native construction must rebuild the correct standard nozzle size")
	installation += nozzle
	builder.put_in_hands(welder)
	welder.attack_self(builder)
	welder.melee_attack_chain(builder, nozzle, list())
	TEST_ASSERT_EQUAL(nozzle.connected_ship, ship, "The rebuilt nozzle must register on its actual hull")
	TEST_ASSERT_EQUAL(navigation.engine_output(nozzle), 0, "Rebuilding a nozzle must not grant thrust without a converter")
	replace_feed(/obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma)
	var/datum/gas_mixture/supply = feed.parents[1].air
	supply.temperature = T20C
	supply.adjust_gas(/datum/gas/plasma, 100)
	feed.parents[1].reconcile_air()
	feed.process_atmos(1)
	TEST_ASSERT(navigation.engine_output(nozzle) > 0, "The rebuilt standard nozzle must resume actual plasma-powered thrust")

/// Small standard nozzle accepts either feed while retaining its own thrust ceiling.
/datum/unit_test/overmap_standard_dock/nozzles/small

/// Protection and shutdown must leave time to recover from a deliberate nuclear-core safety bypass.
/datum/unit_test/overmap_standard_dock/nozzles/fusion_safety/Run()
	var/datum/gas_mixture/fuel = reactor.airs[1]
	fuel.adjust_gas(/datum/gas/tritium, 10000)
	reactor.auto = FALSE
	reactor.control("level", list("value" = 150))
	reactor.control("power", list())
	reactor.toggle_overdrive()
	reactor.process(200)
	TEST_ASSERT(!QDELETED(reactor) && reactor.tripped && !reactor.active, "Working protection must trip safely even after a long processing interval")
	TEST_ASSERT_EQUAL(reactor.meltdown_deadline, 0, "Working protection must not arm a catastrophic countdown")
	reactor.process(300)
	reactor.control("interlock", list())
	reactor.control("power", list())
	reactor.toggle_overdrive()
	reactor.heat = 199
	reactor.process(2)
	TEST_ASSERT(!QDELETED(reactor), "The first unprotected critical tick must warn rather than explode")
	var/deadline = reactor.meltdown_deadline
	TEST_ASSERT_EQUAL(deadline, world.time + 60 SECONDS, "The engineer must have a real minute after the warning")
	reactor.process(120)
	TEST_ASSERT(!QDELETED(reactor), "A large physics interval must not skip the real warning grace period")
	reactor.control("power", list())
	reactor.process(2)
	TEST_ASSERT(!QDELETED(reactor) && !reactor.active, "An engineer must be able to stop the hot reaction")
	reactor.control("power", list())
	reactor.process(2)
	TEST_ASSERT_EQUAL(reactor.meltdown_deadline, deadline, "Toggling a still-hot reaction must not reset its warning deadline")
	reactor.control("power", list())
	reactor.process(300)
	TEST_ASSERT_EQUAL(reactor.meltdown_deadline, 0, "Stopping and actually cooling the core must clear the emergency")

/// A large standard nozzle remains limited by a small or plasma converter.
/datum/unit_test/overmap_standard_dock/nozzles/large
	nozzle_type = /obj/machinery/power/shuttle_engine/large/standard

/// A three-by-three nozzle must bind beyond its full footprint and remain limited by its converter.
/datum/unit_test/overmap_standard_dock/nozzles/huge
	nozzle_type = /obj/machinery/power/shuttle_engine/huge/standard

/// Cosmetic variants must retain their particular shape through the real board/frame rebuild.
/datum/unit_test/overmap_standard_dock/nozzles/variants/Run()
	var/list/variants = list(
		/obj/machinery/power/shuttle_engine/propulsion/standard/left,
		/obj/machinery/power/shuttle_engine/propulsion/standard/right,
		/obj/machinery/power/shuttle_engine/propulsion/standard/burst,
		/obj/machinery/power/shuttle_engine/propulsion/standard/burst/left,
		/obj/machinery/power/shuttle_engine/propulsion/standard/burst/right,
	)
	var/turf/mount = get_turf(nozzle)
	for(var/variant in variants)
		QDEL_NULL(feed)
		qdel(nozzle)
		nozzle_type = variant
		nozzle = allocate(nozzle_type, mount)
		nozzle.anchored = TRUE
		nozzle.on_construction()
		installation += nozzle
		rebuild_nozzle()
