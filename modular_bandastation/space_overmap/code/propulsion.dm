/** Native engine registration stays nominal; the overmap reads delivered gas power separately. */
/obj/machinery/power/shuttle_engine
	/// Ordinary shuttle engines retain their original unlimited propellant behaviour.
	var/requires_combustion = FALSE
	/// Gas receiver supplying this nozzle, without retaining a dismantled machine.
	var/datum/weakref/combustion_feed
	/// Exhaust plume shown while the nozzle delivers commanded thrust.
	var/mutable_appearance/exhaust
	/// Plume colours from the nozzle outward; bluespace drives by default.
	var/list/exhaust_gradient = list("#FFFFFF", "#9FF4FF", "#2F8CFF")
	/// Last feed palette, so changing converters refreshes an already firing plume.
	var/list/last_exhaust_gradient
	/// Engineer's switch on the engine console; a switched-off nozzle gives no thrust and takes no gas.
	var/crew_enabled = TRUE

/obj/machinery/power/shuttle_engine/Destroy(force)
	exhaust = null
	return ..()

/**
 * Display a looping flame at the outlet, scaled to the nozzle width.
 *
 * Arguments:
 * * thrust - Fraction of full thrust currently delivered
 * * boosted - Whether the supplying fusion core is in overdrive
 * * gradient - Core, middle and rim colours supplied by the converter
 */
/obj/machinery/power/shuttle_engine/proc/set_exhaust(thrust, boosted = FALSE, list/gradient)
	if(thrust <= 0)
		if(exhaust)
			cut_overlay(exhaust)
			exhaust = null
			last_exhaust_gradient = null
			set_light(0)
		return

	var/static/list/afterburner_gradient = list("#FFFFFF", "#C9FFB8", "#2BD23C")
	gradient = boosted ? afterburner_gradient : (gradient || exhaust_gradient)
	var/flame_state = "[clamp(CEILING(thrust * 3, 1), 1, 3)]"
	if(exhaust && exhaust.icon_state == flame_state && exhaust.dir == dir && last_exhaust_gradient == gradient)
		return
	if(exhaust)
		cut_overlay(exhaust)
	last_exhaust_gradient = gradient
	exhaust = make_mutable_appearance_directional(mutable_appearance('modular_bandastation/space_overmap/icons/nozzle_flame.dmi', flame_state), dir)
	// The sprite starts at the near edge of the tile immediately outside the nozzle.
	var/list/offset = dir2offset(dir)
	exhaust.pixel_x = (bound_width - ICON_SIZE_X + offset[1] * (bound_width + ICON_SIZE_X)) / 2
	exhaust.pixel_y = (bound_height - ICON_SIZE_Y + offset[2] * (bound_height + ICON_SIZE_Y)) / 2
	exhaust.transform = matrix().Scale(offset[1] ? 1 : bound_width / ICON_SIZE_X, offset[2] ? 1 : bound_height / ICON_SIZE_Y)
	// The sprite's RGB channels mask the hot core, middle flame and outer rim.
	exhaust.color = gradient
	add_overlay(exhaust)
	set_light(2, 1, gradient[2])

/** Standard small nozzle; the converter determines its working fluid and delivered thrust. */
/obj/machinery/power/shuttle_engine/propulsion/standard
	name = "малое корабельное сопло"
	desc = "Стандартное сопло двигательной установки. Требует подачи рабочего тела от преобразователя тяги."
	requires_combustion = TRUE
	circuit = /obj/item/circuitboard/machine/engine/propulsion/standard
	engine_power = 2

/** Standard small nozzle retaining the native left appearance. */
/obj/machinery/power/shuttle_engine/propulsion/standard/left
	name = "левое малое корабельное сопло"
	icon_state = /obj/machinery/power/shuttle_engine/propulsion/left::icon_state
	circuit = /obj/item/circuitboard/machine/engine/propulsion/standard/left

/** Standard small nozzle retaining the native right appearance. */
/obj/machinery/power/shuttle_engine/propulsion/standard/right
	name = "правое малое корабельное сопло"
	icon_state = /obj/machinery/power/shuttle_engine/propulsion/right::icon_state
	circuit = /obj/item/circuitboard/machine/engine/propulsion/standard/right

