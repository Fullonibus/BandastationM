/** Circuit board for the ship fusion core. */
/obj/item/circuitboard/machine/stationtrauma_fusion_core
	name = "термоядерное ядро"
	greyscale_colors = CIRCUIT_COLOR_ENGINEERING
	build_path = /obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core
	req_components = list(
		/datum/stock_part/micro_laser = 4,
		/datum/stock_part/capacitor = 2,
		/obj/item/stack/sheet/plasteel = 5,
	)

/**
 * Ship fusion core: burns tritium from its inlet, feeds the cable grid beneath it in place of portable generators,
 * and pushes hot helium from its outlet to the engine converters.
 *
 * The reaction is a fixed rule, not native gas chemistry; only the tritium taken and the helium given are real gas.
 */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core
	name = "термоядерное ядро"
	desc = "Сжигает тритий в магнитной ловушке. Питает сеть корабля через кабель под собой и подаёт горячий гелий к преобразователям двигателей. Работающее ядро излучает нейтроны."
	icon = 'modular_bandastation/space_overmap/icons/fusion_core.dmi'
	icon_state = "core"
	pixel_x = -32
	pixel_y = -32
	base_pixel_x = -32
	base_pixel_y = -32
	bound_x = -32
	bound_y = -32
	bound_width = 96
	bound_height = 96
	density = TRUE
	layer = OBJ_LAYER
	resistance_flags = FIRE_PROOF
	max_integrity = 400
	use_power = NO_POWER_USE
	circuit = /obj/item/circuitboard/machine/stationtrauma_fusion_core
	/// Electrical heaters share the ship control contract, but consume rather than generate power.
	var/is_electric = FALSE
	/// Installation-specific hookup instructions shown by examination.
	var/connection_description = "Тритий подаётся во вход, горячий гелий уходит из выхода к преобразователям. Электричество идёт в кабель под ядром."
	/// Icon-space origin of pipe sleeves; the fusion casing uses a centred 96px image.
	var/sleeve_origin = ICON_SIZE_X
	/// Local machine sound profiles; electrical heaters supply their own recordings.
	var/soundloop_type = /datum/looping_sound/stationtrauma_fusion
	var/overdrive_sound_type = /datum/looping_sound/stationtrauma_fusion/overdrive
	/// Engineer's manual output setting, in percent of the nominal reaction; above 100 is overload.
	var/level = 100
	/// Whether the core follows the grid and engine demand itself instead of the manual setting.
	var/auto = TRUE
	/// Whether the engineer has started the reaction.
	var/active = FALSE
	/// Helm afterburner: more fuel for more output, heating the core fast.
	var/overdrive = FALSE
	/// Core heat in percent; overload and overdrive raise it, nominal running sheds it.
	var/heat = 0
	/// Emergency interlock: trips the core at full heat; switched off, the core runs on towards a meltdown.
	var/interlock = TRUE
	/// Latched heat trip; the core cannot run again until cold.
	var/tripped = FALSE
	/// Hot restarts retain the warning deadline; cooling below the unsafe range clears it.
	var/meltdown_deadline = 0
	/// Engineer's cap on the tritium injector, in moles per second.
	var/injection_limit = ST_CORE_FUEL_RATE * ST_CORE_MAX_LEVEL / 100 * ST_CORE_OVERDRIVE_FUEL
	/// Output the reaction aimed for on the last tick, in percent.
	var/target = 0
	/// Share of nominal output delivered on the last tick, after any fuel shortage.
	var/output = 0
	/// Tritium injected on the last tick, in moles per second.
	var/fuel_flow = 0
	/// Hull this core powers and drives.
	var/datum/weakref/vessel_ref
	/// Last applied audiovisual state; steady operation does not rebuild appearances or restart loops.
	var/effects_state
	/// Reactor-owned hum, including the ignition and shutdown sequence.
	var/datum/looping_sound/stationtrauma_fusion/soundloop
	/// Additional stressed-reaction layer, heard only during overdrive.
	var/datum/looping_sound/stationtrauma_fusion/overdrive/overdrive_sound

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/Initialize(mapload)
	. = ..()
	soundloop = new soundloop_type(src)
	overdrive_sound = new overdrive_sound_type(src)
	refresh_effects()

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/post_machine_initialize()
	. = ..()
	connect_to_shuttle(port = SSshuttle.get_containing_shuttle(src))

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/connect_to_shuttle(mapload, obj/docking_port/mobile/port, obj/docking_port/stationary/dock)
	. = ..()
	var/obj/docking_port/mobile/stationtrauma_space/previous = vessel_ref?.resolve()
	if(previous && previous != port)
		if(previous.fusion_core?.resolve() == src)
			previous.fusion_core = null
		vessel_ref = null
	if(!istype(port, /obj/docking_port/mobile/stationtrauma_space) || !port.is_in_shuttle_bounds(src))
		return
	var/obj/docking_port/mobile/stationtrauma_space/ship = port
	if(ship.fusion_core?.resolve() && ship.fusion_core.resolve() != src)
		return
	vessel_ref = WEAKREF(ship)
	ship.fusion_core = WEAKREF(src)
	bind_converters()

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/Destroy()
	QDEL_NULL(soundloop)
	QDEL_NULL(overdrive_sound)
	var/obj/docking_port/mobile/stationtrauma_space/ship = vessel_ref?.resolve()
	if(ship?.fusion_core?.resolve() == src)
		ship.fusion_core = null
	vessel_ref = null
	return ..()

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/update_icon_nopipes()
	icon_state = operating_state()

