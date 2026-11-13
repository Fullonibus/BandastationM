/// Real plasma pipes and a finite native SMES supply on the existing isolated nozzle fixture.
/datum/unit_test/overmap_standard_dock/nozzles/plasma_supply
	abstract_type = /datum/unit_test/overmap_standard_dock/nozzles/plasma_supply
	/// Electrical propulsion source replacing the fixture's fusion core.
	var/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/block
	/// Physical battery cells supply the actual cable grid.
	var/obj/machinery/power/smes/battery
	var/obj/structure/cable/supply

/datum/unit_test/overmap_standard_dock/nozzles/plasma_supply/New()
	..()
	var/turf/mount = get_turf(reactor)
	qdel(reactor)
	block = allocate(/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma, mount)
	reactor = block
	block.setDir(SOUTH)
	block.set_init_directions()
	block.connect_to_shuttle(FALSE, ship)
	block.auto = FALSE
	block.active = TRUE
	STOP_PROCESSING(SSmachines, block)
	installation += block
	replace_feed(/obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma_block)
	var/datum/gas_mixture/fuel = block.parents[1].air
	fuel.temperature = T20C
	fuel.adjust_gas(/datum/gas/plasma, 1000)
	block.parents[1].reconcile_air()
	supply = allocate(/obj/structure/cable, mount)
	var/obj/structure/cable/battery_cable = allocate(/obj/structure/cable, get_step(mount, WEST))
	var/obj/machinery/power/terminal/terminal = allocate(/obj/machinery/power/terminal, get_step(battery_cable, WEST))
	terminal.setDir(EAST)
	supply.propagate_if_no_network()
	battery_cable.propagate_if_no_network()
	battery = allocate(/obj/machinery/power/smes, battery_cable.loc)
	battery.on_construction()
	battery.output_level = 300 KILO WATTS
	battery.input_attempt = FALSE
	for(var/obj/item/stock_parts/power_store/cell in battery.component_parts)
		cell.give(cell.max_charge())
	STOP_PROCESSING(SSmachines, battery)
	installation += list(battery, terminal, battery_cable, supply)

/datum/unit_test/overmap_standard_dock/nozzles/plasma_supply/Destroy()
	block = null
	battery = null
	supply = null
	return ..()

/// Advance real stored energy and real gas; never assign fictitious grid availability.
/datum/unit_test/overmap_standard_dock/nozzles/plasma_supply/proc/burn()
	battery.process(2)
	supply.powernet.reset()
	block.parents[1].reconcile_air()
	block.process(2)
	block.parents[2].reconcile_air()
	feed.process_atmos(2)

/// Electrical heat becomes thrust, with no free electricity, nuclear reaction or fuel consumption on a dead grid.
/datum/unit_test/overmap_standard_dock/nozzles/plasma_supply/energy/Run()
	TEST_ASSERT_EQUAL(battery.powernet, supply.powernet, "The heater must receive the physical SMES output")
	TEST_ASSERT(battery.is_operational && battery.terminal, "The fixture needs a real operational battery")
	var/list/readings = battery.ui_data()
	var/initial_charge = readings["charge"]
	for(var/interval in 1 to 4)
		burn()
	TEST_ASSERT(block.power_draw > 0 && block.power_draw <= 170 KILO WATTS, "The block must pay for actual plasma heating within its nominal rating")
	readings = battery.ui_data()
	TEST_ASSERT(readings["charge"] < initial_charge, "Propulsion must spend finite stored electrical energy")
	TEST_ASSERT_EQUAL(supply.powernet.newavail, 0, "An electrical heater must never generate grid energy")
	TEST_ASSERT_EQUAL(block.radiation_range(), 0, "An electrical block must not emit fusion radiation")
	TEST_ASSERT_EQUAL(block.airs[2].moles[/datum/gas/helium] || 0, 0, "Heating plasma must not create helium")
	var/nominal = nozzle.engine_power * navigation.engine_output(nozzle)
	TEST_ASSERT(nominal > 0 && nominal <= 2, "Actual heated plasma must supply nominal standard-nozzle thrust")
	block.overdrive = TRUE
	burn()
	TEST_ASSERT(block.fuel_flow > 2.6 && block.power_draw > 170 KILO WATTS, "Helm boost must spend additional gas and electricity")
	TEST_ASSERT(nozzle.engine_power * navigation.engine_output(nozzle) > nominal, "Additional real supply must increase delivered thrust")
	supply.powernet.reset()
	var/remaining = block.airs[1].moles[/datum/gas/plasma]
	block.process(2)
	TEST_ASSERT_EQUAL(block.power_draw, 0, "A dead grid must stop electrical heating")
	TEST_ASSERT_EQUAL(block.airs[1].moles[/datum/gas/plasma], remaining, "A dead grid must not consume additional source gas")
	block.active = FALSE
	TEST_ASSERT_EQUAL(navigation.engine_output(nozzle), 0, "Stopping the source must immediately deny thrust from its remaining buffer")