/** Standard small nozzle retaining the native burst appearance. */
/obj/machinery/power/shuttle_engine/propulsion/standard/burst
	name = "малое корабельное сопло «Burst»"
	icon_state = /obj/machinery/power/shuttle_engine/propulsion/burst::icon_state
	circuit = /obj/item/circuitboard/machine/engine/propulsion/standard/burst

/** Standard small nozzle retaining the native burst/left appearance. */
/obj/machinery/power/shuttle_engine/propulsion/standard/burst/left
	name = "левое корабельное сопло «Burst»"
	icon_state = /obj/machinery/power/shuttle_engine/propulsion/burst/left::icon_state
	circuit = /obj/item/circuitboard/machine/engine/propulsion/standard/burst/left

/** Standard small nozzle retaining the native burst/right appearance. */
/obj/machinery/power/shuttle_engine/propulsion/standard/burst/right
	name = "правое корабельное сопло «Burst»"
	icon_state = /obj/machinery/power/shuttle_engine/propulsion/burst/right::icon_state
	circuit = /obj/item/circuitboard/machine/engine/propulsion/standard/burst/right

/** Standard heavy nozzle retaining the native two-by-two footprint. */
/obj/machinery/power/shuttle_engine/large/standard
	name = "большое корабельное сопло"
	desc = "Тяжёлое стандартное сопло. Доступная тяга ограничена мощностью подключённого преобразователя."
	requires_combustion = TRUE
	circuit = /obj/item/circuitboard/machine/engine/propulsion/standard/large
	// Four small nozzles' footprint.
	engine_power = 8

/** Standard three-by-three nozzle, with the same capacity per tile as the smaller sizes. */
/obj/machinery/power/shuttle_engine/huge/standard
	name = "огромное корабельное сопло"
	desc = "Стандартное сопло для крупных кораблей. Требует подачи рабочего тела от преобразователя тяги."
	requires_combustion = TRUE
	circuit = /obj/item/circuitboard/machine/engine/propulsion/standard/huge
	engine_power = 18

/** Compatibility for maps using the former fuel-specific nozzle paths. */
/obj/machinery/power/shuttle_engine/propulsion/tritium
	parent_type = /obj/machinery/power/shuttle_engine/propulsion/standard

/** Compatibility for the former heavy fusion nozzle. */
/obj/machinery/power/shuttle_engine/large/tritium
	parent_type = /obj/machinery/power/shuttle_engine/large/standard

/**
 * Fuel gauges of real supply networks; each mixture and canister is counted once, including those behind inlet pumps.
 *
 * Arguments:
 * * networks - Pipelines feeding the drive; the list is extended while walking
 * * gases - Gas type to crew-facing name
 *
 * Returns a list of gauges: name, amount in moles and the nominal fill of the connected canisters of that gas.
 */
/proc/stationtrauma_fuel_gauges(list/networks, list/gases)
	var/list/mixtures = list()
	var/list/canisters = list()
	for(var/index = 1; index <= length(networks); index++)
		var/datum/pipeline/network = networks[index]
		if(!network)
			continue
		mixtures |= network.return_air()
		for(var/obj/machinery/atmospherics/components/component as anything in network.other_atmos_machines)
			mixtures |= component.return_airs_for_reconcilation(network)
			networks |= component.return_pipenets_for_reconcilation(network)
			if(istype(component, /obj/machinery/atmospherics/components/binary/pump))
				if(component.parents[2] == network && component.parents[1])
					networks |= component.parents[1]
			else if(istype(component, /obj/machinery/atmospherics/components/unary/portables_connector))
				var/obj/machinery/atmospherics/components/unary/portables_connector/connector = component
				if(istype(connector.connected_device, /obj/machinery/portable_atmospherics/canister))
					canisters |= connector.connected_device
	var/list/gauges = list()
	for(var/gas in gases)
		var/amount = 0
		for(var/datum/gas_mixture/mixture as anything in mixtures)
			amount += mixture.moles[gas]
		// A standard filled canister is the full mark, as TG fills them in create_gas().
		var/capacity = 0
		for(var/obj/machinery/portable_atmospherics/canister/canister as anything in canisters)
			if(canister.gas_type == gas)
				capacity += canister.maximum_pressure * canister.filled * canister.air_contents.volume / (R_IDEAL_GAS_EQUATION * T20C)
		gauges += list(list("name" = gases[gas], "amount" = round(amount, 0.1), "capacity" = round(capacity, 0.1)))
	return gauges

