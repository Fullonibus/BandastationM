#define ST_PLASMA_FLOW 2.6
#define ST_PLASMA_TEMPERATURE 600
#define ST_PLASMA_POWER (170 KILO WATTS)
#define ST_PLASMA_BOOST_FLOW 1.5
#define ST_PLASMA_BOOST_THRUST 1.35

/** The compact electrical conditioning block uses the existing ship-core control and pipe contract. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma
	name = "плазменный тяговый блок"
	desc = "Электрический компрессор и нагреватель плазмы. Подаёт рабочее тело к преобразователям тяги; электричество не вырабатывает."
	connection_description = "Плазма поступает с тыльной стороны, нагретая плазма выходит к преобразователям. Кабель под центром блока питает компрессор и нагреватель."
	is_electric = TRUE
	dir = EAST
	icon = 'icons/obj/machines/engine/turbine.dmi'
	icon_state = "core_rotor"
	pixel_x = 0
	pixel_y = 0
	base_pixel_x = 0
	base_pixel_y = 0
	bound_x = -32
	bound_y = 0
	bound_width = 96
	bound_height = 32
	sleeve_origin = 0
	circuit = /obj/item/circuitboard/machine/stationtrauma_plasma_core
	injection_limit = ST_PLASMA_FLOW * ST_PLASMA_BOOST_FLOW
	integrity_failure = 0.5
	soundloop_type = /datum/looping_sound/stationtrauma_fusion/plasma
	overdrive_sound_type = /datum/looping_sound/stationtrauma_fusion/overdrive/plasma
	/// Actual electrical watts drawn during the last interval.
	var/power_draw = 0
	/// A breached casing leaks actual pipeline gas until repaired by rebuilding or isolated by valves.
	var/leaking = FALSE
	/// Prevent recursive destruction while the catastrophic failure vents the remaining gas.
	var/rupturing = FALSE

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/Initialize(mapload)
	setDir(dir)
	return ..()

/** Keep the three-tile casing centred while its real pipe ports rotate with the hull. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/setDir(newdir)
	. = ..()
	var/horizontal = dir & (EAST|WEST)
	bound_width = horizontal ? 96 : 32
	bound_height = horizontal ? 32 : 96
	bound_x = horizontal ? -32 : 0
	bound_y = horizontal ? 0 : -32

/** Native frames rebuild in the default direction; the open panel allows real pipe reconnection. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/wrench_act(mob/living/user, obj/item/tool)
	return default_change_direction_wrench(user, tool) ? ITEM_INTERACT_SUCCESS : ITEM_INTERACT_BLOCKING

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/update_icon_nopipes()
	icon_state = "core_rotor"

/** Assemble the native turbine's three existing sprites without separate invisible machinery. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/update_overlays()
	. = ..()
	var/list/offset = dir2offset(dir)
	for(var/side in list(-1, 1))
		var/mutable_appearance/casing = mutable_appearance(icon, side < 0 ? "inlet_compressor" : "turbine_outlet")
		casing.dir = dir
		casing.pixel_x = side * offset[1] * ICON_SIZE_X
		casing.pixel_y = side * offset[2] * ICON_SIZE_Y
		. += casing
		var/mutable_appearance/indicator = mutable_appearance(icon, "[side < 0 ? "inlet" : "outlet"]_[output > 0 ? "on" : "off"]")
		indicator.dir = dir
		indicator.pixel_x = casing.pixel_x
		indicator.pixel_y = casing.pixel_y
		. += indicator
	if(output > 0)
		var/mutable_appearance/rotor = mutable_appearance(icon, "core_on")
		rotor.dir = dir
		. += rotor
	if(panel_open)
		var/mutable_appearance/panel = mutable_appearance(icon, "core_open")
		panel.dir = dir
		. += panel

/** Electrical machinery has no fusion light or reaction sound, but shares the native loop lifecycle. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/refresh_effects()
	var/next_state = "[output > 0]-[overdrive_active()]-[tripped]-[panel_open]"
	if(effects_state == next_state)
		return
	effects_state = next_state
	if(output > 0)
		soundloop?.start()
		set_light(3, 1, "#D3A1FF")
	else
		soundloop?.stop()
		set_light(0)
	if(overdrive_active())
		overdrive_sound?.start()
	else
		overdrive_sound?.stop()
	update_appearance()

/** No electricity or neutrons are produced by a resistance heater. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/radiation_range()
	return 0

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/thrust_multiplier()
	return overdrive_active() ? ST_PLASMA_BOOST_THRUST : 1

/** The generator follows battery demand; this block follows only the helm and primes its finite outlet buffer. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/auto_level(obj/docking_port/mobile/stationtrauma_space/ship)
	return ship?.engines_running ? 100 * max(0.15, ship.overmap?.commanded_thrust()) : 10

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/process(seconds_per_tick)
	if(seconds_per_tick <= 0)
		return
	output = 0
	fuel_flow = 0
	power_draw = 0
	target = 0
	if(active && !tripped && anchored && !panel_open && is_operational)
		target = auto ? auto_level(vessel_ref?.resolve()) : level
		deliver(seconds_per_tick)
	var/datum/gas_mixture/room = loc.return_air()
	var/ambient = room?.heat_capacity() > 0 ? max(0, (room.temperature - T20C - 100) / 100) : 0
	heat = max(0, heat + ((overdrive_active() ? 2 : -1) + ambient) * seconds_per_tick)
	if(interlock && heat >= 100)
		overdrive = FALSE
		if(heat >= 120 && !tripped)
			trip()
	else if(tripped && heat <= 20)
		tripped = FALSE
	if(!interlock && heat >= 140)
		leaking = TRUE
	if(leaking)
		leak_gas(seconds_per_tick)
	if(!interlock && heat >= 200)
		meltdown()
		return
	refresh_effects()

/** Transfer only real plasma, paying the cable grid for compression and the parcel's actual thermal energy. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/deliver(seconds_per_tick)
	if(!parents[1] || !parents[2] || !nodes[1] || !nodes[2])
		return
	var/datum/gas_mixture/inlet = airs[1]
	var/datum/gas_mixture/outlet = airs[2]
	if(outlet.return_pressure() >= ST_CORE_EXHAUST_PRESSURE)
		return
	var/obj/structure/cable/cable = locate() in loc
	var/datum/powernet/grid = cable?.powernet
	var/budget = max(0, grid ? grid.avail - grid.load : 0)
	var/flow = min(injection_limit, ST_PLASMA_FLOW * target / 100 * (overdrive ? ST_PLASMA_BOOST_FLOW : 1))
	var/pumping = 5 KILO WATTS * flow / ST_PLASMA_FLOW * seconds_per_tick
	if(flow <= 0 || budget <= pumping || !inlet.moles[/datum/gas/plasma])
		return
	var/datum/gas_mixture/parcel = inlet.remove_specific(/datum/gas/plasma, flow * seconds_per_tick)
	if(!parcel)
		return
	fuel_flow = parcel.moles[/datum/gas/plasma] / seconds_per_tick
	pumping *= min(1, fuel_flow / flow)
	var/capacity = parcel.heat_capacity()
	var/heating = min(max(0, (ST_PLASMA_TEMPERATURE - parcel.temperature) * capacity), ST_PLASMA_POWER * (overdrive ? ST_PLASMA_BOOST_FLOW : 1) * seconds_per_tick - pumping, budget - pumping)
	if(capacity > 0)
		parcel.temperature += heating / capacity
	power_draw = (heating + pumping) / seconds_per_tick
	grid.load += heating + pumping
	output = fuel_flow / ST_PLASMA_FLOW
	outlet.merge(parcel)
	update_parents()

/** Show the SMES units supplying this consumer, rather than those charged by a fusion generator. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/grid_batteries()
	. = list()
	var/obj/structure/cable/cable = locate() in loc
	for(var/obj/machinery/power/smes/battery in cable?.powernet?.nodes)
		. |= battery

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/fuel_reserve()
	return stationtrauma_fuel_gauges(list(parents[1]), list(/datum/gas/plasma = "Плазма"))

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/ui_data(mob/user)
	. = ..()
	.["electric"] = TRUE
	.["max_level"] = 100
	.["power"] = round(power_draw / (1 KILO WATTS), 0.1)
	.["injection_max"] = ST_PLASMA_FLOW * ST_PLASMA_BOOST_FLOW
	.["leaking"] = leaking

/** Keep the shared controls, with plasma-specific injector and manual limits. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/control(action, list/params, mob/user)
	if(action != "level" && action != "injection")
		return ..()
	if(panel_open || !IS_FINITE(params["value"]))
		return FALSE
	if(action == "level")
		level = clamp(round(params["value"]), 0, 100)
	else
		injection_limit = clamp(params["value"], 0, ST_PLASMA_FLOW * ST_PLASMA_BOOST_FLOW)
	return TRUE

/** A breached block spills its own gas into the actual compartment, where native plasma fire needs oxygen. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/proc/leak_gas(seconds_per_tick)
	var/turf/open/ground = get_turf(src)
	if(!istype(ground))
		return
	var/ignition_temperature = ground.return_air()?.temperature || TCMB
	for(var/datum/gas_mixture/stored as anything in airs)
		var/datum/gas_mixture/escaped = stored.remove(min(stored.total_moles(), seconds_per_tick))
		if(escaped)
			ignition_temperature = max(ignition_temperature, escaped.temperature)
			ground.assume_air(escaped)
	update_parents()
	ground.hotspot_expose(ignition_temperature, 125)
	ground.air_update_turf(FALSE, FALSE)

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/atom_break(damage_flag)
	. = ..()
	leaking = TRUE

/** Heavy external destruction can rupture a hot block even with the thermal interlock enabled. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/atom_destruction(damage_flag)
	if(!rupturing && (output > 0 || heat > 0))
		meltdown()
		return
	return ..()

/** Catastrophic overheating or a destroyed hot casing vents its contents before the local blast. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/meltdown()
	if(rupturing)
		return
	rupturing = TRUE
	var/turf/ground = get_turf(src)
	message_admins("Plasma propulsion block ruptured at [ADMIN_VERBOSEJMP(ground)].")
	log_game("Plasma propulsion block ruptured at [AREACOORD(ground)].")
	leak_gas(INFINITY)
	qdel(src)
	explosion(ground, devastation_range = 1, heavy_impact_range = 3, light_impact_range = 5, flame_range = 4)

/** Electrical block feeding three small nozzles, with no local electric heater at each converter. */
/obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma_block
	name = "плазменный преобразователь тяги"
	desc = "Направляет горячую плазму центрального тягового блока в стандартное сопло."
	circuit = /obj/item/circuitboard/machine/engine/heater/plasma_block
	rated_thrust = 2
	propellant_flow = ST_PLASMA_FLOW / 3
	exhaust_gradient = list("#FFFFFF", "#F2B8FF", "#9B3DFF")

/obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma_block/unavailable_reason()
	. = ..()
	if(.)
		return
	if(!istype(core?.resolve(), /obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma))
		return "Нужен плазменный тяговый блок"
	var/datum/gas_mixture/air = airs[1]
	if(!delivered_fraction && !air.moles[/datum/gas/plasma])
		return "Нет подачи плазмы"

/obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma_block/ready_fraction()
	if(unavailable_reason())
		return 0
	var/obj/machinery/power/shuttle_engine/engine = nozzle.resolve()
	var/obj/docking_port/mobile/stationtrauma_space/ship = engine.connected_ship
	var/datum/gas_mixture/air = airs[1]
	return ship.engines_running && delivered_fraction > 0 ? delivered_fraction : clamp((air.temperature - T20C) / (ST_PLASMA_TEMPERATURE - T20C), 0, 1)

/obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma_block/process_atmos(seconds_per_tick)
	var/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/block = core?.resolve()
	var/normal_flow = initial(propellant_flow)
	propellant_flow = normal_flow * (block?.overdrive_active() ? ST_PLASMA_BOOST_FLOW : 1)
	. = ..()
	propellant_flow = normal_flow

/obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma_block/exhaust_fraction(datum/gas_mixture/exhausted, requested, seconds_per_tick)
	return min(1, exhausted.moles[/datum/gas/plasma] / requested) * clamp((exhausted.temperature - T20C) / (ST_PLASMA_TEMPERATURE - T20C), 0, 1)