/// Healthy protection trips before a leak; breaking the real casing releases its actual plasma.
/datum/unit_test/overmap_standard_dock/nozzles/plasma_supply/protection/Run()
	burn()
	var/datum/gas_mixture/room = block.loc.return_air()
	room.adjust_gas(/datum/gas/oxygen, 100)
	room.temperature = 1500
	block.process(20)
	TEST_ASSERT(block.tripped && !block.active && !block.leaking, "Healthy thermal protection must stop the block before catastrophic overheating")
	room.temperature = T20C
	block.process(300)
	TEST_ASSERT(!block.tripped, "A cold protected block must permit restarting")
	var/level_before = block.level
	block.control("level", list("value" = "forged"))
	TEST_ASSERT_EQUAL(block.level, level_before, "Untrusted nonnumeric controls must be rejected")
	room.temperature = 1500
	block.take_damage(250, BRUTE, MELEE, FALSE, SOUTH, 100)
	TEST_ASSERT(block.leaking && (block.machine_stat & BROKEN), "A heavily damaged real casing must leak")
	var/before_leak = room.moles[/datum/gas/plasma] || 0
	block.process(2)
	TEST_ASSERT(room.moles[/datum/gas/plasma] > before_leak, "A breached block must spill its own actual gas into the compartment")
	var/turf/open/ground = get_turf(block)
	TEST_ASSERT(ground.active_hotspot, "Escaping hot plasma in oxygen must ignite native gas fire")
	installation += ground.active_hotspot