/** Buildable converter using the existing heater appearance. */
/obj/item/circuitboard/machine/engine/heater/combustion
	name = "преобразователь тяги"
	build_path = /obj/machinery/atmospherics/components/unary/ship_engine_heater

/** Rebuilding a standard nozzle retains its requirement for a real converter. */
/obj/item/circuitboard/machine/engine/propulsion/standard
	name = "малое корабельное сопло"
	build_path = /obj/machinery/power/shuttle_engine/propulsion/standard

/** Board preserving the left nozzle during native rebuilding. */
/obj/item/circuitboard/machine/engine/propulsion/standard/left
	name = "левое малое корабельное сопло"
	build_path = /obj/machinery/power/shuttle_engine/propulsion/standard/left

/** Board preserving the right nozzle during native rebuilding. */
/obj/item/circuitboard/machine/engine/propulsion/standard/right
	name = "правое малое корабельное сопло"
	build_path = /obj/machinery/power/shuttle_engine/propulsion/standard/right

/** Board preserving the burst nozzle during native rebuilding. */
/obj/item/circuitboard/machine/engine/propulsion/standard/burst
	name = "малое корабельное сопло «Burst»"
	build_path = /obj/machinery/power/shuttle_engine/propulsion/standard/burst

/** Board preserving the burst/left nozzle during native rebuilding. */
/obj/item/circuitboard/machine/engine/propulsion/standard/burst/left
	name = "левое корабельное сопло «Burst»"
	build_path = /obj/machinery/power/shuttle_engine/propulsion/standard/burst/left

/** Board preserving the burst/right nozzle during native rebuilding. */
/obj/item/circuitboard/machine/engine/propulsion/standard/burst/right
	name = "правое корабельное сопло «Burst»"
	build_path = /obj/machinery/power/shuttle_engine/propulsion/standard/burst/right

/** Heavy standard nozzle board, usable with any compatible converter. */
/obj/item/circuitboard/machine/engine/propulsion/standard/large
	name = "большое корабельное сопло"
	build_path = /obj/machinery/power/shuttle_engine/large/standard

/** Three-by-three nozzle board using the native machine frame. */
/obj/item/circuitboard/machine/engine/propulsion/standard/huge
	name = "огромное корабельное сопло"
	build_path = /obj/machinery/power/shuttle_engine/huge/standard

/** Existing boards rebuild the same standardized hardware as newly printed boards. */
/obj/item/circuitboard/machine/engine/propulsion/tritium
	parent_type = /obj/item/circuitboard/machine/engine/propulsion/standard

/** Compatibility for the former heavy fusion nozzle board. */
/obj/item/circuitboard/machine/engine/propulsion/tritium/large
	parent_type = /obj/item/circuitboard/machine/engine/propulsion/standard/large

/** Buildable heavy converter; its rating is independent of the attached nozzle. */
/obj/item/circuitboard/machine/engine/heater/combustion/large
	name = "большой преобразователь тяги"
	build_path = /obj/machinery/atmospherics/components/unary/ship_engine_heater/large

/** Standard nozzle boards available through shuttle engineering. */
/datum/design/board/stationtrauma_engine
	name = "Плата малого корабельного сопла"
	desc = "Плата стандартного сопла с подачей рабочего тела от преобразователя."
	build_path = /obj/item/circuitboard/machine/engine/propulsion/standard
	build_type = IMPRINTER
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_CARGO | DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_ENGINEERING

