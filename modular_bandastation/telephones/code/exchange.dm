GLOBAL_LIST_EMPTY(telephone_exchanges)
GLOBAL_LIST_EMPTY(telephones)

/// Powered switch connecting desk phones and payphones, including off-station lines.
/obj/machinery/central_telephone_exchange
	name = "central telephone exchange"
	desc = "A switching unit connecting the station's telephone lines."
	icon = 'modular_bandastation/telephones/icons/phone.dmi'
	icon_state = "cte"
	density = TRUE
	idle_power_usage = 100
	processing_flags = START_PROCESSING_MANUALLY

/obj/machinery/central_telephone_exchange/Initialize(mapload)
	. = ..()
	GLOB.telephone_exchanges += src

/obj/machinery/central_telephone_exchange/Destroy()
	GLOB.telephone_exchanges -= src
	disconnect_calls()
	return ..()

/obj/machinery/central_telephone_exchange/on_set_is_operational(old_value)
	. = ..()
	if(!is_operational)
		disconnect_calls()
	update_appearance()

/obj/machinery/central_telephone_exchange/update_overlays()
	. = ..()
	if(is_operational)
		. += emissive_appearance(icon, "cte_light", src)

/// A failed or removed exchange cannot leave either end of a call connected.
/obj/machinery/central_telephone_exchange/proc/disconnect_calls()
	for(var/id in GLOB.telephones)
		var/obj/structure/transmitter/phone = GLOB.telephones[id]
		if(phone.exchange == src)
			phone.end_call()
