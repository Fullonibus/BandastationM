#define ST_SHIPGEN_OVERLOAD 1.5
#define ST_SHIPGEN_DERATE_HEAT 100
#define ST_SHIPGEN_TRIP_HEAT 120
#define ST_SHIPGEN_RESET_HEAT 50
#define ST_SHIPGEN_CRITICAL_HEAT 300

/** Fixed plasma profile: the native PACMAN board's uranium switch is deliberately absent. */
/obj/item/circuitboard/machine/stationtrauma_ship_generator
	name = "корабельный плазменный генератор"
	greyscale_colors = CIRCUIT_COLOR_ENGINEERING
	build_path = /obj/machinery/power/port_gen/pacman/ship
	needs_anchored = FALSE
	req_components = list(
		/obj/item/stack/cable_coil = 10,
		/obj/item/stack/sheet/iron = 10,
		/datum/stock_part/capacitor = 2,
	)

/** A buildable ship supply, unlocked with the existing shuttle engineering research. */
/datum/design/board/stationtrauma_ship_generator
	name = "Плата корабельного плазменного генератора"
	desc = "Генератор на плазменных листах: 200 кВт штатно, 300 кВт в ручной перегрузке."
	build_path = /obj/item/circuitboard/machine/stationtrauma_ship_generator
	build_type = IMPRINTER
	category = list(RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_ENGINEERING)
	departmental_flags = DEPARTMENT_BITFLAG_CARGO | DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_ENGINEERING

/** PACMAN fuel handling and hardware, with metered generation and an explicit overload interlock. */
/obj/machinery/power/port_gen/pacman/ship
	name = "корабельный плазменный генератор"
	desc = "Сжигает плазменные листы для питания корабля. Номинал 200 кВт, ручная перегрузка до 300 кВт."
	circuit = /obj/item/circuitboard/machine/stationtrauma_ship_generator
	power_gen = 200 KILO WATTS
	// Fifty sheets cover twenty minutes at nominal output; this subtype meters seconds, not ticks.
	time_per_sheet = 24
	/// Follow the connected grid and its charging SMES within nominal power.
	var/auto_mode = TRUE
	/// Manual permission for output above nominal; never granted by auto mode.
	var/overload = FALSE
	/// Working thermal protection derates before stopping the generator.
	var/interlock = TRUE
	/// A heat trip remains latched until the casing has cooled.
	var/tripped = FALSE
	/// Actual watts delivered last interval, also used by the grid feedback controller.
	var/generated_power = 0

/** The profile is fixed; calling PACMAN's construction hook would reinterpret this board as switchable. */
/obj/machinery/power/port_gen/pacman/ship/on_construction(mob/user)
	if(anchored)
		connect_to_network()

/** A remaining fraction of a sheet is usable fuel, even when auto mode is idling. */
/obj/machinery/power/port_gen/pacman/ship/HasFuel()
	return sheets + sheet_left > 0

/** A running machine can always be stopped, but a start requires assembled, connected, cold hardware. */
/obj/machinery/power/port_gen/pacman/ship/TogglePower()
	if(!active && (!anchored || !powernet || panel_open || !is_operational || tripped))
		return
	..()
	if(!active)
		generated_power = 0

/**
 * Correct the last output by the completed grid surplus, including unmet charging on this grid's SMES inputs.
 * The small idle output lets a dead APC grid start requesting power again.
 */
/obj/machinery/power/port_gen/pacman/ship/proc/automatic_power()
	if(!powernet)
		return 0
	// Share surplus correction with other supplies rather than making parallel generators oscillate together.
	var/grid_share = generated_power / max(1, generated_power, energy_to_power(powernet.avail))
	var/needed = generated_power - energy_to_power(powernet.netexcess) * grid_share
	for(var/obj/machinery/power/terminal/terminal in powernet.nodes)
		var/obj/machinery/power/smes/battery = terminal.master
		if(!istype(battery) || !battery.is_operational || !battery.input_attempt)
			continue
		var/obj/item/stock_parts/power_store/cell = battery.get_cell()
		if(!cell || cell.charge() >= cell.max_charge())
			continue
		needed += max(0, battery.input_level - energy_to_power(max(0, battery.input_available)))
	return clamp(needed, power_gen * 0.05, power_gen)