/** Printable board for the left small nozzle. */
/datum/design/board/stationtrauma_engine/left
	name = "Плата: левое малое корабельное сопло"
	build_path = /obj/item/circuitboard/machine/engine/propulsion/standard/left

/** Printable board for the right small nozzle. */
/datum/design/board/stationtrauma_engine/right
	name = "Плата: правое малое корабельное сопло"
	build_path = /obj/item/circuitboard/machine/engine/propulsion/standard/right

/** Printable board for the burst small nozzle. */
/datum/design/board/stationtrauma_engine/burst
	name = "Плата: малое корабельное сопло «Burst»"
	build_path = /obj/item/circuitboard/machine/engine/propulsion/standard/burst

/** Printable board for the burst/left small nozzle. */
/datum/design/board/stationtrauma_engine/burst_left
	name = "Плата: левое корабельное сопло «Burst»"
	build_path = /obj/item/circuitboard/machine/engine/propulsion/standard/burst/left

/** Printable board for the burst/right small nozzle. */
/datum/design/board/stationtrauma_engine/burst_right
	name = "Плата: правое корабельное сопло «Burst»"
	build_path = /obj/item/circuitboard/machine/engine/propulsion/standard/burst/right

/** Printable board for the three-by-three standard nozzle. */
/datum/design/board/stationtrauma_engine/huge
	name = "Плата огромного корабельного сопла"
	build_path = /obj/item/circuitboard/machine/engine/propulsion/standard/huge

/** Keep the existing research design identity for heavy nozzles. */
/datum/design/board/stationtrauma_large_engine
	parent_type = /datum/design/board/stationtrauma_engine
	name = "Плата большого корабельного сопла"
	build_path = /obj/item/circuitboard/machine/engine/propulsion/standard/large

/** Heavy converter board paired with the large nozzle rating. */
/datum/design/board/stationtrauma_large_converter
	parent_type = /datum/design/board/stationtrauma_engine
	name = "Плата большого преобразователя тяги"
	desc = "Плата преобразователя горячего газа для тяжёлого корабельного сопла."
	build_path = /obj/item/circuitboard/machine/engine/heater/combustion/large

/** One native pipe inlet, directed toward a separately installed physical nozzle. */
/obj/machinery/atmospherics/components/unary/ship_engine_heater
	name = "преобразователь тяги"
	desc = "Принимает горячий газ термоядерного ядра из магистрали и направляет его в сопло."
	icon = 'icons/turf/shuttle.dmi'
	icon_state = "heater"
	dir = SOUTH
	layer = OBJ_LAYER
	density = TRUE
	// It sits in the exhaust bay, as the native nozzles do.
	resistance_flags = FIRE_PROOF
	max_integrity = 300
	use_power = IDLE_POWER_USE
	idle_power_usage = BASE_MACHINE_IDLE_CONSUMPTION * 0.25
	circuit = /obj/item/circuitboard/machine/engine/heater/combustion
	/// Physical nozzle; its footprint may contain several turfs.
	var/datum/weakref/nozzle
	/// Fusion core found on the actual supply pipeline.
	var/datum/weakref/core
	/// Delivered power remains available between native atmosphere ticks.
	var/delivered_fraction = 0
	/// Moles per second one nozzle draws at full load; thrust comes from engine_power, not from more gas.
	var/propellant_flow = 0.52
	/// Nominal thrust the converter can supply, independently of the nozzle's capacity.
	var/rated_thrust = 2
	/// Working-fluid palette belongs to the installation, not the replaceable nozzle.
	var/list/exhaust_gradient = list("#FFFFFF", "#FCE6B6", "#FD481C")

/** Heavy fusion converter preserving the mapped Raven's existing fuel budget. */
/obj/machinery/atmospherics/components/unary/ship_engine_heater/large
	name = "большой преобразователь тяги"
	circuit = /obj/item/circuitboard/machine/engine/heater/combustion/large
	rated_thrust = 8

/** Mapping preset for receivers connected to the fourth pipe layer. */
/obj/machinery/atmospherics/components/unary/ship_engine_heater/layer4
	piping_layer = 4

