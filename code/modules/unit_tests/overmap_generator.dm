/// A real cable node and a fuelled ship PACMAN on the existing isolated hull fixture.
/datum/unit_test/overmap_standard_dock/ship_generator
	abstract_type = /datum/unit_test/overmap_standard_dock/ship_generator
	/// Native generator and its cable, removed before restoring fixture turfs.
	var/obj/machinery/power/port_gen/pacman/ship/generator
	var/obj/structure/cable/cable
	/// A consistent operator with real tool/item interactions and an unopened native TGUI session.
	var/mob/living/carbon/human/operator
	var/datum/tgui/ui
	/// Owned installation objects needing cleanup before the hull fixture.
	var/list/installation = list()

/datum/unit_test/overmap_standard_dock/ship_generator/New()
	..()
	var/turf/mount = locate(ship.x + 2, ship.y + 5, ship.z)
	cable = allocate(/obj/structure/cable, mount)
	cable.propagate_if_no_network()
	generator = allocate(/obj/machinery/power/port_gen/pacman/ship, mount)
	generator.set_anchored(TRUE)
	STOP_PROCESSING(SSmachines, generator)
	operator = allocate(/mob/living/carbon/human/consistent, get_step(mount, WEST))
	ADD_TRAIT(operator, TRAIT_NOBREATH, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(operator, TRAIT_RESISTLOWPRESSURE, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(operator, TRAIT_RESISTCOLD, TRAIT_SOURCE_UNIT_TESTS)
	ui = allocate(/datum/tgui, operator, generator, "PortableGenerator")
	installation += list(ui, generator, cable)

/datum/unit_test/overmap_standard_dock/ship_generator/Destroy()
	QDEL_LIST(installation)
	generator = null
	cable = null
	operator = null
	ui = null
	return ..()

/// Load physical sheets through the same item entry point used by a player.
/datum/unit_test/overmap_standard_dock/ship_generator/proc/load_fuel(amount)
	var/obj/item/stack/sheet/mineral/plasma/fuel = allocate(/obj/item/stack/sheet/mineral/plasma, null, amount)
	operator.put_in_hands(fuel)
	fuel.melee_attack_chain(operator, generator, list())

/// Physical fuel becomes grid energy at the rated power, regardless of processing interval length.
/datum/unit_test/overmap_standard_dock/ship_generator/metering/Run()
	TEST_ASSERT_EQUAL(generator.powernet, cable.powernet, "Anchoring must connect the generator through the real cable")
	TEST_ASSERT(findtext(jointext(generator.examine(operator), " "), "200 kW"), "Examination must report nominal watts without dividing by the machine interval")
	load_fuel(50)
	generator.ui_act("ship_auto", list(), ui)
	generator.TogglePower()
	STOP_PROCESSING(SSmachines, generator)
	generator.process(1200)
	TEST_ASSERT_EQUAL(generator.powernet.newavail, 240 MEGA JOULES, "Fifty physical sheets must deliver twenty minutes of nominal 200 kW energy")
	TEST_ASSERT(!generator.active && !generator.HasFuel(), "An empty bunker must stop the generator")
	var/energy_before = generator.powernet.newavail
	generator.process(2)
	TEST_ASSERT_EQUAL(generator.powernet.newavail, energy_before, "The empty generator must not supply free power")

	load_fuel(1)
	generator.TogglePower()
	STOP_PROCESSING(SSmachines, generator)
	generator.process(4)
	var/fuel_after_long_tick = generator.sheets + generator.sheet_left
	var/energy_after_long_tick = generator.powernet.newavail - energy_before
	generator.TogglePower()
	generator.DropFuel()
	// Compare against a separate machine so no fuel or grid energy is reset by the fixture.
	var/obj/machinery/power/port_gen/pacman/ship/second = allocate(/obj/machinery/power/port_gen/pacman/ship, locate(ship.x + 4, ship.y + 9, ship.z))
	var/obj/structure/cable/second_cable = allocate(/obj/structure/cable, second.loc)
	second_cable.propagate_if_no_network()
	second.set_anchored(TRUE)
	installation += list(second, second_cable)
	var/obj/item/stack/sheet/mineral/plasma/second_fuel = allocate(/obj/item/stack/sheet/mineral/plasma, null, 1)
	operator.forceMove(get_step(second, WEST))
	operator.put_in_hands(second_fuel)
	second_fuel.melee_attack_chain(operator, second, list())
	second.auto_mode = FALSE
	second.TogglePower()
	STOP_PROCESSING(SSmachines, second)
	for(var/tick in 1 to 4)
		second.process(1)
	TEST_ASSERT(abs(second.sheets + second.sheet_left - fuel_after_long_tick) < 0.00001, "Splitting the interval must preserve fuel consumption within float precision")
	TEST_ASSERT_EQUAL(second.powernet.newavail, energy_after_long_tick, "Splitting the interval must preserve electrical energy")
	generator.TogglePower()
	STOP_PROCESSING(SSmachines, generator)
	generator.process(24)
	TEST_ASSERT(!generator.active && !generator.HasFuel(), "An undersupplied final interval must exhaust the remaining sheet fraction")
	TEST_ASSERT_EQUAL(generator.powernet.newavail - energy_before, 4.8 MEGA JOULES, "A partly burned sheet must yield only its remaining energy, not a full final interval")

/// Auto mode follows a real SMES input and returns to idle once its physical cells are full.
/datum/unit_test/overmap_standard_dock/ship_generator/charging/Run()
	var/obj/machinery/power/terminal/terminal = allocate(/obj/machinery/power/terminal, generator.loc)
	terminal.setDir(EAST)
	terminal.connect_to_network()
	var/obj/machinery/power/smes/battery = allocate(/obj/machinery/power/smes, get_step(generator, EAST))
	STOP_PROCESSING(SSmachines, battery)
	installation += list(battery, terminal)
	TEST_ASSERT_EQUAL(battery.terminal, terminal, "The SMES needs its real native input terminal")
	TEST_ASSERT(battery.is_operational, "The charging fixture must have an operational SMES")
	for(var/obj/item/stock_parts/power_store/cell in battery.component_parts)
		cell.use(cell.charge())
	battery.input_level = 100 KILO WATTS
	battery.output_attempt = FALSE
	load_fuel(5)
	generator.TogglePower()
	STOP_PROCESSING(SSmachines, generator)
	generator.process(2)
	TEST_ASSERT_EQUAL(generator.generated_power, 100 KILO WATTS, "Unmet SMES charging must request power even on a dead grid")
	generator.powernet.reset()
	battery.process(2)
	var/stored_charge = 0
	for(var/obj/item/stock_parts/power_store/cell in battery.component_parts)
		stored_charge += cell.charge()
	TEST_ASSERT(stored_charge > 0, "Generated energy must actually charge native SMES cells")
	for(var/obj/item/stock_parts/power_store/battery_cell in battery.component_parts)
		battery_cell.give(battery_cell.max_charge())
	for(var/tick in 1 to 3)
		generator.process(2)
		generator.powernet.reset()
		battery.process(2)
	generator.process(2)
	TEST_ASSERT_EQUAL(generator.generated_power, 10 KILO WATTS, "A full SMES on an otherwise idle grid must stop requesting nominal output")
	terminal.add_load(power_to_energy(400 KILO WATTS))
	generator.powernet.reset()
	generator.process(2)
	TEST_ASSERT_EQUAL(generator.generated_power, 200 KILO WATTS, "Auto mode must cover a new load only up to nominal power")
	TEST_ASSERT(!generator.overload, "Auto mode must not grant overload permission")

/// Manual overload, forged legacy controls, thermal derating, trip, cooldown and deliberate safety bypass.
/datum/unit_test/overmap_standard_dock/ship_generator/protection/Run()
	load_fuel(20)
	ui.status = UI_CLOSE
	generator.ui_act("ship_overload", list(), ui)
	TEST_ASSERT(!generator.overload, "A noninteractive TGUI must not enable overload")
	ui.status = UI_INTERACTIVE
	for(var/request in 1 to 10)
		generator.ui_act("higher_power", list(), ui)
	TEST_ASSERT_EQUAL(generator.power_output, 1, "Forged legacy PACMAN actions must not bypass the ship controls")
	generator.ui_act("ship_overload", list(), ui)
	TEST_ASSERT(generator.overload && !generator.auto_mode, "An explicit overload order must enter manual mode")
	generator.TogglePower()
	STOP_PROCESSING(SSmachines, generator)
	generator.process(2)
	TEST_ASSERT_EQUAL(generator.generated_power, 300 KILO WATTS, "A manually permitted overload must actually supply 300 kW")
	TEST_ASSERT(20 - generator.sheets - generator.sheet_left > 2 / 24, "Overload must spend more fuel than nominal output")
	generator.process(26)
	generator.ui_act("ship_overload", list(), ui)
	TEST_ASSERT(!generator.overload, "The operator must always be able to revoke permission while hot")
	generator.ui_act("ship_overload", list(), ui)
	TEST_ASSERT(!generator.overload, "A hot protected generator must reject renewed overload permission")
	generator.process(10)
	generator.ui_act("ship_overload", list(), ui)
	for(var/tick in 1 to 30)
		generator.process(2)
	TEST_ASSERT(!generator.overload && generator.active, "Protection must shed overload while preserving nominal operation")
	TEST_ASSERT_EQUAL(generator.generated_power, 200 KILO WATTS, "Thermal derating must return generation to 200 kW")
	var/datum/gas_mixture/room = generator.loc.return_air()
	room.adjust_gas(/datum/gas/nitrogen, 100)
	room.temperature = 1500
	generator.process(8)
	TEST_ASSERT(generator.tripped && !generator.active, "Continuing ambient heating must trip the protected generator")
	generator.TogglePower()
	TEST_ASSERT(!generator.active, "A latched heat trip must prevent a hot restart")
	room.temperature = T20C
	generator.process(100)
	TEST_ASSERT(!generator.tripped, "Cooling below the restart threshold must release the trip")
	generator.ui_act("ship_overload", list(), ui)
	generator.TogglePower()
	STOP_PROCESSING(SSmachines, generator)
	generator.process(200)
	TEST_ASSERT(!QDELETED(generator) && generator.tripped && !generator.active, "Even a long delayed tick must trip working protection before an explosion")
	generator.process(300)
	var/obj/item/card/emag/emag = allocate(/obj/item/card/emag)
	generator.emag_act(operator, emag)
	generator.ui_act("ship_overload", list(), ui)
	generator.TogglePower()
	STOP_PROCESSING(SSmachines, generator)
	generator.process(65)
	TEST_ASSERT(generator.active && !generator.tripped && generator.current_heat > 120, "Deliberately bypassed protection must allow dangerous continued overload")
	TEST_ASSERT_EQUAL(generator.generated_power, 300 KILO WATTS, "Bypassing protection must not unlock unlimited electrical output")

/// A dismantled generator must rebuild with its fixed plasma board rather than PACMAN's switchable profile.
/datum/unit_test/overmap_standard_dock/ship_generator/rebuild/Run()
	generator.deconstruct(TRUE)
	var/obj/structure/frame/machine/frame = locate() in cable.loc
	TEST_ASSERT(frame, "Dismantling must leave a native machine frame")
	installation += frame
	var/obj/item/circuitboard/machine/stationtrauma_ship_generator/board = locate() in cable.loc
	TEST_ASSERT(board, "Dismantling must return the ship generator's own board")
	operator.put_in_hands(board)
	TEST_ASSERT(frame.install_board(operator, board), "The fixed plasma board must fit the native frame")
	for(var/obj/item/part in cable.loc.contents.Copy())
		if(!istype(part, /obj/item/stock_parts) && !istype(part, /obj/item/stack/sheet/iron) && !istype(part, /obj/item/stack/cable_coil))
			continue
		operator.put_in_hands(part)
		part.melee_attack_chain(operator, frame, list())
	var/obj/item/screwdriver/tool = allocate(/obj/item/screwdriver)
	operator.put_in_hands(tool)
	tool.melee_attack_chain(operator, frame, list())
	generator = locate() in cable.loc
	TEST_ASSERT(generator, "Native construction must restore the ship generator")
	installation += generator
	TEST_ASSERT_EQUAL(generator.powernet, cable.powernet, "The rebuilt generator must reconnect to its cable")
	load_fuel(1)
	generator.TogglePower()
	STOP_PROCESSING(SSmachines, generator)
	generator.process(2)
	TEST_ASSERT(generator.generated_power > 0, "The rebuilt installation must produce real fuelled power")