/** Draw the native connection sleeves at the two edges of the centred casing. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/update_icon()
	. = ..()
	underlays.Cut()
	if(!underfloor_state)
		return
	var/list/directions = get_node_connects()
	var/uncovered_turf = loc && HAS_TRAIT(loc, TRAIT_UNCOVERED_TURF)
	for(var/index in 1 to device_type)
		var/port_direction = directions[index]
		var/obj/machinery/atmospherics/node = nodes[index]
		var/connection = node ? "intact" : "exposed"
		var/mutable_appearance/sleeve = mutable_appearance('icons/obj/pipes_n_cables/pipe_underlays.dmi', "[connection]_[port_direction]_[piping_layer]", appearance_flags = RESET_COLOR|KEEP_APART)
		sleeve.color = node ? SELECT_ATMOS_NODE_COLOR(src, node) : pipe_color
		sleeve.pixel_x = sleeve_origin + ICON_SIZE_X * ((port_direction == EAST) - (port_direction == WEST))
		sleeve.pixel_y = sleeve_origin + ICON_SIZE_Y * ((port_direction == NORTH) - (port_direction == SOUTH))
		if(underfloor_state == UNDERFLOOR_VISIBLE || uncovered_turf)
			sleeve.layer = BELOW_CATWALK_LAYER + get_pipe_layer_offset()
			SET_PLANE_EXPLICIT(sleeve, FLOOR_PLANE, src)
		underlays += sleeve

/** Discover pipes outside the 3x3 footprint; the native pipe side finds this atom in its edge turf's contents. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/atmos_init(list/node_connects)
	if(!node_connects)
		node_connects = get_node_connects()
	for(var/index in 1 to device_type)
		for(var/obj/machinery/atmospherics/target in get_ranged_target_turf(src, node_connects[index], 2))
			if(can_be_node(target))
				nodes[index] = target
				break
	update_appearance()

/** Only the middle of each inlet/outlet edge is a port, even though this atom occupies nine turfs. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/is_connectable(obj/machinery/atmospherics/target, given_layer)
	var/turf/target_turf = get_turf(target)
	if(get_dist(get_turf(src), target_turf) != 2)
		return FALSE
	var/list/directions = get_node_connects()
	if(target_turf != get_ranged_target_turf(src, directions[1], 2) && target_turf != get_ranged_target_turf(src, directions[2], 2))
		return FALSE
	return ..()

/** Ventcrawl routing uses the same two exterior ports as gas network discovery. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/find_connecting(direction, prompted_layer)
	for(var/obj/machinery/atmospherics/target in get_ranged_target_turf(src, direction, 2))
		if(connection_check(target, prompted_layer))
			return target

/** The casing is centred regardless of the hull's heading; rotate port directions, not its pixel offset. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/shuttleRotate(rotation, params)
	params &= ~ROTATE_OFFSET
	return ..()

/** The native one-tile adjacency check would disconnect both exterior ports after every hull move. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/lateShuttleMove(turf/oldT, list/movement_force, move_dir)
	if(pipe_vision_img)
		pipe_vision_img.loc = loc
	var/list/directions = get_node_connects()
	var/missing_nodes = FALSE
	for(var/index in 1 to device_type)
		var/obj/machinery/atmospherics/node = nodes[index]
		if(node && get_turf(node) != get_ranged_target_turf(src, directions[index], 2))
			var/datum/gas_mixture/stored = airs[index]
			nullify_node(index)
			// Disconnect the pipe without losing the core's internal tank.
			airs[index] = stored
		if(!nodes[index])
			missing_nodes = TRUE
	if(!missing_nodes)
		update_appearance()
		return
	atmos_init()
	for(var/obj/machinery/atmospherics/node in pipeline_expansion())
		node.atmos_init()
		if(node.return_pipenet())
			node.add_member(src)
	SSair.add_to_rebuild_queue(src)

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/update_overlays()
	. = ..()
	if(is_electric || (icon_state in list("core", "core_open")))
		return
	. += emissive_appearance(icon, "[icon_state]_glow", src)

/** Select the actual reaction's presentation, with a latched heat trip taking priority over all running modes. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/proc/operating_state()
	if(tripped)
		return "core_emergency"
	if(panel_open)
		return "core_open"
	if(output <= 0)
		return "core"
	if(overdrive || output > 1)
		return "core_overdrive"
	if(output <= 0.25)
		return "core_quiet"
	return "core_normal"

/** Apply mode transitions once; ignition follows real output, while quiet/overdrive changes preserve the hum's playback. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/proc/refresh_effects()
	var/next_state = operating_state()
	if(effects_state == next_state)
		return
	effects_state = next_state
	var/hum_volume = 0
	switch(next_state)
		if("core_normal")
			set_light(6, 2, "#ADFFE1")
			hum_volume = 30
		if("core_overdrive")
			set_light(7, 3, "#92FF52")
			hum_volume = 45
		if("core_quiet")
			set_light(3, 0.7, "#54A9BB")
			hum_volume = 12
		if("core_emergency")
			set_light(3, 1, "#FF4A36")
		else
			set_light(0)
	if(hum_volume)
		soundloop.volume = hum_volume
		soundloop.sound_token_instance?.set_volume(hum_volume)
		soundloop.start()
	else
		soundloop.stop()
	if(next_state == "core_overdrive")
		overdrive_sound.start()
	else
		overdrive_sound.stop()
	update_appearance()

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/examine(mob/user)
	. = ..()
	. += span_notice(connection_description)

/** Hand the outlet line's converters to this core and pair each with its nozzle; called on hookup and start, never per tick. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/proc/bind_converters()
	var/obj/docking_port/mobile/stationtrauma_space/ship = vessel_ref?.resolve()
	var/datum/pipeline/line = parents[2]
	if(!ship || !line)
		return
	for(var/obj/machinery/atmospherics/components/unary/ship_engine_heater/converter in line.other_atmos_machines)
		if(istype(converter, /obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma))
			continue
		if(!ship.shuttle_areas[get_area(converter)] || !ship.is_in_shuttle_bounds(converter))
			continue
		converter.core = WEAKREF(src)
		converter.bind_nozzle(ship)

/** Whether overdrive is actually raising the output. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/proc/overdrive_active()
	return overdrive && output > 0

/** Thrust gain belongs to the supplying installation, not the interchangeable nozzle. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/proc/thrust_multiplier()
	return overdrive_active() ? 1 + SHIP_AFTERBURNER_THRUST : 1

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/process(seconds_per_tick)
	var/obj/docking_port/mobile/stationtrauma_space/ship = vessel_ref?.resolve()
	output = 0
	fuel_flow = 0
	target = 0
	if(active && !tripped && anchored && !panel_open && is_operational)
		target = auto ? auto_level(ship) : level
		// Overdrive spends a third more tritium per unit of output.
		var/fuel_per_output = ST_CORE_FUEL_RATE * (overdrive ? ST_CORE_OVERDRIVE_FUEL / ST_CORE_OVERDRIVE_OUTPUT : 1)
		var/needed = min(fuel_per_output * target / 100 * (overdrive ? ST_CORE_OVERDRIVE_OUTPUT : 1), injection_limit) * seconds_per_tick
		var/datum/gas_mixture/fuel_line = airs[1]
		var/datum/gas_mixture/burned = needed > 0 ? fuel_line.remove_specific(/datum/gas/tritium, needed) : null
		if(burned)
			fuel_flow = burned.moles[/datum/gas/tritium] / seconds_per_tick
			output = fuel_flow / fuel_per_output
			deliver(seconds_per_tick)
	var/heating = max(0, output - 1) * ST_CORE_OVERLOAD_HEATING
	if(overdrive_active())
		heating += 100 / ST_CORE_OVERDRIVE_ENDURANCE
	heat = clamp(heat + (heating || -50 / ST_CORE_OVERDRIVE_ENDURANCE) * seconds_per_tick, 0, ST_CORE_MELTDOWN_HEAT)
	if(heat >= 100 && interlock && !tripped)
		trip()
	else if(tripped && heat <= 0)
		tripped = FALSE
	if(heat <= 100)
		meltdown_deadline = 0
	else if(!interlock && output > 0)
		if(!meltdown_deadline)
			meltdown_deadline = world.time + ST_CORE_MELTDOWN_DELAY
			playsound(src, 'sound/machines/warning-buzzer.ogg', 75, FALSE)
			say("Критический перегрев ядра. До возможного разрушения — не менее [ST_CORE_MELTDOWN_DELAY / (1 SECONDS)] секунд. Немедленно остановите реакцию и охладите ядро!")
		if(heat >= ST_CORE_MELTDOWN_HEAT && world.time >= meltdown_deadline)
			meltdown()
			return
	if(output > 1 || heat > 0)
		warm_room(seconds_per_tick)
	if(output > 0)
		// The price of power: fusion neutrons, stopped by a common wall, reach further and more often the harder the core runs.
		radiation_pulse(src, max_range = radiation_range(), threshold = RAD_MEDIUM_INSULATION, chance = DEFAULT_RADIATION_CHANCE * (1 + 2 * output), minimum_exposure_time = ST_CORE_RADIATION_EXPOSURE)
	if(ship?.engines_running && overdrive_active() && ship.overmap?.commanded_thrust() > 0)
		rumble_crew(ship)
	refresh_effects()

/** Neutron reach of the current reaction in tiles; an overheated core reaches further. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/proc/radiation_range()
	return output > 0 ? CEILING(ST_CORE_RADIATION_RANGE * output, 1) + (heat > 100 ? 2 : 0) : 0

/**
 * Output the automatic mode aims for, in percent: enough helium for the commanded thrust and enough power for the batteries still charging.
 *
 * Arguments:
 * * ship - Hull whose helm demand the core follows
 */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/proc/auto_level(obj/docking_port/mobile/stationtrauma_space/ship)
	var/need = ST_CORE_IDLE_LEVEL
	if(ship?.engines_running)
		// Running converters draw at least their idle share of gas.
		need = max(need, 100 * max(0.15, ship.overmap?.commanded_thrust()))
	var/charging = 0
	for(var/obj/machinery/power/smes/battery as anything in grid_batteries())
		if(battery.input_attempt && battery_fraction(battery) < 1)
			charging += battery.input_level
	return clamp(max(need, 100 * charging / ST_CORE_POWER), ST_CORE_IDLE_LEVEL, 100)