/// Native dropped parts rebuild the electrical block, which can then be oriented back onto its real pipes.
/datum/unit_test/overmap_standard_dock/nozzles/plasma_supply/rebuild/Run()
	var/turf/mount = get_turf(block)
	var/mob/living/carbon/human/builder = allocate(/mob/living/carbon/human/consistent, get_step(mount, WEST))
	ADD_TRAIT(builder, TRAIT_NOBREATH, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(builder, TRAIT_RESISTLOWPRESSURE, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(builder, TRAIT_RESISTCOLD, TRAIT_SOURCE_UNIT_TESTS)
	var/obj/item/screwdriver/screwdriver = allocate(/obj/item/screwdriver)
	var/obj/item/wrench/wrench = allocate(/obj/item/wrench)
	block.deconstruct(TRUE)
	var/obj/structure/frame/machine/frame = locate() in mount
	installation += frame
	TEST_ASSERT(frame, "Deconstruction must preserve a real rebuildable frame")
	var/obj/item/circuitboard/machine/board = locate() in mount
	builder.put_in_hands(board)
	TEST_ASSERT(frame.install_board(builder, board), "The dropped plasma board must fit the native frame")
	for(var/obj/item/part in mount.contents.Copy())
		if(!istype(part, /obj/item/stock_parts) && !istype(part, /obj/item/stack))
			continue
		builder.put_in_hands(part)
		part.melee_attack_chain(builder, frame, list())
	builder.put_in_hands(screwdriver)
	screwdriver.melee_attack_chain(builder, frame, list())
	block = locate(/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma) in mount
	TEST_ASSERT(block, "The native frame must rebuild the electrical subtype")
	reactor = block
	installation += block
	STOP_PROCESSING(SSmachines, block)
	screwdriver.melee_attack_chain(builder, block, list())
	builder.put_in_hands(wrench)
	for(var/quarter_turn in 1 to 4)
		wrench.melee_attack_chain(builder, block, list())
		TEST_ASSERT_EQUAL(block.bound_width * block.bound_height, 3 * ICON_SIZE_X * ICON_SIZE_Y, "Rotation must preserve the compact three-tile footprint")
	while(block.dir != SOUTH)
		wrench.melee_attack_chain(builder, block, list())
	builder.put_in_hands(screwdriver)
	screwdriver.melee_attack_chain(builder, block, list())
	for(var/obj/machinery/atmospherics/part as anything in list(block, inlet, outlet, feed))
		part.atmos_init()
		SSair.add_to_rebuild_queue(part)
	var/deadline = world.time + 5 SECONDS
	UNTIL((block.parents[1] && block.parents[2] && feed.parents[1] && !block.parents[1].building && !block.parents[2].building && !feed.parents[1].building) || world.time >= deadline)
	block.bind_converters()
	TEST_ASSERT(block.nodes[1] == inlet && block.nodes[2] == outlet, "The rebuilt oriented block must reconnect to the actual inlet and outlet")
	TEST_ASSERT_EQUAL(ship.fusion_core?.resolve(), block, "The rebuilt block must register on the same hull")
	block.active = TRUE
	block.auto = FALSE
	for(var/interval in 1 to 4)
		burn()
	TEST_ASSERT(navigation.engine_output(nozzle) > 0, "The rebuilt electrical installation must resume actual gas-powered thrust: [feed.unavailable_reason()], fuel=[block.airs[1].moles[/datum/gas/plasma]], power=[block.power_draw], output=[block.output], delivered=[feed.delivered_fraction]")

/// A physical quarter-turn must preserve a restricted fuel pipe and directional electrical isolation.
/datum/unit_test/overmap_standard_dock/nozzles/plasma_supply/rotation
	/// Native ports refuse ordinary qdel, so teardown must explicitly release this fixture's berth.
	var/obj/docking_port/stationary/stationtrauma_space_surface/pad

/datum/unit_test/overmap_standard_dock/nozzles/plasma_supply/rotation/Destroy()
	if(pad)
		qdel(pad, force = TRUE)
		pad = null
	return ..()

/datum/unit_test/overmap_standard_dock/nozzles/plasma_supply/rotation/Run()
	inlet.set_init_directions(NORTH|SOUTH)
	supply.banned_links = NORTH|SOUTH|EAST
	var/list/branch = list()
	for(var/row in outlet.y to inlet.y)
		var/obj/machinery/atmospherics/pipe/smart/pipe = allocate(/obj/machinery/atmospherics/pipe/smart, locate(outlet.x + 1, row, outlet.z))
		branch += pipe
		installation += pipe
	for(var/obj/machinery/atmospherics/pipe/smart/pipe as anything in branch)
		pipe.atmos_init()
	replace_feed(/obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma_block)
	TEST_ASSERT(block.parents[1] != block.parents[2], "The restricted inlet must separate adjacent cold and hot networks")
	pad = allocate(/obj/docking_port/stationary/stationtrauma_space_surface, locate(40, 40, ship.z))
	pad.width = ship.width
	pad.height = ship.height
	pad.dwidth = ship.dwidth
	pad.dheight = ship.dheight
	pad.setDir(turn(ship.dir, 90))
	var/list/bounds = pad.return_coords()
	prepare_vacuum(locate(min(bounds[1], bounds[3]) - 1, min(bounds[2], bounds[4]) - 1, pad.z), locate(max(bounds[1], bounds[3]) + 1, max(bounds[2], bounds[4]) + 1, pad.z), navigation.exterior)
	site.berth = pad
	navigation.selected_destination = site.id
	TEST_ASSERT(navigation.relocate(pad), "The installation must rotate through actual native hull movement")
	TEST_ASSERT(block.parents[1] != block.parents[2], "Hull rotation must not turn a restricted pipe into an unrestricted bypass")
	var/deadline = world.time + 5 SECONDS
	UNTIL(supply.powernet == battery.powernet || world.time >= deadline)
	TEST_ASSERT_EQUAL(supply.powernet, battery.powernet, "The rotated cable cut must still allow the intended finite battery supply")
	for(var/interval in 1 to 4)
		burn()
	TEST_ASSERT(navigation.engine_output(nozzle) > 0, "The rotated real gas and electrical networks must continue to supply thrust")
