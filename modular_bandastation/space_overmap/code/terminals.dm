/** Buildable station dispatch console board. */
/obj/item/circuitboard/computer/stationtrauma_dispatch
	name = "терминал вызова кораблей"
	build_path = /obj/machinery/computer/stationtrauma_dispatch

/datum/design/board/shuttle/stationtrauma_dispatch
	name = "Плата терминала вызова кораблей"
	desc = "Плата для вызова кораблей к зарегистрированному станционному причалу."
	build_path = /obj/item/circuitboard/computer/stationtrauma_dispatch

/** Station terminal calling an idle registered ship to its assigned berth. */
/obj/machinery/computer/stationtrauma_dispatch
	name = "терминал вызова кораблей"
	desc = "Диспетчерская связь с кораблями, обслуживающими причал."
	icon_screen = "shuttle"
	circuit = /obj/item/circuitboard/computer/stationtrauma_dispatch
	req_one_access = list(ACCESS_COMMAND, ACCESS_EXPLORER)
	/// Stable sector destination ID associated with this station berth.
	var/site_id

/** Rebuilt terminals bind to the nearest registered station berth on their own deck. */
/obj/machinery/computer/stationtrauma_dispatch/proc/dispatch_site()
	var/datum/stationtrauma_overmap_sector/space/sector = SSstationtrauma_space_voyage.sectors["epsilon_eridani"]
	if(site_id)
		return sector?.sites[site_id]
	var/datum/stationtrauma_overmap_site/space/nearest
	var/distance = INFINITY
	for(var/id in sector?.sites)
		var/datum/stationtrauma_overmap_site/space/site = sector.sites[id]
		if(!site.physical_docking || QDELETED(site.berth) || site.berth.z != z)
			continue
		var/range = (x - site.berth.x) ** 2 + (y - site.berth.y) ** 2
		if(range < distance)
			nearest = site
			distance = range
	return nearest

/obj/machinery/computer/stationtrauma_dispatch/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	if(!can_interact(user) || !allowed(user) || panel_open || (machine_stat & (NOPOWER|BROKEN)))
		return
	var/datum/stationtrauma_overmap_sector/space/sector = SSstationtrauma_space_voyage.sectors["epsilon_eridani"]
	var/datum/stationtrauma_overmap_site/space/site = dispatch_site()
	if(QDELETED(site) || site.berth?.z != z)
		return
	// The dialog sleeps, so only IDs survive it; the ship and berth are resolved again afterwards.
	var/requested_site_id = site.id
	var/list/choices = list()
	for(var/id in sector.ships)
		var/datum/stationtrauma_overmap/space/listed = sector.ships[id]
		if(listed.vessel.dispatchable)
			choices["Борт [length(choices) + 1]: [listed.vessel.name]"] = id
	if(!length(choices))
		to_chat(user, span_notice("В системе нет кораблей, доступных для вызова."))
		return
	var/choice = tgui_input_list(user, "Вызвать корабль к причалу", name, choices, timeout = 30 SECONDS)
	if(!choice || QDELETED(src) || !can_interact(user) || !allowed(user) || panel_open || (machine_stat & (NOPOWER|BROKEN)))
		return
	sector = SSstationtrauma_space_voyage.sectors["epsilon_eridani"]
	site = dispatch_site()
	var/datum/stationtrauma_overmap/space/map = sector ? sector.ships[choices[choice]] : null
	if(QDELETED(map) || QDELETED(site) || site.id != requested_site_id || site.berth?.z != z)
		return
	if(map.docked == site)
		to_chat(user, span_notice("Корабль уже у причала."))
		return
	if(!map.dispatch_to(site))
		to_chat(user, span_warning("Корабль не может принять вызов: занят, движется или причал недоступен."))
		return
	to_chat(user, span_notice("Вызов принят. Ожидаемое прибытие через две минуты."))

/** Check an idle callable ship and an available compatible native station berth. */
/datum/stationtrauma_overmap/space/proc/can_dispatch(datum/stationtrauma_overmap_site/space/site)
	// Station delivery is independent of the crew's main-engine switch.
	if(!(is_operational() && vessel.dispatchable && knows_site(site) && !site.failed && site.physical_docking && vessel.permits_docking(site) \
		&& !preparing && !planning && !relocating && !arrival_pending && !docked && !ship_docking && !helm_engaged && speed <= ST_NAV_STOPPED_SPEED \
		&& (!site.docking_owner || site.docking_owner == src) && !QDELETED(site.berth)))
		return FALSE
	if(istype(site.berth, /obj/docking_port/stationary/stationtrauma_space_station/standard))
		var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot = site.berth
		return slot.accepts(vessel) && !slot.active_berth
	return vessel.check_dock(site.berth, TRUE)