/** Batteries charged from the core's own grid, found through their input terminals. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/proc/grid_batteries()
	. = list()
	var/obj/structure/cable/cable = locate() in loc
	for(var/obj/machinery/power/terminal/terminal in cable?.powernet?.nodes)
		if(istype(terminal.master, /obj/machinery/power/smes))
			. |= terminal.master

/** Stored share of a battery, read from its cells. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/proc/battery_fraction(obj/machinery/power/smes/battery)
	var/stored = 0
	var/capacity = 0
	for(var/obj/item/stock_parts/power_store/cell in battery.component_parts)
		stored += cell.charge()
		capacity += cell.max_charge()
	return capacity ? stored / capacity : 0

/**
 * Overload and heat warm the core's own room; ventilation has to carry it away.
 *
 * Arguments:
 * * seconds_per_tick - Machine tick length
 */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/proc/warm_room(seconds_per_tick)
	var/turf/open/room = loc
	var/datum/gas_mixture/air = istype(room) ? room.return_air() : null
	var/capacity = air?.heat_capacity()
	if(!capacity)
		return
	air.temperature += ST_CORE_WASTE_HEAT * (max(0, output - 1) + heat / 200) * seconds_per_tick / capacity
	room.air_update_turf(FALSE, FALSE)

/** An unprotected core past its limit tears itself apart. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/proc/meltdown()
	var/turf/ground = get_turf(src)
	message_admins("Fusion core meltdown at [ADMIN_VERBOSEJMP(ground)].")
	log_game("Fusion core meltdown at [AREACOORD(ground)].")
	radiation_pulse(ground, max_range = 10, threshold = RAD_LIGHT_INSULATION, chance = 60)
	qdel(src)
	// A ship reactor catastrophe exceeds the ordinary bomb cap without changing caps for other explosives.
	explosion(ground, devastation_range = 10, heavy_impact_range = 14, light_impact_range = 18, flame_range = 12, ignorecap = TRUE)

/**
 * Feed the cable beneath the core and push hot helium to the outlet line.
 *
 * Arguments:
 * * seconds_per_tick - Machine tick length
 */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/proc/deliver(seconds_per_tick)
	// shortcut: feeds the cable's grid directly instead of being a grid node, so power monitors do not list the core; make it a power machine with atmos ports if that matters.
	var/obj/structure/cable/cable = locate() in loc
	if(cable?.powernet)
		cable.powernet.newavail += power_to_energy(ST_CORE_POWER * output)
	var/datum/gas_mixture/exhaust = airs[2]
	if(exhaust.return_pressure() >= ST_CORE_EXHAUST_PRESSURE)
		return
	var/datum/gas_mixture/helium = new
	helium.temperature = ST_CORE_EXHAUST_TEMPERATURE
	helium.moles[/datum/gas/helium] = ST_CORE_FUEL_RATE * ST_CORE_HELIUM_YIELD * output * seconds_per_tick
	exhaust.merge(helium)
	update_parents()