/** Mapping preset for heavy converters connected to the fourth pipe layer. */
/obj/machinery/atmospherics/components/unary/ship_engine_heater/large/layer4
	piping_layer = 4

/obj/machinery/atmospherics/components/unary/ship_engine_heater/Initialize(mapload)
	. = ..()
	var/datum/gas_mixture/air = airs[1]
	air.volume = UNARY_PIPE_VOLUME

/obj/machinery/atmospherics/components/unary/ship_engine_heater/Destroy()
	var/obj/machinery/power/shuttle_engine/engine = nozzle?.resolve()
	if(engine?.combustion_feed?.resolve() == src)
		engine.combustion_feed = null
	nozzle = null
	core = null
	return ..()

/obj/machinery/atmospherics/components/unary/ship_engine_heater/set_init_directions()
	// The pipe enters behind the receiver; dir points toward its nozzle.
	initialize_directions = REVERSE_DIR(dir)

/obj/machinery/atmospherics/components/unary/ship_engine_heater/update_icon_nopipes()
	icon_state = "heater"

/** Bind once per start/reconnection; no world or range scans in atmosphere processing. */
/obj/machinery/atmospherics/components/unary/ship_engine_heater/proc/bind_nozzle(obj/docking_port/mobile/ship)
	var/obj/machinery/power/shuttle_engine/previous = nozzle?.resolve()
	if(previous?.combustion_feed?.resolve() == src)
		previous.combustion_feed = null
	nozzle = null
	var/turf/nozzle_tile = get_step(src, dir)
	for(var/obj/machinery/power/shuttle_engine/engine as anything in ship.engine_list)
		if(!engine.requires_combustion || engine.dir != dir || !(nozzle_tile in engine.locs))
			continue
		if(engine.combustion_feed?.resolve())
			continue
		nozzle = WEAKREF(engine)
		engine.combustion_feed = WEAKREF(src)
		return TRUE
	return FALSE

/** Find the first turf outside the nozzle's actual bounds, including rotated large engines. */
/obj/machinery/atmospherics/components/unary/ship_engine_heater/proc/exhaust_turf()
	var/obj/machinery/power/shuttle_engine/engine = nozzle?.resolve()
	if(!engine)
		return null
	var/turf/exhaust = get_step(engine, engine.dir)
	while(exhaust && (exhaust in engine.locs))
		exhaust = get_step(exhaust, engine.dir)
	return exhaust

/** Receiver and nozzle hardware faults shared by every feed type. */
/obj/machinery/atmospherics/components/unary/ship_engine_heater/proc/hardware_fault()
	var/obj/machinery/power/shuttle_engine/engine = nozzle?.resolve()
	if(machine_stat & BROKEN)
		return "Преобразователь повреждён"
	if(!is_operational)
		return "Преобразователь обесточен или отключён"
	if(panel_open || !anchored)
		return "Преобразователь не собран"
	if(!nodes[1] || !parents[1])
		return "Нет подключения к трубе"
	if(!engine)
		return "Сопло не подключено"
	if(!engine.crew_enabled)
		return "Отключено с пульта"
	if(!engine.anchored || engine.engine_state != initial(engine.engine_state))
		return "Сопло не собрано"
	if((engine.machine_stat & BROKEN) || engine.get_integrity() <= 0)
		return "Сопло повреждено"
	return null

