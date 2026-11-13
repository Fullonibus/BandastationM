// Radioactive waste of Celadon's waste planet ruins rebuilt on TG's radioactive emitter; icon states come from Shiptest's hazard sheet.
// https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/code/modules/ruins/objects_and_mobs/generic_hazards/hazards/radioactive_barrels.dm

/** Old barrel of nuclear waste; it irradiates its surroundings and can be dragged away from a path. */
/obj/structure/stationtrauma_nuclear_waste
	name = "nuclear waste barrel"
	desc = "An old container of radioactive byproducts."
	icon = 'modular_bandastation/overmap_ruins/icons/celadon_hazard.dmi'
	icon_state = "barrel"
	density = TRUE
	max_integrity = 600
	/// Distance in turfs reached by its radiation pulses.
	var/rad_range = 2

/obj/structure/stationtrauma_nuclear_waste/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/radioactive_emitter, cooldown_time = 3 SECONDS, range = rad_range, threshold = RAD_MEDIUM_INSULATION)

/** Tipped barrel leaking its waste onto the ground. */
/obj/structure/stationtrauma_nuclear_waste/leaking
	name = "leaking waste barrel"
	desc = "A tipped barrel of nuclear waste, dumped here long ago and still leaking."
	icon_state = "barrel_tipped"
	anchored = TRUE
	rad_range = 3

/** Heap of waste barrels, too heavy to move. */
/obj/structure/stationtrauma_nuclear_waste/stack
	name = "stack of nuclear waste"
	desc = "Discarded nuclear waste. Enough of it can poison a whole planet's atmosphere."
	icon_state = "barrel_3"
	anchored = TRUE
	rad_range = 4

/** Invisible radiation lingering over contaminated ground. */
/obj/effect/abstract/stationtrauma_radiation
	/// Distance in turfs reached by its radiation pulses.
	var/rad_range = 3
	/// Delay between its radiation pulses.
	var/pulse_delay = 4 SECONDS

/obj/effect/abstract/stationtrauma_radiation/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/radioactive_emitter, cooldown_time = pulse_delay, range = rad_range, threshold = RAD_MEDIUM_INSULATION)

/** Intense contamination at the heart of a waste dump. */
/obj/effect/abstract/stationtrauma_radiation/intense
	rad_range = 5
	pulse_delay = 8 SECONDS
