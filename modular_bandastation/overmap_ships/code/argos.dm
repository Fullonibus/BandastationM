/** Powered compartments of the independent M-class Argos. */
/area/shuttle/stationtrauma_space/argos
	name = "Argos"
	requires_power = TRUE

/** Argos command bridge. */
/area/shuttle/stationtrauma_space/argos/bridge
	name = "Argos: рубка"

/** Argos private cabin and office. */
/area/shuttle/stationtrauma_space/argos/cabin
	name = "Argos: каюта"

/** Argos medical compartment. */
/area/shuttle/stationtrauma_space/argos/medbay
	name = "Argos: медотсек"

/** Argos security compartment and isolation cell. */
/area/shuttle/stationtrauma_space/argos/security
	name = "Argos: изолятор"

/** Argos passenger lounge and bar. */
/area/shuttle/stationtrauma_space/argos/crew
	name = "Argos: салон"

/** Argos EVA equipment compartment. */
/area/shuttle/stationtrauma_space/argos/eva
	name = "Argos: EVA"

/** Argos central passage and boarding access. */
/area/shuttle/stationtrauma_space/argos/hallway
	name = "Argos: коридор"

/** Argos generators, storage and bluespace drive. */
/area/shuttle/stationtrauma_space/argos/engineering/power
	name = "Argos: энергоотсек"

/** Argos finite air supply and waste collection equipment. */
/area/shuttle/stationtrauma_space/argos/engineering/life_support
	name = "Argos: жизнеобеспечение"

/** Exterior hull trim and nozzles belong to the ship without being sealed compartments. */
/area/shuttle/stationtrauma_space/argos/exterior
	name = "Argos: наружная обшивка"
	monitored_compartment = FALSE
	requires_power = FALSE
	vacuum_by_design = TRUE

/** Argos helm board preserves the restricted console preset through rebuilding. */
/obj/item/circuitboard/computer/stationtrauma_space_navigation/argos
	build_path = /obj/machinery/computer/stationtrauma_space_navigation/argos

/** Argos helm uses the onboard power grid and Central Command crew access. */
/obj/machinery/computer/stationtrauma_space_navigation/argos
	circuit = /obj/item/circuitboard/computer/stationtrauma_space_navigation/argos
	req_access = list(ACCESS_CENT_GENERAL)
	use_power = IDLE_POWER_USE

/** Apply the helm's crew access after the standard machinery interaction checks. */
/obj/machinery/computer/stationtrauma_space_navigation/argos/can_interact(mob/user)
	return ..() && allowed(user)

/** Argos jump terminal board preserves the restricted console preset through rebuilding. */
/obj/item/circuitboard/computer/stationtrauma_bluespace/argos
	build_path = /obj/machinery/computer/stationtrauma_bluespace/argos

/** Argos jump terminal uses the onboard power grid and Central Command crew access. */
/obj/machinery/computer/stationtrauma_bluespace/argos
	circuit = /obj/item/circuitboard/computer/stationtrauma_bluespace/argos
	req_access = list(ACCESS_CENT_GENERAL)
	use_power = IDLE_POWER_USE

/** Apply crew access to jump selection and its post-input revalidation. */
/obj/machinery/computer/stationtrauma_bluespace/argos/can_interact(mob/user)
	return ..() && allowed(user)

/** Argos registration stays on its removable NT board. */
/obj/item/circuitboard/computer/stationtrauma_transponder/nt/argos
	build_path = /obj/machinery/computer/stationtrauma_transponder/argos
	callsign = "Argos"

/** Argos transponder preset retains its NT identity and Central Command crew access. */
/obj/machinery/computer/stationtrauma_transponder/argos
	circuit = /obj/item/circuitboard/computer/stationtrauma_transponder/nt/argos
	req_access = list(ACCESS_CENT_GENERAL)

/** Apply crew access before transmitter controls can be changed. */
/obj/machinery/computer/stationtrauma_transponder/argos/can_interact(mob/user)
	return ..() && allowed(user)