/** Fuel, heat and electrical energy all scale with the actual processing interval. */
/obj/machinery/power/port_gen/pacman/ship/process(seconds_per_tick)
	if(seconds_per_tick <= 0)
		return
	if(active && (!anchored || !powernet || panel_open || !is_operational || !HasFuel()))
		TogglePower()
	if(!active)
		generated_power = 0
		current_heat = max(0, current_heat - 2 * seconds_per_tick)
		if(tripped && current_heat <= ST_SHIPGEN_RESET_HEAT)
			tripped = FALSE
		if(!current_heat)
			return PROCESS_KILL
		return
	var/requested_power = auto_mode ? automatic_power() : power_gen * power_output
	requested_power = clamp(requested_power, 0, power_gen * (overload && !auto_mode ? ST_SHIPGEN_OVERLOAD : 1))
	var/load_fraction = requested_power / power_gen
	var/datum/gas_mixture/room = loc.return_air()
	var/ambient_heat = room?.heat_capacity() > 0 ? max(0, (room.temperature - T20C - 100) / 100) : 0
	var/heating = load_fraction > 1 ? 4 * (load_fraction - 1) : -1
	current_heat = max(0, current_heat + (heating + ambient_heat) * seconds_per_tick)
	if(interlock && current_heat >= ST_SHIPGEN_DERATE_HEAT)
		if(overload)
			visible_message(span_warning("[src]: защита сбрасывает перегрузку!"))
			playsound(src, 'sound/machines/warning-buzzer.ogg', 50, TRUE)
		overload = FALSE
		power_output = min(power_output, 1)
		requested_power = min(requested_power, power_gen)
		if(current_heat >= ST_SHIPGEN_TRIP_HEAT)
			tripped = TRUE
			TogglePower()
			visible_message(span_warning("[src]: аварийная остановка по перегреву!"))
			return
	if(current_heat >= ST_SHIPGEN_CRITICAL_HEAT)
		message_admins("Ship generator overheated at [ADMIN_VERBOSEJMP(src)].")
		log_game("Ship generator overheated at [AREACOORD(src)].")
		overheat()
		qdel(src)
		return
	load_fraction = requested_power / power_gen
	var/needed_fuel = load_fraction * max(1, load_fraction) * seconds_per_tick / time_per_sheet
	var/fuel_used = min(sheets + sheet_left, needed_fuel)
	generated_power = fuel_used < needed_fuel ? requested_power * (fuel_used / needed_fuel) : requested_power
	var/remaining_fuel = max(0, sheets + sheet_left - fuel_used)
	sheets = FLOOR(remaining_fuel, 1)
	sheet_left = remaining_fuel - sheets
	add_avail(generated_power * seconds_per_tick)
	if(!HasFuel())
		TogglePower()

/** Tampering bypasses thermal protection, without changing the electrical hardware's output limit. */
/obj/machinery/power/port_gen/pacman/ship/emag_act(mob/user, obj/item/card/emag/emag_card)
	if(obj_flags & EMAGGED)
		return FALSE
	obj_flags |= EMAGGED
	interlock = FALSE
	balloon_alert(user, "защита отключена")
	return TRUE

/** Extend the native PACMAN contract with ship-only modes and measured generation. */
/obj/machinery/power/port_gen/pacman/ship/ui_data()
	. = ..()
	.["ship_generator"] = TRUE
	.["auto_mode"] = auto_mode
	.["overload"] = overload
	.["interlock"] = interlock
	.["tripped"] = tripped
	.["manual_percent"] = round(power_output * 100)
	.["power_generated"] = display_power(power_gen * 0.25, convert = FALSE)
	.["power_output"] = display_power(generated_power, convert = FALSE)
	.["ready_to_boot"] = active || (anchored && powernet && HasFuel() && !panel_open && is_operational && !tripped)

/** Preserve native power/eject controls and validate ship settings independently of the frontend. */
/obj/machinery/power/port_gen/pacman/ship/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	// The inherited PACMAN controls, including its emag limit, do not grant ship overload permission.
	if(action == "higher_power" || action == "lower_power")
		return TRUE
	. = ..()
	if(.)
		return
	switch(action)
		if("ship_auto")
			auto_mode = !auto_mode
			overload = FALSE
			power_output = min(power_output, 1)
		if("ship_overload")
			if(!overload && (tripped || (interlock && current_heat > ST_SHIPGEN_RESET_HEAT)))
				return TRUE
			overload = !overload
			auto_mode = FALSE
			power_output = overload ? ST_SHIPGEN_OVERLOAD : min(power_output, 1)
		if("ship_interlock")
			interlock = !interlock
			log_game("[key_name(ui.user)] [interlock ? "enabled" : "bypassed"] ship generator protection at [AREACOORD(src)].")
		if("ship_lower_power", "ship_higher_power")
			if(auto_mode)
				return TRUE
			power_output = clamp(power_output + (action == "ship_higher_power" ? 0.25 : -0.25), 0.25, overload ? ST_SHIPGEN_OVERLOAD : 1)
		else
			return FALSE
	return TRUE

#undef ST_SHIPGEN_OVERLOAD
#undef ST_SHIPGEN_DERATE_HEAT
#undef ST_SHIPGEN_TRIP_HEAT
#undef ST_SHIPGEN_RESET_HEAT
#undef ST_SHIPGEN_CRITICAL_HEAT