/** Rebuildable electrical conditioning block. */
/obj/item/circuitboard/machine/stationtrauma_plasma_core
	name = "плазменный тяговый блок"
	greyscale_colors = CIRCUIT_COLOR_ENGINEERING
	build_path = /obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma
	req_components = list(/datum/stock_part/micro_laser = 2, /datum/stock_part/capacitor = 2, /obj/item/stack/sheet/plasteel = 3)

/** Replaceable converter for centrally conditioned plasma. */
/obj/item/circuitboard/machine/engine/heater/plasma_block
	name = "плазменный преобразователь тяги"
	build_path = /obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma_block

/** Existing ship engineering research prints both new installation boards. */
/datum/design/board/stationtrauma_plasma_core
	parent_type = /datum/design/board/stationtrauma_engine
	name = "Плата плазменного тягового блока"
	build_path = /obj/item/circuitboard/machine/stationtrauma_plasma_core

/** Converter board for the central plasma block. */
/datum/design/board/stationtrauma_plasma_converter
	parent_type = /datum/design/board/stationtrauma_engine
	name = "Плата плазменного преобразователя тяги"
	build_path = /obj/item/circuitboard/machine/engine/heater/plasma_block

/** Electrical compressor recordings already supplied by the build. */
/datum/looping_sound/stationtrauma_fusion/plasma
	start_sound = 'sound/machines/generator/generator_start.ogg'
	start_length = 0.4 SECONDS
	mid_sounds = list('sound/machines/generator/generator_mid1.ogg')
	mid_length = 0.4 SECONDS
	end_sound = 'sound/machines/generator/generator_end.ogg'
	volume = 25

/** A stressed compressor layer during helm afterburner. */
/datum/looping_sound/stationtrauma_fusion/overdrive/plasma
	mid_sounds = list('sound/machines/generator/generator_mid3.ogg')
	mid_length = 0.4 SECONDS

#undef ST_PLASMA_FLOW
#undef ST_PLASMA_TEMPERATURE
#undef ST_PLASMA_POWER
#undef ST_PLASMA_BOOST_FLOW
#undef ST_PLASMA_BOOST_THRUST