/** A full core shuts itself down and stays cold-locked; the crew hears and sees it. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/proc/trip()
	tripped = TRUE
	active = FALSE
	overdrive = FALSE
	playsound(src, 'sound/machines/warning-buzzer.ogg', 75, FALSE)
	say("Перегрев ядра: аварийная остановка.")

/** Crew aboard feel a thrusting overdrive as a steady rumble, renewed every machine tick; the shake is purely visual. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/proc/rumble_crew(obj/docking_port/mobile/stationtrauma_space/ship)
	for(var/mob/crew as anything in SSmobs.clients_by_zlevel[ship.z])
		if(ship.is_in_shuttle_bounds(crew))
			shake_camera(crew, 2 SECONDS, 0.35)

/** Tritium gauge of the inlet supply, including canisters behind inlet pumps. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/proc/fuel_reserve()
	return stationtrauma_fuel_gauges(list(parents[1]), list(/datum/gas/tritium = "Тритий"))

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "StationTraumaFusionCore", name)
		ui.open()

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/ui_data(mob/user)
	var/list/batteries = list()
	for(var/obj/machinery/power/smes/battery as anything in grid_batteries())
		batteries += list(list(
			"charge" = round(100 * battery_fraction(battery)),
			"charging" = battery.inputting,
			"input" = round(battery.input_level / (1 KILO WATTS), 0.1),
		))
	var/datum/gas_mixture/exhaust = airs[2]
	var/datum/gas_mixture/room = isopenturf(loc) ? loc.return_air() : null
	return list(
		"active" = active, "tripped" = tripped, "overdrive" = overdrive, "interlock" = interlock,
		"auto" = auto, "level" = level, "max_level" = ST_CORE_MAX_LEVEL,
		"target" = round(target), "output" = round(output * 100), "heat" = round(heat),
		"power" = round(ST_CORE_POWER * output / (1 KILO WATTS), 0.1),
		"fuel_flow" = round(fuel_flow, 0.01),
		"injection_limit" = round(injection_limit, 0.1),
		"injection_max" = ST_CORE_FUEL_RATE * ST_CORE_MAX_LEVEL / 100 * ST_CORE_OVERDRIVE_FUEL,
		"grid" = !!(locate(/obj/structure/cable) in loc),
		"batteries" = batteries,
		"exhaust_pressure" = round(exhaust.return_pressure(), 0.1),
		"room_temperature" = room ? round(room.temperature - T0C, 0.1) : null,
		"radiation" = radiation_range(),
		"fuel" = fuel_reserve(),
	)

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	return control(action, params, ui.user)

/**
 * Engineer's commands, shared by the core's own panel and the control console.
 *
 * Arguments:
 * * action - Command name
 * * params - Command arguments from the interface
 * * user - Engineer giving the command
 */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/proc/control(action, list/params, mob/user)
	if(panel_open)
		return FALSE
	switch(action)
		if("power")
			if(tripped)
				balloon_alert(user, "ядро перегрето!")
				return FALSE
			active = !active
			if(active)
				bind_converters()
			else
				overdrive = FALSE
		if("auto")
			auto = !auto
		if("level")
			var/value = params["value"]
			if(!IS_FINITE(value))
				return FALSE
			level = clamp(round(value), 0, ST_CORE_MAX_LEVEL)
		if("injection")
			var/value = params["value"]
			if(!IS_FINITE(value))
				return FALSE
			injection_limit = clamp(value, 0, ST_CORE_FUEL_RATE * ST_CORE_MAX_LEVEL / 100 * ST_CORE_OVERDRIVE_FUEL)
		if("interlock")
			interlock = !interlock
			log_game("[key_name(user)] turned [name] interlock [interlock ? "on" : "off"] at [AREACOORD(src)].")
			if(!interlock)
				message_admins("[ADMIN_LOOKUPFLW(user)] turned off [name] interlock at [ADMIN_VERBOSEJMP(src)].")
		else
			return FALSE
	return TRUE