/** Reserve a station berth and schedule delivery of a callable idle hull. */
/datum/stationtrauma_overmap/space/proc/dispatch_to(datum/stationtrauma_overmap_site/space/site)
	if(!can_dispatch(site))
		return FALSE
	stop("Вызов к причалу: [site.name]")
	if(!select_site(site.id))
		return FALSE
	cancel_station_docking()
	site.docking_owner = src
	dispatch_target = site
	preparing = TRUE
	dispatch_timer = addtimer(CALLBACK(src, PROC_REF(finish_dispatch), control_revision), ST_SPACE_DISPATCH_TIME, TIMER_STOPPABLE)
	return TRUE

/** Cancel station delivery and release its unoccupied berth reservation. */
/datum/stationtrauma_overmap/space/proc/cancel_dispatch()
	if(dispatch_timer)
		deltimer(dispatch_timer)
		dispatch_timer = null
	if(dispatch_target)
		if(dispatch_target.docking_owner == src && docked != dispatch_target)
			dispatch_target.docking_owner = null
		dispatch_target = null
		preparing = FALSE

/** Revalidate the delivery order before docking; restore virtual position on failure. */
/datum/stationtrauma_overmap/space/proc/finish_dispatch(revision)
	if(!dispatch_target)
		return FALSE
	var/datum/stationtrauma_overmap_site/space/site = dispatch_target
	dispatch_timer = null
	dispatch_target = null
	preparing = FALSE
	if(revision != control_revision || !can_dispatch(site) || site.docking_owner != src)
		if(!QDELETED(site) && site.docking_owner == src)
			site.docking_owner = null
		stop("Вызов к причалу отменён")
		return FALSE
	var/old_x = pos_x
	var/old_y = pos_y
	clear_encounters()
	pos_x = encounter_x = site.pos_x
	pos_y = encounter_y = site.pos_y
	if(dock(instant = TRUE, station_authorized = TRUE))
		return TRUE
	if(!QDELETED(src))
		if(!QDELETED(site) && site.docking_owner == src && docked != site)
			site.docking_owner = null
		pos_x = encounter_x = old_x
		pos_y = encounter_y = old_y
	return FALSE

/** Buildable inter-sector jump terminal board. */
/obj/item/circuitboard/computer/stationtrauma_bluespace
	name = "терминал блюспейс-переходов"
	build_path = /obj/machinery/computer/stationtrauma_bluespace

/** Hull-local terminal selecting charted bluespace jump routes. */
/obj/machinery/computer/stationtrauma_bluespace
	name = "терминал блюспейс-переходов"
	desc = "Расчёт межзвёздного маршрута и управление блюспейс-приводом."
	icon_screen = "shuttle"
	circuit = /obj/item/circuitboard/computer/stationtrauma_bluespace
	use_power = NO_POWER_USE

/** Resolve the overmap of the physical hull containing this terminal. */
/obj/machinery/computer/stationtrauma_bluespace/proc/navigation()
	var/obj/docking_port/mobile/stationtrauma_space/ship = SSshuttle.get_containing_shuttle(src)
	return istype(ship) && ship.is_in_shuttle_bounds(src) ? ship.overmap : null

/obj/machinery/computer/stationtrauma_bluespace/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	if(!can_interact(user) || panel_open || (machine_stat & (NOPOWER|BROKEN)))
		return
	var/datum/stationtrauma_overmap/space/map = navigation()
	if(QDELETED(map))
		return
	// The dialog sleeps, so only the hull ID and helm revision survive it; the overmap is resolved again afterwards.
	var/vessel_id = map.vessel.shuttle_id
	var/revision = map.control_revision
	var/list/choices = list()
	if(map.jump_target)
		choices["Отмена перехода"] = "cancel"
	else
		for(var/list/route as anything in map.jump_data())
			choices[route["name"]] = route["id"]
	map = null
	var/choice = tgui_input_list(user, "Система назначения", name, choices, timeout = 30 SECONDS)
	if(QDELETED(src) || !can_interact(user) || panel_open || (machine_stat & (NOPOWER|BROKEN)) || !(choice in choices))
		return
	map = navigation()
	if(QDELETED(map) || map.vessel.shuttle_id != vessel_id || revision != map.control_revision)
		return
	if(choices[choice] == "cancel")
		map.request_brake()
	else if(!map.request_jump(choices[choice]))
		to_chat(user, span_warning(map.jump_drive() ? "Переход недоступен. Освободите причал и дождитесь завершения текущего манёвра." : "Переход недоступен: блюспейс-привод не заряжен или обесточен."))