/** The same interlocks explain lost thrust to the engineer and prevent gas consumption. */
/obj/machinery/atmospherics/components/unary/ship_engine_heater/proc/unavailable_reason()
	. = hardware_fault()
	if(.)
		return
	var/obj/machinery/power/shuttle_engine/engine = nozzle.resolve()
	var/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/reactor = core?.resolve()
	if(!engine.connected_ship || !reactor)
		return "Нет связи с ядром"
	if(reactor.vessel_ref?.resolve() != engine.connected_ship || engine.dir != dir || !(get_step(src, dir) in engine.locs))
		return "Нарушено соединение с соплом"
	if(reactor.parents[2] != parents[1])
		return "Разрыв магистрали ядра"
	var/turf/open/exhaust = exhaust_turf()
	if(!istype(exhaust))
		return "Выпуск сопла перекрыт"
	if(reactor.tripped)
		return "Ядро перегрето"
	if(!reactor.active)
		return "Ядро остановлено"
	var/obj/docking_port/mobile/stationtrauma_space/ship = engine.connected_ship
	// A delivered parcel powers its interval even if it emptied the inlet.
	if(ship.engines_running && delivered_fraction > 0)
		return null
	var/datum/gas_mixture/air = airs[1]
	if(air.total_moles() <= 0)
		return "Нет подачи газа"
	if(air.temperature < PLASMA_MINIMUM_BURN_TEMPERATURE)
		return "Газ остыл"
	var/datum/gas_mixture/environment = exhaust.return_air()
	if(air.return_pressure() <= (environment?.return_pressure() || 0))
		return "Недостаточный напор"
	return null

/** Hot gas, an intact installation and an unobstructed exhaust are required for thrust. */
/obj/machinery/atmospherics/components/unary/ship_engine_heater/proc/ready_fraction()
	if(unavailable_reason())
		return 0
	var/obj/machinery/power/shuttle_engine/engine = nozzle.resolve()
	var/obj/docking_port/mobile/stationtrauma_space/ship = engine.connected_ship
	if(ship.engines_running && delivered_fraction > 0)
		return delivered_fraction
	var/datum/gas_mixture/air = airs[1]
	return min(1, air.temperature / SHIP_ENGINE_OPERATING_TEMPERATURE)

/** The off-engine preview permits a start; powered flight uses only gas already delivered, raised by core overdrive. */
/obj/machinery/atmospherics/components/unary/ship_engine_heater/proc/propulsion_fraction()
	var/ready = ready_fraction()
	var/obj/machinery/power/shuttle_engine/engine = nozzle?.resolve()
	var/obj/docking_port/mobile/stationtrauma_space/ship = engine?.connected_ship
	var/capacity = engine ? min(1, rated_thrust / max(1, engine.engine_power)) : 0
	if(!ship?.engines_running)
		return ready * capacity
	. = min(ready, delivered_fraction) * capacity
	var/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/reactor = core?.resolve()
	if(.)
		. *= reactor?.thrust_multiplier() || 1

/obj/machinery/atmospherics/components/unary/ship_engine_heater/process_atmos(seconds_per_tick)
	delivered_fraction = 0
	if(seconds_per_tick <= 0 || !ready_fraction())
		return
	var/obj/machinery/power/shuttle_engine/engine = nozzle.resolve()
	var/obj/docking_port/mobile/stationtrauma_space/ship = engine.connected_ship
	if(!ship.engines_running)
		return
	var/datum/stationtrauma_overmap/space/map = ship.overmap
	var/load = map?.commanded_thrust() || 0
	// The fusion core's full output covers every Raven converter at full thrust.
	var/requested = propellant_flow * max(0.15, load) * seconds_per_tick
	var/datum/gas_mixture/air = airs[1]
	var/datum/gas_mixture/exhausted = air.remove(requested)
	if(!exhausted)
		return
	delivered_fraction = exhaust_fraction(exhausted, requested, seconds_per_tick)
	var/turf/exhaust = exhaust_turf()
	// Large nozzles may exhaust beyond the template into uninitialized map-loader space.
	if(istype(exhaust, /turf/open/space/basic) && !(exhaust.flags_1 & INITIALIZED_1))
		exhaust = exhaust.ChangeTurf(/turf/open/space)
	exhaust.assume_air(exhausted)
	update_parents()

/**
 * Share of nominal thrust carried by one exhausted parcel.
 *
 * Arguments:
 * * exhausted - Gas removed from the inlet this atmos tick
 * * requested - Moles a full-power parcel would contain
 * * seconds_per_tick - Atmos tick length
 */
/obj/machinery/atmospherics/components/unary/ship_engine_heater/proc/exhaust_fraction(datum/gas_mixture/exhausted, requested, seconds_per_tick)
	return min(1, exhausted.total_moles() / requested) * min(1, exhausted.temperature / SHIP_ENGINE_OPERATING_TEMPERATURE)

