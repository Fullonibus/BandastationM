/** Removable identification memory; rebuilding a console preserves the installed identity. */
/obj/item/circuitboard/computer/stationtrauma_transponder
	name = "судовой транспондер"
	name_extension = "(плата компьютера)"
	desc = "Регистрационная плата судового ответчика. Позывной и принадлежность записаны в её памяти."
	build_path = /obj/machinery/computer/stationtrauma_transponder
	/// Registered ship name stored on the removable circuitboard.
	var/callsign
	/// Claimed faction stored on the removable circuitboard.
	var/registration_faction

/** Transponder preset nt; identity remains on the removable board. */
/obj/item/circuitboard/computer/stationtrauma_transponder/nt
	registration_faction = "НТ"
	callsign = "Борт НТ"

/** Registered identity installed on Trurl's mapped bridge. */
/obj/item/circuitboard/computer/stationtrauma_transponder/nt/trurl
	callsign = "Трурль"

/** Transponder preset scg; identity remains on the removable board. */
/obj/item/circuitboard/computer/stationtrauma_transponder/scg
	registration_faction = "КССП"
	callsign = "Борт КССП"

/obj/item/circuitboard/computer/stationtrauma_transponder/examine(mob/user)
	. = ..()
	if(callsign && registration_faction)
		. += span_info("Позывной: [html_encode(callsign)]. Принадлежность: [html_encode(registration_faction)].")
	else
		. += span_notice("Регистрационная запись отсутствует.")

/** Hull-connected identification transmitter reading its installed board at reply time. */
/obj/machinery/computer/stationtrauma_transponder
	name = "консоль судового транспондера"
	desc = "Управляет передачей судового позывного и принадлежности."
	icon_screen = "comm"
	icon_keyboard = "tech_key"
	circuit = /obj/item/circuitboard/computer/stationtrauma_transponder
	idle_power_usage = 50
	active_power_usage = 100
	processing_flags = NONE
	/// Crew switch allowing the installed board to answer identification queries.
	var/enabled = TRUE
	/// Physical hull controlled by this navigation instance or console.
	var/obj/docking_port/mobile/stationtrauma_space/vessel

/obj/machinery/computer/stationtrauma_transponder/post_machine_initialize()
	. = ..()
	connect_to_shuttle(FALSE, SSshuttle.get_containing_shuttle(src))

/obj/machinery/computer/stationtrauma_transponder/connect_to_shuttle(mapload, obj/docking_port/mobile/port, obj/docking_port/stationary/dock)
	. = ..()
	if(vessel == port)
		return
	vessel?.transponders.Remove(src)
	vessel = null
	if(istype(port, /obj/docking_port/mobile/stationtrauma_space) && port.is_in_shuttle_bounds(src))
		vessel = port
		vessel.transponders |= src

/obj/machinery/computer/stationtrauma_transponder/Destroy()
	connect_to_shuttle(FALSE, null)
	return ..()

/** Read the installed board itself, so native frame rebuilding preserves a stolen identity. */
/obj/machinery/computer/stationtrauma_transponder/proc/identification()
	if(!enabled || !anchored || (machine_stat & (NOPOWER|BROKEN|MAINT)) || QDELETED(vessel) || !vessel.is_in_shuttle_bounds(src))
		return null
	var/obj/item/circuitboard/computer/stationtrauma_transponder/board = circuit
	if(!istype(board) || board.loc != src || !istext(board.callsign) || !length(board.callsign) || !istext(board.registration_faction) || !length(board.registration_faction))
		return null
	return list("callsign" = board.callsign, "faction" = board.registration_faction)

/obj/machinery/computer/stationtrauma_transponder/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	open_overmap_console(user, ui, "ShipTransponder")

/obj/machinery/computer/stationtrauma_transponder/ui_status(mob/user, datum/ui_state/state)
	return overmap_console_status(user, ..())

/obj/machinery/computer/stationtrauma_transponder/ui_data(mob/user)
	var/obj/item/circuitboard/computer/stationtrauma_transponder/board = circuit
	return list(
		"enabled" = enabled,
		"transmitting" = !!identification(),
		"callsign" = istype(board) ? board.callsign : null,
		"faction" = istype(board) ? board.registration_faction : null,
	)

/obj/machinery/computer/stationtrauma_transponder/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(action != "toggle" || !can_interact(ui.user) || (machine_stat & (NOPOWER|BROKEN)))
		return FALSE
	enabled = !enabled
	return TRUE

/datum/stationtrauma_overmap/space/transponder_identity()
	var/list/identity
	for(var/obj/machinery/computer/stationtrauma_transponder/device as anything in vessel.transponders)
		var/list/answer = device.identification()
		if(!answer)
			continue
		// Contradictory replies do not arbitrarily select one of several transmitters.
		if(identity && (answer["callsign"] != identity["callsign"] || answer["faction"] != identity["faction"]))
			return null
		identity = answer
	return identity
