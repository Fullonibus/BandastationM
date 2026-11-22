/** Buildable board for the station flight-control console. */
/obj/item/circuitboard/computer/stationtrauma_station_traffic
	name = "центр управления полётами"
	build_path = /obj/machinery/computer/stationtrauma_station_traffic

/datum/design/board/shuttle/stationtrauma_station_traffic
	name = "Плата центра управления полётами"
	desc = "Управляет разрешениями на стыковку к причалам станции или носителя."
	build_path = /obj/item/circuitboard/computer/stationtrauma_station_traffic

/** Station-wide dispatch display and docking-clearance operator console. */
/obj/machinery/computer/stationtrauma_station_traffic
	name = "центр управления полётами"
	desc = "Показывает состояние причалов станции или носителя и заявки на стыковку."
	icon_screen = "comm"
	icon_keyboard = "tech_key"
	req_access = list(ACCESS_COMMAND)
	circuit = /obj/item/circuitboard/computer/stationtrauma_station_traffic

/obj/machinery/computer/stationtrauma_station_traffic/proc/can_operate(mob/user)
	if(QDELETED(src) || QDELETED(user) || !anchored || !is_operational || panel_open)
		return FALSE
	var/datum/stationtrauma_overmap/space/host = stationtrauma_carrier_at(src)
	return (host || (!istype(get_area(src), /area/shuttle) && is_station_level(z))) && can_interact(user) && allowed(user)

/obj/machinery/computer/stationtrauma_station_traffic/proc/traffic_sector()
	var/datum/stationtrauma_overmap/space/host = stationtrauma_carrier_at(src)
	var/datum/stationtrauma_overmap_sector/space/sector = host ? host.sector : SSstationtrauma_space_voyage.sectors["epsilon_eridani"]
	return sector?.ready ? sector : null

/** Only control berths owned by the console's carrier or by the station itself. */
/obj/machinery/computer/stationtrauma_station_traffic/proc/controls_berth(datum/stationtrauma_overmap_sector/space/sector, datum/stationtrauma_overmap_site/space/site, datum/stationtrauma_overmap/space/host)
	if(!sector.is_station_berth(site) || site.host != host)
		return FALSE
	if(host)
		return TRUE
	var/obj/docking_port/stationary/stationtrauma_space_station/berth = site.berth
	return !berth.host_ship_id && is_station_level(berth.z)

/obj/machinery/computer/stationtrauma_station_traffic/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	if(!can_operate(user))
		to_chat(user, span_warning("Для работы с ЦУП нужна закреплённая консоль на станции или носителе и доступ командования."))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "StationTrafficControl", name)
		ui.open()

/obj/machinery/computer/stationtrauma_station_traffic/ui_status(mob/user, datum/ui_state/state)
	if(!can_operate(user))
		return UI_CLOSE
	return ..()

/obj/machinery/computer/stationtrauma_station_traffic/ui_data(mob/user)
	if(!can_operate(user))
		return list()
	var/datum/stationtrauma_overmap/space/host = stationtrauma_carrier_at(src)
	var/datum/stationtrauma_overmap_sector/space/sector = traffic_sector()
	if(QDELETED(sector))
		return list()
	var/list/requests = list()
	var/list/approvals = list()
	for(var/ship_id in sector.station_docking_requests)
		var/datum/stationtrauma_station_docking_request/request = sector.station_docking_requests[ship_id]
		if(QDELETED(request) || !request.is_current() || !controls_berth(sector, request.site, host))
			continue
		if(request.approved)
			approvals[request.site] = request
		requests += list(list(
			"ship_id" = ship_id,
			"token" = request.token,
			"ship" = request.requester.vessel.name,
			"dock_id" = request.site.id,
			"dock" = request.site.name,
			"approved" = request.approved,
			"seconds_left" = ceil((request.expires_at - world.time) / (1 SECONDS)),
		))
	var/list/docks = list()
	for(var/site_id in sector.sites)
		var/datum/stationtrauma_overmap_site/space/site = sector.sites[site_id]
		if(!controls_berth(sector, site, host))
			continue
		docks += list(dock_data(site, approvals[site]))
	return list("sector" = sector.name, "docks" = docks, "requests" = requests)

/obj/machinery/computer/stationtrauma_station_traffic/proc/dock_data(datum/stationtrauma_overmap_site/space/site, datum/stationtrauma_station_docking_request/approval)
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot = site.berth
	var/is_standard = istype(slot)
	var/obj/docking_port/mobile/moored = is_standard ? slot.active_berth?.get_docked() : site.berth.get_docked()
	var/closed = site.failed || stationtrauma_berth_unavailable(site.berth)
	var/status = "free"
	var/ship_name
	if(moored)
		status = "occupied"
		ship_name = moored.name
	else if(approval && site.docking_owner == approval.requester && !(is_standard && slot.active_berth) && site.docking_owner.approach_site != site)
		status = "approved"
		ship_name = approval.requester.vessel.name
	else if(site.docking_owner || site.shuttle_order || (is_standard && slot.active_berth))
		status = "reserved"
		ship_name = site.shuttle_order?.offer["name"] || site.docking_owner?.vessel?.name
		if(!ship_name && is_standard)
			ship_name = slot.active_berth?.ship?.name
	else if(closed)
		status = "unavailable"
	return list("id" = site.id, "name" = site.name, "dock_class" = is_standard ? slot.dock_class : null, "status" = status, "ship" = ship_name)

/** Read current admission without attempting a ship-specific approach or scanning the landing footprint. */
/proc/stationtrauma_berth_unavailable(obj/docking_port/stationary/berth)
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/runtime_slot = berth
	if(istype(runtime_slot))
		return runtime_slot.retiring || !runtime_slot.controller_valid() || runtime_slot.host?.carrier_busy()
	var/obj/docking_port/stationary/stationtrauma_space_station/port = berth
	if(istype(port) && port.host?.carrier_busy())
		return TRUE
	if(SSshuttle.emergency?.mode != SHUTTLE_CALL)
		return FALSE
	for(var/obj/docking_port/stationary/native_berth in berth.loc)
		if(native_berth.shuttle_id == "emergency_home")
			return TRUE
	return FALSE

/obj/machinery/computer/stationtrauma_station_traffic/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(!(action in list("approve", "deny")))
		return FALSE
	return respond_to_request(ui.user, params["ship_id"], params["token"], action == "approve")

/** Authorize and submit an operator's response to the exact request shown at this console. */
/obj/machinery/computer/stationtrauma_station_traffic/proc/respond_to_request(mob/user, ship_id, token, approve)
	if(!can_operate(user) || !istext(ship_id) || !istext(token))
		return FALSE
	var/datum/stationtrauma_overmap/space/host = stationtrauma_carrier_at(src)
	var/datum/stationtrauma_overmap_sector/space/sector = traffic_sector()
	if(QDELETED(sector))
		return FALSE
	var/datum/stationtrauma_station_docking_request/request = sector.station_docking_requests[ship_id]
	if(QDELETED(request) || !controls_berth(sector, request.site, host))
		return FALSE
	if(!sector.respond_station_docking(ship_id, token, approve))
		to_chat(user, span_warning("Заявка или причал изменились. Проверьте актуальный статус."))
		return FALSE
	return TRUE