/** Helm afterburner switch; the core must be running and not tripped. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/proc/toggle_overdrive()
	if(!active || tripped)
		return FALSE
	overdrive = !overdrive
	return TRUE

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/screwdriver_act(mob/living/user, obj/item/tool)
	if(active)
		balloon_alert(user, "остановите ядро!")
		return ITEM_INTERACT_BLOCKING
	. = default_deconstruction_screwdriver(user, tool)
	update_appearance()

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/crowbar_act(mob/living/user, obj/item/tool)
	return crowbar_deconstruction_act(user, tool)

/** Circuit board for the fusion core control console. */
/obj/item/circuitboard/computer/stationtrauma_fusion_monitor
	name = "пульт управления ядром"
	greyscale_colors = CIRCUIT_COLOR_ENGINEERING
	build_path = /obj/machinery/computer/stationtrauma_fusion_monitor

/** Engineer's control post for the hull's fusion core, outside the shielded core room. */
/obj/machinery/computer/stationtrauma_fusion_monitor
	name = "пульт управления ядром"
	desc = "Управление термоядерным ядром корабля: пуск, мощность, впрыск трития, аварийная блокировка и электросеть."
	icon_screen = "power"
	icon_keyboard = "power_key"
	circuit = /obj/item/circuitboard/computer/stationtrauma_fusion_monitor