/obj/machinery/atmospherics/components/unary/ship_engine_heater/screwdriver_act(mob/living/user, obj/item/tool)
	var/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/reactor = core?.resolve()
	if(reactor?.active)
		balloon_alert(user, "остановите ядро!")
		return ITEM_INTERACT_BLOCKING
	if(get_integrity() < max_integrity)
		if(do_after(user, 5 SECONDS, src))
			reactor = core?.resolve()
			if(!reactor?.active)
				repair_damage(max_integrity)
		return ITEM_INTERACT_SUCCESS
	return default_deconstruction_screwdriver(user, tool)

/obj/machinery/atmospherics/components/unary/ship_engine_heater/crowbar_act(mob/living/user, obj/item/tool)
	return crowbar_deconstruction_act(user, tool)

/** Compatibility for mapped plasma engines; plasma behaviour belongs to their converter. */
/obj/machinery/power/shuttle_engine/propulsion/plasma
	parent_type = /obj/machinery/power/shuttle_engine/propulsion/standard

/** Existing plasma boards now rebuild the standard small nozzle. */
/obj/item/circuitboard/machine/engine/propulsion/plasma
	parent_type = /obj/item/circuitboard/machine/engine/propulsion/standard

/** Buildable electric plasma heater. */
/obj/item/circuitboard/machine/engine/heater/plasma
	name = "плазменный нагреватель"
	build_path = /obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma

/**
 * Heats plasma taken straight from its inlet pipe with the area's electricity.
 *
 * The heating cap is below what full thrust needs, so hard burns exhaust cooler plasma and give less thrust.
 */
/obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma
	name = "плазменный нагреватель"
	desc = "Разогревает поступающую плазму электричеством и подаёт её к соплу."
	circuit = /obj/item/circuitboard/machine/engine/heater/plasma
	// Three times the fusion drive mass flow: a cheap but hungry drive.
	propellant_flow = 1.56
	rated_thrust = 1
	exhaust_gradient = list("#FFFFFF", "#F2B8FF", "#9B3DFF")
	/// Maximum electric heating rate.
	var/heating_power = 50 KILO WATTS
	/// Exhaust temperature for full thrust; plasma relies on mass flow rather than heat.
	var/exhaust_temperature = 500

/obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma/unavailable_reason()
	. = hardware_fault()
	if(.)
		return
	var/obj/machinery/power/shuttle_engine/engine = nozzle.resolve()
	if(!istype(engine.connected_ship, /obj/docking_port/mobile/stationtrauma_space))
		return "Нет связи с кораблём"
	if(engine.dir != dir || !(get_step(src, dir) in engine.locs))
		return "Нарушено соединение с соплом"
	var/turf/open/exhaust = exhaust_turf()
	if(!istype(exhaust))
		return "Выпуск сопла перекрыт"
	var/obj/docking_port/mobile/stationtrauma_space/ship = engine.connected_ship
	if(ship.engines_running && delivered_fraction > 0)
		return null
	var/datum/gas_mixture/air = airs[1]
	if(!air.moles[/datum/gas/plasma])
		return "Нет подачи плазмы"
	var/datum/gas_mixture/environment = exhaust.return_air()
	if(air.return_pressure() <= (environment?.return_pressure() || 0))
		return "Недостаточный напор"
	return null

/obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma/ready_fraction()
	if(unavailable_reason())
		return 0
	var/obj/machinery/power/shuttle_engine/engine = nozzle.resolve()
	var/obj/docking_port/mobile/stationtrauma_space/ship = engine.connected_ship
	return ship.engines_running && delivered_fraction > 0 ? delivered_fraction : 1

/obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma/exhaust_fraction(datum/gas_mixture/exhausted, requested, seconds_per_tick)
	var/capacity = exhausted.heat_capacity()
	var/heat = min((exhaust_temperature - exhausted.temperature) * capacity, heating_power * seconds_per_tick)
	if(heat > 0)
		exhausted.temperature += use_energy(heat) / capacity
	// Only electrical heating above room temperature produces thrust, so an unpowered heater gives none.
	return min(1, exhausted.moles[/datum/gas/plasma] / requested) * clamp((exhausted.temperature - T20C) / (exhaust_temperature - T20C), 0, 1)

/** Circuit board for the engine console. */
/obj/item/circuitboard/computer/stationtrauma_engine_console
	name = "пульт двигателей"
	greyscale_colors = CIRCUIT_COLOR_ENGINEERING
	build_path = /obj/machinery/computer/stationtrauma_engine_console

/** Engine console: every nozzle of the hull by number and size, its condition, thrust and an on/off switch. */
/obj/machinery/computer/stationtrauma_engine_console
	name = "пульт двигателей"
	desc = "Список сопел корабля по номерам: размер, техническое состояние и тяга. Каждое сопло можно отключить и включить."
	icon_screen = "shuttle"
	icon_keyboard = "atmos_key"
	circuit = /obj/item/circuitboard/computer/stationtrauma_engine_console

/** The hull this console stands in, resolved on demand so a rebuilt console needs no linking. */
/obj/machinery/computer/stationtrauma_engine_console/proc/vessel()
	var/obj/docking_port/mobile/stationtrauma_space/ship = SSshuttle.get_containing_shuttle(src)
	return istype(ship) ? ship : null

/** Nozzles in a stable order: from the port side to starboard, then from the stern forward. */
/proc/cmp_stationtrauma_engine_position(atom/first, atom/second)
	return first.x - second.x || first.y - second.y

/obj/machinery/computer/stationtrauma_engine_console/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	open_overmap_console(user, ui, "StationTraumaEngines")

/obj/machinery/computer/stationtrauma_engine_console/ui_status(mob/user, datum/ui_state/state)
	return overmap_console_status(user, ..())

/obj/machinery/computer/stationtrauma_engine_console/ui_data(mob/user)
	var/obj/docking_port/mobile/stationtrauma_space/ship = vessel()
	if(!ship?.overmap)
		return list("missing" = TRUE)
	var/list/engines = list()
	for(var/obj/machinery/power/shuttle_engine/engine as anything in sortTim(ship.engine_list.Copy(), GLOBAL_PROC_REF(cmp_stationtrauma_engine_position)))
		var/obj/machinery/atmospherics/components/unary/ship_engine_heater/feed = engine.combustion_feed?.resolve()
		var/thrust = round(ship.overmap.engine_output(engine) * 100)
		var/status
		if(!engine.crew_enabled)
			status = "Отключено с пульта"
		else if(engine.requires_combustion)
			status = feed ? feed.unavailable_reason() : "Преобразователь не подключён"
		else if(engine.machine_stat & BROKEN)
			status = "Повреждено"
		status ||= ship.engines_running ? (thrust >= 100 ? "Работает" : "Ограниченная тяга") : "Готово"
		var/size = "Малое"
		if(engine.bound_width > 2 * ICON_SIZE_X)
			size = "Огромное"
		else if(engine.bound_width > ICON_SIZE_X)
			size = "Большое"
		engines += list(list(
			"id" = REF(engine), "number" = length(engines) + 1,
			"size" = size,
			"power" = engine.engine_power,
			"enabled" = engine.crew_enabled,
			"integrity" = round(100 * engine.get_integrity() / engine.max_integrity),
			"status" = status,
			"thrust" = thrust,
		))
	return list(
		"engines_running" = ship.engines_running,
		"total" = round(ship.overmap.engine_fraction() * 100),
		"engines" = engines,
	)

/obj/machinery/computer/stationtrauma_engine_console/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || action != "toggle")
		return
	var/obj/docking_port/mobile/stationtrauma_space/ship = vessel()
	var/obj/machinery/power/shuttle_engine/engine = locate(params["id"]) in ship?.engine_list
	if(!engine)
		return FALSE
	engine.crew_enabled = !engine.crew_enabled
	return TRUE
