// Starting values, 2026-11-17: a third of the fusion core's power, plasma for two small plasma converters.
// Tune by how long a canister and a load of sheets last a small ship.
/// Electrical output at nominal reaction.
#define ST_COMPACT_POWER (200 KILO WATTS)
/// Hydrogen burned at nominal reaction, in moles per second.
#define ST_COMPACT_HYDROGEN_RATE 0.35
/// Hot plasma sent to the converters at nominal reaction: two small plasma converters at full thrust.
#define ST_COMPACT_PLASMA_FLOW (2.6 * 2 / 3)
/// Overdrive raises the reaction by half and burns a third more hydrogen per unit of it.
#define ST_COMPACT_OVERDRIVE_OUTPUT 1.5
#define ST_COMPACT_OVERDRIVE_FUEL (4 / 3)
/// Gaseous plasma one solid sheet sublimates into.
#define ST_COMPACT_SHEET_MOLES 20
/// Sheets the hopper holds.
#define ST_COMPACT_MAX_SHEETS 50
/// Temperature of the plasma and helium leaving for the converters.
#define ST_COMPACT_EXHAUST_TEMPERATURE 700

/**
 * Compact catalytic core: hydrogen fusion catalysed by sublimated plasma, the way muons catalyse fusion without a
 * large magnetic trap. Hydrogen comes in through the inlet pipe, plasma is loaded as solid sheets. The core feeds
 * the cable beneath it and sends the hot plasma, with the helium of the reaction, to the plasma converters.
 *
 * The catalyst is spent only as the working fluid that leaves for the converters; with the outlet line full, the
 * core keeps generating on the plasma it holds. The reaction is a fixed rule, not native gas chemistry.
 */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/compact
	name = "компактное каталитическое ядро"
	desc = "Синтез водорода, катализируемый испарённой плазмой. Питает сеть корабля через кабель под собой и подаёт горячую плазму к плазменным преобразователям тяги."
	connection_description = "Водород поступает с тыльной стороны, горячая плазма выходит со стороны излучателя к плазменным преобразователям. Листы плазмы загружаются вручную. Электричество идёт в кабель под ядром."
	is_electric = FALSE
	icon = 'modular_bandastation/space_overmap/icons/compact_core.dmi'
	icon_state = "core"
	bound_x = 0
	bound_y = 0
	bound_width = 32
	bound_height = 32
	port_reach = 1
	max_integrity = 250
	circuit = /obj/item/circuitboard/machine/stationtrauma_compact_core
	soundloop_type = /datum/looping_sound/stationtrauma_fusion
	overdrive_sound_type = /datum/looping_sound/stationtrauma_fusion/overdrive
	injection_limit = ST_COMPACT_HYDROGEN_RATE * ST_COMPACT_OVERDRIVE_OUTPUT * ST_COMPACT_OVERDRIVE_FUEL
	/// Solid plasma sheets waiting in the hopper.
	var/sheets = 0
	/// Sublimated plasma held in the reaction chamber, in moles.
	var/plasma_moles = 0

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/compact/setDir(newdir)
	. = ..()
	bound_x = 0
	bound_y = 0
	bound_width = 32
	bound_height = 32

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/compact/update_icon_nopipes()
	icon_state = operating_state()

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/compact/casing_overlays()
	return list()

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/compact/refresh_effects()
	var/next_state = operating_state()
	if(effects_state == next_state)
		return
	effects_state = next_state
	var/hum_volume = 0
	switch(next_state)
		if("core_normal")
			set_light(3, 1.5, "#D3A1FF")
			hum_volume = 20
		if("core_overdrive")
			set_light(4, 2, "#F2D6FF")
			hum_volume = 30
		if("core_quiet")
			set_light(2, 0.7, "#9B6BC4")
			hum_volume = 8
		if("core_emergency")
			set_light(2, 1, "#FF4A36")
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

/** A generator follows both the helm and the batteries it charges. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/compact/auto_level(obj/docking_port/mobile/stationtrauma_space/ship)
	var/need = ship?.engines_running ? 100 * max(0.15, ship.overmap?.commanded_thrust()) : 0
	var/charging = 0
	for(var/obj/machinery/power/smes/battery as anything in grid_batteries())
		if(battery.input_attempt && battery_fraction(battery) < 1)
			charging += battery.input_level
	return clamp(max(need, 100 * charging / ST_COMPACT_POWER), ST_CORE_IDLE_LEVEL, 100)

/**
 * Burn hydrogen on the plasma catalyst: power to the cable, hot plasma and helium to the converter line.
 *
 * Arguments:
 * * seconds_per_tick - Machine tick length
 */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/compact/deliver(seconds_per_tick)
	if(!parents[1] || !nodes[1] || (plasma_moles <= 0 && !sublimate_sheet()))
		return
	var/fuel_per_output = ST_COMPACT_HYDROGEN_RATE * (overdrive ? ST_COMPACT_OVERDRIVE_FUEL : 1)
	var/wanted = min(fuel_per_output * target / 100 * (overdrive ? ST_COMPACT_OVERDRIVE_OUTPUT : 1), injection_limit) * seconds_per_tick
	var/datum/gas_mixture/inlet = airs[1]
	var/datum/gas_mixture/burned = wanted > 0 ? inlet.remove_specific(/datum/gas/hydrogen, wanted) : null
	var/hydrogen = burned?.moles[/datum/gas/hydrogen]
	if(!hydrogen)
		return
	fuel_flow = hydrogen / seconds_per_tick
	output = fuel_flow / fuel_per_output
	var/obj/structure/cable/cable = locate() in loc
	if(cable?.powernet)
		cable.powernet.newavail += power_to_energy(ST_COMPACT_POWER * output)
	var/datum/gas_mixture/outlet = airs[2]
	if(!parents[2] || !nodes[2] || outlet.return_pressure() >= ST_CORE_EXHAUST_PRESSURE)
		update_parents()
		return
	var/wanted_plasma = ST_COMPACT_PLASMA_FLOW * output * seconds_per_tick
	while(plasma_moles < wanted_plasma && sublimate_sheet())
		continue
	var/datum/gas_mixture/parcel = new
	parcel.temperature = ST_COMPACT_EXHAUST_TEMPERATURE
	parcel.moles[/datum/gas/plasma] = min(plasma_moles, wanted_plasma)
	// Two hydrogen molecules fuse into one helium atom.
	parcel.moles[/datum/gas/helium] = hydrogen / 2
	plasma_moles -= parcel.moles[/datum/gas/plasma]
	outlet.merge(parcel)
	update_parents()