/** The core of the hull this console stands in, resolved on demand so a rebuilt console needs no linking. */
/obj/machinery/computer/stationtrauma_fusion_monitor/proc/reactor()
	var/obj/docking_port/mobile/stationtrauma_space/ship = SSshuttle.get_containing_shuttle(src)
	return istype(ship) ? ship.fusion_core?.resolve() : null

/obj/machinery/computer/stationtrauma_fusion_monitor/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "StationTraumaFusionCore", name)
		ui.open()

/obj/machinery/computer/stationtrauma_fusion_monitor/ui_data(mob/user)
	var/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/core = reactor()
	return core ? core.ui_data(user) : list("missing" = TRUE)

/obj/machinery/computer/stationtrauma_fusion_monitor/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/core = reactor()
	return core?.control(action, params, ui.user)

/** Local fusion-machine sequence, using the build's existing ignition, low hum and shutdown recordings. */
/datum/looping_sound/stationtrauma_fusion
	start_sound = 'sound/machines/sm/loops/calm_start.ogg'
	start_length = 1.6 SECONDS
	mid_sounds = list('sound/machines/hypertorus/loops/hypertorus_nominal.ogg')
	mid_length = 6 SECONDS
	end_sound = 'sound/machines/sm/loops/calm_end.ogg'
	volume = 30
	falloff_exponent = 2
	falloff_distance = 2
	use_sound_tokens = TRUE

/** Stressed-reaction layer over the continuous hum; changing modes never plays a second ignition. */
/datum/looping_sound/stationtrauma_fusion/overdrive
	start_sound = null
	end_sound = null
	mid_sounds = list('sound/machines/sm/loops/delamming.ogg')
	volume = 22
