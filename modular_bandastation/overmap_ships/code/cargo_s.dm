/// Pressurized hull of the Cyberiad S-class freighter.
/area/shuttle/stationtrauma_space/cargo_s
	name = "Челнок: грузовой отсек"
	requires_power = TRUE

/// Crew controls share the freighter's power grid.
/area/shuttle/stationtrauma_space/cargo_s/bridge
	name = "Челнок: рубка"

/// Exposed engine mount moves with the hull and has no life support.
/area/shuttle/stationtrauma_space/cargo_s/exterior
	name = "Челнок: наружная обшивка"
	monitored_compartment = FALSE
	requires_power = FALSE
	vacuum_by_design = TRUE

/// Registration stored on the freighter's transponder board.
/obj/item/circuitboard/computer/stationtrauma_transponder/nt/cargo_s
	callsign = "Челнок"