/** Turn one hopper sheet into gaseous plasma; FALSE when the hopper is empty. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/compact/proc/sublimate_sheet()
	if(sheets <= 0)
		return FALSE
	sheets--
	plasma_moles += ST_COMPACT_SHEET_MOLES
	return TRUE

/** Batteries charged from the core's own grid, found through their input terminals. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/compact/grid_batteries()
	. = list()
	var/obj/structure/cable/cable = locate() in loc
	for(var/obj/machinery/power/terminal/terminal in cable?.powernet?.nodes)
		if(istype(terminal.master, /obj/machinery/power/smes))
			. |= terminal.master

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/compact/fuel_reserve()
	. = stationtrauma_fuel_gauges(list(parents[1]), list(/datum/gas/hydrogen = "Водород"))
	. += list(list("name" = "Твёрдая плазма", "amount" = sheets, "capacity" = ST_COMPACT_MAX_SHEETS, "unit" = "лист."))

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/compact/ui_data(mob/user)
	. = ..()
	.["electric"] = FALSE
	.["power"] = round(ST_COMPACT_POWER * output / (1 KILO WATTS), 0.1)
	.["injection_max"] = ST_COMPACT_HYDROGEN_RATE * ST_COMPACT_OVERDRIVE_OUTPUT * ST_COMPACT_OVERDRIVE_FUEL
	.["fuel_label"] = "Впрыск водорода"
	.["exhaust_label"] = "Магистраль плазмы"

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/compact/control(action, list/params, mob/user)
	if(action != "injection")
		return ..()
	if(panel_open || !IS_FINITE(params["value"]))
		return FALSE
	injection_limit = clamp(params["value"], 0, ST_COMPACT_HYDROGEN_RATE * ST_COMPACT_OVERDRIVE_OUTPUT * ST_COMPACT_OVERDRIVE_FUEL)
	return TRUE

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/compact/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/stack/sheet/mineral/plasma))
		return ..()
	var/obj/item/stack/sheet/mineral/plasma/stack = tool
	var/loaded = min(stack.get_amount(), ST_COMPACT_MAX_SHEETS - sheets)
	if(loaded <= 0)
		balloon_alert(user, "загрузка полна!")
		return ITEM_INTERACT_BLOCKING
	if(!stack.use(loaded))
		return ITEM_INTERACT_BLOCKING
	sheets += loaded
	balloon_alert(user, "загружено листов: [loaded]")
	playsound(src, 'sound/machines/click.ogg', 40, TRUE)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/compact/examine(mob/user)
	. = ..()
	. += span_notice("В загрузке [sheets] из [ST_COMPACT_MAX_SHEETS] листов плазмы.")

/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/compact/on_deconstruction(disassembled)
	if(sheets > 0)
		new /obj/item/stack/sheet/mineral/plasma(drop_location(), sheets)
		sheets = 0
	return ..()

/** A ruptured core spills the plasma it held along with its pipe contents. */
/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/compact/meltdown()
	var/turf/open/ground = get_turf(src)
	var/stored = plasma_moles + sheets * ST_COMPACT_SHEET_MOLES
	if(!rupturing && istype(ground) && stored > 0)
		var/datum/gas_mixture/spill = new
		spill.temperature = ST_COMPACT_EXHAUST_TEMPERATURE
		spill.moles[/datum/gas/plasma] = stored
		plasma_moles = 0
		sheets = 0
		ground.assume_air(spill)
	return ..()

/obj/item/circuitboard/machine/stationtrauma_compact_core
	name = "компактное каталитическое ядро"
	greyscale_colors = CIRCUIT_COLOR_ENGINEERING
	build_path = /obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/plasma/compact
	req_components = list(/datum/stock_part/micro_laser = 2, /datum/stock_part/capacitor = 1, /obj/item/stack/sheet/plasteel = 2)

/datum/design/board/stationtrauma_compact_core
	parent_type = /datum/design/board/stationtrauma_engine
	name = "Плата компактного каталитического ядра"
	desc = "Однотайловое ядро малого корабля: водород и листы плазмы дают электричество и горячую плазму для плазменных преобразователей тяги."
	build_path = /obj/item/circuitboard/machine/stationtrauma_compact_core

#undef ST_COMPACT_POWER
#undef ST_COMPACT_HYDROGEN_RATE
#undef ST_COMPACT_PLASMA_FLOW
#undef ST_COMPACT_OVERDRIVE_OUTPUT
#undef ST_COMPACT_OVERDRIVE_FUEL
#undef ST_COMPACT_SHEET_MOLES
#undef ST_COMPACT_MAX_SHEETS
#undef ST_COMPACT_EXHAUST_TEMPERATURE
